--!strict

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Requests = require(script.Parent.Parent:WaitForChild("Requests"))
local Crypto = require(script.Parent.Parent:WaitForChild("Cryptography"))

export type JsonValue = boolean | number | string
export type JsonValueL = JsonValue | { JsonValue }

type EventProperties = {
    ["$insert_id"]: string, -- a randomly generated UUID representing *this* event
    time: number, -- unix time the event occurred
    distinct_id: string, -- user id, or empty string if not associated
    [string]: JsonValueL, -- any other properties for the event
}

export type Event = {
    event: string,
    properties: EventProperties,
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
    -- strict: without it mixpanel answers 200 and silently drops events that fail validation
    local response = Requests.post("https://api.mixpanel.com/import", {
        params = { strict = "1" },
        headers = { Authorization = self.authHeader },
        json = Utils.map(events, function(e)
            local properties = Utils.map(e.properties, function<T>(v: T): T
                if typeof(v) == "string" then
                    -- mixpanel automatically truncates to 255 chars, so don't bother uploading more
                    return v:sub(1, 255)
                else
                    return v
                end
            end)
            if typeof(properties.distinct_id) == "number" then
                properties.distinct_id = tostring(properties.distinct_id)
            end
            return {
                event = e.event,
                properties = properties,
            }
        end),
    })

    -- validation failures would fail again on retry; the valid events in the batch were still imported
    if response.statusCode == 400 and response.body:find("failed_records", 1, true) then
        task.defer(
            error,
            ("[KDKit.Mixpanel] %d events failed validation: %s"):format(#events, response.body:sub(1, 1000))
        )
        return response
    end

    response:raiseForStatus()
    return response
end

function HttpClient:updateProfiles(profileUpdates)
    local response = Requests.post("https://api.mixpanel.com/engage", {
        -- ip=0: the request comes from the game server, so geolocating it would give every player the server's city
        params = { verbose = "1", ip = "0" },
        json = Utils.map(profileUpdates, function(p)
            return Utils.merge(p, { ["$token"] = self.projectToken, ["$distinct_id"] = tostring(p["$distinct_id"]) })
        end),
    })
    response:raiseForStatus()

    -- mixpanel answers 200 even when it rejects the whole batch
    local ok, result = pcall(response.json, response)
    if not ok or typeof(result) ~= "table" or result.status ~= 1 then
        error(("[KDKit.Mixpanel] Profile batch rejected: %s"):format(response.body:sub(1, 500)))
    end
    return response
end

return HttpClient
