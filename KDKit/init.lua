--!strict
local RunService = game:GetService("RunService")

local Assembly = require(script:WaitForChild("Assembly"))
local Cooldown = require(script:WaitForChild("Cooldown"))
local Cryptography = require(script:WaitForChild("Cryptography"))
local Humanize = require(script:WaitForChild("Humanize"))
local Maid = require(script:WaitForChild("Maid"))
local MemoryStoreMutex = require(script:WaitForChild("MemoryStoreMutex"))
local Mixpanel = require(script:WaitForChild("Mixpanel"))
local Mutex = require(script:WaitForChild("Mutex"))
local Preload = require(script:WaitForChild("Preload"))
local Random = require(script:WaitForChild("Random"))
local ReplicatedValue = require(script:WaitForChild("ReplicatedValue"))
local Time = require(script:WaitForChild("Time"))
local Utils = require(script:WaitForChild("Utils"))

export type Assembly = Assembly.Assembly
export type Cooldown = Cooldown.Cooldown
export type Maid = Maid.Maid
export type MemoryStoreMutex = MemoryStoreMutex.MemoryStoreMutex
export type MixpanelClient = Mixpanel.Client
export type Mutex = Mutex.Mutex
export type ReplicatedValue = ReplicatedValue.ReplicatedValue

local KDKit = {
    Assembly = Assembly,
    Cooldown = Cooldown,
    Cryptography = Cryptography,
    Humanize = Humanize,
    Maid = Maid,
    Mixpanel = Mixpanel,
    Mutex = Mutex,
    Preload = Preload,
    Random = Random,
    ReplicatedValue = ReplicatedValue,
    Time = Time,
    Utils = Utils,
}

if RunService:IsServer() then
    KDKit.MemoryStoreMutex = MemoryStoreMutex
    KDKit.Requests = require(script:WaitForChild("Requests"))
else
    KDKit.GUI = require(script:WaitForChild("GUI"))
    KDKit.Mouse = require(script:WaitForChild("Mouse"))
end

return KDKit
