local Preload = require(script.Parent:WaitForChild("Preload"))
local Remote = require(script.Parent:WaitForChild("Remote"))
local Utils = require(script.Parent:WaitForChild("Utils"))
local RateLimit = require(script.Parent:WaitForChild("RateLimit"))

local Remotes = {
    list = {},
    rateLimitPools = {},
}
Preload:ensureChildren(script)

for _, instance in script:GetChildren() do
    if Remotes[instance.Name] then
        error(("`%s` is reserved and cannot be used as a KDKit.Remotes name. Sorry!"):format(instance.Name))
    elseif Remotes.list[instance.Name] then
        error(("`%s` occurs multiple times. Remote names must be unique."):format(instance:GetFullName()))
    end

    local rateLimit_Limit = instance:GetAttribute("rateLimit") or 300
    local rateLimit_Period = instance:GetAttribute("rateLimitPeriod") or 60
    local rateLimit_PoolKey = instance:GetAttribute("rateLimitPool") or instance

    local rateLimit = Remotes.rateLimitPools[rateLimit_PoolKey] or RateLimit.new(rateLimit_Limit, rateLimit_Period)
    Remotes.rateLimitPools[rateLimit_PoolKey] = rateLimit

    if rateLimit.limit ~= rateLimit_Limit or rateLimit.period ~= rateLimit_Period then
        error(
            ("Mismatched KDKit.Remotes %s for pool `%s`. Found `%f` on `%s`, but other instances in the same pool have `%f`."):format(
                if rateLimit.limit ~= rateLimit_Limit then "limits" else "periods",
                Utils:repr(rateLimit_PoolKey),
                rateLimit_Limit,
                instance:GetFullName(),
                rateLimit.limit
            )
        )
    end

    Remotes.list[instance.Name] = Remote.new(instance, rateLimit, nil, instance:GetAttribute("nonconcurrent"))
end

return setmetatable(Remotes, { __index = Remotes.list }) -- so you can do Remotes.myRemote(...)
