local Class = require(script.Parent:WaitForChild("Class"))
local Preload = require(script.Parent:WaitForChild("Preload"))

local ConfigGroup = Class.new("KDKit.ConfigGroup")
ConfigGroup.static.Config = require(script:WaitForChild("Config"))

function ConfigGroup:__init(root: Instance)
    Preload:ensureDescendants(root)

    self._root = root
    self._instances = root.configs:GetChildren()
    self._defaults = require(root.defaults)
    self._configs = table.create(#self._instances)

    for _, instance in self._instances do
        local cfg = ConfigGroup.Config.new(self, instance)

        if self._configs[cfg.name] ~= nil then
            error(
                ("You have two (or more) configs with the same name: '%s'. All of the config names within a group must be unique."):format(
                    cfg.name
                )
            )
        end

        if rawget(self, cfg.name) ~= nil then
            error(("You cannot use the config name '%s', it is reserved for internal use."):format(cfg.name))
        end

        self[cfg.name] = cfg
        self._configs[cfg.name] = cfg
    end
end

function ConfigGroup:__iter__()
    return pairs(self._configs)
end

return ConfigGroup
