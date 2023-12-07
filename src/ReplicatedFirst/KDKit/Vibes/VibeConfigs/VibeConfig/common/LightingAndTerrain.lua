local Class = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Class"))
local VibeConfig = require(script.Parent.Parent)
local LightingAndTerrain = Class.new("VibeConfig.LightingAndTerrain", VibeConfig)

local Terrain = require(script.Parent.Parent:WaitForChild("utils"):WaitForChild("Terrain"))
local Lighting = require(script.Parent.Parent:WaitForChild("utils"):WaitForChild("Lighting"))

type Config = {
    lighting: Lighting.Config?,
    terrain: Terrain.Config?,
}

function LightingAndTerrain:__init(module: ModuleScript)
    LightingAndTerrain.__super.__init(self, module)

    self.config = {
        lighting = if module:FindFirstChild("lighting") then Lighting:parse(module.lighting) else nil,
        terrain = if module:FindFirstChild("terrain") then Terrain:parse(module.terrain) else nil,
    } :: Config
end

function LightingAndTerrain:getTweenInfo(): TweenInfo
    return TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

function LightingAndTerrain:animateIn(args)
    local tweenInfo = self:getTweenInfo()

    if self.config.lighting then
        Lighting:tween(self.config.lighting, tweenInfo, self.animationMaid)
    end

    if self.config.terrain then
        Terrain:tween(self.config.terrain, tweenInfo, self.animationMaid)
    end
end

return LightingAndTerrain
