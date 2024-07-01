--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Mouse = require(script.Parent.Parent:WaitForChild("Mouse"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))

local Keybind = require(script:WaitForChild("Keybind"))
local LoadingGroups = require(script:WaitForChild("LoadingGroups"))
local S = require(script:WaitForChild("state"))
local T = require(script:WaitForChild("types"))

type ButtonImpl = T.ButtonImpl
export type Button = T.Button

local Button: ButtonImpl = {
    list = {},
    onHoveredButtonChangedCallbacks = {},
} :: ButtonImpl

-- using coroutine instead of task.defer because I want this to execute immediately.
-- Ideally, an alternative sound will be found before this module returns.
S.sound = script:WaitForChild("example")
coroutine.wrap(function()
    for _, child in script:GetChildren() do
        if child.Name ~= "example" then
            S.sound = child
            return
        end
    end

    S.sound = script.ChildAdded:Wait()
end)()

local STYLE_STATE_PRIORITIES = {
    "disabled",
    "loading",
    "active",
    "hovered",
}
local STATE_NO_STYLING: T.ButtonVisualState = { hovered = false, active = false, loading = false, disabled = false }
local CUSTOM_HITBOXES: { [string]: T.ButtonHitbox }
CUSTOM_HITBOXES = {
    OVAL = function(_btn, xOffset, yOffset, xSize, ySize)
        return (yOffset / ySize - 0.5) ^ 2 + (xOffset / xSize - 0.5) ^ 2 <= 0.25
    end,
    CIRCLE = function(_btn, xOffset, yOffset, xSize, ySize)
        if xSize >= ySize then -- horizontal rectangle
            local padding = xSize - ySize
            return CUSTOM_HITBOXES.OVAL(_btn, xOffset - padding / 2, yOffset, xSize - padding, ySize)
        else -- vertical rectangle
            local padding = ySize - xSize
            return CUSTOM_HITBOXES.OVAL(_btn, xOffset, yOffset - padding / 2, xSize, ySize - padding)
        end
    end,
}
local USER_INPUT_TYPES = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
local ATTRIBUTE_PREFIX = "kdbtn"

function Button.applyToAll(root, funcName, ...)
    local rootInstance = if typeof(root) == "Instance" then root else root.instance

    for instance, button in Button.list do
        if instance == rootInstance or instance:IsDescendantOf(rootInstance) then
            button[funcName](button, ...)
        end
    end
end

function Button.enableWithin(root, animationTime)
    Button.applyToAll(root, "enable", animationTime)
end

function Button.disableWithin(root, animationTime)
    Button.applyToAll(root, "disable", animationTime)
end

function Button.deleteWithin(root, instant)
    Button.applyToAll(root, "delete", instant)
end

function Button.worldIsHovered()
    return S.hovered == S.world
end

function Button.otherIsHovered()
    return S.hovered == S.other
end

function Button.worldIsActive()
    return S.active == S.world
end

function Button.otherIsActive()
    return S.active == S.other
end

function Button.new(instance, onClick)
    local self = setmetatable({
        instance = instance,
        onPressCallbacks = {},
        onReleaseCallbacks = {},
        onClickCallbacks = {},
        loadingGroupIds = {},
        callbackIsExecuting = false,
        enabled = false,
        keybinds = {},
        silenced = false,
        stylingEnabled = true,
        styles = {
            original = {},
            hovered = {},
            active = {},
            loading = {},
            disabled = {},
        },
    }, Button) :: Button

    Button.list[self.instance] = self

    if onClick then
        self:onClick(onClick)
    end

    self:loadStyles()
    self:visualStateChanged(0)

    return self
end

function Button:loadStyles()
    for name, value in self.instance:GetAttributes() do
        local state, property = name:match(ATTRIBUTE_PREFIX .. "_(%w+)_(.+)")
        if not state then
            continue
        end

        if not self.styles[state] then
            warn(
                ("Found an attribute named `%s` on the button `%s` which looks like it might be a style option, but `%s` is not a valid button state. Valid states are: %s."):format(
                    name,
                    self.instance:GetFullName(),
                    state,
                    Humanize.list(Utils.keys(self.styles))
                )
            )
            continue
        end

        local originalValue = Utils.getattr(self.instance, property)
        if typeof(originalValue) ~= typeof(value) then
            error(
                ("KDKit.GUI.Button tried to parse the attribute `%s` on %s, but got an unexpected attribute value of type `%s` which differs from the current property type `%s`"):format(
                    Utils.repr(name),
                    self.instance:GetFullName(),
                    typeof(originalValue),
                    typeof(value)
                )
            )
        end

        -- intentionally setting these in this order because you're allowed to
        -- override the original properties using attributes (e.g. `{ATTRIBUTE_PREFIX}_original_Position`)
        self.styles.original[property] = originalValue
        self.styles[state][property] = value
    end
end

function Button:addCallback(callback, event)
    local callbackTable = if event == "press"
        then self.onPressCallbacks
        elseif event == "release" then self.onReleaseCallbacks
        else self.onClickCallbacks

    local disconnected = false

    table.insert(callbackTable, callback)

    return self,
        {
            Disconnect = function()
                if disconnected then
                    return
                end
                disconnected = true

                local found = table.find(callbackTable, callback)

                if found then
                    table.remove(callbackTable, found)
                end
            end,
        }
end

function Button:onPress(callback)
    return self:addCallback(callback, "press")
end

function Button:onRelease(callback)
    return self:addCallback(callback, "release")
end

function Button:onClick(callback)
    return self:addCallback(callback, "click")
end

function Button:hitbox(hitbox)
    if typeof(hitbox) == "string" then
        self.customHitbox = CUSTOM_HITBOXES[Humanize.casing(hitbox, "upperSnake")]
    else
        self.customHitbox = hitbox
    end

    return self
end

function Button:bind(...)
    local pressable = self:pressable()

    for _, keyReference in { ... } do
        local kb = Keybind.new(self, keyReference)
        self.keybinds[kb.key] = kb

        if pressable then
            kb:enable()
        end
    end

    return self
end

function Button:unbindAll()
    for _, keybind in self.keybinds do
        keybind:disable()
    end
    table.clear(self.keybinds)

    return self
end

function Button:loadWith(...)
    for _, id in self.loadingGroupIds do
        LoadingGroups.remove(self, id)
    end

    self.loadingGroupIds = { ... }
    for _, id in self.loadingGroupIds do
        LoadingGroups.add(self, id)
    end

    return self
end

function Button:disableAllStyling()
    self.stylingEnabled = false
    self:visualStateChanged()

    return self
end

function Button:enableAllStyling()
    self.stylingEnabled = true
    self:visualStateChanged()

    return self
end

function Button:silence()
    self.silenced = true
    return self
end

function Button:unSilence()
    self.silenced = false
    return self
end

--[[
    Stateful Rendering
--]]
function Button:style(style, animationTime)
    if animationTime == 0 then
        for name, value in style do
            Utils.setattr(self.instance, name, value)
        end
    else
        TweenService:Create(
            self.instance,
            TweenInfo.new(animationTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0),
            style
        ):Play()
    end
end

function Button:updateStyle(state, property, value)
    self.styles[state][property] = value
    self:visualStateChanged()
end

function Button:determinePropertyValueDuringState(property, visualState)
    local styles = self.styles

    for _, stateName in STYLE_STATE_PRIORITIES do
        if visualState[stateName] and styles[stateName][property] ~= nil then
            return styles[stateName][property]
        end
    end

    return styles.original[property]
end

function Button:getVisualState()
    if not self.stylingEnabled then
        return STATE_NO_STYLING
    end

    local loading = self:isLoading()
    local pressable = self:pressable()

    local state = {
        hovered = pressable and self:isHovered(),
        active = pressable and self:isActive(),
        loading = loading,
        disabled = loading or not self.enabled,
    }

    -- For touch devices, your virtual cursor doesn't move after you tap a button.
    -- It looks quite awkward to have a 'visually hovered' button when you aren't actually 'hovering' over it at all.
    if S.recentMouseMovementCausedByTouchInput then
        state.hovered = state.hovered and state.active
    end

    return state
end

function Button:visualStateChanged(animationTime)
    local visualState = self:getVisualState()
    local previousVisualState = self._previousVisualState
    self._previousVisualState = table.clone(visualState)

    if self:pressable() then
        for _key, keybind in self.keybinds do
            keybind:enable()
        end
    else
        for _key, keybind in self.keybinds do
            keybind:disable()
        end
    end

    if Utils.shallowEqual(visualState, previousVisualState) then
        return
    end

    local activeChanged = previousVisualState and visualState.active ~= previousVisualState.active

    local style = table.clone(self.styles.original)
    for property in style do
        style[property] = self:determinePropertyValueDuringState(property, visualState)
    end

    self:style(style, animationTime or (if activeChanged then 0.02 else 0.1))
end

function Button:isBoundTo(keyCode: Enum.KeyCode)
    return not not self.keybinds[keyCode]
end

function Button:isLoading(): boolean
    return self.callbackIsExecuting or LoadingGroups.anyAreLoading(self.loadingGroupIds)
end

function Button:isWorld()
    return self == S.world
end

function Button:isOther()
    return self == S.other
end

function Button:isActive()
    return self == S.active
end

function Button:isHovered()
    return self == S.hovered
end

function Button:customHitboxContainsPoint(x, y)
    if not self.customHitbox then
        return true
    end

    local absolutePosition = self.instance.AbsolutePosition
    local absoluteSize = self.instance.AbsoluteSize
    return self.customHitbox(
        self :: Button, -- cast is necessary due to bad type solver
        x - absolutePosition.X,
        y - absolutePosition.Y,
        absoluteSize.X,
        absoluteSize.Y
    )
end

function Button:pressable()
    return self.enabled and not self:isLoading()
end

function Button:makeSound()
    if typeof(S.sound) ~= "Instance" or not S.sound:IsA("Sound") then
        warn(
            ("Button.sound is misconfigured. Expected to find a `Sound` instance, but instead found `%s`"):format(
                Utils.repr(S.sound)
            )
        )
        return nil
    end

    local sound = S.sound:Clone()
    sound.Parent = game:GetService("SoundService")
    sound.PlayOnRemove = true
    task.defer(sound.Destroy, sound)
    return sound
end

function Button:activate()
    local currentlyActive = S.active
    if currentlyActive == self then
        return
    elseif currentlyActive then
        currentlyActive:deactivate()
    end

    S.active = self
    self:visualStateChanged()

    if self:pressable() then
        task.defer(self.firePressCallbacks, self)
    end
end

function Button:deactivate()
    if S.active ~= self then
        return
    end

    S.active = nil
    self:visualStateChanged()

    if self:pressable() then
        task.defer(self.fireReleaseCallbacks, self)
    end
end

function Button:simulateMouseDown()
    self:activate()
end

function Button:simulateMouseUp(skipSound)
    self:deactivate()

    if not self:pressable() then
        return
    end

    if not skipSound and not self.silenced then
        self:makeSound()
    end

    self.callbackIsExecuting = true
    LoadingGroups.update(self.loadingGroupIds)
    self:visualStateChanged()

    Utils.ensure(function()
        self.callbackIsExecuting = false
        LoadingGroups.update(self.loadingGroupIds)
        self:visualStateChanged()
    end, self.fireClickCallbacks, self)
end

function Button:click(skipSound: boolean?)
    self:simulateMouseDown()
    self:simulateMouseUp(skipSound)
end

function Button:fireCallbacks(callbackTable)
    Utils.aggregateErrors(function(aggregate)
        for _, cb in callbackTable do
            aggregate(cb, self)
        end
    end)
end

function Button:firePressCallbacks()
    self:fireCallbacks(self.onPressCallbacks)
end

function Button:fireReleaseCallbacks()
    self:fireCallbacks(self.onReleaseCallbacks)
end

function Button:fireClickCallbacks()
    self:fireCallbacks(self.onClickCallbacks)
end

function Button:enable(animationTime)
    if not self.enabled then
        self.enabled = true
        if self:isActive() and self:pressable() then
            task.defer(self.firePressCallbacks, self)
        end
        self:visualStateChanged(animationTime)
    end

    return self
end

function Button:disable(animationTime)
    if self.enabled then
        if self:isActive() and self:pressable() then
            task.defer(self.fireReleaseCallbacks, self)
        end
        self.enabled = false
        self:visualStateChanged(animationTime)
    end

    return self
end

function Button:delete(...)
    local instant = ...
    self:loadWith(nil)
    self:style(self.styles.original, if instant then 0 elseif self:isActive() then 0.02 else 0.1)

    Button.list[self.instance] = nil

    if self:isHovered() then
        S.hovered = nil
    end
    if self:isActive() then
        S.active = nil
    end
end

-- when you interact with something that is a gui object, but not a Button
S.other = Button.new(Instance.new("Frame")):disableAllStyling():silence():enable()

-- when you interact with the world, not a gui object whatsoever
S.world = Button.new(Instance.new("Frame")):disableAllStyling():silence():enable()

--[[
    User Input Handling
--]]
function Button.onHoveredButtonChanged(callback)
    table.insert(Button.onHoveredButtonChangedCallbacks, callback)

    local disconnected = false
    return {
        Disconnect = function()
            if disconnected then
                return false
            end
            disconnected = true

            local i = table.find(Button.onHoveredButtonChangedCallbacks, callback)
            if i then
                table.remove(Button.onHoveredButtonChangedCallbacks, i)
                return true
            end

            return false
        end,
    }
end

local function invokeHoveredButtonChangedCallbacks(newHoveredButton: Button?)
    Utils.aggregateErrors(function(aggregate)
        for _, cb in Button.onHoveredButtonChangedCallbacks do
            aggregate(cb, newHoveredButton)
        end
    end)
end

local function updateGuiState()
    debug.profilebegin("_KDKit.Button.updateGuiState")

    local mouseX, mouseY = Mouse.getPosition()

    local topmostHoveredButton = nil :: Button?
    local topmostHoveredInstance = nil :: GuiObject?
    for _, instanceUnderMouse in PlayerGui:GetGuiObjectsAtPosition(mouseX, mouseY) do
        local button = Button.list[instanceUnderMouse]

        if button then
            if not button:customHitboxContainsPoint(mouseX, mouseY) then
                continue
            end

            if
                not topmostHoveredButton
                or Utils.guiObjectIsOnTopOfAnother(instanceUnderMouse, topmostHoveredInstance :: GuiObject)
            then
                topmostHoveredButton = button
                topmostHoveredInstance = instanceUnderMouse
            end
        elseif
            not topmostHoveredButton
            and (
                (not instanceUnderMouse:IsA("Frame") and not instanceUnderMouse:IsA("TextLabel"))
                or instanceUnderMouse.BackgroundTransparency < 1
            )
        then
            if
                not topmostHoveredInstance
                or Utils.guiObjectIsOnTopOfAnother(instanceUnderMouse, topmostHoveredInstance)
            then
                topmostHoveredInstance = instanceUnderMouse
            end
        end
    end

    local actualHoveredButton
    if topmostHoveredButton then
        actualHoveredButton = topmostHoveredButton
    elseif topmostHoveredInstance then
        S.other.instance = topmostHoveredInstance
        actualHoveredButton = S.other
    else
        actualHoveredButton = S.world
    end

    local persistableHoveredButton = if S.active == nil or actualHoveredButton:isActive()
        then actualHoveredButton
        else nil

    if S.hovered ~= persistableHoveredButton then
        if S.hovered then
            local unHovered = S.hovered
            S.hovered = nil
            unHovered:visualStateChanged()
        end

        if persistableHoveredButton then
            S.hovered = persistableHoveredButton
            persistableHoveredButton:visualStateChanged()
        end

        task.defer(invokeHoveredButtonChangedCallbacks, persistableHoveredButton)
    end

    if S.hovered and S.hovered ~= S.world and S.hovered ~= S.other and S.hovered:pressable() then
        Mouse.setIcon("_KDKit.GUI.Button", "pointer")
    else
        Mouse.setIcon("_KDKit.GUI.Button", nil)
    end

    debug.profileend()
end
RunService:BindToRenderStep("_KDKit.GUI.Button.updateGuiState", Enum.RenderPriority.Input.Value + 1, updateGuiState)

S.recentMouseMovementCausedByTouchInput = false
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        S.recentMouseMovementCausedByTouchInput = false
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        S.recentMouseMovementCausedByTouchInput = true
    end

    if not USER_INPUT_TYPES[input.UserInputType] then
        return
    end

    updateGuiState()

    if S.hovered then
        S.hovered:simulateMouseDown()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not USER_INPUT_TYPES[input.UserInputType] then
        return
    end

    updateGuiState()

    local active = S.active
    if active then
        if S.hovered == active then
            active:simulateMouseUp()
        else
            active:deactivate()
        end
    end
end)

return Button
