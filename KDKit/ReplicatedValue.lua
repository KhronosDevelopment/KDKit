--!strict
--[[
    A dead-simple way to replicate complicated data to clients in real time.

    Server:
    ```lua
    local rv = ReplicatedValue.get("leaderboards")

    while task.wait(1) do
        rv:set("level", fetchHighestLevelPlayers())
        rv:set("money", fetchRichestPlayers())
    end
    ```

    Client:
    ```lua
    local rv = ReplicatedValue.get("leaderboards")

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
    local rv = ReplicatedValue.get("leaderboards", {}, game.Players.gaberocksall)
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
local IS_CLIENT = RunService:IsClient()

local Utils = require(script.Parent:WaitForChild("Utils"))

type Permission = ((player: Player) -> boolean) | { Player } | Player
type Path = { any }
type PathLike = Path | string
type Listener = { path: Path, callback: (value: any) -> nil, default: any? }

type ReplicatedValueImpl = {
    __index: ReplicatedValueImpl,
    map: { [string]: ReplicatedValue },
    pendingSubscribers: { [string]: { [Player]: true } },
    remotesFolder: Folder,
    remotes: {
        subscribe: RemoteEvent,
        unsubscribe: RemoteEvent,
        update: RemoteEvent,
    },
    get: (key: string, initialValue: any?, initialPermission: Permission?) -> ReplicatedValue,
    free: (key: string) -> (),
    changeAtLocationAffectsPath: (Path, Path) -> boolean,
    addPendingSubscriber: (Player, string) -> (), -- server only
    new: (string, any, Permission?, boolean?) -> ReplicatedValue,
    pullPendingSubscribers: (ReplicatedValue) -> (), -- server only
    hasPermission: (ReplicatedValue, player: Player) -> boolean, -- server only
    receiveNewValueAt: (ReplicatedValue, any, Path, boolean?) -> boolean,
    notifySubscribersOfChangeAt: (ReplicatedValue, Path) -> (), -- server only
    publishPendingSubscriberNotifications: (ReplicatedValue) -> (), -- server only
    notifyListenersOfChangeAt: (ReplicatedValue, Path) -> (),
    evaluate: (ReplicatedValue, PathLike?, any?) -> any,
    set: (ReplicatedValue, PathLike, any?) -> boolean, -- server only
    isSubscribed: (ReplicatedValue, Player) -> boolean, -- server only
    subscribe: (ReplicatedValue, Player) -> (), -- server only
    unsubscribe: (ReplicatedValue, Player) -> (), -- server only
    publishUpdateToSubscriber: (ReplicatedValue, Player, Path, any) -> (), -- server only
    listen: (ReplicatedValue, PathLike, (any) -> (), any?) -> { Disconnect: () -> () },
    clean: (ReplicatedValue) -> (),
}

export type ReplicatedValue = typeof(setmetatable(
    {} :: {
        key: string,
        permission: Permission?,
        currentValue: any,
        subscribers: { Player },
        listeners: { Listener },
        queuedSubscriberNotifications: { { path: Path, value: any } },
        pendingSubscriberNotification: Path?,
    },
    {} :: ReplicatedValueImpl
))

local ReplicatedValue: ReplicatedValueImpl = {
    map = {},
    pendingSubscribers = {},
} :: ReplicatedValueImpl
ReplicatedValue.__index = ReplicatedValue

if IS_SERVER then
    ReplicatedValue.remotesFolder = Instance.new("Folder", game:GetService("ReplicatedStorage"))
    ReplicatedValue.remotesFolder.Name = "_KDKit.ReplicatedValue.Remotes"

    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "subscribe"
    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "unsubscribe"
    Instance.new("RemoteEvent", ReplicatedValue.remotesFolder).Name = "update"
else
    ReplicatedValue.remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("_KDKit.ReplicatedValue.Remotes")
end

ReplicatedValue.remotes = {
    subscribe = ReplicatedValue.remotesFolder:WaitForChild("subscribe") :: RemoteEvent,
    unsubscribe = ReplicatedValue.remotesFolder:WaitForChild("unsubscribe") :: RemoteEvent,
    update = ReplicatedValue.remotesFolder:WaitForChild("update") :: RemoteEvent,
}

function ReplicatedValue.get(key, initialValue, initialPermission)
    local rv = ReplicatedValue.map[key]
    if not rv then
        rv = ReplicatedValue.new(key, initialValue, initialPermission, true)
        ReplicatedValue.map[key] = rv

        if IS_CLIENT then
            ReplicatedValue.remotes.subscribe:FireServer(key)
        end
    end

    return rv
end

function ReplicatedValue.free(key)
    ReplicatedValue.map[key] = nil

    if IS_CLIENT then
        ReplicatedValue.remotes.unsubscribe:FireServer(key)
    end
end

function ReplicatedValue.changeAtLocationAffectsPath(changed, path)
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

if IS_SERVER then
    function ReplicatedValue.addPendingSubscriber(player, key)
        if ReplicatedValue.pendingSubscribers[key] then
            ReplicatedValue.pendingSubscribers[key][player] = true
        else
            ReplicatedValue.pendingSubscribers[key] = { [player] = true }
        end
    end
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

-- WARNING: stores the value without making a copy, DO NOT MODIFY IT!
function ReplicatedValue.new(key, value, permission, internallyHandlingLifecycle)
    if not internallyHandlingLifecycle then
        error("[KDKit.ReplicatedValue] Please use .get(...) instead of .new(...)")
    end

    local self = setmetatable({
        key = key,
        permission = permission,
        currentValue = value,
        subscribers = {},
        listeners = {},
        queuedSubscriberNotifications = {},
    }, ReplicatedValue) :: ReplicatedValue

    if IS_SERVER then
        self:pullPendingSubscribers()
    end

    return self
end

-- WARNING: stores the value without making a copy, DO NOT MODIFY IT!
function ReplicatedValue:receiveNewValueAt(value, path, mustSucceed)
    local pathLength = #path

    if pathLength == 0 then
        self.currentValue = value
    else
        local adjust = self.currentValue
        if adjust == nil then
            adjust = {}
            self.currentValue = adjust
        end

        for pathDepth, pathPart in path do
            if type(adjust) ~= "table" then
                local msg = ("[KDKit.ReplicatedValue] Illegal update made to ReplicatedValue `%s`. Was notified of a change which set `%s` to `%s`, but one of its ancestors is not a table (instead it was of type '%s')."):format(
                    self.key,
                    table.concat(path, "."),
                    Utils.repr(value),
                    type(adjust)
                )

                if mustSucceed then
                    error(msg)
                else
                    warn(msg)
                end

                return false
            end

            if pathDepth == pathLength then
                adjust[pathPart] = value
            else
                if adjust[pathPart] == nil then
                    adjust[pathPart] = {}
                end
                adjust = adjust[pathPart]
            end
        end
    end

    if IS_SERVER then
        self:notifySubscribersOfChangeAt(path)
    end

    self:notifyListenersOfChangeAt(path)

    return true
end

function ReplicatedValue:notifyListenersOfChangeAt(path)
    for _, listener in self.listeners do
        if ReplicatedValue.changeAtLocationAffectsPath(path, listener.path) then
            task.defer(listener.callback, self:evaluate(listener.path, listener.default))
        end
    end
end

-- WARNING: returns internal data without copying, DO NOT MODIFY!
function ReplicatedValue:evaluate(path, default)
    if not path then
        path = {}
    elseif type(path) == "string" then
        path = Utils.split(path, ".")
    end

    local value = self.currentValue
    for _, pathPart in path :: Path do
        if type(value) ~= "table" then
            return default
        end

        value = value[pathPart]
    end

    if value == nil then
        return default
    end

    return value
end

-- WARNING: returns internal data without copying, DO NOT MODIFY!
function ReplicatedValue:listen(path, callback, default)
    if type(path) == "string" then
        path = Utils.split(path, ".")
    end

    local listener = { path = path, callback = callback, default = default } :: Listener
    table.insert(self.listeners, listener)
    task.defer(callback, self:evaluate(path, default))

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
    ReplicatedValue.free(self.key)
end

if IS_SERVER then
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

    function ReplicatedValue:hasPermission(player)
        if not self.permission then
            return true
        elseif typeof(self.permission) == "Instance" then
            return self.permission == player
        elseif type(self.permission) == "table" then
            return not not table.find(self.permission, player)
        elseif type(self.permission) == "function" then
            return self.permission(player)
        end

        warn(
            ("[KDKit.ReplicatedValue] Unknown permission object: `%s`. Disallowing access."):format(
                Utils.repr(self.permission)
            )
        )
        return false
    end

    function ReplicatedValue:isSubscribed(player)
        return not not table.find(self.subscribers, player)
    end

    function ReplicatedValue:subscribe(player)
        if self:isSubscribed(player) or not self:hasPermission(player) then
            return
        end

        table.insert(self.subscribers, player)
        self:publishUpdateToSubscriber(player, {}, self.currentValue)
    end

    function ReplicatedValue:unsubscribe(player)
        local i = table.find(self.subscribers, player)
        if i then
            table.remove(self.subscribers, i)
        end
    end

    function ReplicatedValue:notifySubscribersOfChangeAt(path)
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

    function ReplicatedValue:publishUpdateToSubscriber(subscriber, path, value)
        ReplicatedValue.remotes.update:FireClient(subscriber, self.key, path, value)
    end

    -- WARNING: stores the value without making a copy, DO NOT MODIFY IT!
    function ReplicatedValue:set(path, value)
        if typeof(path) == "string" then
            path = Utils.split(path, ".")
        end
        assert(typeof(path) == "table")

        return self:receiveNewValueAt(value, path, true)
    end

    ReplicatedValue.remotes.subscribe.OnServerEvent:Connect(function(player: Player, dirtyKey: any)
        if typeof(dirtyKey) ~= "string" then
            return
        end
        local key: string = dirtyKey

        local rv = ReplicatedValue.map[key]
        if not rv then
            return ReplicatedValue.addPendingSubscriber(player, key)
        end

        rv:subscribe(player)
    end)

    ReplicatedValue.remotes.unsubscribe.OnServerEvent:Connect(function(player: Player, dirtyKey: any)
        if typeof(dirtyKey) ~= "string" then
            return
        end
        local key: string = dirtyKey

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
    ReplicatedValue.remotes.update.OnClientEvent:Connect(function(key: string, path: Path, value: any)
        local rv = ReplicatedValue.map[key]
        if not rv then
            return
        end

        rv:receiveNewValueAt(value, path)
    end)
end

return ReplicatedValue
