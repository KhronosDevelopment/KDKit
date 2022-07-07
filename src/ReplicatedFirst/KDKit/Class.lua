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
```
print(car.__class == Car) -- true
print(car.__class.__name) -- Car
```

But this behavior can be disabled by simply not supplying a name to Class.new
```lua
local Car = KDKit.Class.new()

-- ... same code as above

local car = Car.new("blue", 45)
print(car.__class) -- nil
print(Car.__name) -- nil
```
--]]

local Class = {}

function Class.new(name)
    local class = {
        __name = name,
    }

    function class:__init(...)
        error(
            ("Please override the class constructor for `%s` by defining `function %s:__init(...)`"):format(
                name or "Unnamed",
                name or "Unnamed"
            )
        )
    end

    function class.new(...)
        if type(class.__new) == "function" then
            local self, skipInitializer = class:__new(...)
            if self then
                if not skipInitializer then
                    -- not using `self:__init(...)` because you are allowed to override __index
                    class.__init(self, ...)
                end
                return self
            end
        end

        local self = setmetatable({
            __class = name and class, -- only set `__class` if a name was provided
        }, class)

        -- not using `self:__init(...)` because you are allowed to override __index
        class.__init(self, ...)

        return self
    end

    class.__index = class
    return class
end

return Class
