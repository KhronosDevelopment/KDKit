local Utils = require(script.Parent:WaitForChild("Utils"))

local KDRandom = {
    rng = Random.new(),
}

local TWO_PI = math.pi * 2
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

function KDRandom:ichoices(options, n)
    local nOptions = #options
    local choices = {}
    for i = 0, n - 1 do
        table.insert(choices, table.remove(options, self:number(1, nOptions - i)))
    end
    return choices
end

function KDRandom:choices(options, n)
    return self:ichoices(table.clone(options), n)
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

function KDRandom:withRNG(rng, f, ...)
    local oldRNG = self.rng
    self.rng = rng

    return Utils:ensure(function()
        self.rng = oldRNG
    end, f, ...)
end

function KDRandom:withSeed(seed, f, ...)
    return self:withRNG(Random.new(seed), f, ...)
end

function KDRandom:vector(minMagnitude, maxMagnitude)
    local v = Vector3.new(self.rng:NextNumber(-1, 1), self.rng:NextNumber(-1, 1), self.rng:NextNumber(-1, 1))

    return v.Unit * self.rng:NextNumber(minMagnitude, maxMagnitude or minMagnitude)
end

function KDRandom:integer(a: NumberRange | number?, b: number?): number
    if typeof(a) == "NumberRange" then
        a, b = a.Min, a.Max
    end

    return self.rng:NextInteger(a or 0, b or 1)
end

function KDRandom:number(a: NumberRange | number?, b: number?): number
    if typeof(a) == "NumberRange" then
        a, b = a.Min, a.Max
    end

    return self.rng:NextNumber(a or 0, b or 1)
end

--[[
    Returns true or false with the given odds (between 0 and 1).
--]]
function KDRandom:test(chance: number): boolean
    return self.rng:NextNumber(0, 1) < chance
end

function KDRandom:normal()
    -- inspired by https://github.com/Bytebit-Org/lua-statistics/blob/3bd0c0bdad2c5bbe46efd1895206287aef903d6d/src/statistics.lua#L193-L201
    return math.sqrt(-2 * math.log(self.rng:NextNumber(0.0001, 1))) * math.cos(TWO_PI * self.rng:NextNumber())
end

--[[
    Randomly rounds up or down based on how close it is to either side.
    For example, 1.75 will have a 75% chance of rounding up and 25% of rounding down.
    Similarly, 82.4 will have a 60% chance of rounding down and 40% of rounding up.
    Negative numbers work as expected, -1.99 has a 99% chance of rounding to -2.
--]]
function KDRandom:round(n: number): number
    if self:test(n % 1) then
        return math.ceil(n)
    else
        return math.floor(n)
    end
end

return KDRandom
