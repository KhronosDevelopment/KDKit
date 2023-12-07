local TweenService = game:GetService("TweenService")
local Utils = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Utils"))
local Terrain = {}

Terrain.terrain = workspace:WaitForChild("Terrain") :: Terrain

Terrain.MATERIALS = Utils:select(Enum.Material:GetEnumItems(), function(material: Enum.Material)
    -- GetMaterialColor throws an error for invalid materials
    return pcall(Terrain.GetMaterialColor, Terrain.terrain, material)
end) :: { Enum.Material }

type DataType = "Color3" | "number"

type PropertyName = string
type PropertyValue = any
Terrain.PROPERTIES = {
    Color3 = {
        "WaterColor",
    },
    number = {
        "WaterReflectance",
        "WaterTransparency",
        "WaterWaveSize",
        "WaterWaveSpeed",
    },
} :: { [DataType]: { PropertyName } }

export type Config = {
    properties: {
        [DataType]: {
            [PropertyName]: { PropertyValue },
        },
    },
    materials: {
        [Enum.Material]: Color3,
    },
}

function Terrain:parse(instance: Instance): Config
    local config: Config = { properties = {}, materials = {} }

    for _, material in self.MATERIALS do
        config.materials[material] = instance:GetAttribute("material_" .. material.Name)
    end

    for propertyDataType, properties in self.PROPERTIES do
        config.properties[propertyDataType] = {}
        for _, propertyName in properties do
            config.properties[propertyDataType][propertyName] = instance:GetAttribute(propertyName)
        end

        if not next(config.properties[propertyDataType]) then
            config.properties[propertyDataType] = nil
        end
    end

    return config
end

function Terrain:tween(config: Config, tweenInfo: TweenInfo, maid: "KDKit.Maid"): nil
    local tweenProps
    local factor = maid:give(Instance.new("NumberValue"))
    factor.Value = 0

    local materialsBefore: { [Enum.Material]: Color3 } = {}
    for material in config.materials do
        materialsBefore[material] = self.terrain:GetMaterialColor(material)
    end

    maid:give(factor.Changed:Connect(function()
        local f = factor.Value

        for material, value in config.materials do
            self.terrain:SetMaterialColor(material, materialsBefore[material]:Lerp(value, f))
        end
    end))

    maid:give(TweenService:Create(factor, tweenInfo, { Value = 1 })):Play()

    tweenProps = {}
    for _, properties in config.properties do
        Utils:imerge(tweenProps, properties)
    end
    if next(tweenProps) then
        maid:give(TweenService:Create(self.terrain, tweenInfo, tweenProps)):Play()
    end
end

return Terrain
