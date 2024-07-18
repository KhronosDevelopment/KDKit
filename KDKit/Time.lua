--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

type RemoteTime = {
    unix: number,
    clock: number,
}

local TIME_ADJUSTMENT_RATE: number
local MAX_REMOTE_HISTORY: number
local MIN_REMOTE_HISTORY: number

local Time = {
    remotes = {},
} :: {
    remotes: { RemoteTime },
    now: () -> number,
    recordRemote: (RemoteTime) -> (),
    sync: () -> (),
    waitForSync: () -> number,
    waitForRemote: () -> RemoteTime,
    estimateCurrentRemoteTime: () -> number,
}

if game:GetService("RunService"):IsServer() then
    local URLS = {
        "https://www.google.com/",
        "https://status.cloud.google.com/",
        "https://www.cloudflare.com/",
        "https://www.reddit.com/",
        "https://www.iana.org/",
        "https://www.facebook.com/",
    }

    TIME_ADJUSTMENT_RATE = 1 / 5 -- a 1 second delta is corrected in 5 seconds
    MAX_REMOTE_HISTORY = 4 * #URLS
    MIN_REMOTE_HISTORY = math.floor(#URLS / 2)

    local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
    remote.Name = "_KDKit.Time"

    remote.OnServerInvoke = function(player)
        return Time.now()
    end

    local Requests = require(script.Parent:WaitForChild("Requests"))

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
            error(("[KDKit.Time] Cannot parse invalid date header! Expected RFC 5322 but got: `%s`"):format(h))
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

        local remoteTime = parseDateHeader(response.headers["date"] or error("[KDKit.Time] Missing `date` header!"))
        local remoteTimeGeneratedAtClock = sentAtClock + requestDuration / 2

        return {
            unix = remoteTime,
            clock = remoteTimeGeneratedAtClock,
        }
    end

    function Time.sync()
        local url = assert(table.remove(URLS, 1))
        table.insert(URLS, url)

        local timeout = 1

        local startAt = os.clock()
        local s, r = Utils.try(Utils.retry, 3, function()
            Time.recordRemote(getUrlTime(url, timeout))
        end):result()
        local duration = os.clock() - startAt

        if not s then
            if duration > timeout and workspace.DistributedGameTime < 15 then
                return -- just ignore timeouts, http is notoriously slow at game start
            end

            error(("[KDKit.Time] Failed to parse timestamp from %s\n%s"):format(url, r))
        end
    end

    for i = 1, #URLS do
        task.defer(Time.sync)
    end
else
    TIME_ADJUSTMENT_RATE = 1 / 2 -- a 1 second delta is corrected in 2 seconds
    MAX_REMOTE_HISTORY = 4
    MIN_REMOTE_HISTORY = 1

    -- note: if you require Time on the client, you must also require it on the server!
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.Time") :: RemoteFunction

    function Time.sync()
        local sentAt = os.clock()
        local result = remote:InvokeServer()
        local duration = os.clock() - sentAt

        Time.recordRemote({
            unix = result,
            clock = sentAt + duration / 2,
        })
    end
end

function Time.recordRemote(remote)
    table.insert(Time.remotes, remote)

    local delete = #Time.remotes - MAX_REMOTE_HISTORY
    for i = 1, delete do
        table.remove(Time.remotes, 1)
    end
end

function Time.waitForSync()
    local startedWaitingAt = os.clock()
    local warnAfter = 5
    while #Time.remotes < MIN_REMOTE_HISTORY do
        task.wait()

        if (os.clock() - startedWaitingAt) > warnAfter then
            warn(("[KDKit.Time] waitForSync is taking longer than expected (%d seconds)"):format(warnAfter))
            warnAfter *= 3
        end
    end

    return os.clock() - startedWaitingAt
end

function Time.estimateCurrentRemoteTime()
    Time.waitForSync()

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

local startedSyncingAt = os.clock()
task.defer(function()
    while true do
        local syncHistoryDuration = os.clock() - startedSyncingAt
        Utils.try(Time.sync)
            :catch(function(t)
                task.defer(error, t)
                task.wait(if syncHistoryDuration < 30 then 1 else 5)
            end)
            :proceed(function()
                task.wait(if syncHistoryDuration < 30 then 5 else 15)
            end)
    end
end)

return Time
