--[[
  Movement Panel (FINAL v9): 
  Fly / Speed / Inf Jump / Anti-Grav / Walk on Air / Walk on Water /
  Anti-Mental / No Fall / Noclip / Stick (smooth) / Teleport / TP Loop /
  ESP / Bright / Fullbright / No Fog / FOV
  - Client-only. LocalScript di StarterPlayer > StarterPlayerScripts.
  - Tab: MOVE / GUARD / VISION / UTIL.
  - Minimize = tombol K (draggable, glow).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local C = {
	bgTop    = Color3.fromRGB(32, 36, 48),
	bgBot    = Color3.fromRGB(14, 16, 22),
	title    = Color3.fromRGB(40, 44, 58),
	card     = Color3.fromRGB(36, 41, 54),
	cardHov  = Color3.fromRGB(46, 52, 68),
	trackOff = Color3.fromRGB(56, 62, 78),
	border   = Color3.fromRGB(60, 66, 84),
	text     = Color3.fromRGB(242, 245, 252),
	muted    = Color3.fromRGB(150, 158, 178),
	accent   = Color3.fromRGB(130, 168, 255),
	accent2  = Color3.fromRGB(180, 140, 255),
	accent3  = Color3.fromRGB(245, 120, 190),
	success  = Color3.fromRGB(78, 226, 132),
	warn     = Color3.fromRGB(255, 195, 42),
	danger   = Color3.fromRGB(248, 113, 113),
	flyCol   = Color3.fromRGB(130, 168, 255),
	spdCol   = Color3.fromRGB(255, 195, 42),
	jmpCol   = Color3.fromRGB(78, 226, 132),
	grvCol   = Color3.fromRGB(175, 145, 255),
	airCol   = Color3.fromRGB(140, 220, 255),
	waterCol = Color3.fromRGB(80, 180, 255),
	noclipCol= Color3.fromRGB(220, 130, 255),
	antiCol  = Color3.fromRGB(50, 220, 200),
	stkCol   = Color3.fromRGB(255, 150, 65),
	fallCol  = Color3.fromRGB(245, 120, 190),
	espCol   = Color3.fromRGB(78, 226, 132),
	shaderCol= Color3.fromRGB(255, 210, 90),
	fullCol  = Color3.fromRGB(255, 235, 160),
	fogCol   = Color3.fromRGB(180, 200, 230),
	fovCol   = Color3.fromRGB(160, 200, 255),
}

local S = {
	fly = false, flySpeed = 60,
	speed = false, walkSpeed = 50,
	inf = false,
	anti = false, gravFactor = 0.15,
	walkAir = false,
	walkWater = false,
	noFling = false,
	noFall = false, fallCap = 30,
	noclip = false,
	stick = false,
	tpLoop = false,
	esp = false,
	brightShader = false,
	fullbright = false,
	noFog = false,
	fov = 70,
	shaderLevel = 0.25,
}
local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local stickTarget = nil
local stickManual = false
local stickOrigWS, stickOrigJP = nil, nil
local selectedPlayer = nil
local targetLabel = nil
local playerListFrame = nil
local currentTab = nil
local hookedHum = nil
local tpLoopRow = nil
local espObjs = {}
local fullbrightSaved = nil
local fogSaved = nil
local noclipTracked = {}
local ANTI_MAX_VEL = 45
local ANTI_VIOLENT = 100
local STICK_RANGE = 60
local STICK_OFFSET = CFrame.new(0, 0.4, 1.2)
local STICK_LERP_RATE = 20
local WALK_AIR_LV_NAME = "MP_WalkAirLV"
local WALK_AIR_ATT_NAME = "MP_WalkAirAtt"

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
local function isFriend(p)
	local ok, res = pcall(function() return lp:IsFriendsWith(p.UserId) end)
	return ok and res or false
end

-- FLY
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

-- WALK ON AIR (LinearVelocity — anti drift + walkable)
local function stopWalkAir()
	local root = getRoot()
	if not root then return end
	local lv = root:FindFirstChild(WALK_AIR_LV_NAME)
	if lv then lv:Destroy() end
	local att = root:FindFirstChild(WALK_AIR_ATT_NAME)
	if att then att:Destroy() end
end

local function walkAirTick()
	if not S.walkAir then
		stopWalkAir()
		return
	end
	local root = getRoot()
	local hum = getHum()
	if not root or not hum then return end
	if S.fly or S.stick or S.tpLoop then
		stopWalkAir()
		return
	end

	local st = hum:GetState()
	local airborne = (st == Enum.HumanoidStateType.Freefall
		or st == Enum.HumanoidStateType.FallingDown)
	if not airborne and (st == Enum.HumanoidStateType.Running
		or st == Enum.HumanoidStateType.Landed) then
		airborne = (hum.FloorMaterial == Enum.Material.Air)
	end

	if not airborne then
		stopWalkAir()
		return
	end

	local lv = root:FindFirstChild(WALK_AIR_LV_NAME)
	if not lv then
		local att = root:FindFirstChild(WALK_AIR_ATT_NAME)
		if not att then
			att = Instance.new("Attachment")
			att.Name = WALK_AIR_ATT_NAME
			att.Parent = root
		end
		lv = Instance.new("LinearVelocity")
		lv.Name = WALK_AIR_LV_NAME
		lv.Attachment0 = att
		lv.MaxForce = math.huge
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = Vector3.zero
		lv.Parent = root
	end

	local move = hum.MoveDirection or Vector3.zero
	local speed = hum.WalkSpeed
	if speed <= 0 then speed = 16 end
	local targetX = move.X * speed
	local targetZ = move.Z * speed
	local current = root.AssemblyLinearVelocity
	lv.VectorVelocity = Vector3.new(
		current.X + (targetX - current.X) * 0.35,
		0,
		current.Z + (targetZ - current.Z) * 0.35
	)

	if st == Enum.HumanoidStateType.Freefall
		or st == Enum.HumanoidStateType.FallingDown then
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- WALK ON WATER
local function walkWaterTick()
	if not S.walkWater or S.fly or S.stick or S.tpLoop then return end
	local root = getRoot()
	local hum = getHum()
	if not root or not hum then return end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Swimming then
		local v = root.AssemblyLinearVelocity
		if v.Y < 2 then
			root.AssemblyLinearVelocity = Vector3.new(v.X, 2, v.Z)
		end
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- NOCLIP
local function setNoclip(on)
	local char = lp.Character
	if not char then return end
	if on then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				pcall(function() part.CanCollide = false end)
				noclipTracked[part] = true
			end
		end
	else
		for part in pairs(noclipTracked) do
			if part and part.Parent then
				pcall(function() part.CanCollide = true end)
			end
		end
		noclipTracked = {}
	end
end

local function noclipTick()
	if not S.noclip then return end
	local char = lp.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			pcall(function() part.CanCollide = false end)
			noclipTracked[part] = true
		end
	end
	local root = getRoot()
	if root and not S.fly and not S.stick and not S.walkAir then
		local v = root.AssemblyLinearVelocity
		if v.Y < 0 then
			root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
		end
	end
	local hum = getHum()
	if hum then
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Freefall
			or st == Enum.HumanoidStateType.FallingDown then
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
	end
end

-- NO FALL
local function applyNoFallState(hum, enabled)
	if not hum then return end
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled) end)
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

-- TELEPORT
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

-- STICK
local COLLISION_GROUP = "MPStick"

local function ensureCollision()
	pcall(function() PhysicsService:RegisterCollisionGroup(COLLISION_GROUP) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", false) end)
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
	stickTarget = nil
	stickManual = false
	setGroup(lp.Character, "Default")
	local hum = getHum()
	if hum and keepState ~= true then
		hum.PlatformStand = false
		hum.AutoRotate = true
		if stickOrigWS then hum.WalkSpeed = stickOrigWS end
		if stickOrigJP then
			if hum.UseJumpPower then hum.JumpPower = stickOrigJP
			else hum.JumpHeight = stickOrigJP end
		end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	stickOrigWS = nil
	stickOrigJP = nil
end

local function startStick(targetPlayer, manual)
	stopStick(true)
	local myChar = lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not hum or not targetPlayer or not targetPlayer.Character then return false end
	local tRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not tRoot then return false end
	ensureCollision()
	setGroup(myChar, COLLISION_GROUP)
	stickOrigWS = hum.WalkSpeed
	stickOrigJP = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
	hum.PlatformStand = true
	hum.AutoRotate = false
	hum.WalkSpeed = 0
	if hum.UseJumpPower then hum.JumpPower = 0 else hum.JumpHeight = 0 end
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	stickTarget = targetPlayer
	stickManual = manual or (targetPlayer == selectedPlayer)
	myRoot.CFrame = tRoot.CFrame * STICK_OFFSET
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- ANTI-MENTAL
local function antiFlingTick()
	if not S.noFling or S.stick or S.fly then return end
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = getHum()
	if not root or not hum then return end
	for _, c in ipairs(root:GetChildren()) do
		if c:IsA("Weld") or c:IsA("WeldConstraint") then
			local other = (c.Part0 == root) and c.Part1 or c.Part0
			if other and not other:IsDescendantOf(char) then c:Destroy() end
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

-- ESP
local function clearESP()
	for _, obj in pairs(espObjs) do
		if obj.hl then obj.hl:Destroy() end
		if obj.bb then obj.bb:Destroy() end
	end
	espObjs = {}
end

local function makeESPFor(p)
	if p == lp or not p.Character then return end
	local isFr = isFriend(p)
	local fillColor = isFr and Color3.fromRGB(80, 220, 130) or Color3.fromRGB(250, 100, 100)
	local outlineColor = isFr and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(255, 150, 150)
	if espObjs[p] then
		local obj = espObjs[p]
		if obj.hl then
			obj.hl.Adornee = p.Character
			obj.hl.FillColor = fillColor
			obj.hl.OutlineColor = outlineColor
		end
		if obj.bb then obj.bb.Adornee = p.Character:FindFirstChild("Head") end
		if obj.nameLbl then
			obj.nameLbl.Text = (isFr and "★ " or "") .. p.Name
			obj.nameLbl.TextColor3 = fillColor
		end
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = fillColor
	hl.FillTransparency = 0.55
	hl.OutlineColor = outlineColor
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = p.Character
	hl.Parent = gui
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 32)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = p.Character:FindFirstChild("Head")
	bb.Parent = gui
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = fillColor
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Text = (isFr and "★ " or "") .. p.Name
	nameLbl.Parent = bb
	local distLbl = Instance.new("TextLabel")
	distLbl.Size = UDim2.new(1, 0, 0.45, 0)
	distLbl.Position = UDim2.new(0, 0, 0.55, 0)
	distLbl.BackgroundTransparency = 1
	distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	distLbl.Font = Enum.Font.Gotham
	distLbl.TextSize = 11
	distLbl.TextStrokeTransparency = 0.4
	distLbl.Text = "—"
	distLbl.Parent = bb
	espObjs[p] = { hl = hl, bb = bb, nameLbl = nameLbl, distLbl = distLbl }
end

local function startESP()
	clearESP()
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= lp then makeESPFor(p) end
	end
end
local function stopESP() clearESP() end

task.spawn(function()
	while true do
		task.wait(0.2)
		if S.esp then
			local myRoot = getRoot()
			if myRoot then
				local myPos = myRoot.Position
				for p, obj in pairs(espObjs) do
					if obj.distLbl and p.Character then
						local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
						if tRoot then
							obj.distLbl.Text = formatDist((tRoot.Position - myPos).Magnitude)
						end
					end
				end
			end
		end
	end
end)

-- SHADER
local function applyBrightShader(enabled)
	local cc = Lighting:FindFirstChild("MP_BrightShader")
	local bloom = Lighting:FindFirstChild("MP_BrightBloom")
	if not enabled then
		if cc then cc:Destroy() end
		if bloom then bloom:Destroy() end
		return
	end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MP_BrightShader"
		cc.Contrast = 0.08
		cc.Saturation = 0.05
		cc.TintColor = Color3.fromRGB(255, 255, 255)
		cc.Parent = Lighting
	end
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "MP_BrightBloom"
		bloom.Intensity = 0.2
		bloom.Size = 24
		bloom.Threshold = 0.9
		bloom.Parent = Lighting
	end
	cc.Brightness = S.shaderLevel
end

local function applyFullbright(enabled)
	if enabled then
		if not fullbrightSaved then
			fullbrightSaved = {
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
			}
		end
		Lighting.Ambient = Color3.fromRGB(185, 185, 185)
		Lighting.OutdoorAmbient = Color3.fromRGB(185, 185, 185)
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
	elseif fullbrightSaved then
		Lighting.Ambient = fullbrightSaved.Ambient
		Lighting.OutdoorAmbient = fullbrightSaved.OutdoorAmbient
		Lighting.Brightness = fullbrightSaved.Brightness
		Lighting.ClockTime = fullbrightSaved.ClockTime
		fullbrightSaved = nil
	end
end

task.spawn(function()
	while true do
		task.wait(0.6)
		if S.fullbright and Lighting.Brightness < 1.5 then
			Lighting.Brightness = 2
			Lighting.Ambient = Color3.fromRGB(185, 185, 185)
			Lighting.OutdoorAmbient = Color3.fromRGB(185, 185, 185)
		end
	end
end)

local function applyNoFog(enabled)
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if enabled then
		if not fogSaved then
			fogSaved = {
				FogEnd = Lighting.FogEnd,
				FogStart = Lighting.FogStart,
				atmosDensity = atmos and atmos.Density or nil,
			}
		end
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
		if atmos then atmos.Density = 0 end
	elseif fogSaved then
		Lighting.FogEnd = fogSaved.FogEnd
		Lighting.FogStart = fogSaved.FogStart
		if atmos and fogSaved.atmosDensity then atmos.Density = fogSaved.atmosDensity end
		fogSaved = nil
	end
end

local function applyFOV(v) cam.FieldOfView = v end

-- PRE-SIM
RunService.PreSimulation:Connect(function()
	if S.noFall and not S.stick and not S.fly and not S.tpLoop and not S.walkAir and not S.noclip then
		local root = getRoot()
		if root then
			local v = root.AssemblyLinearVelocity
			if v.Y < -S.fallCap then
				root.AssemblyLinearVelocity = Vector3.new(v.X, -S.fallCap, v.Z)
			end
		end
	end
end)

-- MAIN HEARTBEAT
RunService.Heartbeat:Connect(function(dt)
	if S.speed and not S.fly and not S.stick and not S.tpLoop then
		local hum = getHum()
		if hum then hum.WalkSpeed = S.walkSpeed end
	end
	if S.anti then workspace.Gravity = DEFAULT_GRAVITY * S.gravFactor end
	antiFlingTick()
	walkAirTick()
	walkWaterTick()
	noclipTick()

	if S.stick then
		local myChar = lp.Character
		local myRoot = getRoot()
		local myHum = getHum()
		if not myRoot or not myHum or not myChar then
			S.stick = false
			stopStick()
		else
			if myHum:GetState() ~= Enum.HumanoidStateType.Physics then
				myHum:ChangeState(Enum.HumanoidStateType.Physics)
			end
			if myHum.AutoRotate then myHum.AutoRotate = false end
			if not myHum.PlatformStand then myHum.PlatformStand = true end
			local tChar = stickTarget and stickTarget.Character
			local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
			local alive = isAlive(stickTarget) and tRoot
			if not alive then
				if stickManual then
					S.stick = false
					stopStick()
					selectedPlayer = nil
				else
					local nt = findNearestPlayer(STICK_RANGE)
					if nt then
						stopStick(true)
						if not startStick(nt, false) then
							S.stick = false
							stopStick()
						end
					else
						S.stick = false
						stopStick()
					end
				end
			else
				local targetCF = tRoot.CFrame * STICK_OFFSET
				local alpha = 1 - math.exp(-dt * STICK_LERP_RATE)
				myRoot.CFrame = myRoot.CFrame:Lerp(targetCF, alpha)
				myRoot.AssemblyLinearVelocity = Vector3.zero
				myRoot.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.15)
		if S.tpLoop then
			if selectedPlayer and isAlive(selectedPlayer) then
				local myRoot = getRoot()
				local tRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot and tRoot then
					if (tRoot.Position - myRoot.Position).Magnitude > 4 then
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

-- INPUT
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

-- UI
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

local FRAME_W = 258
local TITLE_H = 40
local TAB_H = 34
local TAB_HEIGHTS = { move = 360, guard = 280, vision = 300, util = 356 }
local NUM_TABS = 4
local TAB_GAP = 4
local TAB_W = (FRAME_W - 16 - (NUM_TABS - 1) * TAB_GAP) / NUM_TABS
local function tabXOffset(idx) return (idx - 1) * (TAB_W + TAB_GAP) end

local container = mk("Frame", {
	Size = UDim2.fromOffset(FRAME_W + 10, TAB_HEIGHTS.move + 10),
	Position = UDim2.new(0, 14, 0.18, 0),
	BackgroundTransparency = 1,
}, gui)

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
		ColorSequenceKeypoint.new(1, C.accent3),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, titleAccent)

for i = 1, 3 do
	mk("Frame", {
		Size = UDim2.fromOffset(3, 3),
		Position = UDim2.fromOffset(8, 15 + (i - 1) * 6),
		BackgroundColor3 = C.muted,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, titleBar)
end

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

local dragging = false
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = container.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		container.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

local tabBar = mk("Frame", {
	Size = UDim2.new(1, -16, 0, TAB_H - 6),
	Position = UDim2.fromOffset(8, TITLE_H + 3),
	BackgroundTransparency = 1,
}, frame)

local tabIndicator = mk("Frame", {
	Size = UDim2.fromOffset(TAB_W, TAB_H - 6),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	ZIndex = 1,
}, tabBar)
mk("UICorner", { CornerRadius = UDim.new(0, 7) }, tabIndicator)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.accent),
		ColorSequenceKeypoint.new(0.5, C.accent2),
		ColorSequenceKeypoint.new(1, C.accent3),
	}),
}, tabIndicator)

local pages = {}
local tabBtns = {}
local tabOrder = {}

local function createTab(name, label, index)
	tabOrder[index] = name
	local btn = mk("TextButton", {
		Size = UDim2.fromOffset(TAB_W, TAB_H - 6),
		Position = UDim2.fromOffset(tabXOffset(index), 0),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = C.muted,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		AutoButtonColor = false,
		ZIndex = 2,
	}, tabBar)
	mk("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
	tabBtns[name] = btn
	return btn
end

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
pages.vision = makePage()
pages.util = makePage()

local function updateTargetLabel()
	local name = "—"
	if S.stick and stickTarget then name = stickTarget.Name
	elseif selectedPlayer then name = selectedPlayer.Name end
	if targetLabel then targetLabel.Text = "Target: " .. name end
end

local function setTab(name, animate)
	local idx = 0
	for i, n in ipairs(tabOrder) do
		if n == name then idx = i; break end
	end
	if idx == 0 then return end
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, b in pairs(tabBtns) do
		local active = (n == name)
		b.BackgroundTransparency = active and 1 or 0
		TweenService:Create(b, TweenInfo.new(0.15), {
			TextColor3 = active and Color3.new(1, 1, 1) or C.muted,
		}):Play()
	end
	local targetX = tabXOffset(idx)
	if animate ~= false then
		TweenService:Create(tabIndicator, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 0),
		}):Play()
	else
		tabIndicator.Position = UDim2.fromOffset(targetX, 0)
	end
	currentTab = name
	local h = TAB_HEIGHTS[name] or 296
	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(FRAME_W, h),
	}):Play()
	TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(FRAME_W + 10, h + 10),
	}):Play()
end

local function updateStatus()
	local n = 0
	for _, v in pairs(S) do if v == true then n = n + 1 end end
	local active = n > 0
	local color = active and C.success or C.muted
	TweenService:Create(statusDot, TweenInfo.new(0.2), { BackgroundColor3 = color }):Play()
	TweenService:Create(statusText, TweenInfo.new(0.2), { TextColor3 = color }):Play()
	statusText.Text = active and (n .. " ON") or "IDLE"
end

local function toggleRow(parent, order, icon, label, color, key, onChange)
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
	mk("TextLabel", {
		Size = UDim2.fromOffset(20, 30),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = icon,
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, row)
	mk("TextLabel", {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local track = mk("Frame", {
		Size = UDim2.fromOffset(32, 18),
		Position = UDim2.new(1, -42, 0.5, -9),
		BackgroundColor3 = C.trackOff,
		BorderSizePixel = 0,
	}, row)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local trackStroke = mk("UIStroke", { Color = Color3.fromRGB(38, 42, 54), Thickness = 1, Transparency = 0.5 }, track)
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
			TweenService:Create(knob, ti, { Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2) }):Play()
			TweenService:Create(track, ti, { BackgroundColor3 = on and color or C.trackOff }):Play()
			TweenService:Create(trackStroke, ti, {
				Color = on and color or Color3.fromRGB(38, 42, 54),
				Transparency = on and 0.2 or 0.5,
			}):Play()
			TweenService:Create(row, ti, { BackgroundColor3 = on and C.cardHov or C.card }):Play()
			TweenService:Create(rowStroke, ti, {
				Color = on and color or C.border,
				Transparency = on and 0.3 or 0.55,
			}):Play()
		else
			knob.Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2)
			track.BackgroundColor3 = on and color or C.trackOff
			trackStroke.Color = on and color or Color3.fromRGB(38, 42, 54)
			trackStroke.Transparency = on and 0.2 or 0.5
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
	minus.MouseButton1Click:Connect(function() set(math.clamp(get() - step, min, max)); refresh() end)
	plus.MouseButton1Click:Connect(function() set(math.clamp(get() + step, min, max)); refresh() end)
	refresh()
end

-- MOVE PAGE
toggleRow(pages.move, 1, "✈", "Fly", C.flyCol, "fly", function(on)
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
toggleRow(pages.move, 3, "»", "Speed Boost", C.spdCol, "speed", function(on)
	local hum = getHum()
	if not hum then return end
	if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
	else hum.WalkSpeed = origWalk end
end)
stepRow(pages.move, 4, "Walk Speed", function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d")
toggleRow(pages.move, 5, "⇑", "Infinite Jump", C.jmpCol, "inf")
toggleRow(pages.move, 6, "☁", "Anti-Gravity", C.grvCol, "anti", function(on)
	if not on then workspace.Gravity = DEFAULT_GRAVITY end
end)
stepRow(pages.move, 7, "Gravity", function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx")
toggleRow(pages.move, 8, "⤒", "Walk on Air", C.airCol, "walkAir", function(on)
	if not on then stopWalkAir() end
end)
toggleRow(pages.move, 9, "≈", "Walk on Water", C.waterCol, "walkWater")

-- GUARD PAGE
toggleRow(pages.guard, 1, "◈", "Anti-Mental", C.antiCol, "noFling", function(on)
	if not on then
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end
end)
toggleRow(pages.guard, 2, "✧", "No Fall Damage", C.fallCol, "noFall", function(on)
	local hum = getHum()
	if hum then applyNoFallState(hum, on) end
end)
stepRow(pages.guard, 3, "Fall Cap", function() return S.fallCap end, function(v) S.fallCap = v end, 2, 10, 60, "%d")
toggleRow(pages.guard, 4, "◇", "Noclip", C.noclipCol, "noclip", function(on)
	setNoclip(on)
end)

-- VISION PAGE
toggleRow(pages.vision, 1, "◉", "ESP Players", C.espCol, "esp", function(on)
	if on then startESP() else stopESP() end
end)
toggleRow(pages.vision, 2, "☀", "Bright Mode", C.shaderCol, "brightShader", function(on)
	applyBrightShader(on)
end)
stepRow(pages.vision, 3, "Bright Lvl", function() return S.shaderLevel end, function(v)
	S.shaderLevel = v
	if S.brightShader then applyBrightShader(true) end
end, 0.05, 0.1, 0.8, "%.2f")
toggleRow(pages.vision, 4, "☼", "Fullbright", C.fullCol, "fullbright", function(on)
	applyFullbright(on)
end)
toggleRow(pages.vision, 5, "≈", "No Fog", C.fogCol, "noFog", function(on)
	applyNoFog(on)
end)
stepRow(pages.vision, 6, "FOV", function() return S.fov end, function(v)
	S.fov = v
	applyFOV(v)
end, 5, 70, 120, "%d")

-- UTILITY PAGE
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
mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, playerListFrame)

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

tpLoopRow = toggleRow(pages.util, 5, "↺", "TP Loop (chase)", C.accent, "tpLoop", function(on)
	if on then
		if not selectedPlayer then
			selectedPlayer = findNearestPlayer(math.huge)
			if not selectedPlayer then
				S.tpLoop = false
				return
			end
			updateTargetLabel()
			if refreshPlayerList then refreshPlayerList() end
		end
		if S.stick then
			S.stick = false
			stopStick()
			updateStickBtn()
		end
		if S.fly then S.fly = false; stopFly() end
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
		if p ~= lp and isAlive(p) then table.insert(list, p) end
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
		local hpColor = hpPct > 0.5 and C.success or (hpPct > 0.25 and C.warn or C.danger)
		local dist = tRoot and (tRoot.Position - myPos).Magnitude or 0
		local isSel = (p == selectedPlayer)
		local isFr = isFriend(p)

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
			Text = (isFr and "★ " or "") .. p.Name,
			TextColor3 = isFr and Color3.fromRGB(120, 255, 180) or (isSel and Color3.new(1,1,1) or C.text),
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
			TextColor3 = isSel and Color3.new(1,1,1) or C.muted,
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
		task.delay(0.5, function()
			pcall(refreshPlayerList)
			if S.esp then makeESPFor(p) end
			if S.noclip and p == lp then
				noclipTracked = {}
				task.wait(0.1)
				setNoclip(true)
			end
		end)
	end)
end
for _, p in pairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(function(p)
	watchPlayer(p)
	task.delay(0.3, function()
		pcall(refreshPlayerList)
		if S.esp then makeESPFor(p) end
	end)
end)
Players.PlayerRemoving:Connect(function(p)
	if espObjs[p] then
		if espObjs[p].hl then espObjs[p].hl:Destroy() end
		if espObjs[p].bb then espObjs[p].bb:Destroy() end
		espObjs[p] = nil
	end
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

-- INIT
createTab("move", "MOVE", 1).MouseButton1Click:Connect(function() setTab("move") end)
createTab("guard", "GUARD", 2).MouseButton1Click:Connect(function() setTab("guard") end)
createTab("vision", "VISION", 3).MouseButton1Click:Connect(function() setTab("vision") end)
createTab("util", "UTIL", 4).MouseButton1Click:Connect(function()
	setTab("util")
	if refreshPlayerList then refreshPlayerList() end
end)

setTab("move", false)
updateStatus()
pcall(refreshPlayerList)

-- K MINIMIZE BUTTON
local KB_SIZE = 56
local kBtn = mk("TextButton", {
	Size = UDim2.fromOffset(KB_SIZE, KB_SIZE),
	Position = UDim2.new(0, 14, 0.18, 0),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	Text = "K",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 10,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, kBtn)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.accent),
		ColorSequenceKeypoint.new(0.5, C.accent2),
		ColorSequenceKeypoint.new(1, C.accent3),
	}),
	Rotation = 45,
}, kBtn)
local kStroke = mk("UIStroke", { Color = C.accent2, Thickness = 2, Transparency = 0.3 }, kBtn)

task.spawn(function()
	while true do
		task.wait(0.9)
		if kBtn.Visible then
			TweenService:Create(kStroke, TweenInfo.new(0.45), { Transparency = 0 }):Play()
			task.wait(0.45)
			TweenService:Create(kStroke, TweenInfo.new(0.45), { Transparency = 0.4 }):Play()
		end
	end
end)

local kDragging = false
local kDragStart, kStartPos, kMoved = nil, nil, false

kBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		kDragging = true
		kMoved = false
		kDragStart = input.Position
		kStartPos = kBtn.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				kDragging = false
				if not kMoved then
					container.Position = kBtn.Position
					container.Visible = true
					kBtn.Visible = false
				end
			end
		end)
	end
end)

UIS.InputChanged:Connect(function(input)
	if kDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - kDragStart
		if delta.Magnitude > 4 then kMoved = true end
		kBtn.Position = UDim2.new(
			kStartPos.X.Scale, kStartPos.X.Offset + delta.X,
			kStartPos.Y.Scale, kStartPos.Y.Offset + delta.Y)
	end
end)

miniBtn.MouseButton1Click:Connect(function()
	kBtn.Position = UDim2.new(
		container.Position.X.Scale, container.Position.X.Offset,
		container.Position.Y.Scale, container.Position.Y.Offset)
	kBtn.Visible = true
	container.Visible = false
end)

-- FLY PAD
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

-- RESPAWN
local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	origWalk = hum.WalkSpeed
	flyObjs = {}
	stickTarget = nil
	stickManual = false
	hookedHum = nil
	noclipTracked = {}
	stopWalkAir()
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
	if S.noclip then
		task.wait(0.1)
		setNoclip(true)
	end
end
lp.CharacterAdded:Connect(onCharacter)
if lp.Character then task.spawn(onCharacter, lp.Character) end