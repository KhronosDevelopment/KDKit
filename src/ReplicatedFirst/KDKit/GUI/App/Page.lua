local Animate = require(script.Parent.Parent:WaitForChild("Animate"))
local Button = require(script.Parent.Parent:WaitForChild("Button"))
local Class = require(script.Parent.Parent.Parent:WaitForChild("Class"))

local Page = Class.new("KDKit.GUI.App.Page")
Page.TOP_ZINDEX = 100
Page.BOTTOM_ZINDEX = 0

function Page:__init(app, module)
    self.app = app
    self.module = module

    self.name = self.module.Name
    self.instance = module:FindFirstChild("instance")
    self.connections = table.create(16)
    self.buttons = table.create(32)

    if not self.instance then
        error(
            ("You must have a gui object named `instance` under each page. Did not find one under `%s`."):format(
                module:GetFullName()
            )
        )
    end

    self.instance.Name = self.name
    self.instance.Parent = app.instance
end

function Page:rawOpen(transition)
    self.opened = true
    Button:enable(self.instance)
    self.instance.ZIndex = Page.TOP_ZINDEX
    local animationTime = Animate:onscreen(self.instance, true, if transition.initial then 0 else nil)
    self:afterOpened(transition)
    return animationTime
end

function Page:rawClose(transition)
    self:beforeClosed(transition)
    Button:disable(self.instance)
    for _key, connection in self.connections do
        connection:Disconnect()
    end
    table.clear(self.connections)
    self.instance.ZIndex = Page.BOTTOM_ZINDEX
    local animationTime = Animate:offscreen(self.instance, true, if transition.initial then 0 else nil)
    self.opened = false
    return animationTime
end

function Page:afterOpened(transition)
    -- override me
end

function Page:beforeClosed(transition)
    -- override me
end

return Page
