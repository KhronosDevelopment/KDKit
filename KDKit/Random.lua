--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

local KDRandom = {
    rng = Random.new(),
}

local TWO_PI = math.pi * 2
local UUID_HAT = Utils.characters("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

function KDRandom.integer(a: NumberRange | number?, b: number?): number
    if typeof(a) == "NumberRange" then
        a, b = a.Min, a.Max
    end

    return KDRandom.rng:NextInteger((a or 0) :: number, b or 1)
end

function KDRandom.number(a: NumberRange | number?, b: number?): number
    if typeof(a) == "NumberRange" then
        a, b = a.Min, a.Max
    end

    return KDRandom.rng:NextNumber((a or 0) :: number, b or 1)
end

function KDRandom.iLinearChoice<V>(options: { V }): V
    local n = #options
    assert(n > 0, "Cannot choose from 0 elements.")

    return table.remove(options, KDRandom.integer(1, n)) :: V
end

function KDRandom.linearChoice<V>(options: { V }): V
    local n = #options
    assert(n > 0, "Cannot choose from 0 elements.")

    return options[KDRandom.integer(1, n)]
end

function KDRandom.iLinearChoices<V>(options: { V }, k: number): { V }
    local n = #options
    assert(k <= n, "Cannot choose more elements than exist.")

    local choices = {}
    for r = n, n - k + 1, -1 do
        table.insert(choices, table.remove(options, KDRandom.number(1, r)) :: V)
    end

    return choices
end

function KDRandom.linearChoices<V>(options: { V }, k: number): { V }
    return KDRandom.iLinearChoices(table.clone(options), k)
end

function KDRandom.keyChoice<K, V>(options: { [K]: V }): K
    return KDRandom.linearChoice(Utils.keys(options))
end

function KDRandom.keyChoices<K, V>(options: { [K]: V }, k: number): { K }
    return KDRandom.iLinearChoices(Utils.keys(options), k)
end

function KDRandom.iChoice<K, V>(options: { [K]: V }): V
    local key = KDRandom.keyChoice(options)
    local value = options[key]
    options[key] = nil
    return value
end

function KDRandom.choice<K, V>(options: { [K]: V }): V
    return options[KDRandom.keyChoice(options)]
end

function KDRandom.choices<K, V>(options: { [K]: V }, k: number): { [K]: V }
    local keys = Utils.keys(options)
    local n = #keys

    assert(k <= n, "Cannot choose more items than exist.")

    local choices = {}
    for r = n, n - k + 1, -1 do
        local key = table.remove(keys, KDRandom.integer(1, r)) :: K
        choices[key] = options[key]
    end

    return choices
end

function KDRandom.iChoices<K, V>(options: { [K]: V }, k: number): { [K]: V }
    local choices = KDRandom.choices(options, k)

    for k in choices do
        options[k] = nil
    end

    return choices
end

function KDRandom.color(saturation: number?, value: number?): Color3
    return Color3.fromHSV(KDRandom.number(0, 1), saturation or KDRandom.number(0, 1), value or KDRandom.number(0, 1))
end

function KDRandom.enum(e: Enum): EnumItem
    return KDRandom.linearChoice(e:GetEnumItems())
end

function KDRandom.ishuffle(t: { [any]: any })
    local N = #t
    for i = N, 2, -1 do
        local r = KDRandom.integer(1, i)
        t[i], t[r] = t[r], t[i]
    end
end

function KDRandom.shuffle<K, V>(t: { [K]: V }): { [K]: V }
    t = table.clone(t)
    KDRandom.ishuffle(t)
    return t
end

function KDRandom.weightedChoice<K>(options: { [K]: number }): K
    local totalWeight = 0
    for option, weight in options do
        totalWeight += weight
    end
    local winner = KDRandom.number(0, totalWeight)

    totalWeight = 0
    for option, weight in options do
        totalWeight += weight
        if winner <= totalWeight then
            return option
        end
    end

    error("[KDKit.Random] Called weightedChoice with empty table!")
end

function KDRandom.uuid(strlen: number, avoidCollisions: { [string]: any }?, hat: ({ string } | string)?): string
    if hat == nil then
        hat = UUID_HAT
    else
        if type(hat) == "string" then
            hat = Utils.characters(hat)
        end

        assert(next(hat), "cannot use empty hat for uuid generation")
    end

    if avoidCollisions == nil then
        local output = table.create(strlen)
        for i = 1, strlen do
            table.insert(output, KDRandom.linearChoice(hat :: { string }))
        end
        return table.concat(output)
    else
        local output
        while true do
            for try = 1, 5 do
                output = KDRandom.uuid(strlen, nil, hat)
                if avoidCollisions[output] == nil then
                    return output
                end
            end

            -- 5 tries of collisions, need to increase the strlen
            strlen += 1
        end
    end
end

function KDRandom.withRNG<Arg..., Ret...>(rng: Random, f: (Arg...) -> Ret..., ...: Arg...): Ret...
    local oldRNG = KDRandom.rng
    KDRandom.rng = rng

    return Utils.ensure(function()
        KDRandom.rng = oldRNG
    end, f, ...)
end

function KDRandom.withSeed<Arg..., Ret...>(seed: number?, f: (Arg...) -> Ret..., ...: Arg...): Ret...
    return KDRandom.withRNG(Random.new(seed), f, ...)
end

function KDRandom.vector(minMagnitude: number, maxMagnitude: number?): Vector3
    local v = Vector3.new(KDRandom.number(-1, 1), KDRandom.number(-1, 1), KDRandom.number(-1, 1))

    return v.Unit * KDRandom.number(minMagnitude, maxMagnitude or minMagnitude)
end

function KDRandom.angle(): CFrame
    return CFrame.Angles(
        KDRandom.number(-math.pi, math.pi),
        KDRandom.number(-math.pi, math.pi),
        KDRandom.number(-math.pi, math.pi)
    )
end

function KDRandom.sign(): number
    if KDRandom.number() < 0.5 then
        return -1
    else
        return 1
    end
end

--[[
    Returns true or false with the given odds (between 0 and 1).
--]]
function KDRandom.test(chance: number): boolean
    return KDRandom.number(0, 1) < chance
end
KDRandom.chance = KDRandom.test

function KDRandom.normal(): number
    -- inspired by https://github.com/Bytebit-Org/lua-statistics/blob/3bd0c0bdad2c5bbe46efd1895206287aef903d6d/src/statistics.lua#L193-L201
    return math.sqrt(-2 * math.log(KDRandom.number(0.0001, 1))) * math.cos(TWO_PI * KDRandom.number())
end

--[[
    Randomly rounds up or down based on how close it is to either side.
    For example, 1.75 will have a 75% chance of rounding up and 25% of rounding down.
    Similarly, 82.4 will have a 60% chance of rounding down and 40% of rounding up.
    Negative numbers work as expected, -1.99 has a 99% chance of rounding to -2.
--]]
function KDRandom.round(n: number): number
    if KDRandom.test(n % 1) then
        return math.ceil(n)
    else
        return math.floor(n)
    end
end

return KDRandom
