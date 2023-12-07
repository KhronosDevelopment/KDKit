local Utils = require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("Utils"))
local Region = {}

function Region:contains(region: Instance, point: Vector3)
    for _, part in region:GetChildren() do
        if Utils:partTouchesPoint(part, point) then
            return true
        end
    end

    return false
end

return Region
