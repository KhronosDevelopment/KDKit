local root = require(script.Parent:WaitForChild("root"))

return {
    url = root.url .. "log/",
    rateLimit = {
        limit = 30,
        errorWhenExceeded = true,
    },
    getCurrentAuthenticationToken = root.getCurrentAuthenticationToken,
}
