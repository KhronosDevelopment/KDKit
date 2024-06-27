--!strict
--[[
    Network ownership, made easy.
--]]
local Utils = require(script.Parent:WaitForChild("Utils"))

type NetworkOwner = (Player | "auto")?
type AssemblyImpl = {
    __index: AssemblyImpl,
    new: (BasePart?, NetworkOwner) -> Assembly,
    getOwningPlayer: (Assembly) -> Player?,
    clean: (Assembly) -> (),
    setNetworkOwner: (Assembly, NetworkOwner) -> (),
    setInstance: (Assembly, BasePart?) -> (),
    flush: (Assembly, boolean?) -> (),
    autoFlush: { [Assembly]: boolean },
}
export type Assembly = typeof(setmetatable(
    {} :: { instance: BasePart?, networkOwner: NetworkOwner, cleaned: boolean },
    {} :: AssemblyImpl
))

local Assembly: AssemblyImpl = {
    autoFlush = {},
} :: AssemblyImpl
Assembly.__index = Assembly

function Assembly.new(instance, networkOwner)
    local self = setmetatable({
        instance = instance,
        networkOwner = networkOwner,
        cleaned = false,
    }, Assembly) :: Assembly

    self:flush(true)
    Assembly.autoFlush[self] = networkOwner ~= "auto"

    return self
end

function Assembly:getOwningPlayer()
    -- returns `nil` if the server owns the assembly or if the ownership is AUTO
    -- otherwise, returns self.networkOwner
    if self.networkOwner == nil or self.networkOwner == "auto" then
        return nil
    else
        return self.networkOwner
    end
end

function Assembly:clean()
    Assembly.autoFlush[self] = nil
    self.cleaned = true
end

function Assembly:setNetworkOwner(networkOwner: NetworkOwner)
    self.networkOwner = networkOwner
    self:flush()

    if not self.cleaned then -- theoretically unnecessary, you should not be invoking this function after cleaning!
        Assembly.autoFlush[self] = networkOwner ~= "auto"
    end
end

function Assembly:setInstance(instance)
    self.instance = instance
    self:flush()
end

function Assembly:flush(suppressWarnings)
    Utils.try(function()
        if not self.instance or self.instance.Anchored then
            return
        end

        if self.networkOwner == "auto" then
            self.instance:SetNetworkOwnershipAuto()
        else
            self.instance:SetNetworkOwner(self.networkOwner)
        end
    end):catch(function(e)
        if not suppressWarnings then
            warn(e)
        end
    end)
end

task.defer(function()
    while true do
        local startedAt = os.clock()
        for assembly, auto in Assembly.autoFlush do
            if auto then
                assembly:flush(true)
                task.wait()
            end
        end

        task.wait(15 - (os.clock() - startedAt))
    end
end)

return Assembly
