local TweenService = game:GetService("TweenService")
local Animate = {
    counts = setmetatable(table.create(128), { __mode = "kv" }),
}

function Animate:count(instance: Instance)
    local count = (self.counts[instance] or 0) + 1
    self.counts[instance] = count
    return count
end

function Animate:checkCount(instance)
    return self.counts[instance]
end

function Animate:positionBasedOnAttributes(
    instance: Instance,
    positionAttributeName: string,
    delayAttributeNames: ({ string } | string)?,
    includeDescendants: boolean?,
    seconds: number?,
    style: Enum.EasingStyle?,
    direction: Enum.EasingDirection?
)
    delayAttributeNames = delayAttributeNames or { "animationDelay" }
    if typeof(delayAttributeNames) == "string" then
        delayAttributeNames = { delayAttributeNames }
    end
    if includeDescendants == nil then
        includeDescendants = true
    end
    seconds = seconds or 1 / 2
    style = style or Enum.EasingStyle.Back
    direction = direction or Enum.EasingDirection.InOut

    local position = instance:GetAttribute(positionAttributeName)
    local animationDelay = nil
    for _, name in delayAttributeNames do
        animationDelay = animationDelay or instance:GetAttribute(name)
    end
    animationDelay = animationDelay or 0

    if position then
        local me = self:count(instance)

        task.defer(function()
            if animationDelay > 0 then
                task.wait(animationDelay)
            end

            if me == self:checkCount(instance) then
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
                self:positionBasedOnAttributes(
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

function Animate:onscreen(
    instance: Instance,
    includeDescendants: boolean?,
    seconds: number?,
    skipDelay: boolean?,
    style: Enum.EasingStyle?
)
    return self:positionBasedOnAttributes(
        instance,
        "onscreenPosition",
        if skipDelay then {} else { "onscreenAnimationDelay", "animationDelay" },
        includeDescendants,
        seconds or 1 / 2,
        style,
        Enum.EasingDirection.Out
    )
end

function Animate:offscreen(
    instance: Instance,
    includeDescendants: boolean?,
    seconds: number?,
    skipDelay: boolean?,
    style: Enum.EasingStyle?
)
    return self:positionBasedOnAttributes(
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
