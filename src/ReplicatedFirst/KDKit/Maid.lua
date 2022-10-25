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

function Maid:kTaskIsValid(task)
    if Utils:callable(Utils:getattr(task, "Destroy")) then
        return true
    elseif Utils:callable(Utils:getattr(task, "Disconnect")) then
        return true
    elseif Utils:callable(task) then
        return true
    end

    return false
end

function Maid:__init()
    self.nextTaskIndex = 1
    self.tasks = table.create(8)
end

function Maid:give(task)
    local thisTaskIndex = self.nextTaskIndex

    if not Maid:kTaskIsValid(task) then
        error(("Invalid task `%s`"):format(Utils:repr(task)))
    end

    self.tasks[thisTaskIndex] = task

    self.nextTaskIndex += 1
    return thisTaskIndex
end

function Maid:clean(taskOrIndex)
    if taskOrIndex == nil then
        for index, task in self.tasks do
            self:clean(index)
        end
        return
    end

    local index = taskOrIndex
    local task = self.tasks[index]
    if not task then
        for potentialIndex, potentialTask in self.tasks do
            if potentialTask == taskOrIndex then
                index = potentialIndex
                task = potentialTask
                break
            end
        end

        if not task then
            warn(
                ("This Maid never received or already cleaned the task `%s`. Doing nothing."):format(
                    Utils:repr(taskOrIndex)
                )
            )
            return
        end
    end

    self.tasks[index] = nil

    if not Maid:kTaskIsValid(task) then
        warn(("Maid can no longer clean the task `%s`. Doing nothing."):format(Utils:repr(task)))
    else
        local taskRepr = Utils:repr(task) -- the task may be a mutable table, so want to cache this in case of error
        local s, r = xpcall(
            coroutine.wrap(function()
                if Utils:callable(Utils:getattr(task, "Destroy")) then
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
end
Maid.Destroy = Maid.clean
Maid.Disconnect = Maid.clean

return Maid
