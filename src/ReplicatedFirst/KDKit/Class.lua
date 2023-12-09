--[[
    Simple classing library which removes a bit of the metatable boilerplate.

    Simple example of a generic `Car` class
    ```lua
    local KDKit = require(game:GetService("ReplicatedFirst").KDKit)

    local Car = KDKit.Class.new("Car")

    function Car:__init(color, speed)
        self.color = color
        self.speed = speed
    end

    function Car:soundHorn()
        print("honk honk!")
    end

    function Car:__tostring()
        return ("A %s car that has a speed of %s mph."):format(self.color, self.speed)
    end

    local car = Car.new("red", 60)

    print(car.color) -- red
    print(car.speed) -- 60
    print(car) -- A red car that has a speed of 60 mph.

    car:soundHorn() -- honk honk!
    ```

    Additionally, the `__class` attribute will be overridden.
    ```lua
    print(car.__class == Car) -- true
    print(car.__class.__name) -- Car
    ```

    It also supports single-inheritance!
    ```lua
    local Base = Class.new("Base")
    function Base:__init()
        print("Base.__init")
        self.a1 = "base"
    end
    function Base:f1()
        print("Base.f1", self.a1)
    end

    local Derived = Class.new("Derived", Base)
    function Derived:__init()
        print("Derived.__init")
        Derived.__super.__init(self)
        self.a2 = "derived"
    end
    function Derived:f1()
        print("Derived.f1", self.a1)
        Derived.__super.f1(self)
    end
    function Derived:f2()
        print("Derived.f2", self.a2)
    end

    derived = Derived.new()
    derived:f1()
    derived:f2()
    -- output:
    -- Derived.__init
    -- Base.__init
    -- Derived.f1    base
    -- Base.f1       base
    -- Derived.f2    derived
    ```
--]]
local Utils = require(script.Parent:WaitForChild("Utils"))

local class__newindex = function(self, name, value)
    if type(value) ~= "function" then
        error(
            ("You may only add functions directly to the class. You tried to set `%s.%s` to a `%s` (which is not a function). Instead, you can store this variable in `%s.static.%s`."):format(
                self.__name,
                name,
                typeof(value),
                self.__name,
                name
            )
        )
    elseif name == "__index" then
        error("You may not override class:__index. If you need to do this, then you probably shouldn't use KDKit.Class")
    end

    rawset(self, name, value)
end

local Class = { static = { __name = "Class" } }
Class.static.__class = Class
setmetatable(Class, { __index = Class.static, __newindex = class__newindex })

function Class.static.new(name, superclass)
    superclass = superclass or Class.Object

    if typeof(name) ~= "string" then
        error("All classes must have a <string> name.")
    end

    if superclass and not Class:isProbablyAClass(superclass) then
        error(("Cannot inherit from non-class value: %s"):format(Utils:repr(superclass)))
    end

    local class = {
        static = setmetatable(
            { __name = name, __class = Class, __super = superclass },
            { __index = superclass and superclass.static }
        ),
    }

    function class.static.new(...)
        local self = setmetatable({ __class = class }, class)
        class.__init(self, ...)
        return self
    end

    function class:__index(attribute_name)
        if attribute_name == "static" then
            return nil
        end
        return rawget(class, attribute_name) or (superclass and superclass.__index(self, attribute_name))
    end

    return setmetatable(class, {
        __index = function(self, attribute_name)
            return rawget(class.static, attribute_name) or (superclass and superclass[attribute_name])
        end,
        __newindex = class__newindex,
    })
end

function Class.static:isSubClass(child: "KDKit.Class", parent: "KDKit.Class")
    return child == parent or (child.__super and self:isSubClass(child.__super, parent))
end

function Class.static:isInstance(instance: table, of: "KDKit.Class")
    return type(instance.__class) == "table" and self:isSubClass(instance.__class, of)
end

function Class.static:isProbablyAClass(t: any): boolean
    if
        typeof(t) ~= "table"
        or typeof(getmetatable(t)) ~= "table"
        or getmetatable(t).__newindex ~= class__newindex -- if a non-class passes this test, there is malicious intent!
    then
        return false
    end

    local success, isSubClass = Utils:try(self.isSubClass, self, t, self.Object):result()
    return success and isSubClass
end

Class.static.Object = Class.new("Object")
function Class.Object:__init(...)
    local n = select("#", ...)
    if n > 0 then
        error(
            ("Root class `Object` expects no arguments, but got %d. Please override `function %s:__init(...)`."):format(
                n,
                self.__class.__name
            )
        )
    end
end

return Class
