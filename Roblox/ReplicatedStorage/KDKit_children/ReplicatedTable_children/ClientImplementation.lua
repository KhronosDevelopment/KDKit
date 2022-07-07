-- externals
local KDKit = require(script.Parent.Parent)
local Common = require(script.Parent.Common)
local root = script.Parent.root

-- utils
local function setWithIntifiedKey(t, key, value)
    if key:match("-?%d+") == key then
        key = tonumber(key)
    end

    t[key] = value
end

local function buildTableFromFolder(folder)
    local t = {}
    
    for key, value in pairs(folder:GetAttributes()) do
        key = Common:decodeReplicatableKeyName(key)
        setWithIntifiedKey(t, key, value)
    end

    for _, child in pairs(folder:GetChildren()) do
        local key = Common:decodeReplicatableKeyName(child.Name)
        setWithIntifiedKey(t, key, buildTableFromFolder(child))
    end
    
    return t
end

local stagedCallbacks = {}

-- class
local RT = KDKit.Class() -- intentionally have no name!

function RT:__new(parent, name)
    return parent and getmetatable(parent).children[name]
end

function RT:__init(parent, name)
    rawset(self, "__init", nil)
    rawset(self, "////%%%%_NOTE_%%%%////", "To retrieve this value, you need to __call the table.")

    local mt = getmetatable(self)

    if parent then
        local pmt = getmetatable(parent)
        pmt.children[name] = self
        mt.depth = pmt.depth + 1
    else
        mt.depth = 0
    end

    mt.name = name
    mt.parent = parent
    mt.children = {}
    mt.connections = {}

    mt.change = function(mt, down, up)
        for callback, _ in pairs(mt.connections) do
            stagedCallbacks[callback] = self
        end

        if down then
            for name, child in pairs(mt.children) do
                getmetatable(child):change(true, false)
            end
        end

        if up and mt.parent then
            getmetatable(mt.parent):change(false, true)
        end
    end
end

function RT:__index(name)
    return RT(self, Common:encodeReplicatableKeyName(name))
end

function RT:__newindex(name, value)
    error("clients only have read-access")
end

function RT:__call(callback)
    local mt = getmetatable(self)

    if not callback then
        local path = table.create(mt.depth, "")

        local pmt = mt
        for i = mt.depth, 1, -1 do
            path[i] = pmt.name
            pmt = pmt.parent and getmetatable(pmt.parent)
        end

        local f = root
        for i, dir in ipairs(path) do
            f = f:FindFirstChild(dir) or f:GetAttribute(dir)

            if typeof(f) ~= "Instance" then
                if i == mt.depth then
                    return f
                else
                    return nil
                end
            end
        end

        if typeof(f) == "Instance" then
            return buildTableFromFolder(f)
        else
            return f
        end
    else
        -- initial call
        stagedCallbacks[callback] = self

        mt.connections[callback] = true

        -- onChange
        return {
            Disconnect = function(self)
                if not self.Connected then
                    error("Attempted to :Disconnect() more than once.")
                else
                    self.Connected = false
                    mt.connections[callback] = nil
                end
            end,
            Connected = true,
            connection = callback
        }
    end
end

-- setup
local base = RT(nil, '')

local function track(from, folder)
    folder.AttributeChanged:Connect(function(name)
        name = Common:decodeReplicatableKeyName(name)
        getmetatable(from[name]):change(false, true)
    end)

    folder.ChildRemoved:Connect(function(childInstance)
        local name = Common:decodeReplicatableKeyName(childInstance.Name)
        getmetatable(from[name]):change(true, true)
    end)
    
    local function childAdded(childInstance)
        local name = Common:decodeReplicatableKeyName(childInstance.Name)
        local child = from[name]
        getmetatable(child):change(true, true)
        track(child, childInstance)
    end

    folder.ChildAdded:Connect(childAdded)
    for _, childInstance in pairs(folder:GetChildren()) do
        task.defer(childAdded, childInstance)
    end
end

track(base, root)

-- TODO: this should be RenderStepped,
-- but there appears to be some bugs with that
-- i.e. TextLabels do not actually get updated
game:GetService("RunService").Heartbeat:Connect(function()
    for callback, self in pairs(stagedCallbacks) do
        task.defer(callback, self())
    end
    stagedCallbacks = {}
end)

return base
