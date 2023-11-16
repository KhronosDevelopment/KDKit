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
    instance: RemoteEvent | RemoteFunction | BindableEvent | BindableFunction,
    rateLimit: "KDKit.RateLimit"?, -- only enforced for client -> server requests
    clientDropsCallsWhenLimitExceeded: boolean?, -- set to true for requests that don't really matter & you don't want to see "rate limit exceeded" errors
    nonconcurrent: boolean?
)
    self.template = instance
    self.rateLimit = rateLimit
    self.name = instance:GetFullName()
    self.functional = instance:IsA("RemoteFunction") or instance:IsA("BindableFunction")
    self.bindable = instance:IsA("BindableEvent") or instance:IsA("BindableFunction")
    self.clientDropsCallsWhenLimitExceeded = not not clientDropsCallsWhenLimitExceeded
    self.nonconcurrent = not not nonconcurrent

    if self.clientDropsCallsWhenLimitExceeded and self.functional then
        error(
            "You cannot set `clientDropsCallsWhenLimitExceeded = true` for functional remotes. What would be returned?"
        )
    end
    if self.clientDropsCallsWhenLimitExceeded and not self.rateLimit then
        error(
            "You cannot set `clientDropsCallsWhenLimitExceeded = true` without providing a rate limit. What does that even mean?"
        )
    end

    -- ReplicatedFirst doesn't exactly preserve instance references properly,
    -- so we will need to clone them into ReplicatedStorage, where they can be correctly resolved.
    if RunService:IsServer() then
        self.activeCallers = {} :: { [Player]: boolean }
        self.instance = self.template:Clone()
        self.instance.Parent = Remote:waitForFolder()
    else
        coroutine.wrap(function()
            self.instance = Remote:waitForFolder():WaitForChild(self.template.Name)
        end)()
    end
end

function Remote:waitForInstance(): RemoteEvent | RemoteFunction | BindableEvent | BindableFunction
    while not self.instance do
        task.wait()
    end
    return self.instance
end

function Remote:__call(...)
    if self.bindable then
        if self.functional then
            return (self:waitForInstance() :: BindableFunction):Invoke(...)
        else
            (self:waitForInstance() :: BindableEvent):Fire(...)
            return
        end
    end

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

function Remote:connect(callback): RBXScriptConnection?
    if self.bindable then
        return (self:waitForInstance() :: BindableEvent).Event:Connect(callback)
    end

    if RunService:IsServer() then
        local function errorLoggedCallback(player, ...)
            local args = { ... }
            return Utils:ensure(function(failed, traceback)
                if failed then
                    Remote.logServerError(self, player, args, traceback)
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

        local function concurrencyHandledCallback(player, ...)
            if self.nonconcurrent then
                if self.activeCallers[player] then
                    Remote.rateLimitExceeded(player, self:waitForInstance())
                    error("Concurrent call to nonconcurrent Remote.")
                end
            end

            self.activeCallers[player] = true
            return Utils:ensure(function()
                self.activeCallers[player] = nil
            end, rateLimitedCallback, player, ...)
        end

        if self.functional then
            self:waitForInstance().OnServerInvoke = concurrencyHandledCallback
        else
            return self:waitForInstance().OnServerEvent:Connect(concurrencyHandledCallback)
        end
    else
        if self.functional then
            self:waitForInstance().OnClientInvoke = callback
        else
            return self:waitForInstance().OnClientEvent:Connect(callback)
        end
    end
end

function Remote:wait()
    if self.functional then
        error("Cannot :wait() on a functional remote")
    end

    if self.bindable then
        return (self:waitForInstance() :: BindableEvent).Event:Wait()
    end

    if RunService:IsServer() then
        return self:waitForInstance().OnServerEvent:Wait()
    else
        return self:waitForInstance().OnClientEvent:Wait()
    end
end

if RunService:IsServer() then
    Remote.static.rateLimitExceeded = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
    Remote.static.rateLimitExceeded.Name = "KDKit.Remote.rateLimitExceeded"
    Remote.static.rateLimitExceeded = Remote.new(Remote.static.rateLimitExceeded, RateLimit.new(0), true)

    Remote.static.logClientError = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
    Remote.static.logClientError.Name = "KDKit.Remote.logClientError"
    Remote.static.logClientError = Remote.new(Remote.static.logClientError, RateLimit.new(5, 300), true)

    function Remote:logServerError(player: Player, dirtyArgs: table, traceback: string)
        warn(
            "A server-sided error occurred an a KDKit.Remote and wasn't logged. "
                .. "Consider overwriting `function Remote:logServerError`"
        )
        -- Seriously! overwrite this function. For example:
        --[[
            ```lua
            function KDKit.Remote:logServerError(player: Player, dirtyArgs: table, traceback: string)
                (KDKit.API.log / "error"):dpePOST(player, {
                    title = "Unhandled Server Remote Exception",
                    description = traceback,
                    fields = {
                        remote = self.name,
                        args = KDKit.Utils:repr(dirtyArgs):sub(1, 16384),
                    },
                })
            end
            ```
        --]]
    end
else
    Remote.static.rateLimitExceeded = Remote.new(
        game:GetService("ReplicatedStorage"):WaitForChild("KDKit.Remote.rateLimitExceeded"),
        RateLimit.new(0),
        true
    )

    Remote.static.logClientError = Remote.new(
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
                    if successfullyGotState then Utils:repr(state, 3) else "Error getting state: " .. state,
                    Utils:repr(args, 3),
                    traceback
                )
            end
        end, func, ...)
    end
end

return Remote
