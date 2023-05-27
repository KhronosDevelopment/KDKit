--[[
    A dead-simple way to replicate complicated data to clients in real time.

    Server:
    ```lua
    local rv = ReplicatedValue:get("leaderboards")

    while task.wait(1) do
        rv:set("level", fetchHighestLevelPlayers())
        rv:set("money", fetchRichestPlayers())
    end
    ```

    Client:
    ```lua
    local rv = ReplicatedValue:get("leaderboards")

    rv:listen("level", updateLevelLeaderboardsGui)
    rv:listen("money", updateMoneyLeaderboardsGui)
    ```

    It also supports functionality to easily parse subsections of tables,
    so that you can _very_ easily access only the data you're interested in!
    ```lua
    print("The current #1 player is:", rv:evaluate("level.firstPlace.name"))
    print("The current #1 player is:", rv:evaluate().level.firstPlace.name)

    rv:listen("level.firstPlace.name", function(name)
        print("The current #1 player is:", name)
    end)
    ```

    You can also set the `Permission`s for these values, so that only certain players can access them.
    ```lua
    local rv = ReplicatedValue:get("leaderboards", {}, game.Players.gaberocksall)
    -- Now, only `gaberocksall` can access the "leaderboards" key. Other players will never receive updates for it.
    ```

    This module is optimized for speed and network usage. It only supports values that can pass through RemoteEvents.

    You can use non-string keys like so:
    ```lua
    rv:listen({ "money", 1, "name" }, function(name)
        print("The current #1 player is:", name)
    end)
    ```

    or you can listen to the top level key like so:
    ```lua
    rv:listen("", function(leaderboards) -- an empty table will work the same
        print("The current #1 player is:", leaderboards.money[1].name)
    end)
    ```
--]]
local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

local Class = require(script.Parent:WaitForChild("Class"))
local Utils = require(script.Parent:WaitForChild("Utils"))
local Remote = require(script.Parent:WaitForChild("Remote"))
local RateLimit = require(script.Parent:WaitForChild("RateLimit"))

local ReplicatedValue = Class.new("ReplicatedValue")
ReplicatedValue.static.map = {} :: { [string]: "ReplicatedValue" }

if IS_SERVER then
    ReplicatedValue.static.remotesFolder = Instance.new("Folder", game:GetService("ReplicatedStorage"))
    ReplicatedValue.remotesFolder.Name = "KDKit.ReplicatedValue.Remotes"

    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "subscribe"
    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "unsubscribe"
    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "update"
else
    ReplicatedValue.static.remotesFolder = game:GetService("ReplicatedStorage")
        :WaitForChild("KDKit.ReplicatedValue.Remotes")
end

ReplicatedValue.static.remotes = {
    subscribe = Remote.new(ReplicatedValue.remotesFolder:WaitForChild("subscribe"), RateLimit.new(60, 300)),
    unsubscribe = Remote.new(ReplicatedValue.remotesFolder:WaitForChild("unsubscribe"), RateLimit.new(60, 300)),
    update = Remote.new(ReplicatedValue.remotesFolder:WaitForChild("update"), RateLimit.new(0, 1), true),
}

export type Permission = (player: Player) -> boolean | { Player } | Player
export type Path = { any }
export type PathLike = Path | string
export type Listener = { path: Path, callback: (value: any) -> nil }

function ReplicatedValue.static:get(key: string, initialValue: any?, initialPermission: Permission?): "ReplicatedValue"
    local rv = self.map[key]
    if not rv then
        rv = self.new(key, initialValue, initialPermission, true)
        self.map[key] = rv

        if not IS_SERVER then
            ReplicatedValue.remotes.subscribe(key)
        end
    end

    return rv
end

function ReplicatedValue.static:free(key: string)
    self.map[key] = nil

    if not IS_SERVER then
        ReplicatedValue.remotes.unsubscribe(key)
    end
end

function ReplicatedValue.static:changeAtLocationAffectsPath(changed: Path, path: Path)
    for i = 1, math.max(#changed, #path) do
        local c, p = changed[i], path[i]
        if c == nil or p == nil then
            return true
        elseif c ~= p then
            return false
        end
    end

    return true
end

ReplicatedValue.static.pendingSubscribers = {} :: { [string]: { [Player]: boolean } }
function ReplicatedValue.static:addPendingSubscriber(player: Player, key: string)
    local pendingSubscribers = self.pendingSubscribers[key] or {}
    pendingSubscribers[player] = true
    self.pendingSubscribers[key] = pendingSubscribers
end

game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
    for key, pendingSubscribers in ReplicatedValue.pendingSubscribers do
        for pendingSubscriber, _ in pendingSubscribers do
            if pendingSubscriber == player then
                pendingSubscribers[pendingSubscriber] = nil
            end
        end

        if not next(pendingSubscribers) then
            ReplicatedValue.pendingSubscribers[key] = nil
        end
    end
end)

function ReplicatedValue:__init(key: string, permission: Permission?, internallyHandlingLifecycle: boolean?)
    if not internallyHandlingLifecycle then
        error("Please use ReplicatedValue:get(...) instead of ReplicatedValue.new(...)")
    end

    self.key = key
    self.permission = permission

    self.currentValue = nil

    self.subscribers = {} :: { Player }
    self.listeners = {} :: { Listener }

    self.queuedSubscriberNotifications = {} :: { { path: Path, value: any } }

    self:pullPendingSubscribers()
end

function ReplicatedValue:pullPendingSubscribers()
    local pendingSubscribers = ReplicatedValue.pendingSubscribers[self.key]
    if not pendingSubscribers then
        return
    end

    for subscriber, _ in pendingSubscribers do
        self:subscribe(subscriber)
    end
    ReplicatedValue.pendingSubscribers[self.key] = nil
end

function ReplicatedValue:hasPermission(player: Player): boolean
    if not self.permission then
        return true
    elseif typeof(self.permission) == "Instance" then
        return self.permission == player
    elseif type(self.permission) == "table" then
        return not not table.find(self.permission, player)
    elseif type(self.permission) == "function" then
        return self.permission(player)
    end

    warn(("Unknown permission object: `%s`. Disallowing access."):format(Utils:repr(self.permission)))
    return false
end

function ReplicatedValue:receiveNewValueAt(value: any, path: Path, mustSucceed: boolean?)
    local pathLength = #path

    if pathLength == 0 then
        self.currentValue = value
    else
        local adjust = self.currentValue
        for pathDepth, pathPart in path do
            if type(adjust) ~= "table" then
                (if mustSucceed then error else warn)(
                    ("Illegal update made to ReplicatedValue `%s`. Was notified of a change which set `%s` to `%s`, but one of its ancestors is not a table (instead it was of type '%s')."):format(
                        self.key,
                        table.concat(path, "."),
                        Utils:repr(value),
                        type(adjust)
                    )
                )
                return false
            end

            if pathDepth == pathLength then
                adjust[pathPart] = value
            else
                adjust = adjust[pathPart]
            end
        end
    end

    self:notifySubscribersOfChangeAt(path)
    self:notifyListenersOfChangeAt(path)

    return true
end

function ReplicatedValue:notifySubscribersOfChangeAt(path: Path)
    if not self.pendingSubscriberNotification then
        self.pendingSubscriberNotification = path
    else
        local common = {}
        for i, pathPart in self.pendingSubscriberNotification do
            if path[i] == pathPart then
                table.insert(common, pathPart)
            else
                break
            end
        end

        self.pendingSubscriberNotification = common
    end
end

function ReplicatedValue:publishPendingSubscriberNotifications()
    local path = self.pendingSubscriberNotification
    if not path then
        return
    end
    self.pendingSubscriberNotification = nil

    local value = self:evaluate(path)
    for _, subscriber in self.subscribers do
        self:publishUpdateToSubscriber(subscriber, path, value)
    end
end

function ReplicatedValue:notifyListenersOfChangeAt(path: Path)
    for _, listener in self.listeners do
        if ReplicatedValue:changeAtLocationAffectsPath(path, listener.path) then
            task.defer(listener.callback, self:evaluate(listener.path))
        end
    end
end

function ReplicatedValue:evaluate(path: PathLike?): any
    if not path then
        return self.currentValue
    elseif type(path) == "string" then
        path = Utils:split(path, ".")
    end

    local value = self.currentValue
    for _, pathPart in path do
        if type(value) ~= "table" then
            return nil
        end

        value = value[pathPart]
    end

    return value
end

function ReplicatedValue:set(path: PathLike, value: any)
    if type(path) == "string" then
        path = Utils:split(path, ".")
    end

    return self:receiveNewValueAt(value, path, true)
end

function ReplicatedValue:isSubscribed(player: Player)
    return not not table.find(self.subscribers, player)
end

function ReplicatedValue:subscribe(player: Player)
    if self:isSubscribed(player) or not self:hasPermission(player) then
        return
    end

    table.insert(self.subscribers, player)
    self:publishUpdateToSubscriber(player, {}, self.currentValue)
end

function ReplicatedValue:publishUpdateToSubscriber(subscriber: Player, path: Path, value: any)
    ReplicatedValue.remotes.update(subscriber, self.key, path, value)
end

function ReplicatedValue:unsubscribe(player: Player)
    local i = table.find(self.subscribers, player)
    if i then
        table.remove(self.subscribers, i)
    end
end

function ReplicatedValue:listen(path: PathLike, callback: (value: any) -> nil): { Disconnect: () -> nil }
    if type(path) == "string" then
        path = Utils:split(path, ".")
    end

    local listener = { path = path, callback = callback } :: Listener
    table.insert(self.listeners, listener)
    task.defer(callback, self:evaluate(path))

    return {
        Disconnect = function()
            local i = table.find(self.listeners, listener)
            if i then
                table.remove(self.listeners, i)
            end
        end,
    }
end

function ReplicatedValue:clean()
    ReplicatedValue:free(self.key)
end

if IS_SERVER then
    ReplicatedValue.remotes.subscribe:connect(function(player: Player, key: string)
        print("ReplicatedValue.remotes.subscribe", key)

        local rv = ReplicatedValue.map[key]
        if not rv then
            return ReplicatedValue:addPendingSubscriber(player, key)
        end

        rv:subscribe(player)
    end)

    ReplicatedValue.remotes.unsubscribe:connect(function(player: Player, key: string)
        print("ReplicatedValue.remotes.unsubscribe", key)

        local rv = ReplicatedValue.map[key]
        if not rv then
            return
        end

        rv:unsubscribe(player)
    end)

    RunService.Heartbeat:Connect(function()
        for _, rv in ReplicatedValue.map do
            rv:publishPendingSubscriberNotifications()
        end
    end)
else
    ReplicatedValue.remotes.update:connect(function(key: string, path: Path, value: any)
        print("ReplicatedValue.remotes.update", key)
        local rv = ReplicatedValue.map[key]
        if not rv then
            return
        end

        rv:receiveNewValueAt(value, path)
    end)
end

return ReplicatedValue
