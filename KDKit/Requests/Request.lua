--!strict

local HttpService = game:GetService("HttpService")

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local Url = require(script.Parent:WaitForChild("Url"))

export type Options = {
    headers: { [string]: string }?,
    params: { [string]: string }?,
    body: string?,
    json: any,
    compress: boolean?,
    timeout: number?,
}

type HttpRequestOptions = {
    Url: string,
    Method: string?,
    Headers: { [string]: string }?,
    Body: string?,
    Compress: Enum.HttpCompression?,
}

export type HttpResponseData = {
    Success: boolean,
    StatusCode: number,
    StatusMessage: string,
    Headers: { [string]: string },
    Body: string,
}

type RequestImpl = {
    __index: RequestImpl,
    new: (string | Url.Url, string?, Options?) -> Request,
    render: (Request) -> HttpRequestOptions,
    perform: (Request) -> HttpResponseData,
}
export type Request = typeof(setmetatable(
    {} :: {
        url: Url.Url,
        method: string,
        options: Options?,
    },
    {} :: RequestImpl
))

local Request: RequestImpl = {} :: RequestImpl
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
        o.Headers = Utils.mapf(function(v, k)
            return k:lower(), v
        end, self.options.headers)
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
    if not self.options or not self.options.timeout then
        return HttpService:RequestAsync(self:render())
    end

    local result
    coroutine.wrap(function()
        result = HttpService:RequestAsync(self:render())
    end)()

    local startedAt = os.clock()
    while not result do
        if os.clock() - startedAt > self.options.timeout then
            error(("Request timed out after %.2f second(s)."):format(self.options.timeout))
        end

        task.wait()
    end

    return result
end

return Request
