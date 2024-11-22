--!strict

local TweenService = game:GetService("TweenService")
local Animate = {
    counts = setmetatable({} :: { [Instance]: number }, { __mode = "kv" }),
}

function Animate.count(instance: Instance): number
    local count = (Animate.counts[instance] or 0) + 1
    Animate.counts[instance] = count
    return count
end

function Animate.checkCount(instance: Instance): number
    return Animate.counts[instance]
end

function Animate.positionBasedOnAttributes(
    instance: Instance,
    positionAttributeName: string,
    delayAttributeNames: ({ string } | string)?,
    includeDescendants: boolean?,
    seconds: number?,
    style: Enum.EasingStyle?,
    direction: Enum.EasingDirection?
): number
    delayAttributeNames = delayAttributeNames or { "animationDelay" }
    if typeof(delayAttributeNames) == "string" then
        delayAttributeNames = { delayAttributeNames }
    end
    assert(typeof(delayAttributeNames) == "table")

    if includeDescendants == nil then
        includeDescendants = true
    end
    seconds = seconds or 1 / 2
    style = style or Enum.EasingStyle.Back
    direction = direction or Enum.EasingDirection.InOut

    assert(seconds)

    local position = instance:GetAttribute(positionAttributeName)
    local animationDelay = 0
    for _, name in delayAttributeNames do
        local v = instance:GetAttribute(name)
        if typeof(v) == "number" then
            animationDelay = v
            break
        end
    end

    if position then
        local me = Animate.count(instance)

        task.defer(function()
            if animationDelay > 0 then
                task.wait(animationDelay)
            end

            if me == Animate.checkCount(instance) then
                TweenService:Create(instance, TweenInfo.new(seconds, style, direction, 0, false, 0), {
                    Position = position,
                }):Play()
            end
        end)
    end

    local allAnimationsWillCompleteIn = if position then animationDelay + seconds else 0
    if includeDescendants then
        for _, descendant in instance:GetDescendants() do
            allAnimationsWillCompleteIn = math.max(
                allAnimationsWillCompleteIn,
                Animate.positionBasedOnAttributes(
                    descendant,
                    positionAttributeName,
                    delayAttributeNames,
                    false,
                    seconds,
                    style,
                    direction
                )
            )
        end
    end

    return allAnimationsWillCompleteIn
end

function Animate.onscreen(
    instance: Instance,
    includeDescendants: boolean?,
    seconds: number?,
    skipDelay: boolean?,
    style: Enum.EasingStyle?
): number
    return Animate.positionBasedOnAttributes(
        instance,
        "onscreenPosition",
        if skipDelay then {} else { "onscreenAnimationDelay", "animationDelay" },
        includeDescendants,
        seconds or 1 / 2,
        style,
        Enum.EasingDirection.Out
    )
end

function Animate.offscreen(
    instance: Instance,
    includeDescendants: boolean?,
    seconds: number?,
    skipDelay: boolean?,
    style: Enum.EasingStyle?
): number
    return Animate.positionBasedOnAttributes(
        instance,
        "offscreenPosition",
        if skipDelay then {} else { "offscreenAnimationDelay", "animationDelay" },
        includeDescendants,
        seconds or 1 / 3,
        style,
        Enum.EasingDirection.In
    )
end

return Animate
