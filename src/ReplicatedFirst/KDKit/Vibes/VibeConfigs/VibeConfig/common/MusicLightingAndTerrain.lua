local Class = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Class"))
local VibeConfig = require(script.Parent.Parent)
local MusicLightingAndTerrain = Class.new("VibeConfig.MusicLightingAndTerrain", VibeConfig)

local Terrain = require(script.Parent.Parent:WaitForChild("utils"):WaitForChild("Terrain"))
local Lighting = require(script.Parent.Parent:WaitForChild("utils"):WaitForChild("Lighting"))
local Music = require(script.Parent.Parent:WaitForChild("utils"):WaitForChild("Music"))

type Config = {
    lighting: Lighting.Config?,
    terrain: Terrain.Config?,
    music: Music.Config?,
}

function MusicLightingAndTerrain:__init(module: ModuleScript)
    MusicLightingAndTerrain.__super.__init(self, module)

    self.config = {
        lighting = if module:FindFirstChild("lighting") then Lighting:parse(module.lighting) else nil,
        terrain = if module:FindFirstChild("terrain") then Terrain:parse(module.terrain) else nil,
        music = if module:FindFirstChild("music") then Music:parse(module.music, self.name) else nil,
    } :: Config
end

function MusicLightingAndTerrain:getTerrainTweenInfo()
    return TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

function MusicLightingAndTerrain:getLightingTweenInfo()
    return TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

function MusicLightingAndTerrain:getMusicTweenInfo()
    return TweenInfo.new(5, Enum.EasingStyle.Linear)
end

function MusicLightingAndTerrain:animateIn(args)
    if self.config.lighting then
        Lighting:tween(self.config.lighting, self:getLightingTweenInfo(), self.animationMaid)
    end

    if self.config.terrain then
        Terrain:tween(self.config.terrain, self:getTerrainTweenInfo(), self.animationMaid)
    end

    if self.config.music then
        Music:fadeIn(self.config.music, self:getMusicTweenInfo())
    end
end

function MusicLightingAndTerrain:animateOut()
    if self.config.music then
        Music:fadeOut(self.config.music, self:getMusicTweenInfo())
    end
end

return MusicLightingAndTerrain
