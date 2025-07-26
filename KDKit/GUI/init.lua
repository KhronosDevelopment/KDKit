--!strict

local App = require(script:WaitForChild("App"))
local Button = require(script:WaitForChild("Button"))
local Animate = require(script:WaitForChild("Animate"))

export type App = App.App
export type Button = Button.Button

return {
    App = App,
    Button = Button,
    Animate = Animate,
}
