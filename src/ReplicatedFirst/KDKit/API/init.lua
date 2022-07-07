--[[
    KDKit.API provides a seamless interface for making HTTP requests.

    At a glance:
    ```lua
    local success, response = (API.my_configuration / "do" / "something"):POST({ key = "value" })
    -- ^ makes a POST request to https://your.configured.url.com/do/something/ with the JSON body '{"key": "value"}'
    -- will also include several headers, depending on your `my_configuration` configuration

    if not success then
        print("Uh oh, something went wrong. Here's a descriptive error message:", response)
    else
        print("The endpoint responded with some JSON data, which has been decoded into this table:", response)
    end
    ```

    KDKit.API also has numerous other usability features.
    Please also see KDKit.API.Config documentation which goes over some of the most important features, like secure time-based token authentication.

    TODO: explain features like:
        - automatic argument formatting for GET, POST, PUT, PATCH, and DELETE verbs
        - automatic response parsing
        - automatic header additions
        - player, coroutine, and erroneous request flags
        - multiple website & slash-path-ing
        - automatic request queuing and rate limiting

    RESTRICTIONS:
        - At the moment, KDKit.API only supports JSON requests and responses (except GET requests, which uses normal URL arguments).
        There is no plan to change this in the future, since JSON covers all use cases and is the only language supported by HttpService.
        Unless HttpService adds yaml support, then support for yaml will be added. Yaml is sexy.
        If you wish to use an API that only supports xml responses, then email the developers and ask them to grow up.
        - Related to above, you cannot do binary file downloads, since that will not be in the JSON format.
        - KDKit.API does not support dynamically making requests to new domain names. You must configure a list of domains
        that you wish to support before running the game. See KDKit.API.Config for more details.
--]]

if not game:GetService("RunService"):IsServer() then
    -- Only servers can access APIs.
    return nil
end

local API = {
    Config = require(script:WaitForChild("Config")),
    Endpoint = require(script:WaitForChild("Endpoint")),
}

for name, config in API.Config.list do
    if API[name] then
        error(("API.%s is a reserved name, and cannot be used as a Config name."):format(name))
    end

    API[name] = API.Endpoint.new(config)
end

return API
