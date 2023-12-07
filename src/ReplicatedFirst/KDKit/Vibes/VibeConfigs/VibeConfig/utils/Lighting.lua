local Utils = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Utils"))
local TweenService = game:GetService("TweenService")
local Lighting = {}

Lighting.lighting = game:GetService("Lighting")

type DataType = "boolean" | "Color3" | "number"

type PropertyName = string
type PropertyValue = any
Lighting.PROPERTIES = {
    boolean = {
        "GlobalShadows",
    },
    Color3 = {
        "Ambient",
        "ColorShift_Bottom",
        "ColorShift_Top",
        "OutdoorAmbient",
    },
    number = {
        "Brightness",
        "ClockTime",
        "EnvironmentDiffuseScale",
        "EnvironmentSpecularScale",
        "ExposureCompensation",
        "GeographicLatitude",
        "ShadowSoftness",
    },
} :: { [DataType]: { PropertyName } }

type EffectName = string
type EffectPropertyName = string
type EffectPropertyValue = any
Lighting.EFFECT_PROPERTIES = {
    Atmosphere = {
        number = {
            "Density",
            "Offset",
            "Glare",
            "Haze",
        },
        Color3 = {
            "Color",
            "Decay",
        },
    },
    BloomEffect = {
        number = {
            "Intensity",
            "Size",
            "Threshold",
        },
    },
    ColorCorrectionEffect = {
        number = {
            "Brightness",
            "Contrast",
            "Saturation",
        },
        Color3 = {
            "TintColor",
        },
    },
    DepthOfFieldEffect = {
        number = {
            "FarIntensity",
            "FocusDistance",
            "InFocusRadius",
            "NearIntensity",
        },
    },
    SunRaysEffect = {
        number = {
            "Intensity",
            "Spread",
        },
    },
} :: { [EffectName]: { [DataType]: { EffectPropertyName } } }

export type Config = {
    properties: {
        [PropertyName]: {
            [DataType]: { EffectPropertyValue },
        },
    },
    effects: {
        [EffectName]: {
            [EffectPropertyName]: {
                [DataType]: { EffectPropertyValue },
            },
        },
    },
}

function Lighting:parse(instance: Instance): Config
    local config: Config = { properties = {}, effects = {} }

    for propertyDataType, propertyNames in self.PROPERTIES do
        config.properties[propertyDataType] = {}
        for _, propertyName in propertyNames do
            config.properties[propertyDataType][propertyName] = instance:GetAttribute(propertyName)
        end

        if not next(config.properties[propertyDataType]) then
            config.properties[propertyDataType] = nil
        end
    end

    for effectName, effectProperties in Lighting.EFFECT_PROPERTIES do
        local effect = instance:FindFirstChildOfClass(effectName)
        if not effect then
            continue
        end

        config.effects[effectName] = {}
        for effectPropertyDataType, effectPropertyNames in effectProperties do
            config.effects[effectName][effectPropertyDataType] = {}

            for _, effectPropertyName in effectPropertyNames do
                config.effects[effectName][effectPropertyDataType][effectPropertyName] = effect[effectPropertyName]
            end
        end
    end

    return config
end

function Lighting:tween(config: Config, tweenInfo: TweenInfo, maid: "KDKit.Maid"): nil
    local hasBooleans = false
    local tweenProps

    tweenProps = {}
    for propertyType, properties in config.properties do
        if propertyType == "boolean" then
            hasBooleans = true
            continue
        end

        Utils:imerge(tweenProps, properties)
    end

    if next(tweenProps) then
        maid:give(TweenService:Create(self.lighting, tweenInfo, tweenProps)):Play()
    end

    for effectName, typedEffectProperties in config.effects do
        local effect = self.lighting:FindFirstChildOfClass(effectName)
        if not effect then
            continue
        end

        tweenProps = {}
        for effectPropertyType, effectProperties in typedEffectProperties do
            if effectPropertyType == "boolean" then
                hasBooleans = true
                continue
            end

            Utils:imerge(tweenProps, effectProperties)
        end

        if next(tweenProps) then
            maid:give(TweenService:Create(effect, tweenInfo, tweenProps)):Play()
        end
    end

    if hasBooleans then
        local booleanFactor, booleanConnection, booleanTween

        booleanFactor = maid:give(Instance.new("NumberValue"))
        booleanFactor.Value = 0

        booleanConnection = maid:give(booleanFactor.Changed:Connect(function()
            local f = booleanFactor.Value
            if f < 0.5 then
                return
            end

            maid:clean(booleanConnection)
            maid:clean(booleanFactor)
            maid:clean(booleanTween)

            for name, value in config.properties.boolean do
                self.lighting[name] = value
            end
            for effectName, typedEffectProperties in config.effects do
                if not typedEffectProperties.boolean then
                    continue
                end

                local effect = self.lighting:FindFirstChildOfClass(effectName)
                if not effect then
                    continue
                end

                for name, value in typedEffectProperties.boolean do
                    effect[name] = value
                end
            end
        end))

        booleanTween = maid:give(TweenService:Create(booleanFactor, tweenInfo, { Value = 1 }))
        booleanTween:Play()
    end
end

return Lighting
