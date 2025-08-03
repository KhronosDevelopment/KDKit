--!strict

local Utils = require(script.Parent:WaitForChild("Utils"))

export type SignalFn<Arg..., Ret...> = (Arg...) -> Ret...
export type SignalConnection<Arg..., Ret...> = {
    disconnect: () -> (),
    fn: SignalFn<Arg..., Ret...>,
}
export type SignalConnections<Arg..., Ret...> = { [SignalConnection<Arg..., Ret...>]: true }

export type SignalImpl<Arg..., Ret...> = {
    __index: SignalImpl<Arg..., Ret...>,
    new: () -> Signal<Arg..., Ret...>,
    connect: (Signal<Arg..., Ret...>, SignalFn<Arg..., Ret...>) -> SignalConnection<Arg..., Ret...>,
    once: (Signal<Arg..., Ret...>, SignalFn<Arg..., Ret...>) -> SignalConnection<Arg..., Ret...>,
    fire: (Signal<Arg..., Ret...>, Arg...) -> (),
    invoke: (Signal<Arg..., Ret...>, Arg...) -> { Utils.TryNotRaised<Ret...> },
    finishWaiting: (Signal<Arg..., Ret...>, Arg...) -> (),
    wait: (Signal<Arg..., Ret...>, number?, number?) -> Arg...,
    clean: (Signal<Arg..., Ret...>) -> (),
}

export type Signal<Arg..., Ret...> = typeof(setmetatable(
    {} :: {
        connections: SignalConnections<Arg..., Ret...>,
        waiting: { [(Arg...) -> ()]: true },
    },
    {} :: SignalImpl<Arg..., Ret...>
))

local Signal = {} :: SignalImpl<...any>
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)

    self.connections = {}
    self.waiting = {}

    return self
end

function Signal:connect(fn)
    local conn
    conn = {
        disconnect = function()
            self.connections[conn] = nil
        end,
        fn = fn,
    }
    self.connections[conn] = true
    return conn
end

function Signal:once(fn)
    local conn: SignalConnection<...any>?
    conn = self:connect(function(...)
        if conn then
            conn.disconnect()
            conn = nil
            fn(...)
        end
    end)
    return assert(conn)
end

function Signal:fire(...)
    self:finishWaiting(...)

    for conn in self.connections do
        task.defer(conn.fn, ...)
    end
end

function Signal:invoke(...)
    self:finishWaiting(...)

    return Utils.gather(function(exec, ...)
        for conn in self.connections do
            exec(conn.fn, ...)
        end
    end, ...)
end

function Signal:finishWaiting(...)
    -- no defer because it's important that the function runs BEFORE we remove
    -- it from `self.waiting`, otherwise it will think it has been cancelled.
    -- These are synchronous and don't have side effects on the class, so its safe (check :wait()).
    for fn in self.waiting do
        fn(...)
    end
    table.clear(self.waiting)
end

function Signal:wait(timeout, warnAfter)
    if not timeout then
        timeout = math.huge
        if not warnAfter then
            warnAfter = 5
        end
    elseif not warnAfter then
        warnAfter = math.max(5, timeout / 2)
    end

    local args = nil
    local function fn(...)
        args = { ... }
    end
    self.waiting[fn] = true

    local now = os.clock()
    local timeoutAt = now + timeout :: number
    local warnAt = now + warnAfter :: number

    while true do
        task.wait()

        if args then
            return table.unpack(args)
        end

        if not self.waiting[fn] then
            error("Signal wait was cancelled (i.e. via :clean()).")
        end

        now = os.clock()
        if now >= timeoutAt then
            error("Signal wait timed out.")
        elseif now >= warnAt then
            warn(
                "Signal wait is taking a long time. Consider increasing the timeout or warnAfter parameters.",
                debug.traceback()
            )
            warnAt = math.huge
        end
    end
end

function Signal:clean()
    table.clear(self.connections)
    table.clear(self.waiting)
end

return Signal
