local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local Config = Class.new("KDKit.ConfigGroup.Config")

function Config:__init(group: "KDKit.ConfigGroup", instance: ModuleScript)
    self._raw = require(instance)

    self.attributes = instance:GetAttributes()
    self.name = self._raw.name or instance.Name
    self.humanName = self._raw.humanName or self.attributes.humanName or Humanize:casing(self.name, "title")

    self.instance = self._raw.instance or instance:FindFirstChild("instance")

    if self._raw.defaults == nil then
        self.defaults = group.defaults
    end
end

function Config:__index(name)
    local value = self._raw[name]

    if value == nil then
        value = Utils:getattr(self.defaults, name)
    end

    if value == nil then
        value = Class.Object.__index(self, name)
    end

    return value
end

return Config
