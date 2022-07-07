local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

if RunService:IsServer() then
    error("You can't use KDKit.Mouse on the server")
end

local Mouse = {
    cursors = {
        clickable = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
        dragging = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
    },
    cursorByContext = {},
    contexts = {},
    instance = game.Players.LocalPlayer:GetMouse()
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
    if i then table.remove(self.contexts, i) end
    if cursor then
        table.insert(self.contexts, context)
    end
    
    -- update the cursor
    self:recalculateIcon()
end

function Mouse:recalculateIcon()
    local icon = self.cursorByContext[self.contexts[#self.contexts]] or "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
    self.instance.Icon = icon
    return icon
end

function Mouse:getRay(offset)
    return workspace.CurrentCamera:ScreenPointToRay(self.instance.X, self.instance.Y, offset)
end

function Mouse:getPosition(topIsZero)
    local x, y = self.instance.X, self.instance.Y
    
    if topIsZero then
        local topLeftInset, _bottomRightInset = GuiService:GetGuiInset()
        x += topLeftInset.X
        y += topLeftInset.Y
    end
    
    return x, y
end

Mouse:recalculateIcon()
return Mouse
