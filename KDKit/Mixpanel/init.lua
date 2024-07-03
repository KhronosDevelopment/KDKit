--!strict

local Client = require(script:WaitForChild("Client"))

export type Client = Client.Client

return {
    Client = Client,
}
