local HttpService = game:GetService("HttpService")

--[[
    KDKit.Utils is a collection of various utility functions that are "missing" from the standard library and the language itself.
    Yes, all of KDKit could be considered a "collection of various utility functions", but these are functions which don't quite
    fit in anywhere else and aren't large enough to deserve their own submodule.
--]]
local Utils = {
    PRIMITIVE_TYPES = { string = true, boolean = true, number = true, ["nil"] = true },
}

--[[
    Ensures that the first function runs after the second one does, regardless of if the second function errors.
    ```lua
    Utils:ensure(function(failed, traceback)
        if failed then
            print("uh oh, something went wrong :(", traceback) -- prints traceback including "im throwing an error"
        else
            print("worked!")
        end
    end, error, "im throwing an error")
    ```
--]]
function Utils:ensure<A, T>(callback: () -> any, func: (...A) -> T, ...: A): T
    local funcResults = table.pack(xpcall(func, debug.traceback, ...))
    local funcSuccess = table.remove(funcResults, 1)

    local cbResults = table.pack(xpcall(callback, debug.traceback, not funcSuccess, table.unpack(funcResults)))
    local cbSuccess = table.remove(cbResults, 1)

    if not cbSuccess then
        task.defer(
            error,
            ("The following error occurred during the callback to a KDKit.Utils.ensure call. The error was ignored.\n%s"):format(
                cbResults[1]
            )
        )
    end

    if not funcSuccess then
        error(("The following error occurred during a KDKit.Utils.ensure call.\n%s"):format(funcResults[1]))
    end

    return table.unpack(funcResults)
end

--[[
    Returns the keys of the table.
    ```lua
    Utils:keys({a=1, b=2, c=3}) -> { "a", "b", "c" }
    Utils:keys({"a", "b", "c"}) -> { 1, 2, 3 }
    ```
--]]
function Utils:keys<K>(tab: { [K]: any }): { K }
    local keys = table.create(16)
    for key, _value in tab do
        table.insert(keys, key)
    end
    return keys
end

--[[
    Simply removes surrounding whitespace from a string.
    Similar to Python's builtin `str.strip` method.

    ```lua
    Utils:strip("  hello there  ") -> "hello there"
    Utils:strip(" \n\t it strips all types of whitespace \n like this \n\t ") -> "it strips all types of whitespace \n like this"
    ```
--]]
function Utils:strip(str: string): string
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

--[[
    Splits the provided string based on the given delimiter into a table of substrings. By default, splits on groups of whitespace.
    Similar to Python's builtin `str.strip` method.

    ```lua
    Utils:split("Hello there, my name is Gabe!") -> { "Hello", "there,", "my", "name", "is", "Gabe!" }
    Utils:split("  \r\n whitespace   is  \t\t    stripped   \n ") -> { "whitespace", "is", "stripped" }
    Utils:split("a_b_c", "_") -> { "a", "b", "c" }
    Utils:split("abc123xyz", "%d") -> { "abc", "xyz" }
    ```
--]]
function Utils:split(str: string, delimiter: string?): { string }
    local words = table.create(16)

    local wordPattern = if delimiter then ("[^%s]+"):format(delimiter) else "%S+"
    for word in str:gmatch(wordPattern) do
        table.insert(words, word)
    end

    return words
end

--[[
    Calls the provided `transform` function on each value in the table.
    Modifies the table [i]n place, does not make a copy.

    ```lua
    local x = { 1, 2, 3 }
    Utils:imap(function(v) return v * v end, x)
    print(x) -> { 1, 4, 9 }
    ```
--]]
function Utils:imap<K, V, T>(transform: (value: V, key: K) -> T, tab: { [K]: V }): nil
    for key, value in tab do
        tab[key] = transform(value, key)
    end
end

--[[
    Returns a new table whose values have been transformed by the provided `transform` function.
    Similar to Python's builtin `map` function, but is eagerly evaluated.

    ```lua
    Utils:map(function(v) return v ^ 3 end, { 1, 2, 3 }) -> { 1, 8, 27 }
    ```
--]]
function Utils:map<K, V, T>(transform: (value: V, key: K) -> T, tab: { [K]: V }): { [K]: T }
    local copy = table.clone(tab)
    self:imap(transform, copy)
    return copy
end

--[[
    Returns a string which represents the provided value while retaining as much information as possible about the value.
    Similar to Python's builtin `repr` function.
--]]
function Utils:repr(x: any, tableVerbosity: number?, alreadySeenTables: table?): string
    tableVerbosity = math.floor(tableVerbosity or 10)
    alreadySeenTables = alreadySeenTables or table.create(16)

    local tx = typeof(x)
    if tx == "string" then
        return ("'%s'"):format(x)
    elseif tx == "number" then
        if x % 1 == 0 then
            return ("%d"):format(x)
        else
            return ("%g"):format(x)
        end
    elseif tx == "nil" then
        return "nil"
    elseif tx == "boolean" then
        return tostring(x)
    elseif tx == "table" then
        if alreadySeenTables[x] then
            return "<cyclic table detected> " .. tostring(x)
        end
        local parts = table.create(8)

        alreadySeenTables[x] = true
        local n = 0
        local function process(key, value)
            if n < tableVerbosity then
                table.insert(
                    parts,
                    ("[%s] = %s"):format(
                        self:repr(key, math.min(tableVerbosity, math.max(3, tableVerbosity / 2)), alreadySeenTables),
                        self:repr(value, math.min(tableVerbosity, math.max(3, tableVerbosity / 2)), alreadySeenTables)
                    )
                )
                n += 1
                return true
            else
                table.insert(parts, "...")
                return false
            end
        end

        if getmetatable(x) and rawget(getmetatable(x), "__call") and not rawget(getmetatable(x), "__iter") then
            for key, value in pairs(x) do
                if not process(key, value) then
                    break
                end
            end
        else
            for key, value in x do
                if not process(key, value) then
                    break
                end
            end
        end
        alreadySeenTables[x] = nil

        return "{ " .. table.concat(parts, ", ") .. " }"
    elseif tx == "EnumItem" then
        return tostring(x)
    elseif tx == "Enum" then
        return ("Enum.%s"):format(x)
    elseif tx == "Instance" then
        return ("<Instance.%s> %s"):format(x.ClassName, x:GetFullName())
    else
        return ("<Unrepresentable type `%s`> %s"):format(tx, tostring(x))
    end
end

--[[
    return true if the provided string only contains alphabet characters [a-zA-Z]
    similar to Python's builtin `str.isalpha` method
    ```lua
    Utils:isAlpha("Hello") -> true
    Utils:isAlpha("Hello!") -> false
    Utils:isAlpha("hello there") -> false
    Utils:isAlpha("iHave3Apples") -> false
    Utils:isAlpha("") -> true
    ```
--]]
function Utils:isAlpha(str: string): boolean
    return str:match("[^a-zA-Z]") == nil
end

--[[
    returns true if the provided string does not contain lowercase letters [a-z]
    similar to Python's builtin `str.isupper` method, but handles non-alpha characters differently
    ```lua
    Utils:isUpper("HELLO") -> true
    Utils:isUpper("Hello") -> false
    Utils:isUpper("hello") -> false
    Utils:isUpper("HELLO123") -> true
    Utils:isUpper("123") -> true
    Utils:isUpper("") -> true
    ```
--]]
function Utils:isUpper(str: string): boolean
    return str:match("[a-z]") == nil
end

--[[
    returns true if the provided string does not contain uppercase letters [A-Z]
    similar to Python's builtin `str.islower` method, but handles non-alpha characters differently
    ```lua
    Utils:isLower("hello") -> true
    Utils:isLower("Hello") -> false
    Utils:isLower("HELLO") -> false
    Utils:isLower("hello123") -> true
    Utils:isLower("123") -> true
    Utils:isLower("") -> true
    ```
--]]
function Utils:isLower(str: string): boolean
    return str:match("[A-Z]") == nil
end

--[[
    return true if the provided string only contains decimal characters [0-9]
    similar to Python's builtin `str.isnumeric` method, but stricter

    !! Warning: returns false when the string contains a period `.` or a negative sign `-`
    ```lua
    Utils:isNumeric("123") -> true
    Utils:isNumeric("123.456") -> false
    Utils:isNumeric("-5") -> false
    Utils:isNumeric("hello") -> false
    Utils:isNumeric("") -> true
    ```
--]]
function Utils:isNumeric(str: string): boolean
    return str:match("[^0-9]") == nil
end

--[[
    return true if the provided string only contains alphanumeric characters [a-zA-Z0-9]
    similar to Python's builtin `str.isalphanum` method
    ```lua
    Utils:isAlphanumeric("abc123") -> true
    Utils:isAlphanumeric("abc") -> true
    Utils:isAlphanumeric("123") -> true
    Utils:isAlphanumeric("abc 123") -> false
    Utils:isAlphanumeric("123 + 456") -> false
    Utils:isAlphanumeric("hello!") -> false
    Utils:isAlphanumeric("123.456") -> false
    Utils:isAlphanumeric("") -> true
    ```
--]]
function Utils:isAlphanumeric(str: string): boolean
    return str:match("[^0-9a-zA-Z]") == nil
end

--[[
    returns true if the provided string starts with the provided prefix
    similar to Python's builtin `string.startswith` method
    ```lua
    Utils:startsWith("hello world", "hello") -> true
    Utils:startsWith("abcdefg", "abc") -> true
    Utils:startsWith("abcdefg", "xyz") -> false
    Utils:startsWith("abcdefg", "") -> true
    Utils:startsWith("", "abc") -> false
    ```
--]]
function Utils:startsWith(str: string, prefix: string): boolean
    return str:sub(1, prefix:len()) == prefix
end

--[[
    returns true if the provided string ends with the provided suffix
    similar to Python's builtin `string.endswith` method
    ```lua
    Utils:endsWith("hello world", "world") -> true
    Utils:endsWith("abcdefg", "efg") -> true
    Utils:endsWith("abcdefg", "xyz") -> false
    Utils:endsWith("abcdefg", "") -> true
    Utils:endsWith("", "abc") -> false
    ```
--]]
function Utils:endsWith(str: string, suffix: string): boolean
    return str:sub(str:len() - suffix:len() + 1) == suffix
end

--[[
    returns true if and only if the keys in the provided table are continuous increasing integers that start at 1
    ```lua
    Utils:isLinearArray({ "a", "b", "c" }) -> true
    Utils:isLinearArray({ "a", "b", "c", extra = "d" }) -> false
    Utils:isLinearArray({ a = 1, b = 2, c = 3 }) -> false
    Utils:isLinearArray({ [2] = "a", [1] = "b", [3] = "c" }) -> true
    Utils:isLinearArray({ [2] = "a", [3] = "c" }) -> false
    ```
--]]
function Utils:isLinearArray(x: table): boolean
    local last = 0
    for key, _value in x do
        if key ~= last + 1 then
            return false
        end
        last = key
    end

    return true
end

--[[
    Returns a copy of the provided table whose nesting depth does not exceed the provided parameter.
    If the parameter is not a table, then it is returned without adjustment
    unless the depth parameter is < 0, then `"<exceeded maximum depth>"` is returned.
    ```lua
    Utils:truncateAfterMaxDepth({ a = 1, b = 2, c = { 1, 2, 3 }}, 1) -> { a = 1, b = 2, c = "<exceeded maximum depth>" }
    ```
--]]
function Utils:truncateAfterMaxDepth(x: any, depth: number): any
    if depth < 0 then
        return "<exceeded maximum depth>"
    elseif type(x) ~= "table" then
        return x
    end

    local copy = table.clone(x)

    for key, value in copy do
        copy[key] = self:truncateAfterMaxDepth(value, depth - 1)
    end

    return copy
end

--[[
    Returns a *deep copy* of the table, which is guaranteed to be generally serializable, while losing as little information as possible.
    Specifically designed to be serialized via JSON.
    ```lua
    Utils:makeSerializable({ "hi", true, workspace.MyPart, Enum.Material.Wood, { "sub table", value = 123 } })
     -> { "hi", true, "<Instance.Part> Workspace.MyPart", "Enum.Material.Wood", { ["1"] = "sub table", value = 123 } }
    ```
--]]
function Utils:makeSerializable(tab: any, alreadySeen: table?): table
    if type(tab) ~= "table" then
        tab = { data = tab }
    end

    alreadySeen = alreadySeen or table.create(16)
    local isLinearArray = self:isLinearArray(tab)
    local copy = table.create(if isLinearArray then #tab else 16)

    if alreadySeen[tab] then
        return "<cyclic table detected> " .. tostring(tab)
    end

    alreadySeen[tab] = true
    for key, value in tab do -- if you ever get an error here, it's most likely because you implemented `__call` without implementing `__iter`
        -- generally, arrays OR hashmaps are serializable
        -- but in Lua we mix both of those into a single `table` type.
        -- If the table can be represented as an array (with continuous increasing integer keys)
        -- then do so. Otherwise, stringify all of the keys and go full hashmap.
        if not isLinearArray and type(key) ~= "string" then
            key = self:repr(key)
        end

        -- values must be primitive or serializable tables
        local tv = type(value)
        if Utils.PRIMITIVE_TYPES[tv] then
            -- pass
        elseif tv == "table" then
            value = self:makeSerializable(value, alreadySeen)
        else
            value = self:repr(value)
        end

        copy[key] = value
    end
    alreadySeen[tab] = nil

    return copy
end

--[[
    Returns a JSON string representing the provided data without throwing an error.
    If the data contains non-serializable values, an attempt will be made to retain as much information as possible.
    See KDKit.Utils.makeSerializable
    ```lua
    Utils:safeJSONEncode({ "hi", true, workspace.MyPart, Enum.Material.Wood, { "sub table", value = 123 } })
     -> '["hi", true, "<Instance.Part> Workspace.MyPart", "Enum.Material.Wood", {"1": "sub table", "value": 123}]'
    ```
--]]
function Utils:safeJSONEncode(data: any): string
    return HttpService:JSONEncode(self:makeSerializable(data))
end

--[[
    Sort a table (in-place) using a function to extract a comparable value.
    Similar to passing a `key` to Python's builtin `list.sort` function.
    You may also return a table to include tiebreakers.
--]]
function Utils:isort<K, V>(tab: { [K]: V }, key: ((value: V) -> any)?): nil
    local rankings = table.create(#tab)
    local aRanking, bRanking, aRank, bRank

    table.sort(tab, function(a, b)
        aRanking = rankings[a] or key(a)
        bRanking = rankings[b] or key(b)
        rankings[a] = aRanking
        rankings[b] = bRanking

        if type(aRanking) == "table" and type(bRanking) == "table" then
            for i = 1, math.huge do
                aRank, bRank = aRanking[i], bRanking[i]

                if aRank == nil then
                    if bRank == nil then
                        return false -- order not important
                    else
                        return true -- nothing comes before something
                    end
                elseif bRank == nil then
                    return false -- nothing comes before something
                elseif aRank == bRank then
                    continue -- this priority level is not decisive, move to next one
                else
                    return aRank < bRank
                end
            end
        else
            return aRanking < bRanking
        end
    end)
end

--[[
    Similar to Utils.isort, but makes a copy first.
--]]
function Utils:sort<K, V>(tab: { [K]: V }, key: ((value: V) -> any)?): { [K]: V }
    tab = table.clone(tab)
    self:isort(tab, key)
    return tab
end

--[[
    Returns true if the first object is visibly on top of the second gui object.
    Useful for detecting which object is currently visible at a certain point on a client's screen.
--]]
function Utils:guiObjectIsOnTopOfAnother(a: GuiObject, b: GuiObject): boolean
    local aGui = a:FindFirstAncestorOfClass("ScreenGui")
        or a:FindFirstAncestorOfClass("SurfaceGui")
        or a:FindFirstAncestorOfClass("BillboardGui")

    local bGui = b:FindFirstAncestorOfClass("ScreenGui")
        or b:FindFirstAncestorOfClass("SurfaceGui")
        or b:FindFirstAncestorOfClass("BillboardGui")

    -- make sure that they're both even in a Gui
    if aGui and not bGui then
        return true
    elseif bGui and not aGui then
        return false
    elseif not aGui and not bGui then
        return nil -- ambiguous
    end

    -- different gui? ez pz
    if aGui ~= bGui then
        -- prioritize ScreenGui over world Guis
        if aGui:IsA("ScreenGui") and not bGui:IsA("ScreenGui") then
            return true
        elseif not aGui:IsA("ScreenGui") and bGui:IsA("ScreenGui") then
            return false
        end

        -- they are both on the same "surface", just compare DisplayOrder
        if aGui.DisplayOrder ~= bGui.DisplayOrder then
            return aGui.DisplayOrder > bGui.DisplayOrder
        else
            -- descendant?
            if bGui:IsDescendantOf(aGui) then
                return false
            elseif aGui:IsDescendantOf(bGui) then
                return true
            end

            return nil -- ambiguous
        end
    end

    -- the guis are the same
    local gui = aGui -- or bGui, they're equal

    -- global indexing mode? ez pz
    local global = gui.ZIndexBehavior == Enum.ZIndexBehavior.Global
    if global then
        if a.ZIndex ~= b.ZIndex then
            return a.ZIndex > b.ZIndex
        else
            return nil -- ambiguous
        end
    end

    -- child of one another? ez pz
    if b:IsDescendantOf(a) then
        return false
    elseif a:IsDescendantOf(b) then
        return true
    end

    -- not a simple comparison,
    -- will have to build ancestor tree
    -- and do full check

    -- they are ancestors of themselves
    -- it is impossible for these to ever be matched
    -- as a common ancestor because of the above :IsDescendantOf check
    -- but it simplifies the checks later on
    local aAncestors = { [a] = true }
    local bAncestors = { [b] = true }

    -- find first common ancestor
    -- note: something is guaranteed to be found since
    -- `a` and `b` share the same `gui` ancestor
    local firstCommonAncestor = nil
    local aAncestor = a
    local bAncestor = b
    while not firstCommonAncestor do
        if aAncestor.Parent then
            aAncestor = aAncestor.Parent
            aAncestors[aAncestor] = true
        end
        if bAncestor.Parent then
            bAncestor = bAncestor.Parent
            bAncestors[bAncestor] = true
        end

        if bAncestors[aAncestor] then
            firstCommonAncestor = aAncestor
        elseif aAncestors[bAncestor] then
            firstCommonAncestor = bAncestor
        end
    end

    local aFirstDescendantOfCommonAncestor, bFirstDescendantOfCommonAncestor
    for _, v in ipairs(firstCommonAncestor:GetChildren()) do
        if aAncestors[v] then
            aFirstDescendantOfCommonAncestor = v
        elseif bAncestors[v] then
            bFirstDescendantOfCommonAncestor = v
        end
    end

    if aFirstDescendantOfCommonAncestor.ZIndex ~= bFirstDescendantOfCommonAncestor.ZIndex then
        return aFirstDescendantOfCommonAncestor.ZIndex > bFirstDescendantOfCommonAncestor.ZIndex
    else
        return nil -- ambiguous
    end
end

--[[
    Merges the second table into the first one.
    ```lua
    local x = { a = 1, b = 2, c = 3 }
    local y = { a = 2, b = 3, d = 4 }

    Utils:imerge(x, y)

    x -> { a = 2, b = 3, c = 3, d = 4 } -- (a, b, and d modified in place)
    y -> { a = 2, b = 3, d = 4 } -- (unchanged)
    ```
--]]
function Utils:imerge<K1, V1, K2, V2>(dst: { [K1]: V1 }, src: { [K2]: V2 })
    for key, value in src do
        dst[key] = value
    end
end

--[[
    Same as Utils:imerge but makes a copy first.
    ```lua
    Utils:merge({ a = 1, b = 2 }, { a = 2, c = 3 }}) -> { a = 2, b = 2, c = 3 }
    ```
--]]
function Utils:merge<K1, V1, K2, V2>(dst: { [K1]: V1 }, src: { [K2]: V2 }): { [K1 | K2]: V1 | V2 }
    dst = table.clone(dst)
    self:imerge(dst, src)
    return dst
end

--[[
    Inserts all elements from the right list into the left list.
    Similar to Python's builtin `list.extend`
    ```lua
    local x = { 'a', 'b' }
    local y = { 'c', 'd' }

    Utils:iextend(x, y)

    x -> { 'a', 'b', 'c', 'd' } -- (c and d inserted)
    y -> { 'c', 'd' } -- (unchanged)
    ```
--]]
function Utils:iextend<V1, V2>(left: { V1 }, right: { V2 }): nil
    table.move(right, 1, #right, #left + 1, left)
end

--[[
    Same as Utils:iextend but makes a copy first.
    ```lua
    Utils:extend({ 'a', 'b' }, { 'c', 'd' }) -> { 'a', 'b', 'c', 'd' }
    ```
--]]
function Utils:extend<V1, V2>(left: { V1 }, right: { V2 }): { V1 | V2 }
    left = table.clone(left)
    self:iextend(left, right)
    return left
end

--[[
    Linear interpolation.
    ```lua
    Utils:lerp(0, 20, 0.1) -> 2
    ```
--]]
function Utils:lerp(a: number, b: number, f: number): number
    return (b - a) * f + a
end

--[[
    Inverse of Utils.lerp
    ```lua
    Utils:unlerp(10, 20, 12) -> 0.2
    ```
--]]
function Utils:unlerp(a: number, b: number, x: number): number
    return (x - a) / (b - a)
end

--[[
    Checks if the given value is callable, i.e. that it is a function or a callable table.
--]]
function Utils:callable(maybeCallable: any): boolean
    if type(maybeCallable) == "function" then
        return true
    elseif type(maybeCallable) == "table" and type(rawget(getmetatable(maybeCallable), "__call")) == "function" then
        return true
    end

    return false
end

--[[
    Gets the attribute, if present, otherwise returns the provided default value.
    Similar to Python's builtin `getattr`
    ```lua
    Utils:getattr({a = 123}, 'b', 456) -> 456
    Utils:getattr(Vector3.new(), 'blah') -> nil
    ```
--]]
function Utils:getattr(x: any, attr: any, default: any)
    local s, r = pcall(function()
        return x[attr]
    end)

    if not s or r == nil then
        return default
    end

    return r
end

--[[
    Pretty simple. Welds two parts together using a WeldConstraint.
    Note that you will need to set the parent of the returned WeldConstraint in order to make it effective.
--]]
function Utils:weld(a: BasePart, b: BasePart, reuse: WeldConstraint): WeldConstraint
    local weld = reuse or Instance.new("WeldConstraint")

    weld.Part0 = a
    weld.Part1 = b
    weld.Enabled = true

    return weld
end

--[[
    Returns a function that, when invoked, will access the provided key.
--]]
function Utils:plucker(attribute: string): (value: any) -> any
    return function(value: string)
        return value[attribute]
    end
end

--[[
    Basically equivalent to Utils:imap(tab, Utils:plucker(attribute))
--]]
function Utils:ipluck<K, V, T>(plucker: string | (value: K, key: V) -> T, tab: { [K]: V }): nil
    if typeof(plucker) == "string" then
        plucker = self:plucker(plucker)
    end

    self:imap(tab, plucker)
end

--[[
    Same as Utils:ipluck, but makes a copy first.
--]]
function Utils:pluck<K, V, T>(plucker: string | (value: K, key: V) -> T, tab: { [K]: V }): { [K]: T }
    tab = table.clone(tab)
    self:ipluck(plucker, tab)
    return tab
end

--[[
    Returns the insertion index of the provided element, using binary search.
    if you provide a key, it must return something that is comparable.
    Similar to python's builtin `bisect.bisect` function.

    ```lua
    local x = {10, 11, 12, 14, 15}
    Utils:bisect(x, 13) -> 4
    ```
--]]
function Utils:bisect<K, V>(tab: { [K]: V }, element: V, key: ((value: K, key: V) -> any)?): number
    if not key then
        key = function(x)
            return x
        end
    end

    element = key(element, nil)

    local low = 1
    local high = #tab + 1
    local middle

    while low < high do
        middle = math.floor((low + high) / 2)

        if element >= key(tab[middle], middle) then
            low = middle + 1
        else
            high = middle
        end
    end

    return low
end

--[[
    Insert `element` into `tab` such that it remains sorted (with an optional sorting key).
    Similar to Python's builtin `bisect.insort` function.
--]]
function Utils:insort<K, V>(tab: { [K]: V }, element: V, key: ((value: K, key: V) -> any)?): nil
    table.insert(tab, self:bisect(tab, element, key), element)
end

--[[
    Returns an un-parented Part that has CanCollide on, and everything else off.
--]]
function Utils:getBlankPart(): Part
    local part = Instance.new("Part")

    part.TopSurface = Enum.SurfaceType.SmoothNoOutlines
    part.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
    part.RightSurface = Enum.SurfaceType.SmoothNoOutlines
    part.LeftSurface = Enum.SurfaceType.SmoothNoOutlines
    part.FrontSurface = Enum.SurfaceType.SmoothNoOutlines
    part.BackSurface = Enum.SurfaceType.SmoothNoOutlines

    part.Anchored = true
    part.CanCollide = true
    part.CanTouch = false
    part.CanQuery = false

    part.Size = Vector3.new(1, 1, 1)

    return part
end

--[[
    Returns the minimum value in the table (like math.min) except:
        - it accepts a key function
        - it returns the index of the minimum value along with the value itself

    ```lua
    Utils:min({3, 1, 8}) -> 1, 2
    Utils:min({-8, 3}, math.abs) -> 3, 2
    ```
--]]
function Utils:min<K, V>(tab: { [K]: V }, key: ((value: V, key: K) -> any)?): (any, any)
    local minValue, minKey = nil, nil

    for k, v in tab do
        if key(v, k) < minValue then
            minValue = v
            minKey = k
        end
    end

    return minValue, minKey
end

--[[
    Exactly the same as Utils.min, but only returns the key of the minimum value.
    ```lua
    Utils:minKey({a = 2, b = 1, c = 4}) -> "b"
    ```
--]]
function Utils:minKey(...): any
    return select(2, self:min(...))
end

--[[
    Pretty self explanatory, I think.
    ```lua
    Utils:sum({ 1, 2, 3 }) -> 6
    Utils:sum({ 4, "5", 6 }) -> 15
    ```
--]]
function Utils:sum<K, V>(tab: { [K]: V }, key: ((value: V, key: K) -> number)?): number
    key = key or tonumber

    local total = 0
    for k, v in tab do
        total += key(v, k)
    end

    return total
end

--[[
    Swaps the keys and values of the provided table.
    If there are duplicate values, the last occurrence will be kept.
    ```lua
    Utils:invert({ a = "b", c = "d" }) -> { b = "a", d = "c" }
    ```
--]]
function Utils:invert<K, V>(tab: { [K]: V }): { [V]: K }
    local inverted = table.create(#tab)
    for k, v in tab do
        inverted[v] = k
    end
    return inverted
end

return Utils
