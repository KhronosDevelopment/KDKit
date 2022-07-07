local Class = require(script.Parent:WaitForChild("Class"))
local Time = require(script.Parent:WaitForChild("Time"))
local Hash = require(script.Parent:WaitForChild("Hash"))

local TimeBasedPassword = Class.new("KDKit.TimeBasedPassword")

function TimeBasedPassword:__init(secret, period, depth)
    self.secret = secret or error("You must supply a password.")
    self.period = period or 60
    self.depth = depth or 256

    self.cache = {
        prefix = nil,
        password = nil,
    }

    if self.depth < 1 then
        error("You must use a depth of at least one. Otherwise, your password will not be hashed at all.")
    end
end

function TimeBasedPassword:getCurrentPassword()
    local currentPrefix = self:getCurrentPrefix()
    if self.cache.prefix ~= currentPrefix then
        self.cache.prefix = currentPrefix
        self.cache.password = self:generatePasswordFromPrefix(currentPrefix)
    end

    return self.cache.password
end

function TimeBasedPassword:getCurrentPrefix()
    return self:getPrefixAtTime(Time())
end

function TimeBasedPassword:getPrefixAtTime(t)
    return ("%d"):format(math.floor(t / self.period + 0.5))
end

function TimeBasedPassword:generatePasswordFromPrefix(prefix)
    local password = prefix .. self.secret

    for _ = 1, self.depth do
        password = Hash:sha256(password)
    end

    return password
end

function TimeBasedPassword:isValid(password)
    return self:isValidAtTime(password, Time())
end

function TimeBasedPassword:isValidAtTime(password, time)
    return password == self:generatePasswordFromPrefix(self:getPrefixAtTime(time))
        or password == self:generatePasswordFromPrefix(self:getPrefixAtTime(time - self.period))
        or password == self:generatePasswordFromPrefix(self:getPrefixAtTime(time + self.period))
end

return TimeBasedPassword
