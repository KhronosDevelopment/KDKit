--!strict

local HttpService = game:GetService("HttpService")

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local T = require(script.Parent:WaitForChild("types"))
local Url = require(script.Parent:WaitForChild("Url"))
local Response = require(script.Parent:WaitForChild("Response"))

type Request = T.Request
type RequestImpl = T.RequestImpl
type HttpRequestOptions = T.HttpRequestOptions
type HttpResponseData = T.HttpResponseData

local Request: RequestImpl = {
    sentRequests = 0,
} :: RequestImpl
Request.__index = Request

function Request.new(url, method, options)
    local self = setmetatable({
        url = if typeof(url) == "string" then Url.new(url) else url,
        method = method or "GET",
        options = options,
    }, Request) :: Request

    return self
end

function Request:render()
    local o = {
        Method = self.method,
    } :: HttpRequestOptions

    if self.options and self.options.headers then
        o.Headers = Utils.mapf(self.options.headers, function(v, k)
            return k:lower(), v
        end)
    end

    if self.options and self.options.params then
        o.Url = self.url:withExtraParams(self.options.params):render()
    else
        o.Url = self.url:render()
    end

    if self.options and self.options.compress then
        o.Compress = Enum.HttpCompression.Gzip
    elseif self.options and self.options.compress == false then
        o.Compress = Enum.HttpCompression.None
    end

    if self.options and self.options.body then
        o.Body = self.options.body
    elseif self.options and self.options.json then
        o.Body = HttpService:JSONEncode(self.options.json)

        if not o.Headers then
            o.Headers = {}
        end
        assert(o.Headers)

        if not o.Headers["content-type"] then
            o.Headers["content-type"] = "application/json"
        end
    end

    return o
end

function Request:perform()
    local log = not self.options or self.options.log ~= false
    local render = self:render()

    Request.sentRequests += 1
    local id = Request.sentRequests

    if log then
        print(
            ("[KDKit.Requests - %d] Firing %s request to %s - "):format(
                id,
                render.Method or "HTTP",
                tostring(render.Url)
            ),
            render
        )
    end

    local sentAt = os.clock()
    local success, result = Utils.try(function()
        if not self.options or not self.options.timeout then
            return HttpService:RequestAsync(render)
        else
            local result
            coroutine.wrap(function()
                result = HttpService:RequestAsync(render)
            end)()

            local startedAt = os.clock()
            while not result do
                if os.clock() - startedAt > self.options.timeout then
                    error(("[KDKit.Requests - %d] Timed out after %.2f second(s)."):format(id, self.options.timeout))
                end

                task.wait()
            end

            return result
        end
    end):result()
    local responseAt = os.clock()

    if not success then
        assert(typeof(result) == "string")

        error(("[KDKit.Requests - %d] Threw an error:\n%s"):format(id, result))
    elseif log then
        local duration = responseAt - sentAt
        print(
            ("[KDKit.Requests - %d] Status code %d after %.4g ms - "):format(id, result.StatusCode, duration * 1000),
            result
        )
    end

    return Response.new(self, result :: T.HttpResponseData)
end

return Request
