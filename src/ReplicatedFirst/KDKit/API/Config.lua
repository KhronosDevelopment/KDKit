--[[
    Configures API endpoints.

	Valid options are as follows:
]]

local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Preload = require(script.Parent.Parent:WaitForChild("Preload"))
local Tickrate = require(script.Parent.Parent:WaitForChild("Tickrate"))
local RateLimit = require(script.Parent.Parent:WaitForChild("RateLimit"))
local JobId = require(script.Parent.Parent:WaitForChild("JobId"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))

-- only allow 450 requests/minute (true limit is 500, but I want to leave some wiggle room)
local GLOBAL_HTTP_RATE_LIMIT = RateLimit.new(450, 60)

local Config = Class.new("KDKit.API.Config")
Config.static.folder = game:GetService("ServerStorage"):WaitForChild("KDKit.Configuration"):WaitForChild("API")
Config.static.list = {} -- will be populated with children in the above folder (see bottom of this file)
Config.static.LOG_LEVEL = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}
Config.static.URL_PATTERN = "https?://[a-zA-Z0-9][a-zA-Z0-9./]*/"

function Config:__init(instance)
    self.instance = instance
    self.settings = require(instance)
    self.logLevel = self.settings.logLevel and Config.LOG_LEVEL[self.settings.logLevel:upper()]
    if not self.logLevel then
        if game:GetService("RunService"):IsStudio() then
            self.logLevel = Config.LOG_LEVEL.DEBUG
        else
            self.logLevel = Config.LOG_LEVEL.ERROR
        end
    end

    self.name = self.instance.Name
    self.url = self.settings.url
    if self.settings.rateLimit and self.settings.rateLimit.limit then
        self.rateLimit = RateLimit.new(self.settings.rateLimit.limit, self.settings.rateLimit.period or 60)
    end

    if not self.url or type(self.url) ~= "string" or self.url:match(Config.URL_PATTERN) ~= self.url then
        error(
            ('`%s` API.Config has an invalid `url`. It must be a string matching the pattern "%s" but instead you used `%s`'):format(
                self.name,
                Config.URL_PATTERN,
                Utils:repr(self.url)
            )
        )
    end
end

function Config:useRateLimit()
    local errorWhenExceeded = self.settings.rateLimit and self.settings.rateLimit.errorWhenExceeded

    if errorWhenExceeded then
        if self.rateLimit then
            self.rateLimit:use()
        end
        GLOBAL_HTTP_RATE_LIMIT:use()
    else
        if self.rateLimit then
            self.rateLimit:useWhenReady()
        end
        GLOBAL_HTTP_RATE_LIMIT:useWhenReady()
    end

    return true
end

function Config:modifyHeadersBeforeRequest(headers, requestDetails)
    -- server headers
    if not requestDetails.flags.serverless then
        if self.settings.addServerHeaders then
            self.settings:addServerHeaders(headers, requestDetails)
        elseif not self.settings.noServerHeaders then
            self:defaultAddServerHeaders(headers, requestDetails)
            if self.settings.addExtraServerHeaders then
                self.settings:addExtraServerHeaders(headers, requestDetails)
            end
        end
    end

    -- player headers
    if requestDetails.player then
        if self.settings.addPlayerHeaders then
            self.settings:addPlayerHeaders(headers, requestDetails)
        elseif not self.settings.noPlayerHeaders then
            self:defaultAddPlayerHeaders(headers, requestDetails)
            if self.settings.addExtraPlayerHeaders then
                self.settings:addExtraPlayerHeaders(headers, requestDetails)
            end
        end
    end

    -- authentication headers
    if not requestDetails.flags.unauthenticated then
        if self.settings.addAuthenticationHeaders then
            self.settings:addAuthenticationHeaders(headers, requestDetails)
        elseif not self.settings.noAuthenticationHeaders then
            self:defaultAddAuthenticationHeaders(headers, requestDetails)
            if self.settings.addExtraAuthenticationHeaders then
                self.settings:addExtraAuthenticationHeaders(headers, requestDetails)
            end
        end
    end
end

function Config:defaultAddServerHeaders(headers, requestDetails)
    headers["X-Roblox-Game-Id"] = ("%d"):format(game.GameId)
    headers["X-Roblox-Place-Id"] = ("%d"):format(game.PlaceId)
    headers["X-Roblox-Place-Version"] = ("%d"):format(game.PlaceVersion)
    headers["X-Roblox-Job-Id"] = JobId
    headers["X-Roblox-Game-Code"] = workspace:GetAttribute("game_code") -- if attribute not set, this is a no-op

    local tickrate, minTickrate = Tickrate()
    headers["X-Roblox-Server-Tickrate"] = ("%.6f"):format(tickrate)
    headers["X-Roblox-Server-Min-Tickrate"] = ("%.6f"):format(minTickrate)
end

function Config:defaultAddPlayerHeaders(headers, requestDetails)
    headers["X-Roblox-User-Id"] = ("%d"):format(requestDetails.player.UserId)
    headers["X-Roblox-User-Name"] = requestDetails.player.Name
    headers["X-Roblox-User-Display-Name"] = requestDetails.player.DisplayName
end

function Config:defaultAddAuthenticationHeaders(headers, requestDetails)
    headers["X-Roblox-Token"] = self.settings:getCurrentAuthenticationToken(requestDetails)
end

-- initialize all of the provided configs
Preload:ensureChildren(Config.folder)
for _, instance in Config.folder:GetChildren() do
    local config = Config.new(instance)

    if Config.list[config.name] then
        error(
            ("You cannot have two API.Configs with the same name. You have two or more named `%s`."):format(config.name)
        )
    end
    Config.list[config.name] = config
end

return Config
