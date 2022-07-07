-- externals
local IS_SERVER = game:GetService("RunService"):IsServer()
local KDKit = require(script.Parent)

-- utils
local function strip(s)
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function transformWords(s, joiner, wordTransformer)
    local words = {}

    local n = 0
    for w in s:gmatch("%S+") do
        n += 1
        table.insert(words, wordTransformer(w, n))
    end
    
    return table.concat(words, joiner)
end

-- class
local Humanize = {}

function Humanize:capitalize(word)
    return word:sub(1,1):upper() .. word:sub(2):lower()
end

function Humanize:titleCase(s)
    return transformWords(s, ' ', function(w) return self:capitalize(w) end)
end

function Humanize:snakeCase(s)
    return transformWords(s, '_', function(w) return w:lower() end)
end

function Humanize:camelCase(s)
    return transformWords(s, '', function(w, i)
        if i == 1 then
            return w:lower()
        else
            return self:capitalize(w)
        end
    end)
end

function Humanize:pascalCase(s)
    return transformWords(s, '', function(w) return self:capitalize(w) end)
end

function Humanize:upperSnakeCase(s)
    return self:snakeCase(s):upper()
end

function Humanize:letters(s)
    return s:lower():gsub("[^a-z]", "")
end

function Humanize:acronym(s)
    local output = ''
    for w in s:gmatch("%S+") do
        output ..= w:sub(1, 1):upper()
    end
    return output
end

function Humanize:getTimeZone()
    return self:acronym(os.date('%Z'))
end

function Humanize:timestamp(ts, format, add_tz)
    if add_tz == nil and IS_SERVER then
        add_tz = true
    end
    if ts == nil then
        ts = KDKit.Time()
    end
    
    local s = os.date(format or "%Y-%m-%d %I:%M:%S %p")
    
    if add_tz then
        s ..= ' ' .. self:getTimeZone()
    end
    
    return s
end

function Humanize:date(ts, format, add_tz)
    return self:timestamp(ts, "%Y-%m-%d", add_tz)
end

function Humanize:formatSignificantTimeDelta(seconds, long_form)
    local sign = seconds < 0 and "-" or ""
    seconds = math.abs(seconds)
    
    local periods = {
        {1, 60, long_form and {" second", " seconds"} or {"s", "s"}},
        {60, 60, long_form and {" minute", " minutes"} or {"m", "m"}},
        {3600, 24, long_form and {" hour", " hours"} or {"h", "h"}},
        {86400, 7, long_form and {" day", " days"} or {"d", "d"}},
        {86400 * 7, 51, long_form and {" week", " weeks"} or {"w", "w"}},
        {86400 * 365, math.huge, long_form and {" year", " years"} or {"y", "y"}},
    }
    
    for _, period in ipairs(periods) do
        local secondRatio, dontShow, suffixes = table.unpack(period)
        local number = math.round(seconds / secondRatio)
        local suffix = number == 1 and suffixes[1] or suffixes[2]
        
        if number < dontShow then
            return ("%s%.0f%s"):format(sign, number, suffix)
        end
    end
end

local function endsWith(s, suffix)
    return s:sub(s:len() - suffix:len() + 1) == suffix
end

local pluralizeSpecialCases = {
    ["knife"] = "knives"
}
function Humanize:pluralize(word, count)
    if count == 1 then return word end
    
    local knownCorrectWord = pluralizeSpecialCases[strip(word):lower()]
    if knownCorrectWord then
        if word:upper() == word then
            return knownCorrectWord:upper()
        elseif word:lower() == word then
            return knownCorrectWord:lower()
        else
            return self:capitalize(knownCorrectWord)
        end
    end
    
    local ending = 's'
    
    if
        endsWith(word, 's') or
        endsWith(word, 'sh') or 
        endsWith(word, 'ch') or 
        endsWith(word, 'z') or 
        endsWith(word, 'x')
    then
        ending = 'es'
    end
    
    if word:upper() == word then
        ending = ending:upper()
    end
    
    return word .. ending
end

function Humanize:percent(number)
    number *= 100
    
    if number < 0.0009 then -- anything less than 1 in a million is just 0
        return "0%"
    end
    
    if number < 1 then
        return "<1%"
    end
    
    if number >= 9.95 then
        return ("%.0f%%"):format(number)
    end
    
    return ("%.1f%%"):format(number)
end

local hexLetters = {
    [0] = '0', [1] = '1', [2] = '2', [3] = '3',
    [4] = '4', [5] = '5', [6] = '6', [7] = '7',
    [8] = '8', [9] = '9', [10] = 'A', [11] = 'B',
    [12] = 'C', [13] = 'D', [14] = 'E', [15] = 'F',
}

local byteToHex = {}
for high = 0x0, 0xF do
    for low = 0x0, 0xF do
        local i = bit32.bor(bit32.lshift(high, 4), low)
        local s = hexLetters[high] .. hexLetters[low]
        byteToHex[i] = s
    end
end

local hexToByte = {}
for byte, hex in pairs(byteToHex) do
    hexToByte[hex] = byte
end

function Humanize:colorToHex(col)
    local r, g, b = math.round(col.r * 255), math.round(col.g * 255), math.round(col.b * 255)
    return byteToHex[math.clamp(r, 0, 255)] .. byteToHex[math.clamp(g, 0, 255)] .. byteToHex[math.clamp(b, 0, 255)]
end

function Humanize:hexToColor(hex)
    if hex:len() ~= 6 then
        error("Invalid hex code: `" .. tostring(hex) .. "`")
    end
    
    local r, g, b = hex:sub(1, 2), hex:sub(3, 4), hex:sub(5, 6)
    r, g, b = hexToByte[r], hexToByte[g], hexToByte[b]
    
    if not r or not g or not b then
        error("Invalid hex code: `" .. tostring(hex) .. "`")
    end
    
    return Color3.fromRGB(r, g, b)
end

return Humanize
