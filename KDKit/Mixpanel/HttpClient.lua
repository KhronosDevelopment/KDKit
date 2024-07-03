--!strict

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Requests = require(script.Parent.Parent:WaitForChild("Requests"))
local Crypto = require(script.Parent.Parent:WaitForChild("Cryptography"))

export type JsonValue = boolean | number | string
export type JsonValueL = JsonValue | { JsonValue }

export type Event = {
    event: string,
    properties: {
        ["$insert_id"]: string, -- a randomly generated UUID representing *this* event
        time: number, -- unix time the event occurred
        distinct_id: string, -- user id, or empty string if not associated
        [string]: JsonValueL, -- any other properties for the event
    },
}

export type ProfileUpdate = {
    -- ["$token"]: string?, -- added automatically
    ["$distinct_id"]: string, -- profile id
    ["$set"]: { [string]: JsonValueL }?,
    ["$set_once"]: { [string]: JsonValueL }?,
    ["$add"]: { [string]: number }?,
    ["$union"]: { [string]: { JsonValueL } }?,
    ["$append"]: { [string]: JsonValue }?,
    ["$remove"]: { [string]: JsonValue }?,
    ["$unset"]: { string }?,
}

type HttpClientImpl = {
    __index: HttpClientImpl,
    new: (string) -> HttpClient,
    import: (HttpClient, { Event }) -> Requests.Response,
    updateProfiles: (HttpClient, { ProfileUpdate }) -> Requests.Response,
}
export type HttpClient = typeof(setmetatable(
    {} :: {
        projectToken: string,
        authHeader: string,
    },
    {} :: HttpClientImpl
))

local HttpClient: HttpClientImpl = {} :: HttpClientImpl
HttpClient.__index = HttpClient

function HttpClient.new(projectToken)
    -- unfortunately I cannot support `Secret`s since Mixpanel requires it in the request body
    local self = setmetatable({
        projectToken = projectToken,
        authHeader = "Basic " .. Crypto.base64.encode(projectToken .. ":"),
    }, HttpClient) :: HttpClient

    return self
end

function HttpClient:import(events)
    return Requests.post("https://api.mixpanel.com/import", {
        headers = { Authorization = self.authHeader },
        json = events,
    })
end

function HttpClient:updateProfiles(profileUpdates)
    return Requests.post("https://api.mixpanel.com/engage#profile-batch-update", {
        json = Utils.map(function(p: ProfileUpdate)
            return Utils.merge(p, { ["$token"] = self.projectToken })
        end, profileUpdates),
    })
end

return HttpClient
