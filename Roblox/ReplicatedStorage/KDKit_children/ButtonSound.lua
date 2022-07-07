-- externals
local KDKit = require(game.ReplicatedStorage:WaitForChild("KDKit"))
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- class
local ButtonSound = KDKit.Class("ButtonSound")

-- utils
ButtonSound.audio = {
    press = script.press,
    release = script.release,
}

task.defer(function()
    local before = ButtonSound.audio.press
    ButtonSound.audio.press = SoundService:WaitForChild("KDKit.ButtonSound.press", math.huge)
    before:Destroy()
end)

task.defer(function()
    local before = ButtonSound.audio.release
    ButtonSound.audio.release = SoundService:WaitForChild("KDKit.ButtonSound.release", math.huge)
    before:Destroy()
end)

-- implementation
function ButtonSound:__init()
    self.lastPressSound = nil
end

function ButtonSound:press()
    if not RunService:IsRunning() then return end

    local me = ButtonSound.audio.press:Clone()
    me.Name = "_button_press_sound"

    -- make sure that releases will wait to play
    self.lastPressSound = me

    -- destroy on completion
    me.Ended:Connect(function()
        if self.lastPressSound == me then
            self.lastPressSound = nil
        end
        me:Destroy()
    end)

    -- play
    me.Parent = SoundService
    me:Play()
end

function ButtonSound:release()
    if not RunService:IsRunning() then return end

    local me = ButtonSound.audio.release:Clone()
    me.Name = "_button_release_sound"

    task.defer(function()
        -- wait for the press sound to finish
        if self.lastPressSound then
            self.lastPressSound.Ended:Wait()
        end

        -- destroy on completion
        me.Ended:Connect(function()
            me:Destroy()
        end)

        -- play
        me.Parent = SoundService
        me:Play()
    end)
end

return ButtonSound
