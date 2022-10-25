--[[
    Externals
--]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Mouse = require(script.Parent.Parent:WaitForChild("Mouse"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))
local Remote = require(script.Parent.Parent:WaitForChild("Remote"))

--[[
    Class
--]]
local Button = Class.new("KDKit.GUI.Button")
Button.static.list = table.create(256)
Button.static.sound = script:WaitForChild("example")

-- using coroutine instead of task.defer because I want this to execute immediately.
-- Ideally, an alternative sound will be found before this module returns.
coroutine.wrap(function()
    for _, child in script:GetChildren() do
        if child.Name ~= "example" then
            Button.static.sound = child
            return
        end
    end

    Button.static.sound = script.ChildAdded:Wait()
end)()

--[[
    Constants
--]]
Button.static.DELETED_METATABLE = {
    __index = function(_self, key)
        error(("This Button has been deleted. You cannot access the key `%s`."):format(Utils:repr(key)))
    end,
    __newindex = function(_self, key, _value)
        error(("This Button has been deleted. You cannot access the key `%s`."):format(Utils:repr(key)))
    end,
}
Button.static.STYLE_STATE_PRIORITIES = {
    "disabled",
    "loading",
    "active",
    "hovered",
}
Button.static.CUSTOM_HITBOXES = {
    OVAL = function(_btn, xOffset, yOffset, xSize, ySize)
        return (yOffset / ySize - 0.5) ^ 2 + (xOffset / xSize - 0.5) ^ 2 <= 0.25
    end,
    CIRCLE = function(_btn, xOffset, yOffset, xSize, ySize)
        if xSize >= ySize then -- horizontal rectangle
            local padding = xSize - ySize
            return Button.CUSTOM_HITBOXES.OVAL(_btn, xOffset - padding / 2, yOffset, xSize - padding, ySize)
        else -- vertical rectangle
            local padding = ySize - xSize
            return Button.CUSTOM_HITBOXES.OVAL(_btn, xOffset, yOffset - padding / 2, xSize, ySize - padding)
        end
    end,
}
Button.static.USER_INPUT_TYPES = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
Button.static.GET_DEBUG_UIS_STATE = function()
    return {
        AccelerometerEnabled = UserInputService.AccelerometerEnabled,
        KeyboardEnabled = UserInputService.KeyboardEnabled,
        MouseEnabled = UserInputService.MouseEnabled,
        TouchEnabled = UserInputService.TouchEnabled,
    }
end
Button.static.ATTRIBUTE_PREFIX = "kdbtn"

--[[
    Utilities
--]]
local function getPropertyIfExists(object, propertyName)
    local s, r = pcall(function()
        return object[propertyName]
    end)

    if s then
        return s, r
    else
        return s, nil
    end
end

local function parseKeyCode(key: string | Enum.KeyCode | number): Enum.KeyCode?
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    elseif typeof(key) == "string" then
        local s, r = pcall(function()
            return Enum.KeyCode[Humanize:casing(key, "pascal")]
        end)
        if s then
            return r
        else
            return nil
        end
    elseif typeof(key) == "number" then
        return ({
            [0] = Enum.KeyCode.Zero,
            [1] = Enum.KeyCode.One,
            [2] = Enum.KeyCode.Two,
            [3] = Enum.KeyCode.Three,
            [4] = Enum.KeyCode.Four,
            [5] = Enum.KeyCode.Five,
            [6] = Enum.KeyCode.Six,
            [7] = Enum.KeyCode.Seven,
            [8] = Enum.KeyCode.Eight,
            [9] = Enum.KeyCode.Nine,
        })[key]
    end

    return nil
end

local Keybind = Class.new("KDKit.GUI.Button._internal.Keybind")
Keybind.static.nextBindId = 0
Keybind.static.bindCountByKey = table.create(32)
function Keybind.static:useNextBindId()
    self.nextBindId += 1
    return self.nextBindId - 1
end
function Keybind.static:useNextBindString()
    return ("%s_%s"):format(self.__name, self:useNextBindId())
end

function Keybind:__init(button: "KDKit.GUI.Button", key: Enum.KeyCode)
    self.button = button
    self.key = key
end

function Keybind:enable()
    if self.bind then
        return
    end

    Keybind.bindCountByKey[self.key] = (Keybind.bindCountByKey[self.key] or 0) + 1
    self.bind = Keybind:useNextBindString()
    ContextActionService:BindAction(self.bind, function(_actionName, inputState, _inputObject)
        if inputState == Enum.UserInputState.Begin then
            if Button.active == self.button then
                return
            end

            if Button.active then
                local active = Button.active
                Button.active = nil
                active:visualStateChanged()
            end

            Button.active = self.button
            self.button:visualStateChanged()
        elseif inputState == Enum.UserInputState.End then
            if Button.active == self.button then
                self.button:press()

                Button.active = nil
                self.button:visualStateChanged()
            end
        elseif inputState == Enum.UserInputState.Cancel then
            if Button.active == self.button then
                Button.active = nil
                self.button:visualStateChanged()
            end
        end
    end, false, self.key)

    if Keybind.bindCountByKey[self.key] > 1 then
        warn(
            ("You currently have %s Buttons bound to the key `%s`. `%s` was bound most recently and therefore will sink the keypress."):format(
                Keybind.bindCountByKey[self.key],
                Utils:repr(self.key),
                self.button.instance:GetFullName()
            )
        )
    end
end

function Keybind:disable()
    if not self.bind then
        return
    end

    local bindCount = Keybind.bindCountByKey[self.key] - 1
    Keybind.bindCountByKey[self.key] = bindCount

    if bindCount == 0 then
        bindCount = nil
    elseif bindCount == 1 then
        print("Crisis averted. This button used to have multiple binds (see above warning) but now it only has one.")
    end

    ContextActionService:UnbindAction(self.bind)
    self.bind = nil
end

--[[
    Initializer
--]]
function Button:__init(instance: GuiObject, callback: (button: "KDKit.GUI.Button") -> nil)
    self.instance = instance
    self.callback = callback
    Button.list[self.instance] = self

    if self.callback then
        self.callback = Remote:wrapWithClientErrorLogging(
            self.callback,
            ("KDKit.GUI.Button callback <%s>"):format(self.instance:GetFullName()),
            Button.GET_DEBUG_UIS_STATE
        )
    end

    self.loading = false
    self.enabled = false

    self.connections = {}
    self.keybinds = {}

    self.styles = {
        original = table.create(8),
        hovered = table.create(8),
        active = table.create(8),
        loading = table.create(8),
        disabled = table.create(8),
    }

    for name, value in self.instance:GetAttributes() do
        local state, property = name:match(Button.ATTRIBUTE_PREFIX .. "_(%w+)_(.+)")
        if not state then
            continue
        end

        if not self.styles[state] then
            warn(
                ("Found an attribute named `%s` on the button `%s` which looks like it might be a style option, but `%s` is not a valid button state. Valid states are: %s."):format(
                    name,
                    self.instance:GetFullName(),
                    state,
                    Humanize:list(Utils:keys(self.styles))
                )
            )
            continue
        end

        local hasProperty, originalValue = getPropertyIfExists(self.instance, property)
        if not hasProperty then
            error(
                ("KDKit.GUI.Button tried to parse the attribute `%s` on %s, but instances of class `%s` have no such property `%s`"):format(
                    Utils:repr(name),
                    self.instance:GetFullName(),
                    Utils:repr(self.instance.ClassName),
                    Utils:repr(property)
                )
            )
        end

        if typeof(originalValue) ~= typeof(value) then
            error(
                ("KDKit.GUI.Button tried to parse the attribute `%s` on %s, but got an unexpected attribute value of type `%s` which differs from the current property type `%s`"):format(
                    Utils:repr(name),
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

    self:visualStateChanged()
end
Button.__init = Remote:wrapWithClientErrorLogging(Button.__init, "KDKit.GUI.Button.__init", Button.GET_DEBUG_UIS_STATE)

--[[
    Configuration
--]]
function Button:hitbox(hitbox: string | (
    self: "KDKit.GUI.Button",
    xOffset: number,
    yOffset: number,
    sizeX: number,
    sizeY: number
) -> boolean): "KDKit.GUI.Button"
    self.customHitbox = Button.CUSTOM_HITBOXES[Humanize:casing(hitbox, "upperSnake")] or hitbox
    return self
end

function Button:bind(...: string | Enum.KeyCode | number): "KDKit.GUI.Button"
    local keyCodes: { Enum.KeyCode } = {}

    -- Using 2 loops instead of one because this is an all-or-nothing function.
    -- Either all provided keys are bound, or none of them are.
    for _, key in { ... } do
        local keyCode = parseKeyCode(key)
        if not keyCode then
            error(
                ("Failed to parse `%s` into a KeyCode. You may provide any number of keys, but they must all be either a KeyCode (i.e. 'Backspace' or Enum.KeyCode.Backspace) or a number 0-9 which get mapped to 'Zero'-'Nine'"):format(
                    Utils:repr(key)
                )
            )
        end

        if self.keybinds[keyCode] then
            error(("This button is already bound to `%s`"):format(Utils:repr(keyCode)))
        end

        table.insert(keyCodes, keyCode)
    end

    local pressable = self:pressable()
    for _, keyCode in keyCodes do
        self.keybinds[keyCode] = Keybind.new(self, keyCode)
        if pressable then
            self.keybinds[keyCode]:enable()
        end
    end

    return self
end

--[[
    Stateful Rendering
--]]
function Button:style(style, animationTime)
    local t = TweenService:Create(
        self.instance,
        TweenInfo.new(animationTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0),
        style
    )
    t:Play()
    return t
end

function Button:determinePropertyValueDuringState(property, visualState)
    local styles = self.styles

    for _, stateName in Button.STYLE_STATE_PRIORITIES do
        if visualState[stateName] and styles[stateName][property] ~= nil then
            return styles[stateName][property]
        end
    end

    return styles.original[property]
end

function Button:getVisualState()
    local state = {
        hovered = Button.hovered == self and self:pressable(),
        active = Button.active == self,
        loading = self.loading,
        disabled = self.loading or not self.enabled,
    }

    return state
end

function Button:visualStateChanged()
    local visualState = self:getVisualState()
    local previousVisualState = self._previousVisualState or table.clone(visualState)
    self._previousState = table.clone(visualState)

    local becameActive = visualState.active and not previousVisualState.active

    local style = table.clone(self.styles.original)
    for property in style do
        style[property] = self:determinePropertyValueDuringState(property, visualState)
    end

    if self:pressable() then
        for _key, keybind in self.keybinds do
            keybind:enable()
        end
    else
        for _key, keybind in self.keybinds do
            keybind:disable()
        end
    end

    return self:style(style, if becameActive then 0.02 else 0.15)
end

--[[
    Utils
--]]
function Button:customHitboxContainsPoint(x, y)
    if not self.customHitbox then
        return true
    end

    local absolutePosition = self.instance.AbsolutePosition
    local absoluteSize = self.instance.AbsoluteSize
    return self:customHitbox(x - absolutePosition.X, y - absolutePosition.Y, absoluteSize.X, absoluteSize.Y)
end

function Button:pressable()
    return self.enabled and not self.loading
end

function Button:makeSound()
    if typeof(Button.sound) ~= "Instance" or not Button.sound:IsA("Sound") then
        warn(
            ("Button.sound is misconfigured. Expected to find a `Sound` instance, but instead found `%s`"):format(
                Utils:repr(Button.sound)
            )
        )
        return nil
    end

    local sound = Button.sound:Clone()
    sound.Parent = game:GetService("SoundService")
    sound.PlayOnRemove = true
    task.defer(sound.Destroy, sound)
    return sound
end

function Button:press(skipSound)
    if not self:pressable() then
        error(
            "This button is not currently pressable. You can call `button:callback()` directly if you wish (but I don't recommend it)."
        )
    end

    if not skipSound then
        self:makeSound()
    end

    if self.callback then
        self.loading = true
        if Button.active == self then
            Button.active = nil
        end
        self:visualStateChanged()

        Utils:ensure(function()
            self.loading = false
        end, self.callback, self)
    end
end

--[[
    Apply to Groups of Buttons
--]]
function Button.static:applyToAll(root, funcName, ...)
    if type(root) == "table" and root.__class == Button then
        root = root.instance
    end

    for instance, button in self.list do
        if instance == root or instance:IsDescendantOf(root) then
            button[funcName](button, ...)
        end
    end
end

function Button:enable(root)
    local staticCall = self == Button

    if staticCall then
        return self:applyToAll(root, "enable")
    elseif not self.enabled then
        self.enabled = true
        self:visualStateChanged()
    end
end

function Button:disable(root)
    local staticCall = self == Button

    if staticCall then
        return self:applyToAll(root, "disable")
    elseif self.enabled then
        self.enabled = false
        if Button.active == self then
            Button.active = nil
        end
        self:visualStateChanged()
    end
end

function Button:delete(root)
    local staticCall = self == Button

    if staticCall then
        return self:applyToAll(root, "delete")
    else
        self:style(self.styles.original)

        for _, conn in self.connections do
            conn:Disconnect()
        end
        table.clear(self.connections)

        Button.list[self.instance] = nil
        table.clear(self)
        setmetatable(self, Button.DELETED_METATABLE)
    end
end

--[[
    User Input Handling
--]]
RunService.RenderStepped:Connect(function()
    local mouseX, mouseY = Mouse:getPosition()

    local buttonsUnderMouse = table.create(16)
    for _, instanceUnderMouse in PlayerGui:GetGuiObjectsAtPosition(mouseX, mouseY) do
        local button = Button.list[instanceUnderMouse]
        if button and button:customHitboxContainsPoint(mouseX, mouseY) then
            table.insert(buttonsUnderMouse, button)
        end
    end
    table.sort(buttonsUnderMouse, function(a, b)
        return Utils:guiObjectIsOnTopOfAnother(a.instance, b.instance)
    end)

    local mouseHoveringOverButton = buttonsUnderMouse[1]
    if mouseHoveringOverButton ~= Button.hovered then
        if Button.hovered then
            local unHovered = Button.hovered
            Button.hovered = nil
            unHovered:visualStateChanged()
        end

        if mouseHoveringOverButton then
            Button.hovered = mouseHoveringOverButton
            mouseHoveringOverButton:visualStateChanged()
        end
    end

    if Button.hovered and Button.hovered:pressable() then
        Mouse:setIcon("KDKit.GUI.Button", "pointer")
    else
        Mouse:setIcon("KDKit.GUI.Button", nil)
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if Button.USER_INPUT_TYPES[input.UserInputType] and Button.hovered then
        if Button.active then
            local active = Button.active
            Button.active = nil
            active:visualStateChanged()
        end

        if Button.hovered:pressable() then
            Button.active = Button.hovered
            Button.active:visualStateChanged()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Button.USER_INPUT_TYPES[input.UserInputType] and Button.active then
        local active = Button.active
        Button.active = nil
        active:visualStateChanged()

        if active == Button.hovered then
            active:press()
        end
    end
end)

--[[
    End
--]]
return Button
