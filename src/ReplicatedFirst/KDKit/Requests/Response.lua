--!strict

local HttpService = game:GetService("HttpService")

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local Request = require(script.Parent:WaitForChild("Request"))

type ResponseImpl = {
    __index: ResponseImpl,
    new: (Request.Request, Request.HttpResponseData) -> Response,
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

function Response.new(request, data)
    local self = setmetatable({
        request = request,
        succeeded = data.Success,
        statusCode = data.StatusCode,
        statusMessage = data.StatusMessage or "",
        status = Utils.strip(("%d %s"):format(data.StatusCode, data.StatusMessage or "")),
        headers = data.Headers or {},
        body = data.Body or "",
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
