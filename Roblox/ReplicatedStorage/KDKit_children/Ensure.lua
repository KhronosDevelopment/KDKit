local function ypcall(f, ...)
    local args = {...}
    return xpcall(function() return f(table.unpack(args)) end, debug.traceback)
end

return function(ensure, f, ...)
    local results = table.pack(ypcall(f, ...))
    
    local success = table.remove(results, 1)
    
    local ensureResults = table.pack(ypcall(ensure, not success))
    local ensureSuccess = table.remove(ensureResults, 1)
    
    if not ensureSuccess then
        task.defer(error, "KDKit.Ensure callback failed with error: " .. ensureResults[1])
    end
    
    if success then
        return table.unpack(results)
    else
        error(results[1])
    end
end
