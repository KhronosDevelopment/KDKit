local Animate = require(script.Parent.Parent:WaitForChild("Animate"))
local Button = require(script.Parent.Parent:WaitForChild("Button"))
local Class = require(script.Parent.Parent.Parent:WaitForChild("Class"))
local Utils = require(script.Parent.Parent.Parent:WaitForChild("Utils"))

local Page = Class.new("KDKit.GUI.App.Page")
Page.static.TOP_ZINDEX = 100
Page.static.BOTTOM_ZINDEX = 0

function Page:__init(app, module)
    self.app = app
    self.module = module

    self.name = self.module.Name
    self.instance = module:FindFirstChild("instance")
    self.connections = table.create(16)
    self.buttons = table.create(32)

    -- set this to true if you do not want the page to be added to the history stack
    -- with the exception of when the page is currently open, when it will be on the top of the stack
    -- that is, ephemeral pages will never be opened via a call to App:goBack()
    self.ephemeral = false

    -- these are not used internally, but in asynchronous code it is sometimes useful
    -- to be able to track whether or not the current coroutine is still attached to the
    -- active context of the page
    self.nTimesOpened = 0
    self.nTimesClosed = 0

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
    self.nTimesOpened += 1
    Button:enable(self.instance)
    self.instance.ZIndex = Page.TOP_ZINDEX
    local animationTime =
        Animate:onscreen(self.instance, true, if transition.initial then 0 else nil, transition.initial)
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
    local animationTime =
        Animate:offscreen(self.instance, true, if transition.initial then 0 else nil, transition.initial)
    self.opened = false
    self.nTimesClosed += 1
    return animationTime
end

function Page:afterOpened(transition)
    -- override me
end

function Page:beforeClosed(transition)
    -- override me
end

function Page:cycle(seconds, func, ...)
    task.defer(function(...)
        while task.wait(seconds) do
            if self.opened then
                Utils:try(func, ...):catch(function(err)
                    task.defer(error, err)
                end)
            end
        end
    end, ...)
end

return Page
