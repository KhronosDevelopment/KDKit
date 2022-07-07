local Common = require(script.Parent:WaitForChild("Common"))

local ReplicatedTable = {}

local root = Instance.new("Folder")
root.Name = "KDKit.ReplicatedTable.Root"
root.Parent = game.ReplicatedStorage

local childFolder, encodedKey -- in an attempt to optimize, extract eligible locals
local function updateFolderToReflectTable(folder, tab)
    local namesToDelete = folder:GetAttributes()
    for _, child in folder:GetChildren() do
        namesToDelete[child.Name] = true
    end

    for key, value in tab do
        encodedKey = Common:encodeKey(key)
        namesToDelete[encodedKey] = nil

        childFolder = folder:FindFirstChild(encodedKey)

        if type(value) == "table" then
            folder:SetAttribute(encodedKey, nil)

            if not childFolder then
                childFolder = Instance.new("Folder", folder)
                childFolder.Name = encodedKey
            end

            updateFolderToReflectTable(childFolder, value)
        else
            folder:SetAttribute(encodedKey, value)

            if childFolder then
                childFolder:Destroy()
            end
        end
    end

    for name in namesToDelete do
        folder:SetAttribute(name, nil)
        childFolder = folder:FindFirstChild(name)
        if childFolder then
            childFolder:Destroy()
        end
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    updateFolderToReflectTable(root, ReplicatedTable)
end)

return ReplicatedTable
