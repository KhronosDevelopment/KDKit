local function waitForInstanceTree(t)
    for ancestor, children in pairs(t) do
        for k, v in pairs(children) do
            if typeof(v) == "table" then
                local new_ancestor = ancestor:WaitForChild(k)
                waitForInstanceTree({ [new_ancestor] = v })
            else
                ancestor:WaitForChild(tostring(v))
            end
        end        
    end
end

local function waitForDeps(inst)
    if inst:GetAttribute("lazy_require_deps") then
        waitForInstanceTree(
            require(inst:WaitForChild("lazy_require_deps"))
        )
    end 
end

local function ensureSynchronous(func, ...)
    local coro = coroutine.create(func)
    local _, returnValue = coroutine.resume(coro, ...)

    if coroutine.status(coro) == "dead" then
        -- the coroutine is completed, and it did not yield (good)
        return true, returnValue
    else
        -- uh oh.. it did yield (bad)
        return false, returnValue
    end
end

return function(parent, names, deferredNames, eagerNames)
    deferredNames = deferredNames or {}
    eagerNames = eagerNames or {}
    
    local T = {}
    local instances = {}
    
    local function rrequire(name, now)
        local status = instances[name]
        if status == "done" then
            -- no action required
        elseif status == "requiring" then
            error(("Tried to require `%s` again before the first require has finished."):format(parent[name]:GetFullName()))
        elseif status == "failed" then
            error(("Cannot require `%s` since it has already failed."):format(parent[name]:GetFullName()))
        else
            local instance = status
            instances[name] = "requiring"
            
            local s, r = pcall(function()
                if now then
                    local sync, module = ensureSynchronous(require, instance)
                    if not sync then
                        error("[Regarding module: " .. instance:GetFullName() .. "] You are not allowed to yield in a module which is lazily required or deferred. Solutions: 1. redesign the module such that it does not yield, 2. add it to the eagerly required modules, 3. do not use LazyRequire.")
                    end
                    return module
                else
                    return require(instance)
                end
            end)
            
            if not s then
                instances[name] = "failed"
                error(("Failed to require `%s` with error: %s"):format(instance:GetFullName(), r))
            else
                T[name] = r
                instances[name] = "done"
            end
        end
        
        return T[name]
    end
    
    -- wait for ModuleScripts
    for _, name in pairs(names) do
        instances[name] = parent:WaitForChild(name)
    end
    for _, name in pairs(deferredNames) do
        instances[name] = parent:WaitForChild(name)
    end
    for _, name in pairs(eagerNames) do
        instances[name] = parent:WaitForChild(name)
    end
    
    -- wait for their dependencies
    for name, inst in pairs(instances) do
        waitForDeps(inst)
    end
    
    -- wait for parent dependencies
    waitForDeps(parent)

    -- require deferred
    for _, name in pairs(deferredNames) do
        task.defer(rrequire, name, true)
    end

    -- require eagerly
    for _, name in pairs(eagerNames) do
        rrequire(name)
    end
    
    -- lazy evaluated table
    return setmetatable({}, {
        __index = function(self, name)
            if not instances[name] then return nil end
            return rrequire(name, true)
        end
    })
end
