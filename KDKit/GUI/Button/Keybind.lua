--!strict

local ContextActionService = game:GetService("ContextActionService")

local Humanize = require(script.Parent.Parent.Parent:WaitForChild("Humanize"))
local Utils = require(script.Parent.Parent.Parent:WaitForChild("Utils"))
local S = require(script.Parent:WaitForChild("state"))
local T = require(script.Parent:WaitForChild("types"))

type KeybindImpl = T.KeybindImpl
export type Keybind = T.Keybind

local Keybind: KeybindImpl = {
    nextBindId = 0,
} :: KeybindImpl
Keybind.__index = Keybind

function Keybind.parseKeyCode(key)
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    elseif typeof(key) == "string" then
        return Utils.getattr(Enum.KeyCode, Humanize.casing(key, "pascal"))
    elseif typeof(key) == "number" then
        return ({
            [0] = Enum.KeyCode.Zero,
            [1] = Enum.KeyCode.One,
            [2] = Enum.KeyCode.Two,
            [3] = Enum.KeyCode.Three,
            [4] = Enum.KeyCode.Four,
            [5] = Enum.KeyCode.Five,
            [6] = Enum.KeyCode.Six,
            [7] = Enum.KeyCode.Seven,
            [8] = Enum.KeyCode.Eight,
            [9] = Enum.KeyCode.Nine,
        })[key]
    end

    return nil
end

function Keybind.useNextBindId()
    Keybind.nextBindId += 1
    return Keybind.nextBindId - 1
end

function Keybind.useNextBindString()
    return ("_KDKit.GUI.Button.Keybind_%d"):format(Keybind.useNextBindId())
end

function Keybind.new(button, keyReference)
    local key = Keybind.parseKeyCode(keyReference)
    if not key then
        error(("[KDKit.GUI.Button.Keybind] Failed to parse `%s` into a KeyCode."):format(Utils.repr(keyReference)))
    end

    local self = setmetatable({
        button = button,
        key = key,
    }, Keybind) :: Keybind

    return self
end

function Keybind:enable()
    if self.bind then
        return
    end

    self.bind = Keybind.useNextBindString()
    ContextActionService:BindAction(self.bind, function(_actionName, inputState, _inputObject)
        -- todo
        -- if inputState == Enum.UserInputState.Begin then
        --     if S.active ~= self.button then
        --         self.button:simulateMouseDown()
        --     end
        -- elseif inputState == Enum.UserInputState.End then
        --     if S.active == self.button then
        --         self.button:simulateMouseUp()
        --     end
        -- elseif inputState == Enum.UserInputState.Cancel then
        --     self.button:deactivate()
        -- end
    end, false, self.key)
end

function Keybind:disable()
    if not self.bind then
        return
    end

    ContextActionService:UnbindAction(self.bind)
    self.bind = nil
end

return Keybind
