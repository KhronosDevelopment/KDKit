local ESCAPE_CHARACTER = "Z"

local UNESCAPED_CHARACTER_REGEX = "[^a-zA-Z0-9_]" -- MUST include the ESCAPE_CHARACTER and all uppercase hexadecimal characters
local CHARACTER_ESCAPING_PATTERN = ("%s%%02X"):format(ESCAPE_CHARACTER)
local ESCAPED_CHARACTER_PATTERN = ("%s([A-Z0-9][A-Z0-9])"):format(ESCAPE_CHARACTER)

local ESCAPED_NUMBER_PREFIX = ("%s_"):format(ESCAPE_CHARACTER)
local NUMBER_ESCAPING_PATTERN = ("%s%%d"):format(ESCAPED_NUMBER_PREFIX)

local Common = {}

function Common:encodeKey(key)
    if type(key) == "number" then
        return NUMBER_ESCAPING_PATTERN:format(key)
    end

    return tostring(key)
        :gsub(ESCAPE_CHARACTER, function(c)
            return CHARACTER_ESCAPING_PATTERN:format(c:byte())
        end)
        :gsub(UNESCAPED_CHARACTER_REGEX, function(c)
            return CHARACTER_ESCAPING_PATTERN:format(c:byte())
        end)
end

function Common:decodeKey(key)
    if key:sub(1, ESCAPED_NUMBER_PREFIX:len()) == ESCAPED_NUMBER_PREFIX then
        return tonumber(key:sub(ESCAPED_NUMBER_PREFIX:len() + 1)) or error(("invalid key: `%s`"):format(key))
    end

    return key:gsub(ESCAPED_CHARACTER_PATTERN, function(hex)
        print("HERE", hex)
        return string.char(tonumber(hex, 16))
    end)
end

return Common
