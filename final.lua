--[[
  Movement Panel (Final v4): Fly / Speed / Infinite Jump / Anti-Gravity /
                             Anti-Mental / No Fall Damage / Stick (piggyback) /
                             Teleport (any range) / TP Loop (chase)
  - Client-only, tanpa loadstring/HttpGet.
  - LocalScript di StarterPlayer > StarterPlayerScripts.
  - Tab: MOVE / GUARD / UTILITY. Drag title bar untuk pindahin panel.
  Catatan: di game orang lain ini melanggar ToS Roblox. Risiko sendiri.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

---------------------------------------------------------------- COLORS
local C = {
	bgTop    = Color3.fromRGB(32, 36, 48),
	bgBot    = Color3.fromRGB(14, 16, 22),
	title    = Color3.fromRGB(40, 44, 58),
	card     = Color3.fromRGB(36, 41, 54),
	cardHov  = Color3.fromRGB(46, 52, 68),
	trackOff = Color3.fromRGB(56, 62, 78),
	border   = Color3.fromRGB(60, 66, 84),
	divider  = Color3.fromRGB(48, 54, 70),
	text     = Color3.fromRGB(242, 245, 252),
	muted    = Color3.fromRGB(150, 158, 178),
	accent   = Color3.fromRGB(130, 168, 255),
	accent2  = Color3.fromRGB(180, 140, 255),
	success  = Color3.fromRGB(78, 226, 132),
	warn     = Color3.fromRGB(255, 195, 42),
	danger   = Color3.fromRGB(248, 113, 113),
	flyCol   = Color3.fromRGB(130, 168, 255),
	spdCol   = Color3.fromRGB(255, 195, 42),
	jmpCol   = Color3.fromRGB(78, 226, 132),
	grvCol   = Color3.fromRGB(175, 145, 255),
	antiCol  = Color3.fromRGB(50, 220, 200),
	stkCol   = Color3.fromRGB(255, 150, 65),
	fallCol  = Color3.fromRGB(245, 120, 190),
}

---------------------------------------------------------------- STATE
local S = {
	fly = false, flySpeed = 60,
	speed = false, walkSpeed = 50,
	inf = false,
	anti = false, gravFactor = 0.15,
	noFling = false,
	stick = false,
	noFall = false, fallCap = 30,
	tpLoop = false,
}
local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local stickObjs = {}
local stickTarget = nil
local stickManual = false
local selectedPlayer = nil
local targetLabel = nil
local playerListFrame = nil
local currentTab = nil
local hookedHum = nil
local tpLoopRow = nil
local ANTI_MAX_VEL = 45
local ANTI_VIOLENT = 100
local STICK_RANGE = 60
local STICK_OFFSET = CFrame.new(0, 0.4, 1.2)

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
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local d = (r.Position - pos).Magnitude
				if d < best then nearest, best = p, d end
			end
		end
	end
	return nearest
end
local function isAlive(p)
	if not p or p.Parent ~= Players then return false end
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Health > 0 and r ~= nil
end
local function formatDist(d)
	if d >= 1000 then return string.format("%.1fk", d / 1000) end
	return math.floor(d) .. "m"
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
	ao.Responsiveness = 60
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.05 then
		ao.CFrame = CFrame.lookAt(Vector3.zero, flat)
	else
		ao.CFrame = root.CFrame
	end
	ao.Parent = root

	hum.PlatformStand = true
	flyObjs = { att = att, lv = lv, ao = ao }
	return true
end

RunService.RenderStepped:Connect(function(dt)
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
	if flat.Magnitude > 0.05 then
		local target = flat.Unit
		local current = ao.CFrame.LookVector
		if current:Dot(target) > -0.5 then
			local smoothed = current:Lerp(target, math.clamp(dt * 8, 0, 1)).Unit
			ao.CFrame = CFrame.lookAt(Vector3.zero, smoothed)
		else
			ao.CFrame = CFrame.lookAt(Vector3.zero, target)
		end
	end
end)

---------------------------------------------------------------- NO FALL
local function applyNoFallState(hum, enabled)
	if not hum then return end
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
	end)
end

local function hookHumanoid(hum)
	if not hum or hum == hookedHum then return end
	hookedHum = hum

	hum.StateChanged:Connect(function(_, newState)
		if not S.noFall then return end
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.FallingDown
			or newState == Enum.HumanoidStateType.Ragdoll then
			task.defer(function()
				if S.noFall and hum.Parent and hum.Health < hum.MaxHealth then
					hum.Health = hum.MaxHealth
				end
			end)
		end
	end)

	hum.HealthChanged:Connect(function(newHealth)
		if not S.noFall then return end
		if not hum.Parent then return end
		if newHealth >= hum.MaxHealth then return end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Landed
			or st == Enum.HumanoidStateType.Freefall
			or st == Enum.HumanoidStateType.FallingDown
			or st == Enum.HumanoidStateType.Ragdoll then
			hum.Health = hum.MaxHealth
		end
	end)

	applyNoFallState(hum, S.noFall)
end

---------------------------------------------------------------- TELEPORT
local function teleportToPlayer(p)
	if not p then return false end
	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return false end

	local tChar = p.Character
	local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
	if not tRoot then return false end

	if workspace.StreamingEnabled then
		pcall(function() lp:RequestStreamAroundAsync(tRoot.Position) end)
		task.wait(0.15)
		tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
		if not tRoot then return false end
	end

	local targetCF = tRoot.CFrame * CFrame.new(0, 2, 4)

	for attempt = 1, 5 do
		pcall(function() myChar:PivotTo(targetCF) end)
		pcall(function() myRoot.CFrame = targetCF end)
		pcall(function() myRoot.Position = targetCF.Position end)
		pcall(function() myRoot.AssemblyLinearVelocity = Vector3.zero end)
		pcall(function() myRoot.AssemblyAngularVelocity = Vector3.zero end)
		if attempt < 5 then RunService.Heartbeat:Wait() end
	end
	return true
end

---------------------------------------------------------------- STICK (piggyback)
local COLLISION_GROUP = "MPStick"

local function ensureCollision()
	pcall(function() PhysicsService:RegisterCollisionGroup(COLLISION_GROUP) end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", false)
	end)
end

local function setGroup(char, group)
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			pcall(function() p.CollisionGroup = group end)
		end
	end
end

local function stopStick(keepState)
	for _, o in pairs(stickObjs) do
		if typeof(o) == "Instance" and o.Parent then o:Destroy() end
	end
	local oldOrigWS = stickObjs.origWS
	local oldOrigJP = stickObjs.origJP
	stickObjs = {}
	stickTarget = nil
	stickManual = false

	setGroup(lp.Character, "Default")

	local hum = getHum()
	if hum and keepState ~= true then
		hum.PlatformStand = false
		hum.AutoRotate = true
		if oldOrigWS then hum.WalkSpeed = oldOrigWS end
		if oldOrigJP then
			if hum.UseJumpPower then hum.JumpPower = oldOrigJP
			else hum.JumpHeight = oldOrigJP end
		end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function setupAlign(targetPlayer)
	local myRoot = getRoot()
	if not myRoot or not targetPlayer or not targetPlayer.Character then return false end
	local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not tRoot then return false end

	local att0 = Instance.new("Attachment")
	att0.Name = "MP_StickMy"
	att0.Parent = myRoot

	local att1 = Instance.new("Attachment")
	att1.Name = "MP_StickThem"
	att1.CFrame = STICK_OFFSET -- piggyback offset (0, 0.4, 1.2)
	att1.Parent = tRoot

	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.TwoAttachment
	ap.Attachment0 = att0
	ap.Attachment1 = att1
	ap.RigidityEnabled = true
	ap.MaxForce = math.huge
	ap.ApplyAtCenterOfMass = false
	ap.Parent = myRoot

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	ao.Attachment0 = att0
	ao.Attachment1 = att1
	ao.RigidityEnabled = true
	ao.MaxTorque = math.huge
	ao.Parent = myRoot

	stickObjs.att0 = att0
	stickObjs.att1 = att1
	stickObjs.ap = ap
	stickObjs.ao = ao
	stickTarget = targetPlayer
	return true
end

local function startStick(targetPlayer, manual)
	stopStick(true)
	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not hum or not targetPlayer then return false end
	if not setupAlign(targetPlayer) then return false end

	ensureCollision()
	setGroup(myChar, COLLISION_GROUP)

	local origWS = hum.WalkSpeed
	local origJP = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
	hum.PlatformStand = true
	hum.AutoRotate = false
	hum.WalkSpeed = 0
	if hum.UseJumpPower then hum.JumpPower = 0 else hum.JumpHeight = 0 end
	hum:ChangeState(Enum.HumanoidStateType.Physics)

	stickObjs.origWS = origWS
	stickObjs.origJP = origJP
	stickManual = manual or (targetPlayer == selectedPlayer)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero
	return true
end

---------------------------------------------------------------- ANTI-MENTAL
local function antiFlingTick()
	if not S.noFling or S.stick or S.fly then return end
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = getHum()
	if not root or not hum then return end

	for _, c in ipairs(root:GetChildren()) do
		if c:IsA("Weld") or c:IsA("WeldConstraint") then
			local other = (c.Part0 == root) and c.Part1 or c.Part0
			if other and not other:IsDescendantOf(char) then
				c:Destroy()
			end
		end
	end

	local av = root.AssemblyAngularVelocity
	if av and av.Magnitude > 1 then
		pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
	end
	local rv = root.RotVelocity
	if rv and rv.Magnitude > 1 then
		pcall(function() root.RotVelocity = Vector3.zero end)
	end

	local lv = root.AssemblyLinearVelocity
	if lv then
		local mag = lv.Magnitude
		if mag > ANTI_VIOLENT then
			pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		elseif mag > ANTI_MAX_VEL then
			pcall(function() root.AssemblyLinearVelocity = lv.Unit * ANTI_MAX_VEL end)
		end
	end

	if hum.PlatformStand then hum.PlatformStand = false end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Ragdoll
		or st == Enum.HumanoidStateType.FallingDown
		or st == Enum.HumanoidStateType.Flying
		or st == Enum.HumanoidStateType.PlatformStanding then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

---------------------------------------------------------------- PRE-SIM / MAIN
RunService.PreSimulation:Connect(function()
	if S.noFall and not S.stick and not S.fly and not S.tpLoop then
		local root = getRoot()
		if root then
			local v = root.AssemblyLinearVelocity
			if v.Y < -S.fallCap then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -S.fallCap, v.Z)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if S.speed and not S.fly and not S.stick and not S.tpLoop then
		local hum = getHum()
		if hum then hum.WalkSpeed = S.walkSpeed end
	end

	if S.anti then
		workspace.Gravity = DEFAULT_GRAVITY * S.gravFactor
	end

	antiFlingTick()

	if S.stick then
		local myRoot = getRoot()
		local myHum = getHum()
		if not myRoot or not myHum then
			S.stick = false
			stopStick()
		else
			if myHum:GetState() ~= Enum.HumanoidStateType.Physics then
				myHum:ChangeState(Enum.HumanoidStateType.Physics)
			end
			if myHum.AutoRotate then myHum.AutoRotate = false end

			local alive = isAlive(stickTarget)
				and stickObjs.att1
				and stickObjs.att1.Parent == stickTarget.Character.HumanoidRootPart

			if not alive then
				if stickManual then
					S.stick = false
					stopStick()
					selectedPlayer = nil
				else
					local newTarget = findNearestPlayer(STICK_RANGE)
					if newTarget then
						stopStick(true)
						if not startStick(newTarget, false) then
							S.stick = false
							stopStick()
						end
					else
						S.stick = false
						stopStick()
					end
				end
			end
		end
	end
end)

-- TP Loop
task.spawn(function()
	while true do
		task.wait(0.15)
		if S.tpLoop then
			if selectedPlayer and isAlive(selectedPlayer) then
				local myRoot = getRoot()
				local tRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot and tRoot then
					local dist = (tRoot.Position - myRoot.Position).Magnitude
					if dist > 4 then
						teleportToPlayer(selectedPlayer)
					end
				end
			else
				S.tpLoop = false
				if tpLoopRow then tpLoopRow.refresh(true) end
			end
		end
	end
end)

---------------------------------------------------------------- INPUT
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

---------------------------------------------------------------- UI
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

local FRAME_W = 248
local TITLE_H = 40
local TAB_H = 34
local TAB_HEIGHTS = {
	move = 296,
	guard = 248,
	util = 356,
}

local container = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W + 10, TAB_HEIGHTS.move + 10),
	Position = UDim2.new(0, 14, 0.18, 0),
	BackgroundTransparency = 1,
}, gui)

-- Layered shadow (2 layers for depth)
local shadow2 = mk("Frame", {
	Size = UDim2.new(1, -4, 1, -4),
	Position = UDim2.fromOffset(10, 12),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.78,
	BorderSizePixel = 0,
}, container)
mk("UICorner", { CornerRadius = UDim.new(0, 18) }, shadow2)

local shadow = mk("Frame", {
	Size = UDim2.new(1, -8, 1, -8),
	Position = UDim2.fromOffset(5, 6),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, container)
mk("UICorner", { CornerRadius = UDim.new(0, 16) }, shadow)

local frame = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W, TAB_HEIGHTS.move),
	BackgroundColor3 = C.bgTop,
	BorderSizePixel = 0,
	Active = true,
	ClipsDescendants = true,
}, container)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.2 }, frame)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.bgTop),
		ColorSequenceKeypoint.new(1, C.bgBot),
	}),
	Rotation = 90,
}, frame)

---------------------------------------------------------------- TITLE
local titleBar = mk("Frame", {
	Size = UDim2.new(1, 0, 0, TITLE_H),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleBar)
mk("Frame", {
	Size = UDim2.new(1, 0, 0, 16),
	Position = UDim2.new(0, 0, 1, -16),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
}, titleBar)

-- Accent gradient line at bottom of title
local titleAccent = mk("Frame", {
	Size = UDim2.new(1, -24, 0, 2),
	Position = UDim2.new(0, 12, 1, -1),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
}, titleBar)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.accent),
		ColorSequenceKeypoint.new(0.5, C.accent2),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 120, 190)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, titleAccent)

-- Drag grip
for i = 1, 3 do
	mk("Frame", {
		Size = UDim2.fromOffset(3, 3),
		Position = UDim2.fromOffset(8, 15 + (i - 1) * 6),
		BackgroundColor3 = C.muted,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, titleBar)
end

-- Logo icon (rounded box + star)
local logoBox = mk("Frame", {
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.fromOffset(22, 9),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, logoBox)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.accent),
		ColorSequenceKeypoint.new(1, C.accent2),
	}),
	Rotation = 45,
}, logoBox)
mk("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "✦",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
}, logoBox)

mk("TextLabel", {
	Size = UDim2.new(1, -120, 1, 0),
	Position = UDim2.fromOffset(52, 0),
	BackgroundTransparency = 1,
	Text = "Movement Panel",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

-- Status pill
local statusPill = mk("Frame", {
	Size = UDim2.fromOffset(44, 20),
	Position = UDim2.new(1, -76, 0.5, -10),
	BackgroundColor3 = C.card,
	BorderSizePixel = 0,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, statusPill)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.4 }, statusPill)

local statusDot = mk("Frame", {
	Size = UDim2.fromOffset(6, 6),
	Position = UDim2.fromOffset(7, 7),
	BackgroundColor3 = C.muted,
	BorderSizePixel = 0,
}, statusPill)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)

local statusText = mk("TextLabel", {
	Size = UDim2.new(1, -18, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	BackgroundTransparency = 1,
	Text = "IDLE",
	TextColor3 = C.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, statusPill)

local miniBtn = mk("TextButton", {
	Size = UDim2.fromOffset(24, 22),
	Position = UDim2.new(1, -30, 0.5, -11),
	Text = "–",
	BackgroundColor3 = C.trackOff,
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	AutoButtonColor = false,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, miniBtn)

-- Drag
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = container.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		container.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

---------------------------------------------------------------- TAB BAR
local tabBar = mk("Frame", {
	Size = UDim2.new(1, -16, 0, TAB_H - 6),
	Position = UDim2.fromOffset(8, TITLE_H + 3),
	BackgroundTransparency = 1,
}, frame)
mk("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local pages = {}
local tabBtns = {}

local function createTab(name, label, order)
	local btn = mk("TextButton", {
		Size = UDim2.new(1/3, -4, 1, 0),
		BackgroundColor3 = C.card,
		Text = label,
		TextColor3 = C.muted,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		LayoutOrder = order,
		AutoButtonColor = false,
	}, tabBar)
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, btn)
	mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.5 }, btn)
	tabBtns[name] = btn
	return btn
end

---------------------------------------------------------------- CONTENT
local contentY = TITLE_H + TAB_H + 2
local contentContainer = mk("Frame", {
	Size = UDim2.new(1, -16, 1, -contentY - 6),
	Position = UDim2.fromOffset(8, contentY),
	BackgroundTransparency = 1,
}, frame)

local function makePage()
	local p = mk("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.accent,
		ScrollBarImageTransparency = 0.35,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, contentContainer)
	mk("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, p)
	return p
end

pages.move = makePage()
pages.guard = makePage()
pages.util = makePage()

local function updateTargetLabel()
	local name = "—"
	if S.stick and stickTarget then
		name = stickTarget.Name
	elseif selectedPlayer then
		name = selectedPlayer.Name
	end
	if targetLabel then targetLabel.Text = "Target: " .. name end
end

local function setTab(name)
	for n, p in pairs(pages) do
		p.Visible = (n == name)
	end
	for n, b in pairs(tabBtns) do
		local active = (n == name)
		TweenService:Create(b, TweenInfo.new(0.15), {
			BackgroundColor3 = active and C.accent or C.card,
			TextColor3 = active and Color3.new(1, 1, 1) or C.muted,
		}):Play()
	end
	currentTab = name
	local h = TAB_HEIGHTS[name] or 296
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(FRAME_W, h),
	}):Play()
	TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(FRAME_W + 10, h + 10),
	}):Play()
end

createTab("move", "MOVE", 1).MouseButton1Click:Connect(function() setTab("move") end)
createTab("guard", "GUARD", 2).MouseButton1Click:Connect(function() setTab("guard") end)
createTab("util", "UTILITY", 3).MouseButton1Click:Connect(function()
	setTab("util")
	if refreshPlayerList then refreshPlayerList() end
end)

---------------------------------------------------------------- ROW BUILDERS
local function updateStatus()
	local active = S.fly or S.speed or S.inf or S.anti or S.noFling or S.stick or S.noFall or S.tpLoop
	local activeCount = 0
	if S.fly then activeCount += 1 end
	if S.speed then activeCount += 1 end
	if S.inf then activeCount += 1 end
	if S.anti then activeCount += 1 end
	if S.noFling then activeCount += 1 end
	if S.stick then activeCount += 1 end
	if S.noFall then activeCount += 1 end
	if S.tpLoop then activeCount += 1 end

	local color = active and C.success or C.muted
	TweenService:Create(statusDot, TweenInfo.new(0.2), {
		BackgroundColor3 = color,
	}):Play()
	TweenService:Create(statusText, TweenInfo.new(0.2), {
		TextColor3 = color,
	}):Play()
	statusText.Text = active and (activeCount .. " ON") or "IDLE"
end

local function toggleRow(parent, order, label, color, key, onChange)
	local row = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 9) }, row)
	local rowStroke = mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.55 }, row)

	-- Subtle gradient overlay
	local grad = mk("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(0, 9) }, grad)
	local gradFx = mk("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.96),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
	}, grad)

	local dot = mk("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(11, 12),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	mk("UIStroke", { Color = color, Thickness = 1, Transparency = 0.4 }, dot)

	mk("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(24, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	-- Toggle track (bigger, more premium)
	local track = mk("Frame", {
		Size = UDim2.fromOffset(32, 18),
		Position = UDim2.new(1, -42, 0.5, -9),
		BackgroundColor3 = C.trackOff,
		BorderSizePixel = 0,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	mk("UIStroke", { Color = Color3.fromRGB(38, 42, 54), Thickness = 1, Transparency = 0.5 }, track)

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, track)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	mk("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1, Transparency = 0.85 }, knob)

	local function refresh(animate)
		local on = S[key]
		local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if animate then
			TweenService:Create(knob, ti, {
				Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2),
			}):Play()
			TweenService:Create(track, ti, {
				BackgroundColor3 = on and color or C.trackOff,
			}):Play()
			TweenService:Create(row, ti, {
				BackgroundColor3 = on and C.cardHov or C.card,
			}):Play()
			TweenService:Create(rowStroke, ti, {
				Color = on and color or C.border,
				Transparency = on and 0.3 or 0.55,
			}):Play()
		else
			knob.Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2)
			track.BackgroundColor3 = on and color or C.trackOff
			row.BackgroundColor3 = on and C.cardHov or C.card
			rowStroke.Color = on and color or C.border
			rowStroke.Transparency = on and 0.3 or 0.55
		end
	end

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {
			BackgroundColor3 = S[key] and C.cardHov or Color3.fromRGB(42, 48, 62),
		}):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {
			BackgroundColor3 = S[key] and C.cardHov or C.card,
		}):Play()
	end)
	row.MouseButton1Click:Connect(function()
		S[key] = not S[key]
		if onChange then onChange(S[key]) end
		refresh(true)
		updateStatus()
	end)

	refresh(false)
	return { refresh = refresh }
end

local function stepRow(parent, order, label, get, set, step, min, max, fmt)
	local row = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = order,
		BackgroundTransparency = 1,
	}, parent)

	mk("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.muted,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local function btn(txt, x)
		local b = mk("TextButton", {
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, x, 0.5, -11),
			Text = txt,
			BackgroundColor3 = C.trackOff,
			TextColor3 = C.text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			AutoButtonColor = false,
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.6 }, b)
		return b
	end
	local plus = btn("+", -28)
	local minus = btn("–", -56)

	local valLbl = mk("TextLabel", {
		Size = UDim2.fromOffset(46, 22),
		Position = UDim2.new(1, -104, 0.5, -11),
		BackgroundColor3 = C.card,
		Text = "",
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, valLbl)
	mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.5 }, valLbl)

	local function refresh() valLbl.Text = string.format(fmt, get()) end
	minus.MouseButton1Click:Connect(function()
		set(math.clamp(get() - step, min, max)); refresh()
	end)
	plus.MouseButton1Click:Connect(function()
		set(math.clamp(get() + step, min, max)); refresh()
	end)
	refresh()
end

---------------------------------------------------------------- PAGE: MOVE
toggleRow(pages.move, 1, "Fly", C.flyCol, "fly", function(on)
	if on then
		if S.stick then S.stick = false; stopStick() end
		if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end
		if not startFly() then S.fly = false end
	else
		stopFly()
		local hum = getHum()
		if hum and S.speed then hum.WalkSpeed = S.walkSpeed end
	end
end)
stepRow(pages.move, 2, "Fly Speed", function() return S.flySpeed end, function(v) S.flySpeed = v end, 10, 10, 300, "%d")
toggleRow(pages.move, 3, "Speed Boost", C.spdCol, "speed", function(on)
	local hum = getHum()
	if not hum then return end
	if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
	else hum.WalkSpeed = origWalk end
end)
stepRow(pages.move, 4, "Walk Speed", function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d")
toggleRow(pages.move, 5, "Infinite Jump", C.jmpCol, "inf")
toggleRow(pages.move, 6, "Anti-Gravity", C.grvCol, "anti", function(on)
	if not on then workspace.Gravity = DEFAULT_GRAVITY end
end)
stepRow(pages.move, 7, "Gravity", function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx")

---------------------------------------------------------------- PAGE: GUARD
toggleRow(pages.guard, 1, "Anti-Mental", C.antiCol, "noFling", function(on)
	if not on then
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end
end)
toggleRow(pages.guard, 2, "No Fall Damage", C.fallCol, "noFall", function(on)
	local hum = getHum()
	if hum then applyNoFallState(hum, on) end
end)
stepRow(pages.guard, 3, "Fall Cap", function() return S.fallCap end, function(v) S.fallCap = v end, 2, 10, 60, "%d")

---------------------------------------------------------------- PAGE: UTILITY
local utilHeader = mk("Frame", {
	Size = UDim2.new(1, 0, 0, 22),
	LayoutOrder = 1,
	BackgroundTransparency = 1,
}, pages.util)

local playerCountLbl = mk("TextLabel", {
	Size = UDim2.new(1, -84, 1, 0),
	BackgroundTransparency = 1,
	Text = "Players (0)",
	TextColor3 = C.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, utilHeader)

local refreshBtn = mk("TextButton", {
	Size = UDim2.fromOffset(74, 22),
	Position = UDim2.new(1, -74, 0, 0),
	Text = "↻ Refresh",
	BackgroundColor3 = C.card,
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	AutoButtonColor = false,
}, utilHeader)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, refreshBtn)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.5 }, refreshBtn)

playerListFrame = mk("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 145),
	LayoutOrder = 2,
	BackgroundColor3 = Color3.fromRGB(20, 23, 30),
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.accent,
	ScrollBarImageTransparency = 0.35,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, pages.util)
mk("UICorner", { CornerRadius = UDim.new(0, 9) }, playerListFrame)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.5 }, playerListFrame)
mk("UIPadding", {
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 4),
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
}, playerListFrame)
mk("UIListLayout", {
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, playerListFrame)

targetLabel = mk("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	LayoutOrder = 3,
	BackgroundTransparency = 1,
	Text = "Target: —",
	TextColor3 = C.muted,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, pages.util)
mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, targetLabel)

local actionRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, 32),
	LayoutOrder = 4,
	BackgroundTransparency = 1,
}, pages.util)
mk("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionRow)

local teleBtn = mk("TextButton", {
	Size = UDim2.new(0.5, -3, 1, 0),
	LayoutOrder = 1,
	Text = "Teleport",
	BackgroundColor3 = C.accent,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, actionRow)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, teleBtn)

local stickBtn = mk("TextButton", {
	Size = UDim2.new(0.5, -3, 1, 0),
	LayoutOrder = 2,
	Text = "Stick",
	BackgroundColor3 = C.card,
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, actionRow)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, stickBtn)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.4 }, stickBtn)

local function updateStickBtn()
	if S.stick then
		TweenService:Create(stickBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = C.stkCol,
			TextColor3 = Color3.new(1, 1, 1),
		}):Play()
	else
		TweenService:Create(stickBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = C.card,
			TextColor3 = C.text,
		}):Play()
	end
end

tpLoopRow = toggleRow(pages.util, 5, "TP Loop (chase)", C.accent, "tpLoop", function(on)
	if on then
		if not selectedPlayer then
			selectedPlayer = findNearestPlayer(math.huge)
			if not selectedPlayer then
				S.tpLoop = false
				return
			end
			updateTargetLabel()
			refreshPlayerList()
		end
		if S.stick then
			S.stick = false
			stopStick()
			updateStickBtn()
		end
		if S.fly then
			S.fly = false
			stopFly()
		end
	end
end)

function refreshPlayerList()
	if not playerListFrame then return end
	for _, c in ipairs(playerListFrame:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end

	if selectedPlayer and not isAlive(selectedPlayer) then
		selectedPlayer = nil
		if S.stick and stickManual then
			S.stick = false
			stopStick()
			updateStickBtn()
		end
		if S.tpLoop then
			S.tpLoop = false
			if tpLoopRow then tpLoopRow.refresh(true) end
		end
	end

	local list = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= lp and isAlive(p) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

	playerCountLbl.Text = "Players (" .. #list .. ")"

	if #list == 0 then
		mk("TextLabel", {
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Text = "No other players alive",
			TextColor3 = C.muted,
			Font = Enum.Font.Gotham,
			TextSize = 10,
		}, playerListFrame)
		updateTargetLabel()
		return
	end

	local myRoot = getRoot()
	local myPos = myRoot and myRoot.Position or Vector3.zero

	for i, p in ipairs(list) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local tRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local hpPct = hum and (hum.Health / math.max(hum.MaxHealth, 1)) or 1
		local hpColor = hpPct > 0.5 and C.success
			or hpPct > 0.25 and C.warn
			or C.danger
		local dist = tRoot and (tRoot.Position - myPos).Magnitude or 0
		local isSel = (p == selectedPlayer)

		local row = mk("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = i,
			BackgroundColor3 = isSel and C.accent or C.card,
			Text = "",
			AutoButtonColor = false,
		}, playerListFrame)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)

		local hpDot = mk("Frame", {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.fromOffset(7, 9),
			BackgroundColor3 = hpColor,
			BorderSizePixel = 0,
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, hpDot)

		mk("TextLabel", {
			Size = UDim2.new(1, -96, 1, 0),
			Position = UDim2.fromOffset(18, 0),
			BackgroundTransparency = 1,
			Text = p.Name,
			TextColor3 = isSel and Color3.new(1, 1, 1) or C.text,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		mk("TextLabel", {
			Size = UDim2.fromOffset(46, 24),
			Position = UDim2.new(1, -48, 0, 0),
			BackgroundTransparency = 1,
			Text = formatDist(dist),
			TextColor3 = isSel and Color3.new(1, 1, 1) or C.muted,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)

		row.MouseButton1Click:Connect(function()
			selectedPlayer = p
			updateTargetLabel()
			refreshPlayerList()
		end)
	end

	updateTargetLabel()
end

refreshBtn.MouseButton1Click:Connect(function()
	refreshBtn.Text = "↻ ..."
	refreshPlayerList()
	task.delay(0.4, function() refreshBtn.Text = "↻ Refresh" end)
end)

teleBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then
		selectedPlayer = findNearestPlayer(math.huge)
		if not selectedPlayer then
			targetLabel.Text = "No players on server"
			return
		end
		updateTargetLabel()
		refreshPlayerList()
	end
	teleBtn.Text = "..."
	if teleportToPlayer(selectedPlayer) then
		targetLabel.Text = "✓ TP → " .. selectedPlayer.Name
		task.delay(1.0, function()
			teleBtn.Text = "Teleport"
			updateTargetLabel()
		end)
	else
		teleBtn.Text = "Teleport"
		targetLabel.Text = "✗ TP failed"
		task.delay(1.0, updateTargetLabel)
	end
end)

stickBtn.MouseButton1Click:Connect(function()
	if S.stick then
		S.stick = false
		stopStick()
		updateStickBtn()
		updateTargetLabel()
		updateStatus()
	else
		local target = selectedPlayer or findNearestPlayer(math.huge)
		if not target then return end
		if not selectedPlayer then
			selectedPlayer = target
			refreshPlayerList()
		end
		if S.tpLoop then
			S.tpLoop = false
			if tpLoopRow then tpLoopRow.refresh(true) end
		end
		teleportToPlayer(target)
		if startStick(target, true) then
			S.stick = true
			updateStickBtn()
			updateTargetLabel()
			updateStatus()
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if currentTab == "util" and not dragging then
			pcall(refreshPlayerList)
		end
	end
end)

local function watchPlayer(p)
	p.CharacterAdded:Connect(function()
		task.delay(0.5, function() pcall(refreshPlayerList) end)
	end)
end
for _, p in pairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(function(p)
	watchPlayer(p)
	task.delay(0.3, function() pcall(refreshPlayerList) end)
end)
Players.PlayerRemoving:Connect(function(p)
	if selectedPlayer == p then
		selectedPlayer = nil
		if S.stick and stickManual then
			S.stick = false
			stopStick()
			updateStickBtn()
		end
		if S.tpLoop then
			S.tpLoop = false
			if tpLoopRow then tpLoopRow.refresh(true) end
		end
	end
	task.delay(0.2, function() pcall(refreshPlayerList) end)
end)

setTab("move")
updateStatus()
pcall(refreshPlayerList)

---------------------------------------------------------------- MINIMIZE
local minimized = false
miniBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	contentContainer.Visible = not minimized
	tabBar.Visible = not minimized
	if minimized then
		frame.Size = UDim2.fromOffset(FRAME_W, TITLE_H)
		container.Size = UDim2.fromOffset(FRAME_W + 10, TITLE_H + 10)
	else
		local h = TAB_HEIGHTS[currentTab or "move"] or 296
		frame.Size = UDim2.fromOffset(FRAME_W, h)
		container.Size = UDim2.fromOffset(FRAME_W + 10, h + 10)
	end
	miniBtn.Text = minimized and "+" or "–"
end)

---------------------------------------------------------------- FLY PAD
local pad = mk("Frame", {
	Size = UDim2.fromOffset(56, 118),
	Position = UDim2.new(1, -70, 1, -144),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local function holdBtn(txt, y, setter)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(0, y),
		Text = txt,
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.12,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		AutoButtonColor = false,
	}, pad)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.3 }, b)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(true) end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(false) end
	end)
end
holdBtn("↑", 0, function(v) upHeld = v end)
holdBtn("↓", 62, function(v) downHeld = v end)

RunService.RenderStepped:Connect(function() pad.Visible = S.fly end)

---------------------------------------------------------------- RESPAWN
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	origWalk = hum.WalkSpeed
	flyObjs = {}
	stickObjs = {}
	stickTarget = nil
	stickManual = false
	hookedHum = nil
	if S.stick then
		S.stick = false
		updateStickBtn()
	end
	updateTargetLabel()

	hookHumanoid(hum)

	if S.fly then
		task.wait(0.5)
		if S.fly then startFly() end
	end
	if S.speed then hum.WalkSpeed = S.walkSpeed end
	if S.noFall then applyNoFallState(hum, true) end
end
lp.CharacterAdded:Connect(onCharacter)
if lp.Character then task.spawn(onCharacter, lp.Character) end