local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

if RunService:IsServer() then
    return nil
end

local Mouse = {
    cursors = {
        pointer = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
        grabbing = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
    },
    cursorByContext = {},
    contexts = {},
}

function Mouse:setIcon(context, cursor)
    context = context or "global"
    cursor = self.cursors[cursor] or cursor

    if self.cursorByContext[context] == cursor then
        return
    end
    self.cursorByContext[context] = cursor

    -- move this context to the back, since it most recently changed
    -- or delete it if the cursor was cleared
    local i = table.find(self.contexts, context)
    if i then
        table.remove(self.contexts, i)
    end
    if cursor then
        table.insert(self.contexts, context)
    end

    -- update the cursor
    self:updateIcon()
end

function Mouse:updateIcon()
    local icon = self.cursorByContext[self.contexts[#self.contexts]]
        or "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
    UserInputService.MouseIcon = icon
    return icon
end

function Mouse:getRay(offset)
    local x, y = self:getPosition()
    return workspace.CurrentCamera:ScreenPointToRay(x, y, offset)
end

function Mouse:getPosition(topIsZero)
    local pos = UserInputService:GetMouseLocation()

    if not topIsZero then
        local topLeftInset, _bottomRightInset = GuiService:GetGuiInset()
        pos -= topLeftInset
    end

    return pos.X, pos.Y
end

Mouse:updateIcon()
return Mouse
