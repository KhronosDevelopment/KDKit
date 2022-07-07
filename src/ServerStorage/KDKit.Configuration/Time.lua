local KDKitInstance = game:GetService("ReplicatedFirst"):WaitForChild("KDKit")
local LazyRequire = require(KDKitInstance:WaitForChild("LazyRequire"))
local API = LazyRequire(KDKitInstance:WaitForChild("API"))

local TimeConfiguration = {
    remoteFetchRate = 15, -- every 15 seconds, call fetchRemoteTime
    catchupRate = 0.25, -- add or subtract 0.25 seconds per second from the time when there's a delta betwen local and remote time
}

function TimeConfiguration:fetchRemoteTime()
    LazyRequire:resolve(API)
    return (API.root / "timestamp"):ueGET().timestamp
end

return TimeConfiguration
