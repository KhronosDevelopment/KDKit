if game:GetService("RunService"):IsServer() then
    return require(script:WaitForChild("ServerImplementation"))
else
    return require(script:WaitForChild("ClientImplementation"))
end
