--!strict

local Hash = {}

local sha256 = require(script:WaitForChild("sha256"))

function Hash:sha256(str: string): string
    return sha256(str)
end

return Hash
