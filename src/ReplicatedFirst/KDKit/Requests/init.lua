--!strict

local HttpService = game:GetService("HttpService")

local Url = require(script:WaitForChild("Url"))
local Request = require(script:WaitForChild("Request"))
local Response = require(script:WaitForChild("Response"))

export type Url = Url.Url
export type Request = Request.Request
export type Response = Response.Response

local Requests = {
    Url = Url,
    Request = Request,
    Response = Response,
}

type HttpResponseData = {
    Success: boolean,
    StatusCode: number,
    StatusMessage: string,
    Headers: { [string]: string },
    Body: string,
}

local function makeRequester(method: string): (url: string | Url, options: Request.Options?) -> Response
    return function(url, options)
        local request = Request.new(url, method, options)
        local response = HttpService:RequestAsync(request:render()) :: HttpResponseData
        return Response.new(request, response.StatusCode, response.StatusMessage, response.Headers, response.Body)
    end
end

Requests.get = makeRequester("GET")
Requests.post = makeRequester("POST")
Requests.patch = makeRequester("PATCH")
Requests.put = makeRequester("PUT")
Requests.delete = makeRequester("DELETE")
Requests.head = makeRequester("HEAD")
Requests.options = makeRequester("OPTIONS")

return Requests
