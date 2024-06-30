--!strict

local HttpService = game:GetService("HttpService")

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local Request = require(script.Parent:WaitForChild("Request"))

type ResponseImpl = {
    __index: ResponseImpl,
    new: (Request.Request, number, string?, { [string]: string }?, string?) -> Response,
    json: (Response) -> any,
    raiseForStatus: (Response) -> (),
}
export type Response = typeof(setmetatable(
    {} :: {
        request: Request.Request,
        succeeded: boolean,
        statusCode: number,
        statusMessage: string,
        status: string,
        headers: { [string]: string },
        body: string,
    },
    {} :: ResponseImpl
))

local Response: ResponseImpl = {} :: ResponseImpl

function Response.new(request: Request.Request, statusCode, statusMessage, headers, body)
    local self = setmetatable({
        request = request,
        succeeded = 200 <= statusCode and statusCode < 300,
        statusCode = statusCode,
        statusMessage = statusMessage or "",
        status = Utils.strip(("%d %s"):format(statusCode, statusMessage or "")),
        headers = headers or {},
        body = body or "",
    }, Response) :: Response

    return self
end

function Response:json()
    return HttpService:JSONDecode(self.body)
end

function Response:raiseForStatus()
    if not self.succeeded then
        error(
            ("HTTP %s request to %s returned a non-2xx status: %s"):format(
                self.request.method,
                self.request.url.path,
                self.status
            )
        )
    end
end

return Response
