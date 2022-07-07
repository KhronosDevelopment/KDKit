-- externals
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

-- class
local GUIUtility = {}

function GUIUtility:lerp(from, to, factor)
    return (to - from) * factor + from
end

function GUIUtility:easeOutCubic(x)
    return 1 - math.pow(1 - x, 3)
end

function GUIUtility:waitForEvent(event, timeout)
    timeout = timeout or math.huge
    
    local conn, result
    conn = event:Connect(function(...)
        if not conn then return end
        
        result = {...}
        conn:Disconnect()
        conn = nil
    end)
    
    local startedWaitingAt = os.clock()
    while conn and os.clock() - startedWaitingAt < timeout do
        task.wait(0)
    end
    
    if conn then conn:Disconnect() conn = nil end
    
    return table.unpack(result or {})
end

GUIUtility.assetType = {
    IMAGE = "image",
    AUDIO = "audio",
    MESH = "mesh",
    STATIC = "static"
}
function GUIUtility:categorizeAsset(inst)
    if inst:IsA("Sound") then
        return self.assetType.AUDIO
    elseif inst:IsA("Sky") or inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("Decal") or inst:IsA("Texture") then
        return self.assetType.IMAGE
    elseif inst:IsA("MeshPart") or inst:IsA("SpecialMesh") or inst:IsA("FileMesh") then
        return self.assetType.MESH
    else
        return self.assetType.STATIC
    end
end

function GUIUtility:ensureChildren(inst)
    local n = tonumber(inst:GetAttribute("n") or nil)
    
    if n then
        while n ~= #inst:GetChildren() do
            if not self:waitForEvent(inst.ChildAdded, 3) then
                warn(
                    (
                        "GUIUtility:ensureChildren(%s) is waiting for %d children, but it looks like there's actually %d..."
                    ):format(
                        inst:GetFullName(),
                        n,
                        #inst:GetChildren()
                    )
                )
            end
        end
    end
    
    return n
end

function GUIUtility:ensureDescendants(inst)
    local N = tonumber(inst:GetAttribute("N") or nil)
    
    if N then
        while N ~= #inst:GetDescendants() do
            if not self:waitForEvent(inst.DescendantAdded, 3) then
                warn(
                    (
                        "GUIUtility:ensureDescendants(%s) is waiting for %d descendants, but it looks like there's actually %d..."
                    ):format(
                        inst:GetFullName(),
                        N,
                        #inst:GetDescendants()
                    )
                )
            end
        end
    end
    
    return N
end

GUIUtility.preloadStage = {
    STARTED = "started loading",
    FINISHED = "finished loading",
    FAILED = "failed to load"
}
function GUIUtility:preload(inst, progressCallback, callback)
    -- make callbacks safe
    local _og_callback = callback
    local function callback(...)
        if not _og_callback then return end
        
        local s, r = pcall(_og_callback, ...)
        if not s then
            warn("GUIUtility:preload(" .. inst:GetFullName() .. ") callback failed w/ error:" .. r)
        end
        
        return r
    end

    local _og_progressCallback = progressCallback
    local function progressCallback(...)
        if not _og_progressCallback then return end

        local s, r = pcall(_og_progressCallback, ...)
        if not s then
            warn("GUIUtility:preload(" .. inst:GetFullName() .. ") progressCallback failed w/ error:" .. r)
        end

        return r
    end
    
    -- wait for the right number of descendants & children
    self:ensureChildren(inst)
    self:ensureDescendants(inst)
    
    if game:GetService("RunService"):IsServer() then
        progressCallback(1)
        return
    end
    
    -- start preloading
    local preloadsStarted = 0
    local preloadsCompleted = 0
    local destroyme = {
        screengui = Instance.new("ScreenGui")
    }
    destroyme.screengui.IgnoreGuiInset = true
    destroyme.screengui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    destroyme.screengui.DisplayOrder = -9999
    destroyme.screengui.Enabled = true
    destroyme.screengui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local function rawpreload(inst, x, at, id)
        callback(inst, id, self.assetType.IMAGE, self.preloadStage.STARTED)

        preloadsStarted += 1
        coroutine.wrap(pcall)(ContentProvider.PreloadAsync, ContentProvider, {x}, function(_, status)
            preloadsCompleted += 1
            callback(
                inst,
                id,
                at,
                status == Enum.AssetFetchStatus.Success and self.preloadStage.FINISHED or self.preloadStage.FAILED
            )
        end)
    end

    local function preloadImage(instance)
        local id = instance.Image

        local x = Instance.new("ImageLabel")
        x.Image = id
        x.Size = UDim2.fromOffset(1,1)
        x.Position = UDim2.fromOffset(0,0)
        x.BackgroundTransparency = 1
        x.ImageTransparency = 0.9
        x.BorderSizePixel = 0
        x.Parent = destroyme.screengui

        rawpreload(instance, x, self.assetType.IMAGE, id)
    end
    
    for _, d in pairs(inst:GetDescendants()) do
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
            preloadImage(d)
            
            -- button active
            if d:GetAttribute("button_active_image") then
                local tmp = d.Image
                d.Image = d:GetAttribute("button_active_image")

                preloadImage(d)

                d.Image = tmp
            end

            -- button hover
            if d:GetAttribute("button_hover_image") then
                local tmp = d.Image
                d.Image = d:GetAttribute("button_hover_image")

                preloadImage(d)

                d.Image = tmp
            end
        end
    end
    
    local lastProgressCallback = -1
    while preloadsCompleted < preloadsStarted do
        local progress = preloadsCompleted / preloadsStarted
        if progress ~= lastProgressCallback then
            progressCallback(progress)
        end
        lastProgressCallback = progress
        
        task.wait()
    end
    
    for _, inst in pairs(destroyme) do
        inst:Destroy()
    end

    progressCallback(1)
end

function GUIUtility:tweenOn(inst, seconds, style, includeDescendants)
    seconds = seconds or 0.5
    style = style or Enum.EasingStyle.Back
    if includeDescendants == nil then
        includeDescendants = true
    end

    local gu_onp = inst:GetAttribute("gu_onp")
    local gu_delay = inst:GetAttribute("gu_ond") or inst:GetAttribute("gu_d") or 0

    if gu_onp then
        local me = (tonumber(inst:GetAttribute("_gu_counter") or 0) or 0) + 1
        inst:SetAttribute("_gu_counter", me)

        coroutine.wrap(function()
            if gu_delay > 0 then task.wait(gu_delay) end

            if me == inst:GetAttribute("_gu_counter") then
                TweenService:Create(
                    inst,
                    TweenInfo.new(seconds, style, Enum.EasingDirection.Out, 0, false, 0),
                    {
                        Position = gu_onp
                    }
                ):Play()
            end
        end)()
    end

    local max_anim_time = gu_delay + seconds
    
    if includeDescendants then
        for _, d in pairs(inst:GetDescendants()) do
            max_anim_time = math.max(max_anim_time, self:tweenOn(d, seconds, style, false))
        end
    end
    
    return max_anim_time
end

function GUIUtility:tweenOff(inst, seconds, style, includeDescendants)
    seconds = seconds or 0.5
    style = style or Enum.EasingStyle.Back
    if includeDescendants == nil then
        includeDescendants = true
    end

    local gu_offp = inst:GetAttribute("gu_offp")
    local gu_delay = inst:GetAttribute("gu_offd") or inst:GetAttribute("gu_d") or 0

    if gu_offp then
        local me = (tonumber(inst:GetAttribute("_gu_counter") or 0) or 0) + 1
        inst:SetAttribute("_gu_counter", me)

        coroutine.wrap(function()
            if gu_delay > 0 then task.wait(gu_delay) end

            if me == inst:GetAttribute("_gu_counter") then
                TweenService:Create(
                    inst,
                    TweenInfo.new(seconds, style, Enum.EasingDirection.In, 0, false, 0),
                    {
                        Position = gu_offp
                    }
                ):Play()
            end
        end)()
    end

    local max_anim_time = gu_delay + seconds
    if includeDescendants then
        for _, d in pairs(inst:GetDescendants()) do
            max_anim_time = math.max(max_anim_time, self:tweenOff(d, seconds, style, false))
        end
    end
    
    return max_anim_time
end

function GUIUtility:aOnTopOfB(a, b) -- return true if a is rendered above b, nil if ambiguous, false otherwise
    local aGui =
        a:FindFirstAncestorOfClass("ScreenGui") or 
        a:FindFirstAncestorOfClass("SurfaceGui") or
        a:FindFirstAncestorOfClass("BillboardGui")

    local bGui =
        b:FindFirstAncestorOfClass("ScreenGui") or 
        b:FindFirstAncestorOfClass("SurfaceGui") or
        b:FindFirstAncestorOfClass("BillboardGui")

    -- make sure that they're both even in a Gui
    if aGui and not bGui then
        return true
    elseif bGui and not aGui then
        return false
    elseif not aGui and not bGui then
        return nil -- ambiguous
    end

    -- different gui? ez pz
    if aGui ~= bGui then

        -- prioritize ScreenGui over world Guis
        if aGui:IsA("ScreenGui") and not bGui:IsA("ScreenGui") then
            return true
        elseif not aGui:IsA("ScreenGui") and bGui:IsA("ScreenGui") then
            return false
        end

        -- they are both on the same "surface", just compare displayorder
        if aGui.DisplayOrder ~= bGui.DisplayOrder then
            return aGui.DisplayOrder > bGui.DisplayOrder
        else
            -- descendant?
            if bGui:IsDescendantOf(aGui) then
                return false
            elseif aGui:IsDescendantOf(bGui) then
                return true
            end

            return nil -- ambiguous
        end
    end

    -- the guis are the same
    local gui = aGui -- or bGui, they're equal

    -- global indexing mode? ez pz
    local global = gui.ZIndexBehavior == Enum.ZIndexBehavior.Global
    if global then
        if a.ZIndex ~= b.ZIndex then
            return a.ZIndex > b.ZIndex
        else
            return nil -- ambiguous
        end
    end

    -- child of one another? ez pz
    if b:IsDescendantOf(a) then
        return false
    elseif a:IsDescendantOf(b) then
        return true
    end

    -- not a simple comparison,
    -- will have to build ancestor tree
    -- and do full check

    -- they are ancestors of themselves
    -- it is impossible for these to ever be matched
    -- as a common ancestor because of the above :IsDescendantOf check
    -- but it simplifies the checks later on
    local aAncestors = {[a] = true}
    local bAncestors = {[b] = true}

    -- find first common ancestor
    -- note: something is guranteed to be found since
    -- `a` and `b` share the same `gui` ancestor
    local firstCommonAncestor = nil
    local aAncestor = a
    local bAncestor = b
    while not firstCommonAncestor do
        if aAncestor.Parent then
            aAncestor = aAncestor.Parent
            aAncestors[aAncestor] = true
        end
        if bAncestor.Parent then
            bAncestor = bAncestor.Parent
            bAncestors[bAncestor] = true
        end

        if bAncestors[aAncestor] then
            firstCommonAncestor = aAncestor
        elseif aAncestors[bAncestor] then
            firstCommonAncestor = bAncestor
        end
    end

    local aFirstDescendantOfCommonAncestor, bFirstDescendantOfCommonAncestor
    local aWasFoundFirst = nil
    for _, v in ipairs(firstCommonAncestor:GetChildren()) do
        if aAncestors[v] then
            aFirstDescendantOfCommonAncestor = v
        elseif bAncestors[v] then
            bFirstDescendantOfCommonAncestor = v
        end
    end

    if aFirstDescendantOfCommonAncestor.ZIndex ~= bFirstDescendantOfCommonAncestor.ZIndex then
        return aFirstDescendantOfCommonAncestor.ZIndex > bFirstDescendantOfCommonAncestor.ZIndex
    else
        return nil -- ambiguous
    end
end

return GUIUtility
