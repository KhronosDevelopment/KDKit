--!strict

local T = require(script:WaitForChild("types"))
local Url = require(script:WaitForChild("Url"))
local Request = require(script:WaitForChild("Request"))
local Response = require(script:WaitForChild("Response"))

export type Url = T.Url
export type Request = T.Request
export type Options = T.Options
export type Response = T.Response

local Requests = {
    Url = Url,
    Request = Request,
    Response = Response,
}

local function makeRequester(method: string): (url: string | Url, options: Options?) -> Response
    return function(url, options)
        return Request.new(url, method, options):perform()
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
