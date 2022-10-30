local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))

local Config = Class.new("KDKit.ConfigGroup.Config")

function Config:__init(instance: ModuleScript)
    self.name = instance.Name
    self.attributes = instance:GetAttributes()
    self.humanName = self.attributes.humanName or Humanize:casing(self.name, "title")
    self.humanNamePlural = self.attributes.humanNamePlural or Humanize:plural(self.humanName)
end

return Config
