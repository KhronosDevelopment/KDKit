--!strict

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

type UrlImpl = {
    __index: UrlImpl,
    STANDARD_LEGAL_URL_CHARACTERS: { [string]: boolean },
    encode: (string) -> string,
    decode: (string) -> string,
    extractUrlParams: (string) -> (string, { [string]: string }),
    new: (string, { [string]: string }?) -> Url,
    render: (Url) -> string,
    withExtraParams: (Url, { [string]: string }) -> Url,
}
export type Url = typeof(setmetatable(
    {} :: {
        path: string,
        params: { [string]: string },
    },
    {} :: UrlImpl
))

local Url: UrlImpl = {} :: UrlImpl
Url.__index = Url
Url.STANDARD_LEGAL_URL_CHARACTERS = Utils.mapf(function(v, k)
    return v, true
end, Utils.characters(":-_.!~*'()@=$,;"))

function Url.encode(str)
    return str:gsub("([^a-zA-Z0-9])", function(v)
        if Url.STANDARD_LEGAL_URL_CHARACTERS[v] then
            return v
        end
        if v == " " then
            return "+"
        end
        return ("%%%02X"):format(v:byte())
    end)
end

function Url.decode(str)
    return str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16) or 0)
    end):gsub("+", " ")
end

function Url.extractUrlParams(url)
    local path, query = url:match("([^?]+)%??(.*)")

    if not path or path:len() == 0 then
        path = ""
    end
    assert(path)

    if not query or query:len() == 0 then
        query = ""
    end
    assert(query)

    local params = {}
    for key, value in query:gmatch("([^&=?]+)=([^&=?]+)") do
        assert(value)
        params[Url.decode(key)] = Url.decode(value)
    end

    return path, params
end

function Url.new(url, extraParams)
    local path, params = Url.extractUrlParams(url)
    if extraParams then
        Utils.imerge(params, extraParams)
    end

    local self = setmetatable({
        path = path,
        params = params,
    }, Url) :: Url

    return self
end

function Url:render()
    if next(self.params) then
        return self.path
            .. "?"
            .. table.concat(
                Utils.mapf(function(v, k, index)
                    return index, Url.encode(k) .. "=" .. Url.encode(v)
                end, self.params) :: { string },
                "&"
            )
    end

    return self.path
end

function Url:withExtraParams(params)
    return Url.new(self.path, Utils.merge(self.params, params))
end

return Url
