local RunService = game:GetService("RunService")
local t = { id = 0 }

RunService.Heartbeat:Connect(function()
    t.id += 1
end)

return t
