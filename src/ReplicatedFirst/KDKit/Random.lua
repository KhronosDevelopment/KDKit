local Utils = require(script.Parent:WaitForChild("Utils"))

local KDRandom = {
    rng = Random.new(),
}

function KDRandom:linearChoice(options)
    return options[self.rng:NextInteger(1, #options)]
end

function KDRandom:keyChoice(options)
    local keys = table.create(#options)
    for key, _ in options do
        table.insert(keys, key)
    end

    return self:linearChoice(keys)
end

function KDRandom:choice(options)
    local k = self:keyChoice(options)
    if k == nil then
        return nil
    end

    return options[k]
end

function KDRandom:color(saturation, value)
    return Color3.fromHSV(
        self.rng:NextNumber(0, 1),
        saturation or self.rng:NextNumber(0, 1),
        value or self.rng:NextNumber(0, 1)
    )
end

function KDRandom:enum(e)
    return self:linearChoice(e:GetEnumItems())
end

function KDRandom:shuffle(t)
    local N = #t
    for i = N, 2, -1 do
        local r = self.rng:NextInteger(1, i)
        t[i], t[r] = t[r], t[i]
    end
end

function KDRandom:weightedChoice(options)
    local totalWeight = 0
    for option, weight in options do
        totalWeight += weight
    end
    local winner = self.rng:NextNumber(0, totalWeight)

    totalWeight = 0
    for option, weight in options do
        totalWeight += weight
        if winner <= totalWeight then
            return option
        end
    end
end

function KDRandom:uuid(strlen, hat)
    hat = hat or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local hatSize = hat:len()

    local output = table.create(strlen)
    local j
    for i = 1, strlen do
        j = self.rng:NextInteger(1, hatSize)
        table.insert(output, hat:sub(j, j))
    end

    return table.concat(output)
end

function KDRandom:withSeed(seed, f, ...)
    local oldRNG = self.rng
    self.rng = Random.new(seed)

    return Utils:ensure(function()
        self.rng = oldRNG
    end, f, ...)
end

function KDRandom:vector(minMagnitude, maxMagnitude)
    local v = Vector3.new(self.rng:NextNumber(-1, 1), self.rng:NextNumber(-1, 1), self.rng:NextNumber(-1, 1))

    return v.Unit * self.rng:NextNumber(minMagnitude, maxMagnitude or minMagnitude)
end

return KDRandom
