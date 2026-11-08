--[[
  Movement Panel: Fly / Speed / Infinite Jump / Anti-Gravity / Fling /
                  Anti-Fling (Strengthened) / Stick-to-Player (Carry)
  - Client-only, tanpa loadstring/HttpGet.
  - LocalScript di StarterPlayer > StarterPlayerScripts.
  - Kontrol mobile: stick = arah, tombol UP/DOWN = naik/turun.
  - Kontrol PC: E = naik, Q = turun.
  Catatan: di game orang lain ini melanggar ToS Roblox. Risiko sendiri.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

---------------------------------------------------------------- STATE
local S = {
	fly = false, flySpeed = 60,
	speed = false, walkSpeed = 50,
	inf = false,
	anti = false, gravFactor = 0.15,
	fling = false,
	noFling = false,
	stick = false,
}
local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local flingObjs = {}
local stickObjs = {}
local stickTarget = nil
local stickTargetLbl = nil
local ANTI_FLING_MAX_VEL = 45
local ANTI_FLING_VIOLENT = 100
local FLING_RANGE = 15
local FLING_RADIUS = 14
local STICK_RANGE = 40

local function getHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function findNearestPlayer(maxDist)
	local myRoot = getRoot()
	if not myRoot then return nil end
	local pos = myRoot.Position
	local nearest, best = nil, maxDist
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= lp and p.Character then
			local r = p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - pos).Magnitude
				if d < best then nearest, best = p, d end
			end
		end
	end
	return nearest
end

---------------------------------------------------------------- FLY
local function stopFly()
	for _, o in pairs(flyObjs) do
		if o and o.Parent then o:Destroy() end
	end
	flyObjs = {}
	local hum = getHum()
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function startFly()
	stopFly()
	local root, hum = getRoot(), getHum()
	if not root or not hum then return false end

	local att = Instance.new("Attachment")
	att.Name = "MP_Att"
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = math.huge
	ao.Responsiveness = 40
	ao.Parent = root

	hum.PlatformStand = true
	flyObjs = { att = att, lv = lv, ao = ao }
	return true
end

RunService.RenderStepped:Connect(function()
	if not S.fly then return end
	local lv, ao = flyObjs.lv, flyObjs.ao
	if not (lv and lv.Parent and ao and ao.Parent) then return end

	local hum = getHum()
	local move = hum and hum.MoveDirection or Vector3.zero
	local lm = cam.CFrame:VectorToObjectSpace(move)
	local dir = cam.CFrame.LookVector * -lm.Z + cam.CFrame.RightVector * lm.X
	dir += Vector3.new(0, (upHeld and 1 or 0) - (downHeld and 1 or 0), 0)

	if dir.Magnitude > 0.05 then
		lv.VectorVelocity = dir.Unit * S.flySpeed
	else
		lv.VectorVelocity = Vector3.zero
	end

	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		ao.CFrame = CFrame.lookAt(Vector3.zero, flat)
	end
end)

---------------------------------------------------------------- FLING
local function stopFling()
	for _, o in pairs(flingObjs) do
		if o and o.Parent then o:Destroy() end
	end
	flingObjs = {}
end

local function startFling()
	stopFling()
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local spin = Instance.new("Part")
	spin.Name = "MP_Fling"
	spin.Size = Vector3.new(FLING_RADIUS, FLING_RADIUS, FLING_RADIUS)
	spin.Transparency = 1
	spin.CanCollide = true
	spin.CanQuery = false
	spin.CanTouch = true
	spin.Massless = false
	spin.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.3, 1, 1)
	spin.CFrame = root.CFrame
	spin.Parent = char

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = spin
	weld.Parent = spin

	local av = Instance.new("BodyAngularVelocity")
	av.AngularVelocity = Vector3.new(15000, 15000, 15000)
	av.MaxTorque = math.huge
	av.Parent = spin

	flingObjs = { spin = spin, weld = weld, av = av }
	return true
end

RunService.Heartbeat:Connect(function()
	if not S.fling then return end
	local root = getRoot()
	if not root then return end
	local target = findNearestPlayer(FLING_RANGE * 3)
	if target and target.Character then
		local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
		if tRoot and (tRoot.Position - root.Position).Magnitude > FLING_RANGE then
			local dir = (tRoot.Position - root.Position).Unit
			root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + dir * 5
		end
	end
end)

---------------------------------------------------------------- STICK (Carry / Nempel)
local function stopStick()
	for _, o in pairs(stickObjs) do
		if o and o.Parent then o:Destroy() end
	end
	stickObjs = {}
	stickTarget = nil
	if stickTargetLbl then stickTargetLbl.Text = "Target: —" end
	local hum = getHum()
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function startStick(targetPlayer)
	stopStick()
	local myRoot = getRoot()
	local hum = getHum()
	if not myRoot or not hum then return false end
	if not targetPlayer or not targetPlayer.Character then return false end
	local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not tRoot then return false end

	local att = Instance.new("Attachment")
	att.Name = "MP_StickAtt"
	att.Parent = myRoot

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = att
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Position = tRoot.Position
	ap.MaxForce = math.huge
	ap.Responsiveness = 200
	ap.ApplyAtCenterOfMass = true
	ap.Parent = myRoot

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.CFrame = tRoot.CFrame
	ao.MaxTorque = math.huge
	ao.Responsiveness = 200
	ao.Parent = myRoot

	hum.PlatformStand = true

	stickObjs = { att = att, ap = ap, ao = ao }
	stickTarget = targetPlayer
	if stickTargetLbl then
		stickTargetLbl.Text = "Target: " .. targetPlayer.Name
	end
	return true
end

---------------------------------------------------------------- ANTI-MENTAL (strengthened)
local function antiFlingTick()
	if not S.noFling or S.fly or S.stick or S.fling then return end
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = getHum()
	if not root or not hum then return end

	-- 1) Kill all foreign welds on our HRP (weld-based fling)
	for _, c in ipairs(root:GetChildren()) do
		if c:IsA("Weld") or c:IsA("WeldConstraint") then
			local other = (c.Part0 == root) and c.Part1 or c.Part0
			if other and not other:IsDescendantOf(char) then
				c:Destroy()
			end
		end
	end

	-- 2) Kill angular velocity (spin fling)
	local av = root.AssemblyAngularVelocity
	if av and av.Magnitude > 1 then
		pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
	end
	local rv = root.RotVelocity
	if rv and rv.Magnitude > 1 then
		pcall(function() root.RotVelocity = Vector3.zero end)
	end

	-- 3) Velocity control: violent → zero, moderate → clamp
	local lv = root.AssemblyLinearVelocity
	if lv then
		local mag = lv.Magnitude
		if mag > ANTI_FLING_VIOLENT then
			pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		elseif mag > ANTI_FLING_MAX_VEL then
			pcall(function() root.AssemblyLinearVelocity = lv.Unit * ANTI_FLING_MAX_VEL end)
		end
	end

	-- 4) Lock humanoid state (prevent PlatformStand / Ragdoll / Flying / FallingDown)
	if hum.PlatformStand then hum.PlatformStand = false end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Ragdoll
		or st == Enum.HumanoidStateType.FallingDown
		or st == Enum.HumanoidStateType.Flying
		or st == Enum.HumanoidStateType.PlatformStanding then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

---------------------------------------------------------------- MAIN LOOP
RunService.Heartbeat:Connect(function()
	-- Speed
	if S.speed and not S.fly then
		local hum = getHum()
		if hum then hum.WalkSpeed = S.walkSpeed end
	end

	-- Anti-Grav
	if S.anti then
		workspace.Gravity = DEFAULT_GRAVITY * S.gravFactor
	end

	-- Anti-Mental
	antiFlingTick()

	-- Stick: follow target, re-find if lost
	if S.stick then
		local alive = stickTarget
			and stickTarget.Parent
			and stickTarget.Character
			and stickTarget.Character:FindFirstChild("HumanoidRootPart")
			and stickTarget.Character:FindFirstChildOfClass("Humanoid")
			and stickTarget.Character:FindFirstChildOfClass("Humanoid").Health > 0

		if not alive then
			local newTarget = findNearestPlayer(STICK_RANGE)
			if newTarget then
				startStick(newTarget)
			else
				S.stick = false
				stopStick()
			end
		else
			local tRoot = stickTarget.Character.HumanoidRootPart
			if stickObjs.ap then
				stickObjs.ap.Position = tRoot.Position
				stickObjs.ao.CFrame = tRoot.CFrame
			end
		end
	end
end)

---------------------------------------------------------------- INFINITE JUMP
UIS.JumpRequest:Connect(function()
	if S.inf and not S.fly then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.E then upHeld = true
	elseif i.KeyCode == Enum.KeyCode.Q then downHeld = true end
end)
UIS.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.E then upHeld = false
	elseif i.KeyCode == Enum.KeyCode.Q then downHeld = false end
end)

---------------------------------------------------------------- GUI
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local gui = Instance.new("ScreenGui")
gui.Name = "MovementPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
local okParent = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okParent or not gui.Parent then
	gui.Parent = lp:WaitForChild("PlayerGui")
end

local BG = Color3.fromRGB(24, 26, 32)
local ON = Color3.fromRGB(48, 160, 100)
local OFF = Color3.fromRGB(52, 56, 66)
local ACCENT = Color3.fromRGB(120, 180, 255)
local TXT = Color3.fromRGB(235, 238, 245)
local MUTED = Color3.fromRGB(150, 155, 170)

local FRAME_W = 226
local FRAME_H = 468

local frame = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W, FRAME_H), Position = UDim2.new(0, 10, 0.14, 0),
	BackgroundColor3 = BG, BorderSizePixel = 0,
	Active = true, Draggable = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
mk("UIStroke", { Color = Color3.fromRGB(58, 62, 76), Thickness = 1, Transparency = 0.2 }, frame)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 37, 46)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 20, 26)),
	}),
	Rotation = 90,
}, frame)

-- Title bar
local title = mk("TextLabel", {
	Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(12, 4),
	BackgroundTransparency = 1, Text = "Movement Panel",
	TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local statusDot = mk("Frame", {
	Size = UDim2.fromOffset(9, 9), Position = UDim2.new(1, -66, 0, 13),
	BackgroundColor3 = Color3.fromRGB(90, 92, 105), BorderSizePixel = 0,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)

local miniBtn = mk("TextButton", {
	Size = UDim2.fromOffset(26, 24), Position = UDim2.new(1, -34, 0, 5),
	Text = "-", BackgroundColor3 = OFF, TextColor3 = TXT,
	Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 7) }, miniBtn)

-- Body
local body = mk("Frame", {
	Size = UDim2.new(1, -16, 1, -40), Position = UDim2.fromOffset(8, 34),
	BackgroundTransparency = 1,
}, frame)
mk("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

local minimized = false
miniBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	frame.Size = minimized and UDim2.fromOffset(FRAME_W, 34) or UDim2.fromOffset(FRAME_W, FRAME_H)
	miniBtn.Text = minimized and "+" or "-"
end)

local function updateStatusDot()
	local active = S.fly or S.speed or S.inf or S.anti or S.fling or S.noFling or S.stick
	statusDot.BackgroundColor3 = active and Color3.fromRGB(80, 220, 130) or Color3.fromRGB(90, 92, 105)
end

local function sectionHeader(order, text)
	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order,
		BackgroundTransparency = 1, Text = text,
		TextColor3 = ACCENT, Font = Enum.Font.GothamBold, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, body)
end

local function toggleRow(order, label, icon, key, onChange)
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order,
		BackgroundColor3 = OFF, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false,
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, b)

	mk("TextLabel", {
		Size = UDim2.fromOffset(22, 32), Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1, Text = icon,
		TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 15,
	}, b)

	mk("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1, Text = label,
		TextColor3 = TXT, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, b)

	local statusLbl = mk("TextLabel", {
		Size = UDim2.fromOffset(50, 32), Position = UDim2.new(1, -58, 0, 0),
		BackgroundTransparency = 1, Text = "OFF",
		TextColor3 = MUTED, Font = Enum.Font.GothamBold, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, b)

	local function refresh()
		statusLbl.Text = S[key] and "ON" or "OFF"
		statusLbl.TextColor3 = S[key] and Color3.fromRGB(140, 255, 175) or MUTED
		b.BackgroundColor3 = S[key] and ON or OFF
	end

	b.MouseEnter:Connect(function()
		local c = S[key] and ON or OFF
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = c:Lerp(Color3.new(1,1,1), 0.08) }):Play()
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = S[key] and ON or OFF
	end)

	b.MouseButton1Click:Connect(function()
		S[key] = not S[key]
		if onChange then onChange(S[key]) end
		refresh()
		updateStatusDot()
	end)

	refresh()
	return { button = b, refresh = refresh }
end

local function stepRow(order, label, get, set, step, min, max, fmt)
	local row = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order,
		BackgroundTransparency = 1,
	}, body)

	local function btn(txt, x)
		local b = mk("TextButton", {
			Size = UDim2.fromOffset(30, 24),
			Position = UDim2.new(x, x == 0 and 0 or -30, 0, 0),
			Text = txt, BackgroundColor3 = OFF, TextColor3 = TXT,
			Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false,
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		return b
	end
	local minus, plus = btn("-", 0), btn("+", 1)

	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, -74, 1, 0), Position = UDim2.fromOffset(38, 0),
		BackgroundTransparency = 1, TextColor3 = MUTED,
		Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local function refresh()
		lbl.Text = label .. "  " .. string.format(fmt, get())
	end
	minus.MouseButton1Click:Connect(function() set(math.clamp(get() - step, min, max)); refresh() end)
	plus.MouseButton1Click:Connect(function() set(math.clamp(get() + step, min, max)); refresh() end)
	refresh()
end

-- FLIGHT
sectionHeader(1, "FLIGHT")
local flyRow = toggleRow(2, "Fly", "✈", "fly", function(on)
	if on then
		if S.stick then S.stick = false; stopStick() end
		if not startFly() then S.fly = false end
	else
		stopFly()
		local hum = getHum()
		if hum and S.speed then hum.WalkSpeed = S.walkSpeed end
	end
end)
stepRow(3, "Speed", function() return S.flySpeed end, function(v) S.flySpeed = v end, 10, 10, 300, "%d")

-- MOVEMENT
sectionHeader(4, "MOVEMENT")
toggleRow(5, "Speed", "🏃", "speed", function(on)
	local hum = getHum()
	if not hum then return end
	if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
	else hum.WalkSpeed = origWalk end
end)
stepRow(6, "Walk", function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d")
toggleRow(7, "Infinite Jump", "⤒", "inf")
toggleRow(8, "Anti-Gravity", "☁", "anti", function(on)
	if not on then workspace.Gravity = DEFAULT_GRAVITY end
end)
stepRow(9, "Gravity", function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx")

-- COMBAT
sectionHeader(10, "COMBAT")
toggleRow(11, "Fling (Mental)", "✷", "fling", function(on)
	if on then
		if S.stick then S.stick = false; stopStick() end
		if not startFling() then S.fling = false end
	else
		stopFling()
	end
end)
toggleRow(12, "Anti-Mental", "🛡", "noFling", function(on)
	if not on then
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end
end)
toggleRow(13, "Stick to Player", "🔗", "stick", function(on)
	if on then
		if S.fly then S.fly = false; stopFly() end
		if S.fling then S.fling = false; stopFling() end
		local target = findNearestPlayer(STICK_RANGE)
		if target and startStick(target) then
			-- ok
		else
			S.stick = false
			if stickTargetLbl then stickTargetLbl.Text = "Target: — (none in range)" end
		end
	else
		stopStick()
	end
end)

stickTargetLbl = mk("TextLabel", {
	Size = UDim2.new(1, -8, 0, 16), LayoutOrder = 14,
	BackgroundTransparency = 1, Text = "Target: —",
	TextColor3 = MUTED, Font = Enum.Font.Gotham, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, body)
mk("UIPadding", { PaddingLeft = UDim.new(0, 6) }, stickTargetLbl)

-- Tombol naik/turun (muncul saat Fly ON)
local pad = mk("Frame", {
	Size = UDim2.fromOffset(64, 134), Position = UDim2.new(1, -78, 1, -160),
	BackgroundTransparency = 1, Visible = false,
}, gui)
local function holdBtn(txt, y, setter)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, y),
		Text = txt, BackgroundColor3 = BG, BackgroundTransparency = 0.15,
		TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 18,
		AutoButtonColor = false,
	}, pad)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	mk("UIStroke", { Color = Color3.fromRGB(60, 64, 78), Thickness = 1 }, b)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(true) end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(false) end
	end)
end
holdBtn("↑", 0, function(v) upHeld = v end)
holdBtn("↓", 70, function(v) downHeld = v end)

RunService.RenderStepped:Connect(function() pad.Visible = S.fly end)

updateStatusDot()

---------------------------------------------------------------- RESPAWN
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	origWalk = hum.WalkSpeed
	flyObjs = {}
	flingObjs = {}
	stickObjs = {}
	stickTarget = nil
	if stickTargetLbl then stickTargetLbl.Text = "Target: —" end

	if S.fly then
		task.wait(0.5)
		if S.fly then startFly() end
	end
	if S.fling then
		task.wait(0.5)
		if S.fling then startFling() end
	end
	if S.speed then hum.WalkSpeed = S.walkSpeed end
end
lp.CharacterAdded:Connect(onCharacter)
if lp.Character then task.spawn(onCharacter, lp.Character) end