--[[
    A group of utility modules based around loading content.
]]
local Preload = {}

-- if there has not been any progress for this many seconds, warn
local WARNING_INTERVAL = 5

-- wait a certain number of seconds for an event to occur
-- returns nil if the event did not return in time
function Preload:waitForEvent(event, timeout)
    local timeoutAt = os.clock() + timeout
    local returnValue = nil

    local connection
    connection = event:Connect(function(...)
        if returnValue then
            return
        end

        returnValue = { ... }
        connection:Disconnect()
        connection = nil
    end)

    while not returnValue and os.clock() < timeoutAt do
        task.wait()
    end

    if returnValue then
        return table.unpack(returnValue)
    else
        connection:Disconnect()
        return nil
    end
end

-- Waits for an instance to have a certain number of children, which can be specified as the second
-- argument but is by default pulled from the `n` attribute on the instance.
function Preload:ensureChildren(instance, n)
    n = n or instance:GetAttribute("n")
    local ref = ("KDKit.Preload:ensureChildren(%s)"):format(instance:GetFullName())

    if not n then
        warn(("Attempted to %s without an `n` attribute. Skipping preload."):format(ref))
        return instance
    end

    while #instance:GetChildren() ~= n do
        if not self:waitForEvent(instance.ChildAdded, WARNING_INTERVAL) then
            warn(
                ("%s is waiting for %d children, but it looks like there are actually %d children."):format(
                    ref,
                    n,
                    #instance:GetChildren()
                )
            )
        end
    end

    return instance
end

-- identical to Preload:ensureDescendants, except it counts the descendants and uses the `N` attribute (uppercase!)
function Preload:ensureDescendants(instance, N)
    N = N or instance:GetAttribute("N")
    local ref = ("KDKit.Preload:ensureChildren(%s)"):format(instance:GetFullName())

    if not N then
        warn(("Attempted to %s without an `N` attribute. Skipping preload."):format(ref))
        return instance
    end

    while #instance:GetDescendants() ~= N do
        if not self:waitForEvent(instance.DescendantAdded, WARNING_INTERVAL) then
            warn(
                ("%s is waiting for %d descendants, but it looks like there are actually %d descendants."):format(
                    ref,
                    N,
                    #instance:GetDescendants()
                )
            )
        end
    end

    return instance
end

-- TODO: utilities for preloading content assets

return Preload
