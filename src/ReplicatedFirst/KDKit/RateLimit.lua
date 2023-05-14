--[[
    A simple blocking rate limiter.

    ```lua
    local rl = KDKit.RateLimit.new(3, 5) -- rate limit at 3 processes every 5 seconds

    -- this loop will immediately print 3 times, then wait 5 seconds, and print another 3 times, etc.
    while true do
        rl:useWhenReady()
        print("running")
    end
    ```
--]]

local Class = require(script.Parent:WaitForChild("Class"))
local Utils = require(script.Parent:WaitForChild("Utils"))
local Humanize = require(script.Parent:WaitForChild("Humanize"))

local RateLimit = Class.new("KDKit.RateLimit")

function RateLimit:__init(limit, period)
    self.limit = limit or 60
    self.period = period or 60

    if self.period > 3600 then
        error(
            ("The maximum period allowed is 1 hour (to avoid wasting memory), but your period is set to %s. If you wish to construct a unlimited RateLimit, then increase the limit - not the period."):format(
                Humanize:timeDelta(self.period)
            )
        )
    end

    self.pools = {}
end

function RateLimit:getOrCreatePool(key)
    if key == nil then
        key = "global"
    end

    -- please don't call this function without also calling maybeRemovePoolAfterLimitRemainingIncreased to clean it up
    local pool = self.pools[key]
    if not pool then
        pool = { limitRemaining = self.limit, queued = 0, dequeued = 0 }
        self.pools[key] = pool
    end

    return pool
end

function RateLimit:maybeRemovePoolAfterLimitRemainingIncreased(key)
    if key and key ~= "global" then
        local pool = self.pools[key]
        if pool and pool.queued <= pool.dequeued and pool.limitRemaining >= self.limit then
            self.pools[key] = nil
        end
    end
end

function RateLimit:isReady(key)
    if key == nil then
        key = "global"
    end

    local pool = self.pools[key]
    return not pool or pool.limitRemaining > 0
end

function RateLimit:use(key, waitUntilReady)
    if key == nil then
        key = "global"
    end
    local pool = self:getOrCreatePool(key)

    if pool.limitRemaining <= 0 then
        if not waitUntilReady then
            error(("RateLimit is not ready (key = `%s`)"):format(Utils:repr(key)))
        else
            local threadsBeforeMe = pool.queued

            -- add myself to the queue
            pool.queued += 1

            -- wait until all the threads before me have gone
            while pool.dequeued ~= threadsBeforeMe do
                task.wait()
            end

            -- wait until there is limit remaining
            while pool.limitRemaining <= 0 do
                task.wait()
            end

            -- remove myself from the queue
            pool.dequeued += 1
        end
    end

    pool.limitRemaining -= 1
    task.delay(self.period, function()
        pool.limitRemaining += 1
        self:maybeRemovePoolAfterLimitRemainingIncreased(key)
    end)

    return pool.limitRemaining - pool.queued + pool.dequeued
end

function RateLimit:useWhenReady(key)
    return self:use(key, true)
end

return RateLimit
