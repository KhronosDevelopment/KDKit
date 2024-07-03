--!strict

local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

local T = require(script.Parent:WaitForChild("types"))

type Url = T.Url
type UrlImpl = T.UrlImpl

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

    local _, secrets = self:segregateParams()
    if Utils.count(secrets) > 1 then
        error("A Url can only contain one secret! (Roblox Limitation)")
    end

    return self
end

function Url:segregateParams()
    local secrets: { [string]: Secret } = {}
    local params: { [string]: string } = {}

    for name, value in self.params do
        if typeof(value) == "Secret" then
            secrets[name] = value
        else
            params[name] = value
        end
    end

    return params, secrets
end

function Url:render(withoutSecrets)
    local params, secrets = self:segregateParams()

    if withoutSecrets or not next(secrets) then
        if next(params) then
            return self.path
                .. "?"
                .. table.concat(
                    Utils.mapf(function(v, k, index)
                        return index, Url.encode(k) .. "=" .. Url.encode(v)
                    end, params) :: { string },
                    "&"
                )
        end

        return self.path
    end

    if Utils.count(secrets) > 1 then
        error("A Url can only contain one secret! (Roblox Limitation)")
    end

    local key, secret = next(secrets)
    assert(key and secret)

    local publicUrl = self:render(true)
    assert(typeof(publicUrl) == "string")

    if next(params) then
        return secret:AddPrefix(publicUrl .. "&" .. Url.encode(key) .. "=")
    else
        return secret:AddPrefix(publicUrl .. "?" .. Url.encode(key) .. "=")
    end
end

function Url:withExtraParams(params)
    return Url.new(self.path, Utils.merge(self.params, params))
end

return Url
