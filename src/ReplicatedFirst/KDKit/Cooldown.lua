--!strict

type CooldownImpl = {
    __index: CooldownImpl,
    new: () -> Cooldown,
    start: (Cooldown, any, number) -> (),
    stop: (Cooldown, any) -> (),
    ready: (Cooldown, any) -> boolean,
}
export type Cooldown = typeof(setmetatable({} :: { cooldowns: { [any]: number } }, {} :: CooldownImpl))

local Cooldown: CooldownImpl = {} :: CooldownImpl
Cooldown.__index = Cooldown

function Cooldown.new()
    local self = setmetatable({
        cooldowns = {},
    }, Cooldown) :: Cooldown

    return self
end

function Cooldown:start(id, seconds)
    self.cooldowns[id] = os.clock() + seconds

    -- we don't want to leak memory by keeping a reference
    -- to `id` past when it is required.
    -- self:ready(id) will clean up the reference if applicable
    task.delay(seconds + 1, self.ready, self, id)
end

function Cooldown:stop(id)
    self.cooldowns[id] = nil
end

function Cooldown:ready(id)
    local ready = not self.cooldowns[id] or self.cooldowns[id] < os.clock()

    if ready then
        self:stop(id)
    end

    return ready
end

return Cooldown
