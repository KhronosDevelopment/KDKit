local root = require(script.Parent:WaitForChild("root"))

return {
    url = root.url .. "log/",
    rateLimit = {
        limit = 5,
        period = 10,
        errorWhenExceeded = true,
    },
    getCurrentAuthenticationToken = root.getCurrentAuthenticationToken,
}
