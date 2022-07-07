-- externals 
local KDKit = require(script.Parent)

-- class
local Decimal = KDKit.Class("Decimal")

-- utils
local floor = math.floor

function Decimal:__init(...)
    local argc = select('#', ...)
    
    if argc == 0 then
        return self:__init(true, "0", "0")
    elseif argc == 1 then
        local number = ...

        if type(number) == "number" then
            number = ("%.6f"):format(number)
        end
        
        if type(number) == "table" and type(number._positive) == "boolean" and number._integral and number._decimal then
            return self:__init(number._positive, number._integral, number._decimal)
        elseif type(number) == "string" then
            -- "[+-]123.123" and "[+-]123" are allowed
            number = number:gsub("_", "")
            if number:match("[+-]?%d+%.%d+") ~= number and number:match("[+-]?%d+") ~= number then
                warn("Invalid argument for Decimal:", number)
                return self:__init(true, "0", "0")
            end

            local positive = number:sub(1,1)
            if positive == "+" then
                number = number:sub(2)
                positive = true
            elseif positive == "-" then
                number = number:sub(2)
                positive = false
            else
                positive = true
            end
            
            local integral, decimal = number, "0"
            local dot = number:find("%.")
            if dot ~= nil then
                integral = number:sub(1, dot - 1)
                decimal = number:sub(dot + 1)
            end
            
            return self:__init(positive, integral, decimal)
        else
            warn("Invalid argument to Decimal:", number)
            return self:__init(true, "0", "0")
        end
    elseif argc == 2 then
        local integral, decimal = ...
        integral = integral or 0
        decimal = decimal or 0
        local positive = true
        
        if type(integral) == "string" then
            integral = integral:gsub("_", "")
            if integral:match("[+-]?%d+") ~= integral then
                warn("Invalid integral for Decimal:", integral)
                integral = "0"
            end
            
            -- grab (optional) sign from integral
            positive = integral:sub(1,1)
            if positive == "+" then
                integral = integral:sub(2)
                positive = true
            elseif positive == "-" then
                integral = integral:sub(2)
                positive = false
            else
                positive = true
            end
        elseif type(integral) == "number" then
            if integral < 0 then
                positive = false
                integral = -integral
            else
                positive = true
            end
            
            integral = ("%d"):format(integral)
        else
            warn("Invalid integral for Decimal:", integral)
            
            integral = "0"
        end
        

        if type(decimal) == "string" then
            decimal = decimal:gsub("_", "")
            if decimal:match("%d+") ~= decimal then
                warn("Invalid decimal for Decimal:", decimal)
                decimal = "0"
            end
        else
            warn("Invalid decimal for Decimal:", decimal)
            decimal = "0"
        end
        
        return self:__init(positive, integral, decimal)
    elseif argc == 3 then
        local positive, integral, decimal = ...
        
        if type(positive) == "boolean" then
            -- pass
        elseif positive == "+" then
            positive = true
        elseif positive == "-" then
            positive = false
        else
            warn("Invalid sign value for Decimal:", positive)
            positive = true
        end

        if type(integral) == "number" then
            integral = ("%d"):format(integral)
        end
        if type(decimal) == "number" then
            decimal = ("%d"):format(decimal)
        end

        if type(integral) ~= "string" or integral:match("[%d_]+") ~= integral then
            warn("Invalid integral for Decimal:", integral)
            integral = "0"
        end
        if type(decimal) ~= "string" or decimal:match("[%d_]+") ~= decimal then
            warn("Invalid integral for Decimal:", decimal)
            decimal = "0"
        end
        
        integral = integral:gsub("_", "")
        decimal = decimal:gsub("_", "")
        
        self._positive = positive
        self._integral = integral:gsub("^0+", "") -- remove preceding zeros
        self._decimal = decimal:gsub("0+$", "") -- remove trailing zeros
        
        if self._integral == "" then self._integral = "0" end
        if self._decimal == "" then self._decimal = "0" end
        if self._integral == "0" and self._decimal == "0" then
            self._positive = true
        end
    end
end

function Decimal:round(digits)
    digits = digits or 0
    
    if digits >= self._decimal:len() then
        return Decimal(self)
    end
    
    local deciding_digit = self._decimal:sub(digits + 1, digits + 1)
    local truncated_decimal = Decimal(
        self._positive,
        self._integral,
        digits == 0 and "0" or self._decimal:sub(1, digits)
    )
    
    if deciding_digit < "5" then
        return truncated_decimal
    else
        local to_add = digits == 0 and "1" or ("0." .. ("0"):rep(digits - 1) .. "1")
        return truncated_decimal + to_add
    end
end

function Decimal:__unm()
    return Decimal(not self._positive, self._integral, self._decimal)
end

function Decimal:__lt(other)
    other = Decimal(other)
    
    if self._positive ~= other._positive then
        return other._positive
    end
    
    if not self._positive then
        
        self._positive = true
        other._positive = true
        
        local result = self < other
        
        self._positive = false
        other._positive = false
        
        return not result
    else
        local a, b = self._integral, other._integral
        local alen, blen = a:len(), b:len()
        
        -- compare integral magnitude
        if alen ~= blen then
            return alen < blen
        end
        
        -- compare integral parts
        if a ~= b then
            return a < b -- equal length numeric strings can be alphabetically compared w/o issues
        end
        
        -- integral parts are the same, check decimal
        a, b = self._decimal, other._decimal
        alen, blen = a:len(), b:len()
        
        -- right pad with zeros
        if alen < blen then
            a ..= ("0"):rep(blen - alen)
        elseif blen < alen then
            b ..= ("0"):rep(alen - blen)
        end
        
        return a < b
    end
end

function Decimal:__eq(other)
    -- copy not necessary because __eq will not be invoked unless
    -- `other` is also a Decimal that has the same __eq function
    --other = Decimal(other)
    return self._positive == other._positive and self._integral == other._integral and self._decimal == other._decimal
end

function Decimal:__le(other)
    other = Decimal(other)
    return (self == other) or (self < other)
end

function Decimal:__add(other)
    other = Decimal(other)
    
    if self._positive and not other._positive then -- (+a) + (-b) = (+a) - (+b)
        other._positive = true
        return self - other
    elseif not self._positive and other._positive then -- (-a) + (+b) = (-a) - (-b)
        other._positive = false
        return self - other
    end

    -- it is now known that the sign will be unaffected
    local carry, r = 0, 0

    -- setup addition of decimals
    local a, b = self._decimal, other._decimal
    local alen, blen = a:len(), b:len()

    -- right pad with zeros
    if alen < blen then
        a ..= ("0"):rep(blen - alen)
        alen = blen
    elseif blen < alen then
        b ..= ("0"):rep(alen - blen)
        blen = alen
    end

    -- perform addition
    local decimalOutput = table.create(alen, 0)
    for digitIndex = alen, 1, -1 do
        r = a:byte(digitIndex) + b:byte(digitIndex) + carry - 96
        carry = floor(r / 10) -- +1 if r >= 10
        r %= 10
        decimalOutput[digitIndex] = r
    end
    
    -- setup addition of integrals
    a, b = self._integral, other._integral
    alen, blen = a:len(), b:len()

    -- left pad with zeros
    if alen < blen then
        a = ("0"):rep(blen - alen) .. a
        alen = blen
    elseif blen < alen then
        b = ("0"):rep(alen - blen) .. b
        blen = alen
    end

    -- perform addition
    local integralOutput = table.create(alen, 0)
    for digitIndex = alen, 1, -1 do
        r = a:byte(digitIndex) + b:byte(digitIndex) + carry - 96
        carry = floor(r / 10) -- +1 if r >= 10
        r %= 10
        integralOutput[digitIndex] = r
    end
    
    if carry > 0 then
        integralOutput[1] = "1" .. integralOutput[1]
    end

    other._integral = table.concat(integralOutput):gsub("^0+", "")
    other._decimal = table.concat(decimalOutput):gsub("0+$", "")

    if other._integral == "" then other._integral = "0" end
    if other._decimal == "" then other._decimal = "0" end
    if other._integral == "0" and other._decimal == "0" then
        other._positive = true
    end
    -- the sign will not have changed

    return other
end

function Decimal:__sub(other)
    other = Decimal(other)
    
    if self._positive and not other._positive then -- (+a) - (-b) = (+a) + (+b)
        other._positive = true
        return self + other
    elseif not self._positive and other._positive then -- (-a) - (+b) = (-a) + (-b)
        other._positive = false
        return self + other
    end
    
    -- if small number minus big number then do -(other - self)
    -- TODO: this is broken, terenary doesn't work when values are falsy
    if (self._positive and other > self) or (not self._positive and self > other) then
        local result = other - self
        result.positive = not result.positive
        return result
    end
    
    -- it is now known that the sign will be unaffected
    local carry, r = 0, 0
    
    -- setup subtraction of decimals
    local a, b = self._decimal, other._decimal
    local alen, blen = a:len(), b:len()
    
    -- right pad with zeros
    if alen < blen then
        a ..= ("0"):rep(blen - alen)
        alen = blen
    elseif blen < alen then
        b ..= ("0"):rep(alen - blen)
        blen = alen
    end
    
    -- perform subtraction
    local decimalOutput = table.create(alen, 0)
    for digitIndex = alen, 1, -1 do
        r = a:byte(digitIndex) - b:byte(digitIndex) + carry
        carry = floor(r / 10) -- -1 if r < 0
        r %= 10
        decimalOutput[digitIndex] = r
    end

    -- setup subtraction of integrals
    a, b = self._integral, other._integral
    alen, blen = a:len(), b:len()

    -- left pad with zeros
    if alen < blen then
        a = ("0"):rep(blen - alen) .. a
        alen = blen
    elseif blen < alen then
        b = ("0"):rep(alen - blen) .. b
        blen = alen
    end
    
    -- perform subtraction
    local integralOutput = table.create(alen, 0)
    for digitIndex = alen, 1, -1 do
        r = a:byte(digitIndex) - b:byte(digitIndex) + carry
        carry = floor(r / 10) -- -1 if r < 0
        r %= 10
        integralOutput[digitIndex] = r
    end
    
    -- carry WILL be 0, becuase we already made sure abs(self) >= abs(other)
    
    other._integral = table.concat(integralOutput):gsub("^0+", "")
    other._decimal = table.concat(decimalOutput):gsub("0+$", "")
    -- the sign will not have changed

    if other._integral == "" then other._integral = "0" end
    if other._decimal == "" then other._decimal = "0" end
    if other._integral == "0" and other._decimal == "0" then
        other._positive = true
    end
    
    return other
end

function Decimal:__tostring()
    local s = self._integral
    
    if not self._positive then
        s = "-" .. s
    end
    
    if self._decimal ~= "0" then
        s ..= "." .. self._decimal
    end
    
    return s
end

function Decimal:__tonumber()
    return tonumber(tostring(self))
end
Decimal.asNumber = Decimal.__tonumber
Decimal.asFloat = Decimal.__tonumber
Decimal.toNumber = Decimal.__tonumber
Decimal.asFloaat = Decimal.__tonumber
Decimal.float = Decimal.__tonumber
Decimal.number = Decimal.__tonumber

function Decimal:details()
    return {
        positive = self._positive,
        integral = self._integral,
        decimal = self._decimal
    }
end

return Decimal
