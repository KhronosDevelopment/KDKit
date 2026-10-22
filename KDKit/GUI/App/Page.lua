--!strict

local T = require(script.Parent:WaitForChild("types"))
local Animate = require(script.Parent.Parent:WaitForChild("Animate"))
local Button = require(script.Parent.Parent:WaitForChild("Button"))
local Utils = require(script.Parent.Parent.Parent:WaitForChild("Utils"))

type PageImpl = T.PageImpl
export type Page = T.Page

local Page: PageImpl = {
    TOP_ZINDEX = 100,
    BOTTOM_ZINDEX = 0,
} :: PageImpl
Page.__index = Page

function Page.new(app, module)
    local self = setmetatable({
        app = app,
        module = module,
        name = module.Name,
        instance = module:FindFirstChild("instance"),
        modalButton = Instance.new("TextButton"),
        connections = {},
        buttons = {},
        opened = false,
        -- set this to true to unlock the mouse while this page is open
        modal = false,
        -- set this to true if you do not want the page to be added to the history stack
        -- with the exception of when the page is currently open, when it will be on the top of the stack
        -- that is, ephemeral pages will never be opened via a call to App():goBack()
        ephemeral = false,
        -- these are not used internally, but in asynchronous code it is sometimes useful
        -- to be able to track whether or not the current coroutine is still attached to the
        -- active context of the page
        nTimesOpened = 0,
        nTimesClosed = 0,
        -- override this!
        animationDuration = {
            onscreen = 1 / 3,
            offscreen = 1 / 3,
        },
    }, Page) :: Page

    if not self.instance then
        error(
            ("[KDKit.GUI.Page] You must have a gui object named `instance` under each page. Did not find one under `%s`."):format(
                module:GetFullName()
            )
        )
    end

    self.instance.Name = self.name
    self.instance.Parent = app.instance

    self.modalButton.Name = "_KDKit.GUI.Page.ModalButton_" .. self.name
    self.modalButton.BackgroundTransparency = 1
    self.modalButton.Position = UDim2.fromScale(-1, -1)
    self.modalButton.Size = UDim2.fromOffset(0, 0)
    self.modalButton.Text = ""
    self.modalButton.AutoButtonColor = false
    self.modalButton.Selectable = false
    self.modalButton.Active = false
    self.modalButton.Modal = true
    self.modalButton.Visible = false
    self.modalButton.Parent = app.instance

    return self
end

function Page:rawOpen(transition)
    self.opened = true
    self.nTimesOpened += 1
    Button.enableWithin(self.instance)
    self.modalButton.Visible = self.modal
    self.instance.ZIndex = Page.TOP_ZINDEX
    local animationTime =
        Animate.onscreen(self.instance, if transition.initial then 0 else self.animationDuration.onscreen)
    self:afterOpened(transition)
    return animationTime
end

function Page:rawClose(transition)
    self:beforeClosed(transition)
    Button.disableWithin(self.instance)
    self.modalButton.Visible = false
    for _key, connection in self.connections do
        connection:Disconnect()
    end
    table.clear(self.connections)
    self.instance.ZIndex = Page.BOTTOM_ZINDEX
    local animationTime =
        Animate.offscreen(self.instance, if transition.initial then 0 else self.animationDuration.offscreen)
    self.opened = false
    self.nTimesClosed += 1
    return animationTime
end

function Page:cycle<Arg...>(seconds, func, ...)
    local stopped = false
    task.defer(function(...)
        while task.wait(seconds) and not stopped do
            if self.opened then
                Utils.try(func, ...):catch(function(err)
                    task.defer(error, err)
                end)
            end
        end
    end, ...)

    return {
        Disconnect = function()
            stopped = true
        end,
    }
end

function Page:afterOpened(transition)
    -- override me
end

function Page:beforeClosed(transition)
    -- override me
end

return Page
