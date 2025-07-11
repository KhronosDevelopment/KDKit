--!strict

local TweenService = game:GetService("TweenService")
local Animate = {
    counts = {} :: { [Instance]: number },
}

export type Style = { [string]: any }

function Animate.count(instance: Instance): number
    local count = (Animate.counts[instance] or 0) + 1
    Animate.counts[instance] = count
    return count
end

function Animate.checkCount(instance: Instance): number
    return Animate.counts[instance]
end

function Animate.clearCount(instance: Instance)
    Animate.counts[instance] = nil
end

function Animate.tween(instance: Instance, style: Style, tweenInfo: TweenInfo)
    if tweenInfo.Time <= 0 then
        for k, v in style do
            (instance :: any)[k] = v
        end
    else
        TweenService:Create(instance, tweenInfo, style):Play()
    end
end

function Animate.style(instance: Instance, style: Style, tweenInfo: TweenInfo, delay: number)
    local me = Animate.count(instance)

    if delay <= 0 then
        Animate.tween(instance, style, tweenInfo)
    else
        task.delay(delay, function()
            if Animate.checkCount(instance) == me then
                Animate.clearCount(instance)
                Animate.tween(instance, style, tweenInfo)
            end
        end)
    end
end

function Animate.basedOnAttributes(
    instance: Instance,
    prefix: string,
    tweenInfo: TweenInfo,
    noDelay: boolean?,
    excludeDescendants: boolean?
): number
    local style = {} :: Style
    local animationDelay = 0

    for name, value in instance:GetAttributes() do
        local property = name:match(prefix .. "(.+)")
        if property == "delay" then
            animationDelay = tonumber(value) or 0
        elseif property then
            style[property] = value
        end
    end

    if noDelay then
        animationDelay = 0
    end

    local allAnimationsWillCompleteIn = if next(style) then animationDelay + tweenInfo.DelayTime + tweenInfo.Time else 0

    if not excludeDescendants then
        for _, child in instance:GetChildren() do
            allAnimationsWillCompleteIn =
                math.max(allAnimationsWillCompleteIn, Animate.basedOnAttributes(child, prefix, tweenInfo, noDelay))
        end
    end

    if next(style) then
        Animate.style(instance, style, tweenInfo, animationDelay)
    end

    return allAnimationsWillCompleteIn
end

function Animate.onscreen(instance: Instance, duration: number): number
    return Animate.basedOnAttributes(
        instance,
        "onscreen_",
        TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        duration <= 0
    )
end

function Animate.offscreen(instance: Instance, duration: number): number
    return Animate.basedOnAttributes(
        instance,
        "offscreen_",
        TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        duration <= 0
    )
end

return Animate
