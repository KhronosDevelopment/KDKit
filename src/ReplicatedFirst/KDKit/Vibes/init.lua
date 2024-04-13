if game:GetService("RunService"):IsServer() then
    return nil
end

local Utils = require(script.Parent:WaitForChild("Utils"))
local Remote = require(script.Parent:WaitForChild("Remote"))
local Mutex = require(script.Parent:WaitForChild("Mutex"))

local Vibes = {}

Vibes.configs = require(script:WaitForChild("VibeConfigs"))
Vibes.current = nil :: "VibeConfig"?

local EMPTY_DEFAULT_ARGS = table.freeze({ characterPosition = Vector3.new(0, 0, 0), alive = false, everAlive = false })
local lastDefaultArgs = EMPTY_DEFAULT_ARGS

function Vibes:getDefaultArgs(): { characterPosition: Vector3 }
    local character = game.Players.LocalPlayer.Character
    if not character then
        lastDefaultArgs = table.clone(lastDefaultArgs)
        lastDefaultArgs.alive = false
        return table.freeze(lastDefaultArgs)
    end

    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        lastDefaultArgs = table.clone(lastDefaultArgs)
        lastDefaultArgs.alive = false
        return table.freeze(lastDefaultArgs)
    end

    local rootPart = humanoid.RootPart
    if not rootPart then
        lastDefaultArgs = table.clone(lastDefaultArgs)
        lastDefaultArgs.alive = false
        return table.freeze(lastDefaultArgs)
    end

    lastDefaultArgs = table.freeze({ characterPosition = rootPart.Position, alive = true, everAlive = true })
    return lastDefaultArgs
end

function Vibes:determineCurrent(): ("VibeConfig"?, table?)
    local defaultArgs = self:getDefaultArgs()
    local configsAndArgs = Utils:map(function(c)
        return { c, c:getArgs(defaultArgs) }
    end, self.configs)

    local configAndArgs = Utils:max(configsAndArgs, function(configAndArgs)
        local config, args = table.unpack(configAndArgs)
        return { if config:isApplicable(args) then 1 else 0, config:getPriority(args) }
    end)

    if configAndArgs == nil then
        return nil, nil
    end

    return table.unpack(configAndArgs)
end

function Vibes:mustUpdate()
    local old = self.current
    local new, args = self:determineCurrent()

    if old == new then
        return
    end

    if old then
        old:beforeDeactivated(new)
    end

    if new then
        new:beforeActivated(args, old)
    end

    if old then
        old:animateOut(new)
    end
    if new then
        new:animateIn(args, old)
    end
    self.current = new

    if old then
        old:afterDeactivated(new)
    end

    if new then
        new:afterActivated(args, old)
    end
end

function Vibes:update(): boolean
    return Utils:try(Vibes.mustUpdate, Vibes)
        :catch(function(traceback: string)
            local state = Utils:repr({
                current = if self.current then self.current.name else nil,
                configs = Utils:keys(self.configs),
            })

            local successfullyBuiltArgs, argsOrTraceback = Utils:try(function()
                local args = {}
                for name, config in Vibes.configs do
                    args[name] = config:getArgs(lastDefaultArgs)
                end

                return Utils:repr(args)
            end):result()

            local args = (if successfullyBuiltArgs then "Error building args: " else "") .. argsOrTraceback

            Remote.logClientError("KDKit.Vibes.update", state, args, traceback)
        end)
        :result()
end

task.defer(function()
    local backoff = 1
    while true do
        if not Vibes:update() then
            task.wait(0.25 * backoff)
            backoff *= 2
        else
            backoff = 1
        end

        task.wait()
    end
end)

return Vibes
