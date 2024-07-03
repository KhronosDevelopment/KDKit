--!strict
local RunService = game:GetService("RunService")

return {
    Assembly = require(script:WaitForChild("Assembly")),
    Cooldown = require(script:WaitForChild("Cooldown")),
    Cryptography = require(script:WaitForChild("Cryptography")),
    GUI = require(script:WaitForChild("GUI")),
    Humanize = require(script:WaitForChild("Humanize")),
    JobId = require(script:WaitForChild("JobId")),
    Maid = require(script:WaitForChild("Maid")),
    Mixpanel = require(script:WaitForChild("Mixpanel")),
    Mouse = if RunService:IsClient() then require(script:WaitForChild("Mouse")) else nil,
    Mutex = require(script:WaitForChild("Mutex")),
    Preload = require(script:WaitForChild("Preload")),
    Random = require(script:WaitForChild("Random")),
    ReplicatedValue = require(script:WaitForChild("ReplicatedValue")),
    Requests = if RunService:IsServer() then require(script:WaitForChild("Requests")) else nil,
    Time = require(script:WaitForChild("Time")),
    Utils = require(script:WaitForChild("Utils")),
}
