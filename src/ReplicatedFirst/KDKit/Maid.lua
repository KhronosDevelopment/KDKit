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

function Maid.static:isTaskValid(task)
    if Utils:callable(Utils:getattr(task, "clean")) then
        return true
    elseif Utils:callable(Utils:getattr(task, "Destroy")) then
        return true
    elseif Utils:callable(Utils:getattr(task, "Disconnect")) then
        return true
    elseif Utils:callable(task) then
        return true
    end

    return false
end

function Maid:__init()
    self.tasks = table.create(32)
end

function Maid:give(task)
    if not Maid:isTaskValid(task) then
        error(("Invalid task `%s`"):format(Utils:repr(task)))
    end

    self.tasks[task] = true
    return task
end

function Maid:clean(task)
    if task == nil then
        for task in self.tasks do
            self:clean(task)
        end
        return
    end

    if not self.tasks[task] then
        warn(("This Maid never received or already cleaned the task `%s`. Doing nothing."):format(Utils:repr(task)))
        return
    end
    self.tasks[task] = nil

    local taskRepr = Utils:repr(task) -- the task may be a mutable table, so want to cache this in case of error
    local s, r = xpcall(
        coroutine.wrap(function()
            if Utils:callable(Utils:getattr(task, "clean")) then
                task:clean()
            elseif Utils:callable(Utils:getattr(task, "Destroy")) then
                task:Destroy()
            elseif Utils:callable(Utils:getattr(task, "Disconnect")) then
                task:Disconnect()
            elseif Utils:callable(task) then
                task()
            else
                error("Failed to resolve task cleaning method.")
            end
        end),
        debug.traceback
    )

    if not s then
        warn(("Maid failed to clean task `%s` due to callback error:\n%s"):format(taskRepr, r))
    end
end
Maid.Destroy = Maid.clean
Maid.Disconnect = Maid.clean

return Maid
