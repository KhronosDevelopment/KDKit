-- externals 
local KDKit = require(script.Parent)

-- class
local HumanNumbers = {}

HumanNumbers.SUFFIX_MODE = {
    none = "none",
    short = "short",
    long = "long"
}

HumanNumbers.MAGNITUDE_LABEL = {
    [4] = {"K", "Thousand"},
    [7] = {"M", "Million"},
    [10] = {"B", "Billion"},
    [13] = {"T", "Trillion"},
    [16] = {"Q", "Quadrillion"}
}

local INCREMENT_CHAR = {
    ["0"] = "1",
    ["1"] = "2",
    ["2"] = "3",
    ["3"] = "4",
    ["4"] = "5",
    ["5"] = "6",
    ["6"] = "7",
    ["7"] = "8",
    ["8"] = "9",
    ["9"] = "0",
}

function HumanNumbers:smartToString(number)
    if type(number) == "number" then
        return ("%.7f"):format(number), true
    else
        number = tostring(number)
        
        -- make sure this is a real number        
        if number:match("[+-]?%d+%.%d+") ~= number and number:match("[+-]?%d+") ~= number then
            return nil
        end
        
        return number
    end
end

function HumanNumbers:addCommas(number)
    local numberString = self:smartToString(number)
    if not numberString then
        warn("Invalid number '" .. number .. "' passed to HumanNumbers:addCommas. Returning '[error]'.")
    end
    number = numberString
    
    local sign = number:sub(1,1)
    if sign == "+" then
        number = number:sub(2)
        sign = ""
    elseif sign == "-" then
        number = number:sub(2)
    else
        sign = ""
    end
    
    local radix = number:find("%.")   
    if radix then
        -- round to integer
        local fractional = tonumber("0" .. number:sub(radix))
        number = number:sub(1, radix - 1)
        
        if fractional >= 0.5 then
            local chars = {}
            local carry = true
            for i = number:len(), 1, -1 do
                local c = number:sub(i, i)
                
                chars[i] = carry and INCREMENT_CHAR[c] or c
                
                carry = c == "9"
            end
            
            number = table.concat(chars)
            if carry then
                number = "1" .. number
            end
        end
    end
    
    number = number:reverse()
    
    local groups = {}
    for i = 1, number:len(), 3 do
        table.insert(groups, number:sub(i, i + 2))
    end
    
    return sign .. table.concat(groups, ","):reverse()
end

function HumanNumbers:stringify(number, significantFigures, suffix)
    local numberString = self:smartToString(number)
    if not numberString then
        warn("Invalid number '" .. number .. "' passed to HumanNumbers:stringify. Returning '[error]'.")
    end
    number = numberString
end

return HumanNumbers
