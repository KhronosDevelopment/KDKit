local Hash = {}

local sha256 = require(script:WaitForChild("sha256"))
function Hash:sha256(str)
    return sha256(str)
end

return Hash
