--[[
  Movement Panel: Fly / Speed / Infinite Jump / Anti-Gravity /
                  Anti-Mental / No Fall Damage / Stick to Player
  - Client-only, tanpa loadstring/HttpGet.
  - LocalScript di StarterPlayer > StarterPlayerScripts.
  - Kontrol: E = naik, Q = turun (saat Fly). Scroll untuk semua fitur.
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
	bgTop    = Color3.fromRGB(28, 31, 40),
	bgBot    = Color3.fromRGB(16, 18, 24),
	title    = Color3.fromRGB(34, 38, 48),
	card     = Color3.fromRGB(32, 36, 46),
	cardHov  = Color3.fromRGB(40, 45, 57),
	trackOff = Color3.fromRGB(58, 63, 78),
	border   = Color3.fromRGB(52, 57, 72),
	divider  = Color3.fromRGB(44, 48, 60),
	text     = Color3.fromRGB(238, 241, 248),
	muted    = Color3.fromRGB(148, 156, 174),
	accent   = Color3.fromRGB(122, 162, 255),
	success  = Color3.fromRGB(74, 222, 128),
	flyCol   = Color3.fromRGB(122, 162, 255),
	spdCol   = Color3.fromRGB(251, 191, 36),
	jmpCol   = Color3.fromRGB(74, 222, 128),
	grvCol   = Color3.fromRGB(167, 139, 250),
	antiCol  = Color3.fromRGB(45, 212, 191),
	stkCol   = Color3.fromRGB(251, 146, 60),
	fallCol  = Color3.fromRGB(244, 114, 182),
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
}
local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local stickObjs = {}
local stickTarget = nil
local stickTargetLbl = nil
local hookedHum = nil
local ANTI_MAX_VEL = 45
local ANTI_VIOLENT = 100
local STICK_RANGE = 60

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

	-- Smooth orientation — no more "muter-muter gajelas"
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

---------------------------------------------------------------- NO FALL DAMAGE (aggressive)
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

---------------------------------------------------------------- STICK (smooth carry)
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
	if stickTargetLbl then stickTargetLbl.Text = "Target: —" end

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
	att1.Position = Vector3.new(0, 0, 2)
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
	if stickTargetLbl then stickTargetLbl.Text = "Target: " .. targetPlayer.Name end
	return true
end

local function startStick(targetPlayer)
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
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero
	return true
end

---------------------------------------------------------------- ANTI-MENTAL (4-layer)
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

---------------------------------------------------------------- PRE-SIMULATION LOOP (no fall clamp runs BEFORE physics)
RunService.PreSimulation:Connect(function()
	if S.noFall and not S.stick and not S.fly then
		local root = getRoot()
		if root then
			local v = root.AssemblyLinearVelocity
			if v.Y < -S.fallCap then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -S.fallCap, v.Z)
			end
		end
	end
end)

---------------------------------------------------------------- MAIN LOOP
RunService.Heartbeat:Connect(function()
	if S.speed and not S.fly and not S.stick then
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

			local tHum = stickTarget and stickTarget.Character
				and stickTarget.Character:FindFirstChildOfClass("Humanoid")
			local tRoot = stickTarget and stickTarget.Character
				and stickTarget.Character:FindFirstChild("HumanoidRootPart")
			local alive = tHum and tHum.Health > 0 and tRoot
				and stickObjs.att1 and stickObjs.att1.Parent == tRoot

			if not alive then
				local newTarget = findNearestPlayer(STICK_RANGE)
				if newTarget then
					stopStick(true)
					if not startStick(newTarget) then
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

local FRAME_W, FRAME_H = 240, 470
local TITLE_H = 38

local frame = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W, FRAME_H),
	Position = UDim2.new(0, 12, 0.14, 0),
	BackgroundColor3 = C.bgTop,
	BorderSizePixel = 0,
	Active = true, Draggable = true,
	ClipsDescendants = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.3 }, frame)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.bgTop),
		ColorSequenceKeypoint.new(1, C.bgBot),
	}),
	Rotation = 90,
}, frame)

local titleBar = mk("Frame", {
	Size = UDim2.new(1, 0, 0, TITLE_H),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, titleBar)
mk("Frame", {
	Size = UDim2.new(1, 0, 0, 14),
	Position = UDim2.new(0, 0, 1, -14),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
}, titleBar)
mk("Frame", {
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 1, 0),
	BackgroundColor3 = C.divider,
	BorderSizePixel = 0,
}, titleBar)

mk("TextLabel", {
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.fromOffset(10, 8),
	BackgroundTransparency = 1,
	Text = "✦",
	TextColor3 = C.accent,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
}, titleBar)

mk("TextLabel", {
	Size = UDim2.new(1, -110, 1, 0),
	Position = UDim2.fromOffset(36, 0),
	BackgroundTransparency = 1,
	Text = "Movement Panel",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local statusDot = mk("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.new(1, -68, 0.5, -4),
	BackgroundColor3 = C.muted,
	BorderSizePixel = 0,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, statusDot)
mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.4 }, statusDot)

local miniBtn = mk("TextButton", {
	Size = UDim2.fromOffset(26, 24),
	Position = UDim2.new(1, -32, 0, 7),
	Text = "–",
	BackgroundColor3 = C.trackOff,
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	AutoButtonColor = false,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(0, 7) }, miniBtn)

local scroll = mk("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -TITLE_H),
	Position = UDim2.fromOffset(0, TITLE_H),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.accent,
	ScrollBarImageTransparency = 0.4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	ClipsDescendants = true,
}, frame)
mk("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 12),
}, scroll)
mk("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)

local minimized = false
local function setMinimized(m)
	minimized = m
	scroll.Visible = not minimized
	frame.Size = minimized and UDim2.fromOffset(FRAME_W, TITLE_H) or UDim2.fromOffset(FRAME_W, FRAME_H)
	miniBtn.Text = minimized and "+" or "–"
end
miniBtn.MouseButton1Click:Connect(function() setMinimized(not minimized) end)

local function updateStatusDot()
	local active = S.fly or S.speed or S.inf or S.anti or S.noFling or S.stick or S.noFall
	local color = active and C.success or C.muted
	local size = active and UDim2.fromOffset(10, 10) or UDim2.fromOffset(8, 8)
	local pos = active and UDim2.new(1, -69, 0.5, -5) or UDim2.new(1, -68, 0.5, -4)
	TweenService:Create(statusDot, TweenInfo.new(0.2), {
		BackgroundColor3 = color, Size = size, Position = pos,
	}):Play()
end

local function sectionHeader(order, text)
	local wrap = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		BackgroundTransparency = 1,
	}, scroll)
	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(4, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, wrap)
	mk("Frame", {
		Size = UDim2.new(1, -8, 0, 1),
		Position = UDim2.new(0, 4, 1, -2),
		BackgroundColor3 = C.divider,
		BorderSizePixel = 0,
	}, wrap)
end

local function toggleRow(order, label, color, key, onChange)
	local row = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = order,
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, scroll)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, row)
	mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.4 }, row)

	mk("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(12, 16),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, row)
	local dot = row:GetChildren()[#row:GetChildren()]
	if dot then mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot) end

	mk("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(26, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local track = mk("Frame", {
		Size = UDim2.fromOffset(32, 18),
		Position = UDim2.new(1, -44, 0.5, -9),
		BackgroundColor3 = C.trackOff,
		BorderSizePixel = 0,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, track)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

	local function refresh(animate)
		local on = S[key]
		local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
		else
			knob.Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2)
			track.BackgroundColor3 = on and color or C.trackOff
			row.BackgroundColor3 = on and C.cardHov or C.card
		end
	end

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), {
			BackgroundColor3 = S[key] and C.cardHov or Color3.fromRGB(38, 42, 54),
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
		updateStatusDot()
	end)

	refresh(false)
	return { refresh = refresh }
end

local function stepRow(order, label, get, set, step, min, max, fmt)
	local row = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		BackgroundTransparency = 1,
	}, scroll)

	mk("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.muted,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local function btn(txt, x)
		local b = mk("TextButton", {
			Size = UDim2.fromOffset(24, 22),
			Position = UDim2.new(1, x, 0.5, -11),
			Text = txt,
			BackgroundColor3 = C.trackOff,
			TextColor3 = C.text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = false,
		}, row)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		return b
	end
	local plus = btn("+", -30)
	local minus = btn("–", -58)

	local valLbl = mk("TextLabel", {
		Size = UDim2.fromOffset(50, 22),
		Position = UDim2.new(1, -108, 0.5, -11),
		BackgroundColor3 = C.card,
		Text = "",
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, valLbl)
	mk("UIStroke", { Color = C.border, Thickness = 1, Transparency = 0.4 }, valLbl)

	local function refresh() valLbl.Text = string.format(fmt, get()) end
	minus.MouseButton1Click:Connect(function()
		set(math.clamp(get() - step, min, max)); refresh()
	end)
	plus.MouseButton1Click:Connect(function()
		set(math.clamp(get() + step, min, max)); refresh()
	end)
	refresh()
end

---------------------------------------------------------------- BUILD UI
sectionHeader(1, "FLIGHT")

toggleRow(2, "Fly", C.flyCol, "fly", function(on)
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

sectionHeader(4, "MOVEMENT")

toggleRow(5, "Speed Boost", C.spdCol, "speed", function(on)
	local hum = getHum()
	if not hum then return end
	if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
	else hum.WalkSpeed = origWalk end
end)
stepRow(6, "Walk Speed", function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d")
toggleRow(7, "Infinite Jump", C.jmpCol, "inf")
toggleRow(8, "Anti-Gravity", C.grvCol, "anti", function(on)
	if not on then workspace.Gravity = DEFAULT_GRAVITY end
end)
stepRow(9, "Gravity", function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx")

sectionHeader(10, "PROTECTION")

toggleRow(11, "Anti-Mental", C.antiCol, "noFling", function(on)
	if not on then
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end
end)
toggleRow(12, "No Fall Dmg", C.fallCol, "noFall", function(on)
	local hum = getHum()
	if hum then applyNoFallState(hum, on) end
end)
stepRow(13, "Fall Cap", function() return S.fallCap end, function(v) S.fallCap = v end, 2, 10, 60, "%d")

sectionHeader(14, "UTILITY")

toggleRow(15, "Stick to Player", C.stkCol, "stick", function(on)
	if on then
		if S.fly then S.fly = false; stopFly() end
		local target = findNearestPlayer(STICK_RANGE)
		if target and startStick(target) then
			-- ok
		else
			S.stick = false
		end
	else
		stopStick()
	end
end)

stickTargetLbl = mk("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16),
	LayoutOrder = 16,
	BackgroundTransparency = 1,
	Text = "Target: —",
	TextColor3 = C.muted,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, scroll)
mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, stickTargetLbl)

updateStatusDot()

-- Fly control pad (muncuk saat Fly ON, mobile-friendly)
local pad = mk("Frame", {
	Size = UDim2.fromOffset(64, 134),
	Position = UDim2.new(1, -78, 1, -160),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local function holdBtn(txt, y, setter)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(0, y),
		Text = txt,
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.1,
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
holdBtn("↓", 70, function(v) downHeld = v end)

RunService.RenderStepped:Connect(function() pad.Visible = S.fly end)

---------------------------------------------------------------- RESPAWN
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	origWalk = hum.WalkSpeed
	flyObjs = {}
	stickObjs = {}
	stickTarget = nil
	hookedHum = nil
	if stickTargetLbl then stickTargetLbl.Text = "Target: —" end

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