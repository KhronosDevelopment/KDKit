local RunService = game:GetService("RunService")

local clock = os.clock
local Time = {
    remote = {
        time = os.time(),
        at = clock(),
    },
    initialSyncComplete = false,
    adjustmentRate = script:GetAttribute("adjustmentRate"),
}

function Time:remoteSync(remoteTime, pingTime)
    self.remote = {
        time = remoteTime + pingTime / 2,
        at = clock()
    }
    self.initialSyncComplete = true
end

function Time:startRemoteSync()
    local startedAt = clock()
    return function(remoteTime)
        return self:remoteSync(remoteTime, clock() - startedAt)
    end
end

function Time:estimateRemoteTime()
    return Time.remote.time + clock() - Time.remote.at
end

function Time:waitForInitialSync()
    local warnAt = clock() + 5
    while not self.initialSyncComplete do
        task.wait()
        if clock() > warnAt then
            warn("Time:waitForInitialSync() is taking longer than expected.")
            warnAt += 2
        end
    end
end

local lastInvokedAt
local lastInvocationResult
function Time:now()
    self:waitForInitialSync()
    if not lastInvokedAt then
        lastInvokedAt = self.remote.at
        lastInvocationResult = self.remote.time
    end

    local now = clock()
    local timeSinceLastCall = now - lastInvokedAt

    local remoteTime = self:estimateRemoteTime()
    local localTime = lastInvocationResult + timeSinceLastCall

    local requiredAdjustment = remoteTime - localTime
    local maxAdjustment = timeSinceLastCall * self.adjustmentRate
    local useAdjustment = math.sign(requiredAdjustment) * math.min(math.abs(requiredAdjustment), maxAdjustment)
    lastInvocationResult = localTime + useAdjustment
    lastInvokedAt = now

    return lastInvocationResult
end

if RunService:IsServer() then
    task.defer(function()
        print('[KDKit.Time] Waiting for remote sync')
        Time:waitForInitialSync()
        print('[KDKit.Time] Ready - Beginning client periodic sync')
        RunService.Heartbeat:Connect(function()
            script:SetAttribute("replicatedTime", Time:now())
        end)
    end)
else
    local LocalPlayer = game.Players.LocalPlayer
    local function update()
        Time:remoteSync(
            script:GetAttribute("replicatedTime"),
            LocalPlayer:GetNetworkPing()
        )
    end
    if script:GetAttribute("replicatedTime") then update() end
    script:GetAttributeChangedSignal("replicatedTime"):Connect(update)

    print('[KDKit.Time] Waiting for remote sync')
    Time:waitForInitialSync()
    print('[KDKit.Time] Ready')
end

return setmetatable(Time, {__call = Time.now})
