--!strict

local RunService = game:GetService("RunService")
local KDRandom = require(script.Parent:WaitForChild("Random"))

-- cannot use a workspace attribute due to some weird bug with GetAttributeChangedSignal, idk, don't wanna deal with it
local instance
if RunService:IsServer() then
    instance = Instance.new("StringValue")
    instance.Name = "_KDKit.JobId"

    if RunService:IsStudio() then
        -- game.JobId is an empty string
        -- so just generate a new one
        instance.Value = "RobloxStudio_" .. KDRandom.uuid(32)
    else
        -- roblox job ids are occasionally reused
        -- I submitted a bug report about this with
        -- with sufficient proof and logging info,
        -- and am awaiting a fix.
        -- for now, just make it unique by adding some extra stuff
        instance.Value = game.JobId .. "_" .. KDRandom.uuid(8)
    end

    instance.Parent = game:GetService("ReplicatedStorage")
else
    instance = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.JobId")
end

return instance.Value
