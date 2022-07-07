local allowed_metamethods = {
    "__index",
    "__newindex",
    "__call",
    "__tostring",
    "__len",
    "__pairs",
    "__ipairs",
    "__gc",
    "__name",
    "__close",
    "__unm",
    "__add",
    "__sub",
    "__mul",
    "__div",
    "__idiv",
    "__mod",
    "__pow",
    "__concat",
    "__band",
    "__bor",
    "__bxor",
    "__bnot",
    "__shl",
    "__shr",
    "__eq",
    "__lt",
    "__le"
}
local allowed_metamethods_set = {}
for _, name in ipairs(allowed_metamethods) do
    allowed_metamethods_set[name] = true
end

local disallowed_metamethods = {
    "__mode",
    "__metatable",
}
local disallowed_metamethods_set = {}
for _, name in ipairs(disallowed_metamethods) do
    disallowed_metamethods_set[name] = true
end

return function(name)
    return setmetatable({ name = name }, {
        __metatable = function(...)
            error("You may not adjust the metatable of a class. Metamethods will be added automatically to instances.")
        end,
        __call = function(cls, ...)
            if type(cls.__new) == "function" then
                local self = cls:__new(...)
                if self ~= nil then
                    return self
                end
                
                -- if you return nil from __new(), then 
                -- the default behavior will be used
            end
            
            
            local mt = {}
            local self = {}
            if name then
                self.class = cls
            end
            
            for name, func in pairs(cls) do
                if type(func) ~= "function" then
                    continue
                end
                
                if name == "__new" then
                    continue
                end

                if disallowed_metamethods_set[name] then
                    error(("The `%s` metamethod is not allowed for classes."):format(name))
                end
                
                if allowed_metamethods_set[name] then
                    mt[name] = func
                else
                    self[name] = func
                end
            end
            
            setmetatable(self, mt)
            self:__init(...)
            -- it may be of interest to remove __init after initial call
            
            return self
        end
    })
end
