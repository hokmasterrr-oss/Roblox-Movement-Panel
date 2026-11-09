--[[
  MOVEMENT PANEL v10 - pixel edition
  Pencipta: kemalgans12

  MOVE    Fly, Speed, Inf Jump, Anti-Grav, Air Walk, Water Walk
  GUARD   Anti-Mental, No Fall, Noclip
  VISION  ESP, Bright, Fullbright, No Fog, FOV
  UTIL    Teleport, Stick, TP Loop

  - Client-only. Taruh sebagai LocalScript di StarterPlayer > StarterPlayerScripts
    (atau jalankan lewat executor).
  - Tombol "-" di pojok jendela = minimize jadi kotak K (bisa digeser, tap untuk buka lagi).
  - Intro: tap layar untuk melewati. Matikan dengan CFG.intro = false.
]]

local CFG = { intro = true }
local CREDIT = "kemalgans12"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- ScreenGui dibuat paling awal supaya ESP & UI sama-sama bisa memakainya
local gui = Instance.new("ScreenGui")
gui.Name = "MovementPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okParent = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not okParent or not gui.Parent then
	gui.Parent = lp:WaitForChild("PlayerGui")
end

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
local friendCache = {}
local function isFriend(p)
	local v = friendCache[p.UserId]
	if v == nil then
		local ok, res = pcall(function() return lp:IsFriendsWith(p.UserId) end)
		v = ok and res or false
		friendCache[p.UserId] = v
	end
	return v
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
			obj.nameLbl.Text = (isFr and "* " or "") .. p.Name
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
	nameLbl.Font = Enum.Font.Arcade
	nameLbl.TextSize = 13
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Text = (isFr and "* " or "") .. p.Name
	nameLbl.Parent = bb
	local distLbl = Instance.new("TextLabel")
	distLbl.Size = UDim2.new(1, 0, 0.45, 0)
	distLbl.Position = UDim2.new(0, 0, 0.55, 0)
	distLbl.BackgroundTransparency = 1
	distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	distLbl.Font = Enum.Font.Arcade
	distLbl.TextSize = 11
	distLbl.TextStrokeTransparency = 0.4
	distLbl.Text = "-"
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

---------------------------------------------------------------- UI (pixel edition)
local FONT = Enum.Font.Arcade
local P = {
	ink = Color3.fromRGB(12, 14, 34), bg = Color3.fromRGB(29, 43, 83), bg2 = Color3.fromRGB(18, 25, 56),
	row = Color3.fromRGB(41, 58, 108), plum = Color3.fromRGB(126, 37, 83), plum2 = Color3.fromRGB(78, 22, 54),
	text = Color3.fromRGB(255, 241, 232), dim = Color3.fromRGB(131, 118, 156),
	ok = Color3.fromRGB(0, 228, 54), warn = Color3.fromRGB(255, 236, 39), bad = Color3.fromRGB(255, 0, 77),
	orange = Color3.fromRGB(255, 163, 0), blue = Color3.fromRGB(41, 173, 255), pink = Color3.fromRGB(255, 119, 168),
	peach = Color3.fromRGB(255, 204, 170), silver = Color3.fromRGB(194, 195, 199), lav = Color3.fromRGB(190, 170, 255),
	teal = Color3.fromRGB(0, 200, 190),
}

-- sprite 7x7: '#' = piksel menyala, baris dipisah '|'
local SPR = {
	fly    = "...#...|..###..|..###..|..###..|.#####.|#.###.#|...#...",
	speed  = ".......|#..#...|.#..#..|..#..#.|.#..#..|#..#...|.......",
	jump   = "...#...|..###..|.#.#.#.|...#...|...#...|.#####.|.......",
	grav   = "..###..|.#####.|.#####.|.#####.|..###..|...#...|...#...",
	air    = ".......|..##...|.#####.|#######|#######|.#####.|.......",
	water  = ".......|.#..#..|#.##.##|.......|.#..#..|#.##.##|.......",
	shield = "#######|#######|#######|#######|.#####.|..###..|...#...",
	chute  = ".#####.|#######|#.#.#.#|.#.#.#.|..#.#..|...#...|...#...",
	ghost  = "..###..|.#####.|##.#.##|#######|#######|#######|#.#.#.#",
	eye    = ".......|..###..|.#####.|###.###|.#####.|..###..|.......",
	sun    = "...#...|.#...#.|..###..|#.###.#|..###..|.#...#.|...#...",
	bulb   = "..###..|.#####.|.#####.|..###..|..###..|..#.#..|..###..",
	fog    = ".......|##.###.|.......|.###.##|.......|##.###.|.......",
	fov    = "##...##|#.....#|.......|...#...|.......|#.....#|##...##",
	loop   = "..#....|.######|..#....|.......|....#..|######.|....#..",
	up     = "...#...|..###..|.#####.|#######|...#...|...#...|...#...",
	down   = "...#...|...#...|...#...|#######|.#####.|..###..|...#...",
	check  = ".....#|....##|#..##.|.###..|..#...",
	k      = "##...##|##..##.|##.##..|####...|##.##..|##..##.|##...##",
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

-- kotak pixel: garis luar 2px + sorotan atas + bayangan bawah
local function box(parent, size, pos, fill, class)
	local o = mk(class or "Frame", { Size = size, Position = pos, BackgroundColor3 = P.ink, BorderSizePixel = 0 }, parent)
	if o:IsA("GuiButton") then o.Text = ""; o.AutoButtonColor = false end
	local f = mk("Frame", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = fill, BorderSizePixel = 0 }, o)
	mk("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = fill:Lerp(Color3.new(1, 1, 1), 0.22), BorderSizePixel = 0 }, f)
	mk("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = fill:Lerp(Color3.new(0, 0, 0), 0.35), BorderSizePixel = 0 }, f)
	return o, f
end

-- gambar sprite dari teks (baris piksel berurutan digabung jadi satu kotak)
local function sprite(parent, key, color, px, x, y)
	local h = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y) }, parent)
	local rows, wmax = 0, 0
	for line in SPR[key]:gmatch("[^|]+") do
		wmax = math.max(wmax, #line)
		local i = 1
		while true do
			local a, b = line:find("#+", i)
			if not a then break end
			mk("Frame", {
				Size = UDim2.fromOffset((b - a + 1) * px, px), Position = UDim2.fromOffset((a - 1) * px, rows * px),
				BackgroundColor3 = color, BorderSizePixel = 0,
			}, h)
			i = b + 1
		end
		rows += 1
	end
	h.Size = UDim2.fromOffset(wmax * px, rows * px)
	return h
end
local function tint(h, c)
	for _, f in ipairs(h:GetChildren()) do f.BackgroundColor3 = c end
end

-- teks otomatis mengecil kalau tidak muat (lebar font pixel beda-beda), maksimal sebesar "size"
local function txt(parent, s, size, color, pos, sz, align)
	local l = mk("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = s, Font = FONT, TextSize = size, TextColor3 = color,
		TextScaled = true, Position = pos, Size = sz or UDim2.fromScale(1, 1),
		TextXAlignment = align or Enum.TextXAlignment.Left,
	}, parent)
	mk("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 7 }, l)
	return l
end

-- geser jendela dengan jari / mouse; onTap dipanggil kalau cuma di-tap (tidak digeser)
local function drag(handle, target, onTap)
	handle.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local start, from, moved = input.Position, target.Position, false
		local conn = UIS.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				local d = i.Position - start
				if d.Magnitude > 4 then moved = true end
				target.Position = UDim2.new(from.X.Scale, from.X.Offset + d.X, from.Y.Scale, from.Y.Offset + d.Y)
			end
		end)
		local c2
		c2 = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				c2:Disconnect()
				if not moved and onTap then onTap() end
			end
		end)
	end)
end

-- tahan tombol = ulangi aksi (buat tombol - dan +)
local function holdRepeat(btn, fn)
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local alive = true
		local c
		c = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then alive = false; c:Disconnect() end
		end)
		task.spawn(function()
			fn()
			task.wait(0.4)
			while alive do fn(); task.wait(0.07) end
		end)
	end)
end

---------------------------------------------------------------- JENDELA
local W, H, TITLE_H, TAB_H, FOOT_H = 296, 304, 30, 26, 18
local refreshPlayerList, updateStickBtn, setTab

local container = mk("Frame", {
	Size = UDim2.fromOffset(W + 6, H + 6), Position = UDim2.new(0, 12, 0.14, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Visible = false,
}, gui)
mk("Frame", {
	Size = UDim2.fromOffset(W, H), Position = UDim2.fromOffset(6, 6),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0,
}, container)
local _, face = box(container, UDim2.fromOffset(W, H), nil, P.bg)

-- title bar
local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = P.plum, BorderSizePixel = 0 }, face)
mk("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, bar)
sprite(bar, "k", P.warn, 2, 8, 7)
txt(bar, "MOVEMENT PANEL", 14, P.text, UDim2.fromOffset(30, 0), UDim2.new(1, -124, 1, -2))
local led = mk("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(1, -92, 0.5, -5), BackgroundColor3 = P.dim, BorderSizePixel = 0 }, bar)
local stat = txt(bar, "IDLE", 12, P.dim, UDim2.new(1, -80, 0, 0), UDim2.fromOffset(52, TITLE_H - 2))
local miniBtn, miniFace = box(bar, UDim2.fromOffset(22, 20), UDim2.new(1, -28, 0.5, -11), P.plum2, "TextButton")
txt(miniFace, "-", 16, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
drag(bar, container)

local function updateStatus()
	local n = 0
	for _, v in pairs(S) do if v == true then n += 1 end end
	led.BackgroundColor3 = n > 0 and P.ok or P.dim
	stat.Text = n > 0 and (n .. " ON") or "IDLE"
	stat.TextColor3 = n > 0 and P.ok or P.dim
end

-- konten + footer (kredit)
local content = mk("Frame", {
	Size = UDim2.new(1, -12, 1, -(TITLE_H + TAB_H + 11 + FOOT_H + 4)), Position = UDim2.fromOffset(6, TITLE_H + TAB_H + 11),
	BackgroundTransparency = 1, BorderSizePixel = 0,
}, face)
local foot = mk("Frame", { Size = UDim2.new(1, 0, 0, FOOT_H), Position = UDim2.new(0, 0, 1, -FOOT_H), BackgroundColor3 = P.bg2, BorderSizePixel = 0 }, face)
mk("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, foot)
local credit = txt(foot, "by <font color=\"#FF77A8\">" .. CREDIT .. "</font>", 11, P.dim, UDim2.fromOffset(8, 2), UDim2.new(0.7, 0, 1, -2))
credit.RichText = true
txt(foot, "v10", 11, P.dim, UDim2.new(0.7, 0, 0, 2), UDim2.new(0.3, -8, 1, -2), Enum.TextXAlignment.Right)

-- tab + halaman
local tabs, pages = {}, {}
local tabList = { { "move", "MOVE" }, { "guard", "GUARD" }, { "vision", "VISION" }, { "util", "UTIL" } }
local TAB_W = (W - 4 - 12 - 12) / 4
for i, t in ipairs(tabList) do
	local name = t[1]
	local pg = mk("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = P.plum, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
	}, content)
	mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, pg)
	mk("UIPadding", { PaddingRight = UDim.new(0, 6) }, pg)
	pages[name] = pg
	local b, f = box(face, UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(6 + (i - 1) * (TAB_W + 4), TITLE_H + 5), P.bg2, "TextButton")
	tabs[name] = {
		face = f,
		lbl = txt(f, t[2], 12, P.dim, UDim2.new(), nil, Enum.TextXAlignment.Center),
		under = mk("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = P.warn, BorderSizePixel = 0, Visible = false }, f),
	}
	b.MouseButton1Click:Connect(function() setTab(name) end)
end

setTab = function(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do
		local on = (n == name)
		t.face.BackgroundColor3 = on and P.plum or P.bg2
		t.lbl.TextColor3 = on and P.text or P.dim
		t.under.Visible = on
	end
	currentTab = name
	if name == "util" and refreshPlayerList then pcall(refreshPlayerList) end
end

---------------------------------------------------------------- BARIS FITUR
-- o = { label, icon, color, key (toggle, opsional), on (callback), st = {get, set, step, min, max, fmt} (opsional) }
local function featureRow(page, order, o)
	local btn, f = box(page, UDim2.new(1, 0, 0, 30), nil, P.row, "TextButton")
	btn.LayoutOrder = order
	local stripe = mk("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = o.color, BorderSizePixel = 0, Visible = false }, f)
	local icon = sprite(f, o.icon, o.key and P.dim or o.color, 2, 10, 6)
	local right = (o.key and 26 or 0) + (o.st and (o.key and 86 or 88) or 0)
	txt(f, o.label, 14, P.text, UDim2.fromOffset(30, 0), UDim2.new(1, -(30 + right + 4), 1, 0))

	local cb, cbf, chk
	if o.key then
		cb = mk("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -17, 0.5, 0), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, f)
		cbf = mk("Frame", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = P.bg2, BorderSizePixel = 0 }, cb)
		chk = sprite(cbf, "check", P.ink, 2, 1, 2)
		chk.Visible = false
	end

	if o.st then
		local get, set, step, mn, mx, fmt = table.unpack(o.st)
		local sb = mk("Frame", { Size = UDim2.fromOffset(80, 18), Position = UDim2.new(1, o.key and -112 or -88, 0.5, -9), BackgroundTransparency = 1, BorderSizePixel = 0 }, f)
		local vb = mk("Frame", { Size = UDim2.fromOffset(40, 18), Position = UDim2.fromOffset(20, 0), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, sb)
		local vf = mk("Frame", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = P.bg2, BorderSizePixel = 0 }, vb)
		local val = txt(vf, "", 10, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
		local function show() val.Text = string.format(fmt, get()) end
		local function stepBtn(sym, x, dir)
			local b, bf = box(sb, UDim2.fromOffset(18, 18), UDim2.fromOffset(x, 0), P.bg, "TextButton")
			txt(bf, sym, 14, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
			holdRepeat(b, function() set(math.clamp(get() + dir * step, mn, mx)); show() end)
		end
		stepBtn("-", 0, -1)
		stepBtn("+", 62, 1)
		show()
	end

	local function refresh(animate)
		if not o.key then return end
		local on = S[o.key]
		stripe.Visible = on
		tint(icon, on and o.color or P.dim)
		cbf.BackgroundColor3 = on and o.color or P.bg2
		chk.Visible = on
		if animate then
			cb.Size = UDim2.fromOffset(24, 24)
			task.delay(0.06, function() cb.Size = UDim2.fromOffset(18, 18) end)
		end
		updateStatus()
	end
	btn.MouseButton1Click:Connect(function()
		if not o.key then return end
		S[o.key] = not S[o.key]
		if o.on then o.on(S[o.key]) end
		refresh(true)
	end)
	refresh(false)
	return { refresh = refresh }
end

-- MOVE
local flyRow = featureRow(pages.move, 1, {
	label = "Fly", icon = "fly", color = P.orange, key = "fly",
	st = { function() return S.flySpeed end, function(v) S.flySpeed = v end, 10, 10, 300, "%d" },
	on = function(on)
		if on then
			if S.stick then S.stick = false; stopStick(); updateStickBtn() end
			if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end
			if not startFly() then S.fly = false end
		else
			stopFly()
			local hum = getHum()
			if hum and S.speed then hum.WalkSpeed = S.walkSpeed end
		end
	end,
})
featureRow(pages.move, 2, {
	label = "Speed", icon = "speed", color = P.warn, key = "speed",
	st = { function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d" },
	on = function(on)
		local hum = getHum()
		if not hum then return end
		if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed
		else hum.WalkSpeed = origWalk end
	end,
})
featureRow(pages.move, 3, { label = "Inf Jump", icon = "jump", color = P.ok, key = "inf" })
featureRow(pages.move, 4, {
	label = "Anti-Grav", icon = "grav", color = P.pink, key = "anti",
	st = { function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx" },
	on = function(on) if not on then workspace.Gravity = DEFAULT_GRAVITY end end,
})
featureRow(pages.move, 5, {
	label = "Air Walk", icon = "air", color = P.silver, key = "walkAir",
	on = function(on) if not on then stopWalkAir() end end,
})
featureRow(pages.move, 6, { label = "Water Walk", icon = "water", color = P.teal, key = "walkWater" })

-- GUARD
featureRow(pages.guard, 1, {
	label = "Anti-Mental", icon = "shield", color = P.blue, key = "noFling",
	on = function(on)
		if not on then
			local hum = getHum()
			if hum then hum.PlatformStand = false end
		end
	end,
})
featureRow(pages.guard, 2, {
	label = "No Fall", icon = "chute", color = P.peach, key = "noFall",
	st = { function() return S.fallCap end, function(v) S.fallCap = v end, 2, 10, 60, "%d" },
	on = function(on)
		local hum = getHum()
		if hum then applyNoFallState(hum, on) end
	end,
})
featureRow(pages.guard, 3, { label = "Noclip", icon = "ghost", color = P.lav, key = "noclip", on = function(on) setNoclip(on) end })

-- VISION
featureRow(pages.vision, 1, {
	label = "ESP", icon = "eye", color = P.ok, key = "esp",
	on = function(on) if on then startESP() else stopESP() end end,
})
featureRow(pages.vision, 2, {
	label = "Bright", icon = "sun", color = P.warn, key = "brightShader",
	st = { function() return S.shaderLevel end, function(v)
		S.shaderLevel = v
		if S.brightShader then applyBrightShader(true) end
	end, 0.05, 0.1, 0.8, "%.2f" },
	on = function(on) applyBrightShader(on) end,
})
featureRow(pages.vision, 3, { label = "Fullbright", icon = "bulb", color = P.text, key = "fullbright", on = function(on) applyFullbright(on) end })
featureRow(pages.vision, 4, { label = "No Fog", icon = "fog", color = P.silver, key = "noFog", on = function(on) applyNoFog(on) end })
featureRow(pages.vision, 5, {
	label = "FOV", icon = "fov", color = P.blue,
	st = { function() return S.fov end, function(v) S.fov = v; applyFOV(v) end, 5, 70, 120, "%d" },
})

---------------------------------------------------------------- UTIL (daftar pemain)
local util = pages.util
local hdr = mk("Frame", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, BackgroundTransparency = 1, BorderSizePixel = 0 }, util)
local countLbl = txt(hdr, "PLAYERS 0", 12, P.dim, UDim2.new(), UDim2.new(1, -76, 1, 0))
local refreshBtn, refreshFace = box(hdr, UDim2.fromOffset(72, 20), UDim2.new(1, -72, 0, 0), P.bg, "TextButton")
local refreshTxt = txt(refreshFace, "REFRESH", 11, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)

local listBox, listFace = box(util, UDim2.new(1, 0, 0, 84), nil, P.bg2)
listBox.LayoutOrder = 2
playerListFrame = mk("ScrollingFrame", {
	Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = P.plum, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, listFace)
mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, playerListFrame)

targetLabel = txt(util, "TARGET  -", 11, P.dim, nil, UDim2.new(1, 0, 0, 16))
targetLabel.LayoutOrder = 3
local function updateTargetLabel()
	local name = "-"
	if S.stick and stickTarget then name = stickTarget.Name
	elseif selectedPlayer then name = selectedPlayer.Name end
	targetLabel.Text = "TARGET  " .. name
end

local act = mk("Frame", { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 4, BackgroundTransparency = 1, BorderSizePixel = 0 }, util)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, act)
local teleBtn, teleFace = box(act, UDim2.new(0.5, -3, 1, 0), nil, P.pink, "TextButton")
teleBtn.LayoutOrder = 1
local teleTxt = txt(teleFace, "TELEPORT", 13, P.ink, UDim2.new(), nil, Enum.TextXAlignment.Center)
local stickBtn, stickFace = box(act, UDim2.new(0.5, -3, 1, 0), nil, P.bg, "TextButton")
stickBtn.LayoutOrder = 2
local stickTxt = txt(stickFace, "STICK", 13, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)

updateStickBtn = function()
	stickTxt.Text = S.stick and "UNSTICK" or "STICK"
	stickTxt.TextColor3 = S.stick and P.warn or P.text
end

tpLoopRow = featureRow(util, 5, {
	label = "TP Loop", icon = "loop", color = P.orange, key = "tpLoop",
	on = function(on)
		if not on then return end
		if not selectedPlayer then
			selectedPlayer = findNearestPlayer(math.huge)
			if not selectedPlayer then S.tpLoop = false; return end
			updateTargetLabel()
			refreshPlayerList()
		end
		if S.stick then S.stick = false; stopStick(); updateStickBtn() end
		if S.fly then S.fly = false; stopFly(); flyRow.refresh(true) end
	end,
})

refreshPlayerList = function()
	for _, c in ipairs(playerListFrame:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if selectedPlayer and not isAlive(selectedPlayer) then
		selectedPlayer = nil
		if S.stick and stickManual then S.stick = false; stopStick(); updateStickBtn() end
		if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end
	end
	local list = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= lp and isAlive(p) then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
	countLbl.Text = "PLAYERS " .. #list
	if #list == 0 then
		txt(playerListFrame, "NO ONE ELSE HERE", 11, P.dim, nil, UDim2.new(1, 0, 0, 26), Enum.TextXAlignment.Center)
	end
	local myRoot = getRoot()
	local myPos = myRoot and myRoot.Position or Vector3.zero
	for i, p in ipairs(list) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local tRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local hp = hum and (hum.Health / math.max(hum.MaxHealth, 1)) or 1
		local hpCol = hp > 0.5 and P.ok or (hp > 0.25 and P.warn or P.bad)
		local dist = tRoot and (tRoot.Position - myPos).Magnitude or 0
		local sel, fr = (p == selectedPlayer), isFriend(p)
		local r = mk("TextButton", {
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, BackgroundColor3 = sel and P.plum or P.row,
			BorderSizePixel = 0, Text = "", AutoButtonColor = false,
		}, playerListFrame)
		mk("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(6, 8), BackgroundColor3 = hpCol, BorderSizePixel = 0 }, r)
		local nm = txt(r, (fr and "* " or "") .. p.Name, 12, fr and P.ok or P.text, UDim2.fromOffset(18, 0), UDim2.new(1, -66, 1, 0))
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		txt(r, formatDist(dist), 11, sel and P.text or P.dim, UDim2.new(1, -48, 0, 0), UDim2.fromOffset(44, 22), Enum.TextXAlignment.Right)
		r.MouseButton1Click:Connect(function()
			selectedPlayer = p
			updateTargetLabel()
			refreshPlayerList()
		end)
	end
	updateTargetLabel()
end

refreshBtn.MouseButton1Click:Connect(function()
	refreshTxt.Text = "..."
	refreshPlayerList()
	task.delay(0.4, function() refreshTxt.Text = "REFRESH" end)
end)

teleBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then
		selectedPlayer = findNearestPlayer(math.huge)
		if not selectedPlayer then targetLabel.Text = "NO PLAYERS ON SERVER"; return end
		updateTargetLabel()
		refreshPlayerList()
	end
	teleTxt.Text = "..."
	if teleportToPlayer(selectedPlayer) then
		targetLabel.Text = "TP OK  " .. selectedPlayer.Name
		task.delay(1, function() teleTxt.Text = "TELEPORT"; updateTargetLabel() end)
	else
		teleTxt.Text = "TELEPORT"
		targetLabel.Text = "TP FAILED"
		task.delay(1, updateTargetLabel)
	end
end)

stickBtn.MouseButton1Click:Connect(function()
	if S.stick then
		S.stick = false
		stopStick()
		updateStickBtn()
		updateTargetLabel()
		updateStatus()
		return
	end
	local target = selectedPlayer or findNearestPlayer(math.huge)
	if not target then return end
	if not selectedPlayer then
		selectedPlayer = target
		refreshPlayerList()
	end
	if S.tpLoop then S.tpLoop = false; tpLoopRow.refresh(true) end
	teleportToPlayer(target)
	if startStick(target, true) then
		S.stick = true
		updateStickBtn()
		updateTargetLabel()
		updateStatus()
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if currentTab == "util" and container.Visible then pcall(refreshPlayerList) end
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
		if S.stick and stickManual then S.stick = false; stopStick(); updateStickBtn() end
		if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end
	end
	task.delay(0.2, function() pcall(refreshPlayerList) end)
end)

---------------------------------------------------------------- MINIMIZE (kotak K) + PAD TERBANG
local kBtn, kFace = box(gui, UDim2.fromOffset(48, 48), UDim2.new(0, 12, 0.14, 0), P.plum, "TextButton")
kBtn.Visible = false
kBtn.ZIndex = 10
txt(kFace, "K", 28, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
task.spawn(function()
	local lit = false
	while true do
		task.wait(0.5)
		if kBtn.Visible then
			lit = not lit
			kBtn.BackgroundColor3 = lit and P.warn or P.ink
		end
	end
end)
drag(kBtn, kBtn, function()
	container.Position = kBtn.Position
	container.Visible = true
	kBtn.Visible = false
end)
miniBtn.MouseButton1Click:Connect(function()
	kBtn.Position = container.Position
	kBtn.Visible = true
	container.Visible = false
end)

local pad = mk("Frame", {
	Size = UDim2.fromOffset(52, 110), Position = UDim2.new(1, -66, 1, -140),
	BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
}, gui)
local function holdBtn(spr, y, setter)
	local b, f = box(pad, UDim2.fromOffset(52, 52), UDim2.fromOffset(0, y), P.bg, "TextButton")
	sprite(f, spr, P.text, 4, 10, 10)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(true) end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(false) end
	end)
end
holdBtn("up", 0, function(v) upHeld = v end)
holdBtn("down", 58, function(v) downHeld = v end)
RunService.RenderStepped:Connect(function() pad.Visible = S.fly end)

---------------------------------------------------------------- INTRO (boot screen) + BUKA JENDELA
local function openWindow(fast)
	container.Visible = true
	if not fast then
		for _, h in ipairs({ 8, 64, 150, 240 }) do
			container.Size = UDim2.fromOffset(W + 6, h)
			task.wait(0.05)
		end
	end
	container.Size = UDim2.fromOffset(W + 6, H + 6)
end

local function runIntro(done)
	local skip = false
	local ov = mk("TextButton", {
		Name = "Intro", Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.ink, BackgroundTransparency = 1,
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 50,
	}, gui)
	ov.MouseButton1Click:Connect(function() skip = true end)
	local function w(t) if not skip then task.wait(t) end end

	local CW, CH = 290, 142
	local card, cf = box(ov, UDim2.fromOffset(CW, CH), UDim2.new(0.5, -CW / 2, 0, -CH - 20), P.bg)
	card.ClipsDescendants = true
	sprite(cf, "k", P.warn, 3, 14, 10)
	local l1 = txt(cf, "", 12, P.dim, UDim2.fromOffset(44, 12), UDim2.fromOffset(220, 16))
	local l2s = txt(cf, "", 26, P.plum, UDim2.fromOffset(18, 38), UDim2.fromOffset(250, 30))
	local l2 = txt(cf, "", 26, P.warn, UDim2.fromOffset(16, 36), UDim2.fromOffset(250, 30))
	local l3 = txt(cf, "", 14, P.text, UDim2.fromOffset(16, 72), UDim2.fromOffset(250, 16))
	local _, bf = box(cf, UDim2.fromOffset(258, 18), UDim2.fromOffset(12, 94), P.bg2)
	local N, segs = 16, {}
	for i = 1, N do
		segs[i] = mk("Frame", { Size = UDim2.fromOffset(13, 8), Position = UDim2.fromOffset(8 + (i - 1) * 15, 3), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, bf)
	end
	local status = txt(cf, "", 11, P.dim, UDim2.fromOffset(16, 118), UDim2.fromOffset(250, 14))

	-- 1) layar meredup bertahap, kartu jatuh patah-patah
	for _, tr in ipairs({ 0.85, 0.7, 0.55 }) do ov.BackgroundTransparency = tr; w(0.04) end
	for i = 1, 4 do
		card.Position = UDim2.new(0.5, -CW / 2, 0.5, -CH / 2 - (4 - i) * 60)
		w(0.05)
	end

	-- 2) ketik teks satu per satu
	local function typeOut(lbls, s, d)
		for i = 1, #s do
			for _, l in ipairs(lbls) do l.Text = s:sub(1, i) .. "_" end
			w(d)
		end
		for _, l in ipairs(lbls) do l.Text = s end
	end
	typeOut({ l1 }, "CREATED BY", 0.03)
	typeOut({ l2s, l2 }, CREDIT, 0.05)
	typeOut({ l3 }, "MOVEMENT PANEL  V10", 0.02)

	-- 3) loading bar berwarna
	local ramp = { P.bad, P.orange, P.warn, P.ok }
	local msg = { "INIT PHYSICS", "LOAD MODULES", "BUILD UI", "READY!" }
	for i = 1, N do
		segs[i].BackgroundColor3 = ramp[math.ceil(i / N * #ramp)]
		status.Text = msg[math.ceil(i / N * #msg)] .. "  " .. math.floor(i / N * 100) .. "%"
		w(0.055)
	end
	for _ = 1, 3 do
		status.TextColor3 = P.warn; w(0.07)
		status.TextColor3 = P.ok; w(0.07)
	end
	w(0.1)

	-- 4) kartu menciut, layar terang lagi
	local fades = { 0.7, 0.85, 1 }
	for i, h in ipairs({ 90, 40, 8 }) do
		card.Size = UDim2.fromOffset(CW, h)
		card.Position = UDim2.new(0.5, -CW / 2, 0.5, -h / 2)
		ov.BackgroundTransparency = fades[i]
		w(0.04)
	end
	ov:Destroy()
	done()
end

---------------------------------------------------------------- INIT
setTab("move")
updateStatus()
task.spawn(pcall, refreshPlayerList) -- jangan tahan intro sambil menunggu cek teman
if CFG.intro then task.spawn(runIntro, openWindow) else openWindow(true) end

---------------------------------------------------------------- RESPAWN
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
