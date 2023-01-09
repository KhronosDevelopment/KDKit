--[[
    Heavily inspired by Nevermore's `Maid`, if that wasn't obvious.
    The API is pretty simple:
    ```lua
    local maid = Maid.new()
    maid:give(Instance.new("Part", workspace))
    maid:clean() -- destroys the part
    ```
--]]

local Utils = require(script.Parent:WaitForChild("Utils"))
local Class = require(script.Parent:WaitForChild("Class"))
local Maid = Class.new("KDKit.Maid")
Maid.static.ERROR_ON_UNKNOWN_CLEANS = game:GetService("RunService"):IsStudio()

function Maid.static:isTaskValid(task): boolean
    if Utils:callable(Utils:getattr(task, "clean")) or Utils:callable(Utils:getattr(task, "Clean")) then
        return true
    elseif Utils:callable(Utils:getattr(task, "destroy")) or Utils:callable(Utils:getattr(task, "Destroy")) then
        return true
    elseif Utils:callable(Utils:getattr(task, "disconnect")) or Utils:callable(Utils:getattr(task, "Disconnect")) then
        return true
    elseif Utils:callable(task) then
        return true
    end

    return false
end

function Maid:__init()
    self.tasks = table.create(32)
end

function Maid:has(task): boolean
    return self.tasks[task]
end

function Maid:give<T, A>(task: (T | (...A) -> T), ...: A): (T | () -> T)
    if type(task) == "function" then
        local func: (...A) -> T = task
        local args = { ... }
        task = function()
            return func(table.unpack(args))
        end
    end

    if not Maid:isTaskValid(task) then
        error(("Invalid task `%s`"):format(Utils:repr(task)))
    end

    self.tasks[task] = true
    return task
end

function Maid:remove(task: any): nil
    self.tasks[task] = nil
end

function Maid:removeAll(): nil
    table.clear(self.tasks)
end

function Maid:clean(task, skipDebugProfile: boolean): nil
    if not skipDebugProfile then
        debug.profilebegin("Maid:clean()")
    end

    if task == nil then
        for task in self.tasks do
            self:clean(task, true)
        end
        if not skipDebugProfile then
            debug.profileend()
        end
        return nil
    end

    if not self:has(task) then
        if not skipDebugProfile then
            debug.profileend()
        end
        local func = if Maid.ERROR_ON_UNKNOWN_CLEANS then error else warn
        func(("This Maid never received or already cleaned the task `%s`. Doing nothing."):format(Utils:repr(task)))
        return nil
    end
    self.tasks[task] = nil

    local s, r
    if typeof(task) == "Instance" then
        s, r = pcall(task.Destroy, task)
    else
        s, r = xpcall(
            coroutine.wrap(function()
                if Utils:callable(Utils:getattr(task, "destroy")) then
                    task:destroy()
                elseif Utils:callable(Utils:getattr(task, "clean")) then
                    task:clean()
                elseif Utils:callable(Utils:getattr(task, "Disconnect")) then
                    task:Disconnect()
                elseif Utils:callable(Utils:getattr(task, "disconnect")) then
                    task:disconnect()
                elseif Utils:callable(Utils:getattr(task, "Destroy")) then
                    task:Destroy()
                elseif Utils:callable(Utils:getattr(task, "Clean")) then
                    task:Clean()
                elseif Utils:callable(task) then
                    task()
                else
                    error("Failed to resolve task cleaning method.")
                end
            end),
            debug.traceback
        )
    end

    if not s then
        warn(("Maid failed to clean task `%s` due to callback error:\n%s"):format(Utils:repr(task), r))
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
