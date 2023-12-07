local Class = require(script.Parent.Parent.Parent:WaitForChild("Class"))
local ConfigGroup = require(script.Parent.Parent.Parent:WaitForChild("ConfigGroup"))
local Maid = require(script.Parent.Parent.Parent:WaitForChild("Maid"))

local VibeConfig = Class.new("VibeConfig", ConfigGroup.Config)

type Args = table

function VibeConfig:__init(module: ModuleScript)
    VibeConfig.__super.__init(self, module)

    self.animationMaid = Maid.new()
end

function VibeConfig:getArgs(defaultArgs: { characterPosition: Vector3 }): Args
    return defaultArgs
end

function VibeConfig:getPriority(args: Args): number
    return self.attributes.priority or 0
end

function VibeConfig:isApplicable(args: Args): boolean
    warn("Please override `isApplicable` if you wish your vibe to be used!")
    return false
end

function VibeConfig:beforeDeactivated(nextConfig: "VibeConfig"?): nil
    self.animationMaid:clean()
end
function VibeConfig:afterDeactivated(nextConfig: "VibeConfig"?): nil
    -- should typically be left blank
end

function VibeConfig:beforeActivated(args: Args, previousConfig: "VibeConfig"?): nil
    self.animationMaid:clean()
end
function VibeConfig:afterActivated(args: Args, previousConfig: "VibeConfig"?): nil
    -- should typically be left blank
end

function VibeConfig:animateIn(args: Args, previousConfig: "VibeConfig"?): nil
    -- most vibes should add to `animationMaid` here
end
function VibeConfig:animateOut(nextConfig: "VibeConfig"?): nil
    -- should typically be left blank
end

return VibeConfig
