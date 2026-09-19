local wind ='https://github.com/Footagesus/WindUI.';

if game.PlaceId == 139897142163588 then
    local Tab17 = Window:Tab({
        Title = "我讨厌脑红",
        Icon = "crown"
    })
    
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
local Event = ReplicatedStorage.Events.CastJunctionVote

local voteLoopEnabled = false
local voteLeftThread = nil
local voteRightThread = nil



Tab17:Section({
    Title = "自动投票",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab17:Toggle({
    Title = "循环投左路",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if voteLeftThread then
                task.cancel(voteLeftThread)
            end
            if voteRightThread then
                task.cancel(voteRightThread)
                voteRightThread = nil
            end
            voteLoopEnabled = true
            voteLeftThread = task.spawn(function()
                while true do
                    pcall(function()
                        Event:FireServer("Left")
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if voteLeftThread then
                task.cancel(voteLeftThread)
                voteLeftThread = nil
            end
            if not voteRightThread then
                voteLoopEnabled = false
            end
        end
    end
})

Tab17:Toggle({
    Title = "循环投右路",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if voteRightThread then
                task.cancel(voteRightThread)
            end
            if voteLeftThread then
                task.cancel(voteLeftThread)
                voteLeftThread = nil
            end
            voteLoopEnabled = true
            voteRightThread = task.spawn(function()
                while true do
                    pcall(function()
                        Event:FireServer("Right")
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if voteRightThread then
                task.cancel(voteRightThread)
                voteRightThread = nil
            end
            if not voteLeftThread then
                voteLoopEnabled = false
            end
        end
    end
})

local leverThread18 = nil

local Tab18 = Window:Tab({
    Title = "拉杆循环",
    Icon = "mouse-pointer-click",
    Border = true,
})

Tab18:Section({
    Title = "自动拉杆",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab18:Toggle({
    Title = "自动拉杆",
    Desc = "需站在拉杆附近才能生效",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if leverThread18 then
                task.cancel(leverThread18)
            end
            leverThread18 = task.spawn(function()
                while true do
                    pcall(function()
                        local cart = workspace:FindFirstChild("Cart")
                        if not cart then task.wait(0.5) return end
                        local lever = cart:FindFirstChild("Lever")
                        if not lever then task.wait(0.5) return end
                        local proxPart = lever:FindFirstChild("ProxPart")
                        if not proxPart then task.wait(0.5) return end
                        local prompt = proxPart:FindFirstChildOfClass("ProximityPrompt")
                        if not prompt then task.wait(0.5) return end

                        local char = game:GetService("Players").LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if not root then task.wait(0.5) return end

                        local promptPos = proxPart.Position
                        local dist = (promptPos - root.Position).Magnitude
                        local maxDist = math.max(prompt.MaxActivationDistance, 12)

                        if dist > maxDist then
                            task.wait(0.5)
                            return
                        end

                        local oldHold = prompt.HoldDuration
                        local oldLOS = prompt.RequiresLineOfSight

                        prompt.RequiresLineOfSight = false
                        prompt.HoldDuration = 0

                        prompt:InputHoldBegin()
                        task.wait(0.05)
                        prompt:InputHoldEnd()

                        task.wait(0.1)
                        prompt.HoldDuration = oldHold
                        prompt.RequiresLineOfSight = oldLOS
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if leverThread18 then
                task.cancel(leverThread18)
                leverThread18 = nil
            end
        end
    end
})


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer

local PlayEquipAnimEvent = ReplicatedStorage:FindFirstChild("PlayEquipAnim")
local NotificationEvent = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Notification")

local brainStemTrinket = ReplicatedStorage and ReplicatedStorage:FindFirstChild("BlasterTrinkets") and ReplicatedStorage.BlasterTrinkets:FindFirstChild("Charm_BrainStem")
local lightningMuzzle = ReplicatedStorage and ReplicatedStorage:FindFirstChild("BlasterTrinkets") and ReplicatedStorage.BlasterTrinkets:FindFirstChild("Muzzle_Lightning")

local animLoopThread = nil
local notifyLoopThread = nil

local Tab19 = Window:Tab({
    Title = "特效通知循环",
    Icon = "sparkles",
    Border = true,
})

Tab19:Section({
    Title = "播放装备动画",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab19:Button({
    Title = "单次播放 BrainStem动画",
    Desc = "",
    Callback = function()
        if PlayEquipAnimEvent and brainStemTrinket then
            pcall(function()
                firesignal(PlayEquipAnimEvent.OnClientEvent, brainStemTrinket)
            end)
        end
    end
})

Tab19:Toggle({
    Title = "循环播放 BrainStem动画",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if animLoopThread then
                task.cancel(animLoopThread)
            end
            animLoopThread = task.spawn(function()
                while true do
                    pcall(function()
                        if PlayEquipAnimEvent and brainStemTrinket then
                            firesignal(PlayEquipAnimEvent.OnClientEvent, brainStemTrinket)
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if animLoopThread then
                task.cancel(animLoopThread)
                animLoopThread = nil
            end
        end
    end
})

Tab19:Button({
    Title = "单次播放 Lightning动画",
    Desc = "",
    Callback = function()
        if PlayEquipAnimEvent and lightningMuzzle then
            pcall(function()
                firesignal(PlayEquipAnimEvent.OnClientEvent, lightningMuzzle)
            end)
        end
    end
})

Tab19:Toggle({
    Title = "循环播放 Lightning动画",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if animLoopThread then
                task.cancel(animLoopThread)
            end
            animLoopThread = task.spawn(function()
                while true do
                    pcall(function()
                        if PlayEquipAnimEvent and lightningMuzzle then
                            firesignal(PlayEquipAnimEvent.OnClientEvent, lightningMuzzle)
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if animLoopThread then
                task.cancel(animLoopThread)
                animLoopThread = nil
            end
        end
    end
})

Tab19:Section({
    Title = "弹出通知",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab19:Button({
    Title = "单次弹出 德与牛逼通知",
    Desc = "触发一次 德与牛逼 通知",
    Callback = function()
        if NotificationEvent then
            pcall(function()
                firesignal(NotificationEvent.OnClientEvent, "德与中山牛逼", "", "Default")
            end)
        end
    end
})

Tab19:Toggle({
    Title = "循环弹出 我爱你德与中山通知",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if notifyLoopThread then
                task.cancel(notifyLoopThread)
            end
            notifyLoopThread = task.spawn(function()
                while true do
                    pcall(function()
                        if NotificationEvent then
                            firesignal(NotificationEvent.OnClientEvent, "我爱你德与中山", "", "Default")
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if notifyLoopThread then
                task.cancel(notifyLoopThread)
                notifyLoopThread = nil
            end
        end
    end
})

local effectLoopThread19 = nil
local biomeLoopThread19 = nil

Tab19:Section({
    Title = "特效/环境文本",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab19:Toggle({
    Title = "循环 TrinketEffectTrigger特效德与中山牛逼文本",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if effectLoopThread19 then
                task.cancel(effectLoopThread19)
            end
            effectLoopThread19 = task.spawn(function()
                while true do
                    pcall(function()
                        local ev = game:GetService("ReplicatedStorage"):FindFirstChild("TrinketEffectTrigger")
                        if ev then
                            firesignal(ev.OnClientEvent, "德与中山牛逼")
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if effectLoopThread19 then
                task.cancel(effectLoopThread19)
                effectLoopThread19 = nil
            end
        end
    end
})

Tab19:Toggle({
    Title = "循环 屏幕下方出现德与中山",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if biomeLoopThread19 then
                task.cancel(biomeLoopThread19)
            end
            biomeLoopThread19 = task.spawn(function()
                while true do
                    pcall(function()
                        local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
                        local ev = events and events:FindFirstChild("BiomeAnimation")
                        if ev then
                            firesignal(ev.OnClientEvent, "德与中山牛逼")
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if biomeLoopThread19 then
                task.cancel(biomeLoopThread19)
                biomeLoopThread19 = nil
            end
        end
    end
})
local TY1 = game:GetService("Players")
local TY2 = game:GetService("RunService")
local TY3 = TY1.LocalPlayer or TY1:GetPropertyChangedSignal("LocalPlayer"):Wait() and TY1.LocalPlayer

local TY4 = false
local TY5 = false
local TY6 = nil

local function TY7()
    local TY8 = TY3.Character
    if not TY8 then return nil end
    for _, TY9 in pairs(TY8:GetChildren()) do
        if TY9:IsA("Tool") or (TY9:IsA("Model") and TY9:FindFirstChild("Remotes")) then
            if TY9:FindFirstChild("Remotes") and TY9.Remotes:FindFirstChild("Shoot") then
                return TY9
            end
        end
    end
    return nil
end

local function TY10()
    local TY11 = {}
    local function TY12(TY13)
        if TY13:IsA("Model") and TY13 ~= TY3.Character then
            local TY14 = TY13:FindFirstChildOfClass("Humanoid")
            if TY14 and TY14.Health > 0 and not TY1:GetPlayerFromCharacter(TY13) then
                local TY15 = TY13:FindFirstChild("Head") or TY13:FindFirstChild("HumanoidRootPart") or TY13.PrimaryPart
                if TY15 then
                    table.insert(TY11, {h = TY14, p = TY15})
                end
            end
        end
    end

    local TY16 = workspace:FindFirstChild("ActiveEnemies")
    if TY16 then
        for _, TY17 in pairs(TY16:GetDescendants()) do
            if TY17:IsA("Humanoid") then
                TY12(TY17.Parent)
            end
        end
    end

    for _, TY18 in pairs(workspace:GetChildren()) do
        if TY18:IsA("Model") and (TY18.Name:find("Boss") or TY18:FindFirstChild("Humanoid")) then
            TY12(TY18)
        end
    end

    return TY11
end

local function GetOffsets_Algo1(TY32)
    local TY33 = TY32.p.Position
    local TY34 = {}
    local TY35 = {
        Vector3.new(0, 0, 0),
        Vector3.new(0, 1, 0),
        Vector3.new(0, -1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0.5, 1),
        Vector3.new(0, -0.5, -1),
    }
    for _, TY36 in ipairs(TY35) do
        table.insert(TY34, TY33 + TY36)
    end
    return TY34
end

local function GetOffsets_Algo2(TY32, TY37)
    local TY33 = TY32.p.Position
    local TY34 = {}
    local TY38 = 6
    local TY39 = tick() * 3
    for TY40 = 0, TY38 - 1 do
        local TY41 = (TY40 / TY38) * math.pi * 2 + TY39
        local TY42 = Vector3.new(math.cos(TY41), math.sin(TY41), math.sin(TY41 * 2))
        table.insert(TY34, TY33 + TY42 * (TY37 or 1.5))
    end
    return TY34
end

local function TY43()
    if TY6 then return end
    TY6 = TY2.RenderStepped:Connect(function()
        if not TY4 then return end

        local TY20 = TY7()
        if not TY20 then return end

        local TY21 = TY20.Remotes:FindFirstChild("Shoot")
        local TY22 = TY20.Remotes:FindFirstChild("Reload")

        if TY22 and not TY5 then
            task.spawn(function()
                pcall(function()
                    TY22:InvokeServer()
                end)
            end)
        end

        if TY21 then
            local TY23 = TY10()
            for _, TY24 in pairs(TY23) do
                task.spawn(function()
                    pcall(function()
                        local TY25 = TY3.Character and TY3.Character.PrimaryPart and TY3.Character.PrimaryPart.Position
                        if not TY25 then return end

                        local TY27 = {
                            ["1"] = TY24.h
                        }

                        if TY5 then
                            local TY44 = {}
                            for _, TY45 in ipairs(GetOffsets_Algo1(TY24)) do
                                table.insert(TY44, TY45)
                            end
                            for _, TY45 in ipairs(GetOffsets_Algo2(TY24)) do
                                table.insert(TY44, TY45)
                            end
                            for _, TY45 in ipairs(TY44) do
                                local TY26 = CFrame.new(TY25, TY45)
                                TY21:FireServer(workspace:GetServerTimeNow(), TY26, TY27)
                            end
                        else
                            local TY26 = CFrame.new(TY25, TY24.p.Position)
                            TY21:FireServer(workspace:GetServerTimeNow(), TY26, TY27)
                        end
                    end)
                end)
            end
        end
    end)
end

local function TY28()
    TY4 = false
    if TY6 then
        TY6:Disconnect()
        TY6 = nil
    end
end

local TY29 = Window:Tab({
    Title = "主要",
    Icon = "crosshair",
    Border = true,
})

TY29:Section({
    Title = "自动射击",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

TY29:Toggle({
    Title = "启用 Ragebot",
    Desc = "无限弹药",
    Value = false,
    Callback = function(TY30)
        TY4 = TY30
        if TY30 then
            TY43()
        else
            TY28()
        end
    end
})



local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer

local enemyESPEnabled = false
local espCleaned = false
local espHighlights = {}
local trackedEnemies = {}

local ESPConfig = {
    HighlightColor = Color3.fromRGB(255, 0, 0),
    OutlineColor = Color3.fromRGB(255, 255, 255),
    FillTransparency = 0.75,
    OutlineTransparency = 0,
    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}

local function getEnemyModels()
    local enemies = {}
    local function checkModel(model)
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not Players:GetPlayerFromCharacter(model) then
                table.insert(enemies, model)
            end
        end
    end

    local activeEnemies = workspace:FindFirstChild("ActiveEnemies")
    if activeEnemies then
        for _, desc in pairs(activeEnemies:GetDescendants()) do
            if desc:IsA("Humanoid") and desc.Parent:IsA("Model") then
                checkModel(desc.Parent)
            end
        end
    end

    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") and (child.Name:find("Boss") or child:FindFirstChild("Humanoid")) then
            checkModel(child)
        end
    end

    return enemies
end

local function addHighlight(model)
    if espHighlights[model] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "EnemyESP"
    highlight.FillColor = ESPConfig.HighlightColor
    highlight.OutlineColor = ESPConfig.OutlineColor
    highlight.FillTransparency = ESPConfig.FillTransparency
    highlight.OutlineTransparency = ESPConfig.OutlineTransparency
    highlight.DepthMode = ESPConfig.DepthMode
    highlight.Adornee = model
    highlight.Parent = model
    espHighlights[model] = highlight
    trackedEnemies[model] = true
end

local function removeHighlight(model)
    if espHighlights[model] then
        espHighlights[model]:Destroy()
        espHighlights[model] = nil
    end
    trackedEnemies[model] = nil
end

local function clearAllHighlights()
    for model, _ in pairs(espHighlights) do
        if espHighlights[model] then
            espHighlights[model]:Destroy()
        end
        espHighlights[model] = nil
    end
    table.clear(trackedEnemies)
end

RunService.RenderStepped:Connect(function()
    if not enemyESPEnabled then
        if not espCleaned then
            clearAllHighlights()
            espCleaned = true
        end
        return
    end

    espCleaned = false

    local currentModels = {}
    local enemies = getEnemyModels()

    for _, model in ipairs(enemies) do
        currentModels[model] = true
        addHighlight(model)
    end

    for model, _ in pairs(trackedEnemies) do
        if not currentModels[model] or not model.Parent then
            removeHighlight(model)
        end
    end
end)
TY29:Section({
    Title = "怪物透视",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})
TY29:Toggle({
    Title = "启用怪物 ESP",
    Desc = "高亮显示所有怪物",
    Value = false,
    Callback = function(enabled)
        enemyESPEnabled = enabled
        if not enabled then
            clearAllHighlights()
            espCleaned = true
        end
    end
})

end
