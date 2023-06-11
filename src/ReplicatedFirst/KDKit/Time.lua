local Time = {
    config = nil,
    remote = {
        time = os.time(),
        fetchedAt = nil,
    },
    REMOTE_FUNCTION_NAME = "KDKit.Time.now",
    INITIALIZATION_WARNING_INTERVAL = 3,
}

if game:GetService("RunService"):IsServer() then
    Time.config = require(game:GetService("ServerStorage"):WaitForChild("KDKit.Configuration"):WaitForChild("Time"))
    Time.remoteFunction = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
    Time.remoteFunction.Name = Time.REMOTE_FUNCTION_NAME

    Time.remoteFunction.OnServerInvoke = function(...)
        return Time:now()
    end

    function Time:fetchRemoteTime()
        return self.config:fetchRemoteTime()
    end
else
    Time.config = {
        remoteFetchRate = 1, -- rather fast remote fetch rate since it's a simple workspace:GetAttribute()
        catchupRate = 0.5, -- rather fast catchup rate since the client and server should stay relatively in sync
    }
    Time.remoteFunction = game:GetService("ReplicatedStorage"):WaitForChild(Time.REMOTE_FUNCTION_NAME) :: RemoteFunction

    function Time:fetchRemoteTime()
        return self.remoteFunction:InvokeServer()
    end
end

function Time:fetchRemoteAndPing()
    local before = os.clock()
    local remoteTime = self:fetchRemoteTime()
    local ping = os.clock() - before

    return remoteTime, ping
end

function Time:updateRemoteTime()
    local remoteTime, pingTime = self:fetchRemoteAndPing()

    -- assume that the remote rendered in the middle of the request
    remoteTime -= pingTime / 2

    self.remote = {
        time = remoteTime,
        at = os.clock(),
    }
end

function Time:waitForInitialSync()
    local warnAt = os.clock() + Time.INITIALIZATION_WARNING_INTERVAL + math.max(6 - workspace.DistributedGameTime, 0)
    while not self.remote.at do
        task.wait()
        if os.clock() > warnAt then
            warn(
                "KDKit.Time:waitForInitialSync() is taking longer than expected. To silence this warning, increase Time.INITIALIZATION_WARNING_INTERVAL."
            )
            warnAt = os.clock() + Time.INITIALIZATION_WARNING_INTERVAL
        end
    end
end

function Time:estimateCurrentRemoteTime()
    self:waitForInitialSync()
    return self.remote.time + (os.clock() - self.remote.at)
end

local lastInvokeAt
local lastReturnValue
function Time:now()
    if not lastInvokeAt then
        lastReturnValue = self:estimateCurrentRemoteTime()
    else
        local timeSinceLastCall = os.clock() - lastInvokeAt
        local remoteTime = self:estimateCurrentRemoteTime()
        local localTime = lastReturnValue + timeSinceLastCall

        local requiredAdjustment = remoteTime - localTime
        lastReturnValue = localTime
            + math.sign(requiredAdjustment)
                * math.min(math.abs(requiredAdjustment), timeSinceLastCall * self.config.catchupRate)
    end

    lastInvokeAt = os.clock()
    return lastReturnValue
end

-- not using task.defer because I would actually like to begin execution on this immediately.
-- that way, clients can access Time() without any initial delays since the workspace attribute
-- is likely already present.
coroutine.wrap(function()
    while true do
        local s, e = xpcall(Time.updateRemoteTime, debug.traceback, Time)
        if not s then
            warn("KDKit.Time.updateRemoteTime failed with error:", e)
        end
        task.wait(Time.config.remoteFetchRate)
    end
end)()


return setmetatable(Time, {
    __call = Time.now,
    __iter = function(self)
        return next, self
    end,
})
