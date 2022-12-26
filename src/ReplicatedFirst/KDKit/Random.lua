local Utils = require(script.Parent:WaitForChild("Utils"))

local KDRandom = {
    rng = Random.new(),
}

local UUID_HAT = Utils:characters("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

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

function KDRandom:ishuffle(t)
    local N = #t
    for i = N, 2, -1 do
        local r = self.rng:NextInteger(1, i)
        t[i], t[r] = t[r], t[i]
    end
end

function KDRandom:shuffle(t)
    t = table.clone(t)
    self:ishuffle(t)
    return t
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

function KDRandom:uuid(strlen: number, avoidCollisions: { [string]: any }?, hat: ({ string } | string)?): string
    if hat == nil then
        hat = UUID_HAT
    else
        if type(hat) == "string" then
            hat = Utils:characters(hat)
        end

        assert(next(hat), "cannot use empty hat for uuid generation")
    end

    if avoidCollisions == nil then
        local output = table.create(strlen)
        for i = 1, strlen do
            table.insert(output, self:linearChoice(hat))
        end
        return table.concat(output)
    else
        local output
        while true do
            for try = 1, 5 do
                output = self:uuid(strlen, nil, hat)
                if avoidCollisions[output] == nil then
                    return output
                end
            end

            -- 5 tries of collisions, need to increase the strlen
            strlen += 1
        end
    end
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

function KDRandom:number(a: NumberRange | number?, b: number?): number
    if typeof(a) == "NumberRange" then
        a, b = a.Min, a.Max
    end

    return self.rng:NextNumber(a or 0, b or 1)
end

return KDRandom
