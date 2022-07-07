local Class = require(script.Parent.Parent.Parent:WaitForChild("Class"))
local Transition = Class.new("KDKit.GUI.App.Transition")

function Transition:__init(
    app: "KDKit.GUI.App",
    source: string,
    from: "KDKit.GUI.App.Page"?,
    to: "KDKit.GUI.App.Page"?,
    isForwards: boolean,
    data: any,
    parent: "KDKit.GUI.App.Transition"?
)
    self.app = app
    self.source = source
    self.from = from
    self.to = to
    self.direction = if isForwards then "forward" else "backward"
    self.forward = self.direction == "forward"
    self.forwards = self.forward
    self.backward = self.direction == "backward"
    self.backwards = self.backward
    self.data = data
    self.parent = parent

    self.initial = self.source == "INITIAL_SETUP"
    self.builtin = not not (self.app and table.find(self.app.__class.BUILTIN_SOURCES, self.source))

    self.constructedAt = os.clock()
end

function Transition:isFrom(pageReference: string | "KDKit.GUI.App.Page"): boolean
    return (pageReference == self.from) or not not (self.from and self.from.name == pageReference)
end

function Transition:isTo(pageReference: string | "KDKit.GUI.App.Page"): boolean
    return (pageReference == self.to) or not not (self.to and self.to.name == pageReference)
end

function Transition:summary(): { [string]: any }
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
