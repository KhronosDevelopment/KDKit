--[[
    Very simply tickrate tracker (measured in hertz), which helps measure server lag.
    Higher values are better. Roblox's pipeline runs at a maximum of 60 hz.

    ```lua
    local tickrate, minTickrate = KDKit.Tickrate()
    if tickrate < 45 then
        print("Having a 5-minute average of less than 45 hz is like, really bad. I should probably make some optimizations.")
    else
        print(("The server is currently operating at %.2fhz. For it's entire runtime, the worst reported tickrate was %.2fhz."):format(tickrate, minTickrate))
    end
    ```
--]]

local AVG_TICKRATE_OVER = 300
local tickrate = 60
local minTickrate = tickrate
game:GetService("RunService").Heartbeat:Connect(function(timeStep)
    if timeStep <= 1 / 1000 then
        -- This shouldn't technically be possible, but one of my servers reported an infinite tickrate somehow.
        -- So I just want to be safe.
        return
    end
    local hz = 1 / timeStep
    tickrate = (tickrate * (AVG_TICKRATE_OVER - 1) + hz) / AVG_TICKRATE_OVER

    if workspace.DistributedGameTime < AVG_TICKRATE_OVER then
        return -- Server initialization is usually very slow. We don't want to include that time in our minTickrate calculation.
    end
    minTickrate = math.min(minTickrate, tickrate)
end)

return function()
    return tickrate, minTickrate
end
