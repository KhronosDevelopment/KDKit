local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local Config = Class.new("KDKit.ConfigGroup.Config")

function Config:__init(group: "KDKit.ConfigGroup", instance: ModuleScript)
    self._raw = require(instance)

    self.attributes = self._raw.attributes or instance:GetAttributes()
    self.name = self._raw.name or instance.Name
    self.humanName = self._raw.humanName or self.attributes.humanName or Humanize:casing(self.name, "title")
    self.instance = self._raw.instance or instance:FindFirstChild("instance")
    self.defaults = group.defaults

    local og_mt = getmetatable(self)
    setmetatable(
        self,
        Utils:merge(og_mt, {
            __index = function(t, name)
                local value = self._raw[name]

                if value == nil then
                    value = self.defaults[name]
                end

                if value == nil then
                    value = og_mt.__index(t, name)
                end

                return value
            end,
        })
    )
end

return Config
