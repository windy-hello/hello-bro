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
        Max     = 999,
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
        Max     = 999,
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
    Title = "环绕传送",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
    Opened = true,
})

Tab20:Slider({
    Title = "环绕半径",
    Desc = "",
    Value = { Min = 2, Max = 99, Default = 8 },
    Step = 1,
    Callback = function(v) ORBIT_RADIUS = v end,
})

Tab20:Slider({
    Title = "环绕速度",
    Desc = "",
    Value = { Min = 0.5, Max = 99, Default = 2 },
    Step = 0.1,
    Callback = function(v) ORBIT_SPEED = v end,
})

Tab20:Slider({
    Title = "高度偏移",
    Desc = "",
    Value = { Min = -5, Max = 15, Default = 3 },
    Step = 1,
    Callback = function(v) ORBIT_HEIGHT = v end,
})

Tab20:Toggle({
    Title = "开始环绕",
    Desc = "",
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
Tab20:Toggle({
})
-- =================== 甩飞核心 ===================
local function SkidFling(TargetPlayer)

    if not TargetPlayer or TargetPlayer == LocalPlayer then return end
    if Flinging then return end
    Flinging = true

    local Player = LocalPlayer
    local Character = Player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    if not (Character and Humanoid and RootPart and TCharacter) then
        Flinging = false
        return
    end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    local Camera = workspace.CurrentCamera

    local Dead = false
    local DeadConn
    DeadConn = Player.CharacterAdded:Connect(function()
        Dead = true
        if DeadConn then
            DeadConn:Disconnect()
            DeadConn = nil
        end
    end)

    if RootPart and RootPart.Parent and RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end

    if Camera then
        if THead then
            Camera.CameraSubject = THead
        elseif Handle then
            Camera.CameraSubject = Handle
        elseif THumanoid then
            Camera.CameraSubject = THumanoid
        end
    end

    local function FPos(BasePart, Pos, Ang)
        if Dead then return end
        local curChar = Player.Character
        local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
        local curRoot = curHum and curHum.RootPart
        if not curChar or not curHum or not curRoot then return end
        if not curRoot.Parent then return end
        if not BasePart or not BasePart.Parent then return end

        local targetCF = CFrame.new(BasePart.Position) * Pos * Ang

        pcall(function()
            curRoot.CFrame = targetCF
            curChar:SetPrimaryPartCFrame(targetCF)
            curRoot.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            curRoot.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end)
    end

    local function SFBasePart(BasePart)

        local TimeToWait = 2
        local Time = tick()
        local Angle = 0

        repeat
            if Dead then break end
            if not BasePart or not BasePart.Parent then break end

            local curChar = Player.Character
            local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
            local curRoot = curHum and curHum.RootPart
            if not curChar or not curHum or not curRoot then break end

            if not TRootPart or not TRootPart.Parent then break end
            if not THumanoid or THumanoid.Health <= 0 then break end

            if BasePart.Velocity.Magnitude > 1 then

                Angle = Angle + 100

                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()

            else

                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
                task.wait()

                FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
            end

        until BasePart.Velocity.Magnitude > 500
            or not BasePart.Parent
            or Dead
            or tick() > Time + TimeToWait
    end

    local BV = nil
    if not Dead and RootPart and RootPart.Parent then
        pcall(function()
            BV = Instance.new("BodyVelocity")
            BV.Parent = RootPart
            BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
            BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        end)
    end

    pcall(function()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    end)

    if not Dead then
        if TRootPart and TRootPart.Parent then
            SFBasePart(TRootPart)
        elseif THead and THead.Parent then
            SFBasePart(THead)
        elseif Handle and Handle.Parent then
            SFBasePart(Handle)
        end
    end

    if BV then
        pcall(function() BV:Destroy() end)
        BV = nil
    end

    local postChar = Player.Character
    local postHum = postChar and postChar:FindFirstChildOfClass("Humanoid")
    if postHum then
        pcall(function()
            postHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        end)
    else
        pcall(function()
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        end)
    end

    if Camera then
        local newChar = Player.Character
        local newHum = newChar and newChar:FindFirstChildOfClass("Humanoid")
        if newHum then
            Camera.CameraSubject = newHum
        end
    end

    if not Dead and getgenv().OldPos then
        local newChar = Player.Character
        local newRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
        local newHum = newChar and newChar:FindFirstChildOfClass("Humanoid")

        if newRoot and newHum and newHum.Health > 0 then
            local brakeCount = 0
            repeat
                brakeCount = brakeCount + 1
                newChar = Player.Character
                newRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
                newHum = newChar and newChar:FindFirstChildOfClass("Humanoid")

                if not newRoot or not newHum or newHum.Health <= 0 then break end

                pcall(function()
                    newRoot.CFrame = getgenv().OldPos * CFrame.new(0, 0.5, 0)
                    newChar:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, 0.5, 0))
                    newHum:ChangeState("GettingUp")

                    for _, x in ipairs(newChar:GetChildren()) do
                        if x:IsA("BasePart") then
                            x.Velocity = Vector3.zero
                            x.RotVelocity = Vector3.zero
                        end
                    end
                end)

                task.wait()
            until (newRoot and (newRoot.Position - getgenv().OldPos.Position).Magnitude < 25)
                or brakeCount > 60
                or not newRoot
        end
    end

    if DeadConn then
        DeadConn:Disconnect()
        DeadConn = nil
    end

    Flinging = false
end

-- =================== 目标监控 ===================
local function MonitorTarget(target)

    if not target then return end

    if not (TP_Loop or FlingLoop or Flinging) then
        return
    end

    if not AlreadyNotified[target] then
        AlreadyNotified[target] = {
            dead = false,
            left = false
        }
    end

    local state = AlreadyNotified[target]

    task.spawn(function()

        while true do

            if not (TP_Loop or FlingLoop or Flinging) then
                break
            end

            if not target or not target.Parent then

                if not state.left then
                    state.left = true

                    local msg = "玩家已退出，操作已终止"

                    if TP_Loop then
                        msg = "目标退出，无法继续传送"
                    elseif FlingLoop or Flinging then
                        msg = "目标退出，无法继续甩飞"
                    end

                    Notify("目标失效", msg, 3)
                end

                break
            end

            local char = target.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not char or not hum or hum.Health <= 0 then

                if not state.dead then
                    state.dead = true

                    local msg = target.Name .. " 已死亡或消失"

                    if TP_Loop then
                        msg = target.Name .. " 已死亡或不存在，无法继续传送"
                    elseif FlingLoop or Flinging then
                        msg = target.Name .. " 已死亡或不存在，无法继续甩飞"
                    end

                    Notify("目标失效", msg, 3)
                end

                repeat
                    task.wait(0.5)
                    char = target.Character
                    hum = char and char:FindFirstChildOfClass("Humanoid")
                until (hum and hum.Health > 0) or not target.Parent

                if hum and hum.Health > 0 then
                    state.dead = false
                end
            end

            task.wait(0.5)
        end

    end)
end

-- =================== 循环甩飞 ===================
local function StartFlingLoop()

    if FlingLoop then return end
    FlingLoop = true
    AlreadyNotified = {}

    task.spawn(function()

        while FlingLoop do

            local selfChar = LocalPlayer.Character
            local selfHum = selfChar and selfChar:FindFirstChildOfClass("Humanoid")
            local selfRoot = selfChar and selfChar:FindFirstChild("HumanoidRootPart")

            if not selfChar or not selfHum or not selfRoot or selfHum.Health <= 0 then
                task.wait(0.5)
                continue
            end

            -- ================= 所有人模式 =================
            if TP_SelectedPlayer == "ALL" then

                for _, p in ipairs(Players:GetPlayers()) do
                    if not FlingLoop then break end

                    local c = LocalPlayer.Character
                    local h = c and c:FindFirstChildOfClass("Humanoid")
                    if not c or not h or h.Health <= 0 then break end

                    if p ~= LocalPlayer then

                        local char = p.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")

                        if hum and hum.Health > 0 then

                            if not AlreadyNotified[p] then
                                MonitorTarget(p)
                            end

                            local t1 = tick()
                            repeat task.wait() until not Flinging or tick() - t1 > 3

                            -- ⭐ 修复：等待结束后确认玩家仍存活再甩
                            local pChar = p.Character
                            local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
                            if pHum and pHum.Health > 0 then
                                SkidFling(p)
                            end

                            local t2 = tick()
                            repeat task.wait() until not Flinging or tick() - t2 > 3

                            task.wait(0.1)
                        end
                    end
                end
