--!strict

local T = require(script.Parent:WaitForChild("types"))

type TransitionImpl = T.TransitionImpl
export type Transition = T.Transition

local Transition: TransitionImpl = {} :: TransitionImpl
Transition.__index = Transition

function Transition.new(app, source, from, to, isForwards, data, parent)
    local self = setmetatable({
        app = app,
        source = source,
        from = from,
        to = to,
        direction = if isForwards then "forward" else "backward",
        data = data,
        parent = parent,
        constructedAt = os.clock(),
        -- derivative properties:
        forward = not not isForwards,
        forwards = not not isForwards,
        backward = not isForwards,
        backwards = not isForwards,
        initial = source == "INITIAL_SETUP",
        builtin = not not table.find(T.BUILTIN_SOURCES, source),
    }, Transition) :: Transition

    return self
end

function Transition:isFrom(pageReference)
    return (pageReference == self.from) or not not (self.from and self.from.name == pageReference)
end

function Transition:isTo(pageReference)
    return (pageReference == self.to) or not not (self.to and self.to.name == pageReference)
end

function Transition:summary()
    return {
        app = self.app and self.app.instance:GetFullName(),
        source = self.source,
        from = self.from and self.from.name,
        to = self.to and self.to.name,
        direction = self.direction,
        data = self.data,
        clock = self.constructedAt,
    }
end

return Transition
