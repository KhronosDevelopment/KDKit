-- externals 
local KDKit = require(script.Parent)

-- class
local AsyncEE = KDKit.Class("AsyncEE")
local AsyncEETracker = KDKit.Class("AsyncEETracker")

-- utils
local list = setmetatable({}, {__mode = "kv"})

function AsyncEE:__init(identifier)
    self.opens = 0
    self.closes = 0
    
    list[identifier] = self
end

function AsyncEETracker:__init(aee)
    self.aee = aee
    self:open()
end

function AsyncEETracker:open()
    if self.opened then self:close() end
    
    self.aee.opens += 1
    self.opened = self.aee.opens
end

function AsyncEETracker:check()
    return self.opened and self.aee.opens == self.opened
end

function AsyncEETracker:close()
    if not self.opened then return end
    
    self.opened = false
    self.aee.closes += 1
end
AsyncEETracker.__gc = AsyncEETracker.close

return setmetatable({
    count = function(self, prefix)
        -- AsyncEE.count() instead of :count()
        if type(self) == "string" then
            prefix = self
        end
        
        -- by default count all
        prefix = prefix or ""
        
        local c = 0
        for identifier, aee in pairs(list) do
            if identifier:sub(1, prefix:len()) == prefix then
                c += aee.opens - aee.closes
            end
        end
        
        return c
    end,
}, {
    __call = function(self, identifier)
        identifier = tostring(identifier)
        return AsyncEETracker(list[identifier] or AsyncEE(identifier))
    end
})
