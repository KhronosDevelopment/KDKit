function errorOccurred(e)
    -- this will raise the real error in the debug console
    task.defer(error, e)

    -- this is the error that the client will see
    -- wrapping it in an anonymous function causes the
    -- topmost stack frame to be unintelligible
    -- (roblox only sends the topmost stack frame, so that's fine)
    ;(function() error("Something went wrong!") end)()
end

return function(f)
    return function(...)
        local args = {...}
        local results = table.pack(xpcall(function() return f(table.unpack(args)) end, debug.traceback))

        if results[1] == false then
            errorOccurred(results[2])
        else
            table.remove(results, 1)
            return table.unpack(results)
        end
    end
end
