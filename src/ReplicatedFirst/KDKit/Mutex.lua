--[[
    Pretty standard mutex lock implementation, with a timeout parameter.

    ```lua
    local mtx = Mutex.new(3) -- 3 second timeout

    task.defer(function()
        mtx:lock(function()
            print("E")
        end)
    end)

    mtx:lock(function(unlock)
        print("A")
        task.wait(5)
        print("B")
        unlock(function()
            mtx:lock(function()
                print("C")
            end)
        end)
        print("D")
    end)
    ```

    output:
    > A
    (3 seconds later)
    > error: mutex lock timed out
    (2 seconds later)
    > B
    > C
    > D
--]]

local Class = require(script.Parent:WaitForChild("Class"))
local Utils = require(script.Parent:WaitForChild("Utils"))

local Mutex = Class.new("KDKit.Mutex")

function Mutex:__init(timeout)
    self.timeout = timeout or 60
    self.locked = false
    self.destroyed = false
    self.owner = 0
end

function Mutex:newOwner()
    if self.locked then
        error(("Another owner (%d) already owns this lock."):format(self.owner))
    end

    self.locked = true
    self.owner += 1

    return self.owner
end

function Mutex:wait()
    if self.destroyed then
        error("The mutex has been destroyed.")
    end

    local start = os.clock()
    local warned = false
    while self.locked and os.clock() - start < self.timeout do
        task.wait()
        if self.destroyed then
            error("The mutex has been destroyed.")
        end
        if not warned and os.clock() - start > self.timeout / 2 then
            warn(
                ("A mutex lock has been waiting to be released for %.1f seconds. Potential deadlock detected. An error will be thrown if not resolved by %.1f seconds. If this is an okay delay, raise your mutex's timeout threshold.\n%s"):format(
                    os.clock() - start,
                    self.timeout,
                    debug.traceback()
                )
            )
            warned = true
        end
    end

    if self.locked then
        error(
            ("Mutex timed out after %.1f seconds. Probable deadlock, otherwise, raise your mutex's timeout threshold."):format(
                self.timeout
            )
        )
    end

    return os.clock() - start
end

function Mutex:lock(fnToExecuteWithLock)
    self:wait()
    local me = self:newOwner()

    local function unlock(fnToExecuteWithoutLock)
        if me ~= self.owner or not self.locked then
            error("This unlocker is not available because the mutex has been released and/or re-acquired.")
        end

        self.locked = false
        Utils:ensure(function()
            me = self:newOwner()
        end, self.lock, self, fnToExecuteWithoutLock)
    end

    return Utils:ensure(function()
        self.locked = false
    end, fnToExecuteWithLock, unlock)
end

function Mutex:destroy()
    self.destroyed = true
end

function Mutex:wrap(func)
    return function(...)
        local args = { ... }
        return self:lock(function()
            return func(table.unpack(args))
        end)
    end
end

return Mutex
