local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Utils = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Utils"))
local KDRandom = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Random"))

local Music = {
    muted = false,
    group = Instance.new("SoundGroup", SoundService),
}
Music.group.Volume = 1

do -- instances
    Music.instanceTemplate = Instance.new("SoundGroup")
    Music.instanceTemplate.Volume = 1
    Music.instanceTemplate.Name = "KDKit.Vibes.Music"
end

export type Config = {
    endedConnection: RBXScriptConnection?,
    queue: { Sound },
    nextQueue: { Sound },
    instance: SoundGroup,
}

function Music:iGenerateNextQueue(config: Config)
    --[[
    If you have 3 song (A, B, and C) then all of these results would be undesirable:
        - C, A, B, B, C, A, ... because B is repeated
        - B, A, C, A, C, B, ... because A and C appear too close together
    
    this variable is the minimum distance between duplicates of a song,
    so for example `minimumDistanceBetweenReplays = 1` means that
    `A, B, A` is acceptable and `B, B` is not.
    and `minimumDistanceBetweenReplays = 2` means that
    `A, B, C, A` is acceptable but `A, B, A` is not
    --]]
    local n = #config.queue
    local minimumDistanceBetweenReplays
    if n > 3 then
        minimumDistanceBetweenReplays = math.ceil(n / 3)
    elseif n > 0 then
        minimumDistanceBetweenReplays = n - 1
    else
        config.nextQueue = {}
        return
    end

    local cpy = table.clone(config.queue)

    local nextQueue = {}
    for _ = 1, minimumDistanceBetweenReplays do
        local index = KDRandom:integer(1, n - minimumDistanceBetweenReplays)
        local song = table.remove(cpy, index)
        table.insert(nextQueue, song)
    end

    KDRandom:ishuffle(cpy)
    Utils:iextend(nextQueue, cpy)

    config.nextQueue = nextQueue
end

function Music:playNext(config: Config)
    if not next(config.queue) then
        config.queue = config.nextQueue
        self:iGenerateNextQueue(config)
    end

    if not next(config.queue) then
        return
    end

    if config.endedConnection then
        config.endedConnection:Disconnect()
    end
    config.instance:ClearAllChildren()
    table.remove(config.queue, 1):Clone().Parent = config.instance
    config.endedConnection = config.instance.sound.Ended:Connect(function()
        self:playNext(config)
    end)

    local v = config.instance.sound.Volume
    config.instance.sound.Volume = 0
    TweenService:Create(
        config.instance.sound,
        TweenInfo.new(
            config.instance.sound:GetAttribute("volumeFadeDuration") or 1,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        ),
        { Volume = v }
    ):Play()

    config.instance.sound:Play()
end

function Music:parse(instance: Instance, name: string?): Config
    local cfg = {
        name = name,
        instance = self.instanceTemplate:Clone(),
    }
    if name then
        cfg.instance.Name ..= " - " .. name
    end

    cfg.instance.Volume = 0
    cfg.instance.Parent = self.group

    cfg.queue = KDRandom:shuffle(Utils:map(
        function(s: Sound)
            s = s:Clone()
            s.Looped = false
            s.SoundGroup = cfg.instance
            s.Name = "sound"
            return s
        end,
        Utils:select(instance:GetChildren(), function(s)
            return s:IsA("Sound")
        end)
    ))

    self:iGenerateNextQueue(cfg)
    self:playNext(cfg)

    return cfg
end

function Music:fadeIn(config: Config, tweenInfo: TweenInfo)
    TweenService:Create(config.instance, tweenInfo, { Volume = 1 }):Play()
end

function Music:fadeOut(config: Config, tweenInfo: TweenInfo)
    TweenService:Create(config.instance, tweenInfo, { Volume = 0 }):Play()
end

function Music:setVolume(volume: number)
    self.group.Volume = volume
end

function Music:getVolume(): number
    return self.group.Volume
end

return Music
