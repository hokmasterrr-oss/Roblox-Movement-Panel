--[[
  Movement Panel: Fly / Speed / Infinite Jump / Anti-Gravity / Fling /
                  Anti-Fling / No Fall Damage
  - Satu file, tanpa loadstring/HttpGet, semua kodenya bisa kamu baca.
  - Pakai di game milikmu: LocalScript di StarterPlayer > StarterPlayerScripts.
  - Murni client-side (hanya mengubah karakter & gravitasi lokalmu).
  - Kontrol mobile: stick = arah (mengikuti arah kamera), tombol UP/DOWN = naik/turun.
  - Kontrol PC: E = naik, Q = turun.
  Catatan: di game orang lain, memakai ini melanggar ToS Roblox & bisa kena
  anti-cheat / ban. Itu risiko kamu sendiri.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

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
	noFall = false,
}
local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local flingObjs = {}
local hookedHum = nil
local lastFreefall = 0
local ANTI_FLING_MAX_VEL = 80

local function getHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
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

---------------------------------------------------------------- FLING / MENTALIN
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
	spin.Size = Vector3.new(8, 8, 8)
	spin.Transparency = 1
	spin.CanCollide = true
	spin.Massless = true
	spin.CanQuery = false
	spin.CanTouch = true
	spin.CFrame = root.CFrame
	spin.Parent = char

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = spin
	weld.C0 = CFrame.new()
	weld.C1 = CFrame.new()
	weld.Parent = spin

	local av = Instance.new("BodyAngularVelocity")
	av.AngularVelocity = Vector3.new(10000, 10000, 10000)
	av.MaxTorque = math.huge
	av.Parent = spin

	flingObjs = { spin = spin, weld = weld, av = av }
	return true
end

---------------------------------------------------------------- ANTI-FLING + NO FALL DMG (hooks)
local function hookHumanoid(hum)
	if not hum or hum == hookedHum then return end
	hookedHum = hum
	lastFreefall = 0

	hum.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Freefall then
			lastFreefall = os.clock()
		end
	end)

	hum.HealthChanged:Connect(function(newHealth)
		if not S.noFall then return end
		if not hum.Parent then return end
		if newHealth >= hum.MaxHealth then return end

		local recentFall = (os.clock() - lastFreefall) < 0.6
		local state = hum:GetState()
		local inAirOrLanding =
			state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Ragdoll

		if recentFall or inAirOrLanding then
			hum.Health = hum.MaxHealth
		end
	end)

	if S.noFall then
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	end
end

---------------------------------------------------------------- SPEED / ANTIGRAVITY / ANTI-FLING
RunService.Heartbeat:Connect(function()
	if S.speed and not S.fly then
		local hum = getHum()
		if hum then hum.WalkSpeed = S.walkSpeed end
	end

	if S.anti then
		workspace.Gravity = DEFAULT_GRAVITY * S.gravFactor
	end

	if S.noFling and not S.fling and not S.fly then
		local root = getRoot()
		if root then
			local okAng, av = pcall(function() return root.AssemblyAngularVelocity end)
			if okAng and av and av.Magnitude > 5 then
				pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
			elseif not okAng and root.RotVelocity.Magnitude > 5 then
				root.RotVelocity = Vector3.zero
			end
			local okLin, lv = pcall(function() return root.AssemblyLinearVelocity end)
			local vec = okLin and lv or root.Velocity
			if vec and vec.Magnitude > ANTI_FLING_MAX_VEL then
				local dir = vec.Unit
				pcall(function() root.AssemblyLinearVelocity = dir * ANTI_FLING_MAX_VEL end)
				root.Velocity = dir * ANTI_FLING_MAX_VEL
			end
		end

		local hum = getHum()
		if hum then
			local st = hum:GetState()
			if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			hum.PlatformStand = false
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

local BG, ON, OFF = Color3.fromRGB(28, 30, 36), Color3.fromRGB(46, 160, 90), Color3.fromRGB(70, 74, 86)
local FRAME_W = 190
local FRAME_H = 380

local frame = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W, FRAME_H), Position = UDim2.new(0, 8, 0.20, 0),
	BackgroundColor3 = BG, BackgroundTransparency = 0.12, BorderSizePixel = 0,
	Active = true, Draggable = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)

local title = mk("TextLabel", {
	Size = UDim2.new(1, -34, 0, 26), Position = UDim2.fromOffset(8, 2),
	BackgroundTransparency = 1, Text = "Movement Panel", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local body = mk("Frame", { Size = UDim2.new(1, -12, 1, -34), Position = UDim2.fromOffset(6, 30), BackgroundTransparency = 1 }, frame)
mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)

local miniBtn = mk("TextButton", {
	Size = UDim2.fromOffset(24, 22), Position = UDim2.new(1, -28, 0, 4),
	Text = "-", BackgroundColor3 = OFF, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 16,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, miniBtn)
local minimized = false
miniBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	frame.Size = minimized and UDim2.fromOffset(FRAME_W, 30) or UDim2.fromOffset(FRAME_W, FRAME_H)
	miniBtn.Text = minimized and "+" or "-"
end)

local function toggleRow(order, label, key, onChange)
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, BackgroundColor3 = OFF,
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 13,
		Text = label .. ": OFF",
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
	local function refresh()
		b.Text = label .. ": " .. (S[key] and "ON" or "OFF")
		b.BackgroundColor3 = S[key] and ON or OFF
	end
	b.MouseButton1Click:Connect(function()
		S[key] = not S[key]
		if onChange then onChange(S[key]) end
		refresh()
	end)
	return refresh
end

local function stepRow(order, label, get, set, step, min, max, fmt)
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, BackgroundTransparency = 1 }, body)
	local function btn(txt, x)
		local b = mk("TextButton", {
			Size = UDim2.fromOffset(34, 26), Position = UDim2.new(x, x == 0 and 0 or -34, 0, 0),
			Text = txt, BackgroundColor3 = OFF, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 15,
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
		return b
	end
	local minus, plus = btn("-", 0), btn("+", 1)
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, -76, 1, 0), Position = UDim2.fromOffset(38, 0), BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 12,
	}, row)
	local function refresh() lbl.Text = label .. " " .. string.format(fmt, get()) end
	minus.MouseButton1Click:Connect(function() set(math.clamp(get() - step, min, max)); refresh() end)
	plus.MouseButton1Click:Connect(function() set(math.clamp(get() + step, min, max)); refresh() end)
	refresh()
end

-- FLY
toggleRow(1, "Fly", "fly", function(on)
	if on then
		if not startFly() then S.fly = false end
	else
		stopFly()
		local hum = getHum()
		if hum and S.speed then hum.WalkSpeed = S.walkSpeed end
	end
end)
stepRow(2, "Fly spd", function() return S.flySpeed end, function(v) S.flySpeed = v end, 10, 10, 300, "%d")

-- SPEED
toggleRow(3, "Speed", "speed", function(on)
	local hum = getHum()
	if not hum then return end
	if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
	else hum.WalkSpeed = origWalk end
end)
stepRow(4, "Walk", function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d")

-- INFINITE JUMP
toggleRow(5, "Inf Jump", "inf")

-- ANTIGRAVITY
toggleRow(6, "Anti-Grav", "anti", function(on)
	if not on then workspace.Gravity = DEFAULT_GRAVITY end
end)
stepRow(7, "Gravity", function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx")

-- FLING / MENTALIN
toggleRow(8, "Fling (Mental)", "fling", function(on)
	if on then
		if not startFling() then S.fling = false end
	else
		stopFling()
	end
end)

-- ANTI-FLING / ANTI-MENTAL DIRI SENDIRI
toggleRow(9, "Anti-Mental", "noFling", function(on)
	if not on then
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end
end)

-- NO FALL DAMAGE
toggleRow(10, "No Fall Dmg", "noFall", function(on)
	local hum = getHum()
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
	end
end)

-- Tombol naik/turun (muncul saat Fly ON)
local pad = mk("Frame", {
	Size = UDim2.fromOffset(64, 134), Position = UDim2.new(1, -76, 1, -170),
	BackgroundTransparency = 1, Visible = false,
}, gui)
local function holdBtn(txt, y, setter)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, y), Text = txt,
		BackgroundColor3 = BG, BackgroundTransparency = 0.25, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold, TextSize = 18,
	}, pad)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(true) end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(false) end
	end)
end
holdBtn("UP", 0, function(v) upHeld = v end)
holdBtn("DN", 70, function(v) downHeld = v end)

RunService.RenderStepped:Connect(function() pad.Visible = S.fly end)

---------------------------------------------------------------- RESPAWN
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	origWalk = hum.WalkSpeed
	flyObjs = {}
	flingObjs = {}
	hookedHum = nil
	hookHumanoid(hum)

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