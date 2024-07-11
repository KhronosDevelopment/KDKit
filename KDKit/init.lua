--!strict
local RunService = game:GetService("RunService")

local KDKit = {
    Assembly = require(script:WaitForChild("Assembly")),
    Cooldown = require(script:WaitForChild("Cooldown")),
    Cryptography = require(script:WaitForChild("Cryptography")),
    Humanize = require(script:WaitForChild("Humanize")),
    Maid = require(script:WaitForChild("Maid")),
    Mixpanel = require(script:WaitForChild("Mixpanel")),
    Mutex = require(script:WaitForChild("Mutex")),
    Preload = require(script:WaitForChild("Preload")),
    Random = require(script:WaitForChild("Random")),
    ReplicatedValue = require(script:WaitForChild("ReplicatedValue")),
    Time = require(script:WaitForChild("Time")),
    Utils = require(script:WaitForChild("Utils")),
}

if RunService:IsServer() then
    KDKit.Requests = require(script:WaitForChild("Requests"))
else
    KDKit.GUI = require(script:WaitForChild("GUI"))
    KDKit.Mouse = require(script:WaitForChild("Mouse"))
end

return KDKit
