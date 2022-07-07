local KDRandom = {}
KDRandom.rng = Random.new(os.clock())

function KDRandom:linearChoice(options)
    return options[self.rng:NextInteger(1, #options)]
end

function KDRandom:keyChoice(options)
    local keys = table.create(#options)
    for key, _ in pairs(options) do
        table.insert(keys, key)
    end
    
    return self:linearChoice(keys)
end

function KDRandom:choice(options)
    local k = self:keyChoice(options)
    if k == nil then return nil end
    
    return options[k]
end

function KDRandom:weightedChoice(options)
    local totalWeight = 0
    for option, weight in pairs(options) do
        totalWeight += weight
    end
    local winner = self.rng:NextNumber(0, totalWeight)
    
    totalWeight = 0
    for option, weight in pairs(options) do
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

return KDRandom
