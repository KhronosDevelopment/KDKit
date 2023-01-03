# KDKit.API

An amazingly sleek interface to `HttpService`. This module makes numerous usability improvements to any and all HTTP requests. Where do I even begin?

## Demo
```lua
local KDKit = require(game:GetService("ReplicatedFirst"):WaitForChild("KDKit"))

-- make a GET request to https://www.yoursite.com/my/endpoint/
-- (you can create custom site configurations in ServerStorage/KDKit.Configuration/API, here we are using the root config)
local success, response = (KDKit.API.root / "my" / "endpoint"):GET()
if success then
    print("yoo it worked, here is the JSON decoded response table:", response)
else
    print("uh oh something went wrong, here is the error message:", response)
end

-- make a PUT request to https://www.yoursite.com/players/ including the JSON object {"extraData": 123}
-- the `p` flag prompts us to include a Player object which will cause various player headers like X-Roblox-User-Id to be added(in accordance with your config)
-- the `e` flag will cause any errors to be raised rather than returned
local response = (KDKit.API.root / "players"):pePUT(game.Players.SomePlayer, { extraData = 123 })
print("they have", response.xp, "experience") -- or whatever your endpoint returns

-- Make a DELETE request to https://www.yoursite/game_code/data/
-- the `d` flag makes the request "deferred" which means that it is entirely asynchronous and it is impossible to retrieve the return value
-- the `p` flag prompts us to include a Player object which will attach related headers
-- the `e` flag makes the request raise errors rather than returning them (since the request is deferred, this is kind of important)
(KDKit.API.game / "data"):dpeDELETE(game.Players.SomePlayer)
```

Furthermore, a huge amount of boilerplate work is occurring behind the scenes.
1. Requests are authenticated using KDKit.TimeBasedPassword, so that you can easily verify that requests are indeed coming from official Roblox game servers.
2. Many headers are attached so that servers/players can be identified and diagnostic information can be obtained.
3. URLs are escaped properly and a trailing slash is always present.
4. All data is JSON encoded an decoded automatically in an extremely error resistant manner (see Utils.safeJSONEncode)
5. The entire service will never raise an error (rather, it returns them with extra added detail) unless you specifically request that they are raised (via the `e` flag).
6. A global and config-based rate limit is applied. Requests will yield until the rate limit opens up, rather than throwing an error.
7. The config system is extremely verbose and allows many customizations. For example, `API.root` and `API.log` have several major behavioral differences. 


The following methods are available:
* GET
* POST
* PUT
* PATCH
* DELETE

## Flags
As was shown in the demo, every request can have multiple flags specified.
Here are the definitions of each flag (which must be supplied in the order that they appear here):
* [`d`]eferred - The request will happen in a separate coroutine, and will be completely non-blocking. It is highly recommended that you also use the `e` flag in conjunction with this `d` flag, since there will otherwise be no way of knowing if the request failed.
* [`u`]nauthenticated - Authentication will be skipped. This flag is used internally within the KDKit.Time modulo, since time synchronization is a dependency of authentication. I don't think there is any reason to use this flag unless you want to avoid authentication altogether (which I wouldn't recommend).
* [`p`]layer - Requires that a `Player` object is specified in the request. This will invoke `config:addPlayerHeaders()` which by default will add the following headers:
    * `X-Roblox-User-Id`
    * `X-Roblox-User-Name`
    * `X-Roblox-User-Display-Name`
* [`e`]rroneous - Raises any errors that occur, rather than returning them.
* [`s`]erverless - Prevents the api from invoking `config:addServerHeaders()` which by default would have added the following headers:
    * `X-Roblox-Game-Id` - game.GameId
    * `X-Roblox-Place-Id` - game.PlaceId
    * `X-Roblox-Place-Version` - game.PlaceVersion
    * `X-Roblox-Job-Id` - KDKit.JobId
    * `X-Roblox-Game-Code` - workspace:GetAttribute("game_code")
    * `X-Roblox-Server-Tickrate` - see KDKit.Tickrate()
    * `X-Roblox-Server-Min-Tickrate` - see KDKit.Tickrate()