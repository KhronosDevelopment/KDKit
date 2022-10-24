local KDKitInstance = game:GetService("ReplicatedFirst"):WaitForChild("KDKit")
local TimeBasedPassword = require(KDKitInstance:WaitForChild("TimeBasedPassword"))

local rootAPIConfiguration = {
    url = script:GetAttribute("API_URL"), -- i.e. "https://api.yoursite.com/"
}

local tbp = TimeBasedPassword.new(script:GetAttribute("API_SECRET"))
function rootAPIConfiguration:getCurrentAuthenticationToken(requestDetails)
    return tbp:getCurrentPassword()
end

return rootAPIConfiguration
