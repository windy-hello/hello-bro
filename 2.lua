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
    Title = "德与中山(免费版)",
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
    Title = "修改移速",
    Desc = "默认 16",
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
    Title = "修改移速",
    Desc = "",
    Value = false,
    Callback = function(on)
        speedEnabled = on
        applySpeed()
    end,
})

Tab20:Button({
    Title = "重置",
    Desc = "默认 16",
    Callback = function()
        speedEnabled = false
        speedValue   = DEFAULT_SPEED
        applySpeed()
    end,
})
--====================================================
-- 通用功能 : 跳跃
--====================================================
local DEFAULT_JUMP_POWER = 50

local jumpHeightValue = DEFAULT_JUMP_POWER
local jumpHeightOn    = false
local holdJumpOn      = false

-- 三个来源分开记账，任一为 true 就算按着
local jumpHeldKey   = false   -- PC 键盘空格
local jumpHeldTouch = false   -- 移动端触摸跳跃按钮
local jumpHeldHum   = false   -- Humanoid.Jump 属性（两端通用）

local holdConn  = nil
local currentLV = nil
local currentAtt = nil

local JUMP_LIFT_SPEED = 50

local function getHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- ---------- 跳跃高度 ----------
local function applyJumpHeight()
    local hum = getHum()
    if not hum then return end
    hum.UseJumpPower = true
    hum.JumpPower = jumpHeightOn and jumpHeightValue or DEFAULT_JUMP_POWER
end

-- ---------- 输入检测 ----------
local UIS = game:GetService("UserInputService")

-- 移动端跳跃按钮：不挂事件（会被 Roblox 内部吞掉），改成坐标判断
local jumpBtnRef  = nil
local activeTouch = nil   -- 追踪当前按住跳跃按钮的那根手指

local function getJumpBtn()
    if jumpBtnRef and jumpBtnRef.Parent then return jumpBtnRef end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    -- 不同 Roblox 版本容器名不同，都试一遍
    for _, name in ipairs({ "TouchGui", "TouchControlFrame", "TouchGui" }) do
        local tg = pg:FindFirstChild(name)
        if tg then
            local btn = tg:FindFirstChild("JumpButton", true)
            if btn and btn:IsA("GuiButton") then
                jumpBtnRef = btn
                return btn
            end
        end
    end
    return nil
end

-- 触摸点是否落在按钮矩形里
local function isOnJumpBtn(pos)
    local btn = getJumpBtn()
    if not btn or not btn.Visible then return false end
    local ap = btn.AbsolutePosition
    local as = btn.AbsoluteSize
    return pos.X >= ap.X and pos.X <= ap.X + as.X
       and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
end

UIS.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.Touch then
        -- 注意：不要因为 gpe=true 就跳过。点跳跃按钮时 gpe 一定是 true
        if isOnJumpBtn(input.Position) then
            jumpHeldTouch = true
            activeTouch = input
        end
    elseif input.KeyCode == Enum.KeyCode.Space then
        jumpHeldKey = true
    end
end)

UIS.InputEnded:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.Touch then
        if input == activeTouch then
            jumpHeldTouch = false
            activeTouch = nil
        end
    elseif input.KeyCode == Enum.KeyCode.Space then
        jumpHeldKey = false
    end
end)



-- Humanoid.Jump 属性：无论 PC 还是移动端，按跳跃时都会置 true
-- 是 Roblox 跨平台最稳的接口
local function bindHumJump(hum)
    if not hum then return end
    hum:GetPropertyChangedSignal("Jump"):Connect(function()
        jumpHeldHum = hum.Jump
    end)
end

local function onCharacter(char)
    task.wait(0.3)
    if not char or not char.Parent then return end
    applyJumpHeight()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        bindHumJump(hum)
    end
end

if LocalPlayer.Character then
    onCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)

-- 综合判定：任一路径为真即算按着
local function isJumpHeld()
    if jumpHeldKey or jumpHeldTouch or jumpHeldHum then
        return true
    end

    -- 兜底 1：直接读键盘状态
    local ok, down = pcall(function()
        return UIS:IsKeyDown(Enum.KeyCode.Space)
    end)
    if ok and down then return true end

    -- 兜底 2：直接读 Humanoid.Jump
    local hum = getHum()
    if hum and hum.Jump then return true end

    return false
end


local function destroyLift()
    if currentLV then
        pcall(function() currentLV:Destroy() end)
        currentLV = nil
    end
    if currentAtt then
        pcall(function() currentAtt:Destroy() end)
        currentAtt = nil
    end
end

local function ensureLift(root)
    if currentLV and currentLV.Parent == root then return end
    destroyLift()

    currentAtt = Instance.new("Attachment")
    currentAtt.Name = "HoldJumpAttach"
    currentAtt.Parent = root

    currentLV = Instance.new("LinearVelocity")
    currentLV.Attachment0 = currentAtt
    currentLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    currentLV.VectorVelocity = Vector3.new(0, JUMP_LIFT_SPEED, 0)
    currentLV.MaxForce = math.huge
    -- 只在 Y 轴出力，水平移动不受影响
    currentLV.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    currentLV.MaxAxesForce = Vector3.new(0, math.huge, 0)
    currentLV.RelativeTo = Enum.ActuatorRelativeTo.World
    currentLV.Parent = root
end

local function startHoldJump()
    if holdConn then return end
    holdConn = RunService.Heartbeat:Connect(function()
        if not holdJumpOn then return end

        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if not (hum and root and hum.Health > 0) then
            destroyLift()
            return
        end

        if isJumpHeld() then
            ensureLift(root)
        else
            destroyLift()
        end
    end)
end

local function stopHoldJump()
    if holdConn then
        holdConn:Disconnect()
        holdConn = nil
    end
    destroyLift()
end

-- ---------- UI ----------
Tab20:Section({
    Title = "跳跃",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

local jumpSliderPending = false
Tab20:Slider({
    Title = "跳跃高度",
    Desc = "",
    Value = {
        Min     = 0,
        Max     = 999,
        Default = 50,
    },
    Step = 1,
    Callback = function(val)
        jumpHeightValue = val
        if jumpSliderPending then return end
        jumpSliderPending = true
        task.delay(0.05, function()
            jumpSliderPending = false
            if jumpHeightOn then
                applyJumpHeight()
            end
        end)
    end,
})

Tab20:Toggle({
    Title = "启用跳跃高度修改",
    Desc = "",
    Value = false,
    Callback = function(on)
        jumpHeightOn = on
        applyJumpHeight()
    end,
})

Tab20:Toggle({
    Title = "无限跳跃",
    Desc = "",
    Value = false,
    Callback = function(on)
        holdJumpOn = on
        if on then
            startHoldJump()
        else
            stopHoldJump()
        end
    end,
})

Tab20:Button({
    Title = "重置跳跃功能",
    Desc = "",
    Callback = function()
        jumpHeightOn = false
        jumpHeightValue = DEFAULT_JUMP_POWER
        holdJumpOn = false
        stopHoldJump()
        applyJumpHeight()
    end,
})
--====================================================
-- 通用功能 : 飞行
--====================================================
local FLY_SPEED = 60

local flyOn   = false
local flyConn = nil
local flyLV   = nil
local flyAtt  = nil

local function destroyFlyRig()
    if flyLV then pcall(function() flyLV:Destroy() end) flyLV = nil end
    if flyAtt then pcall(function() flyAtt:Destroy() end) flyAtt = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

local function ensureFlyRig(root, hum)
    if flyLV and flyLV.Parent == root then return end
    destroyFlyRig()

    -- PlatformStand 让角色脱离重力和地面判定，不然一松手就往下掉
    hum.PlatformStand = true

    flyAtt = Instance.new("Attachment")
    flyAtt.Name = "FlyAttach"
    flyAtt.Parent = root

    flyLV = Instance.new("LinearVelocity")
    flyLV.Attachment0 = flyAtt
    flyLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    flyLV.VectorVelocity = Vector3.zero
    flyLV.MaxForce = math.huge
    flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
    flyLV.Parent = root
end

local function startFly()
    if flyConn then return end
    flyConn = RunService.Heartbeat:Connect(function()
        if not flyOn then return end

        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and root and hum.Health > 0) then return end

        ensureFlyRig(root, hum)

        -- MoveDirection 是引擎根据 WASD 或移动端摇杆算出来的
        -- 相机相对、世界坐标、单位向量。直接乘速度就是水平移动
        local move = hum.MoveDirection * FLY_SPEED

        -- 上升：PC 空格，移动端跳跃按钮按住
        if UIS:IsKeyDown(Enum.KeyCode.Space) or jumpHeldTouch or jumpHeldHum then
            move = move + Vector3.new(0, FLY_SPEED, 0)
        end

        -- 下降：PC 左 Shift。移动端暂时没对应按钮，靠视角下压 + 前进键凑合
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, FLY_SPEED, 0)
        end

        flyLV.VectorVelocity = move
    end)
end

local function stopFly()
    flyOn = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    destroyFlyRig()
end

-- ---------- UI ----------
Tab20:Section({
    Title = "飞行",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

local flySliderPending = false
Tab20:Slider({
    Title = "飞行速度",
    Desc = "默认 60",
    Value = {
        Min     = 10,
        Max     = 300,
        Default = 60,
    },
    Step = 1,
    Callback = function(val)
        FLY_SPEED = val
    end,
})
-- ---------- 移动端：飞行下降按钮 ----------
local flyDownHeld = false
local flyDownGui  = nil

-- 把按钮位置同步到跳跃按钮左侧
local function positionFlyDownBtn()
    if not flyDownGui then return end
    local btn = flyDownGui:FindFirstChild("FlyDownBtn")
    if not btn then return end

    local jb = getJumpBtn()
    if jb and jb.Visible then
        local jp = jb.AbsolutePosition
        local js = jb.AbsoluteSize
        local bs = btn.AbsoluteSize
        -- 跳跃按钮左边，垂直居中
        btn.Position = UDim2.fromOffset(
            jp.X - bs.X - 16,
            jp.Y + (js.Y - bs.Y) / 2
        )
    else
        -- 找不到跳跃按钮时退回右下角
        btn.Position = UDim2.new(1, -200, 1, -120)
    end
end

local function showFlyDownBtn()
    if flyDownGui then return end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "FlyDownBtnGui"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = pg

    local btn = Instance.new("TextButton")
    btn.Name = "FlyDownBtn"
    btn.Size = UDim2.fromOffset(72, 72)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.BackgroundTransparency = 0.25
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "↓"
    btn.TextSize = 40
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = sg

    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.4
    stroke.Parent = btn

    -- 用按钮自己的事件。之前那些"事件被吞"是针对 Roblox 默认 UI 的问题
    -- 自己创建的 GuiButton 事件是可靠的
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            flyDownHeld = true
            btn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            flyDownHeld = false
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)

    flyDownGui = sg
    positionFlyDownBtn()
end

local function hideFlyDownBtn()
    if flyDownGui then
        flyDownGui:Destroy()
        flyDownGui = nil
    end
    flyDownHeld = false
end

-- ---------- 飞行主逻辑（替换原 startFly） ----------
local function startFly()
    if flyConn then return end

    -- 移动端才显示下降按钮。PC 上 Shift 就够用
    if UIS.TouchEnabled then
        showFlyDownBtn()
    end

    local posTick = 0
    flyConn = RunService.Heartbeat:Connect(function()
        if not flyOn then return end

        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and root and hum.Health > 0) then return end

        ensureFlyRig(root, hum)

        local move = hum.MoveDirection * FLY_SPEED

        -- 上升：PC 空格 + 移动端跳跃按钮 + Humanoid.Jump 兜底
        if UIS:IsKeyDown(Enum.KeyCode.Space) or jumpHeldTouch or jumpHeldHum then
            move = move + Vector3.new(0, FLY_SPEED, 0)
        end

        -- 下降：PC 左 Shift + 移动端自定义按钮
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or flyDownHeld then
            move = move - Vector3.new(0, FLY_SPEED, 0)
        end

        flyLV.VectorVelocity = move

        -- 每 10 帧同步一次按钮位置，跳跃按钮横竖屏时会挪位置
        posTick = posTick + 1
        if posTick >= 10 then
            posTick = 0
            positionFlyDownBtn()
        end
    end)
end

local function stopFly()
    flyOn = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    destroyFlyRig()
    hideFlyDownBtn()   -- 关闭飞行时销毁按钮
end
Tab20:Toggle({
    Title = "开启飞行",
    Desc = "",
    Value = false,
    Callback = function(on)
        flyOn = on
        if on then
            startFly()
        else
            stopFly()
        end
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
