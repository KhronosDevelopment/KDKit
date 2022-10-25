local Class = require(script.Parent:WaitForChild("Class"))
local Cooldown = Class.new("KDKit.Cooldown")

function Cooldown:__init()
    self.cooldowns = {}
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
