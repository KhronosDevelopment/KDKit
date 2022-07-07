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
Endpoint.requestCounter = 0 -- increments upon each http request

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
		print(f'Endpoint.{flag_combination}{verb} = {function_generator}("{flag_combination}", "{verb}")')
```
--]]
Endpoint.GET = createRequestMethodWithoutPlayerSignature("", "GET")
Endpoint.dGET = createRequestMethodWithoutPlayerSignature("d", "GET")
Endpoint.uGET = createRequestMethodWithoutPlayerSignature("u", "GET")
Endpoint.eGET = createRequestMethodWithoutPlayerSignature("e", "GET")
Endpoint.sGET = createRequestMethodWithoutPlayerSignature("s", "GET")
Endpoint.duGET = createRequestMethodWithoutPlayerSignature("du", "GET")
Endpoint.deGET = createRequestMethodWithoutPlayerSignature("de", "GET")
Endpoint.dsGET = createRequestMethodWithoutPlayerSignature("ds", "GET")
Endpoint.ueGET = createRequestMethodWithoutPlayerSignature("ue", "GET")
Endpoint.usGET = createRequestMethodWithoutPlayerSignature("us", "GET")
Endpoint.esGET = createRequestMethodWithoutPlayerSignature("es", "GET")
Endpoint.dueGET = createRequestMethodWithoutPlayerSignature("due", "GET")
Endpoint.dusGET = createRequestMethodWithoutPlayerSignature("dus", "GET")
Endpoint.desGET = createRequestMethodWithoutPlayerSignature("des", "GET")
Endpoint.uesGET = createRequestMethodWithoutPlayerSignature("ues", "GET")
Endpoint.duesGET = createRequestMethodWithoutPlayerSignature("dues", "GET")
Endpoint.pGET = createRequestMethodWithPlayerSignature("p", "GET")
Endpoint.dpGET = createRequestMethodWithPlayerSignature("dp", "GET")
Endpoint.upGET = createRequestMethodWithPlayerSignature("up", "GET")
Endpoint.peGET = createRequestMethodWithPlayerSignature("pe", "GET")
Endpoint.psGET = createRequestMethodWithPlayerSignature("ps", "GET")
Endpoint.dupGET = createRequestMethodWithPlayerSignature("dup", "GET")
Endpoint.dpeGET = createRequestMethodWithPlayerSignature("dpe", "GET")
Endpoint.dpsGET = createRequestMethodWithPlayerSignature("dps", "GET")
Endpoint.upeGET = createRequestMethodWithPlayerSignature("upe", "GET")
Endpoint.upsGET = createRequestMethodWithPlayerSignature("ups", "GET")
Endpoint.pesGET = createRequestMethodWithPlayerSignature("pes", "GET")
Endpoint.dupeGET = createRequestMethodWithPlayerSignature("dupe", "GET")
Endpoint.dupsGET = createRequestMethodWithPlayerSignature("dups", "GET")
Endpoint.dpesGET = createRequestMethodWithPlayerSignature("dpes", "GET")
Endpoint.upesGET = createRequestMethodWithPlayerSignature("upes", "GET")
Endpoint.dupesGET = createRequestMethodWithPlayerSignature("dupes", "GET")

Endpoint.POST = createRequestMethodWithoutPlayerSignature("", "POST")
Endpoint.dPOST = createRequestMethodWithoutPlayerSignature("d", "POST")
Endpoint.uPOST = createRequestMethodWithoutPlayerSignature("u", "POST")
Endpoint.ePOST = createRequestMethodWithoutPlayerSignature("e", "POST")
Endpoint.sPOST = createRequestMethodWithoutPlayerSignature("s", "POST")
Endpoint.duPOST = createRequestMethodWithoutPlayerSignature("du", "POST")
Endpoint.dePOST = createRequestMethodWithoutPlayerSignature("de", "POST")
Endpoint.dsPOST = createRequestMethodWithoutPlayerSignature("ds", "POST")
Endpoint.uePOST = createRequestMethodWithoutPlayerSignature("ue", "POST")
Endpoint.usPOST = createRequestMethodWithoutPlayerSignature("us", "POST")
Endpoint.esPOST = createRequestMethodWithoutPlayerSignature("es", "POST")
Endpoint.duePOST = createRequestMethodWithoutPlayerSignature("due", "POST")
Endpoint.dusPOST = createRequestMethodWithoutPlayerSignature("dus", "POST")
Endpoint.desPOST = createRequestMethodWithoutPlayerSignature("des", "POST")
Endpoint.uesPOST = createRequestMethodWithoutPlayerSignature("ues", "POST")
Endpoint.duesPOST = createRequestMethodWithoutPlayerSignature("dues", "POST")
Endpoint.pPOST = createRequestMethodWithPlayerSignature("p", "POST")
Endpoint.dpPOST = createRequestMethodWithPlayerSignature("dp", "POST")
Endpoint.upPOST = createRequestMethodWithPlayerSignature("up", "POST")
Endpoint.pePOST = createRequestMethodWithPlayerSignature("pe", "POST")
Endpoint.psPOST = createRequestMethodWithPlayerSignature("ps", "POST")
Endpoint.dupPOST = createRequestMethodWithPlayerSignature("dup", "POST")
Endpoint.dpePOST = createRequestMethodWithPlayerSignature("dpe", "POST")
Endpoint.dpsPOST = createRequestMethodWithPlayerSignature("dps", "POST")
Endpoint.upePOST = createRequestMethodWithPlayerSignature("upe", "POST")
Endpoint.upsPOST = createRequestMethodWithPlayerSignature("ups", "POST")
Endpoint.pesPOST = createRequestMethodWithPlayerSignature("pes", "POST")
Endpoint.dupePOST = createRequestMethodWithPlayerSignature("dupe", "POST")
Endpoint.dupsPOST = createRequestMethodWithPlayerSignature("dups", "POST")
Endpoint.dpesPOST = createRequestMethodWithPlayerSignature("dpes", "POST")
Endpoint.upesPOST = createRequestMethodWithPlayerSignature("upes", "POST")
Endpoint.dupesPOST = createRequestMethodWithPlayerSignature("dupes", "POST")

Endpoint.PUT = createRequestMethodWithoutPlayerSignature("", "PUT")
Endpoint.dPUT = createRequestMethodWithoutPlayerSignature("d", "PUT")
Endpoint.uPUT = createRequestMethodWithoutPlayerSignature("u", "PUT")
Endpoint.ePUT = createRequestMethodWithoutPlayerSignature("e", "PUT")
Endpoint.sPUT = createRequestMethodWithoutPlayerSignature("s", "PUT")
Endpoint.duPUT = createRequestMethodWithoutPlayerSignature("du", "PUT")
Endpoint.dePUT = createRequestMethodWithoutPlayerSignature("de", "PUT")
Endpoint.dsPUT = createRequestMethodWithoutPlayerSignature("ds", "PUT")
Endpoint.uePUT = createRequestMethodWithoutPlayerSignature("ue", "PUT")
Endpoint.usPUT = createRequestMethodWithoutPlayerSignature("us", "PUT")
Endpoint.esPUT = createRequestMethodWithoutPlayerSignature("es", "PUT")
Endpoint.duePUT = createRequestMethodWithoutPlayerSignature("due", "PUT")
Endpoint.dusPUT = createRequestMethodWithoutPlayerSignature("dus", "PUT")
Endpoint.desPUT = createRequestMethodWithoutPlayerSignature("des", "PUT")
Endpoint.uesPUT = createRequestMethodWithoutPlayerSignature("ues", "PUT")
Endpoint.duesPUT = createRequestMethodWithoutPlayerSignature("dues", "PUT")
Endpoint.pPUT = createRequestMethodWithPlayerSignature("p", "PUT")
Endpoint.dpPUT = createRequestMethodWithPlayerSignature("dp", "PUT")
Endpoint.upPUT = createRequestMethodWithPlayerSignature("up", "PUT")
Endpoint.pePUT = createRequestMethodWithPlayerSignature("pe", "PUT")
Endpoint.psPUT = createRequestMethodWithPlayerSignature("ps", "PUT")
Endpoint.dupPUT = createRequestMethodWithPlayerSignature("dup", "PUT")
Endpoint.dpePUT = createRequestMethodWithPlayerSignature("dpe", "PUT")
Endpoint.dpsPUT = createRequestMethodWithPlayerSignature("dps", "PUT")
Endpoint.upePUT = createRequestMethodWithPlayerSignature("upe", "PUT")
Endpoint.upsPUT = createRequestMethodWithPlayerSignature("ups", "PUT")
Endpoint.pesPUT = createRequestMethodWithPlayerSignature("pes", "PUT")
Endpoint.dupePUT = createRequestMethodWithPlayerSignature("dupe", "PUT")
Endpoint.dupsPUT = createRequestMethodWithPlayerSignature("dups", "PUT")
Endpoint.dpesPUT = createRequestMethodWithPlayerSignature("dpes", "PUT")
Endpoint.upesPUT = createRequestMethodWithPlayerSignature("upes", "PUT")
Endpoint.dupesPUT = createRequestMethodWithPlayerSignature("dupes", "PUT")

Endpoint.PATCH = createRequestMethodWithoutPlayerSignature("", "PATCH")
Endpoint.dPATCH = createRequestMethodWithoutPlayerSignature("d", "PATCH")
Endpoint.uPATCH = createRequestMethodWithoutPlayerSignature("u", "PATCH")
Endpoint.ePATCH = createRequestMethodWithoutPlayerSignature("e", "PATCH")
Endpoint.sPATCH = createRequestMethodWithoutPlayerSignature("s", "PATCH")
Endpoint.duPATCH = createRequestMethodWithoutPlayerSignature("du", "PATCH")
Endpoint.dePATCH = createRequestMethodWithoutPlayerSignature("de", "PATCH")
Endpoint.dsPATCH = createRequestMethodWithoutPlayerSignature("ds", "PATCH")
Endpoint.uePATCH = createRequestMethodWithoutPlayerSignature("ue", "PATCH")
Endpoint.usPATCH = createRequestMethodWithoutPlayerSignature("us", "PATCH")
Endpoint.esPATCH = createRequestMethodWithoutPlayerSignature("es", "PATCH")
Endpoint.duePATCH = createRequestMethodWithoutPlayerSignature("due", "PATCH")
Endpoint.dusPATCH = createRequestMethodWithoutPlayerSignature("dus", "PATCH")
Endpoint.desPATCH = createRequestMethodWithoutPlayerSignature("des", "PATCH")
Endpoint.uesPATCH = createRequestMethodWithoutPlayerSignature("ues", "PATCH")
Endpoint.duesPATCH = createRequestMethodWithoutPlayerSignature("dues", "PATCH")
Endpoint.pPATCH = createRequestMethodWithPlayerSignature("p", "PATCH")
Endpoint.dpPATCH = createRequestMethodWithPlayerSignature("dp", "PATCH")
Endpoint.upPATCH = createRequestMethodWithPlayerSignature("up", "PATCH")
Endpoint.pePATCH = createRequestMethodWithPlayerSignature("pe", "PATCH")
Endpoint.psPATCH = createRequestMethodWithPlayerSignature("ps", "PATCH")
Endpoint.dupPATCH = createRequestMethodWithPlayerSignature("dup", "PATCH")
Endpoint.dpePATCH = createRequestMethodWithPlayerSignature("dpe", "PATCH")
Endpoint.dpsPATCH = createRequestMethodWithPlayerSignature("dps", "PATCH")
Endpoint.upePATCH = createRequestMethodWithPlayerSignature("upe", "PATCH")
Endpoint.upsPATCH = createRequestMethodWithPlayerSignature("ups", "PATCH")
Endpoint.pesPATCH = createRequestMethodWithPlayerSignature("pes", "PATCH")
Endpoint.dupePATCH = createRequestMethodWithPlayerSignature("dupe", "PATCH")
Endpoint.dupsPATCH = createRequestMethodWithPlayerSignature("dups", "PATCH")
Endpoint.dpesPATCH = createRequestMethodWithPlayerSignature("dpes", "PATCH")
Endpoint.upesPATCH = createRequestMethodWithPlayerSignature("upes", "PATCH")
Endpoint.dupesPATCH = createRequestMethodWithPlayerSignature("dupes", "PATCH")

Endpoint.DELETE = createRequestMethodWithoutPlayerSignature("", "DELETE")
Endpoint.dDELETE = createRequestMethodWithoutPlayerSignature("d", "DELETE")
Endpoint.uDELETE = createRequestMethodWithoutPlayerSignature("u", "DELETE")
Endpoint.eDELETE = createRequestMethodWithoutPlayerSignature("e", "DELETE")
Endpoint.sDELETE = createRequestMethodWithoutPlayerSignature("s", "DELETE")
Endpoint.duDELETE = createRequestMethodWithoutPlayerSignature("du", "DELETE")
Endpoint.deDELETE = createRequestMethodWithoutPlayerSignature("de", "DELETE")
Endpoint.dsDELETE = createRequestMethodWithoutPlayerSignature("ds", "DELETE")
Endpoint.ueDELETE = createRequestMethodWithoutPlayerSignature("ue", "DELETE")
Endpoint.usDELETE = createRequestMethodWithoutPlayerSignature("us", "DELETE")
Endpoint.esDELETE = createRequestMethodWithoutPlayerSignature("es", "DELETE")
Endpoint.dueDELETE = createRequestMethodWithoutPlayerSignature("due", "DELETE")
Endpoint.dusDELETE = createRequestMethodWithoutPlayerSignature("dus", "DELETE")
Endpoint.desDELETE = createRequestMethodWithoutPlayerSignature("des", "DELETE")
Endpoint.uesDELETE = createRequestMethodWithoutPlayerSignature("ues", "DELETE")
Endpoint.duesDELETE = createRequestMethodWithoutPlayerSignature("dues", "DELETE")
Endpoint.pDELETE = createRequestMethodWithPlayerSignature("p", "DELETE")
Endpoint.dpDELETE = createRequestMethodWithPlayerSignature("dp", "DELETE")
Endpoint.upDELETE = createRequestMethodWithPlayerSignature("up", "DELETE")
Endpoint.peDELETE = createRequestMethodWithPlayerSignature("pe", "DELETE")
Endpoint.psDELETE = createRequestMethodWithPlayerSignature("ps", "DELETE")
Endpoint.dupDELETE = createRequestMethodWithPlayerSignature("dup", "DELETE")
Endpoint.dpeDELETE = createRequestMethodWithPlayerSignature("dpe", "DELETE")
Endpoint.dpsDELETE = createRequestMethodWithPlayerSignature("dps", "DELETE")
Endpoint.upeDELETE = createRequestMethodWithPlayerSignature("upe", "DELETE")
Endpoint.upsDELETE = createRequestMethodWithPlayerSignature("ups", "DELETE")
Endpoint.pesDELETE = createRequestMethodWithPlayerSignature("pes", "DELETE")
Endpoint.dupeDELETE = createRequestMethodWithPlayerSignature("dupe", "DELETE")
Endpoint.dupsDELETE = createRequestMethodWithPlayerSignature("dups", "DELETE")
Endpoint.dpesDELETE = createRequestMethodWithPlayerSignature("dpes", "DELETE")
Endpoint.upesDELETE = createRequestMethodWithPlayerSignature("upes", "DELETE")
Endpoint.dupesDELETE = createRequestMethodWithPlayerSignature("dupes", "DELETE")

return Endpoint
