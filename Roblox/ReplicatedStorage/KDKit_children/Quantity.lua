-- externals 
local KDKit = require(script.Parent)

-- class
local Quantity = KDKit.Class("Quantity")

function Quantity:__init(data, validator)
    rawset(self, "_data", {})
    
    if type(validator) == "table" then
        rawset(self, "validator", function(name) return not not validator[name] end)
    elseif type(validator) == "function" then
        rawset(self, "validator", validator)
    else
        rawset(self, "validator", function(name) return true end)
    end
    
    if type(data) ~= "table" then
        data = {}
    end
    
    for name, qty in pairs(data) do
        self[name] = tonumber(qty) or 0
    end
end

function Quantity:__index(name)
    return rawget(self, name) or rawget(self._data, name) or 0
end

function Quantity:__newindex(name, value)
    if not self.validator(name) then
        value = 0
    end
    
    if value <= 0 then
        self.__data[name] = nil
    else
        self._data[name] = value
    end
end

return Quantity
