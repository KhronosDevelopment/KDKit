--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

type RemoteTime = {
    unix: number,
    clock: number,
}

local TIME_ADJUSTMENT_RATE: number
local DELAY_BETWEEN_REMOTE_UPDATES: number
local MAX_REMOTE_HISTORY: number

local Time = {
    remotes = {},
} :: {
    remotes: { RemoteTime },
    now: () -> number,
    fetch: () -> { RemoteTime },
    sync: () -> (),
    waitForRemote: () -> RemoteTime,
    estimateCurrentRemoteTime: () -> number,
}

if game:GetService("RunService"):IsServer() then
    TIME_ADJUSTMENT_RATE = 1 / 5 -- a 1 second delta is corrected in 5 seconds
    DELAY_BETWEEN_REMOTE_UPDATES = 30
    MAX_REMOTE_HISTORY = 4 * 10

    local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
    remote.Name = "_KDKit.Time"

    remote.OnServerInvoke = function(player)
        return Time.now()
    end

    local Requests = require(script.Parent:WaitForChild("Requests"))

    MAX_REMOTE_HISTORY = 4 * 6
    local urls = {
        "https://www.google.com/",
        "https://www.cloudflare.com/",
        "https://www.cdc.gov/",
        "https://www.time.gov/",
    }

    local function parseDateHeader(h: string): number
        local months = {
            Jan = 1,
            Feb = 2,
            Mar = 3,
            Apr = 4,
            May = 5,
            Jun = 6,
            Jul = 7,
            Aug = 8,
            Sep = 9,
            Oct = 10,
            Nov = 11,
            Dec = 12,
        }

        local day, month, year, hour, min, sec = h:match("(%d+)%s+(%a+)%s+(%d+)%s+(%d+)%s*:%s*(%d+)%s*:%s*(%d+)")
        if not day then
            error(("Cannot parse invalid date header! Expected RFC 5322 but got: `%s`"):format(h))
        end

        local dt = DateTime.fromUniversalTime(
            tonumber(year),
            months[month],
            tonumber(day),
            tonumber(hour),
            tonumber(min),
            tonumber(sec)
        )

        return dt.UnixTimestamp
    end

    local function getUrlTime(url: string, timeout: number?): RemoteTime
        local sentAtClock = os.clock()
        local response = Requests.head(url, { timeout = timeout })
        local requestDuration = os.clock() - sentAtClock

        local remoteTime = parseDateHeader(response.headers["date"] or error("Missing `date` header!"))
        local remoteTimeGeneratedAtClock = sentAtClock + requestDuration / 2

        return {
            unix = remoteTime,
            clock = remoteTimeGeneratedAtClock,
        }
    end

    function Time.fetch()
        local results = {} :: { RemoteTime }
        local processing = #urls
        local timeout = 3
        for _, url in urls do
            task.defer(function(u)
                Utils.try(getUrlTime, u, timeout)
                    :proceed(function(r)
                        table.insert(results, r)
                    end)
                    :catch(function(err)
                        task.defer(error, err)
                    end)

                processing -= 1
            end, url)
        end

        while processing > 0 do
            task.wait()
        end

        return results
    end
else
    TIME_ADJUSTMENT_RATE = 1 / 2 -- a 1 second delta is corrected in 2 seconds
    DELAY_BETWEEN_REMOTE_UPDATES = 10
    MAX_REMOTE_HISTORY = 4

    -- note: if you require Time on the client, you must also require it on the server!
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.Time") :: RemoteFunction

    function Time.fetch()
        local sentAt = os.clock()
        local result = remote:InvokeServer()
        local duration = os.clock() - sentAt

        return { {
            unix = result,
            clock = sentAt + duration / 2,
        } }
    end
end

function Time.sync()
    Utils.iextend(Time.remotes, Time.fetch())

    local delete = #Time.remotes - MAX_REMOTE_HISTORY
    for i = 1, delete do
        table.remove(Time.remotes, 1)
    end
end

function Time.estimateCurrentRemoteTime()
    while not next(Time.remotes) do
        task.wait()
    end

    local now = os.clock()
    local currentTimes = Utils.map(function(r: RemoteTime)
        return r.unix + (now - r.clock)
    end, Time.remotes)
    local processingTime = os.clock() - now

    return Utils.mean(currentTimes) + processingTime
end

local lastInvokeAt = nil
local lastReturnValue = nil
function Time.now()
    if not lastInvokeAt then
        lastReturnValue = Time.estimateCurrentRemoteTime()
    else
        local timeSinceLastCall = os.clock() - lastInvokeAt
        local remoteTime = Time.estimateCurrentRemoteTime()
        local localTime = lastReturnValue + timeSinceLastCall

        local requiredAdjustment = remoteTime - localTime
        lastReturnValue = localTime
            + math.sign(requiredAdjustment)
                * math.min(math.abs(requiredAdjustment), timeSinceLastCall * TIME_ADJUSTMENT_RATE)
    end

    lastInvokeAt = os.clock()
    return lastReturnValue
end

task.defer(function()
    local backoff = DELAY_BETWEEN_REMOTE_UPDATES / 4
    while true do
        Utils.try(Time.sync)
            :catch(function(t)
                task.defer(error, t)
                task.wait(backoff)
                backoff *= 2
            end)
            :proceed(function()
                task.wait(DELAY_BETWEEN_REMOTE_UPDATES)
                backoff = DELAY_BETWEEN_REMOTE_UPDATES / 4
            end)
    end
end)

return Time
