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

local STARTED_RECORDING_AT = os.clock()
local AVG_TICKRATE_OVER = 300
local KEEP_HISTORY_DURATION = AVG_TICKRATE_OVER + 2
local recentTicksPerSecond = table.create(KEEP_HISTORY_DURATION)
for i = KEEP_HISTORY_DURATION - 1, 0, -1 do
    table.insert(recentTicksPerSecond, { math.floor(STARTED_RECORDING_AT) - i, 60 })
end

local function cycle()
    while (os.clock() - recentTicksPerSecond[1][1]) > KEEP_HISTORY_DURATION do
        table.remove(recentTicksPerSecond, 1)
        table.insert(recentTicksPerSecond, { recentTicksPerSecond[KEEP_HISTORY_DURATION - 1][1] + 1, 0 })
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    debug.profilebegin("KDKit.Tickrate (record)")

    -- timeStep isn't as accurate as I would like it to be, so keeping a tick history instead
    recentTicksPerSecond[KEEP_HISTORY_DURATION][2] += 1
    cycle()

    print("ticked", math.floor(os.clock()))

    debug.profileend()
end)

local minTickrate = 60
return function()
    debug.profilebegin("KDKit.Tickrate (compute)")

    cycle()

    -- Sum up the number of ticks from the previous second groups. Exclude the most recent second (which is not full yet).
    local tickCount = 0
    for i = 1, AVG_TICKRATE_OVER do
        tickCount += recentTicksPerSecond[KEEP_HISTORY_DURATION - i][2]
    end

    local tickrate = tickCount / AVG_TICKRATE_OVER

    if os.clock() - STARTED_RECORDING_AT >= AVG_TICKRATE_OVER then
        minTickrate = math.min(minTickrate, tickrate)
    end

    debug.profileend()
    return tickrate, minTickrate
end
