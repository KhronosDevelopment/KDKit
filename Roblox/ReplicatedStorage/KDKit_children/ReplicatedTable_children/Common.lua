-- conversion utils
local digits = {
    '_',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
}
local ENCODING_BASE = #digits

local digitLookup = {}
for k, v in pairs(digits) do
    digitLookup[v] = k - 1
end

local function divmod(numerator, denominator)
    return math.floor(numerator / denominator), numerator % denominator
end

-- encode/decode utils
local function intToString(int)
    local r
    local out = {}

    while int > 0 do
        int, r = divmod(int, ENCODING_BASE)
        table.insert(out, digits[r + 1])
    end

    return digits[#out] .. table.concat(out)
end

local function stringToInt(str)
    local len = digitLookup[str:sub(1, 1)] + 1
    str = str:sub(2, len + 1)

    local int, mag = 0, 1
    for i = 1, len do
        local char = str:sub(i, i)
        local digit = digitLookup[char]
        int += digit * mag
        mag *= ENCODING_BASE
    end

    return int, len
end

local function intToChar(int)
    local r
    local bytes = {}

    while int > 0 do
        int, r = divmod(int, 256)
        table.insert(bytes, r)
    end

    return string.char(table.unpack(bytes))
end

local function charToInt(c)
    local idx, byt, mag, int = 1, c:byte(1), 1, 0

    repeat
        int += byt * mag

        idx += 1
        byt = c:byte(idx)
        mag *= 256
    until not byt

    return int
end

local function encodeChar(c)
    return intToString(charToInt(c))
end

local function decodeChar(str)
    local int, strlen = stringToInt(str)
    return intToChar(int), strlen
end

-- class
local Common = {}

function Common:encodeReplicatableKeyName(key)
    key = tostring(key)
    
    local out = {}

    local lastBadCharacter = 0
    local badCharacter = key:find("%W")

    while badCharacter do
        table.insert(out, key:sub(lastBadCharacter + 1, badCharacter - 1))
        table.insert(out, "_")
        table.insert(out, encodeChar(key:sub(badCharacter, badCharacter)))

        lastBadCharacter = badCharacter
        badCharacter = key:find("%W", lastBadCharacter + 1)
    end

    table.insert(out, key:sub(lastBadCharacter + 1))

    return table.concat(out)
end

function Common:decodeReplicatableKeyName(key)
    key = tostring(key)
    
    local out = {}
    local chr, len

    local lastEscapeSequenceEndedAt = 0
    local escapeSequenceStart = key:find("_")

    while escapeSequenceStart do
        table.insert(out, key:sub(lastEscapeSequenceEndedAt + 1, escapeSequenceStart - 1))
        chr, len = decodeChar(key:sub(escapeSequenceStart + 1))
        table.insert(out, chr)

        lastEscapeSequenceEndedAt = escapeSequenceStart + 1 + len
        escapeSequenceStart = key:find("_", lastEscapeSequenceEndedAt + 1)
    end
    table.insert(out, key:sub(lastEscapeSequenceEndedAt + 1))

    return table.concat(out)
end

return Common
