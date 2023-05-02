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

    self:flush(true)

    Assembly.autoFlush[self] = true
end

function Assembly:clean()
    Assembly.autoFlush[self] = nil
end

function Assembly:setNetworkOwner(networkOwner: (Player | AUTO)?)
    self.networkOwner = networkOwner
    self:flush()
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
        for toilet, _ in Assembly.autoFlush do
            toilet:flush(true) -- tee hee
            task.wait()
        end

        task.wait(15 - (os.clock() - startedAt))
    end
end)

return Assembly
