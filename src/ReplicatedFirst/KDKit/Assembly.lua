--[[
    Network ownership, made easy.
--]]
local Class = require(script.Parent:WaitForChild("Class"))
local Utils = require(script.Parent:WaitForChild("Utils"))
local Assembly = Class.new("Assembly")

type AUTO = "auto"
Assembly.static.AUTO = "auto"
Assembly.static.autoFlush = {} :: { ["Class.Assembly"]: boolean }

function Assembly:__init(instance: BasePart?, networkOwner: (Player | AUTO)?)
    self.instance = instance
    self.networkOwner = networkOwner
    self.cleaned = false

    self:flush(true)

    Assembly.autoFlush[self] = networkOwner ~= Assembly.AUTO
end

function Assembly:getOwningPlayer(): Player?
    -- returns `nil` if the server owns the assembly or if the ownership is AUTO
    -- otherwise, returns self.networkOwner
    if self.networkOwner == nil or self.networkOwner == Assembly.AUTO then
        return nil
    else
        return self.networkOwner
    end
end

function Assembly:clean()
    Assembly.autoFlush[self] = nil
    self.cleaned = true
end

function Assembly:setNetworkOwner(networkOwner: (Player | AUTO)?)
    self.networkOwner = networkOwner
    self:flush()

    if not self.cleaned then -- theoretically unnecessary, you should not be invoking this function after cleaning!
        Assembly.autoFlush[self] = networkOwner ~= Assembly.AUTO
    end
end

function Assembly:setInstance(instance: BasePart?)
    self.instance = instance
    self:flush()
end

function Assembly:flush(suppressWarnings: boolean?)
    Utils:try(function()
        if not self.instance or self.instance.Anchored then
            return
        end

        if self.networkOwner == Assembly.AUTO then
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
