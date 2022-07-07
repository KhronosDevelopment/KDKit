if not game:GetService("RunService"):IsClient() then
    -- Only clients have GUIs.
    return nil
end

return {
    App = require(script:WaitForChild("App")),
    Button = require(script:WaitForChild("Button")),
    Animate = require(script:WaitForChild("Animate")),
}
