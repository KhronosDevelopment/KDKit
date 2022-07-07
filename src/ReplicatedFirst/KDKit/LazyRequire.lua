--[[
    LazyRequire is a pretty simple module which allows you to have circular requires.
    Generally, if you can avoid using LazyRequire, then you should.
    Otherwise, here's a usage example:

    ```lua
    local KDKit = require(game:GetService("ReplicatedFirst").KDKit)

    local Module = KDKit.LazyRequire(workspace.Module)
    ```

    At this point, `Module` is an empty table which has a metatable containing overridden `__index` and `__newindex` methods.
    You will not be able to access anything within `Module` until it has finished being required, which will take
    a varying amount of time depending on what code is running in `Module` and if this is the first time that
    `Module` is being required.

    ```lua
    print(Module.value) -- Error: "This module [...] has not resolved yet [...]"
    task.wait(2)
    print(Module.value) -- works fine (assuming it takes <2 seconds to resolve)

    for key, value in Module do
        -- never works, since `Module` is just an empty table with overridden metamethods
    end

    local ActualModule = LazyRequire:resolve(Module) -- waits until the module has resolved, and returns the *actual* required table.
    for key, value in ActualModule do
        -- works as expected
    end
    ```
--]]
local LazyRequire = {}

local unresolvedIndexer = function(self, key, ...)
    error(
        ("This module was LazyRequire'd and has not resolved yet, so you cannot access it's contents (specifically, you accessed the key `%s`). Consider using LazyRequire:resolve(module) to wait for it to resolve."):format(
            tostring(key)
        )
    )
end

local unresolvedMetatable = {
    __index = unresolvedIndexer,
    __newindex = unresolvedIndexer,
}

function LazyRequire:isResolved(lazyRequiredModule)
    return getmetatable(lazyRequiredModule) ~= unresolvedMetatable
end

function LazyRequire:resolve(lazyRequiredModule)
    while not self:isResolved(lazyRequiredModule) do
        task.wait()
    end

    return getmetatable(lazyRequiredModule).__index
end

return setmetatable(LazyRequire, {
    __call = function(self, moduleInstance)
        local module = {}

        task.defer(function()
            local actualModule = require(moduleInstance)
            setmetatable(module, { __index = actualModule, __newindex = actualModule })
        end)

        return setmetatable(module, unresolvedMetatable)
    end,
    __iter = function(self)
        return next, self
    end,
})
