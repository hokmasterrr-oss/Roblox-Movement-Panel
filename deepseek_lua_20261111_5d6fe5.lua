--[[
  MOVEMENT PANEL v28 - GLOWING PIXEL EDITION
  Tab: MOVE | GUARD | VISION | UTIL | VISUAL
  
  FITUR BARU:
  - UI Animations (Glow/kedip di bingkai, tab, & tombol)
  - Waypoints (Save & TP lokasi)
  - Anti-AFK (Anti kick pas diem)
  - 15 Efek Visual
]]

local CFG = { intro = true }
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "MovementPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not ok or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local S = {
	fly=false, flySpeed=60, speed=false, walkSpeed=50, inf=false,
	anti=false, gravFactor=0.15, walkAir=false, walkWater=false,
	noFling=false, noFall=false, fallCap=30, noclip=false,
	stick=false, tpLoop=false, esp=false, brightShader=false,
	fullbright=false, noFog=false, fov=70, shaderLevel=0.25,
	cinemaHD=false, cinemaDoF=false, cinemaRetro=false, cinemaBars=false, cinemaClean=false,
	cinemaBloom=false, cinemaSunrays=false, cinemaBWM=false, cinemaCyberpunk=false,
	cinemaSepia=false, cinemaBlur=false, cinemaNightvision=false, cinemaNegative=false,
	cinemaDreamy=false, cinemaFisheye=false, autorespawn=false, antiAFK=false
}

local ccHD, ccBWM, ccCyberpunk, ccSepia, ccNightvision, ccNegative, ccDreamy, ccRetro
local dofObj, blurRetro, blurMotion, bloomObj, sunraysObj
local uiBarsTop, uiBarsBottom, uiVhsScanlines, uiVhsVignette, uiCleanExit

local DEFAULT_GRAVITY = workspace.Gravity
local origWalk = 16
local upHeld, downHeld = false, false
local flyObjs = {}
local stickTarget, stickManual, stickOrigWS, stickOrigJP
local selectedPlayer, targetLabel, playerListFrame, currentTab
local hookedHum, tpLoopRow, espObjs, fullbrightSaved, fogSaved, noclipTracked = nil, nil, {}, nil, nil, {}
local waypoints = {nil, nil, nil}
local antiAFKThread = nil
local ANTI_MAX_VEL = 45
local ANTI_VIOLENT = 100
local STICK_RANGE = 60
local STICK_OFFSET = CFrame.new(0, 0.4, 1.2)
local STICK_LERP_RATE = 20
local WALK_AIR_LV = "MP_WalkAirLV"
local WALK_AIR_ATT = "MP_WalkAirAtt"

local function getHum() local c=lp.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c=lp.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function findNearest(maxDist)
	local r = getRoot(); if not r then return nil end
	local pos, nearest, best = r.Position, nil, maxDist
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= lp and p.Character then
			local tr = p.Character:FindFirstChild("HumanoidRootPart")
			local th = p.Character:FindFirstChildOfClass("Humanoid")
			if tr and th and th.Health > 0 then
				local d = (tr.Position - pos).Magnitude
				if d < best then nearest, best = p, d end
			end
		end
	end
	return nearest
end
local function isAlive(p)
	if not p or p.Parent ~= Players then return false end
	local c=p.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
	local r=c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Health > 0 and r ~= nil
end
local function fmtDist(d) if d >= 1000 then return string.format("%.1fk", d/1000) end; return math.floor(d).."m" end
local friendCache = {}
local function isFriend(p)
	local v = friendCache[p.UserId]
	if v == nil then
		local ok2, res = pcall(function() return lp:IsFriendsWith(p.UserId) end)
		v = ok2 and res or false; friendCache[p.UserId] = v
	end
	return v
end

-- FLY
local function stopFly()
	for _, o in pairs(flyObjs) do if o and o.Parent then o:Destroy() end end
	flyObjs = {}
	local h = getHum()
	if h then h.PlatformStand = false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end
end
local function startFly()
	stopFly()
	local root, hum = getRoot(), getHum()
	if not root or not hum then return false end
	local att = Instance.new("Attachment"); att.Name="MP_Att"; att.Parent=root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0=att; lv.MaxForce=math.huge
	lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.VectorVelocity=Vector3.zero; lv.Parent=root
	local ao = Instance.new("AlignOrientation")
	ao.Mode=Enum.OrientationAlignmentMode.OneAttachment; ao.Attachment0=att
	ao.MaxTorque=math.huge; ao.Responsiveness=60
	local look=cam.CFrame.LookVector; local flat=Vector3.new(look.X,0,look.Z)
	ao.CFrame = flat.Magnitude>0.05 and CFrame.lookAt(Vector3.zero,flat) or root.CFrame
	ao.Parent=root; hum.PlatformStand=true
	flyObjs={att=att,lv=lv,ao=ao}
	return true
end
RunService.RenderStepped:Connect(function(dt)
	if not S.fly then return end
	local lv, ao = flyObjs.lv, flyObjs.ao
	if not (lv and lv.Parent and ao and ao.Parent) then return end
	local hum=getHum()
	local move = hum and hum.MoveDirection or Vector3.zero
	local lm = cam.CFrame:VectorToObjectSpace(move)
	local dir = cam.CFrame.LookVector*-lm.Z + cam.CFrame.RightVector*lm.X
	dir += Vector3.new(0, (upHeld and 1 or 0)-(downHeld and 1 or 0), 0)
	if dir.Magnitude > 0.05 then lv.VectorVelocity = dir.Unit*S.flySpeed
	else lv.VectorVelocity = Vector3.zero end
	local look=cam.CFrame.LookVector; local flat=Vector3.new(look.X,0,look.Z)
	if flat.Magnitude > 0.05 then
		local tgt, cur = flat.Unit, ao.CFrame.LookVector
		if cur:Dot(tgt) > -0.5 then ao.CFrame = CFrame.lookAt(Vector3.zero, cur:Lerp(tgt, math.clamp(dt*8,0,1)).Unit)
		else ao.CFrame = CFrame.lookAt(Vector3.zero, tgt) end
	end
end)

-- WALK AIR
local function stopWalkAir()
	local root = getRoot(); if not root then return end
	local lv = root:FindFirstChild(WALK_AIR_LV); if lv then lv:Destroy() end
	local att = root:FindFirstChild(WALK_AIR_ATT); if att then att:Destroy() end
end
local function walkAirTick()
	if not S.walkAir then stopWalkAir(); return end
	local root, hum = getRoot(), getHum()
	if not root or not hum then return end
	if S.fly or S.stick or S.tpLoop then stopWalkAir(); return end
	local st = hum:GetState()
	local airborne = (st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.FallingDown)
	if not airborne and (st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.Landed) then
		airborne = (hum.FloorMaterial == Enum.Material.Air)
	end
	if not airborne then stopWalkAir(); return end
	local lv = root:FindFirstChild(WALK_AIR_LV)
	if not lv then
		local att = root:FindFirstChild(WALK_AIR_ATT)
		if not att then att=Instance.new("Attachment"); att.Name=WALK_AIR_ATT; att.Parent=root end
		lv=Instance.new("LinearVelocity"); lv.Name=WALK_AIR_LV; lv.Attachment0=att
		lv.MaxForce=math.huge; lv.RelativeTo=Enum.ActuatorRelativeTo.World
		lv.VectorVelocity=Vector3.zero; lv.Parent=root
	end
	local move = hum.MoveDirection or Vector3.zero
	local speed = hum.WalkSpeed; if speed <= 0 then speed = 16 end
	local cur = root.AssemblyLinearVelocity
	lv.VectorVelocity = Vector3.new(cur.X + (move.X*speed - cur.X)*0.35, 0, cur.Z + (move.Z*speed - cur.Z)*0.35)
	if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.FallingDown then hum:ChangeState(Enum.HumanoidStateType.Running) end
end

local function walkWaterTick()
	if not S.walkWater or S.fly or S.stick or S.tpLoop then return end
	local root, hum = getRoot(), getHum()
	if not root or not hum then return end
	if hum:GetState() == Enum.HumanoidStateType.Swimming then
		local v = root.AssemblyLinearVelocity
		if v.Y < 2 then root.AssemblyLinearVelocity = Vector3.new(v.X, 2, v.Z) end
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- NOCLIP
local function setNoclip(on)
	local char = lp.Character; if not char then return end
	if on then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide = false end); noclipTracked[p] = true end
		end
	else
		for p in pairs(noclipTracked) do if p and p.Parent then pcall(function() p.CanCollide = true end) end end
		noclipTracked = {}
	end
end
local function noclipTick()
	if not S.noclip then return end
	local char = lp.Character; if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide = false end); noclipTracked[p] = true end
	end
	local root = getRoot()
	if root and not S.fly and not S.stick and not S.walkAir then
		local v = root.AssemblyLinearVelocity
		if v.Y < 0 then root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z) end
	end
	local hum = getHum()
	if hum then
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.FallingDown then hum:ChangeState(Enum.HumanoidStateType.Running) end
	end
end

-- NO FALL
local function applyNoFallState(hum, en) if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not en) end) end end
local function hookHumanoid(hum)
	if not hum or hum == hookedHum then return end
	hookedHum = hum
	hum.StateChanged:Connect(function(_, ns)
		if not S.noFall then return end
		if ns == Enum.HumanoidStateType.Landed or ns == Enum.HumanoidStateType.FallingDown or ns == Enum.HumanoidStateType.Ragdoll then
			task.defer(function() if S.noFall and hum.Parent and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end end)
		end
	end)
	hum.HealthChanged:Connect(function(nh)
		if not S.noFall or not hum.Parent or nh >= hum.MaxHealth then return end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
			hum.Health = hum.MaxHealth
		end
	end)
	applyNoFallState(hum, S.noFall)
end

-- TELEPORT & STICK
local function teleportToPlayer(p)
	if not p then return false end
	local mc = lp.Character; local mr = mc and mc:FindFirstChild("HumanoidRootPart")
	if not mr then return false end
	local tc = p.Character; local tr = tc and tc:FindFirstChild("HumanoidRootPart")
	if not tr then return false end
	if workspace.StreamingEnabled then
		pcall(function() lp:RequestStreamAroundAsync(tr.Position) end); task.wait(0.15)
		tr = tc and tc:FindFirstChild("HumanoidRootPart"); if not tr then return false end
	end
	local tCF = tr.CFrame * CFrame.new(0, 2, 4)
	for i = 1, 5 do
		pcall(function() mc:PivotTo(tCF) end); pcall(function() mr.CFrame = tCF end)
		pcall(function() mr.Position = tCF.Position end); pcall(function() mr.AssemblyLinearVelocity = Vector3.zero end)
		pcall(function() mr.AssemblyAngularVelocity = Vector3.zero end)
		if i < 5 then RunService.Heartbeat:Wait() end
	end
	return true
end
local CG = "MPStick"
local function ensureCollision()
	pcall(function() PhysicsService:RegisterCollisionGroup(CG) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(CG, "Default", false) end)
end
local function setGroup(char, g) if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CollisionGroup = g end) end end end end
local function stopStick(keep)
	stickTarget, stickManual = nil, false
	setGroup(lp.Character, "Default")
	local hum = getHum()
	if hum and keep ~= true then
		hum.PlatformStand = false; hum.AutoRotate = true
		if stickOrigWS then hum.WalkSpeed = stickOrigWS end
		if stickOrigJP then if hum.UseJumpPower then hum.JumpPower = stickOrigJP else hum.JumpHeight = stickOrigJP end end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	stickOrigWS, stickOrigJP = nil, nil
end
local function startStick(tp, manual)
	stopStick(true)
	local mc = lp.Character; local mr = mc and mc:FindFirstChild("HumanoidRootPart")
	local hum = mc and mc:FindFirstChildOfClass("Humanoid")
	if not mr or not hum or not tp or not tp.Character then return false end
	local tr = tp.Character:FindFirstChild("HumanoidRootPart"); if not tr then return false end
	ensureCollision(); setGroup(mc, CG)
	stickOrigWS = hum.WalkSpeed; stickOrigJP = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
	hum.PlatformStand = true; hum.AutoRotate = false; hum.WalkSpeed = 0
	if hum.UseJumpPower then hum.JumpPower = 0 else hum.JumpHeight = 0 end
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	stickTarget = tp; stickManual = manual or (tp == selectedPlayer)
	mr.CFrame = tr.CFrame * STICK_OFFSET
	mr.AssemblyLinearVelocity = Vector3.zero; mr.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- ANTI-MENTAL & ESP
local function antiFlingTick()
	if not S.noFling or S.stick or S.fly then return end
	local char = lp.Character; local root = char and char:FindFirstChild("HumanoidRootPart"); local hum = getHum()
	if not root or not hum then return end
	for _, c in ipairs(root:GetChildren()) do
		if c:IsA("Weld") or c:IsA("WeldConstraint") then
			local other = (c.Part0 == root) and c.Part1 or c.Part0
			if other and not other:IsDescendantOf(char) then c:Destroy() end
		end
	end
	local av = root.AssemblyAngularVelocity
	if av and av.Magnitude > 1 then pcall(function() root.AssemblyAngularVelocity = Vector3.zero end) end
	local rv = root.RotVelocity
	if rv and rv.Magnitude > 1 then pcall(function() root.RotVelocity = Vector3.zero end) end
	local lv = root.AssemblyLinearVelocity
	if lv then
		local mag = lv.Magnitude
		if mag > ANTI_VIOLENT then pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		elseif mag > ANTI_MAX_VEL then pcall(function() root.AssemblyLinearVelocity = lv.Unit*ANTI_MAX_VEL end) end
	end
	if hum.PlatformStand then hum.PlatformStand = false end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Flying or st == Enum.HumanoidStateType.PlatformStanding then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end
local function clearESP()
	for _, o in pairs(espObjs) do if o.hl then o.hl:Destroy() end; if o.bb then o.bb:Destroy() end end
	espObjs = {}
end
local function makeESPFor(p)
	if p == lp or not p.Character then return end
	local isFr = isFriend(p)
	local fill = isFr and Color3.fromRGB(80,220,130) or Color3.fromRGB(250,100,100)
	local outline = isFr and Color3.fromRGB(120,255,180) or Color3.fromRGB(255,150,150)
	if espObjs[p] then
		local o = espObjs[p]
		if o.hl then o.hl.Adornee = p.Character; o.hl.FillColor = fill; o.hl.OutlineColor = outline end
		if o.bb then o.bb.Adornee = p.Character:FindFirstChild("Head") end
		if o.nameLbl then o.nameLbl.Text = (isFr and "* " or "")..p.Name; o.nameLbl.TextColor3 = fill end
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = fill; hl.FillTransparency = 0.55; hl.OutlineColor = outline; hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee = p.Character; hl.Parent = gui
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 32); bb.StudsOffset = Vector3.new(0, 2.8, 0); bb.AlwaysOnTop = true; bb.LightInfluence = 0
	bb.Adornee = p.Character:FindFirstChild("Head"); bb.Parent = gui
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1,0,0.55,0); nameLbl.BackgroundTransparency = 1; nameLbl.TextColor3 = fill
	nameLbl.Font = Enum.Font.Arcade; nameLbl.TextSize = 13; nameLbl.TextStrokeTransparency = 0
	nameLbl.Text = (isFr and "* " or "")..p.Name; nameLbl.Parent = bb
	local distLbl = Instance.new("TextLabel")
	distLbl.Size = UDim2.new(1,0,0.45,0); distLbl.Position = UDim2.new(0,0,0.55,0); distLbl.BackgroundTransparency = 1
	distLbl.TextColor3 = Color3.fromRGB(255,255,255); distLbl.Font = Enum.Font.Arcade; distLbl.TextSize = 11
	distLbl.TextStrokeTransparency = 0.4; distLbl.Text = "-"; distLbl.Parent = bb
	espObjs[p] = {hl=hl, bb=bb, nameLbl=nameLbl, distLbl=distLbl}
end
local function startESP() clearESP(); for _, p in pairs(Players:GetPlayers()) do if p ~= lp then makeESPFor(p) end end end
local function stopESP() clearESP() end

-- ================= VISUAL EFFECTS =================
local function toggleCinemaHD(on)
	if on then
		if not ccHD then
			ccHD = Instance.new("ColorCorrectionEffect", Lighting)
			ccHD.Brightness = 0.1; ccHD.Contrast = 0.35; ccHD.Saturation = 0.4
		end
		if not sunraysObj then
			sunraysObj = Instance.new("SunRaysEffect", Lighting)
			sunraysObj.Intensity = 0.15; sunraysObj.Spread = 0.5
		end
		if not bloomObj then
			bloomObj = Instance.new("BloomEffect", Lighting)
			bloomObj.Intensity = 0.4; bloomObj.Size = 24
		end
	else
		if ccHD then ccHD:Destroy(); ccHD = nil end
		if sunraysObj then sunraysObj:Destroy(); sunraysObj = nil end
		if bloomObj then bloomObj:Destroy(); bloomObj = nil end
	end
end
local function toggleCinemaDoF(on)
	if on then
		if not dofObj then
			dofObj = Instance.new("DepthOfFieldEffect", Lighting)
			dofObj.FocusDistance = 15; dofObj.InFocusRadius = 10
			dofObj.NearIntensity = 0.6; dofObj.FarIntensity = 0.9
		end
	elseif dofObj then dofObj:Destroy(); dofObj = nil end
end
local function toggleCinemaRetro(on)
	if on then
		if not ccRetro then
			ccRetro = Instance.new("ColorCorrectionEffect", Lighting)
			ccRetro.Brightness = -0.05; ccRetro.Contrast = 0.2
			ccRetro.Saturation = -0.3; ccRetro.TintColor = Color3.fromRGB(255, 230, 200)
		end
		if not blurRetro then blurRetro = Instance.new("BlurEffect", Lighting); blurRetro.Size = 2 end
		if not uiVhsScanlines then
			uiVhsScanlines = Instance.new("Frame", gui)
			uiVhsScanlines.Size = UDim2.fromScale(1, 1); uiVhsScanlines.BackgroundTransparency = 1; uiVhsScanlines.ZIndex = 999
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0))
			grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.8),NumberSequenceKeypoint.new(0.1,1),NumberSequenceKeypoint.new(0.2,0.8)})
			grad.Rotation = 90; grad.Parent = uiVhsScanlines
		end
		if not uiVhsVignette then
			uiVhsVignette = Instance.new("ImageLabel", gui)
			uiVhsVignette.Size = UDim2.fromScale(1, 1); uiVhsVignette.BackgroundTransparency = 1; uiVhsVignette.ZIndex = 998
			uiVhsVignette.Image = "rbxassetid://8992230677"; uiVhsVignette.ImageColor3 = Color3.new(0,0,0)
			uiVhsVignette.ImageTransparency = 0.4; uiVhsVignette.ScaleType = Enum.ScaleType.Stretch
		end
	else
		if ccRetro then ccRetro:Destroy(); ccRetro = nil end
		if blurRetro then blurRetro:Destroy(); blurRetro = nil end
		if uiVhsScanlines then uiVhsScanlines:Destroy(); uiVhsScanlines = nil end
		if uiVhsVignette then uiVhsVignette:Destroy(); uiVhsVignette = nil end
	end
end
local function toggleCinemaBars(on)
	if on then
		if not uiBarsTop then
			uiBarsTop = Instance.new("Frame", gui)
			uiBarsTop.Size = UDim2.new(1, 0, 0.08, 0); uiBarsTop.Position = UDim2.new(0, 0, 0, 0)
			uiBarsTop.BackgroundColor3 = Color3.new(0, 0, 0); uiBarsTop.BorderSizePixel = 0; uiBarsTop.ZIndex = 997
			uiBarsBottom = Instance.new("Frame", gui)
			uiBarsBottom.Size = UDim2.new(1, 0, 0.08, 0); uiBarsBottom.Position = UDim2.new(0, 0, 1, 0)
			uiBarsBottom.AnchorPoint = Vector2.new(0, 1); uiBarsBottom.BackgroundColor3 = Color3.new(0, 0, 0)
			uiBarsBottom.BorderSizePixel = 0; uiBarsBottom.ZIndex = 997
		end
	else
		if uiBarsTop then uiBarsTop:Destroy(); uiBarsTop = nil end
		if uiBarsBottom then uiBarsBottom:Destroy(); uiBarsBottom = nil end
	end
end

-- CLEAN UI (X Kecil)
local function toggleCinemaClean(on)
	if on then
		container.Visible = false
		kBtn.Visible = false
		pad.Visible = false
		if uiCleanExit then uiCleanExit:Destroy(); uiCleanExit = nil end
		
		uiCleanExit = Instance.new("TextButton")
		uiCleanExit.Size = UDim2.fromOffset(36, 36)
		uiCleanExit.Position = UDim2.new(1, -46, 0, 10)
		uiCleanExit.BackgroundColor3 = Color3.fromRGB(255, 30, 80)
		uiCleanExit.BackgroundTransparency = 0.4
		uiCleanExit.Text = "X"
		uiCleanExit.TextColor3 = Color3.new(1, 1, 1)
		uiCleanExit.Font = FONT
		uiCleanExit.TextSize = 18
		uiCleanExit.AutoButtonColor = false
		uiCleanExit.ZIndex = 9999
		uiCleanExit.Parent = gui
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = uiCleanExit
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.5
		stroke.Parent = uiCleanExit
		
		uiCleanExit.MouseButton1Click:Connect(function()
			S.cinemaClean = false
			toggleCinemaClean(false)
			if cinemaCleanRow then cinemaCleanRow.refresh(false) end
		end)
	else
		if uiCleanExit then uiCleanExit:Destroy(); uiCleanExit = nil end
		container.Visible = true
		pad.Visible = S.fly
	end
end

local function toggleCinemaBloom(on)
	if on then if not bloomObj then bloomObj = Instance.new("BloomEffect", Lighting); bloomObj.Intensity = 1.5; bloomObj.Size = 40 end
	elseif bloomObj then bloomObj:Destroy(); bloomObj = nil end
end
local function toggleCinemaSunrays(on)
	if on then if not sunraysObj then sunraysObj = Instance.new("SunRaysEffect", Lighting); sunraysObj.Intensity = 0.5; sunraysObj.Spread = 1 end
	elseif sunraysObj then sunraysObj:Destroy(); sunraysObj = nil end
end
local function toggleCinemaBWM(on)
	if on then if not ccBWM then ccBWM = Instance.new("ColorCorrectionEffect", Lighting); ccBWM.Saturation = -1; ccBWM.Contrast = 0.3 end
	elseif ccBWM then ccBWM:Destroy(); ccBWM = nil end
end
local function toggleCinemaCyberpunk(on)
	if on then if not ccCyberpunk then ccCyberpunk = Instance.new("ColorCorrectionEffect", Lighting); ccCyberpunk.TintColor = Color3.fromRGB(200, 50, 255); ccCyberpunk.Contrast = 0.4; ccCyberpunk.Saturation = 0.6 end
	elseif ccCyberpunk then ccCyberpunk:Destroy(); ccCyberpunk = nil end
end
local function toggleCinemaSepia(on)
	if on then if not ccSepia then ccSepia = Instance.new("ColorCorrectionEffect", Lighting); ccSepia.TintColor = Color3.fromRGB(255, 200, 150); ccSepia.Saturation = -0.4; ccSepia.Contrast = 0.2 end
	elseif ccSepia then ccSepia:Destroy(); ccSepia = nil end
end
local function toggleCinemaBlur(on)
	if on then if not blurMotion then blurMotion = Instance.new("BlurEffect", Lighting); blurMotion.Size = 6 end
	elseif blurMotion then blurMotion:Destroy(); blurMotion = nil end
end
local function toggleCinemaNightvision(on)
	if on then if not ccNightvision then ccNightvision = Instance.new("ColorCorrectionEffect", Lighting); ccNightvision.TintColor = Color3.fromRGB(0, 255, 0); ccNightvision.Contrast = 0.5; ccNightvision.Brightness = 0.1 end
	elseif ccNightvision then ccNightvision:Destroy(); ccNightvision = nil end
end
local function toggleCinemaNegative(on)
	if on then if not ccNegative then ccNegative = Instance.new("ColorCorrectionEffect", Lighting); ccNegative.TintColor = Color3.fromRGB(255, 255, 0); ccNegative.Contrast = 0.8 end
	elseif ccNegative then ccNegative:Destroy(); ccNegative = nil end
end
local function toggleCinemaDreamy(on)
	if on then
		if not ccDreamy then ccDreamy = Instance.new("ColorCorrectionEffect", Lighting); ccDreamy.Brightness = 0.2; ccDreamy.TintColor = Color3.fromRGB(255, 200, 255) end
		if not blurRetro then blurRetro = Instance.new("BlurEffect", Lighting); blurRetro.Size = 4 end
	else
		if ccDreamy then ccDreamy:Destroy(); ccDreamy = nil end
		if blurRetro then blurRetro:Destroy(); blurRetro = nil end
	end
end
local function toggleCinemaFisheye(on)
	if on then cam.FieldOfView = 120 else cam.FieldOfView = S.fov end
end

-- SHADER & FOG
local function applyBrightShader(en)
	local cc = Lighting:FindFirstChild("MP_BrightShader"); local bl = Lighting:FindFirstChild("MP_BrightBloom")
	if not en then if cc then cc:Destroy() end; if bl then bl:Destroy() end; return end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect"); cc.Name = "MP_BrightShader"; cc.Contrast = 0.08
		cc.Saturation = 0.05; cc.TintColor = Color3.fromRGB(255,255,255); cc.Parent = Lighting
	end
	if not bl then
		bl = Instance.new("BloomEffect"); bl.Name = "MP_BrightBloom"; bl.Intensity = 0.2
		bl.Size = 24; bl.Threshold = 0.9; bl.Parent = Lighting
	end
	cc.Brightness = S.shaderLevel
end
local function applyFullbright(en)
	if en then
		if not fullbrightSaved then fullbrightSaved = {Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient, Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime} end
		Lighting.Ambient = Color3.fromRGB(185,185,185); Lighting.OutdoorAmbient = Color3.fromRGB(185,185,185)
		Lighting.Brightness = 2; Lighting.ClockTime = 14
	elseif fullbrightSaved then
		Lighting.Ambient = fullbrightSaved.Ambient; Lighting.OutdoorAmbient = fullbrightSaved.OutdoorAmbient
		Lighting.Brightness = fullbrightSaved.Brightness; Lighting.ClockTime = fullbrightSaved.ClockTime
		fullbrightSaved = nil
	end
end
task.spawn(function()
	while true do
		task.wait(0.6)
		if S.fullbright and Lighting.Brightness < 1.5 then
			Lighting.Brightness = 2; Lighting.Ambient = Color3.fromRGB(185,185,185); Lighting.OutdoorAmbient = Color3.fromRGB(185,185,185)
		end
	end
end)
local function applyNoFog(en)
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if en then
		if not fogSaved then fogSaved = {FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart, atmosDensity=atmos and atmos.Density or nil} end
		Lighting.FogEnd = 100000; Lighting.FogStart = 100000; if atmos then atmos.Density = 0 end
	elseif fogSaved then
		Lighting.FogEnd = fogSaved.FogEnd; Lighting.FogStart = fogSaved.FogStart
		if atmos and fogSaved.atmosDensity then atmos.Density = fogSaved.atmosDensity end; fogSaved = nil
	end
end
local function applyFOV(v) cam.FieldOfView = v end

local function toggleAutoRespawn(on)
	S.autorespawn = on
	local hum = getHum()
	if hum and on then
		hum.Died:Connect(function()
			if S.autorespawn then task.wait(0.1); pcall(function() lp:LoadCharacter() end) end
		end)
	end
end

local function toggleAntiAFK(on)
	S.antiAFK = on
	if on then
		if antiAFKThread then task.cancel(antiAFKThread) end
		antiAFKThread = task.spawn(function()
			local VIM = game:GetService("VirtualInputManager")
			while S.antiAFK do
				task.wait(10)
				if S.antiAFK then
					pcall(function()
						VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
						task.wait(0.1)
						VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
					end)
				end
			end
		end)
	else
		if antiAFKThread then task.cancel(antiAFKThread); antiAFKThread = nil end
	end
end

-- ============ MAIN LOOPS ============
RunService.PreSimulation:Connect(function()
	if S.noFall and not S.stick and not S.fly and not S.tpLoop and not S.walkAir and not S.noclip then
		local root = getRoot()
		if root then local v = root.AssemblyLinearVelocity; if v.Y < -S.fallCap then root.AssemblyLinearVelocity = Vector3.new(v.X, -S.fallCap, v.Z) end end
	end
end)
RunService.Heartbeat:Connect(function(dt)
	if S.speed and not S.fly and not S.stick and not S.tpLoop then local hum = getHum(); if hum then hum.WalkSpeed = S.walkSpeed end end
	if S.anti then workspace.Gravity = DEFAULT_GRAVITY * S.gravFactor end
	antiFlingTick(); walkAirTick(); walkWaterTick(); noclipTick()
	if S.stick then
		local mc, mr, mh = lp.Character, getRoot(), getHum()
		if not mr or not mh or not mc then S.stick = false; stopStick()
		else
			if mh:GetState() ~= Enum.HumanoidStateType.Physics then mh:ChangeState(Enum.HumanoidStateType.Physics) end
			if mh.AutoRotate then mh.AutoRotate = false end
			if not mh.PlatformStand then mh.PlatformStand = true end
			local tc = stickTarget and stickTarget.Character
			local tr = tc and tc:FindFirstChild("HumanoidRootPart")
			local alive = isAlive(stickTarget) and tr
			if not alive then
				if stickManual then S.stick = false; stopStick(); selectedPlayer = nil
				else
					local nt = findNearest(STICK_RANGE)
					if nt then stopStick(true); if not startStick(nt, false) then S.stick = false; stopStick() end
					else S.stick = false; stopStick() end
				end
			else
				local tCF = tr.CFrame * STICK_OFFSET; local a = 1 - math.exp(-dt * STICK_LERP_RATE)
				mr.CFrame = mr.CFrame:Lerp(tCF, a); mr.AssemblyLinearVelocity = Vector3.zero; mr.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.15)
		if S.tpLoop then
			if selectedPlayer and isAlive(selectedPlayer) then
				local mr = getRoot(); local tr = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
				if mr and tr and (tr.Position-mr.Position).Magnitude > 4 then teleportToPlayer(selectedPlayer) end
			else S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end
		end
	end
end)

-- UI CONSTANTS
local FONT = Enum.Font.Arcade
local P = {
	ink = Color3.fromRGB(12,14,34), bg = Color3.fromRGB(29,43,83), bg2 = Color3.fromRGB(18,25,56),
	row = Color3.fromRGB(41,58,108), plum = Color3.fromRGB(126,37,83), plum2 = Color3.fromRGB(78,22,54),
	text = Color3.fromRGB(255,241,232), dim = Color3.fromRGB(131,118,156),
	ok = Color3.fromRGB(0,228,54), warn = Color3.fromRGB(255,236,39), bad = Color3.fromRGB(255,0,77),
	orange = Color3.fromRGB(255,163,0), blue = Color3.fromRGB(41,173,255), pink = Color3.fromRGB(255,119,168),
	peach = Color3.fromRGB(255,204,170), silver = Color3.fromRGB(194,195,199), lav = Color3.fromRGB(190,170,255),
	teal = Color3.fromRGB(0,200,190),
	card = Color3.fromRGB(36, 41, 54), trackOff = Color3.fromRGB(56, 62, 78),
	border = Color3.fromRGB(60, 66, 84), accent = Color3.fromRGB(130, 168, 255),
	accent2 = Color3.fromRGB(180, 140, 255), accent3 = Color3.fromRGB(245, 120, 190)
}
local SPR = {
	fly="...#...|..###..|..###..|..###..|.#####.|#.###.#|...#...",
	speed=".......|#..#...|.#..#..|..#..#.|.#..#..|#..#...|.......",
	jump="...#...|..###..|.#.#.#.|...#...|...#...|.#####.|.......",
	grav="..###..|.#####.|.#####.|.#####.|..###..|...#...|...#...",
	air=".......|..##...|.#####.|#######|#######|.#####.|.......",
	water=".......|.#..#..|#.##.##|.......|.#..#..|#.##.##|.......",
	shield="#######|#######|#######|#######|.#####.|..###..|...#...",
	chute=".#####.|#######|#.#.#.#|.#.#.#.|..#.#..|...#...|...#...",
	ghost="..###..|.#####.|##.#.##|#######|#######|#######|#.#.#.#",
	eye=".......|..###..|.#####.|###.###|.#####.|..###..|.......",
	sun="...#...|.#...#.|..###..|#.###.#|..###..|.#...#.|...#...",
	bulb="..###..|.#####.|.#####.|..###..|..###..|..#.#..|..###..",
	fog=".......|##.###.|.......|.###.##|.......|##.###.|.......",
	fov="##...##|#.....#|.......|...#...|.......|#.....#|##...##",
	loop="..#....|.######|..#....|.......|....#..|######.|....#..",
	up="...#...|..###..|.#####.|#######|...#...|...#...|...#...",
	down="...#...|...#...|...#...|#######|.#####.|..###..|...#...",
	check=".....#|....##|#..##.|.###..|..#...",
	k="##...##|##..##.|##.##..|####...|##.##..|##..##.|##...##",
	cam="..###..|.#####.|##.#.##|#######|.#####.|..###..|......."
}

-- ANIMATION SYSTEM (PULSING STROKES)
local strokePulses = {}
local function addPulse(stroke, base, amp, speed)
    strokePulses[stroke] = {base = base, amp = amp, speed = speed, start = os.clock()}
end
local function removePulse(stroke)
    strokePulses[stroke] = nil
end
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    for stroke, p in pairs(strokePulses) do
        if stroke and stroke.Parent then
            stroke.Transparency = math.clamp(p.base + math.sin((now - p.start) * p.speed) * p.amp, 0, 1)
        else
            strokePulses[stroke] = nil
        end
    end
end)

local function mk(c, p, par) local o = Instance.new(c); for k, v in pairs(p) do o[k] = v end; o.Parent = par; return o end
local function box(parent, size, pos, fill, class)
	local o = mk(class or "Frame", {Size=size, Position=pos, BackgroundColor3=P.ink, BorderSizePixel=0}, parent)
	if o:IsA("GuiButton") then o.Text = ""; o.AutoButtonColor = false end
	local f = mk("Frame", {Size=UDim2.new(1,-4,1,-4), Position=UDim2.fromOffset(2,2), BackgroundColor3=fill, BorderSizePixel=0}, o)
	mk("Frame", {Size=UDim2.new(1,0,0,2), BackgroundColor3=fill:Lerp(Color3.new(1,1,1),0.22), BorderSizePixel=0}, f)
	mk("Frame", {Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2), BackgroundColor3=fill:Lerp(Color3.new(0,0,0),0.35), BorderSizePixel=0}, f)
	return o, f
end
local function sprite(parent, key, color, px, x, y)
	local h = mk("Frame", {BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.fromOffset(x,y)}, parent)
	local rows, wmax = 0, 0
	for line in SPR[key]:gmatch("[^|]+") do
		wmax = math.max(wmax, #line); local i = 1
		while true do
			local a, b = line:find("#+", i); if not a then break end
			mk("Frame", {Size=UDim2.fromOffset((b-a+1)*px, px), Position=UDim2.fromOffset((a-1)*px, rows*px), BackgroundColor3=color, BorderSizePixel=0}, h)
			i = b + 1
		end
		rows += 1
	end
	h.Size = UDim2.fromOffset(wmax*px, rows*px); return h
end
local function tint(h, c) for _, f in ipairs(h:GetChildren()) do f.BackgroundColor3 = c end end
local function txt(parent, s, size, color, pos, sz, align)
	local l = mk("TextLabel", {
		BackgroundTransparency=1, BorderSizePixel=0, Text=s, Font=FONT, TextSize=size, TextColor3=color,
		TextScaled=true, Position=pos, Size=sz or UDim2.fromScale(1,1), TextXAlignment = align or Enum.TextXAlignment.Left}, parent)
	mk("UITextSizeConstraint", {MaxTextSize=size, MinTextSize=7}, l); return l
end
local function drag(handle, target, onTap)
	handle.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local start, from, moved = input.Position, target.Position, false
		local conn = UIS.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				local d = i.Position - start; if d.Magnitude > 4 then moved = true end
				target.Position = UDim2.new(from.X.Scale, from.X.Offset+d.X, from.Y.Scale, from.Y.Offset+d.Y)
			end
		end)
		local c2; c2 = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then conn:Disconnect(); c2:Disconnect(); if not moved and onTap then onTap() end end
		end)
	end)
end
local function holdRepeat(btn, fn)
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local alive = true
		local c; c = input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then alive = false; c:Disconnect() end end)
		task.spawn(function() fn(); task.wait(0.4); while alive do fn(); task.wait(0.07) end end)
	end)
end

local W, H, TITLE_H, TAB_H, FOOT_H = 296, 304, 30, 26, 18
local refreshPlayerList, updateStickBtn, setTab, cinemaCleanRow

local container = mk("Frame", {
	Size=UDim2.fromOffset(W+6, H+6), Position=UDim2.new(0,12,0.14,0),
	BackgroundTransparency=1, BorderSizePixel=0, ClipsDescendants=true, Visible=false}, gui)
mk("Frame", {Size=UDim2.fromOffset(W,H), Position=UDim2.fromOffset(6,6), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.5, BorderSizePixel=0}, container)
local _, face = box(container, UDim2.fromOffset(W,H), nil, P.bg)
local mainStroke = mk("UIStroke", { Color = P.border, Thickness = 1, Transparency = 0.2 }, face)
addPulse(mainStroke, 0.5, 0.3, 1.5)

local bar = mk("Frame", {Size=UDim2.new(1,0,0,TITLE_H), BackgroundColor3=P.plum, BorderSizePixel=0}, face)
mk("Frame", {Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2), BackgroundColor3=P.ink, BorderSizePixel=0}, bar)
sprite(bar, "k", P.warn, 2, 8, 7)
txt(bar, "MOVEMENT PANEL", 14, P.text, UDim2.fromOffset(30,0), UDim2.new(1,-124,1,-2))
local led = mk("Frame", {Size=UDim2.fromOffset(8,8), Position=UDim2.new(1,-92,0.5,-5), BackgroundColor3=P.dim, BorderSizePixel=0}, bar)
local stat = txt(bar, "IDLE", 12, P.dim, UDim2.new(1,-80,0,0), UDim2.fromOffset(52,TITLE_H-2))
local miniBtn, miniFace = box(bar, UDim2.fromOffset(22,20), UDim2.new(1,-28,0.5,-11), P.plum2, "TextButton")
txt(miniFace, "-", 16, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
drag(bar, container)
local function updateStatus()
	local n = 0; for k, v in pairs(S) do if v == true then n += 1 end end
	led.BackgroundColor3 = n > 0 and P.ok or P.dim; stat.Text = n > 0 and (n.." ON") or "IDLE"; stat.TextColor3 = n > 0 and P.ok or P.dim
end
local content = mk("Frame", {Size=UDim2.new(1,-12,1,-(TITLE_H+TAB_H+11+FOOT_H+4)), Position=UDim2.fromOffset(6, TITLE_H+TAB_H+11), BackgroundTransparency=1, BorderSizePixel=0}, face)
local foot = mk("Frame", {Size=UDim2.new(1,0,0,FOOT_H), Position=UDim2.new(0,0,1,-FOOT_H), BackgroundColor3=P.bg2, BorderSizePixel=0}, face)
mk("Frame", {Size=UDim2.new(1,0,0,2), BackgroundColor3=P.ink, BorderSizePixel=0}, foot)
local credit = txt(foot, "by <font color=\"#FF77A8\">kemalgans12</font>", 11, P.dim, UDim2.fromOffset(8,2), UDim2.new(0.7,0,1,-2)); credit.RichText = true
txt(foot, "v28", 11, P.dim, UDim2.new(0.7,0,0,2), UDim2.new(0.3,-8,1,-2), Enum.TextXAlignment.Right)

local tabList = {{"move","MOVE"},{"guard","GUARD"},{"vision","VISION"},{"util","UTIL"},{"cinema","VISUAL"}}
local TAB_W = (W - 4 - 12 - 12) / 5
local tabs, pages = {}, {}
for i, t in ipairs(tabList) do
	local name = t[1]
	local pg = mk("ScrollingFrame", {
		Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
		ScrollBarImageColor3=P.plum, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, Visible=false}, content)
	mk("UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, pg); mk("UIPadding", {PaddingRight=UDim.new(0,6)}, pg)
	pages[name] = pg
	local b, f = box(face, UDim2.fromOffset(TAB_W, TAB_H), UDim2.fromOffset(6 + (i - 1) * (TAB_W + 4), TITLE_H + 5), P.bg2, "TextButton")
	tabs[name] = {face = f, lbl = txt(f, t[2], 11, P.dim, UDim2.new(), nil, Enum.TextXAlignment.Center),
		under = mk("Frame", {Size=UDim2.new(1,0,0,3), Position=UDim2.new(0,0,1,-3), BackgroundColor3=P.warn, BorderSizePixel=0, Visible=false}, f)}
	b.MouseButton1Click:Connect(function() setTab(name) end)
end
setTab = function(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do
		local on = (n == name); t.face.BackgroundColor3 = on and P.plum or P.bg2
		t.lbl.TextColor3 = on and P.text or P.dim; t.under.Visible = on
	end
	currentTab = name; if name == "util" and refreshPlayerList then pcall(refreshPlayerList) end
end

local tabIndicator = mk("Frame", {
	Size = UDim2.fromOffset(TAB_W, TAB_H - 6),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = P.accent,
	BorderSizePixel = 0,
	ZIndex = 1,
}, tabBar)
mk("UICorner", { CornerRadius = UDim.new(0, 7) }, tabIndicator)
mk("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, P.accent),
		ColorSequenceKeypoint.new(0.5, P.accent2),
		ColorSequenceKeypoint.new(1, P.accent3),
	}),
	Rotation = 0,
}, tabIndicator)
addPulse(tabIndicator, 0.2, 0.2, 4)

local function featureRow(page, order, o)
	local btn, f = box(page, UDim2.new(1,0,0,30), nil, P.row, "TextButton"); btn.LayoutOrder = order
	local stripe = mk("Frame", {Size=UDim2.new(0,4,1,0), BackgroundColor3=o.color, BorderSizePixel=0, Visible=false}, f)
	local icon = sprite(f, o.icon, o.key and P.dim or o.color, 2, 10, 6)
	local right = (o.key and 26 or 0) + (o.st and (o.key and 86 or 88) or 0)
	txt(f, o.label, 14, P.text, UDim2.fromOffset(30,0), UDim2.new(1, -(30+right+4), 1, 0))
	local cb, cbf, chk
	if o.key then
		cb = mk("Frame", {Size=UDim2.fromOffset(18,18), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(1,-17,0.5,0), BackgroundColor3=P.ink, BorderSizePixel=0}, f)
		cbf = mk("Frame", {Size=UDim2.new(1,-4,1,-4), Position=UDim2.fromOffset(2,2), BackgroundColor3=P.bg2, BorderSizePixel=0}, cb)
		chk = sprite(cbf, "check", P.ink, 2, 1, 2); chk.Visible = false
	end
	if o.st then
		local get, set, step, mn, mx, fmt = table.unpack(o.st)
		local sb = mk("Frame", {Size=UDim2.fromOffset(80,18), Position=UDim2.new(1, o.key and -112 or -88, 0.5, -9), BackgroundTransparency=1, BorderSizePixel=0}, f)
		local vb = mk("Frame", {Size=UDim2.fromOffset(40,18), Position=UDim2.fromOffset(20,0), BackgroundColor3=P.ink, BorderSizePixel=0}, sb)
		local vf = mk("Frame", {Size=UDim2.new(1,-4,1,-4), Position=UDim2.fromOffset(2,2), BackgroundColor3=P.bg2, BorderSizePixel=0}, vb)
		local val = txt(vf, "", 10, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
		local function show() val.Text = string.format(fmt, get()) end
		local function stepBtn(sym, x, dir)
			local b, bf = box(sb, UDim2.fromOffset(18,18), UDim2.fromOffset(x,0), P.bg, "TextButton")
			txt(bf, sym, 14, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
			holdRepeat(b, function() set(math.clamp(get()+dir*step, mn, mx)); show() end)
		end
		stepBtn("-", 0, -1); stepBtn("+", 62, 1); show()
	end
	local rowStroke = mk("UIStroke", { Color = P.border, Thickness = 1, Transparency = 0.55 }, f)
	local function refresh(animate)
		if not o.key then return end
		local on = S[o.key]
		stripe.Visible = on
		tint(icon, on and o.color or P.dim)
		cbf.BackgroundColor3 = on and o.color or P.bg2
		chk.Visible = on
		
		if on then
			rowStroke.Color = o.color
			addPulse(rowStroke, 0.3, 0.3, 3)
		else
			removePulse(rowStroke)
			rowStroke.Color = P.border
			rowStroke.Transparency = 0.55
		end
		
		if animate then cb.Size = UDim2.fromOffset(24,24); task.delay(0.06, function() cb.Size = UDim2.fromOffset(18,18) end) end
		updateStatus()
	end
	btn.MouseButton1Click:Connect(function()
		if not o.key then return end
		S[o.key] = not S[o.key]; if o.on then pcall(o.on, S[o.key]) end; refresh(true)
	end)
	refresh(false); return {refresh = refresh}
end

local function stepRow(parent, order, label, get, set, step, mn, mx, fmt)
	local row = mk("Frame", {Size=UDim2.new(1,0,0,24), LayoutOrder=order, BackgroundTransparency=1}, parent)
	txt(row, label, 11, P.dim, UDim2.fromOffset(10,0), UDim2.new(1,-100,1,0))
	local function btn(txt, x)
		local b = mk("TextButton", {Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,x,0.5,-11), Text=txt, BackgroundColor3=P.trackOff, TextColor3=P.text, Font=FONT, TextSize=13, AutoButtonColor=false}, row)
		mk("UICorner", {CornerRadius=UDim.new(0,6)}, b); return b
	end
	local plus = btn("+", -28)
	local minus = btn("-", -56)
	local valLbl = mk("TextLabel", {Size=UDim2.fromOffset(46,22), Position=UDim2.new(1,-104,0.5,-11), BackgroundColor3=P.card, Text="", TextColor3=P.text, Font=FONT, TextSize=10}, row)
	mk("UICorner", {CornerRadius=UDim.new(0,6)}, valLbl)
	local function refresh() valLbl.Text = string.format(fmt, get()) end
	minus.MouseButton1Click:Connect(function() set(math.clamp(get()-step, mn, mx)); refresh() end)
	plus.MouseButton1Click:Connect(function() set(math.clamp(get()+step, mn, mx)); refresh() end)
	refresh()
end

local kBtn, kFace = box(gui, UDim2.fromOffset(48,48), UDim2.new(0,12,0.14,0), P.plum, "TextButton")
kBtn.Visible = false; kBtn.ZIndex = 10; txt(kFace, "K", 28, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
local kStroke = mk("UIStroke", { Color = P.accent2, Thickness = 2, Transparency = 0.3 }, kBtn)
addPulse(kStroke, 0.4, 0.4, 3)
task.spawn(function()
	local lit = false; while true do task.wait(0.5); if kBtn.Visible then lit = not lit; kBtn.BackgroundColor3 = lit and P.warn or P.ink end end
end)
drag(kBtn, kBtn, function() container.Position = kBtn.Position; container.Visible = true; kBtn.Visible = false end)
miniBtn.MouseButton1Click:Connect(function() kBtn.Position = container.Position; kBtn.Visible = true; container.Visible = false end)
local pad = mk("Frame", {Size=UDim2.fromOffset(52,110), Position=UDim2.new(1,-66,1,-140), BackgroundTransparency=1, BorderSizePixel=0, Visible=false}, gui)
local function holdBtn(spr, y, setter)
	local b, f = box(pad, UDim2.fromOffset(52,52), UDim2.fromOffset(0,y), P.bg, "TextButton"); sprite(f, spr, P.text, 4, 10, 10)
	b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then setter(true) end end)
	b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then setter(false) end end)
end
holdBtn("up", 0, function(v) upHeld = v end); holdBtn("down", 58, function(v) downHeld = v end)
RunService.RenderStepped:Connect(function() if not S.cinemaClean then pad.Visible = S.fly end end)

-- MOVE ROWS
local flyRow = featureRow(pages.move, 1, {
	label="Fly", icon="fly", color=P.orange, key="fly", st={function() return S.flySpeed end, function(v) S.flySpeed = v end, 10, 10, 300, "%d"},
	on=function(on) if on then if S.stick then S.stick = false; stopStick(); updateStickBtn() end; if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end; if not startFly() then S.fly = false end
	else stopFly(); local hum = getHum(); if hum and S.speed then hum.WalkSpeed = S.walkSpeed end end end})
featureRow(pages.move, 2, {
	label="Speed", icon="speed", color=P.warn, key="speed", st={function() return S.walkSpeed end, function(v) S.walkSpeed = v end, 5, 16, 200, "%d"},
	on=function(on) local hum = getHum(); if not hum then return end; if on then origWalk = hum.WalkSpeed; hum.WalkSpeed = S.walkSpeed else hum.WalkSpeed = origWalk end end})
featureRow(pages.move, 3, {label="Inf Jump", icon="jump", color=P.ok, key="inf"})
featureRow(pages.move, 4, {label="Anti-Grav", icon="grav", color=P.pink, key="anti", st={function() return S.gravFactor end, function(v) S.gravFactor = v end, 0.05, 0.02, 1, "%.2fx"}, on=function(on) if not on then workspace.Gravity = DEFAULT_GRAVITY end end})
featureRow(pages.move, 5, {label="Air Walk", icon="air", color=P.silver, key="walkAir", on=function(on) if not on then stopWalkAir() end end})
featureRow(pages.move, 6, {label="Water Walk", icon="water", color=P.teal, key="walkWater"})

-- GUARD
featureRow(pages.guard, 1, {label="Anti-Mental", icon="shield", color=P.blue, key="noFling", on=function(on) if not on then local h=getHum(); if h then h.PlatformStand = false end end end})
featureRow(pages.guard, 2, {label="No Fall", icon="chute", color=P.peach, key="noFall", st={function() return S.fallCap end, function(v) S.fallCap = v end, 2, 10, 60, "%d"}, on=function(on) local h=getHum(); if h then applyNoFallState(h, on) end end})
featureRow(pages.guard, 3, {label="Noclip", icon="ghost", color=P.lav, key="noclip", on=function(on) setNoclip(on) end})

-- VISION
featureRow(pages.vision, 1, {label="ESP", icon="eye", color=P.ok, key="esp", on=function(on) if on then startESP() else stopESP() end end})
featureRow(pages.vision, 2, {label="Bright", icon="sun", color=P.warn, key="brightShader", st={function() return S.shaderLevel end, function(v) S.shaderLevel = v; if S.brightShader then applyBrightShader(true) end end, 0.05, 0.1, 0.8, "%.2f"}, on=function(on) applyBrightShader(on) end})
featureRow(pages.vision, 3, {label="Fullbright", icon="bulb", color=P.text, key="fullbright", on=function(on) applyFullbright(on) end})
featureRow(pages.vision, 4, {label="No Fog", icon="fog", color=P.silver, key="noFog", on=function(on) applyNoFog(on) end})
featureRow(pages.vision, 5, {label="FOV", icon="fov", color=P.blue, st={function() return S.fov end, function(v) S.fov = v; if not S.cinemaFisheye then applyFOV(v) end end, 5, 70, 120, "%d"}})

-- VISUAL TAB
local cHdr = mk("Frame", {Size=UDim2.new(1,0,0,20), LayoutOrder=1, BackgroundTransparency=1}, pages.cinema)
txt(cHdr, "VISUAL & PHOTOGRAPHY", 12, P.warn, UDim2.new(), UDim2.new(1,0,1,0))

featureRow(pages.cinema, 2, {label="HD Clarity (Ultra)", icon="sun", color=P.ok, key="cinemaHD", on=function(on) toggleCinemaHD(on) end})
featureRow(pages.cinema, 3, {label="Aesthetic DoF", icon="eye", color=P.lav, key="cinemaDoF", on=function(on) toggleCinemaDoF(on) end})
featureRow(pages.cinema, 4, {label="90s Retro (VHS)", icon="fog", color=P.peach, key="cinemaRetro", on=function(on) toggleCinemaRetro(on) end})
featureRow(pages.cinema, 5, {label="Cinematic Bars", icon="fov", color=P.silver, key="cinemaBars", on=function(on) toggleCinemaBars(on) end})
cinemaCleanRow = featureRow(pages.cinema, 6, {label="Clean UI (Screenshot)", icon="cam", color=P.blue, key="cinemaClean", on=function(on) toggleCinemaClean(on) end})

featureRow(pages.cinema, 7, {label="Bloom (Neon Glow)", icon="sun", color=P.pink, key="cinemaBloom", on=function(on) toggleCinemaBloom(on) end})
featureRow(pages.cinema, 8, {label="Sun Rays", icon="sun", color=P.warn, key="cinemaSunrays", on=function(on) toggleCinemaSunrays(on) end})
featureRow(pages.cinema, 9, {label="Black & White", icon="eye", color=P.silver, key="cinemaBWM", on=function(on) toggleCinemaBWM(on) end})
featureRow(pages.cinema, 10, {label="Cyberpunk", icon="fov", color=P.pink, key="cinemaCyberpunk", on=function(on) toggleCinemaCyberpunk(on) end})
featureRow(pages.cinema, 11, {label="Sepia (Old Photo)", icon="fog", color=P.peach, key="cinemaSepia", on=function(on) toggleCinemaSepia(on) end})
featureRow(pages.cinema, 12, {label="Motion Blur", icon="speed", color=P.blue, key="cinemaBlur", on=function(on) toggleCinemaBlur(on) end})
featureRow(pages.cinema, 13, {label="Night Vision", icon="eye", color=P.ok, key="cinemaNightvision", on=function(on) toggleCinemaNightvision(on) end})
featureRow(pages.cinema, 14, {label="Negative (Invert)", icon="fov", color=P.lav, key="cinemaNegative", on=function(on) toggleCinemaNegative(on) end})
featureRow(pages.cinema, 15, {label="Dreamy (Soft Focus)", icon="eye", color=P.pink, key="cinemaDreamy", on=function(on) toggleCinemaDreamy(on) end})
featureRow(pages.cinema, 16, {label="Fish Eye (FOV 120)", icon="fov", color=P.orange, key="cinemaFisheye", on=function(on) toggleCinemaFisheye(on) end})

local infoTxt = txt(pages.cinema, "Tips: Aktifin HD + DoF + Bars, terus Clean UI buat foto bersih.", 10, P.dim, nil, UDim2.new(1,0,0,40))
infoTxt.LayoutOrder = 17; infoTxt.TextWrapped = true; infoTxt.TextYAlignment = Enum.TextYAlignment.Top

-- UTIL TAB (Waypoints & Anti-AFK)
local util = pages.util
local hdr = mk("Frame", {Size=UDim2.new(1,0,0,20), LayoutOrder=1, BackgroundTransparency=1}, util)
local countLbl = txt(hdr, "PLAYERS 0", 12, P.dim, UDim2.new(), UDim2.new(1,-76,1,0))
local refreshBtn, refreshFace = box(hdr, UDim2.fromOffset(72,20), UDim2.new(1,-72,0,0), P.bg, "TextButton")
local refreshTxt = txt(refreshFace, "REFRESH", 11, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)

featureRow(util, 2, {label="Instant Respawn", icon="chute", color=P.ok, key="autorespawn", on=function(on) toggleAutoRespawn(on) end})
featureRow(util, 3, {label="Anti-AFK", icon="loop", color=P.warn, key="antiAFK", on=function(on) toggleAntiAFK(on) end})

-- WAYPOINTS SECTION
local wpHeader = mk("Frame", {Size=UDim2.new(1,0,0,20), LayoutOrder=4, BackgroundTransparency=1}, util)
txt(wpHeader, "WAYPOINTS (Save Location)", 11, P.warn, UDim2.new(), UDim2.new(1,0,1,0))

local function createWP(index, order)
	local r = mk("Frame", {Size=UDim2.new(1,0,0,28), LayoutOrder=order, BackgroundColor3=P.row, BorderSizePixel=0}, util)
	mk("UICorner", {CornerRadius=UDim.new(0,6)}, r)
	txt(r, "Slot "..index, 12, P.text, UDim2.fromOffset(10,0), UDim2.new(0.4,0,1,0))
	
	local saveBtn = mk("TextButton", {Size=UDim2.new(0.3,-4,0.8,0), Position=UDim2.new(0.4,0,0.1,0), BackgroundColor3=P.ok, Text="SAVE", TextColor3=P.ink, Font=FONT, TextSize=11, AutoButtonColor=false}, r)
	mk("UICorner", {CornerRadius=UDim.new(0,4)}, saveBtn)
	
	local tpBtn = mk("TextButton", {Size=UDim2.new(0.3,-4,0.8,0), Position=UDim2.new(0.7,0,0.1,0), BackgroundColor3=P.bg, Text="TP", TextColor3=P.dim, Font=FONT, TextSize=11, AutoButtonColor=false}, r)
	mk("UICorner", {CornerRadius=UDim.new(0,4)}, tpBtn)
	local tpStroke = mk("UIStroke", {Color=P.border, Thickness=1}, tpBtn)
	
	saveBtn.MouseButton1Click:Connect(function()
		local root = getRoot()
		if root then
			waypoints[index] = root.Position
			local orig = saveBtn.BackgroundColor3
			saveBtn.BackgroundColor3 = Color3.fromRGB(200, 255, 200)
			TweenService:Create(saveBtn, TweenInfo.new(0.4), {BackgroundColor3 = orig}):Play()
			
			tpBtn.BackgroundColor3 = P.blue
			tpBtn.TextColor3 = P.ink
			tpStroke.Color = P.blue
			addPulse(tpStroke, 0.4, 0.4, 2)
		end
	end)
	
	tpBtn.MouseButton1Click:Connect(function()
		local root = getRoot()
		if root and waypoints[index] then
			root.CFrame = CFrame.new(waypoints[index] + Vector3.new(0, 3, 0))
		end
	end)
end
createWP(1, 5); createWP(2, 6); createWP(3, 7)

local listBox, listFace = box(util, UDim2.new(1,0,0,70), nil, P.bg2); listBox.LayoutOrder = 8
playerListFrame = mk("ScrollingFrame", {Size=UDim2.new(1,-6,1,-6), Position=UDim2.fromOffset(3,3), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=P.plum, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y}, listFace)
mk("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder}, playerListFrame)
targetLabel = txt(util, "TARGET  -", 11, P.dim, nil, UDim2.new(1,0,0,16)); targetLabel.LayoutOrder = 9
local function updateTargetLabel() local n = "-"; if S.stick and stickTarget then n = stickTarget.Name elseif selectedPlayer then n = selectedPlayer.Name end; targetLabel.Text = "TARGET  "..n end
local act = mk("Frame", {Size=UDim2.new(1,0,0,28), LayoutOrder=10, BackgroundTransparency=1, BorderSizePixel=0}, util)
mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, act)
local teleBtn, teleFace = box(act, UDim2.new(0.5,-3,1,0), nil, P.pink, "TextButton"); teleBtn.LayoutOrder = 1
local teleTxt = txt(teleFace, "TELEPORT", 13, P.ink, UDim2.new(), nil, Enum.TextXAlignment.Center)
local stickBtn, stickFace = box(act, UDim2.new(0.5,-3,1,0), nil, P.bg, "TextButton"); stickBtn.LayoutOrder = 2
local stickTxt = txt(stickFace, "STICK", 13, P.text, UDim2.new(), nil, Enum.TextXAlignment.Center)
updateStickBtn = function() stickTxt.Text = S.stick and "UNSTICK" or "STICK"; stickTxt.TextColor3 = S.stick and P.warn or P.text end
tpLoopRow = featureRow(util, 11, {label="TP Loop", icon="loop", color=P.orange, key="tpLoop",
	on=function(on) if not on then return end; if not selectedPlayer then selectedPlayer = findNearest(math.huge); if not selectedPlayer then S.tpLoop = false; return end; updateTargetLabel(); refreshPlayerList() end
	if S.stick then S.stick = false; stopStick(); updateStickBtn() end; if S.fly then S.fly = false; stopFly(); flyRow.refresh(true) end end})

-- LIST LOGIC
refreshPlayerList = function()
	for _, c in ipairs(playerListFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	if selectedPlayer and not isAlive(selectedPlayer) then selectedPlayer = nil
		if S.stick and stickManual then S.stick = false; stopStick(); updateStickBtn() end
		if S.tpLoop then S.tpLoop = false; if tpLoopRow then tpLoopRow.refresh(true) end end end
	local list = {}; for _, p in pairs(Players:GetPlayers()) do if p ~= lp and isAlive(p) then table.insert(list, p) end end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end); countLbl.Text = "PLAYERS "..#list
	if #list == 0 then txt(playerListFrame, "NO ONE ELSE HERE", 11, P.dim, nil, UDim2.new(1,0,0,26), Enum.TextXAlignment.Center) end
	local mr = getRoot(); local pos = mr and mr.Position or Vector3.zero
	for i, p in ipairs(list) do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local hp = h and (h.Health/math.max(h.Max