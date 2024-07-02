--!strict

local RunService = game:GetService("RunService")
local Utils = require(script.Parent:WaitForChild("Utils"))
local Time = require(script.Parent:WaitForChild("Time"))

--[[
    Humans are unpredictable and like to read data in comfortable formats. This module contains utilities to navigate
    the complex problem of communicating with humans.
--]]
type Casing = { transformer: (string, number) -> string, separator: string }
type TimeUnit = { seconds: number, name: string }
local Humanize = {
    CASING = {
        none = {
            transformer = string.lower,
            separator = " ",
        },
        sentence = {
            transformer = function(word, index)
                if index == 0 then
                    return word:sub(1, 1):upper() .. word:sub(2):lower()
                else
                    return word:lower()
                end
            end,
            separator = " ",
        },
        title = {
            transformer = function(word)
                return word:sub(1, 1):upper() .. word:sub(2):lower()
            end,
            separator = " ",
        },
        pascal = {
            transformer = function(word)
                return word:sub(1, 1):upper() .. word:sub(2):lower()
            end,
            separator = "",
        },
        camel = {
            transformer = function(word, index)
                if index == 1 then
                    return word:lower()
                else
                    return word:sub(1, 1):upper() .. word:sub(2):lower()
                end
            end,
            separator = "",
        },
        snake = { transformer = string.lower, separator = "_" },
        upperSnake = { transformer = string.upper, separator = "_" },
        kebab = { transformer = string.lower, separator = "-" },
        upperKebab = { transformer = string.upper, separator = "-" },
        acronym = {
            transformer = function(word)
                return word:sub(1, 1):lower()
            end,
            separator = "",
        },
        upperAcronym = {
            transformer = function(word)
                return word:sub(1, 1):upper()
            end,
            separator = "",
        },
        dottedAcronym = {
            transformer = function(word)
                return word:sub(1, 1):lower() .. "."
            end,
            separator = "", -- handled within the transformer, since there is a trailing dot
        },
        upperDottedAcronym = {
            transformer = function(word)
                return word:sub(1, 1):upper() .. "."
            end,
            separator = "", -- handled within the transformer, since there is a trailing dot
        },
    } :: { [string]: Casing },
    TIME_UNITS = {
        {
            seconds = 60 * 60 * 24 * (365 + 1 / 4 - 1 / 100 + 1 / 400), -- math is for leap years
            name = "year",
        },
        {
            seconds = 60 * 60 * 24 * 7,
            name = "week",
        },
        {
            seconds = 60 * 60 * 24,
            name = "day",
        },
        {
            seconds = 60 * 60,
            name = "hour",
        },
        {
            seconds = 60,
            name = "minute",
        },
        {
            seconds = 1,
            name = "second",
        },
    } :: { TimeUnit },
    IRREGULAR_NOUNS_PLURALIZATION = {
        -- Based on this list, from an American perspective: http://www.esldesk.com/vocabulary/irregular-nouns
        -- There are a couple of words that have different plural versions depending on the context (i.e. "There are 10 fish in my aquarium." and "I caught 2 fishes today, 15 salmon and 10 tuna.")
        -- and for those words, I just went with what seemed more "generally appropriate". I marked those words as "overgeneralized".
        addendum = "addenda",
        alga = "algae",
        alumna = "alumnae",
        alumnus = "alumni",
        analysis = "analyses",
        antenna = "antennae", -- overgeneralized
        apparatus = "apparatuses",
        appendix = "appendices", -- overgeneralized
        axis = "axes",
        bacillus = "bacilli",
        bacterium = "bacteria",
        basis = "bases",
        beau = "beaux",
        bison = "bison",
        -- buffalo overgeneralized to buffalos by default
        bureau = "bureaus",
        bus = "busses",
        cactus = "cacti", -- overgeneralized
        calf = "calves",
        child = "children",
        corps = "corps",
        corpus = "corpora", -- overgeneralized
        crisis = "crises",
        criterion = "criteria",
        curriculum = "curricula",
        datum = "data",
        deer = "deer",
        die = "dice",
        dwarf = "dwarves", -- overgeneralized
        diagnosis = "diagnoses",
        echo = "echoes",
        elf = "elves",
        ellipsis = "ellipses",
        embargo = "embargoes",
        emphasis = "emphases",
        erratum = "errata",
        fireman = "firemen",
        fish = "fish", -- overgeneralized
        focus = "focuses",
        foot = "feet",
        -- formula overgeneralized to formulas by default
        fungus = "fungi",
        genus = "genera",
        goose = "geese",
        half = "halves",
        hero = "heroes",
        hippopotamus = "hippopotami", -- overgeneralized
        hoof = "hooves", -- overgeneralized
        hypothesis = "hypotheses",
        index = "indices", -- overgeneralized
        knife = "knives",
        leaf = "leaves",
        life = "lives",
        loaf = "loaves",
        louse = "lice",
        man = "men",
        matrix = "matrices",
        means = "means",
        medium = "media",
        memorandum = "memoranda",
        millennium = "milennia", -- overgeneralized
        moose = "moose",
        mosquito = "mosquitoes",
        mouse = "mice",
        nebula = "nebulae", -- overgeneralized
        neurosis = "neuroses",
        nucleus = "nuclei",
        oasis = "oases",
        octopus = "octopi", -- overgeneralized
        ovum = "ova",
        ox = "oxen",
        paralysis = "paralyses",
        parenthesis = "parentheses",
        person = "people",
        phenomenon = "phenomena",
        potato = "potatoes",
        radius = "radii", -- overgeneralized
        scarf = "scarves", -- overgeneralized
        self = "selves",
        series = "series",
        sheep = "sheep",
        shelf = "shelves",
        scissors = "scissors",
        species = "species",
        stimulus = "stimuli",
        stratum = "strata",
        syllabus = "syllabi", -- overgeneralized
        -- symposium overgeneralized to symposiums by default
        synthesis = "syntheses",
        synopsis = "synopses",
        tableau = "tableaux",
        that = "those",
        thesis = "theses",
        thief = "thieves",
        this = "these",
        tomato = "tomatoes",
        tooth = "teeth",
        torpedo = "torpedoes",
        vertebra = "vertebrae",
        veto = "vetoes",
        vita = "vitae",
        watch = "watches",
        wife = "wives",
        wolf = "wolves",
        woman = "women",
    } :: { [string]: string },
}

--[[
    This function is mostly used internally by Humanize.casing(...) which converts between cases,
    but I might as well expose this functionality :shrug:
    Probably best explained through example:
    ```lua
    Humanize.detectCasingAndExtractWords("detectCasingAndExtractWords") -> { "detect", "Casing", "And", "Extract", "Words" }
    Humanize.detectCasingAndExtractWords("thisStringIsInCamelCase") -> { "this", "String", "Is", "In", "Camel", "Case" }
    Humanize.detectCasingAndExtractWords("kebab-case") -> { "kebab", "case" }
    Humanize.detectCasingAndExtractWords("UPPER_SNAKE_CASE") -> { "UPPER", "SNAKE", "CASE" }
    Humanize.detectCasingAndExtractWords("separated by spaces") -> { "separated", "by", "spaces" }
    Humanize.detectCasingAndExtractWords("PascalCaseWithANAcronym") -> { "Pascal", "Case", "With", "ANAcronym" }
    Humanize.detectCasingAndExtractWords("123String456With789Numbers000") -> { "123", "String", "456", "With", "789", "Numbers", "000" }
    Humanize.detectCasingAndExtractWords("complex_-_Strings are \t REASONABLY_SUPPORTED, \n yes---really") -> { "complex", "Strings", "are", "REASONABLY", "SUPPORTED", "yes", "really" }
    ```
--]]
function Humanize.detectCasingAndExtractWords(text: string): { string }
    local words = table.create(16)

    local wordStartedAt: number? = nil
    local previousCharacterIsLetter = false
    local previousCharacterIsNumber = false
    local previousLetterIsLower = false
    for characterIndex = 1, text:len() do
        local character = text:sub(characterIndex, characterIndex)
        local characterIsLetter = Utils.isAlpha(character)
        local characterIsNumber = Utils.isNumeric(character)
        local letterIsUpper = characterIsLetter and (character == character:upper())
        local letterIsLower = characterIsLetter and not letterIsUpper

        if wordStartedAt then -- need to detect if this character ends an existing word
            if letterIsUpper and previousLetterIsLower then
                table.insert(words, text:sub(wordStartedAt, characterIndex - 1))
                wordStartedAt = nil
            elseif previousCharacterIsLetter and not characterIsLetter then
                table.insert(words, text:sub(wordStartedAt, characterIndex - 1))
                wordStartedAt = nil
            elseif previousCharacterIsNumber and not characterIsNumber then
                table.insert(words, text:sub(wordStartedAt, characterIndex - 1))
                wordStartedAt = nil
            end
        end

        if not wordStartedAt then -- need to detect if this character starts a new word
            if letterIsUpper and previousLetterIsLower then
                wordStartedAt = characterIndex
            elseif characterIsLetter and not previousCharacterIsLetter then
                wordStartedAt = characterIndex
            elseif characterIsNumber and not previousCharacterIsNumber then
                wordStartedAt = characterIndex
            end
        end

        previousCharacterIsLetter = characterIsLetter
        previousCharacterIsNumber = characterIsNumber
        previousLetterIsLower = letterIsLower
    end

    if wordStartedAt then
        table.insert(words, text:sub(wordStartedAt))
    end

    return words
end

--[[
    Converts a string to a certain casing. Uses `KDKit.Utils.detectCasingAndExtractWords` to detect words in the source string.

    Supported modes are:
        * none: hello world
        * sentence: Hello world
        * title: Hello World
        * pascal: HelloWorld
        * camel: helloWorld
        * snake: hello_world
        * upperSnake: HELLO_WORLD
        * kebab: hello-world
        * upperKebab: HELLO-WORLD
        * acronym: hw
        * upperAcronym: HW
        * dottedAcronym: h.w.
        * upperDottedAcronym: H.W.
    ```lua
    Humanize.casing("hello world", "pascal") -> "HelloWorld"
    Humanize.casing("HelloWorld", "none") -> "hello world"
    Humanize.casing("HelloWorld", "camel") -> "helloWorld"
    Humanize.casing("complex_-_Strings are \t REASONABLY_SUPPORTED!", "upperKebab") -> "COMPLEX-STRINGS-ARE-REASONABLY-SUPPORTED"
    ```
--]]
function Humanize.casing(text: string, mode: string)
    local casing = Humanize.CASING[mode]
    if not casing then
        error(
            ("Invalid casing mode `%s`. Valid options are %s."):format(
                Utils.repr(mode),
                Humanize.list(Utils.map(function(option)
                    return Utils.repr(option)
                end, Utils.keys(Humanize.CASING)))
            )
        )
    end

    local words = Humanize.detectCasingAndExtractWords(text)
    Utils.imap(casing.transformer, words)
    return table.concat(words, casing.separator)
end

--[[
    Returns a comma separated list.
    ```lua
    Humanize.list({"a", "b", "c"}) -> "a, b, and c"
    Humanize.list({"x"}) -> "x"
    Humanize.list({"a", "b", "c", "d", "e"}, 3, "thing") -> "a, b, c, and 2 other things"
    Humanize.list({"a", "b", "c"}, 2, "item") -> "a, b, and 1 other item"
    ```
--]]
function Humanize.list(array: { string }, maxItems: number?, name: string?)
    if not Utils.isLinearArray(array) then
        error("You may only pass linear arrays to `KDKit.Humanize.list`.")
    end
    local n = #array

    if maxItems then
        name = name or "item"
        local extra = n - maxItems
        local show = math.min(maxItems, n)
        local items = table.create(show + 1)

        for i = 1, show do
            local v = array[i]
            if type(v) ~= "string" then
                items[i] = Utils.repr(v)
            else
                items[i] = v
            end
        end

        if extra > 0 then
            table.insert(items, ("and %d other %s"):format(extra, Humanize.plural(name :: string, extra)))
        else
            items[n] = "and " .. items[n]
        end

        return table.concat(items, ", ")
    else
        local items = Utils.map(function(item)
            if type(item) ~= "string" then
                return Utils.repr(item)
            else
                return item
            end
        end, array)

        if n > 1 then
            items[n] = "and " .. items[n]
        end

        return table.concat(items, ", ")
    end
end

--[[
    Format the provided timestamp using the given format specifier and optionally with the timezone.
    If a timestamp is not provided, then the current time will be used.
    If a format is not specified, then an iso8601-like format will be used. Specifically, `YYYY-MM-DD HH:MM:SS PP`.
    By default a timezone will be appended if rendered on the server, and no timezone if rendered on the client.
    ```lua
    Humanize.timestamp(0, nil, true) -> "1970-01-01 12:00:00 AM GMT"
    ```
--]]
function Humanize.timestamp(unixTimestamp: number, format: string?, addTimezone: boolean?): string
    -- on the server, add the timezone by default
    -- but on the client, the player likely already knows
    -- what timezone they are in, so do *not* add it by default.
    if addTimezone == nil and RunService:IsServer() then
        addTimezone = true
    end

    local str = os.date(format or "%Y-%m-%d %I:%M:%S %p", unixTimestamp or Time())

    if addTimezone then
        str ..= " " .. Humanize.casing(
            os.date("%Z"), -- ex: "Pacific Daylight Time"
            "upper_acronym"
        )
    end

    return str
end

--[[
    This function is a proxy to `Humanize.timestamp` but with the format `%Y-%m-%d`.
    ```lua
    Humanize.date(0) -> "1970-01-01"
    ```
--]]
function Humanize.date(unixTimestamp: number, addTimezone: boolean?): string
    return Humanize.timestamp(unixTimestamp, "%Y-%m-%d", addTimezone)
end

--[[
    Returns a string containing a single unit which represents a delta in time.
    ```lua
    Humanize.timeDelta(10) -> "10 seconds"
    Humanize.timeDelta(65) -> "1 minute"
    Humanize.timeDelta(90) -> "1 minute"
    Humanize.timeDelta(120) -> "2 minutes"
    Humanize.timeDelta(3600) -> "1 hour"
    Humanize.timeDelta(86400) -> "1 day"
    Humanize.timeDelta(86400 * 7) -> "1 week"
    Humanize.timeDelta(86400 * 365) -> "1 year"

    Humanize.timeDelta(10, true) -> "10s"
    Humanize.timeDelta(300, true) -> "5m"
    Humanize.timeDelta(86400 * 365, true) -> "1y"

    Humanize.timeDelta(-10, true) -> "-10s"
    Humanize.timeDelta(-86400 * 7 * 3) -> "-3 weeks"
    ```
--]]
function Humanize.timeDelta(seconds: number, short: boolean?): string
    local sign = seconds < 0 and "-" or ""
    seconds = math.abs(seconds)

    local value
    local unit
    for _, unitOption in Humanize.TIME_UNITS do
        unit = unitOption
        value = math.floor(seconds / unit.seconds)
        if value >= 1 then
            break
        end
    end

    if short then
        return ("%s%d%s"):format(sign, value, unit.name:sub(1, 1))
    else
        return ("%s%d %s"):format(sign, value, Humanize.plural(unit.name, value))
    end
end

--[[
    Pluralizes the provided word, optionally based on a number.
    Reasonably handles most irregular nouns, like "bus" -> "busses".

    ```lua
    Humanize.plural("item") -> "items"
    Humanize.plural("knife") -> "knives"
    Humanize.plural("Option") -> "Options"
    Humanize.plural("LIST") -> "LISTS"
    Humanize.plural("example", 5) -> "examples"
    Humanize.plural("example", 1) -> "example"
    Humanize.plural("example", 0) -> "examples"
    Humanize.plural("STUFF", 5) -> "STUFFS"
    Humanize.plural("fish", 5) -> "fish"
    ```
--]]
function Humanize.plural(word: string, count: number?): string
    if count == 1 then
        return word
    end

    local irregularPluralVersion = Humanize.IRREGULAR_NOUNS_PLURALIZATION[Utils.strip(word):lower()]
    if irregularPluralVersion then
        if Utils.isUpper(word) then
            return irregularPluralVersion:upper()
        elseif Utils.isLower(word) then
            return irregularPluralVersion:lower()
        else
            return Humanize.casing(irregularPluralVersion, "sentence")
        end
    end

    local ending = "s"
    if
        Utils.endsWith(word, "s")
        or Utils.endsWith(word, "sh")
        or Utils.endsWith(word, "ch")
        or Utils.endsWith(word, "z")
        or Utils.endsWith(word, "x")
    then
        ending = "es"
    end

    if Utils.isUpper(word) then
        ending = ending:upper()
    end

    return word .. ending
end

--[[
    An opinionated way of formatting the odds of something happening.
    Anything less than or equal to one in a million will be formatted as "0%".
    Anything less than one in one hundred will be formatted as "<1%".
    Otherwise, the percent is formatted using two significant figures. (maxing out at 100%)
    ```lua
    Humanize.percent(-0.5) -> "0%"
    Humanize.percent(1 / 1_000_000) -> "0%"
    Humanize.percent(0.1 / 100) -> "<1%"
    Humanize.percent(5 / 100) -> "5%"
    Humanize.percent(5.3 / 100) -> "5.3%"
    Humanize.percent(73.8 / 100) -> "74%"
    Humanize.percent(99.9999 / 100) -> "99%"
    Humanize.percent(100 / 100) -> "100%"
    Humanize.percent(500 / 100) -> "100%"
    ```
--]]
function Humanize.percent(odds: number): string
    if odds <= 1 / 1_000_000 then
        return "0%"
    end

    if odds < 1 / 100 then
        return "<1%"
    end

    if odds >= 1 then
        return "100%"
    elseif odds >= 0.995 then -- %.2g would round to "1e+02%" above this point
        return "99%"
    end

    return ("%.2g%%"):format(odds * 100)
end

--[[
    Beautifully formats a number with several options:
        - decimalPlaces (7)          : how many decimal places should be included? (e.g. 3.14 vs vs 3.14159 vs 3.1415926535)
        - addCommas (false)          : add commas between thousands groups? (e.g. 1000000 vs 1,000,000)
        - removeTrailingZeros (true) : should redundant zeros after the radix get removed? (e.g. 123.456000 vs 123.456)
    ```lua
    Humanize.number(1) -> "1"
    Humanize.number(123.456) -> "123.456"
    Humanize.number(2 / 3, { decimalPlaces = 3 }) -> "0.667"
    Humanize.number(math.pi * 1000000, { addCommas = true, decimalPlaces = 4 }) -> "3,141,592.6536"
    Humanize.number(1, { decimalPlaces = 4, removeTrailingZeros = false }) -> "1.0000"
    ```
--]]
type NumberFmtOptions = { decimalPlaces: number?, addCommas: boolean?, removeTrailingZeros: boolean? }
function Humanize.number(number: number, options: NumberFmtOptions): string
    options.decimalPlaces = options.decimalPlaces or 7
    options.addCommas = options.addCommas or false
    if options.removeTrailingZeros == nil then
        options.removeTrailingZeros = true
    end

    local fmt = "%." .. (options.decimalPlaces :: number) .. "f"
    local str = fmt:format(number)

    if options.addCommas then
        local prefix = ""
        if str:sub(1, 1) == "-" then
            prefix = "-"
            str = str:sub(2)
        end

        local suffix = ""
        local radix = str:find("%.")
        if radix then
            suffix = str:sub(radix)
            str = str:sub(1, radix - 1)
        end

        local reversedGroups = {}
        for reverseGroup in str:reverse():gmatch("..?.?") do
            table.insert(reversedGroups, reverseGroup)
        end

        str = prefix .. table.concat(reversedGroups, ","):reverse() .. suffix
    end

    if options.removeTrailingZeros then
        str = (str:match("(.*%.[1-9]*)0*$") or str):gsub("%.$", "")
    end

    return str
end

--[[
    Simply a shortcut for Humanize.number(x, { addCommas = true, decimalPlaces = 0 })
--]]
function Humanize.integer(number: number): string
    return Humanize.number(number, { addCommas = true, decimalPlaces = 0 })
end

--[[
    Formats a number which represents money. Always rounds towards 0.
    You may specify whether or not you want to include cents (default: yes) and optionally a unit (default: none).
    ```lua
    "$" .. Humanize.money(1) -> "$1.00"
    "$" .. Humanize.money(15.8277) -> "$15.82"
    Humanize.money(25.87, true) -> "25"
    Humanize.money(13, true) -> "13"
    Humanize.money(5, true, "dollar") -> "5 dollars"
    Humanize.money(3, true, "gem") -> "5 gems"
    Humanize.money(85.98, false, "pound") -> "85.98 pounds"
    ```
--]]
function Humanize.money(number: number, noCents: boolean?, unit: string?): string
    if noCents then
        number = math.floor(number)
    else
        number = math.floor(number) + math.floor((number % 1) * 100) / 100
    end

    local result, _ = Humanize.number(number, {
        addCommas = true,
        decimalPlaces = if noCents then 0 else 2,
        removeTrailingZeros = false,
    }):gsub("%.00$", "")

    if unit then
        if not (result == "1.00" or result == "-1.00" or result == "1" or result == "-1") then
            unit = Humanize.plural(unit)
        end

        return ("%s %s"):format(result, unit)
    else
        return result
    end
end

--[[
    Converts a string to hexadecimal representation.
    ```lua
    Humanize.hex("hello") -> "68656C6C6F"
    Humanize.hex("\0\n\t\v\0") -> "000A090B00"
    ```
--]]
function Humanize.hex(string: string): string
    return string:gsub(".", function(c)
        return ("%02X"):format(c:byte())
    end)
end

--[[
    Logical opposite of `KDKit.Humanize.hex`. Converts a string from hexadecimal representation.
    ```lua
    Humanize.unhex("68656C6C6F") -> "hello"
    Humanize.hex("000A090B00") -> "\0\n\t\v\0"
    ```
--]]
function Humanize.unhex(hex: string): string
    return hex:gsub("..", function(h)
        return string.char(tonumber(h, 16) or 0)
    end)
end

--[[
    Converts a given Color3 as a hexadecimal color code string.
    ```lua
    Humanize.colorToHex(Color3.fromRGB(0, 0, 0)) -> "000000"
    Humanize.colorToHex(Color3.fromRGB(59, 124, 217)) -> "3B7CD9"
    Humanize.colorToHex(Color3.fromRGB(255, 255, 255)) -> "FFFFFF"
    ```
--]]
function Humanize.colorToHex(color: Color3): string
    return ("%02X%02X%02X"):format(
        math.clamp(math.round(color.R * 255), 0, 255),
        math.clamp(math.round(color.G * 255), 0, 255),
        math.clamp(math.round(color.B * 255), 0, 255)
    )
end

--[[
    Logical opposite of colorToHex. Returns a Color3 given the hexadecimal color code string.
    ```lua
    Humanize.colorToHex("000000") -> Color3.fromRGB(0, 0, 0)
    Humanize.colorToHex("3B7CD9") -> Color3.fromRGB(59, 124, 217)
    Humanize.colorToHex("FFFFFF") -> Color3.fromRGB(255, 255, 255))
    ```
--]]
function Humanize.hexToColor(hex: string): Color3
    if hex:len() ~= 6 then
        error(("Invalid hex code: %s"):format(Utils.repr(hex)))
    end

    local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)

    if not r or not g or not b then
        error(("Invalid hex code: %s"):format(Utils.repr(hex)))
    end

    return Color3.fromRGB(r, g, b)
end

return Humanize
