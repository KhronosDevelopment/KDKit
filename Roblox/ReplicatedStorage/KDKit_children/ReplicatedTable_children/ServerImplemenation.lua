local t = {}
local Common = require(script.Parent.Common)
local root = script.Parent.root

local function buildFolderFromTable(tab, name, parent)
    local folder = Instance.new("Folder")
    
    for key, value in pairs(tab) do
        key = Common:encodeReplicatableKeyName(key)
        
        if type(value) == "table" then
            local sub = buildFolderFromTable(value, key, folder)
        else
            folder:SetAttribute(key, value)
        end
    end
    
    folder.Name = name or "unnamed"
    folder.Parent = parent
    
    return folder
end

local function diff(folder, tab)
    -- remove things that aren't supposed to exist
    local allowedKeys = {}
    for key, value in pairs(tab) do
        allowedKeys[Common:encodeReplicatableKeyName(key)] = true
    end
    for name, _ in pairs(folder:GetAttributes()) do
        if not allowedKeys[name] then
            folder:SetAttribute(name, nil)
        end
    end
    for _, child in pairs(folder:GetChildren()) do
        if not allowedKeys[child.Name] then
            child:Destroy()
        end
    end
    
    -- add things that should exist
    -- change things that are wrong
    for name, value in pairs(tab) do
        name = Common:encodeReplicatableKeyName(name)
        
        local attr = folder:GetAttribute(name)
        local child = attr == nil and folder:FindFirstChild(name)

        if type(value) == "table" then
            if attr ~= nil then
                folder:SetAttribute(name, nil)
            end
            
            if not child then
                local x = buildFolderFromTable(value, name, folder)
            else
                diff(child, value)
            end
        else
            if child then
                child:Destroy()
            end
            
            if attr ~= value then
                folder:SetAttribute(name, value)
            end
        end
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    diff(root, t)
end)

return t
