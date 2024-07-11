--!strict

--[[
    Heavily inspired by Nevermore's `Maid`, if that wasn't obvious.
    The API is pretty simple:
    ```lua
    local maid = Maid.new()
    maid:give(Instance.new("Part", workspace))
    maid:clean() -- destroys the part
    ```
--]]

local RunService = game:GetService("RunService")
local Utils = require(script.Parent:WaitForChild("Utils"))

type MaidImpl = {
    __index: MaidImpl,
    new: () -> Maid,
    isTaskValid: (any) -> boolean,
    has: (Maid, any) -> boolean,
    give: <T, A...>(Maid, T | (A...) -> T, A...) -> T | () -> T,
    remove: (Maid, any) -> (),
    removeAll: (Maid) -> (),
    clean: (Maid, any, boolean?) -> (),
    -- aliases of `clean`:
    destroy: (Maid, any, boolean?) -> (),
    disconnect: (Maid, any, boolean?) -> (),
    Destroy: (Maid, any, boolean?) -> (),
    Disconnect: (Maid, any, boolean?) -> (),
}
export type Maid = typeof(setmetatable(
    {} :: {
        tasks: { [any]: boolean },
        RBXScriptConnectionTasks: { [RBXScriptConnection]: boolean },
    },
    {} :: MaidImpl
))

local Maid: MaidImpl = {} :: MaidImpl
Maid.__index = Maid

function Maid.isTaskValid(task): boolean
    if typeof(task) == "Instance" or typeof(task) == "RBXScriptConnection" or Utils.callable(task) then
        return true
    elseif Utils.callable(Utils.getattr(task, "clean")) or Utils.callable(Utils.getattr(task, "Clean")) then
        return true
    elseif Utils.callable(Utils.getattr(task, "destroy")) or Utils.callable(Utils.getattr(task, "Destroy")) then
        return true
    elseif Utils.callable(Utils.getattr(task, "disconnect")) or Utils.callable(Utils.getattr(task, "Disconnect")) then
        return true
    end

    return false
end

function Maid.new()
    local self = setmetatable({ tasks = {}, RBXScriptConnectionTasks = {} }, Maid) :: Maid
    return self
end

function Maid:has(task)
    return not not (self.tasks[task] or self.RBXScriptConnectionTasks[task])
end

function Maid:give<T, A...>(task, ...)
    if typeof(task) == "RBXScriptConnection" then
        self.RBXScriptConnectionTasks[task] = true
        return task
    elseif type(task) == "function" then
        local args = { ... }
        local func = function()
            return task(table.unpack(args))
        end
        self.tasks[func] = true
        return func
    elseif Maid.isTaskValid(task) then
        self.tasks[task] = true
        return task
    end

    error(("[KDKit.Maid] Invalid task `%s`"):format(Utils.repr(task)))
end

function Maid:remove(task)
    self.tasks[task] = nil
    self.RBXScriptConnectionTasks[task] = nil
end

function Maid:removeAll()
    table.clear(self.tasks)
    table.clear(self.RBXScriptConnectionTasks)
end

function Maid:clean(task, skipDebugProfile)
    if not skipDebugProfile then
        debug.profilebegin("Maid:clean()")
    end

    if task == nil then
        for t in self.RBXScriptConnectionTasks do
            self:clean(t, true)
        end
        for t in self.tasks do
            self:clean(t, true)
        end
        if not skipDebugProfile then
            debug.profileend()
        end
        return
    end

    if not self:has(task) then
        if not skipDebugProfile then
            debug.profileend()
        end

        local msg = ("[KDKit.Maid] Never received or already cleaned the task `%s`. Doing nothing."):format(
            Utils.repr(task)
        )
        if RunService:IsStudio() then
            error(msg)
        else
            warn(msg)
        end

        return
    end
    self:remove(task)

    local s, r = Utils.try(function()
        if typeof(task) == "RBXScriptConnection" then
            return task:Disconnect()
        elseif typeof(task) == "Instance" then
            return task:Destroy()
        end

        return coroutine.wrap(function()
            if Utils.callable(Utils.getattr(task, "destroy")) then
                task:destroy()
            elseif Utils.callable(Utils.getattr(task, "clean")) then
                task:clean()
            elseif Utils.callable(Utils.getattr(task, "Disconnect")) then
                task:Disconnect()
            elseif Utils.callable(Utils.getattr(task, "disconnect")) then
                task:disconnect()
            elseif Utils.callable(Utils.getattr(task, "Destroy")) then
                task:Destroy()
            elseif Utils.callable(Utils.getattr(task, "Clean")) then
                task:Clean()
            elseif Utils.callable(task) then
                task()
            else
                error("[KDKit.Maid] Failed to resolve task cleaning method.")
            end
        end)()
    end):result()

    if not s then
        warn(("[KDKit.Maid] Failed to clean task `%s` due to callback error:\n%s"):format(Utils.repr(task), r))
    end

    if not skipDebugProfile then
        debug.profileend()
    end
    return nil
end
Maid.destroy = Maid.clean
Maid.disconnect = Maid.clean
Maid.Destroy = Maid.clean
Maid.Disconnect = Maid.clean

return Maid
