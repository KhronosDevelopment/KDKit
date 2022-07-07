local KDKitInstance = game:GetService("ReplicatedFirst"):WaitForChild("KDKit")
local TimeBasedPassword = require(KDKitInstance:WaitForChild("TimeBasedPassword"))

local rootAPIConfiguration = {
    url = "https://api.khronosdevelopment.com/",
}

local tbp = TimeBasedPassword.new(script:GetAttribute("API_SECRET"))
function rootAPIConfiguration:getCurrentAuthenticationToken(requestDetails)
    return tbp:getCurrentPassword()
end

return rootAPIConfiguration
