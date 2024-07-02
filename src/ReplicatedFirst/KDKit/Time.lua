--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

type RemoteTime = {
    unix: number,
    clock: number,
}

local Time = {}

function Time.now(): number
    -- todo
    return 1
end

if game:GetService("RunService"):IsServer() then
    local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
    remote.Name = "_KDKit.Time"

    remote.OnServerInvoke = function(player)
        return Time.now()
    end

    local Requests = require(script.Parent:WaitForChild("Requests"))

    local urls = {
        "https://www.google.com/",
        "https://www.cloudflare.com/",
        "https://www.cdc.gov/",
        "https://www.time.gov/",
    }

    local function parseDateHeader(h: string): number
        return 123
    end

    local function getUrlTime(url: string, timeout: number?): RemoteTime
        local sentAtClock = os.clock()
        local response = Requests.head(url, { timeout = timeout })
        local requestDuration = os.clock() - sentAtClock

        local remoteTime = parseDateHeader(response.headers["Date"] or error("Missing `Date` header!"))
        local remoteTimeGeneratedAtClock = sentAtClock + requestDuration / 2

        return {
            unix = remoteTime,
            clock = remoteTimeGeneratedAtClock,
        }
    end

    function Time.fetch(): RemoteTime
        local results: { RemoteTime } = {}
        local timeout = 3
        for _, url in urls do
            coroutine.wrap(function(u)
                table.insert(results, getUrlTime(u, timeout))
            end)(url)
        end

        local startedAt = os.clock()
        while #results < #urls and os.clock() - startedAt < timeout do
            task.wait()
        end

        local currentTimes = Utils.map(function(r: RemoteTime)
            return r.unix + (os.clock() - r.clock)
        end, results)

        return {
            unix = Utils.median(currentTimes),
            clock = os.clock(),
        }
    end
else
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.Time") :: RemoteFunction

    function Time.fetch(): RemoteTime
        local sentAt = os.clock()
        local result = remote:InvokeServer()
        local duration = os.clock() - sentAt

        return {
            unix = result,
            clock = sentAt + duration / 2,
        }
    end
end

return Time
