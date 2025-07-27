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
    fire: (Signal<Arg..., Ret...>, Arg...) -> (),
    invoke: (Signal<Arg..., Ret...>, Arg...) -> { Utils.TryNotRaised<Ret...> },
}

export type Signal<Arg..., Ret...> = typeof(setmetatable(
    {} :: {
        connections: SignalConnections<Arg..., Ret...>,
    },
    {} :: SignalImpl<Arg..., Ret...>
))

local Signal = {} :: SignalImpl<...any>
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)

    self.connections = {}

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

function Signal:fire(...)
    for conn in self.connections do
        task.defer(conn.fn, ...)
    end
end

function Signal:invoke(...)
    return Utils.gather(function(exec, ...)
        for conn in self.connections do
            exec(conn.fn, ...)
        end
    end, ...)
end

return Signal
