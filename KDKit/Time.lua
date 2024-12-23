--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

local TIME_ADJUSTMENT_RATE: number
local MAX_REMOTE_HISTORY: number
local MIN_REMOTE_HISTORY: number

local Time = {
    remoteOffsets = {},
    avgRemoteOffset = 0,
} :: {
    remoteOffsets: { number },
    avgRemoteOffset: number,
    now: () -> number,
    recordRemoteOffset: (number) -> (),
    sync: () -> (),
    waitForSync: () -> number,
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

    TIME_ADJUSTMENT_RATE = 1 / 300 -- a 1 second delta is corrected in 300 seconds
    MAX_REMOTE_HISTORY = 10 * #URLS
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

    local function getUrlTimeOffset(url: string, timeout: number?): number
        local sentAtClock = os.clock()
        local response = Requests.head(url, { timeout = timeout })
        local requestDuration = os.clock() - sentAtClock

        local remoteTime = parseDateHeader(response.headers["date"] or error("[KDKit.Time] Missing `date` header!"))
        local remoteTimeGeneratedAtClock = sentAtClock + requestDuration / 2

        return remoteTime - remoteTimeGeneratedAtClock
    end

    function Time.sync()
        local url = assert(table.remove(URLS, 1))
        table.insert(URLS, url)

        local timeout = 1

        local startAt = os.clock()
        local s, r = Utils.try(Utils.retry, 3, function()
            Time.recordRemoteOffset(getUrlTimeOffset(url, timeout))
        end):result()
        local duration = os.clock() - startAt

        if not s then
            if duration > timeout and workspace.DistributedGameTime < 15 then
                return -- just ignore timeouts, http is notoriously slow at game start
            end

            error(("[KDKit.Time] Failed to parse timestamp from %s\n%s"):format(url, r))
        end
    end

    task.defer(function()
        repeat
        until game:GetService("RunService").Heartbeat:Wait() < (1 / 50)

        for i = 0, #URLS - 1 do
            task.delay(i / #URLS, Time.sync)
        end
    end)
else
    TIME_ADJUSTMENT_RATE = 1 / 15 -- a 1 second delta is corrected in 15 seconds
    MAX_REMOTE_HISTORY = 5
    MIN_REMOTE_HISTORY = 3

    -- note: if you require Time on the client, you must also require it on the server!
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.Time") :: RemoteFunction

    function Time.sync()
        local sentAt = os.clock()
        local remoteTime = remote:InvokeServer()
        local duration = os.clock() - sentAt
        local remoteTimeGeneratedAtClock = sentAt + duration / 2

        Time.recordRemoteOffset(remoteTime - remoteTimeGeneratedAtClock)
    end

    task.defer(function()
        remote:InvokeServer() -- first call doesn't count towards timing
        for i = 0, 2 do
            task.delay(i / 3, Time.sync)
        end
    end)
end

function Time.recordRemoteOffset(offset)
    table.insert(Time.remoteOffsets, offset)

    local delete = #Time.remoteOffsets - MAX_REMOTE_HISTORY
    for i = 1, delete do
        table.remove(Time.remoteOffsets, 1)
    end

    Time.avgRemoteOffset = Utils.median(Time.remoteOffsets)
end

function Time.waitForSync()
    local startedWaitingAt = os.clock()
    local warnAfter = 5
    while #Time.remoteOffsets < MIN_REMOTE_HISTORY do
        task.wait()

        if (os.clock() - startedWaitingAt) > warnAfter then
            warn(("[KDKit.Time] waitForSync is taking longer than expected (%d seconds)"):format(warnAfter))
            warnAfter *= 3
        end
    end

    return os.clock() - startedWaitingAt
end

local offset = nil
local lastUpdatedOffsetAt = nil
function Time.now(): number
    if not offset or not lastUpdatedOffsetAt then
        Time.waitForSync()
        offset = Time.avgRemoteOffset
        lastUpdatedOffsetAt = os.clock()
    end

    local now = os.clock()
    local offsetDifference = Time.avgRemoteOffset - offset
    offset += math.sign(offsetDifference) * math.min(
        math.abs(offsetDifference),
        (now - lastUpdatedOffsetAt) * TIME_ADJUSTMENT_RATE
    )

    lastUpdatedOffsetAt = now

    return now + offset
end

local startedSyncingAt = os.clock()
task.defer(function()
    Time.waitForSync()

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

        task.wait(math.random())
    end
end)

return Time
