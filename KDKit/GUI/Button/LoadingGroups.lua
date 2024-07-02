--!strict

local LoadingGroup = require(script.Parent:WaitForChild("LoadingGroup"))
local T = require(script.Parent:WaitForChild("types"))

local LoadingGroups = {}

function LoadingGroups.add(button: T.Button, id: any)
    local group = LoadingGroup.list[id] or LoadingGroup.new(id)
    group:add(button)
end

function LoadingGroups.remove(button: T.Button, id: any)
    local group = LoadingGroup.list[id]

    if group then
        group:remove(button)
    end
end

function LoadingGroups.anyAreLoading(ids: { any }): boolean
    for _, id in ids do
        local group = LoadingGroup.list[id]
        if group and group:isLoading() then
            return true
        end
    end
    return false
end

function LoadingGroups.update(ids: { any })
    for _, id in ids do
        local group = LoadingGroup.list[id]
        if group then
            group:update()
        end
    end
end

return LoadingGroups
