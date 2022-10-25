--[[
	This is a class that should only be constructed interanally by API itself.
	It represents a path relative to a config.

	`API.my_configuration` will return an `Endpoint`.
	and
	`API.my_configuration / "path"` will return a different `Endpoint` but with the same config.

	See top-level `API` docs to see what an `Endpoint` can do.
--]]

local HttpService = game:GetService("HttpService")

local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Config = require(script.Parent:WaitForChild("Config"))

local Endpoint = Class.new("KDKit.API.Endpoint")
Endpoint.static.requestCounter = 0 -- increments upon each http request

local STANDARD_LEGAL_URL_CHARACTERS = {
    [":"] = true,
    ["-"] = true,
    ["_"] = true,
    ["."] = true,
    ["!"] = true,
    ["~"] = true,
    ["*"] = true,
    ["'"] = true,
    ["("] = true,
    [")"] = true,
    ["@"] = true,
    ["="] = true,
    ["$"] = true,
    [","] = true,
    [";"] = true,
}
local function urlEncode(str)
    if type(str) ~= "string" then
        str = Utils:repr(str)
    end
    return str:gsub("([^a-zA-Z0-9])", function(v)
        if STANDARD_LEGAL_URL_CHARACTERS[v] then
            return v
        end
        if v == " " then
            return "+"
        end
        return ("%%%02X"):format(v:byte())
    end)
end

-- Format a table of arguments into URL arguments.
-- Doesn't support list-arguments or otherwise nested data.
-- for example: `"website.com" .. formatURLArguments({ arg = 123 })` -> "website.com?arg=123"
local function formatURLArguments(arguments)
    if not arguments or not next(arguments) then
        return ""
    end

    local kvPairs = table.create(32) -- arbitrarily chose 32, since I can't imagine ever using more than that
    for k, v in arguments do
        table.insert(kvPairs, urlEncode(k) .. "=" .. urlEncode(v))
    end

    return "?" .. table.concat(kvPairs, "&")
end

function Endpoint:__init(config, path)
    self.config = config
    self.path = path or {}

    for i, pathSegment in self.path do
        if type(pathSegment) ~= "string" then
            pathSegment = Utils:repr(pathSegment)
        end
        self.path[i] = urlEncode(pathSegment:gsub("^/+", ""):gsub("/+$", ""))
    end
end

function Endpoint:__div(ext)
    local newPath = table.clone(self.path)
    table.insert(newPath, ext)
    return Endpoint.new(self.config, newPath)
end

function Endpoint:renderURL()
    local url = self.config.url

    if url:sub(url:len()) ~= "/" then
        url ..= "/"
    end

    return url .. table.concat(self.path, "/") .. "/"
end

-- makes a blocking HTTP request, and returns `success, jsonDecodedDataOrErrorMessage, rawHttpResponseData`
function Endpoint:makeRawRequest(requestAsyncArgs)
    Endpoint.requestCounter += 1
    local thisRequestId = Endpoint.requestCounter
    local logPrefix = ("[API REQUEST %d]"):format(thisRequestId)
    local logLevel = self.config.logLevel

    if logLevel <= Config.LOG_LEVEL.DEBUG then
        print(("%s %s %s"):format(logPrefix, requestAsyncArgs.Method, requestAsyncArgs.Url), requestAsyncArgs)
    elseif logLevel <= Config.LOG_LEVEL.INFO then
        print(("%s %s %s"):format(logPrefix, requestAsyncArgs.Method, requestAsyncArgs.Url))
    end

    self.config:useRateLimit()

    local httpSuccess, httpResponse = pcall(HttpService.RequestAsync, HttpService, requestAsyncArgs)

    if not httpSuccess then
        if logLevel <= Config.LOG_LEVEL.ERROR then
            warn(("%s HttpService:RequestAsync failed with error message: %s"):format(logPrefix, httpResponse))
        end
        return false, "HTTP error: " .. httpResponse, nil
    end

    if not httpResponse.Success then -- response.StatusCode not on [200, 299]
        if logLevel <= Config.LOG_LEVEL.ERROR then
            warn(("%s Failed with status code %d"):format(logPrefix, httpResponse.StatusCode), httpResponse)
        end
        return false,
            ("Non-2xx status code %d. Raw response: %s"):format(httpResponse.StatusCode, httpResponse.Body),
            httpResponse
    end

    local jsonDecodeSuccess, jsonDecodeResponse = pcall(HttpService.JSONDecode, HttpService, httpResponse.Body)
    if not jsonDecodeSuccess then
        if logLevel <= Config.LOG_LEVEL.ERROR then
            warn(
                ("%s HttpService:JSONDecode failed with error message: %s"):format(logPrefix, jsonDecodeResponse),
                httpResponse
            )
        end
        return false, ("Invalid JSON data. Raw response: %s"):format(httpResponse.Body), httpResponse
    end

    if logLevel <= Config.LOG_LEVEL.DEBUG then
        print(("%s Succeeded with status code %d."):format(logPrefix, httpResponse.StatusCode), jsonDecodeResponse)
    elseif logLevel <= Config.LOG_LEVEL.INFO then
        print(("%s Succeeded with status code %d."):format(logPrefix, httpResponse.StatusCode))
    end

    return true, jsonDecodeResponse, httpResponse
end

-- makes a json-body request (such as POST, PUT, PATCH, DELETE, but not GET)
function Endpoint:makeGenericJSONBodyRequest(verb, data, headers)
    if not headers["Content-Type"] then
        headers["Content-Type"] = "application/json"
    end

    return self:makeRawRequest({
        Method = verb,
        Url = self:renderURL(),
        Headers = headers,
        Body = Utils:safeJSONEncode(data),
    })
end

-- makes a request with URL arguments (which is only GET requests)
function Endpoint:makeGenericURLArgumentsRequest(verb, data, headers)
    return self:makeRawRequest({
        Method = verb,
        Url = self:renderURL() .. formatURLArguments(data),
        Headers = headers,
    })
end

function Endpoint:request(flags, verb, data, headers, player)
    if flags.player and (not player or not player:IsA("Player")) then
        error("You must specify a player when using the `p` flag.")
    end

    headers = headers or {}
    data = data or {}

    self.config:modifyHeadersBeforeRequest(headers, {
        flags = flags,
        verb = verb,
        data = data,
        player = player,
    })

    local function perform()
        local success, response, rawResponse
        if verb:lower() == "get" then
            success, response, rawResponse = self:makeGenericURLArgumentsRequest(verb, data, headers)
        else
            success, response, rawResponse = self:makeGenericJSONBodyRequest(verb, data, headers)
        end

        if flags.erroneous then
            if not success then
                error(response)
            else
                return response, rawResponse
            end
        end

        return success, response, rawResponse
    end

    if flags.deferred then
        task.defer(perform)
    else
        return perform()
    end
end

--[[
	there are 5 supported verbs: GET, POST, PUT, PATCH, DELETE
	and 5 supported flags:
		- [d]eferred indicates that the request will be `task.defer`'d. I highly recommend you also include the `e` flag so that the errors aren't silently dropped and will instead be printed in console.
		- [u]nauthenticated indicates that the request should not include authentication headers
		- [p]layer indicates that a specific player is linked to the request
		- [e]rroneous indicates that the request should raise an error upon failure, rather than returning success = false
		- [s]erverless indicates that the request headers should not contain any data pertaining to the server

	I will painstakingly create a function for each of these combinations rather than using a loop,
	so that IDE's can autocomplete. You're welcome.
--]]
function createRequestMethod(flags, verb)
    flags = {
        deferred = not not flags:find("d"),
        unauthenticated = not not flags:find("u"),
        player = not not flags:find("p"),
        erroneous = not not flags:find("e"),
        serverless = not not flags:find("s"),
    }
    verb = verb:upper()

    if flags.player then
        return function(self, player, data, headers)
            return self:request(flags, verb, data, headers, player)
        end
    else
        return function(self, data, headers)
            return self:request(flags, verb, data, headers, nil)
        end
    end
end

function createRequestMethodWithoutPlayerSignature(...): (self: "Endpoint", data: table, headers: table) -> any
    return createRequestMethod(...)
end

function createRequestMethodWithPlayerSignature(
    ...
): (self: "Endpoint", player: Player, data: table, headers: table) -> any
    return createRequestMethod(...)
end

--[[
Autogenerated using python:
```py
import itertools

flags = 'dupes'
flag_combinations = list(map(
	''.join,
	(combination for i in range(len(flags) + 1) for combination in itertools.combinations(flags, i))
))

flag_combinations.sort(key=lambda combo: 'p' in combo)

for verb in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']:
	print()
	for flag_combination in flag_combinations:
		function_generator = 'createRequestMethodWithPlayerSignature' if 'p' in flag_combination else 'createRequestMethodWithoutPlayerSignature'
		print(f'Endpoint.static.{flag_combination}{verb} = {function_generator}("{flag_combination}", "{verb}")')
```
--]]
Endpoint.static.GET = createRequestMethodWithoutPlayerSignature("", "GET")
Endpoint.static.dGET = createRequestMethodWithoutPlayerSignature("d", "GET")
Endpoint.static.uGET = createRequestMethodWithoutPlayerSignature("u", "GET")
Endpoint.static.eGET = createRequestMethodWithoutPlayerSignature("e", "GET")
Endpoint.static.sGET = createRequestMethodWithoutPlayerSignature("s", "GET")
Endpoint.static.duGET = createRequestMethodWithoutPlayerSignature("du", "GET")
Endpoint.static.deGET = createRequestMethodWithoutPlayerSignature("de", "GET")
Endpoint.static.dsGET = createRequestMethodWithoutPlayerSignature("ds", "GET")
Endpoint.static.ueGET = createRequestMethodWithoutPlayerSignature("ue", "GET")
Endpoint.static.usGET = createRequestMethodWithoutPlayerSignature("us", "GET")
Endpoint.static.esGET = createRequestMethodWithoutPlayerSignature("es", "GET")
Endpoint.static.dueGET = createRequestMethodWithoutPlayerSignature("due", "GET")
Endpoint.static.dusGET = createRequestMethodWithoutPlayerSignature("dus", "GET")
Endpoint.static.desGET = createRequestMethodWithoutPlayerSignature("des", "GET")
Endpoint.static.uesGET = createRequestMethodWithoutPlayerSignature("ues", "GET")
Endpoint.static.duesGET = createRequestMethodWithoutPlayerSignature("dues", "GET")
Endpoint.static.pGET = createRequestMethodWithPlayerSignature("p", "GET")
Endpoint.static.dpGET = createRequestMethodWithPlayerSignature("dp", "GET")
Endpoint.static.upGET = createRequestMethodWithPlayerSignature("up", "GET")
Endpoint.static.peGET = createRequestMethodWithPlayerSignature("pe", "GET")
Endpoint.static.psGET = createRequestMethodWithPlayerSignature("ps", "GET")
Endpoint.static.dupGET = createRequestMethodWithPlayerSignature("dup", "GET")
Endpoint.static.dpeGET = createRequestMethodWithPlayerSignature("dpe", "GET")
Endpoint.static.dpsGET = createRequestMethodWithPlayerSignature("dps", "GET")
Endpoint.static.upeGET = createRequestMethodWithPlayerSignature("upe", "GET")
Endpoint.static.upsGET = createRequestMethodWithPlayerSignature("ups", "GET")
Endpoint.static.pesGET = createRequestMethodWithPlayerSignature("pes", "GET")
Endpoint.static.dupeGET = createRequestMethodWithPlayerSignature("dupe", "GET")
Endpoint.static.dupsGET = createRequestMethodWithPlayerSignature("dups", "GET")
Endpoint.static.dpesGET = createRequestMethodWithPlayerSignature("dpes", "GET")
Endpoint.static.upesGET = createRequestMethodWithPlayerSignature("upes", "GET")
Endpoint.static.dupesGET = createRequestMethodWithPlayerSignature("dupes", "GET")

Endpoint.static.POST = createRequestMethodWithoutPlayerSignature("", "POST")
Endpoint.static.dPOST = createRequestMethodWithoutPlayerSignature("d", "POST")
Endpoint.static.uPOST = createRequestMethodWithoutPlayerSignature("u", "POST")
Endpoint.static.ePOST = createRequestMethodWithoutPlayerSignature("e", "POST")
Endpoint.static.sPOST = createRequestMethodWithoutPlayerSignature("s", "POST")
Endpoint.static.duPOST = createRequestMethodWithoutPlayerSignature("du", "POST")
Endpoint.static.dePOST = createRequestMethodWithoutPlayerSignature("de", "POST")
Endpoint.static.dsPOST = createRequestMethodWithoutPlayerSignature("ds", "POST")
Endpoint.static.uePOST = createRequestMethodWithoutPlayerSignature("ue", "POST")
Endpoint.static.usPOST = createRequestMethodWithoutPlayerSignature("us", "POST")
Endpoint.static.esPOST = createRequestMethodWithoutPlayerSignature("es", "POST")
Endpoint.static.duePOST = createRequestMethodWithoutPlayerSignature("due", "POST")
Endpoint.static.dusPOST = createRequestMethodWithoutPlayerSignature("dus", "POST")
Endpoint.static.desPOST = createRequestMethodWithoutPlayerSignature("des", "POST")
Endpoint.static.uesPOST = createRequestMethodWithoutPlayerSignature("ues", "POST")
Endpoint.static.duesPOST = createRequestMethodWithoutPlayerSignature("dues", "POST")
Endpoint.static.pPOST = createRequestMethodWithPlayerSignature("p", "POST")
Endpoint.static.dpPOST = createRequestMethodWithPlayerSignature("dp", "POST")
Endpoint.static.upPOST = createRequestMethodWithPlayerSignature("up", "POST")
Endpoint.static.pePOST = createRequestMethodWithPlayerSignature("pe", "POST")
Endpoint.static.psPOST = createRequestMethodWithPlayerSignature("ps", "POST")
Endpoint.static.dupPOST = createRequestMethodWithPlayerSignature("dup", "POST")
Endpoint.static.dpePOST = createRequestMethodWithPlayerSignature("dpe", "POST")
Endpoint.static.dpsPOST = createRequestMethodWithPlayerSignature("dps", "POST")
Endpoint.static.upePOST = createRequestMethodWithPlayerSignature("upe", "POST")
Endpoint.static.upsPOST = createRequestMethodWithPlayerSignature("ups", "POST")
Endpoint.static.pesPOST = createRequestMethodWithPlayerSignature("pes", "POST")
Endpoint.static.dupePOST = createRequestMethodWithPlayerSignature("dupe", "POST")
Endpoint.static.dupsPOST = createRequestMethodWithPlayerSignature("dups", "POST")
Endpoint.static.dpesPOST = createRequestMethodWithPlayerSignature("dpes", "POST")
Endpoint.static.upesPOST = createRequestMethodWithPlayerSignature("upes", "POST")
Endpoint.static.dupesPOST = createRequestMethodWithPlayerSignature("dupes", "POST")

Endpoint.static.PUT = createRequestMethodWithoutPlayerSignature("", "PUT")
Endpoint.static.dPUT = createRequestMethodWithoutPlayerSignature("d", "PUT")
Endpoint.static.uPUT = createRequestMethodWithoutPlayerSignature("u", "PUT")
Endpoint.static.ePUT = createRequestMethodWithoutPlayerSignature("e", "PUT")
Endpoint.static.sPUT = createRequestMethodWithoutPlayerSignature("s", "PUT")
Endpoint.static.duPUT = createRequestMethodWithoutPlayerSignature("du", "PUT")
Endpoint.static.dePUT = createRequestMethodWithoutPlayerSignature("de", "PUT")
Endpoint.static.dsPUT = createRequestMethodWithoutPlayerSignature("ds", "PUT")
Endpoint.static.uePUT = createRequestMethodWithoutPlayerSignature("ue", "PUT")
Endpoint.static.usPUT = createRequestMethodWithoutPlayerSignature("us", "PUT")
Endpoint.static.esPUT = createRequestMethodWithoutPlayerSignature("es", "PUT")
Endpoint.static.duePUT = createRequestMethodWithoutPlayerSignature("due", "PUT")
Endpoint.static.dusPUT = createRequestMethodWithoutPlayerSignature("dus", "PUT")
Endpoint.static.desPUT = createRequestMethodWithoutPlayerSignature("des", "PUT")
Endpoint.static.uesPUT = createRequestMethodWithoutPlayerSignature("ues", "PUT")
Endpoint.static.duesPUT = createRequestMethodWithoutPlayerSignature("dues", "PUT")
Endpoint.static.pPUT = createRequestMethodWithPlayerSignature("p", "PUT")
Endpoint.static.dpPUT = createRequestMethodWithPlayerSignature("dp", "PUT")
Endpoint.static.upPUT = createRequestMethodWithPlayerSignature("up", "PUT")
Endpoint.static.pePUT = createRequestMethodWithPlayerSignature("pe", "PUT")
Endpoint.static.psPUT = createRequestMethodWithPlayerSignature("ps", "PUT")
Endpoint.static.dupPUT = createRequestMethodWithPlayerSignature("dup", "PUT")
Endpoint.static.dpePUT = createRequestMethodWithPlayerSignature("dpe", "PUT")
Endpoint.static.dpsPUT = createRequestMethodWithPlayerSignature("dps", "PUT")
Endpoint.static.upePUT = createRequestMethodWithPlayerSignature("upe", "PUT")
Endpoint.static.upsPUT = createRequestMethodWithPlayerSignature("ups", "PUT")
Endpoint.static.pesPUT = createRequestMethodWithPlayerSignature("pes", "PUT")
Endpoint.static.dupePUT = createRequestMethodWithPlayerSignature("dupe", "PUT")
Endpoint.static.dupsPUT = createRequestMethodWithPlayerSignature("dups", "PUT")
Endpoint.static.dpesPUT = createRequestMethodWithPlayerSignature("dpes", "PUT")
Endpoint.static.upesPUT = createRequestMethodWithPlayerSignature("upes", "PUT")
Endpoint.static.dupesPUT = createRequestMethodWithPlayerSignature("dupes", "PUT")

Endpoint.static.PATCH = createRequestMethodWithoutPlayerSignature("", "PATCH")
Endpoint.static.dPATCH = createRequestMethodWithoutPlayerSignature("d", "PATCH")
Endpoint.static.uPATCH = createRequestMethodWithoutPlayerSignature("u", "PATCH")
Endpoint.static.ePATCH = createRequestMethodWithoutPlayerSignature("e", "PATCH")
Endpoint.static.sPATCH = createRequestMethodWithoutPlayerSignature("s", "PATCH")
Endpoint.static.duPATCH = createRequestMethodWithoutPlayerSignature("du", "PATCH")
Endpoint.static.dePATCH = createRequestMethodWithoutPlayerSignature("de", "PATCH")
Endpoint.static.dsPATCH = createRequestMethodWithoutPlayerSignature("ds", "PATCH")
Endpoint.static.uePATCH = createRequestMethodWithoutPlayerSignature("ue", "PATCH")
Endpoint.static.usPATCH = createRequestMethodWithoutPlayerSignature("us", "PATCH")
Endpoint.static.esPATCH = createRequestMethodWithoutPlayerSignature("es", "PATCH")
Endpoint.static.duePATCH = createRequestMethodWithoutPlayerSignature("due", "PATCH")
Endpoint.static.dusPATCH = createRequestMethodWithoutPlayerSignature("dus", "PATCH")
Endpoint.static.desPATCH = createRequestMethodWithoutPlayerSignature("des", "PATCH")
Endpoint.static.uesPATCH = createRequestMethodWithoutPlayerSignature("ues", "PATCH")
Endpoint.static.duesPATCH = createRequestMethodWithoutPlayerSignature("dues", "PATCH")
Endpoint.static.pPATCH = createRequestMethodWithPlayerSignature("p", "PATCH")
Endpoint.static.dpPATCH = createRequestMethodWithPlayerSignature("dp", "PATCH")
Endpoint.static.upPATCH = createRequestMethodWithPlayerSignature("up", "PATCH")
Endpoint.static.pePATCH = createRequestMethodWithPlayerSignature("pe", "PATCH")
Endpoint.static.psPATCH = createRequestMethodWithPlayerSignature("ps", "PATCH")
Endpoint.static.dupPATCH = createRequestMethodWithPlayerSignature("dup", "PATCH")
Endpoint.static.dpePATCH = createRequestMethodWithPlayerSignature("dpe", "PATCH")
Endpoint.static.dpsPATCH = createRequestMethodWithPlayerSignature("dps", "PATCH")
Endpoint.static.upePATCH = createRequestMethodWithPlayerSignature("upe", "PATCH")
Endpoint.static.upsPATCH = createRequestMethodWithPlayerSignature("ups", "PATCH")
Endpoint.static.pesPATCH = createRequestMethodWithPlayerSignature("pes", "PATCH")
Endpoint.static.dupePATCH = createRequestMethodWithPlayerSignature("dupe", "PATCH")
Endpoint.static.dupsPATCH = createRequestMethodWithPlayerSignature("dups", "PATCH")
Endpoint.static.dpesPATCH = createRequestMethodWithPlayerSignature("dpes", "PATCH")
Endpoint.static.upesPATCH = createRequestMethodWithPlayerSignature("upes", "PATCH")
Endpoint.static.dupesPATCH = createRequestMethodWithPlayerSignature("dupes", "PATCH")

Endpoint.static.DELETE = createRequestMethodWithoutPlayerSignature("", "DELETE")
Endpoint.static.dDELETE = createRequestMethodWithoutPlayerSignature("d", "DELETE")
Endpoint.static.uDELETE = createRequestMethodWithoutPlayerSignature("u", "DELETE")
Endpoint.static.eDELETE = createRequestMethodWithoutPlayerSignature("e", "DELETE")
Endpoint.static.sDELETE = createRequestMethodWithoutPlayerSignature("s", "DELETE")
Endpoint.static.duDELETE = createRequestMethodWithoutPlayerSignature("du", "DELETE")
Endpoint.static.deDELETE = createRequestMethodWithoutPlayerSignature("de", "DELETE")
Endpoint.static.dsDELETE = createRequestMethodWithoutPlayerSignature("ds", "DELETE")
Endpoint.static.ueDELETE = createRequestMethodWithoutPlayerSignature("ue", "DELETE")
Endpoint.static.usDELETE = createRequestMethodWithoutPlayerSignature("us", "DELETE")
Endpoint.static.esDELETE = createRequestMethodWithoutPlayerSignature("es", "DELETE")
Endpoint.static.dueDELETE = createRequestMethodWithoutPlayerSignature("due", "DELETE")
Endpoint.static.dusDELETE = createRequestMethodWithoutPlayerSignature("dus", "DELETE")
Endpoint.static.desDELETE = createRequestMethodWithoutPlayerSignature("des", "DELETE")
Endpoint.static.uesDELETE = createRequestMethodWithoutPlayerSignature("ues", "DELETE")
Endpoint.static.duesDELETE = createRequestMethodWithoutPlayerSignature("dues", "DELETE")
Endpoint.static.pDELETE = createRequestMethodWithPlayerSignature("p", "DELETE")
Endpoint.static.dpDELETE = createRequestMethodWithPlayerSignature("dp", "DELETE")
Endpoint.static.upDELETE = createRequestMethodWithPlayerSignature("up", "DELETE")
Endpoint.static.peDELETE = createRequestMethodWithPlayerSignature("pe", "DELETE")
Endpoint.static.psDELETE = createRequestMethodWithPlayerSignature("ps", "DELETE")
Endpoint.static.dupDELETE = createRequestMethodWithPlayerSignature("dup", "DELETE")
Endpoint.static.dpeDELETE = createRequestMethodWithPlayerSignature("dpe", "DELETE")
Endpoint.static.dpsDELETE = createRequestMethodWithPlayerSignature("dps", "DELETE")
Endpoint.static.upeDELETE = createRequestMethodWithPlayerSignature("upe", "DELETE")
Endpoint.static.upsDELETE = createRequestMethodWithPlayerSignature("ups", "DELETE")
Endpoint.static.pesDELETE = createRequestMethodWithPlayerSignature("pes", "DELETE")
Endpoint.static.dupeDELETE = createRequestMethodWithPlayerSignature("dupe", "DELETE")
Endpoint.static.dupsDELETE = createRequestMethodWithPlayerSignature("dups", "DELETE")
Endpoint.static.dpesDELETE = createRequestMethodWithPlayerSignature("dpes", "DELETE")
Endpoint.static.upesDELETE = createRequestMethodWithPlayerSignature("upes", "DELETE")
Endpoint.static.dupesDELETE = createRequestMethodWithPlayerSignature("dupes", "DELETE")

return Endpoint
