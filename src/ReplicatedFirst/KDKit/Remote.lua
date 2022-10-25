local RunService = game:GetService("RunService")
local Class = require(script.Parent:WaitForChild("Class"))
local RateLimit = require(script.Parent:WaitForChild("RateLimit"))
local Utils = require(script.Parent:WaitForChild("Utils"))

local Remote = Class.new("KDKit.Remote")

if RunService:IsServer() then
    Remote.static.folder = Instance.new("Folder", game:GetService("ReplicatedStorage"))
    Remote.static.folder.Name = "KDKit.Remote.instances"
else
    coroutine.wrap(function()
        Remote.static.folder = game:GetService("ReplicatedStorage"):WaitForChild("KDKit.Remote.instances")
    end)()
end

function Remote.static:waitForFolder()
    while not Remote.folder do
        task.wait()
    end
    return Remote.folder
end

function Remote:__init(
    instance: RemoteEvent | RemoteFunction,
    rateLimit: "KDKit.RateLimit"?, -- only enforced for client -> server requests
    clientDropsCallsWhenLimitExceeded: boolean? -- set to true for requests that don't really matter & you don't want to see "rate limit exceeded" errors
)
    self.template = instance
    self.rateLimit = rateLimit
    self.functional = instance:IsA("RemoteFunction")
    self.clientDropsCallsWhenLimitExceeded = not not clientDropsCallsWhenLimitExceeded

    if self.clientDropsCallsWhenLimitExceeded and self.functional then
        error("You cannot set `clientDropsCallsWhenLimitExceeded = true` for RemoteFunctions. What would be returned?")
    end
    if self.clientDropsCallsWhenLimitExceeded and not self.rateLimit then
        error(
            "You cannot set `clientDropsCallsWhenLimitExceeded = true` without providing a rate limit. What does that even mean?"
        )
    end

    -- ReplicatedFirst doesn't exactly preserve instance references properly,
    -- so we will need to clone them into ReplicatedStorage, where they can be correctly resolved.
    if RunService:IsServer() then
        self.instance = self.template:Clone()
        self.instance.Parent = Remote:waitForFolder()
    else
        coroutine.wrap(function()
            self.instance = Remote:waitForFolder():WaitForChild(self.template.Name)
        end)()
    end
end

function Remote:waitForInstance()
    while not self.instance do
        task.wait()
    end
    return self.instance
end

function Remote:__call(...)
    if RunService:IsServer() then
        if self.functional then
            return self:waitForInstance():InvokeClient(...)
        else
            local args = { ... }
            local player = table.remove(args, 1)
            if player then
                return self:waitForInstance():FireClient(player, table.unpack(args))
            else
                return self:waitForInstance():FireAllClients(table.unpack(args))
            end
        end
    else
        if self.functional then
            return self:waitForInstance():InvokeServer(...)
        else
            if self.clientDropsCallsWhenLimitExceeded then
                if not self.rateLimit:isReady() then
                    return nil
                else
                    self.rateLimit:use()
                end
            end
            return self:waitForInstance():FireServer(...)
        end
    end
end

function Remote:__iter()
    return next, self
end

function Remote:connect(callback)
    if RunService:IsServer() then
        local function errorLoggedCallback(player, ...)
            local args = { ... }
            return Utils:ensure(function(failed, traceback)
                if failed then
                    Remote.onServerError(self, player, args, traceback)
                end
            end, callback, player, ...)
        end

        local function rateLimitedCallback(player, ...)
            if self.rateLimit then
                Utils:ensure(function(failed)
                    if failed then
                        Remote.rateLimitExceeded(player, self:waitForInstance())
                    end
                end, self.rateLimit.use, self.rateLimit, player.UserId)
            end
            return errorLoggedCallback(player, ...)
        end

        if self.functional then
            self:waitForInstance().OnServerInvoke = rateLimitedCallback
        else
            self:waitForInstance().OnServerEvent:Connect(rateLimitedCallback)
        end
    else
        if self.functional then
            self:waitForInstance().OnClientInvoke = callback
        else
            self:waitForInstance().OnClientEvent:Connect(callback)
        end
    end
end

function Remote:wait()
    if self.functional then
        error("Cannot :wait() on a RemoteFunction")
    end

    if RunService:IsServer() then
        return self:waitForInstance().OnServerEvent:Wait()
    else
        return self:waitForInstance().OnClientEvent:Wait()
    end
end

if RunService:IsServer() then
    Remote.rateLimitExceeded = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
    Remote.rateLimitExceeded.Name = "KDKit.Remote.rateLimitExceeded"
    Remote.rateLimitExceeded = Remote.new(Remote.rateLimitExceeded, RateLimit.new(0), true)

    Remote.logClientError = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
    Remote.logClientError.Name = "KDKit.Remote.logClientError"
    Remote.logClientError = Remote.new(Remote.logClientError, RateLimit.new(5, 300), true)

    Remote.onServerError = function(remote, player, args, traceback)
        -- override me! I get called after every server error!
    end
else
    Remote.rateLimitExceeded = Remote.new(
        game:GetService("ReplicatedStorage"):WaitForChild("KDKit.Remote.rateLimitExceeded"),
        RateLimit.new(0),
        true
    )
    Remote.logClientError = Remote.new(
        game:GetService("ReplicatedStorage"):WaitForChild("KDKit.Remote.logClientError"),
        RateLimit.new(5, 300),
        true
    )
end

function Remote:wrapWithClientErrorLogging(func, context, getState)
    if not RunService:IsClient() then
        error("`KDKit.Remote.wrapWithClientErrorLogging` is only available from the client.")
    end

    return function(...)
        local args = { ... }
        return Utils:ensure(function(failed, traceback)
            if failed then
                local successfullyGotState, state = pcall(getState or function()
                    return nil
                end)

                Remote.logClientError(
                    context,
                    if successfullyGotState then Utils:makeSerializable(state) else "Error getting state: " .. state,
                    Utils:makeSerializable(args),
                    traceback
                )
            end
        end, func, ...)
    end
end

return Remote
