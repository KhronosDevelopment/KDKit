local root = require(script.Parent:WaitForChild("root"))

if workspace:GetAttribute("game_code") then
    return {
        url = root.url .. workspace:GetAttribute("game_code"):lower() .. "/",
        getCurrentAuthenticationToken = root.getCurrentAuthenticationToken,
    }
else
    return root
end
