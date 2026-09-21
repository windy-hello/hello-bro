--========== 依赖加载 ==========
if not loadstring then
    error("当前执行器不支持 loadstring，无法运行")
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

--========== 服务与常量（统一定义，避免重复 local） ==========
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- 安全等待关键事件，避免 Events 尚未复制就索引 nil
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local CastJunctionVote = Events and Events:WaitForChild("CastJunctionVote", 10)

--========== 执行器能力检测 ==========
if not firesignal then
    warn("[脚本] 当前执行器不支持 firesignal，特效/通知类功能将无法生效")
end

--========== 主窗口 ==========
local Window = WindUI:CreateWindow({
    Title = "德与中山",
    Icon = "crown",
    Author = "你",
    Folder = "MyScript",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    UserConfig = true,
})

--====================================================
-- Tab17 : 自动投票
--====================================================
local Tab17 = Window:Tab({
    Title = "自动投票",
    Icon = "vote",
    Border = true,
})

Tab17:Section({
    Title = "自动投票",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

local voteLeftThread  = nil
local voteRightThread = nil

-- 关闭左路时只取消左路，不动右路
Tab17:Toggle({
    Title = "循环投左路",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if voteLeftThread then
                task.cancel(voteLeftThread)
                voteLeftThread = nil
            end
            if not CastJunctionVote then
                warn("[自动投票] 未找到 CastJunctionVote 事件")
                return
            end
            voteLeftThread = task.spawn(function()
                while true do
                    pcall(function()
                        CastJunctionVote:FireServer("Left")
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if voteLeftThread then
                task.cancel(voteLeftThread)
                voteLeftThread = nil
            end
        end
    end,
})

Tab17:Toggle({
    Title = "循环投右路",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if voteRightThread then
                task.cancel(voteRightThread)
                voteRightThread = nil
            end
            if not CastJunctionVote then
                warn("[自动投票] 未找到 CastJunctionVote 事件")
                return
            end
            voteRightThread = task.spawn(function()
                while true do
                    pcall(function()
                        CastJunctionVote:FireServer("Right")
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if voteRightThread then
                task.cancel(voteRightThread)
                voteRightThread = nil
            end
        end
    end,
})

--====================================================
-- Tab18 : 拉杆循环
--====================================================
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

local leverThread18 = nil

Tab18:Toggle({
    Title = "自动拉杆",
    Desc = "需站在拉杆附近才能生效",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if leverThread18 then
                task.cancel(leverThread18)
                leverThread18 = nil
            end
            leverThread18 = task.spawn(function()
                while true do
                    pcall(function()
                        local cart = workspace:FindFirstChild("Cart")
                        if not cart then return end
                        local lever = cart:FindFirstChild("Lever")
                        if not lever then return end
                        local proxPart = lever:FindFirstChild("ProxPart")
                        if not proxPart then return end
                        local prompt = proxPart:FindFirstChildOfClass("ProximityPrompt")
                        if not prompt then return end

                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if not root then return end

                        local promptPos = proxPart.Position
                        local dist = (promptPos - root.Position).Magnitude

                        -- 只允许在服务端允许的距离内触发，避免被回弹
                        if dist > prompt.MaxActivationDistance then
                            return
                        end

                        local oldHold = prompt.HoldDuration
                        local oldLOS  = prompt.RequiresLineOfSight

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
    end,
})

--====================================================
-- Tab19 : 特效通知循环
--====================================================
local PlayEquipAnimEvent = ReplicatedStorage:FindFirstChild("PlayEquipAnim")
local NotificationEvent   = Events and Events:FindFirstChild("Notification")

local BlasterTrinkets = ReplicatedStorage:FindFirstChild("BlasterTrinkets")
local brainStemTrinket = BlasterTrinkets and BlasterTrinkets:FindFirstChild("Charm_BrainStem")
local lightningMuzzle  = BlasterTrinkets and BlasterTrinkets:FindFirstChild("Muzzle_Lightning")

-- 每个循环使用独立线程变量，避免相互取消
local brainStemThread  = nil
local lightningThread  = nil
local notifyLoopThread = nil
local effectLoopThread19 = nil
local biomeLoopThread19  = nil

local function safeFireSignal(sig, ...)
    if not sig or not firesignal then return end
    pcall(firesignal, sig.OnClientEvent, ...)
end

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
        safeFireSignal(PlayEquipAnimEvent, brainStemTrinket)
    end,
})

Tab19:Toggle({
    Title = "循环播放 BrainStem动画",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if brainStemThread then
                task.cancel(brainStemThread)
                brainStemThread = nil
            end
            brainStemThread = task.spawn(function()
                while true do
                    safeFireSignal(PlayEquipAnimEvent, brainStemTrinket)
                    task.wait(0.5)
                end
            end)
        else
            if brainStemThread then
                task.cancel(brainStemThread)
                brainStemThread = nil
            end
        end
    end,
})

Tab19:Button({
    Title = "单次播放 Lightning动画",
    Desc = "",
    Callback = function()
        safeFireSignal(PlayEquipAnimEvent, lightningMuzzle)
    end,
})

Tab19:Toggle({
    Title = "循环播放 Lightning动画",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if lightningThread then
                task.cancel(lightningThread)
                lightningThread = nil
            end
            lightningThread = task.spawn(function()
                while true do
                    safeFireSignal(PlayEquipAnimEvent, lightningMuzzle)
                    task.wait(0.5)
                end
            end)
        else
            if lightningThread then
                task.cancel(lightningThread)
                lightningThread = nil
            end
        end
    end,
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
        safeFireSignal(NotificationEvent, "德与中山牛逼", "", "Default")
    end,
})

Tab19:Toggle({
    Title = "循环弹出 我爱你德与中山通知",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if notifyLoopThread then
                task.cancel(notifyLoopThread)
                notifyLoopThread = nil
            end
            notifyLoopThread = task.spawn(function()
                while true do
                    safeFireSignal(NotificationEvent, "我爱你德与中山", "", "Default")
                    task.wait(0.5)
                end
            end)
        else
            if notifyLoopThread then
                task.cancel(notifyLoopThread)
                notifyLoopThread = nil
            end
        end
    end,
})

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
                effectLoopThread19 = nil
            end
            effectLoopThread19 = task.spawn(function()
                while true do
                    pcall(function()
                        local ev = ReplicatedStorage:FindFirstChild("TrinketEffectTrigger")
                        if ev then
                            safeFireSignal(ev, "德与中山牛逼")
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
    end,
})

Tab19:Toggle({
    Title = "循环 屏幕下方出现德与中山",
    Desc = "",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if biomeLoopThread19 then
                task.cancel(biomeLoopThread19)
                biomeLoopThread19 = nil
            end
            biomeLoopThread19 = task.spawn(function()
                while true do
                    pcall(function()
                        local ev = Events and Events:FindFirstChild("BiomeAnimation")
                        if ev then
                            safeFireSignal(ev, "德与中山牛逼")
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
    end,
})

--====================================================
-- Tab29 : 主要（Ragebot + ESP）
--====================================================

-- ---------- Ragebot ----------
local ragebotEnabled   = false
local extendedSpread   = false   -- 对应原来的 TY5，默认关闭
local ragebotConn      = nil
local reloadCooldown   = 0
local lastReloadTime   = 0

local function findWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Tool") or (child:IsA("Model") and child:FindFirstChild("Remotes")) then
            local remotes = child:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Shoot") then
                return child
            end
        end
    end
    return nil
end

local function collectEnemies()
    local list = {}
    local function tryModel(model)
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(model) then
                local part = model:FindFirstChild("Head")
                    or model:FindFirstChild("HumanoidRootPart")
                    or model.PrimaryPart
                if part then
                    table.insert(list, { h = hum, p = part })
                end
            end
        end
    end

    local active = workspace:FindFirstChild("ActiveEnemies")
    if active then
        for _, d in pairs(active:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent then
                tryModel(d.Parent)
            end
        end
    end

    for _, c in pairs(workspace:GetChildren()) do
        if c:IsA("Model") and (c.Name:find("Boss") or c:FindFirstChild("Humanoid")) then
            tryModel(c)
        end
    end

    return list
end

local function getOffsets_Algo1(target)
    local base = target.p.Position
    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(0, 1, 0),
        Vector3.new(0, -1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0.5, 1),
        Vector3.new(0, -0.5, -1),
    }
    local out = {}
    for _, o in ipairs(offsets) do
        table.insert(out, base + o)
    end
    return out
end

local function getOffsets_Algo2(target, radius)
    local base = target.p.Position
    local out = {}
    local count = 6
    local t = os.clock() * 3
    for i = 0, count - 1 do
        local ang = (i / count) * math.pi * 2 + t
        local dir = Vector3.new(math.cos(ang), math.sin(ang), math.sin(ang * 2))
        table.insert(out, base + dir * (radius or 1.5))
    end
    return out
end

local function startRagebot()
    if ragebotConn then return end
    ragebotConn = RunService.RenderStepped:Connect(function()
        if not ragebotEnabled then return end

        local weapon = findWeapon()
        if not weapon then return end

        local shootRemote  = weapon.Remotes:FindFirstChild("Shoot")
        local reloadRemote = weapon.Remotes:FindFirstChild("Reload")

        -- 装弹节流：最多每 1 秒触发一次
        local now = os.clock()
        if reloadRemote and (now - lastReloadTime) >= 1.0 then
            lastReloadTime = now
            task.spawn(function()
                pcall(function()
                    reloadRemote:InvokeServer()
                end)
            end)
        end

        if not shootRemote then return end

        local enemies = collectEnemies()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
        local myPos  = myRoot and myRoot.Position
        if not myPos then return end

        for _, target in pairs(enemies) do
            task.spawn(function()
                pcall(function()
                    local args = { ["1"] = target.h }

                    if extendedSpread then
                        local positions = {}
                        for _, p in ipairs(getOffsets_Algo1(target)) do
                            table.insert(positions, p)
                        end
                        for _, p in ipairs(getOffsets_Algo2(target)) do
                            table.insert(positions, p)
                        end
                        for _, p in ipairs(positions) do
                            local cf = CFrame.new(myPos, p)
                            shootRemote:FireServer(workspace:GetServerTimeNow(), cf, args)
                        end
                    else
                        local cf = CFrame.new(myPos, target.p.Position)
                        shootRemote:FireServer(workspace:GetServerTimeNow(), cf, args)
                    end
                end)
            end)
        end
    end)
end

local function stopRagebot()
    ragebotEnabled = false
    if ragebotConn then
        ragebotConn:Disconnect()
        ragebotConn = nil
    end
end

-- ---------- ESP ----------
local enemyESPEnabled = false
local espConn         = nil
local espHighlights   = {}
local trackedEnemies  = {}

local ESPConfig = {
    HighlightColor     = Color3.fromRGB(255, 0, 0),
    OutlineColor       = Color3.fromRGB(255, 255, 255),
    FillTransparency   = 0.75,
    OutlineTransparency = 0,
    DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop,
}

local function addHighlight(model)
    if espHighlights[model] then return end
    local hl = Instance.new("Highlight")
    hl.Name                = "EnemyESP"
    hl.FillColor           = ESPConfig.HighlightColor
    hl.OutlineColor        = ESPConfig.OutlineColor
    hl.FillTransparency    = ESPConfig.FillTransparency
    hl.OutlineTransparency = ESPConfig.OutlineTransparency
    hl.DepthMode           = ESPConfig.DepthMode
    hl.Adornee             = model
    hl.Parent              = model
    espHighlights[model]   = hl
    trackedEnemies[model]  = true
end

local function removeHighlight(model)
    if espHighlights[model] then
        espHighlights[model]:Destroy()
        espHighlights[model] = nil
    end
    trackedEnemies[model] = nil
end

local function clearAllHighlights()
    for model, hl in pairs(espHighlights) do
        if hl then hl:Destroy() end
        espHighlights[model] = nil
    end
    table.clear(trackedEnemies)
end

local function startESP()
    if espConn then return end
    espConn = RunService.RenderStepped:Connect(function()
        if not enemyESPEnabled then return end

        local current = {}
        for _, model in ipairs(collectEnemiesModels()) do
            current[model] = true
            addHighlight(model)
        end

        for model, _ in pairs(trackedEnemies) do
            if not current[model] or not model.Parent then
                removeHighlight(model)
            end
        end
    end)
end

local function stopESP()
    enemyESPEnabled = false
    clearAllHighlights()
    if espConn then
        espConn:Disconnect()
        espConn = nil
    end
end

-- ESP 用模型集合（与 Ragebot 的 collectEnemies 区分开，避免重复包 Humanoid）
function collectEnemiesModels()
    local models = {}
    local seen = {}
    local function tryModel(model)
        if seen[model] then return end
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(model) then
                seen[model] = true
                table.insert(models, model)
            end
        end
    end

    local active = workspace:FindFirstChild("ActiveEnemies")
    if active then
        for _, d in pairs(active:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent then
                tryModel(d.Parent)
            end
        end
    end

    for _, c in pairs(workspace:GetChildren()) do
        if c:IsA("Model") and (c.Name:find("Boss") or c:FindFirstChild("Humanoid")) then
            tryModel(c)
        end
    end

    return models
end
--====================================================
-- 通用功能 : 移速调整
--====================================================
local Tab20 = Window:Tab({
    Title = "通用功能",
    Icon = "settings",
    Border = true,
})

Tab20:Section({
    Title = "移动速度",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

-- Roblox 祖传默认值就是 16，写死别问
local DEFAULT_SPEED = 16
local speedValue    = DEFAULT_SPEED
local speedEnabled  = false

local function getHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function applySpeed()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = speedEnabled and speedValue or DEFAULT_SPEED
end

-- 重生后 Humanoid 是新的，旧的那个已经成灰了，得重新套一遍
-- 不加判断直接 wait 0.3，是因为 CharacterAdded 触发时 Humanoid 有时还没挂上
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    applySpeed()
end)

-- 拖动的时候别每帧都写 WalkSpeed，会跟物理系统打架
-- 攒一下，50ms 写一次就够了，肉眼根本看不出延迟
local sliderPending = false
local function onSliderChange(val)
    speedValue = val
    if sliderPending then return end
    sliderPending = true
    task.delay(0.05, function()
        sliderPending = false
        if speedEnabled then
            applySpeed()
        end
    end)
end

Tab20:Slider({
    Title = "移速数值",
    Desc = "默认 16，30 以内相对安全；超过 100 服务端大概率把你弹回来",
    Value = {
        Min     = 8,
        Max     = 200,
        Default = 16,
    },
    -- 步进：整数就够，滑到小数点后面也没意义
    Step = 1,
    Callback = onSliderChange,
})

Tab20:Toggle({
    Title = "启用移速修改",
    Desc = "",
    Value = false,
    Callback = function(on)
        speedEnabled = on
        applySpeed()
    end,
})

Tab20:Button({
    Title = "重置为默认",
    Desc = "恢复成 16",
    Callback = function()
        speedEnabled = false
        speedValue   = DEFAULT_SPEED
        applySpeed()
    end,
})
-- ---------- Tab29 UI ----------
local Tab29 = Window:Tab({
    Title = "主要",
    Icon = "crosshair",
    Border = true,
})

Tab29:Section({
    Title = "自动射击",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab29:Toggle({
    Title = "启用 Ragebot",
    Desc = "无限弹药",
    Value = false,
    Callback = function(state)
        ragebotEnabled = state
        if state then
            startRagebot()
        else
            stopRagebot()
        end
    end,
})

-- 新增开关控制扩展弹道（原来 TY5 的死代码，现在可用）
Tab29:Toggle({
    Title = "扩展弹道（多发）",
    Desc = "开启后会朝多个角度开火，风险更高",
    Value = false,
    Callback = function(state)
        extendedSpread = state
    end,
})

Tab29:Section({
    Title = "怪物透视",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab29:Toggle({
    Title = "启用怪物 ESP",
    Desc = "高亮显示所有怪物",
    Value = false,
    Callback = function(state)
        enemyESPEnabled = state
        if state then
            startESP()
        else
            stopESP()
        end
    end,
})
