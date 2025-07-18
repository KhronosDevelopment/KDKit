--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")

local Utils = require(script.Parent:WaitForChild("Utils"))
local KDRandom = require(script.Parent:WaitForChild("Random"))

local STORE
if game:GetService("RunService"):IsServer() then
    STORE = MemoryStoreService:GetHashMap("_KDKit.MemoryStoreMutex")
end

export type MemoryStoreMutexImpl = {
    __index: MemoryStoreMutexImpl,
    new: (string) -> MemoryStoreMutex,
    _tryWrite: (MemoryStoreMutex) -> (boolean, string?),
    _write: (MemoryStoreMutex, number) -> (),
    _tryClear: (MemoryStoreMutex) -> (boolean, string?),
    _clear: (MemoryStoreMutex, number) -> (),
    getTimeToExpiration: (MemoryStoreMutex) -> number,
    acquire: (MemoryStoreMutex, (number) -> ()) -> (),
    release: (MemoryStoreMutex) -> (),
}
export type MemoryStoreMutex = typeof(setmetatable(
    {} :: {
        name: string,
        uuid: string,
        acquiring: boolean?,
        acquired: { expiry: number }?,
        releasing: boolean?,
    },
    {} :: MemoryStoreMutexImpl
))

local MemoryStoreMutex = {} :: MemoryStoreMutexImpl
MemoryStoreMutex.__index = MemoryStoreMutex

function MemoryStoreMutex.new(name)
    local self = setmetatable({}, MemoryStoreMutex)

    self.name = name
    self.uuid = game.JobId .. KDRandom.uuid(16)
    self.acquiring = false
    self.acquired = nil
    self.releasing = false

    return self
end

function MemoryStoreMutex:_tryWrite()
    local persistedOwner
    local s, r = pcall(STORE.UpdateAsync, STORE, self.name, function(ownerUUID: string?): string?
        persistedOwner = ownerUUID
        if persistedOwner and persistedOwner ~= self.uuid then
            return nil
        end

        if self.releasing then
            return nil
        end

        return self.uuid
    end, 300)

    if not s then
        return false, "UpdateAsync threw an error: " .. r
    elseif r == self.uuid then
        self.acquired = {
            expiry = os.clock() + 300,
        }
        return true, nil
    elseif persistedOwner and persistedOwner ~= self.uuid then
        self.acquired = nil
        return false, "the lock was owned by someone else: " .. Utils.repr(persistedOwner)
    elseif self.releasing then
        return false, "the write was aborted (`release` was called)"
    else
        return false, "this should be impossible"
    end
end

function MemoryStoreMutex:_write(attempts)
    local timeout = 1
    for attempt = 1, attempts do
        local s, r = self:_tryWrite()
        if s then
            break
        end

        if self.releasing then
            error("The acquisition was aborted (`release` was called).")
        end

        if attempt == attempts then
            error("Ran out of attempts. Most recent error: " .. assert(r))
        end

        for second = 1, timeout do
            task.wait(1)
            if self.releasing then
                error("The acquisition was aborted (`release` was called).")
            end
        end
        timeout *= 2
    end
end

function MemoryStoreMutex:_tryClear()
    local s, r = pcall(STORE.UpdateAsync, STORE, self.name, function(ownerUUID: string?): string?
        if not ownerUUID then
            -- already cleared!
            return nil
        elseif ownerUUID ~= self.uuid then
            -- wrong owner... i guess that works too?
            warn(
                "[MemoryStoreMutex] While clearing the mutex "
                    .. Utils.repr(self.name)
                    .. " for "
                    .. Utils.repr(self.uuid)
                    .. ", it was found to be owned by someone else: "
                    .. Utils.repr(ownerUUID)
            )
            return nil
        end

        -- set the owner with an immediate expiration
        return self.uuid
    end, 0)

    if not s then
        return false, "UpdateAsync threw an error: " .. r
    else
        self.acquired = nil
        return true, nil
    end
end

function MemoryStoreMutex:_clear(attempts)
    assert(self.acquired and self.releasing and not self.acquiring)
    local eta = self.acquired.expiry - os.clock()
    if eta <= 10 then
        -- don't bother, it's expiring soon anyway
        return
    end

    local timeout = 1
    for attempt = 1, attempts do
        local s, r = self:_tryClear()
        if s then
            break
        end

        if attempt == attempts then
            error("Ran out of attempts. Most recent error: " .. assert(r))
        end

        local etaAfterTimeout = self.acquired.expiry - (os.clock() + timeout)
        if etaAfterTimeout <= 10 then
            -- don't bother, it will be expiring too soon anyway
            return
        end
        task.wait(timeout)
        timeout *= 2
    end
end

function MemoryStoreMutex:getTimeToExpiration()
    if not self.acquired then
        return -math.huge
    else
        return self.acquired.expiry - os.clock()
    end
end

function MemoryStoreMutex:acquire(cbOnReleasingPrematurely)
    if self.acquiring or self.acquired or self.releasing then
        error("Wait for the lock to be released before acquiring it again.")
    end

    self.acquiring = true
    Utils.ensure(function()
        self.acquiring = false
    end, self._write, self, 6) -- 6 tries takes >31 seconds

    if self.releasing then
        error("The acquisition succeeded, but in the meantime `release` was called.")
    end

    local me = assert(self.acquired)
    task.defer(function()
        while task.wait(30) and not self.releasing and self.acquired == me do
            assert(not self.acquiring)
            self.acquiring = true
            local r = Utils.try(self._write, self, 8)
            me = self.acquired
            self.acquiring = false

            if self.releasing then
                -- don't care if the write failed, we are releasing anyway
                return
            end

            r:catch(function(failed)
                local eta = if me then me.expiry - os.clock() else -1
                task.defer(cbOnReleasingPrematurely, eta)
                task.delay(eta, function()
                    if not self.releasing and self.acquired == me then
                        self.acquired = nil
                    end
                end)
            end):raise()

            assert(me)
        end
    end)
end

function MemoryStoreMutex:release()
    if self.releasing then
        error("This lock is already releasing.")
    end

    self.releasing = true

    while self.acquiring do
        task.wait()
    end

    if self.acquired then
        Utils
            .try(self._clear, self, 5) -- 5 tries takes >15 seconds
            :catch(function(e)
                warn(
                    "[MemoryStoreMutex] Failed to clear the mutex "
                        .. Utils.repr(self.name)
                        .. ". It will be expiring automatically in "
                        .. (self.acquired.expiry - os.clock())
                        .. " seconds. The error was: \n"
                        .. e
                )
            end)
        self.acquired = nil
    end

    self.releasing = false
end

return MemoryStoreMutex
