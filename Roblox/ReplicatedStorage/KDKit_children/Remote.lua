-- externals 
local KDKit = require(script.Parent)
local RunService = game:GetService("RunService")
local ErrorHider = require(script.ErrorHider)
local IS_SERVER = RunService:IsServer()
local IS_STUDIO = false--RunService:IsStudio()

-- class
local Remote = KDKit.Class("Remote")

-- utils
local requestPools = {}
local function rateLimit(remote, by, mustBeReadyNow, sender)
    local pool_key = remote.instance:GetAttribute('rate_limit_pool') or remote.instance
    local rate = remote.instance:GetAttribute('rate_limit') or (if remote.isRemote then 60 else math.huge)
    
    local pool = requestPools[pool_key] or {}
    requestPools[pool_key] = pool
    
    local playerPool = pool[by] or { history = 0, queue = 0 }
    pool[by] = playerPool
    
    local enqueuedAt = os.clock()
    playerPool.queue += 1
    while playerPool.history >= rate do
        if mustBeReadyNow then
            -- metamethods don't directly defer properly
            task.defer(function()
                local key = pool_key
                if typeof(key) == "Instance" then
                    key = key:GetFullName()
                end

                if typeof(sender) == "Instance" and sender:IsA("Player") then
                    Remote.rateLimitExceeded(sender, key, remote.instance)
                else
                    Remote.rateLimitExceeded(key, remote.instance)
                end
            end)

            playerPool.queue -= 1
            error('Rate limit exceeded.')
        end
        task.wait()
    end
    playerPool.queue -= 1
    playerPool.history += 1
    
    task.delay(60, function()
        playerPool.history -= 1
        
        if playerPool.history == 0 and playerPool.queue == 0 then
            pool[by] = nil
        end
    end)
    
    return os.clock() - enqueuedAt
end

local function hideErrorTraceback(f)
    return function(...)
        local args = {...}
        local results = table.pack(xpcall(function() return f(table.unpack(args)) end, debug.traceback))
        
        if results[1] == false then
            -- this will raise the real error in the debug console
            task.defer(error, results[2])
            
            -- this is the error that the client will see
            -- wrapping it in an anonymous function makes 
            ;(function() error("Something went wrong!") end)()
        else
            table.remove(results, 1)
            return table.unpack(results)
        end
    end
end

local function RLWrapper(remote, f)
    if not remote.isEvent and IS_SERVER and not IS_STUDIO then
        -- for some reason, roblox reports raw error tracebacks
        -- to clients. This is obviously bad since it reveals
        -- information about the back-end structure.
        f = ErrorHider(f)
    end
    
    if IS_SERVER and remote.isRemote then
        -- rate limit by player
        return function(plr, ...)
            rateLimit(remote, plr.UserId, true, plr)
            return f(plr, ...)
        end
    else
        -- rate limit by remote
        return function(...)
            rateLimit(remote, remote, true, nil)
            return f(...)
        end
    end
end

-- implementation
function Remote:__init(instance)
    if typeof(instance) ~= "Instance" or not ({RemoteEvent = 1, RemoteFunction = 1, BindableEvent = 1, BindableFunction = 1})[instance.ClassName] then
        error("You must provide a Remote/BindableEvent or a Remote/BindableFunction to create a Remote object.")
    end
    
    self.instance = instance
    self.isRemote = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")
    self.isEvent = instance:IsA("RemoteEvent") or instance:IsA("BindableEvent")
end

if IS_SERVER then
    function Remote:__call(...)
        if self.isRemote then
            local args = { ... }
            if #args == 0 then
                args = { nil }
            end
            
            local toPlayer = table.remove(args, 1)
            if self.isEvent then
                if toPlayer == nil then
                    return self.instance:FireAllClients(table.unpack(args))
                else
                    return self.instance:FireClient(toPlayer, table.unpack(args))
                end
            else
                return self.instance:InvokeClient(table.unpack(args))
            end
        else
            if self.isEvent then
                return self.instance:Fire(...)
            else
                return self.instance:Invoke(...)
            end
        end
    end
    
    function Remote:Connect(callback)
        callback = RLWrapper(self, callback)
        
        if self.isEvent then
            if self.isRemote then
                return self.instance.OnServerEvent:Connect(callback)
            else
                return self.instance.Event:Connect(callback)
            end
        else
            error("Please use Remote:OnInvoke(callback) for Remote/BindableFunctions")
        end
    end
    
    function Remote:OnInvoke(callback)
        callback = RLWrapper(self, callback)
        
        if not self.isEvent then
            if self._invoke_callback then
                warn("You just overwrote the OnServerInvoke callback for Remote/BindableFunction " .. self.instance:GetFullName())
            end
            
            if self.isRemote then
                self.instance.OnServerInvoke = callback
            else
                self.instance.OnInvoke = callback
            end

            self._invoke_callback = callback
        else
            error("Please use Remote:Connect(callback) for Remote/BindableEvents")
        end
    end
    
    function Remote:Wait()
        if self.isEvent then
            if self.isRemote then
                return self.instance.OnServerEvent:Wait()
            else
                return self.instance.Event:Wait()
            end
        else
            error("Cannot :Wait() on Remote/BindableFunctions")
        end
    end
    
else
    
    function Remote:__call(...)
        if self.isRemote then
            if self.isEvent then
                return self.instance:FireServer(...)
            else
                return self.instance:InvokeServer(...)
            end
        else
            if self.isEvent then
                return self.instance:Fire(...)
            else
                return self.instance:Invoke(...)
            end
        end
    end

    function Remote:Connect(callback)
        callback = RLWrapper(self, callback)

        if self.isEvent then
            if self.isRemote then
                return self.instance.OnClientEvent:Connect(callback)
            else
                return self.instance.Event:Connect(callback)
            end
        else
            error("Please use Remote:OnInvoke(callback) for Remote/BindableFunctions")
        end
    end

    function Remote:OnInvoke(callback)
        callback = RLWrapper(self, callback)

        if not self.isEvent then
            if self._invoke_callback then
                warn("You just overwrote the OnServerInvoke callback for Remote/BindableFunction " .. self.instance:GetFullName())
            end

            if self.isRemote then
                self.instance.OnClientInvoke = callback
            else
                self.instance.OnInvoke = callback
            end

            self._invoke_callback = callback
        else
            error("Please use Remote:Connect(callback) for Remote/BindableEvents")
        end
    end

    function Remote:Wait()
        if self.isEvent then
            if self.isRemote then
                return self.instance.OnClientEvent:Wait()
            else
                return self.instance.Event:Wait()
            end
        else
            error("Cannot :Wait() on Remote/BindableFunctions")
        end
    end
end

Remote.rateLimitExceeded = Remote(script.rateLimitExceeded)

return Remote
