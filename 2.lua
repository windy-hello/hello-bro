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
if not LocalPlayer then--========== 依赖加载 ==========
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
--====================================================
-- 通用功能 : 环绕跟随
--====================================================
local ORBIT_RADIUS   = 8     -- 离目标多远
local ORBIT_HEIGHT   = 3     -- 相对目标根部的高度偏移
local ORBIT_SPEED    = 2     -- 每秒转多少弧度（2π ≈ 6.28 是一圈）
local TARGET_RECHECK = 0.5   -- 每多少秒重选一次最近玩家

local orbitOn       = false
local orbitConn     = nil
local orbitTarget   = nil
local orbitAngle    = 0
local lastCheckTick = 0

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function findNearestPlayer()
    local myRoot = getRoot(LocalPlayer.Character)
    if not myRoot then return nil end
    local myPos = myRoot.Position

    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local root = getRoot(char)
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local d = (root.Position - myPos).Magnitude
                if d < bestDist then
                    best, bestDist = plr, d
                end
            end
        end
    end
    return best
end

local function isTargetValid(plr)
    if not plr or not plr.Parent then return false end
    local char = plr.Character
    local root = getRoot(char)
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    return root and hum and hum.Health > 0
end

local function startOrbit()
    if orbitConn then return end
    lastCheckTick = 0
    orbitAngle = 0

    orbitConn = RunService.Heartbeat:Connect(function(dt)
        if not orbitOn then return end

        local myChar = LocalPlayer.Character
        local myRoot = getRoot(myChar)
        local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not (myRoot and myHum and myHum.Health > 0) then return end

        -- 定期重选，不然两个玩家距离接近时每帧来回切目标会抖
        lastCheckTick = lastCheckTick + dt
        if lastCheckTick >= TARGET_RECHECK or not isTargetValid(orbitTarget) then
            lastCheckTick = 0
            if not isTargetValid(orbitTarget) then
                orbitTarget = findNearestPlayer()
            end
        end

        local tgtChar = orbitTarget and orbitTarget.Character
        local tgtRoot = getRoot(tgtChar)
        local tgtHum  = tgtChar and tgtChar:FindFirstChildOfClass("Humanoid")
        if not (tgtRoot and tgtHum and tgtHum.Health > 0) then return end

        orbitAngle = orbitAngle + ORBIT_SPEED * dt

        local center = tgtRoot.Position + Vector3.new(0, ORBIT_HEIGHT, 0)
        local offset = Vector3.new(
            math.cos(orbitAngle) * ORBIT_RADIUS,
            0,
            math.sin(orbitAngle) * ORBIT_RADIUS
        )
        local newPos = center + offset

        -- lookAt 让角色面朝圆心，视觉上像在围观
        myRoot.CFrame = CFrame.lookAt(newPos, center)
    end)
end

local function stopOrbit()
    orbitOn = false
    if orbitConn then
        orbitConn:Disconnect()
        orbitConn = nil
    end
    orbitTarget = nil
end

-- ---------- UI ----------
Tab20:Section({
    Title = "环绕跟随",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab20:Slider({
    Title = "环绕半径",
    Desc = "离目标多少 studs，太小贴脸，太大跑出视野",
    Value = { Min = 2, Max = 30, Default = 8 },
    Step = 1,
    Callback = function(v) ORBIT_RADIUS = v end,
})

Tab20:Slider({
    Title = "环绕速度",
    Desc = "每秒转多少弧度，6.28 约等于一秒一圈",
    Value = { Min = 0.5, Max = 12, Default = 2 },
    Step = 0.1,
    Callback = function(v) ORBIT_SPEED = v end,
})

Tab20:Slider({
    Title = "高度偏移",
    Desc = "相对目标根部，负数会沉到地面以下",
    Value = { Min = -5, Max = 15, Default = 3 },
    Step = 1,
    Callback = function(v) ORBIT_HEIGHT = v end,
})

Tab20:Toggle({
    Title = "开始环绕",
    Desc = "自动传送到最近玩家身边绕圈，暂停后角色自然落地",
    Value = false,
    Callback = function(on)
        orbitOn = on
        if on then
            startOrbit()
        else
            stopOrbit()
        end
    end,
})

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
