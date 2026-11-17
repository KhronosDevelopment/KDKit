--!strict

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local KDRandom = require(script.Parent.Parent:WaitForChild("Random"))
local HttpClient = require(script.Parent:WaitForChild("HttpClient"))

type JsonValue = HttpClient.JsonValue
type JsonValueL = HttpClient.JsonValueL

type BatchingOptions = {
    maxSize: number?, -- how many items can be included in one batch
    maxDuration: number?, -- how long can an item sit in a batch
    delay: number?, -- how long should we wait after a new item before closing the batch
}

type Batch<T> = {
    id: number, -- increments every time a batch is fired
    openedAt: number, -- os.clock
    lastItemAddedAt: number, -- os.clock
    items: { T },
}

type RetryBatchesOptions = {
    initialDelay: number?, -- doubles after every failure
    maxDelay: number?, -- before backoff stops
    maxTries: number?, -- after which the items are dropped
}

type Options = {
    batching: { default: BatchingOptions?, event: BatchingOptions?, profile: BatchingOptions? }?,
    retryBatches: RetryBatchesOptions?,
    timeProvider: (() -> number)?,
    -- false to call `client:close()` from your own game:BindToClose instead, after the last events are queued
    bindToClose: boolean?,
}

type Properties = { [string]: JsonValueL? } -- "?" to allow you to do `{ value = value }` where value might be nil
export type ProfileUpdate = {
    set: Properties?,
    set_once: Properties?,
    add: { [string]: number }?,
    union: { [string]: { JsonValue } }?,
    append: { [string]: JsonValue }?,
    remove: { [string]: JsonValue }?,
    unset: { string }?,
}

type ClientImpl = {
    __index: ClientImpl,
    new: (string, Options?) -> Client,
    getCurrentTime: (Client) -> number,
    batchingParam: (Client, string, string) -> number,
    batchingParams: (Client, string) -> { maxSize: number, maxDuration: number, delay: number },
    batch: (Client, string, any) -> (),
    fireBatch: (Client, string, ((boolean, string?) -> ())?) -> (),
    flushAsync: (Client) -> (),
    close: (Client) -> (),
    queueEvent: (Client, string, Properties?) -> JsonValueL,
    queueEventP: (Client, string, Player, Properties?) -> JsonValueL,
    queueProfileUpdate: (Client, number, ProfileUpdate) -> (),
    queueProfileUpdateP: (Client, Player, ProfileUpdate?) -> (),
}
export type Client = typeof(setmetatable(
    {} :: {
        http: HttpClient.HttpClient,
        options: Options,
        timeProvider: () -> number,
        batches: {
            event: Batch<HttpClient.Event>,
            profile: Batch<HttpClient.ProfileUpdate>,
        },
        inProgressBatchFires: number,
    },
    {} :: ClientImpl
))

local BATCHING_DEFAULT: BatchingOptions = {
    maxSize = 25,
    maxDuration = 30,
    delay = 5,
}

local RETRY_BATCHES_DEFAULT: RetryBatchesOptions = {
    initialDelay = 3,
    maxDelay = 60,
    maxTries = 10,
}

local Client: ClientImpl = {} :: ClientImpl
Client.__index = Client

function Client.new(projectToken, options)
    local self = setmetatable({
        http = HttpClient.new(projectToken),
        options = options or {},
        inProgressBatchFires = 0,
    }, Client) :: Client

    self.timeProvider = self.options.timeProvider or require(script.Parent.Parent:WaitForChild("Time")).now

    self.batches = Utils.mapf({ "event", "profile" }, function(v): (string, Batch<any>)
        return v,
            {
                id = 0,
                openedAt = 0,
                lastItemAddedAt = 0,
                items = {},
            }
    end)

    if self.options.bindToClose ~= false then
        game:BindToClose(function()
            self:close()
        end)
    end

    return self
end

function Client:getCurrentTime()
    return self.timeProvider()
end

function Client:batchingParam(endpoint, param)
    return Utils.dig(self.options.batching, endpoint, param)
        or Utils.dig(self.options.batching, "default", param)
        or BATCHING_DEFAULT[param]
        or error(("[KDKit.Mixpanel] Invalid batching param '%s'"):format(param))
end

function Client:batchingParams(endpoint)
    return {
        maxSize = self:batchingParam(endpoint, "maxSize"),
        maxDuration = self:batchingParam(endpoint, "maxDuration"),
        delay = self:batchingParam(endpoint, "delay"),
    }
end

function Client:batch(endpoint, item)
    local batch = self.batches[endpoint] :: Batch<any>

    table.insert(batch.items, item)
    local nItems = #batch.items

    local now = os.clock()

    batch.lastItemAddedAt = now
    if nItems == 1 then
        batch.openedAt = now
    end

    local batchAge = now - batch.openedAt
    local batchLifespan = self:batchingParam(endpoint, "maxDuration") - batchAge

    if nItems >= self:batchingParam(endpoint, "maxSize") then
        self:fireBatch(endpoint)
    elseif nItems == 1 then
        local me = batch.id
        task.delay(math.min(batchLifespan, self:batchingParam(endpoint, "delay")), function()
            while me == batch.id do
                now = os.clock()
                batchAge = now - batch.openedAt
                batchLifespan = self:batchingParam(endpoint, "maxDuration") - batchAge

                if batchLifespan < 0 then
                    self:fireBatch(endpoint)
                    return
                elseif now - batch.lastItemAddedAt > self:batchingParam(endpoint, "delay") then
                    self:fireBatch(endpoint)
                    return
                end

                task.wait(math.min(batchLifespan, self:batchingParam(endpoint, "delay")))
            end
        end)
    end
end

function Client:fireBatch(endpoint, cb)
    local batch = self.batches[endpoint] :: Batch<any>
    local items = table.clone(batch.items)

    table.clear(batch.items)
    batch.id += 1

    local function fire()
        if endpoint == "event" then
            self.http:import(items)
        else
            assert(endpoint == "profile")
            self.http:updateProfiles(items)
        end
    end

    self.inProgressBatchFires += 1
    task.defer(function()
        local retryInitialDelay: number = Utils.dig(self.options, "retryBatches", "initialDelay")
            or RETRY_BATCHES_DEFAULT.initialDelay
        local retryMaxDelay: number = Utils.dig(self.options, "retryBatches", "maxDelay")
            or RETRY_BATCHES_DEFAULT.maxDelay
        local retryMaxAttempts: number = Utils.dig(self.options, "retryBatches", "maxTries")
            or RETRY_BATCHES_DEFAULT.maxTries

        if retryMaxAttempts <= 0 then
            error("[KDKit.Mixpanel] Must allow at least one batch try.")
        end

        Utils.ensure(function(failed, traceback)
            self.inProgressBatchFires -= 1
            if cb then
                cb(failed, traceback)
            end
        end, Utils.retry, retryMaxAttempts, fire, retryInitialDelay, retryMaxDelay)
    end)
end

-- fires everything queued so far and yields until every batch fire (including retries) has finished
function Client:flushAsync()
    while true do
        for endpoint, batch in self.batches :: { [string]: Batch<any> } do
            if next(batch.items) then
                self:fireBatch(endpoint)
            end
        end

        if self.inProgressBatchFires == 0 then
            return
        end
        task.wait(0.1)
    end
end

-- from now on every item is sent immediately; yields until everything queued has been sent
function Client:close()
    self.options.batching = { default = { maxSize = 0 } }
    self:flushAsync()
    print("[KDKit.Mixpanel] Flushed at game close.")
end

function Client:queueEvent(name, properties)
    properties = properties or {}
    assert(properties)

    if not properties.time then
        properties.time = self:getCurrentTime()
    end

    if not properties["$insert_id"] then
        properties["$insert_id"] = KDRandom.uuid(16)
    end

    print(("[KDKit.Mixpanel] Event '%s' added to batch with properties"):format(name), properties)
    self:batch("event", { event = name, properties = properties })

    return assert(properties["$insert_id"])
end

function Client:queueEventP(name, player, properties)
    -- mixpanel rejects events whose distinct_id isn't a string
    return self:queueEvent(name, Utils.merge(properties or {}, { distinct_id = tostring(player.UserId) }))
end

-- Mixpanel rejects an update with more than one operation, so each one is sent as its own update
local PROFILE_OPERATIONS = { "set", "set_once", "add", "union", "append", "remove", "unset" }

function Client:queueProfileUpdate(distinctId, params)
    print(("[KDKit.Mixpanel] Profile update for '%s' added to batch with params"):format(tostring(distinctId)), params)
    for _, operation in PROFILE_OPERATIONS do
        local value = (params :: any)[operation]
        if value ~= nil then
            self:batch("profile", { ["$distinct_id"] = tostring(distinctId), ["$" .. operation] = value })
        end
    end
end

function Client:queueProfileUpdateP(player, params)
    params = params or {}
    assert(params)

    params.set = Utils.merge({
        name = player.Name,
        displayName = player.DisplayName,
        accountAge = player.AccountAge,
        membershipType = player.MembershipType.Name,
        localeId = player.LocaleId,
    }, params.set or {})

    self:queueProfileUpdate(player.UserId, params)
end

return Client
