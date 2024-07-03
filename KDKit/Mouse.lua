--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Mouse = {
    cursors = {
        pointer = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
        grabbing = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
        dragging = "rbxasset://textures/Cursors/mouseIconCameraTrack.png",
    },
    cursorByContext = {} :: { [string]: string },
    contexts = {} :: { string },
}

function Mouse.setIcon(context: string?, cursor: string?)
    context = context or "global"
    cursor = Mouse.cursors[cursor] or cursor

    assert(context)

    if Mouse.cursorByContext[context] == cursor then
        return
    end

    Mouse.cursorByContext[context] = cursor :: any -- cast required because `cursor` may be `nil`

    -- move this context to the back, since it most recently changed
    -- or delete it if the cursor was cleared
    local i = table.find(Mouse.contexts, context)
    if i then
        table.remove(Mouse.contexts, i)
    end
    if cursor then
        table.insert(Mouse.contexts, context)
    end

    -- update the cursor
    Mouse.updateIcon()
end

function Mouse.updateIcon(): string
    local icon = Mouse.cursorByContext[Mouse.contexts[#Mouse.contexts]]
        or "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
    UserInputService.MouseIcon = icon
    return icon
end

function Mouse.getRay(offset: number): Ray
    local x, y = Mouse.getPosition()
    return workspace.CurrentCamera:ScreenPointToRay(x, y, offset)
end

function Mouse.getPosition(topIsZero: boolean?): (number, number)
    local pos = UserInputService:GetMouseLocation()

    if not topIsZero then
        local topLeftInset, _bottomRightInset = GuiService:GetGuiInset()
        pos -= topLeftInset
    end

    return pos.X, pos.Y
end

Mouse.updateIcon()
return Mouse
