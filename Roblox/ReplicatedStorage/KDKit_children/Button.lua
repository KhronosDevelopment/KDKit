-- externals
local KDKit = require(script.Parent)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = RunService:IsRunning() and LocalPlayer:WaitForChild("PlayerGui") or game:GetService("StarterGui")

-- class
local Button = KDKit.Class("Button")

-- utils
local ButtonSound = KDKit.ButtonSound
local GU = KDKit.GUIUtility
local Mouse = KDKit.Mouse

local function makeKeyList(...)
    local keys = {...}

    for i, key in ipairs(keys) do
        if type(key) == "string" then
            keys[i] = Enum.KeyCode[key]
        end
    end

    return keys
end

local _CAS_ACTION_ID = 0
local function getNextCASActionString()
    _CAS_ACTION_ID += 1
    return "__BUTTON_MODULE_CAS_BIND_" .. _CAS_ACTION_ID
end

Button.buttons = {}
Button.hovered = nil
Button.active = nil

Button.collisionTypes = {
    RECTANGLE = function(btn, sx, sy, x, y)
        return x >= 0 and y >= 0 and x <= sx and y <= sy
    end,
    OVAL = function(btn, sx, sy, x, y)
        x = (x / sx) - 0.5
        y = (y / sy) - 0.5
        
        return x * x + y * y <= 0.25
    end,
    CIRCLE = function(btn, sx, sy, x, y)
        if sx >= sy then -- horizontal rectangle
            local padding = sx - sy
            return Button.collisionTypes.OVAL(btn, sx - padding, sy, x - padding / 2, y)
        else -- vertical rectangle
            local padding = sy - sx
            return Button.collisionTypes.OVAL(btn, sx, sy - padding, x, y - padding / 2)
        end
    end,
    -- rounded corners maybe?
}

-- hover checking
Button._rs_conn = RunService.RenderStepped:Connect(function(dt)
    local mouseX, mouseY = Mouse:getPosition()
    local guiObjectsUnderMouse = PlayerGui:GetGuiObjectsAtPosition(
        mouseX,
        mouseY
    )
    
    -- find topmost button which is collided
    local potentialButtons = {}
    for _, obj in ipairs(guiObjectsUnderMouse) do
        local btn = Button.buttons[obj]
        if btn and btn.enabled and btn:isMouseColliding(true) then
            table.insert(potentialButtons, btn)
        end
    end
    table.sort(potentialButtons, function(a, b)
        -- if returns nil or false, order should be maintained
        return GU:aOnTopOfB(a.instance, b.instance) == true
    end)
    
    local actuallyHoveredButton = potentialButtons[1]
    
    -- out with the old, in with the new
    if actuallyHoveredButton ~= Button.hovered then
        if Button.hovered then
            Button.hovered:endHover()
            Button.hovered = nil
        end
        
        if actuallyHoveredButton then
            actuallyHoveredButton:beginHover()
            Button.hovered = actuallyHoveredButton
        end
    end
    
    if Button.hovered and not Button.hovered.loading then
        Mouse:setIcon("KDKit.Button", "clickable")
    else
        Mouse:setIcon("KDKit.Button", nil)
    end
end)

-- active checking
Button.activationInputTypes = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
Button._uis_ib_conn = UserInputService.InputBegan:Connect(function(input)
    if Button.activationInputTypes[input.UserInputType] and Button.hovered then
        if Button.active then
            Button.active:endActive()
            Button.active = nil
        end
        
        Button.active = Button.hovered
        Button.active:beginActive(false)
    end
end)
Button._uis_ie_conn = UserInputService.InputEnded:Connect(function(input)
    if Button.activationInputTypes[input.UserInputType] and Button.active then
        local active = Button.active
        
        active:endActive()
        Button.active = nil
        
        if active == Button.hovered then
            active:press()
        end
    end
end)

local function isValidButtonableInstance(instance)
    local success = pcall(function()
        return instance.Parent, instance.AbsolutePosition, instance.AbsoluteSize, instance.ZIndex
    end)
    
    return success
end

-- implementation
function Button:__init(instance, callback, callbackBeforeClick, callbackAfterClick)
    if Button.buttons[instance] then
        error("A button already exists for this instance: " .. tostring(instance))
    end
    if not isValidButtonableInstance(instance) then
        error("Cannot create button from instance: " .. tostring(instance))
    end
    Button.buttons[instance] = self
    
    -- args
    self.instance = instance
    self.callback = callback
    self.callbackBeforeClick = callbackBeforeClick
    self.callbackAfterClick = callbackAfterClick
    
    -- default properties
    self.enabled = true
    self.hovered = false
    self.active = false
    self.keyed = false
    self.collisionChecker = Button.collisionTypes.RECTANGLE
    self.keybinds = {}
    self.bindWhenEnabled = {}
    self.sound = ButtonSound()
    self.muted = false
    self.loadable = true
    self.loading = false
    self.visuallyLoading = false
    self.loadingShared = {}
    self.deleted = false
    
    -- make connnections
    self.connections = {}
    
    -- destroyer
    self.connections.ancestryChanged = self.instance.AncestryChanged:Connect(function() 
        if not self.instance:IsDescendantOf(game) then
            warn("Button `", self.instance, "` was removed from the game. Please :delete() the button before :Destroy()ing the instance.")
            self:delete()
        end
    end)
    
    -- things to track
    self.isImage = self.instance:IsA("ImageButton") or self.instance:IsA("ImageLabel")
    self.visualHovered = false
    self.visualActive = false
    
    self.style = {
        base = {
            size = self.instance.Size,
            image = self.isImage and self.instance.Image or nil,
            color = self.isImage and self.instance.ImageColor3 or nil,
            bgTransparency = self.instance.BackgroundTransparency,
        },
        
        hovered = {
            animTime = self.instance:GetAttribute("button_hover_anim_time"),
            size = self.instance:GetAttribute("button_hover_size"),
            color = self.instance:GetAttribute("button_hover_color"),
            image = self.instance:GetAttribute("button_hover_image"),
            bgTransparency = self.instance:GetAttribute("button_hover_bg_transparency"),
        },
        
        active = {
            animTime = self.instance:GetAttribute("button_active_anim_time"),
            size = self.instance:GetAttribute("button_active_size"),
            color = self.instance:GetAttribute("button_active_color"),
            image = self.instance:GetAttribute("button_active_image"),
            bgTransparency = self.instance:GetAttribute("button_active_bg_transparency"),
        }
    }
    
    -- validate styles
    local base = self.style.base
    local isImage = self.isImage
    for _, category in ipairs({"hovered", "active"}) do
        local style = self.style[category]
        
        -- validate size
        if typeof(style.size) == "UDim" then
            style.size = UDim2.new(
                base.size.X.Scale * style.size.Scale,
                base.size.X.Offset + style.size.Offset,
                base.size.Y.Scale * style.size.Scale,
                base.size.Y.Offset + style.size.Offset
            )
        elseif typeof(style.size) == "UDim2" then
            style.size = UDim2.new(
                base.size.X.Scale * style.size.X.Scale,
                base.size.X.Offset + style.size.X.Offset,
                base.size.Y.Scale * style.size.Y.Scale,
                base.size.Y.Offset + style.size.Y.Offset
            )
        elseif typeof(style.size) == "nil" then
            -- pass
        else
            warn(("Invalid button attribute `%s` on %s."):format("button_" .. category .. "_size", self.instance:GetFullName()))
            warn(("A UDim or UDim2 was expected, but got %s."):format(typeof(style.size)))
            style.size = nil
        end

        -- validate color
        if typeof(style.color) == "nil" or (isImage and typeof(style.color) == "Color3") then
            -- pass
        else
            warn(("Invalid button attribute `%s` on %s."):format("button_" .. category .. "_color", self.instance:GetFullName()))
            if isImage then
                warn(("A Color3 was expected, but got %s."):format(typeof(style.color)))
            else
                warn("You can only set the color of images.")
            end
            style.color = nil
        end

        -- validate image
        if typeof(style.image) == "nil" or (isImage and typeof(style.image) == "string") then
            -- pass
        else
            warn(("Invalid button attribute `%s` on %s."):format("button_" .. category .. "_imaage", self.instance:GetFullName()))
            if isImage then
                warn(("A string was expected, but got %s."):format(typeof(style.image)))
            else
                warn("You can only set the image of images.")
            end
            style.image = nil
        end
    end
end

function Button:mute()
    self.muted = true
    return self    
end

function Button:unmute()
    self.muted = false
    return self
end

function Button:hull(method)
    local cc = Button.collisionTypes[method:upper()]
    if not cc then error("invalid collision detection method: " .. tostring(method)) end
    self.collisionChecker = cc
end

function Button:bind(...)
    local keys = makeKeyList(...)
    
    for _, key in ipairs(keys) do
        if self.keybinds[key] then
            warn("Tried to bind", key, "multiple times for button `", self.instance, "`, skipping.")
            continue
        end

        if not self.enabled then
            self.keybinds[key] = true
            continue
        end
        
        local actionName = getNextCASActionString() .. "_" .. key.Name
        self.keybinds[key] = actionName
        
        ContextActionService:BindAction(
            actionName,
            function(_, state, obj)
                if state == Enum.UserInputState.Begin then
                    if Button.active then
                        Button.active:endActive()
                        Button.active = nil
                    end
                    
                    Button.active = self
                    self:beginActive(true)
                elseif state == Enum.UserInputState.End then
                    if Button.active == self then
                        self:endActive()
                        Button.active = nil
                        
                        self:press()
                    end
                end
                
                return Enum.ContextActionResult.Sink
            end,
            false,
            key
        )
    end
    
    return self
end

function Button:unbind(...)
    local keys = makeKeyList(...)
    
    for _, key in ipairs(keys) do
        if not self.keybinds[key] then
            warn("Tried to unbind", key, "which already wasn't bound for button `", self.instance, "`, skipping.")
            continue
        end
        
        if self.enabled then
            ContextActionService:UnbindAction(self.keybinds[key])
        end
        
        self.keybinds[key] = nil
    end
    
    return self
end

function Button:unbindAll()
    for key, _ in pairs(self.keybinds) do
        self:unbind(key)
    end
    return self
end

local _rect_collision_type = Button.collisionTypes.RECTANGLE
function Button:isMouseColliding(rect_checked)
    if rect_checked and self.collisionChecker == _rect_collision_type then
        return true
    end
    
    local sx, sy = self.instance.AbsoluteSize.X, self.instance.AbsoluteSize.Y
    local mouseX, mouseY = Mouse:getPosition()
    mouseX -= self.instance.AbsolutePosition.X
    mouseY -= self.instance.AbsolutePosition.Y
    
    return self:collisionChecker(sx, sy, mouseX, mouseY)
end

function Button:determineAnimation(attr, hovered, active)
    local style = self.style
    
    local baseStyle = style.base[attr]
    local activeStyle = style.active[attr]
    local hoveredStyle = style.hovered[attr]
    
    local activeAnimTime = style.active.animTime or 0.05
    local hoveredAnimTime = style.hovered.animTime or 0.2
    
    if active and activeStyle then
        return activeStyle, activeAnimTime
    elseif hovered and hoveredStyle then
        return hoveredStyle, hoveredAnimTime
    elseif activeStyle then
        return baseStyle, activeAnimTime
    elseif hoveredStyle then
        return baseStyle, hoveredAnimTime
    else
        return nil, nil -- it does not have this style
    end
end

function Button:hasAnyAnimations()
    local style = self.style
    
    for _, prop in pairs(style.hovered) do
        if prop ~= nil then return true end
    end
    for _, prop in pairs(style.active) do
        if prop ~= nil then return true end
    end
    
    return false
end

function Button:updateVisuals()
    local style = self.style
    local hovered = self.hovered and not self.loading
    local active = self.active and (self.hovered or self.keyed) and not self.loading
    
    -- make sure something actually changed
    if hovered == self.visualHovered and active == self.visualActive then
        return false
    end
    self.visualHovered = hovered
    self.visualActive = active
    
    local props = {size = "Size", image = "Image", color = "ImageColor3", bgTransparency = "BackgroundTransparency"}
    for attr, propertyName in pairs(props) do
        local newValue, tweenTime = self:determineAnimation(attr, hovered, active)
        
        -- skip this property if we don't have it
        if not newValue or not tweenTime then
            continue
        end
        
        -- don't tween untweenable properties
        if attr == "image" then
            self.instance[propertyName] = newValue
            continue
        end
        
        -- do tween
        TweenService:Create(
            self.instance,
            TweenInfo.new(
                tweenTime,
                Enum.EasingStyle.Quart,
                Enum.EasingDirection.InOut,
                0,
                false,
                0
            ),
            {
                [propertyName] = newValue
            }
        ):Play()
    end
    
    return true
end

function Button:beginHover()
    self.hovered = true
    self:updateVisuals()
end

function Button:endHover()
    self.hovered = false
    self:updateVisuals()
end

function Button:beginActive(isFromKeypress)
    self.active = true
    self.keyed = not not isFromKeypress
    self:updateVisuals()
    
    if not self.muted and not self.loading then
        self.sound:press()
    end
end

function Button:endActive()
    self.active = false
    self.keyed = false
    self:updateVisuals()
end

function Button:noLoad(noload)
    if noload == nil then noload = true end
    self.loadable = not noload
    return self
end

function Button:beginLoading(spinnerOffsetRotation)
    self:endLoading()
    
    -- determine bounds of loading symbol (in SCALE terms)
    local xmin, xmax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
    
    -- absolute bounds of parent (in OFFSET terms)
    local parentAbsPos = self.instance.AbsolutePosition
    local parentAbsSz = self.instance.AbsoluteSize
    for _, v in ipairs(self.instance:GetDescendants()) do
        pcall(function()
            local absPos = v.AbsolutePosition
            local absSz = v.AbsoluteSize
            xmin = math.min(xmin, (absPos.X - parentAbsPos.X) / parentAbsSz.X)
            xmax = math.max(xmax, (absPos.X + absSz.X - parentAbsPos.X) / parentAbsSz.X)
            ymin = math.min(ymin, (absPos.Y - parentAbsPos.Y) / parentAbsSz.Y)
            ymax = math.max(ymax, (absPos.Y + absSz.Y - parentAbsPos.Y) / parentAbsSz.Y)
        end)
    end
    
    if xmin == math.huge then xmin = 0 end
    if xmax == -math.huge then xmax = 1 end
    if ymin == math.huge then ymin = 0 end
    if ymax == -math.huge then ymax = 1 end
    
    -- hide existing children
    local loadingHidden = Instance.new("Frame")
    loadingHidden.Name = "loadingHidden"
    loadingHidden.Size = UDim2.fromScale(1, 1)
    loadingHidden.Visible = false
    loadingHidden.Parent = self.instance
    for _, v in pairs(self.instance:GetChildren()) do
        if v == loadingHidden then continue end
        v.Parent = loadingHidden
    end
    
    -- add loading symbol
    local loading = script.loadingSpinner:Clone()
    loading.Name = "loading"
    loading.Size = UDim2.fromScale(
        (xmax - xmin) * 0.5,
        (ymax - ymin) * 0.5
    )
    loading.Position = UDim2.fromScale(
        (xmin + xmax) / 2,
        (ymin + ymax) / 2
    )
    loading.Rotation = spinnerOffsetRotation or (math.random() * 360)
    loading.Parent = self.instance
    TweenService:Create(
        loading,
        TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, math.huge, false, 0),
        { Rotation = loading.Rotation + 360 }
    ):Play()

    self.loading = true
    self.visuallyLoading = true
    self:updateVisuals()
end

function Button:endLoading()
    self.loading = false
    
    if not self.visuallyLoading then return end
    self.visuallyLoading = false
    self.instance.loading:Destroy()
    
    local loadingHidden = self.instance.loadingHidden
    for _, v in pairs(loadingHidden:GetChildren()) do
        v.Parent = self.instance
    end
    loadingHidden:Destroy()

    self:updateVisuals()
end

function Button:shareLoading(other)
    local btn = Button.buttons[other] or other
    self.loadingShared[btn.instance] = btn
    btn.loadingShared[self.instance] = self
end

function Button:press(root)
    local staticCall = self == Button
    
    if staticCall then
        if type(root) == "table" then
            root = root.instance
        end
        for instance, button in pairs(self.buttons) do
            if instance == root or instance:IsDescendantOf(root) then
                button:enable()
            end
        end
    else
        if self.loading then return end
        
        if not self.muted then
            self.sound:release()
        end
        
        if self.callbackBeforeClick then
            task.defer(self.callbackBeforeClick, self)
        end
        
        if self.callback then
            local after = self.callbackAfterClick
            local loading = {self}
            for _, btn in pairs(self.loadingShared) do
                table.insert(loading, btn)
            end
            
            local loadingSpinnnerOffset = math.random() * 360
            for _, l in ipairs(loading) do
                if l.loadable then l:beginLoading(loadingSpinnnerOffset) end
            end
            
            task.defer(function()
                local s, e = xpcall(self.callback, debug.traceback, self)

                for _, l in ipairs(loading) do
                    if not l.deleted then l:endLoading() end
                end

                if after then
                    task.defer(after, self)
                end
                
                if not s then
                    error(e)
                end
            end)
        end
        
    end
end
Button.click = Button.press

function Button:enable(root)
    local staticCall = self == Button
    
    if staticCall then
        if type(root) == "table" then
            root = root.instance
        end
        for instance, button in pairs(self.buttons) do
            if instance == root or instance:IsDescendantOf(root) then
                button:enable()
            end
        end
    else
        if self.enabled then return self end

        self.enabled = true
        
        if self.loading and not self.visuallyLoading then
            self:beginLoading()
        end

        local keys = {}
        for key, _ in pairs(self.keybinds) do
            table.insert(keys, key)
        end
        self.keybinds = {}

        return self:bind(table.unpack(keys))
    end
end

function Button:disable(root, except)
    local staticCall = self == Button

    if staticCall then
        if type(root) == "table" then
            root = root.instance
        end
        if type(except) == "table" then 
            except = except.instance
        end
        for instance, button in pairs(self.buttons) do
            if except and (instance == except or instance:IsDescendantOf(except)) then
                continue
            end
            if instance == root or instance:IsDescendantOf(root) then
                button:disable()
            end
        end
    else
        -- just because the button was disabled doesn't mean
        -- that the loading has been completed, but visually it should
        local loading = self.loading
        
        self:endLoading()
        self:endActive()
        self:endHover()

        self.loading = loading

        if Button.active == self then
            Button.active = nil
        end

        if Button.hovered == self then
            Button.hovered = nil
        end

        if not self.enabled then return self end

        local keys = {}
        for key, _ in pairs(self.keybinds) do
            table.insert(keys, key)
        end

        self:unbind(table.unpack(keys))
        self.enabled = false
        self:bind(table.unpack(keys))

        return self
    end
end

function Button:delete(root)
    local staticCall = self == Button

    if staticCall then
        if type(root) == "table" then
            root = root.instance
        end
        for instance, button in pairs(self.buttons) do
            if instance == root or instance:IsDescendantOf(root) then
                button:delete()
            end
        end
    else
        self:disable()

        for _, conn in pairs(self.connections) do
            conn:Disconnect()
        end
        self.connections = {}

        Button.buttons[self.instance] = nil
        
        -- remove everything from the button with sensible error message
        for k, v in pairs(self) do
            self[k] = nil
        end
        self.deleted = true
        setmetatable(self, {
            __mode = "kv",
            __index = function(self, name) error("This button has been deleted. You cannot access the value '" .. name .. "'") end,
            __newindex = function(self, name, value) error("This button has been deleted. You cannot set the value '" .. name .. "'") end,
        })
    end
end
Button.clear = Button.delete
Button.clean = Button.delete

return Button
