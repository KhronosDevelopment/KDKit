local RunService = game:GetService("RunService")

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Common = require(script.Parent:WaitForChild("Common"))
local root = game.ReplicatedStorage:WaitForChild("KDKit.ReplicatedTable.Root")

local ReplicatedTable = {}

ReplicatedTable.CALLBACK_COUNT = table.create(128) -- only used to prevent garbage collection of RTs that have at least one connection

local function nonCyclicDeepClone(src)
    local dst = table.clone(src)

    for key, value in dst do
        if type(value) == "table" then
            dst[key] = nonCyclicDeepClone(value)
        end
    end

    return dst
end

local instanceTableCache = table.create(256)
local function buildTableFromInstance(instance, noCache)
    if instanceTableCache[instance] then
        return nonCyclicDeepClone(instanceTableCache[instance])
    end

    local output = table.create(16)

    for key, value in instance:GetAttributes() do
        output[Common:decodeKey(key)] = value
    end

    for _, child in instance:GetChildren() do
        output[Common:decodeKey(child.Name)] = buildTableFromInstance(child, true)
    end

    if not noCache then
        instanceTableCache[instance] = nonCyclicDeepClone(output)
    end
    return output
end

function ReplicatedTable.new(parent, path)
    local self = parent and rawget(parent, "!!! PRIVATE INTERNAL STORAGE !!!").children[path]

    if self then
        return self
    else
        self = setmetatable({}, ReplicatedTable)
    end

    ReplicatedTable.__init(self, parent, path)
    return self
end

function ReplicatedTable:__init(parent, path)
    -- attempt to save someone from thinking they've gone crazy while debugging
    rawset(
        self,
        "!!! Attention !!!",
        "This is a `KDKit.ReplicatedTable`. In order to see its contents, you must *call* the table which will fetch the current state."
    )

    rawset(self, "!!! PRIVATE INTERNAL STORAGE !!!", {
        parent = parent,
        path = path,
        children = setmetatable(table.create(16), { __mode = "v" }),
        callbacks = table.create(16),
    })

    if parent then
        rawget(parent, "!!! PRIVATE INTERNAL STORAGE !!!").children[path] = self
    end
end

function ReplicatedTable:__index(name)
    return ReplicatedTable.new(self, name)
end

function ReplicatedTable:__newindex(name, value)
    error(("ReplicatedTables are readonly from the client. Attempted to set key `%s`."):format(Utils:repr(name)))
end

function ReplicatedTable:__call(callback, skipInitialCall)
    local storage = rawget(self, "!!! PRIVATE INTERNAL STORAGE !!!")
    local parentStorage = storage.parent and rawget(storage.parent, "!!! PRIVATE INTERNAL STORAGE !!!")

    local currentState = (storage.instance and buildTableFromInstance(storage.instance))
        or (
            parentStorage
            and parentStorage.instance
            and parentStorage.instance:GetAttribute(Common:encodeKey(storage.path))
        )

    if callback and not skipInitialCall then
        task.defer(callback, currentState)
    end

    if callback then
        if storage.callbacks[callback] then
            error(
                "You cannot connect the same function to the same replicated table twice. You'll need to disconnect your first connection first."
            )
        end

        local disconnected = false
        storage.callbacks[callback] = true

        ReplicatedTable.CALLBACK_COUNT[self] = (ReplicatedTable.CALLBACK_COUNT[self] or 0) + 1

        return {
            disconnect = function(self)
                if disconnected then
                    error("Already disconnected!")
                end

                disconnected = true
                storage.callbacks[callback] = nil

                ReplicatedTable.CALLBACK_COUNT[self] = if ReplicatedTable.CALLBACK_COUNT[self] == 1
                    then nil
                    else ReplicatedTable.CALLBACK_COUNT[self] - 1
            end,
        }
    else
        return currentState
    end
end

function ReplicatedTable:__iter()
    local v = self()
    return next, if type(v) == "table" then v else {}
end

local pendingChangedRtCallbacks = table.create(256)
local function onChanged_noRecurse(rt)
    local storage = rawget(rt, "!!! PRIVATE INTERNAL STORAGE !!!")
    pendingChangedRtCallbacks[rt] = storage.callbacks
end

local function onChanged_recurse(rt)
    if pendingChangedRtCallbacks[rt] then
        return
    end

    local storage = rawget(rt, "!!! PRIVATE INTERNAL STORAGE !!!")
    pendingChangedRtCallbacks[rt] = storage.callbacks

    if storage.parent then
        onChanged_recurse(storage.parent)
    end
end

local function onInstanceRemoved(instance, rt)
    table.clear(instanceTableCache)

    local storage = rawget(rt, "!!! PRIVATE INTERNAL STORAGE !!!")
    storage.instance = nil

    storage.onChildAdded:Disconnect()
    storage.onChildAdded = nil

    storage.onChildRemoved:Disconnect()
    storage.onChildRemoved = nil

    storage.onAttributeChanged:Disconnect()
    storage.onAttributeChanged = nil

    onChanged_recurse(rt)
    for attribute in instance:GetAttributes() do
        onChanged_noRecurse(rt[Common:decodeKey(attribute)])
    end
end

local function onInstanceAdded(instance, rt)
    table.clear(instanceTableCache)

    local storage = rawget(rt, "!!! PRIVATE INTERNAL STORAGE !!!")
    if storage.instance then
        if storage.instance == instance then
            return rt
        else
            onInstanceRemoved(storage.instance, rt)
        end
    end
    storage.instance = instance

    storage.onChildAdded = instance.ChildAdded:Connect(function(child)
        onInstanceAdded(child, rt[Common:decodeKey(child.Name)])
    end)
    for _, child in instance:GetChildren() do
        onInstanceAdded(child, rt[Common:decodeKey(child.Name)])
    end

    storage.onAttributeChanged = instance.AttributeChanged:Connect(function(attribute)
        table.clear(instanceTableCache)
        onChanged_recurse(rt[Common:decodeKey(attribute)])
    end)
    for attribute in instance:GetAttributes() do
        onChanged_noRecurse(rt[Common:decodeKey(attribute)])
    end
    onChanged_recurse(rt)

    storage.onChildRemoved = instance.ChildRemoved:Connect(function(child)
        onInstanceRemoved(child, rt[Common:decodeKey(child.Name)])
    end)

    return rt
end

RunService.Heartbeat:Connect(function()
    for rt, callbacks in pendingChangedRtCallbacks do
        for callback in callbacks do
            task.defer(callback, rt())
        end
    end
    table.clear(pendingChangedRtCallbacks)
end)

return onInstanceAdded(root, ReplicatedTable.new(nil, nil))
