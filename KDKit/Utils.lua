--!strict

--[[
    KDKit.Utils is a collection of various utility functions that are "missing" from the standard library and the language itself.
    Yes, all of KDKit could be considered a "collection of various utility functions", but these are functions which don't quite
    fit in anywhere else and aren't large enough to deserve their own submodule.
--]]
local Utils = {
    PRIMITIVE_TYPES = { string = true, boolean = true, number = true, ["nil"] = true },
}

type Evaluator<K, V, T> = ((V, K) -> T) | string
function Utils.evaluator<K, V, T>(e: Evaluator<K, V, T>?): (V, K) -> T
    if e == nil then
        return function(v: V, k: K)
            return (v :: any) :: T
        end
    elseif typeof(e) == "string" then
        return function(v: V, k: K)
            return ((v :: any) :: { [string]: T })[e]
        end
    else
        return e
    end
end

--[[
    same as `xpcall` but packs the results (for easier use)
--]]
function Utils.packedXPCall<HandledError, Arg..., Ret...>(
    func: (Arg...) -> Ret...,
    handleError: (err: string) -> HandledError,
    ...: Arg...
): (boolean, HandledError | { any }) -- actually packed { Ret... }
    local successAndResults = table.pack(xpcall(func, handleError, ...))
    local success = table.remove(successAndResults, 1) :: boolean
    if success then
        local results = successAndResults
        return true, results :: { any }
    else
        local handledError = table.remove(successAndResults, 1)
        return false, (handledError :: any) :: HandledError
    end
end

--[[
    try/catch syntax
    ```lua
    local result = Utils.try(function()
        return 1 + "a"
    end):catch(function(err)
        print("uh oh that didn't work")
    end):raise():result()
    ```

    This code will print "uh oh that didn't work", then raise an error.

    Here's a list of each available chaining function:
        - `catch` accepts a function which handles an error, if it occurs. The function will not be called if no error occurs.
        - `proceed` accepts a function that will be called with the results, only if an error did not occur
        - `after` accepts a function which will always be called, regardless of whether or not an error occurs.
                  It accepts a single argument, `err`, which is a traceback string if an error occurred, and `nil` otherwise.
        - `raise` does not accept any arguments, but it re-raises the caught error, if one occurred. Even if you called `:catch()`.
        - `result` does not accept any arguments. It has different behavior depending on whether or not `raise` has already been called:
                   * `raise` has already been called: It returns the result of the original function
                   * `raise` has not been called: It returns a success boolean and either an error string or the function result
--]]

type _AnyTry<Ret...> = TryNotRaised<Ret...> | TryRaised<Ret...>

type TryNotRaised<Ret...> = {
    success: boolean,
    traceback: string?, -- note that this only includes frames from AFTER :try()
    results: { any }?, -- actually packed { Ret... }
    catch: (self: TryNotRaised<Ret...>, (err: string) -> nil) -> TryNotRaised<Ret...>,
    proceed: (self: TryNotRaised<Ret...>, (Ret...) -> nil) -> TryNotRaised<Ret...>,
    after: (self: TryNotRaised<Ret...>, (err: string?) -> nil) -> TryNotRaised<Ret...>,
    raise: (self: TryNotRaised<Ret...>) -> TryRaised<Ret...>,
    _raise_called: false,
    result: (self: TryNotRaised<Ret...>) -> (boolean, string | any), -- the 'any' is actually 'Ret...',
}

type TryRaised<Ret...> = {
    success: boolean,
    traceback: string?, -- note that this only includes frames from AFTER :try()
    results: { any }?, -- actually packed { Ret... }
    catch: (self: TryRaised<Ret...>, (err: string) -> nil) -> TryRaised<Ret...>,
    proceed: (self: TryRaised<Ret...>, (Ret...) -> nil) -> TryRaised<Ret...>,
    after: (self: TryRaised<Ret...>, (err: string?) -> nil) -> TryRaised<Ret...>,
    raise: (self: TryRaised<Ret...>) -> TryRaised<Ret...>,
    _raise_called: true,
    result: (self: TryRaised<Ret...>) -> Ret...,
}

function Utils.try<Arg..., Ret...>(func: (Arg...) -> Ret..., ...: Arg...): TryNotRaised<Ret...>
    local function nonReEntrantWrapper(...: Arg...): Ret...
        return func(...)
    end

    local function buildTraceback(err: string): string
        local i = 2
        while true do
            local s, l, n, f = debug.info(i, "slnf")
            i += 1

            if f == nonReEntrantWrapper then
                break
            end

            if s == "[C]" or l == nil or l < 0 then
                continue
            end

            if n and n:gsub("%s", "") ~= "" then
                err ..= ("\n%s:%d: in function %s"):format(s, l, n)
            else
                err ..= ("\n%s:%d:"):format(s, l)
            end
        end

        return err
    end

    local success, results = Utils.packedXPCall(nonReEntrantWrapper, buildTraceback, ...)

    return {
        success = success,
        results = if success then results :: { any } else nil,
        traceback = if success then nil elseif typeof(results) == "string" then results else Utils.repr(results), -- apparently errors are not necessarily strings - see `error({})`
        _raise_called = false :: false,
        catch = function(ctx, cb)
            if not ctx.success then
                assert(ctx.traceback)

                cb(ctx.traceback)
            end

            return ctx
        end,
        proceed = function(ctx, cb)
            if ctx.success then
                assert(ctx.results)

                cb(table.unpack(ctx.results))
            end

            return ctx
        end,
        after = function(ctx, cb)
            cb(ctx.traceback)
            return ctx
        end,
        raise = function(ctx)
            if not ctx.success then
                assert(ctx.traceback)

                error(
                    ("The following error occurred during a KDKit.Utils.try call.\n%s"):format(
                        Utils.indent(ctx.traceback, "|   ")
                    )
                )
            end

            local typeAdjustedCtx = (ctx :: any) :: TryRaised<Ret...>
            typeAdjustedCtx._raise_called = true

            return typeAdjustedCtx
        end,
        result = function(ctx)
            if ctx._raise_called then
                assert(ctx.results)
                return table.unpack(ctx.results)
            elseif ctx.success then
                assert(ctx.results)
                return true, table.unpack(ctx.results)
            else
                return false, ctx.traceback
            end
        end,
    }
end

--[[

--]]
function Utils.retry<Ret...>(
    totalAttempts: number,
    f: () -> Ret...,
    waitAfterFailure: number?,
    maxWait: number?,
    expBackoffRate: number?
): Ret...
    waitAfterFailure = waitAfterFailure or 0
    assert(waitAfterFailure)

    expBackoffRate = expBackoffRate or 2
    assert(expBackoffRate)

    maxWait = (expBackoffRate ^ 6 * waitAfterFailure) or 60
    assert(maxWait)

    local backoff = waitAfterFailure
    for attempt = 1, (totalAttempts - 1) do
        local r = Utils.try(f)

        if not r.success then
            task.wait(backoff)
            backoff = math.min(backoff * expBackoffRate, maxWait)
        else
            return r:raise():result()
        end
    end

    return f()
end

--[[
    Ensures that the first function runs after the second one does, regardless of if the second function errors.
    ```lua
    Utils.ensure(function(failed, traceback)
        if failed then
            print("uh oh, something went wrong :(", traceback) -- prints traceback including "im throwing an error"
        else
            print("worked!")
        end
    end, error, "im throwing an error")
    ```
--]]
function Utils.ensure<Arg..., Ret...>(
    callback: (failed: boolean, traceback: string?) -> nil,
    func: (Arg...) -> Ret...,
    ...: Arg...
): Ret...
    return Utils.try(func, ...)
        :after(function(err: string?)
            Utils.try(callback, not not err, err):catch(function(cbErr)
                task.defer(
                    error,
                    ("The following error occurred during the callback to a KDKit.Utils.ensure call. The error was ignored.\n%s"):format(
                        cbErr
                    )
                )
            end)
        end)
        :raise()
        :result()
end

--[[
    Executes all the provided tasks simultaneously
--]]
function Utils.gather<Ret...>(cb: (<Arg...>((Arg...) -> Ret..., Arg...) -> ()) -> ()): { TryNotRaised<Ret...> }
    local results = {}
    local queued = 0
    local completed = 0

    local function queue<Arg...>(func: (Arg...) -> Ret..., ...: Arg...)
        queued += 1
        local me = queued

        task.defer(function(...)
            results[me] = Utils.try(func, ...)
            completed += 1
        end, ...)
    end

    cb(queue)

    while queued > completed do
        task.wait()
    end

    return results
end

--[[
    Returns the keys of the table.
    ```lua
    Utils.keys({a=1, b=2, c=3}) -> { "a", "b", "c" }
    Utils.keys({"a", "b", "c"}) -> { 1, 2, 3 }
    ```
--]]
function Utils.keys<K>(tab: { [K]: any }): { K }
    local keys = table.create(16)
    for key, _value in tab do
        table.insert(keys, key)
    end
    return keys
end

--[[
    Returns the values of the table.
    ```lua
    Utils.keys({a=1, b=2, c=3}) -> { 1, 2, 3 }
    Utils.keys({"a", "b", "c"}) -> { "a", "b", "c" }
    ```
--]]
function Utils.values<V>(tab: { [any]: V }): { V }
    local values = table.create(16)
    for _key, value in tab do
        table.insert(values, value)
    end
    return values
end

--[[
    Simply removes surrounding whitespace from the right side of a string.
    Similar to Python's builtin `str.rstrip` method.

    ```lua
    Utils.rstrip("  hello there  ") -> "  hello there"
    Utils.rstrip(" \n\t it strips all types of whitespace \n like this \n\t ") -> " \n\t it strips all types of whitespace \n like this"
    ```
--]]
function Utils.rstrip(str: string): string
    local x, _ = str:gsub("%s+$", "")
    return x
end

--[[
    Identical to `Utils.rstrip()` except removes whitespace from the left.
    Similar to Python's builtin `str.lstrip` method.
    ```
--]]
function Utils.lstrip(str: string): string
    local x, _ = str:gsub("^%s+", "")
    return x
end

--[[
    Simply removes surrounding whitespace from a string.
    Similar to Python's builtin `str.strip` method.
--]]
function Utils.strip(str: string): string
    return Utils.lstrip(Utils.rstrip(str))
end

--[[
    Splits the provided string based on the given delimiter into a table of substrings. By default, splits on groups of whitespace.
    Similar to Python's builtin `str.split` method.

    ```lua
    Utils.split("Hello there, my name is Gabe!") -> { "Hello", "there,", "my", "name", "is", "Gabe!" }
    Utils.split("  \r\n whitespace   is  \t\t    stripped   \n ") -> { "whitespace", "is", "stripped" }
    Utils.split("a_b_c", "_") -> { "a", "b", "c" }
    Utils.split("abc123xyz", "%d") -> { "abc", "xyz" }
    ```
--]]
function Utils.split(str: string, delimiter: string?): { string }
    local words = table.create(16)

    local wordPattern = if delimiter then ("[^%s]+"):format(delimiter) else "%S+"
    for word in str:gmatch(wordPattern) do
        table.insert(words, word)
    end

    return words
end

--[[
    Returns a table containing the characters of the string.
    Similar to Python's builtin `list(string)`
    ```lua
    Utils.characters("abc") -> { "a", "b", "c" }
    ```
--]]
function Utils.characters(s: string): { string }
    local characters = table.create(s:len())
    for i = 1, s:len() do
        table.insert(characters, s:sub(i, i))
    end
    return characters
end

--[[
    Simple deep-copy, with support for recursive tables.
--]]
function Utils.deepCopy<T>(original: T, cloneInstances: boolean?, _copyLookup: { [T]: T }?): T
    if typeof(original) == "table" then
        _copyLookup = _copyLookup or {}
        assert(_copyLookup)

        if _copyLookup[original] then
            return _copyLookup[original]
        end

        local copy = setmetatable(
            {},
            Utils.deepCopy(getmetatable(original), cloneInstances, _copyLookup) :: { [any]: any } -- cast required because luau thinks `original` is a `never`
        )
        _copyLookup[original] = (copy :: any) :: T -- cast required because luau doesn't realize that `T` is a table

        for k, v in original do
            copy[Utils.deepCopy(k, cloneInstances, _copyLookup)] = Utils.deepCopy(v, cloneInstances, _copyLookup)
        end

        return (copy :: any) :: T -- cast required because luau doesn't realize that `T` is a table
    elseif cloneInstances and typeof(original) == "Instance" then
        return original:Clone()
    end

    return original
end

--[[
    [!] UPDATES THE TABLE IN-PLACE
    Calls the provided `transform` function on each value in the table.
    Modifies the table [i]n place, does not make a copy.

    ```lua
    local x = { 1, 2, 3 }
    Utils.imap(x, function(v) return v * v end)
    print(x) -> { 1, 4, 9 }
    ```
--]]
function Utils.imap<K, V, T>(tab: { [K]: V }, evaluator: Evaluator<K, V, T>): { [K]: T }
    local e = Utils.evaluator(evaluator)
    local typeAdjustedTab = (tab :: any) :: { [K]: T }

    for key, value in tab do
        typeAdjustedTab[key] = e(value, key)
    end

    return typeAdjustedTab
end

--[[
    Returns a new table whose values have been transformed by the provided `transform` function.
    Similar to Python's builtin `map` function, but is eagerly evaluated & args are swapped.

    ```lua
    Utils.map({ 1, 2, 3 }, function(v) return v ^ 3 end) -> { 1, 8, 27 }
    ```
--]]
function Utils.map<K, V, T>(tab: { [K]: V }, evaluator: Evaluator<K, V, T>): { [K]: T }
    return Utils.imap(table.clone(tab), evaluator)
end

--[[
    Similar to Utils.map, except you can specify both the key and the value.

    ```lua
    Utils.mapf({ 1, 2, 3 }, function(v, k) return k + 1, v ^ 2 end) -> { [2] = 1, [3] = 4, [4] = 9 }
    ```
--]]
function Utils.mapf<K1, V1, K2, V2>(tab: { [K1]: V1 }, transform: (value: V1, key: K1, index: number) -> (K2, V2)): { [K2]: V2 }
    local output = {}
    local index = 1
    for k1, v1 in tab do
        local k2, v2 = transform(v1, k1, index)
        index += 1
        if k2 ~= nil then
            output[k2] = v2
        end
    end
    return output
end

--[[
    Returns a string which represents the provided value while retaining as much information as possible about the value.
    Similar to Python's builtin `repr` function.
--]]
function Utils.repr(
    x: any,
    tableDepth: number?,
    tableVerbosity: number?,
    tableIndent: (string | boolean)?,
    alreadySeenTables: { [{ any }]: boolean }?
): string
    if not tableDepth then
        tableDepth = 4
    end
    assert(tableDepth)
    tableDepth = math.floor(tableDepth)

    if not tableVerbosity then
        tableVerbosity = 10
    end
    assert(tableVerbosity)
    tableVerbosity = math.floor(tableVerbosity)

    if tableIndent == nil or tableIndent == true then
        tableIndent = "  "
    else
        tableIndent = nil
    end
    assert(tableIndent == nil or type(tableIndent) == "string")

    if not alreadySeenTables then
        alreadySeenTables = {}
    end
    assert(alreadySeenTables)

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
        elseif tableDepth <= 0 then
            return "<table depth exceeded> " .. tostring(x)
        end
        local parts = table.create(8)

        alreadySeenTables[x] = true
        local n = 0
        local function process(key, value)
            if n < tableVerbosity then
                local part = ("[%s] = %s"):format(
                    Utils.repr(
                        key,
                        tableDepth - 1,
                        math.min(tableVerbosity, math.max(3, tableVerbosity / 2)),
                        false,
                        alreadySeenTables
                    ),
                    Utils.repr(
                        value,
                        tableDepth - 1,
                        math.min(tableVerbosity, math.max(3, tableVerbosity / 2)),
                        tableIndent,
                        alreadySeenTables
                    )
                )
                if tableIndent then
                    part = (tableIndent :: string) .. part
                    part = part:gsub("\n", "\n" .. (tableIndent :: string))
                end
                table.insert(parts, part)
                n += 1
                return true
            else
                if tableIndent then
                    table.insert(parts, (tableIndent :: string) .. "...")
                end

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

        if tableIndent then
            if #parts == 0 then
                return "{}"
            end

            table.insert(parts, "")
            return "{\n" .. table.concat(parts, ",\n") .. "}"
        else
            return "{ " .. table.concat(parts, ", ") .. " }"
        end
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
    Utils.isAlpha("Hello") -> true
    Utils.isAlpha("Hello!") -> false
    Utils.isAlpha("hello there") -> false
    Utils.isAlpha("iHave3Apples") -> false
    Utils.isAlpha("") -> true
    ```
--]]
function Utils.isAlpha(str: string): boolean
    return str:match("[^a-zA-Z]") == nil
end

--[[
    returns true if the provided string does not contain lowercase letters [a-z]
    similar to Python's builtin `str.isupper` method, but handles non-alpha characters differently
    ```lua
    Utils.isUpper("HELLO") -> true
    Utils.isUpper("Hello") -> false
    Utils.isUpper("hello") -> false
    Utils.isUpper("HELLO123") -> true
    Utils.isUpper("123") -> true
    Utils.isUpper("") -> true
    ```
--]]
function Utils.isUpper(str: string): boolean
    return str:match("[a-z]") == nil
end

--[[
    returns true if the provided string does not contain uppercase letters [A-Z]
    similar to Python's builtin `str.islower` method, but handles non-alpha characters differently
    ```lua
    Utils.isLower("hello") -> true
    Utils.isLower("Hello") -> false
    Utils.isLower("HELLO") -> false
    Utils.isLower("hello123") -> true
    Utils.isLower("123") -> true
    Utils.isLower("") -> true
    ```
--]]
function Utils.isLower(str: string): boolean
    return str:match("[A-Z]") == nil
end

--[[
    return true if the provided string only contains decimal characters [0-9]
    similar to Python's builtin `str.isnumeric` method, but stricter

    !! Warning: returns false when the string contains a period `.` or a negative sign `-`
    ```lua
    Utils.isNumeric("123") -> true
    Utils.isNumeric("123.456") -> false
    Utils.isNumeric("-5") -> false
    Utils.isNumeric("hello") -> false
    Utils.isNumeric("") -> true
    ```
--]]
function Utils.isNumeric(str: string): boolean
    return str:match("[^0-9]") == nil
end

--[[
    return true if the provided string only contains alphanumeric characters [a-zA-Z0-9]
    similar to Python's builtin `str.isalphanum` method
    ```lua
    Utils.isAlphanumeric("abc123") -> true
    Utils.isAlphanumeric("abc") -> true
    Utils.isAlphanumeric("123") -> true
    Utils.isAlphanumeric("abc 123") -> false
    Utils.isAlphanumeric("123 + 456") -> false
    Utils.isAlphanumeric("hello!") -> false
    Utils.isAlphanumeric("123.456") -> false
    Utils.isAlphanumeric("") -> true
    ```
--]]
function Utils.isAlphanumeric(str: string): boolean
    return str:match("[^0-9a-zA-Z]") == nil
end

--[[
    returns true if the provided string starts with the provided prefix
    similar to Python's builtin `string.startswith` method
    ```lua
    Utils.startsWith("hello world", "hello") -> true
    Utils.startsWith("abcdefg", "abc") -> true
    Utils.startsWith("abcdefg", "xyz") -> false
    Utils.startsWith("abcdefg", "") -> true
    Utils.startsWith("", "abc") -> false
    ```
--]]
function Utils.startsWith(str: string, prefix: string): boolean
    return str:sub(1, prefix:len()) == prefix
end

--[[
    returns true if the provided string ends with the provided suffix
    similar to Python's builtin `string.endswith` method
    ```lua
    Utils.endsWith("hello world", "world") -> true
    Utils.endsWith("abcdefg", "efg") -> true
    Utils.endsWith("abcdefg", "xyz") -> false
    Utils.endsWith("abcdefg", "") -> true
    Utils.endsWith("", "abc") -> false
    ```
--]]
function Utils.endsWith(str: string, suffix: string): boolean
    return str:sub(str:len() - suffix:len() + 1) == suffix
end

--[[
    returns true if and only if the keys in the provided table are continuous increasing integers that start at 1
    ```lua
    Utils.isLinearArray({ "a", "b", "c" }) -> true
    Utils.isLinearArray({ "a", "b", "c", extra = "d" }) -> false
    Utils.isLinearArray({ a = 1, b = 2, c = 3 }) -> false
    Utils.isLinearArray({ [2] = "a", [1] = "b", [3] = "c" }) -> true
    Utils.isLinearArray({ [2] = "a", [3] = "c" }) -> false
    ```
--]]
function Utils.isLinearArray(x: { any }): boolean
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
    `Utils.count(x)` is basically `#x` except it works with dictionaries.
--]]
function Utils.count(x: { [any]: any }): number
    local n = 0
    for _ in x do
        n += 1
    end

    return n
end

--[[
    Returns a copy of the provided table whose nesting depth does not exceed the provided parameter.
    If the parameter is not a table, then it is returned without adjustment
    unless the depth parameter is < 0, then `"<exceeded maximum depth>"` is returned.
    ```lua
    Utils.truncateAfterMaxDepth({ a = 1, b = 2, c = { 1, 2, 3 }}, 1) -> { a = 1, b = 2, c = "<exceeded maximum depth>" }
    ```
--]]
function Utils.truncateAfterMaxDepth(x: any, depth: number): any
    if depth < 0 then
        return "<exceeded maximum depth>"
    elseif type(x) ~= "table" then
        return x
    end

    local copy = table.clone(x)

    for key, value in copy do
        copy[key] = Utils.truncateAfterMaxDepth(value, depth - 1)
    end

    return copy
end

--[[
    Returns a *deep copy* of the table, which is guaranteed to be generally serializable, while losing as little information as possible.
    Specifically designed to be serialized via JSON.
    ```lua
    Utils.makeSerializable({ "hi", true, workspace.MyPart, Enum.Material.Wood, { "sub table", value = 123 } })
     -> { "hi", true, "<Instance.Part> Workspace.MyPart", "Enum.Material.Wood", { ["1"] = "sub table", value = 123 } }
    ```
--]]
function Utils.makeSerializable(tab: any, alreadySeen: { [{ any }]: boolean }?): string | { any }
    if type(tab) ~= "table" then
        tab = { data = tab }
    end

    if not alreadySeen then
        alreadySeen = {}
    end
    assert(alreadySeen)

    local isLinearArray = Utils.isLinearArray(tab)
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
            key = Utils.repr(key)
        end

        -- values must be primitive or serializable tables
        local tv = type(value)
        if Utils.PRIMITIVE_TYPES[tv] then
            -- pass
        elseif tv == "table" then
            value = Utils.makeSerializable(value, alreadySeen)
        else
            value = Utils.repr(value)
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
    Utils.safeJSONEncode({ "hi", true, workspace.MyPart, Enum.Material.Wood, { "sub table", value = 123 } })
     -> '["hi", true, "<Instance.Part> Workspace.MyPart", "Enum.Material.Wood", {"1": "sub table", "value": 123}]'
    ```
--]]
function Utils.safeJSONEncode(data: any): string
    return game:GetService("HttpService"):JSONEncode(Utils.makeSerializable(data))
end

--[[
    [!] UPDATES THE TABLE IN-PLACE

    Sort a table (in-place) using a function to extract a comparable value.
    Similar to passing a `key` to Python's builtin `list.sort` function.
    You may also return a table to include tiebreakers.
--]]
function Utils.isort<V>(tab: { V }, evaluator: Evaluator<nil, V, any>?): { V }
    local e = Utils.evaluator(evaluator) :: (V, nil) -> any
    local rankings = {}

    table.sort(tab, function(a, b)
        rankings[a] = rankings[a] or e(a)
        rankings[b] = rankings[b] or e(b)

        return Utils.compare(rankings[a], rankings[b]) == -1
    end)

    return tab
end

--[[
    Similar to Utils.isort, but makes a copy first.
--]]
function Utils.sort<V>(tab: { V }, evaluator: Evaluator<nil, V, any>?): { V }
    return Utils.isort(table.clone(tab), evaluator)
end

--[[
    Returns true if the first object is visibly on top of the second gui object.
    Returns false in the opposite case.
    Otherwise, returns nil in ambiguous cases.

    Useful for detecting which object is currently visible at a certain point on a client's screen.

    Note: this function does not consider physical locations of SurfaceGuis and BillboardGuis within the workspace.
--]]
function Utils.guiObjectIsOnTopOfAnother(a: GuiObject, b: GuiObject): boolean?
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

    assert(aGui and bGui)

    -- different gui? ez pz
    if aGui ~= bGui then
        if aGui:IsA("ScreenGui") and bGui:IsA("ScreenGui") then
            if aGui.DisplayOrder ~= bGui.DisplayOrder then
                return aGui.DisplayOrder > bGui.DisplayOrder
            else
                if bGui:IsDescendantOf(aGui) then
                    return false
                elseif aGui:IsDescendantOf(bGui) then
                    return true
                end
                -- else, ambiguous
            end
        elseif aGui:IsA("ScreenGui") and not bGui:IsA("ScreenGui") then
            return true
        elseif not aGui:IsA("ScreenGui") and bGui:IsA("ScreenGui") then
            return false
        end

        -- TODO: figure out how SurfaceGui/BillboardGui works

        return nil -- ambiguous
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

    -- descendant of one another? ez pz
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
            aAncestor = aAncestor.Parent :: GuiObject
            aAncestors[aAncestor] = true
        end
        if bAncestor.Parent then
            bAncestor = bAncestor.Parent :: GuiObject
            bAncestors[bAncestor] = true
        end

        if bAncestors[aAncestor] then
            firstCommonAncestor = aAncestor
        elseif aAncestors[bAncestor] then
            firstCommonAncestor = bAncestor
        end
    end

    local aFirstDescendantOfCommonAncestor, bFirstDescendantOfCommonAncestor
    for _, v in firstCommonAncestor:GetChildren() do
        if aAncestors[v :: any] then
            aFirstDescendantOfCommonAncestor = v :: GuiObject
        elseif bAncestors[v :: any] then
            bFirstDescendantOfCommonAncestor = v :: GuiObject
        end
    end

    if aFirstDescendantOfCommonAncestor.ZIndex ~= bFirstDescendantOfCommonAncestor.ZIndex then
        return aFirstDescendantOfCommonAncestor.ZIndex > bFirstDescendantOfCommonAncestor.ZIndex
    end

    return nil -- ambiguous
end

--[[
    [!] UPDATES THE TABLE IN-PLACE

    Merges the second table into the first one.
    ```lua
    local x = { a = 1, b = 2, c = 3 }
    local y = { a = 2, b = 3, d = 4 }

    Utils.imerge(x, y)

    x -> { a = 2, b = 3, c = 3, d = 4 } -- (a, b, and d modified in place)
    y -> { a = 2, b = 3, d = 4 } -- (unchanged)
    ```
--]]
function Utils.imerge<K1, V1, K2, V2>(dst: { [K1]: V1 }, src: { [K2]: V2 }): { [K1 | K2]: V1 | V2 }
    local typeAdjustedDst = dst :: { [K1 | K2]: V1 | V2 }

    for key, value in src do
        typeAdjustedDst[key] = value
    end

    return typeAdjustedDst
end

--[[
    Same as Utils.imerge but makes a copy first.
    ```lua
    Utils.merge({ a = 1, b = 2 }, { a = 2, c = 3 }}) -> { a = 2, b = 2, c = 3 }
    ```
--]]
function Utils.merge<K1, V1, K2, V2>(dst: { [K1]: V1 }, src: { [K2]: V2 }): { [K1 | K2]: V1 | V2 }
    return Utils.imerge(table.clone(dst), src)
end

--[[
    [!] UPDATES THE TABLE IN-PLACE

    Inserts all elements from the right list into the left list.
    Similar to Python's builtin `list.extend`
    ```lua
    local x = { 'a', 'b' }
    local y = { 'c', 'd' }

    Utils.iextend(x, y)

    x -> { 'a', 'b', 'c', 'd' } -- (c and d inserted)
    y -> { 'c', 'd' } -- (unchanged)
    ```
--]]
function Utils.iextend<V1, V2>(left: { V1 }, right: { V2 }): { V1 | V2 }
    local typeAdjustedLeft = left :: { V1 | V2 }
    local typeAdjustedRight = right :: { V1 | V2 }

    table.move(typeAdjustedRight, 1, #typeAdjustedRight, #typeAdjustedLeft + 1, typeAdjustedLeft)
    return typeAdjustedLeft
end

--[[
    Same as Utils.iextend but makes a copy first.
    ```lua
    Utils.extend({ 'a', 'b' }, { 'c', 'd' }) -> { 'a', 'b', 'c', 'd' }
    ```
--]]
function Utils.extend<V1, V2>(left: { V1 }, right: { V2 }): { V1 | V2 }
    return Utils.iextend(table.clone(left), right)
end

--[[
    Linear interpolation.
    ```lua
    Utils.lerp(0, 20, 0.1) -> 2
    ```
--]]
function Utils.lerp(a: number, b: number, f: number, clamp: boolean?): number
    if clamp then
        return math.clamp((b - a) * f + a, math.min(a, b), math.max(a, b))
    else
        return (b - a) * f + a
    end
end

--[[
    Inverse of Utils.lerp
    ```lua
    Utils.unlerp(10, 20, 12) -> 0.2
    ```
--]]
function Utils.unlerp(a: number, b: number, x: number, clamp: boolean?): number
    if clamp then
        return math.clamp((x - a) / (b - a), 0, 1)
    else
        return (x - a) / (b - a)
    end
end

--[[
    Checks if the given value is callable, i.e. that it is a function or a callable table.
--]]
function Utils.callable(maybeCallable: any): boolean
    if type(maybeCallable) == "function" then
        return true
    elseif
        type(maybeCallable) == "table"
        and type(getmetatable(maybeCallable)) == "table"
        and type(rawget(getmetatable(maybeCallable), "__call")) == "function"
    then
        return true
    end

    return false
end

--[[
    Gets the attribute, if present, otherwise returns the provided default value.
    Similar to Python's builtin `getattr`
    ```lua
    Utils.getattr({a = 123}, 'b', 456) -> 456
    Utils.getattr(Vector3.new(), 'blah') -> nil
    ```
--]]
function Utils.getattr<K, V, T>(x: { [K]: V } | any, attr: K, default: T?): V | T?
    local s, r = pcall(function()
        return (x :: { [K]: V })[attr]
    end)

    if not s or r == nil then
        return default
    end

    return r
end

--[[
    Repeatedly calls `getattr()` until reaching the value, or breaking.
    Similar to Ruby's `dig`.
--]]
function Utils.dig(x: any, ...: any): any
    for _, k in { ... } do
        if x == nil then
            return x
        end

        x = Utils.getattr(x, k)
    end

    return x
end

--[[
    Similar to Python's builtin `setattr`
--]]
function Utils.setattr<K, V, T>(x: { [K]: V } | any, attr: K, value: V): boolean
    local s = pcall(function()
        (x :: { [K]: V })[attr] = value
    end)
    return s
end

--[[
    Pretty simple. Welds two parts together using a WeldConstraint.
    Note that you will need to set the parent of the returned WeldConstraint in order to make it effective.
--]]
function Utils.weld(a: BasePart, b: BasePart, reuse: WeldConstraint?): WeldConstraint
    local weld = reuse or Instance.new("WeldConstraint")

    weld.Part0 = a
    weld.Part1 = b
    weld.Enabled = true

    return weld
end

--[[
    Returns true if at least one of the elements of the table are truthy.
    Optionally, you may specify a function which will be used to judge the truthiness of each element.
    Note that this function is lazy, so any elements that occur after a truthy one will not be evaluated.
    If you wish to avoid this lazy behavior, use Utils.any(Utils.map(collection, evaluator)).
    * Very similar to Python's builtin `any` function.

    ```lua
    Utils.any({false, true, false}) -> true
    Utils.any({false, false}) -> false
    Utils.any({}) -> false
    Utils.any({1, 2, 3, -5}, function(x) return x < 0 end) -> true
    ```
--]]
function Utils.any<K, V>(collection: { [K]: V }, evaluator: Evaluator<K, V, boolean>?): boolean
    local e = Utils.evaluator(evaluator) :: (V, K) -> boolean

    for k, v in collection do
        if e(v, k) then
            return true
        end
    end

    return false
end

--[[
    Similar to Utils.any(), but checks if _all_ the elements are truthy.
--]]
function Utils.all<K, V>(collection: { [K]: V }, evaluator: Evaluator<K, V, boolean>?): boolean
    local e = Utils.evaluator(evaluator) :: (V, K) -> boolean

    for k, v in collection do
        if not e(v, k) then
            return false
        end
    end

    return true
end

--[[
    Returns:
        -1 if a < b
        0 if a == b
        1 if a > b
        and when their types don't match:
        1 if a == nil and b ~= nil
        1 if type(a) > type(b)
    If both `a` and `b` are arrays,  corresponding elements are compared
    in order until a tie is broken. (similar to tuple comparison in Python)
    ```lua
    Utils.compare(5, 10) -> -1
    Utils.compare(10, 10) -> 0
    Utils.compare(15, 10) -> 1
    Utils.compare({ "a", "y" }, { "a", "z" }) -> -1
    Utils.compare({ "a", "b" }, { "a", "b" }) -> 0
    Utils.compare({ "a", "z" }, { "a", "y" }) -> 1
    Utils.compare({ "a", "z" }, { "b", "y" }) -> -1
    ```
--]]
function Utils.compare(a: any, b: any): number
    if a == b then
        return 0
    elseif type(a) == "table" and type(b) == "table" then
        for k, aa in a do
            local bb = b[k]
            local c = Utils.compare(aa, bb)
            if c ~= 0 then
                return c
            end
        end

        return 0
    elseif a == nil then
        return 1 -- nil comes last in ascending sort
    elseif type(a) > type(b) then
        return 1
    elseif a < b then
        return -1
    else
        return 1
    end
end

--[[
    Returns the index such that `table.insert(tab, index, element)` will
    maintain (ascending) sorted order. If an equivalent `element` is 
    already in the table, the returned index will be after the last copy.
    Similar to Python's `bisect.bisect_right`.

    ```lua
    local x = {10, 11, 12, 14, 15}
    Utils.bisect_right(x, 13) -> 4
    ```
--]]
function Utils.bisect_right<V, C>(tab: { V }, value: C, key: Evaluator<number?, V, C>?, low: number?, high: number?): number
    local e = Utils.evaluator(key) :: (V, number?) -> any

    local lo = low or 1
    local hi = (high or #tab) + 1
    local middle

    while lo < hi do
        middle = math.floor((lo + hi) / 2)

        if Utils.compare(value, e(tab[middle], middle)) >= 0 then
            lo = middle + 1
        else
            hi = middle
        end
    end

    return lo
end
Utils.bisect = Utils.bisect_right

--[[
    Similar to `Utils.bisect_right`, but in the case where the table
    contains equivalent elements, it returns the index of the leftmost copy.
    Similar to Python's `bisect.bisect_left`.
--]]
function Utils.bisect_left<V, C>(tab: { V }, value: C, key: Evaluator<number?, V, C>?, low: number?, high: number?): number
    local e = Utils.evaluator(key) :: (V, number?) -> C

    local lo = math.max(low or 1, 1)
    local hi = math.min(high or #tab, #tab) + 1
    local middle

    while lo < hi do
        middle = math.floor((lo + hi) / 2)

        if Utils.compare(value, e(tab[middle], middle)) > 0 then
            lo = middle + 1
        else
            hi = middle
        end
    end

    return lo
end

--[[
    Insert `element` into `tab` such that it remains sorted.
    In the case of tiebreakers, the new element is placed on the right.
    Similar to Python's builtin `bisect.insort_right` function.
--]]
function Utils.insort_right<V>(tab: { V }, element: V, key: Evaluator<number?, V, any>?, low: number?, high: number?)
    local evaluator = Utils.evaluator(key) :: (V, number?) -> any
    table.insert(tab, Utils.bisect_right(tab, evaluator(element, nil), evaluator, low, high), element)
end
Utils.insort = Utils.insort_right

--[[
    Similar to `Utils.insort_right` but in the case of
    tiebreakers, the new element is placed to the left.
--]]
function Utils.insort_left<V>(tab: { V }, element: V, key: Evaluator<number?, V, any>?, low: number?, high: number?)
    local evaluator = Utils.evaluator(key) :: (V, number?) -> any
    table.insert(tab, Utils.bisect_left(tab, evaluator(element, nil), evaluator, low, high), element)
end

--[[
    Insert an item into a sorted list. If an item with
    the same sort key is already in the list, replace it.
    If there are multiple, it replaces the first occurrence.
--]]
function Utils.insort_or_replace<V>(tab: { V }, element: V, key: Evaluator<number?, V, any>?, low: number?, high: number?)
    local evaluator = Utils.evaluator(key) :: (V, number?) -> any
    local index = Utils.bisect_left(tab, evaluator(element, nil), evaluator, low, high)

    local existing_value = tab[index]
    if existing_value == nil or Utils.deepEqual(evaluator(element), evaluator(existing_value)) then
        tab[index] = element
    else
        table.insert(tab, index, element)
    end
end

--[[
    Returns an un-parented Part that has CanCollide/Anchored on, and everything else off.
--]]
function Utils.getBlankPart(parent: Instance?): Part
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

    part.Parent = parent

    return part
end

--[[
    Returns the minimum value in the table (like math.min) except:
        - it accepts a key function
        - it returns the index of the minimum value along with the value itself

    ```lua
    Utils.min({3, 1, 8}) -> 1, 2
    Utils.min({-8, 3}, math.abs) -> 3, 2
    Utils.min({}) -> nil, nil
    ```
--]]
function Utils.min<K, V>(tab: { [K]: V }, key: Evaluator<K, V, any>?): (V?, K?)
    local e = Utils.evaluator(key) :: (V, K) -> any
    local minValue: V?, minKey: K? = nil, nil

    if key then
        local minimumEvaluation = nil

        for k, v in tab do
            local evaluation = e(v, k)
            if minimumEvaluation == nil or Utils.compare(evaluation, minimumEvaluation) < 0 then
                minValue = v
                minKey = k
                minimumEvaluation = evaluation
            end
        end
    else
        for k, v in tab do
            if minValue == nil or Utils.compare(v, minValue) < 0 then
                minValue = v
                minKey = k
            end
        end
    end

    return minValue, minKey
end

--[[
    Exactly the same as Utils.min, but only returns the key of the minimum value.
    Similar to Python's `numpy.argmin`
    ```lua
    Utils.minKey({a = 2, b = 1, c = 4}) -> "b"
    ```
--]]
function Utils.minKey(...): any
    return select(2, Utils.min(...))
end

--[[
    Identical to `Utils.min` but, you know.
--]]
function Utils.max<K, V>(tab: { [K]: V }, key: Evaluator<K, V, any>?): (V, K)
    local e = Utils.evaluator(key) :: (V, K) -> any
    local maxValue, maxKey = nil, nil

    if key then
        local maximumEvaluation = nil

        for k, v in tab do
            local evaluation = e(v, k)
            if maximumEvaluation == nil or Utils.compare(evaluation, maximumEvaluation) > 0 then
                maxValue = v
                maxKey = k
                maximumEvaluation = evaluation
            end
        end
    else
        for k, v in tab do
            if maxValue == nil or Utils.compare(v, maxValue) > 0 then
                maxValue = v
                maxKey = k
            end
        end
    end

    return maxValue, maxKey
end

--[[
    Same as `Utils.minKey` but, you know.
--]]
function Utils.maxKey(...): any
    return select(2, Utils.max(...))
end

--[[
    Pretty self explanatory, I think.
    ```lua
    Utils.sum({ 1, 2, 3 }) -> 6
    Utils.sum({ 4, "5", 6 }) -> 15
    ```
--]]
function Utils.sum<K, V>(tab: { [K]: V }, key: Evaluator<K, V, number>?): number
    local e = Utils.evaluator(key) :: (V, K) -> number

    local total = 0
    for k, v in tab do
        total += e(v, k)
    end
    return total
end

--[[
    Pretty self explanatory, I think.
    ```lua
    Utils.mean({ 7, 9, 2 }) -> 7
    Utils.mean({ 3, 8 }) -> 5.5
    ```
--]]
function Utils.mean<V>(tab: { number }): number
    return Utils.sum(tab) / #tab
end

--[[
    Pretty self explanatory, I think.
    ```lua
    Utils.median({ 1, 2, 3 }) -> 2
    Utils.median({ 1, 2, 3, 4 }) -> 2.5
    ```
--]]
function Utils.median<V>(tab: { number }): number
    local t = table.clone(tab)
    table.sort(t)

    local n = #t
    if n == 0 then
        error("Cannot find the median of an empty set.")
    elseif n % 2 == 0 then
        return (t[n / 2] + t[n / 2 + 1]) / 2
    else
        return t[math.ceil(n / 2)]
    end
end

--[[
    Swaps the keys and values of the provided table.
    If there are duplicate values, the last occurrence will be kept.
    ```lua
    Utils.invert({ a = "b", c = "d" }) -> { b = "a", d = "c" }
    ```
--]]
function Utils.invert<K, V>(tab: { [K]: V }): { [V]: K }
    local inverted = {}
    for k, v in tab do
        inverted[v] = k
    end
    return inverted
end

--[[
    Returns the unique values in the provided table.
    Equivalent to Ruby's `Array::uniq`
    ```lua
    Utils.unique({ "a", "b", "c", "a", "b" }) -> { "a", "b", "c" }
    ```
--]]
function Utils.unique<V>(tab: { [any]: V }): { V }
    return Utils.keys(Utils.invert(tab))
end

--[[
    Indents each line of the provided string.
    ```lua
    Utils.indent("hello\nworld") -> "    hello\n    world"
    ```
--]]
function Utils.indent(str: string, using: string?): string
    using = using or "    "
    assert(using)
    return using .. str:gsub("\n", "\n" .. using)
end

--[[
    Waits to throw errors until after the block is complete.
    Inspired by Ruby RSpec's "aggregate_failures"
    ```lua
    Utils.aggregateErrors(function(aggregate)
        for i = 1, 3 do
            aggregate(function()
                error(("I am throwing an error. (%d)"):format(i))
            end)
        end
    end)

    Utils.lua:939: The following 3 error(s) occurred within a call to Utils.aggregateErrors:
    Error 1:
        Utils.lua:953: I am throwing an error. (1)
        Utils.lua:905 function aggregate
        Utils.lua:915 function aggregateErrors

    Error 2:
        Utils.lua:953: I am throwing an error. (2)
        Utils.lua:905 function aggregate
        Utils.lua:915 function aggregateErrors

    Error 3:
        Utils.lua:953: I am throwing an error. (3)
        Utils.lua:905 function aggregate
        Utils.lua:915 function aggregateErrors
    stacktrace:
    [C] error
    Utils.lua:939 function aggregateErrors
    Utils.lua:950
    ```
--]]
function Utils.aggregateErrors<FRet...>(
    func: (
        aggregate: <AArg..., ARet...>((AArg...) -> ARet..., AArg...) -> (boolean, any) -- actually returns (boolean, AArg... | string)
    ) -> FRet...
): FRet...
    local errors = {}

    local function aggregate<AArg..., ARet...>(f: (AArg...) -> ARet..., ...: AArg...): (boolean, any)
        local tried = Utils.try(f, ...)

        if tried.success then
            assert(tried.results)
            return true, table.unpack(tried.results)
        else
            assert(tried.traceback)
            table.insert(errors, tried.traceback)
            return false, tried.traceback
        end
    end

    local tried = Utils.try(func, aggregate)
    if not tried.success then
        assert(tried.traceback)
        table.insert(
            errors,
            ("This error occurred outside of a call to `aggregate`, so it was not protected and the function exited early.\n%s"):format(
                tried.traceback
            )
        )
    end

    if next(errors) then
        Utils.imap(errors, function(err, index)
            return ("Error %d:\n"):format(index) .. Utils.indent(Utils.rstrip(err), "|   ")
        end)
        error(
            ("The following %d error(s) occurred within a call to Utils.aggregateErrors:\n%s"):format(
                #errors,
                table.concat(errors, "\n\n")
            )
        )
    end

    assert(tried.results)
    return table.unpack(tried.results)
end

--[[
    Select elements from the provided table.
    Similar to Ruby's `Array::select` (which I think is added by ActiveSupport but I'm too lazy to check)
    ```lua
    Utils.select({1, 2, 3, 4, 5}, function(x)
        return x % 2 == 0
    end) -> {2, 4}
    ```
--]]
function Utils.select<K, V>(tab: { [K]: V }, shouldSelect: Evaluator<K, V, boolean>?): { V }
    local e = Utils.evaluator(shouldSelect) :: (V, K) -> boolean
    local selected = {} :: { V }

    for k, v in tab do
        if e(v, k) then
            table.insert(selected, v)
        end
    end

    return selected
end

--[[
    Like `select`, but works for non-array-like tables.
--]]
function Utils.selectMap<K, V>(tab: { [K]: V }, shouldSelect: Evaluator<K, V, boolean>?): { [K]: V }
    local e = Utils.evaluator(shouldSelect) :: (V, K) -> boolean
    local selected = {} :: { [K]: V }

    for k, v in tab do
        if e(v, k) then
            selected[k] = v
        end
    end

    return selected
end

--[[
    Logical opposite of Utils.select
--]]
function Utils.reject<K, V>(tab: { [K]: V }, shouldReject: Evaluator<K, V, boolean>?): { V }
    local e = Utils.evaluator(shouldReject) :: (V, K) -> boolean
    local selected = {} :: { V }

    for k, v in tab do
        if not e(v, k) then
            table.insert(selected, v)
        end
    end

    return selected
end

--[[
    Logical opposite of Utils.selectMap
--]]
function Utils.rejectMap<K, V>(tab: { [K]: V }, shouldReject: Evaluator<K, V, boolean>?): { [K]: V }
    local e = Utils.evaluator(shouldReject) :: (V, K) -> boolean
    local selected = {} :: { [K]: V }

    for k, v in tab do
        if not e(v, k) then
            selected[k] = v
        end
    end

    return selected
end

--[[
    Returns the first value in the table where the `func` returns `true`.
--]]
function Utils.find<K, V>(tab: { [K]: V }, evaluator: Evaluator<K, V, boolean>?): (V?, K?)
    local e = Utils.evaluator(evaluator) :: (V, K) -> boolean

    for k, v in tab do
        if e(v, k) then
            return v, k
        end
    end

    return nil, nil
end

--[[
    Returns the index of the value in the table, or nil if it wasn't found.
    Similar to Python's `list.index`, but does not throw an error.
--]]
function Utils.index<K>(tab: { [K]: any }, value: any): K?
    for k, v in tab do
        if value == v then
            return k
        end
    end

    return nil
end

--[[
    Returns true if and only if the provided part is touching the provided point.
    Note: this currently only works for rectangular parts (not spheres or cylinders).

    Will return true for points that are exactly on the surface of the part.
--]]
function Utils.partTouchesPoint(part: Part, point: Vector3): boolean
    point = part.CFrame:PointToObjectSpace(point)
    return math.abs(point.X) <= part.Size.X / 2
        and math.abs(point.Y) <= part.Size.Y / 2
        and math.abs(point.Z) <= part.Size.Z / 2
end

--[[
    Returns true if and only if the two provided tables have the same keys with equivalent values.
    Does not recurse into table values; if that is desirable, see deepEqual.
    ```lua
    Utils.shallowEqual({a=1, b=2}, {b=2, a=1}) -> true
    Utils.shallowEqual({a=1, b=2}, {a=3, b=4}) -> false
    Utils.shallowEqual({a=1}, {a=1, b=2}) -> false
    Utils.shallowEqual({}, {}) -> true
    Utils.shallowEqual({a=1, b={1,2,3}}, {a=1, b={1,2,3}}) -> false -- see deepEqual
    ```
--]]
function Utils.shallowEqual(a: any, b: any): boolean
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    for k, v in a do
        if b[k] ~= v then
            return false
        end
    end

    for k, v in b do
        if a[k] ~= v then
            return false
        end
    end

    return true
end

--[[
    Equivalent to shallowEqual, but also compares nested tables.
    ```lua
    Utils.deepEqual({a=1, b={1,2,3}}, {a=1, b={1,2,3}}) -> true
    ```
--]]
function Utils.deepEqual(a: any, b: any): boolean
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    for k, v in a do
        if not Utils.deepEqual(v, b[k]) then
            return false
        end
    end

    for k, v in b do
        if a[k] == nil or not Utils.deepEqual(v, a[k]) then
            return false
        end
    end

    return true
end

--[[
    Resolves the nearest Enum.NormalId based on a vector normal.
    (important) Assumes that `normal` is a unit vector.
--]]
local NORMAL_IDS_EXCEPT_TOP: { [Enum.NormalId]: Vector3 } = {
    [Enum.NormalId.Right] = Vector3.fromNormalId(Enum.NormalId.Right),
    [Enum.NormalId.Left] = Vector3.fromNormalId(Enum.NormalId.Left),
    [Enum.NormalId.Front] = Vector3.fromNormalId(Enum.NormalId.Front),
    [Enum.NormalId.Back] = Vector3.fromNormalId(Enum.NormalId.Back),
    [Enum.NormalId.Bottom] = Vector3.fromNormalId(Enum.NormalId.Bottom),
}
function Utils.resolveNormalId(part: Part, normal: Vector3): Enum.NormalId
    for normalId, untransformedTrueNormal in NORMAL_IDS_EXCEPT_TOP do
        --[[
        Un-optimized solution:

        local trueNormal = part.CFrame:VectorToWorldSpace(untransformedTrueNormal)
        local angle = math.acos(trueNormal:Dot(normal) / (trueNormal.Magnitude * normal.Magnitude))
        if angle <= math.radians(45) then
            return normalId
        end
        --]]

        -- optimized, assuming that the provided normal is a unit vector
        if part.CFrame:VectorToWorldSpace(untransformedTrueNormal):Dot(normal) >= 0.707106781186547 then
            return normalId
        end
    end

    return Enum.NormalId.Top
end

--[[
    Reverses an array in place.
--]]
function Utils.ireverse<V>(tab: { V })
    local n = #tab
    for i = 1, n // 2 do
        local j = n - i + 1
        tab[i], tab[j] = tab[j], tab[i]
    end
    return tab
end

--[[
    Same as ireverse, but makes a copy first.
--]]
function Utils.reverse<V>(tab: { V })
    local copy = table.clone(tab)
    Utils.ireverse(copy)
    return copy
end

return Utils
