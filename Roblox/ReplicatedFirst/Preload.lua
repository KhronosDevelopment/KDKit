-- externals

-- class
local Preload = {}

-- utils
local function waitForEvent(event, timeout)
    timeout = timeout or math.huge

    local conn, result
    conn = event:Connect(function(...)
        if not conn.Connected then
            return
        end
        conn:Disconnect()
        
        result = {...}
    end)

    local startedWaitingAt = os.clock()
    while conn.Connected and os.clock() - startedWaitingAt < timeout do
        task.wait()
    end
    
    local fired = true
    if conn.Connected then
        fired = false
        conn:Disconnect()
    end

    return fired, table.unpack(result or {})
end

-- implementation
function Preload:ensureChildren(instance, exact)
    local n = instance:GetAttribute("n")
    if not n then
        warn(("You used Preload:ensureChildren on an instance which didn't have an `n` attribute. Nothing will be loaded. Regarding: %s"):format(instance:GetFullName()))
        return
    end
    
    while true do
        local found = false
        local children = #instance:GetChildren()
        if exact then
            found = children == n
        else
            found = children >= n
        end
        
        if found then
            break
        end

        -- wait for another child to be added
        while not waitForEvent(instance.ChildAdded, 3) do
            local fmt = "Preload:ensureChildren is looking for %d children under %s, but it looks like there are %d."
            warn(fmt:format(n, instance:GetFullName(), children))
        end
    end
    
    return #instance:GetChildren()
end

function Preload:ensureDescendants(instance, allowOverage)
    local N = instance:GetAttribute("N")
    if not N then
        warn(("You used Preload:ensureDescendants on an instance which didn't have an `N` attribute. Nothing will be loaded. Regarding: %s"):format(instance:GetFullName()))
        return
    end

    while true do
        local found = false
        local descendants = #instance:GetDescendants()
        if allowOverage then
            found = descendants >= N
        else
            found = descendants == N
        end

        if found then
            break
        end
        
        -- wait for another descendant to be added
        while not waitForEvent(instance.DescendantAdded, 3) do
            local fmt = "Preload:ensureDescendants is looking for %d descendants under %s, but it looks like there are %d."
            warn(fmt:format(N, instance:GetFullName(), descendants))
        end
    end

    return #instance:GetDescendants()
end

function Preload:setDescendants(instance)
    instance:SetAttribute("N", #instance:GetDescendants())
end

function Preload:setChildren(instance)
    instance:SetAttribute("n", #instance:GetChildren())
end

function Preload:setNs(instance)
    self:setDescendants(instance)
    self:setChildren(instance)
end

return Preload
