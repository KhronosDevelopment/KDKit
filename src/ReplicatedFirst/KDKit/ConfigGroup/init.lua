local Preload = require(script.Parent:WaitForChild("Preload"))
local Humanize = require(script.Parent:WaitForChild("Humanize"))
local Class = require(script.Parent:WaitForChild("Class"))

local ConfigGroup = {
    Config = require(script:WaitForChild("Config")),
}

function ConfigGroup.new(groupInstance: ModuleScript, skipNameWarning: boolean?)
    local group = {}

    local rootConfigInstance = nil
    repeat
        rootConfigInstance = groupInstance:GetChildren()[1] or Preload:waitForEvent(groupInstance.ChildAdded, 3)
        if not rootConfigInstance then
            warn(("KDKit.ConfigGroup is waiting for a child to appear under `%s`"):format(groupInstance:GetFullName()))
        end
    until rootConfigInstance

    if not skipNameWarning and groupInstance.Name ~= Humanize:plural(rootConfigInstance.Name) then
        warn(
            ("The ConfigGroup `%s` should be named '%s' rather than '%s'. Pass `skipNameWarning = true` to silence"):format(
                groupInstance:GetFullName(),
                Humanize:plural(rootConfigInstance.Name),
                groupInstance.Name
            )
        )
    end

    Preload:ensureDescendants(rootConfigInstance)
    local rootConfig = require(rootConfigInstance)

    if not Class:isSubClass(rootConfig, ConfigGroup.Config) then
        error(("Config root at `%s` must inherit KDKit.ConfigGroup.Config."):format(rootConfigInstance))
    end

    local checkedCommons = false
    for _, configInstance in rootConfigInstance:GetChildren() do
        if configInstance:IsA("Folder") and configInstance.Name == "common" then
            if checkedCommons then
                error(
                    "You may only have one commons folder, but you have at least two. " .. configInstance:GetFullName()
                )
            end
            checkedCommons = true
        elseif not configInstance:IsA("ModuleScript") then
            error(
                "All children of a ConfigGroup must be either a ModuleScript or a Folder named 'commons'. Found "
                    .. configInstance:GetFullName()
                    .. " instead."
            )
        end

        local expectedClassName = ("%s.%s"):format(rootConfig.__name, configInstance.name)

        local config = require(configInstance)
        if config == nil then
            config = Class.new(expectedClassName, rootConfig).new(configInstance)
        end

        if config.__class == Class then
            error(
                ("Config at `%s` must return a singleton instance of the class, not the class itself. For example `return %s.new(script)`."):format(
                    config.__name
                )
            )
        end

        if not Class:isSubClass(config.__class, rootConfig) then
            error(
                ("Config at `%s` must inherit from the root config at `%s`."):format(
                    configInstance:GetFullName(),
                    rootConfigInstance:GetFullName()
                )
            )
        end

        if config.name ~= configInstance.Name then
            error(
                ("Please don't override `config.name`, that's confusing! Maybe you meant to override `humanName`? (in config `%s`)"):format(
                    configInstance:GetFullName()
                )
            )
        end

        if config.__class.__name ~= expectedClassName then
            error(
                ("Config at `%s` was expected to have the class name '%s', but instead got '%s'."):format(
                    configInstance:GetFullName(),
                    expectedClassName,
                    config.__class.__name
                )
            )
        end

        if group[config.name] then
            error(("Duplicate config name '%s' at `%s`."):format(config.name, configInstance:GetFullName()))
        end

        group[config.name] = config
    end

    return group
end

return ConfigGroup
