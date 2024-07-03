--!strict

export type UrlImpl = {
    __index: UrlImpl,
    STANDARD_LEGAL_URL_CHARACTERS: { [string]: boolean },
    encode: (string) -> string,
    decode: (string) -> string,
    extractUrlParams: (string) -> (string, { [string]: string }),
    new: (string, { [string]: string | Secret }?) -> Url,
    segregateParams: (Url) -> ({ [string]: string }, { [string]: Secret }),
    render: (Url, boolean?) -> string | Secret,
    withExtraParams: (Url, { [string]: string | Secret }) -> Url,
}
export type Url = typeof(setmetatable(
    {} :: {
        path: string,
        params: { [string]: string | Secret },
    },
    {} :: UrlImpl
))

export type Options = {
    headers: { [string]: string | Secret }?,
    params: { [string]: string | Secret }?,
    body: string?,
    json: any,
    compress: boolean?,
    timeout: number?,
}

export type HttpRequestOptions = {
    Url: string | Secret,
    Method: string?,
    Headers: { [string]: string | Secret }?,
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

export type RequestImpl = {
    __index: RequestImpl,
    new: (string | Url, string?, Options?) -> Request,
    render: (Request) -> HttpRequestOptions,
    perform: (Request) -> Response,
}
export type Request = typeof(setmetatable(
    {} :: {
        url: Url,
        method: string,
        options: Options?,
    },
    {} :: RequestImpl
))

export type ResponseImpl = {
    __index: ResponseImpl,
    new: (Request, HttpResponseData) -> Response,
    json: (Response) -> any,
    raiseForStatus: (Response) -> (),
}
export type Response = typeof(setmetatable(
    {} :: {
        request: Request,
        succeeded: boolean,
        statusCode: number,
        statusMessage: string,
        status: string,
        headers: { [string]: string },
        body: string,
    },
    {} :: ResponseImpl
))

return {}
