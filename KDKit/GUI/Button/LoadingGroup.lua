--!strict

local T = require(script.Parent:WaitForChild("types"))

type LoadingGroupImpl = T.LoadingGroupImpl
export type LoadingGroup = T.LoadingGroup

local LoadingGroup: LoadingGroupImpl = {
    list = {},
} :: LoadingGroupImpl
LoadingGroup.__index = LoadingGroup

function LoadingGroup.new(id)
    local self = setmetatable({
        id = id,
        buttons = {},
        wasLoadingOnLastUpdate = nil,
    }, LoadingGroup) :: LoadingGroup

    LoadingGroup.list[self.id] = self

    return self
end

function LoadingGroup:add(button)
    if self.buttons[button] then
        self:remove(button)
    end

    self.buttons[button] = true
    self:update()
end

function LoadingGroup:remove(button)
    if not self.buttons[button] then
        return
    end
    self.buttons[button] = nil
    self:update()

    -- if that was the last button, delete the entire group
    if not next(self.buttons) then
        LoadingGroup.list[self.id] = nil
    end
end

function LoadingGroup:isLoading()
    for button in self.buttons do
        if button.callbackIsExecuting then
            return true
        end
    end

    return false
end

function LoadingGroup:update()
    local loading = self:isLoading()
    if loading ~= self.wasLoadingOnLastUpdate then
        self.wasLoadingOnLastUpdate = loading
        for b in self.buttons do
            local button = b :: T.Button -- type checker fails on templates
            button:visualStateChanged()
        end
    end
end

return LoadingGroup
