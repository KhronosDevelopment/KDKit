--!strict

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

local Utils = require(script.Parent:WaitForChild("Utils"))

type MutexImpl = {
    __index: MutexImpl,
    new: (timeout: number?) -> Mutex,
    newOwner: (Mutex) -> number,
    wait: (Mutex) -> number,
    lock: <RL...>(Mutex, (<RU...>(() -> RU...) -> RU...) -> RL...) -> RL...,
    acquire: (Mutex) -> number,
    release: (Mutex, number) -> (),
    destroy: (Mutex) -> (),
}
export type Mutex = typeof(setmetatable(
    {} :: { timeout: number, locked: boolean, destroyed: boolean, owner: number },
    {} :: MutexImpl
))

local Mutex: MutexImpl = {} :: MutexImpl
Mutex.__index = Mutex

function Mutex.new(timeout)
    local self = setmetatable({
        timeout = timeout or 60,
        locked = false,
        destroyed = false,
        owner = 0,
    }, Mutex) :: Mutex
    return self
end

function Mutex:newOwner()
    if self.locked then
        error(("[KDKit.Mutex] Another owner (%d) already owns this lock."):format(self.owner))
    end

    self.locked = true
    self.owner += 1

    return self.owner
end

function Mutex:wait()
    if self.destroyed then
        error("[KDKit.Mutex] The mutex has been destroyed.")
    end

    local start = os.clock()
    local warned = false
    while self.locked and os.clock() - start < self.timeout do
        task.wait()
        if self.destroyed then
            error("[KDKit.Mutex] The mutex has been destroyed.")
        end
        if not warned and os.clock() - start > self.timeout / 2 then
            warn(
                ("[KDKit.Mutex] A lock has been waiting to be released for %.1f seconds. Potential deadlock detected. An error will be thrown if not resolved by %.1f seconds. If this is an okay delay, raise your mutex's timeout threshold.\n%s"):format(
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
            ("[KDKit.Mutex] Timed out after %.1f seconds. Probable deadlock, otherwise, raise your mutex's timeout threshold."):format(
                self.timeout
            )
        )
    end

    return os.clock() - start
end

function Mutex:lock<RL...>(fnToExecuteWithLock)
    self:wait()
    local me = self:newOwner()

    local function unlock<RU...>(fnToExecuteWithoutLock: () -> RU...): RU...
        if me ~= self.owner or not self.locked then
            error(
                "[KDKit.Mutex] This unlocker is not available because the mutex has been released and/or re-acquired."
            )
        end

        self.locked = false

        local function runWithoutYielding(): RU...
            local returnValue, returnTraceback
            local function wrapped()
                Utils.try(fnToExecuteWithoutLock)
                    :proceed(function(...)
                        returnValue = { ... }
                    end)
                    :catch(function(traceback)
                        returnTraceback = traceback
                    end)
            end

            local co = coroutine.create(wrapped)
            coroutine.resume(co)

            if returnValue then
                return table.unpack(returnValue :: any)
            elseif returnTraceback then
                error(returnTraceback)
            elseif not self.locked and self.owner == me then
                error("[KDKit.Mutex] You may not unlock a function which yields before acquiring the mutex lock.")
            end

            while coroutine.status(co) ~= "dead" do
                task.wait()
            end

            if returnValue then
                return table.unpack(returnValue :: any)
            elseif returnTraceback then
                error(returnTraceback)
            end

            assert(false)
        end

        return Utils.ensure(function()
            me = self:newOwner()
        end, runWithoutYielding)
    end

    return Utils.ensure(function()
        self.locked = false
    end, fnToExecuteWithLock, unlock)
end

function Mutex:acquire()
    self:wait()
    return self:newOwner()
end

function Mutex:release(owner)
    assert(self.owner == owner, "You may not release a mutex lock you do not own.")
    self.locked = false
end

function Mutex:destroy()
    self.destroyed = true
end

return Mutex
