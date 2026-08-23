--[[
	TWDO3 Fresh v2 | The Walking Dead Online 3 [BETA]
	gui: skeet lib | hosted: NexSync-dev/test.guilib
	built entirely from live decompilation + empirical testing (place v4501+)

	AC model (decompiled GunClient.ClientIntegrity):
	  - heartbeat rollback past legit horizontal speed, renderstep walkspeed
	    clamp, injected physics destroy+flag, humanoid state checks,
	    position-vs-velocity mismatch sampling - all IsOnFoot-gated
	  - server height pull-down above ~15-18 studs on foot (empirical)
	  - server anti-TP with AntiTPClientGraceUntil attribute + reanchor seq
	  - gun shots: client-signed tokens over shot tables (GunProtocolNonce)

	features:
	  - ESP: players / walkers / vehicles / loot(tier colors) + world memory
	    overlay that keeps showing loot through StreamingEnabled gaps
	  - aim assist: FOV, smoothing, wallcheck, priority, hold key
	  - silent aim: hooks workspace:Raycast namecall. GetAimPosition()
	    fingerprints as origin==camera pos && dir==LookVector*Range(>=100).
	    On armed shots the cast is re-run toward the target; a REAL
	    RaycastResult is returned so wallcheck is inherent and every token
	    downstream signs consistently. Angle-clamped to look legit.
	  - movement: low hover (<13st, PD controller), vehicle fly while driving,
	    walkboost via velocity <= 21 st/s (matches reported velocity so the
	    mismatch sampler stays clean)
	  - auto loot open replays Interaction.OpenLootPart's exact remote pair
	  - fullbright/no-fog/crosshair/fov/zoom QoL

	loadstring:
	  loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/TWDO3_fresh.lua"))()
]]

local genv = (type(getgenv) == "function" and getgenv()) or _G

if genv.TWDO3F_SHUTDOWN then
	pcall(genv.TWDO3F_SHUTDOWN)
end

local function loadLib()
	local urls = {
		"https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet%20lib.lua",
		"https://raw.githubusercontent.com/NexSync-dev/test.guilib/main/skeet%20lib.lua",
	}
	for _, url in ipairs(urls) do
		local ok, lib = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if ok and type(lib) == "table" and lib.CreateWindow then
			return lib
		end
	end
	local paths = {}
	if genv.SKEET_LIB_PATH then table.insert(paths, genv.SKEET_LIB_PATH) end
	table.insert(paths, "new/skeet lib.lua")
	for _, path in ipairs(paths) do
		if isfile and isfile(path) then
			local chunk = loadfile and loadfile(path)
			if not chunk and readfile then
				chunk = loadstring(readfile(path), path)
			end
			if chunk then
				local lok, llib = pcall(chunk)
				if lok and type(llib) == "table" and llib.CreateWindow then
					return llib
				end
			end
		end
	end
	error("[TWDO3F] skeet lib not found", 0)
end

local library = loadLib()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer
local hasDrawing = (type(Drawing) == "table") or (type(Drawing) == "function")
local hasMouseMove = (type(mousemoverel) == "function")
local hasHook = (type(hookmetamethod) == "function") and (type(getrawmetatable) == "function")

local ICONS = {
	esp = "rbxassetid://8547236654",
	aim = "rbxassetid://10723407389",
	silent = "rbxassetid://10734973670",
	move = "rbxassetid://6031280882",
	util = "rbxassetid://6034509993",
}

-- //////////////////////////////////////////////////////////////// settings

local S = {
	-- esp
	espEnabled = true,
	espMaxDist = 400,
	espTextSize = 13,

	espPlayers = true,
	espPlayerColor = Color3.fromRGB(255, 85, 85),
	playerBoxes = true,
	playerNames = true,
	playerDist = true,
	playerHealth = true,
	playerTracers = false,

	espWalkers = true,
	espWalkerColor = Color3.fromRGB(140, 210, 90),
	walkerBoxes = true,
	walkerNames = false,
	walkerDist = true,
	walkerHealth = false,
	walkerTracers = false,
	walkerCap = 40,

	espLoot = false,
	lootDist = 60,
	lootColor = Color3.fromRGB(255, 200, 60),
	tierColors = true,
	lootMinTier = 0,
	lootNames = true,
	lootCap = 30,

	espVehicles = false,
	vehicleColor = Color3.fromRGB(80, 200, 255),
	vehicleNames = true,
	vehicleDist = true,

	memoryESP = false,
	memoryRadius = 120,
	memoryCap = 40,
	memoryColor = Color3.fromRGB(180, 180, 180),

	-- aim assist
	aimEnabled = false,
	aimTargets = { 1 },
	aimFov = 90,
	aimShowFov = true,
	aimSmooth = 0.35,
	aimHead = true,
	aimHoldMode = true,
	aimWallcheck = true,
	aimMaxDist = 350,
	aimPriority = 1, -- 1 crosshair, 2 distance

	-- silent aim
	silentEnabled = false,
	silentTargets = { 1 },
	silentFov = 150,
	silentAngleClamp = 12,
	silentHead = true,
	silentWallcheck = true,
	silentShowStatus = true,

	-- visuals
	crosshair = false,
	crosshairStyle = 1, -- 1 cross, 2 dot, 3 both
	crosshairSize = 8,
	crosshairGap = 4,
	crosshairColor = Color3.fromRGB(255, 255, 255),
	fullbrightOn = false,
	noFogOn = false,
	fovChangerOn = false,
	customFov = 90,
	zoomOutOn = false,
	maxZoom = 128,

	-- movement
	hoverEnabled = false,
	hoverHeight = 10,
	hoverMaxAlt = 13,
	walkBoostOn = false,
	walkBoostSpeed = 18,
	walkBoostMax = 21,
	vehicleFlyOn = false,
	vflySpeed = 60,
	vflyVertSpeed = 40,

	-- utility
	instantLoot = false,
	lootRange = 6,
	lootCooldown = 0.4,
}

local state = {
	connections = {},
	groups = {},
	fovCircle = nil,
	silentFovCircle = nil,
	chDots = {},
	chLines = {},
	lootCache = nil,
	lootCacheAt = 0,
	lastLootOpen = 0,
	aimKeyDown = false,
	frames = 0,
	fpsAt = os.clock(),
	fps = 0,
	lastEspAt = 0,
	unloaded = false,
	silentArmUntil = 0,
	silentTargetPart = nil,
	silentStatus = "off",
	namecallHook = nil,
	rawNamecall = nil,

	memory = {}, -- [instance] = {pos=Vector3, name=string, tier=number?, kind=string, lastSeen=os.clock()}
	memoryScanAt = 0,
}

-- //////////////////////////////////////////////////////////////// helpers

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(state.connections, c)
	return c
end

local function cam()
	return Workspace.CurrentCamera
end

local function getRoot()
	local char = lp.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function myPos()
	local root = getRoot()
	return root and root.Position or cam().CFrame.Position
end

local function worldToScreen(v3)
	local c = cam()
	local vp, onScreen = c:WorldToViewportPoint(v3)
	return vp, onScreen, vp.Z
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundDistance()
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return -1 end
	rayParams.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -(S.hoverMaxAlt + 40), 0), rayParams)
	return hit and (hrp.Position.Y - hit.Position.Y) or -1
end

local function canSee(fromPart, targetPart)
	if not S.aimWallcheck then return true end
	local c = cam()
	rayParams.FilterDescendantsInstances = { lp.Character, targetPart.Parent }
	local hit = Workspace:Raycast(fromPart.Position, targetPart.Position - fromPart.Position, rayParams)
	if not hit then return true end
	return hit.Instance:IsDescendantOf(targetPart.Parent)
end

local function getWalkersFolder()
	local ai = Workspace:FindFirstChild("AI")
	return ai and ai:FindFirstChild("Walkers")
end

-- //////////////////////////////////////////////////////////////// drawing pool

local function newText()
	local d = Drawing.new("Text")
	d.Size = S.espTextSize
	d.Center = true
	d.Outline = true
	d.Visible = false
	d.Font = 2
	return d
end

local function getGroup(kind)
	local g = state.groups[kind]
	if not g then
		g = { free = {}, used = {} }
		state.groups[kind] = g
	end
	return g
end

local function releaseAll()
	for _, group in pairs(state.groups) do
		for _, obj in ipairs(group.used) do
			obj.Visible = false
			table.insert(group.free, obj)
		end
		group.used = {}
	end
end

local function takeFromPool(kind, maker)
	local group = getGroup(kind)
	local n = #group.free
	local obj
	if n > 0 then
		obj = group.free[n]
		table.remove(group.free, n)
	else
		obj = maker()
	end
	table.insert(group.used, obj)
	obj.Visible = true
	return obj
end

local function drawText(text, x, y, color, size)
	local t = takeFromPool("text", newText)
	t.Text = text
	t.Position = Vector2.new(x, y)
	t.Color = color
	t.Size = size or S.espTextSize
	return t
end

local function drawBox(centerX, topY, bottomY, color)
	local h = bottomY - topY
	if h < 4 then return end
	local w = h * 0.45
	local b = takeFromPool("box", function()
		local q = Drawing.new("Square")
		q.Thickness = 1
		q.Filled = false
		return q
	end)
	b.Size = Vector2.new(w * 2, h)
	b.Position = Vector2.new(centerX - w, topY)
	b.Color = color
end

local function drawLine(fromV2, toV2, color)
	local l = takeFromPool("line", function()
		local d = Drawing.new("Line")
		d.Thickness = 1
		return d
	end)
	l.From = fromV2
	l.To = toV2
	l.Color = color
end

-- //////////////////////////////////////////////////////////////// containers & world memory

local function collectContainers()
	local out = {}
	local lootables = Workspace:FindFirstChild("Lootables")
	if lootables then
		for _, m in ipairs(lootables:GetChildren()) do
			out[#out + 1] = m
		end
	end
	local corpses = Workspace:FindFirstChild("Corpses")
	if corpses then
		for _, d in ipairs(corpses:GetDescendants()) do
			if d:IsA("Model") and d.Name:sub(1, 5) == "Loot_" then
				out[#out + 1] = d
			end
		end
	end
	return out
end

local function tierFromName(name)
	return tonumber(name:match("_Tier(%d+)"))
end

-- streaming-aware registry: remembers container positions after their parts
-- stream out (models persist with pivots even when geometry is gone)
local function updateMemory()
	local now = os.clock()
	local mem = state.memory
	for _, m in ipairs(collectContainers()) do
		local okPivot, pivot = pcall(m.GetPivot, m)
		if okPivot and pivot then
			local e = mem[m]
			if not e then
				mem[m] = { pos = pivot.Position, name = m.Name, tier = tierFromName(m.Name), lastSeen = now }
			else
				e.pos = pivot.Position
				e.lastSeen = now
			end
		end
	end
	-- prune entries whose instances died
	for inst in pairs(mem) do
		if not inst.Parent then
			mem[inst] = nil
		end
	end
end

local function scanLootNear(pos)
	local now = os.clock()
	if state.lootCache and (now - state.lootCacheAt) < 0.5 then
		return state.lootCache
	end
	local results = {}
	local maxD = math.max(S.lootDist, S.lootRange + 2)
	local okInfo, LootInfo = pcall(require, ReplicatedStorage:WaitForChild("CLIENT_MODULES"):WaitForChild("LootInfo"))
	local seen = {}
	for _, m in ipairs(collectContainers()) do
		local okPivot, pivot = pcall(m.GetPivot, m)
		if okPivot and pivot then
			local d = (pivot.Position - pos).Magnitude
			if d <= maxD then
				local label = m.Name
				if okInfo and type(LootInfo) == "table" and LootInfo[m.Name] then
					label = LootInfo[m.Name].ItemName or label
				end
				results[#results + 1] = { model = m, pos = pivot.Position, dist = d, label = label, tier = tierFromName(m.Name), live = true }
				seen[m] = true
			end
		end
	end
	-- memory fallback for streamed-out containers
	if S.memoryESP or true then
		for inst, e in pairs(state.memory) do
			if not seen[inst] then
				local d = (e.pos - pos).Magnitude
				if d <= maxD then
					results[#results + 1] = { model = inst, pos = e.pos, dist = d, label = e.name, tier = e.tier, live = false }
				end
			end
		end
	end
	table.sort(results, function(a, b) return a.dist < b.dist end)
	state.lootCache = results
	state.lootCacheAt = now
	return results
end

local function lootColor(tier)
	if S.tierColors and tier then
		if tier >= 4 then
			return Color3.fromRGB(255, 215, 0)
		elseif tier == 3 then
			return Color3.fromRGB(186, 85, 211)
		elseif tier == 2 then
			return Color3.fromRGB(80, 200, 255)
		end
	end
	return S.lootColor
end

-- //////////////////////////////////////////////////////////////// esp

local function healthLabel(hum)
	if not hum then return "" end
	return string.format(" %d%%", math.floor((hum.Health / math.max(hum.MaxHealth, 1)) * 100))
end

local function espCharacter(hrp, hum, color, kind, label)
	local dist = (hrp.Position - myPos()).Magnitude
	local top, topOn = worldToScreen(hrp.Position + Vector3.new(0, 3, 0))
	local bottom, bottomOn = worldToScreen(hrp.Position - Vector3.new(0, 3, 0))
	if not (topOn and bottomOn) then return end
	local cx = (top.X + bottom.X) / 2

	if S[kind .. "Boxes"] then
		drawBox(cx, top.Y, bottom.Y, color)
	end
	if S[kind .. "Names"] and label then
		drawText(label, cx, top.Y - S.espTextSize - 2, color, S.espTextSize)
	end
	local extra = ""
	if S[kind .. "Health"] and hum then
		extra = healthLabel(hum)
	end
	if extra ~= "" then
		drawText(extra, cx, top.Y - (S.espTextSize + 2) * ((S[kind .. "Names"] and label) and 2 or 1), color, S.espTextSize - 1)
	end
	if S[kind .. "Dist"] then
		drawText(string.format("[%d]", math.floor(dist)), cx, bottom.Y + 1, color, S.espTextSize - 1)
	end
	if S[kind .. "Tracers"] then
		local vs = cam().ViewportSize
		drawLine(Vector2.new(vs.X / 2, vs.Y), Vector2.new(cx, bottom.Y), color)
	end
end

local function renderESP()
	releaseAll()
	if not S.espEnabled or not hasDrawing then return end
	local mypos = myPos()

	if S.espPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= lp then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 and (hrp.Position - mypos).Magnitude <= S.espMaxDist then
					espCharacter(hrp, hum, S.espPlayerColor, "player", plr.DisplayName)
				end
			end
		end
	end

	if S.espWalkers then
		local wf = getWalkersFolder()
		if wf then
			local near = {}
			for _, w in ipairs(wf:GetChildren()) do
				local hrp = w:FindFirstChild("HumanoidRootPart")
				if hrp then
					local d = (hrp.Position - mypos).Magnitude
					if d <= S.espMaxDist then
						near[#near + 1] = { hrp = hrp, d = d, hum = w:FindFirstChildOfClass("Humanoid") }
					end
				end
			end
			table.sort(near, function(a, b) return a.d < b.d end)
			for i = 1, math.min(#near, S.walkerCap) do
				espCharacter(near[i].hrp, near[i].hum, S.espWalkerColor, "walker", "Walker")
			end
		end
	end

	if S.espVehicles then
		local cars = Workspace:FindFirstChild("Cars")
		if cars then
			for _, car in ipairs(cars:GetChildren()) do
				local okPivot, pivot = pcall(car.GetPivot, car)
				if okPivot and pivot then
					local d = (pivot.Position - mypos).Magnitude
					if d <= S.espMaxDist then
						local vp, onScreen, depth = worldToScreen(pivot.Position)
						if onScreen and depth > 0 then
							local label = car.Name
							if S.vehicleDist then
								label = label .. string.format(" [%d]", math.floor(d))
							end
							drawText(label, vp.X, vp.Y - 7, S.vehicleColor, S.espTextSize)
						end
					end
				end
			end
		end
	end

	if S.espLoot then
		local entries = scanLootNear(mypos)
		local drawn = 0
		for _, e in ipairs(entries) do
			if drawn >= S.lootCap then break end
			if (S.lootMinTier == 0) or (e.tier and e.tier >= S.lootMinTier) then
				local vp, onScreen, depth = worldToScreen(e.pos)
				if onScreen and depth > 0 then
					drawn = drawn + 1
					drawText(e.label .. string.format(" [%d]", math.floor(e.dist)), vp.X, vp.Y - 7, lootColor(e.tier), S.espTextSize - 1)
				end
			end
		end
	end

	if S.memoryESP then
		local now = os.clock()
		local drawn = 0
		local best = {}
		for inst, e in pairs(state.memory) do
			local d = (e.pos - mypos).Magnitude
			if d <= S.memoryRadius then
				best[#best + 1] = { e = e, d = d }
			end
		end
		table.sort(best, function(a, b) return a.d < b.d end)
		for i = 1, math.min(#best, S.memoryCap) do
			local e = best[i].e
			local vp, onScreen, depth = worldToScreen(e.pos)
			if onScreen and depth > 0 then
				drawn = drawn + 1
				drawText("*" .. e.name, vp.X, vp.Y - 7, S.memoryColor, S.espTextSize - 2)
			end
		end
	end
end

-- //////////////////////////////////////////////////////////////// targeting

local function gatherTargets(kindTargets, headPref, maxDist, wallcheck, priorityCrosshair)
	local c = cam()
	local center = c.ViewportSize / 2
	local mypos = myPos()
	local best, bestScore = nil, math.huge
	local myChar = lp.Character

	local function consider(model, part)
		if not part then return end
		local d3 = (part.Position - mypos).Magnitude
		if d3 > maxDist then return end
		local vp, onScreen, depth = worldToScreen(part.Position)
		if not onScreen or depth <= 0 then return end
		if wallcheck and myChar then
			rayParams.FilterDescendantsInstances = { myChar, model }
			local hit = Workspace:Raycast(c.CFrame.Position, part.Position - c.CFrame.Position, rayParams)
			if hit and not hit.Instance:IsDescendantOf(model) then return end
		end
		local sp = Vector2.new(vp.X, vp.Y)
		local score = priorityCrosshair and (sp - center).Magnitude or d3
		if score < bestScore then
			best, bestScore = part, score
		end
	end

	for _, t in ipairs(kindTargets) do
		if t == 1 then
			local wf = getWalkersFolder()
			if wf then
				for _, w in ipairs(wf:GetChildren()) do
					local hum = w:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health > 0 then
						local part = headPref and (w:FindFirstChild("HeadHitbox") or w:FindFirstChild("Head")) or w:FindFirstChild("HumanoidRootPart")
						consider(w, part)
					end
				end
			end
		elseif t == 2 then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= lp and plr.Character then
					local hum = plr.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						local part = headPref and plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
						consider(plr.Character, part)
					end
				end
			end
		end
	end
	return best
end

local function findAimTarget()
	return gatherTargets(S.aimTargets, S.aimHead, S.aimMaxDist, S.aimWallcheck, S.aimPriority == 1)
end

local function stepAim()
	if not hasDrawing then return end

	local circle = state.fovCircle
	if not circle then
		circle = Drawing.new("Circle")
		circle.Thickness = 1
		circle.NumSides = 64
		circle.Filled = false
		state.fovCircle = circle
	end
	circle.Radius = S.aimFov
	circle.Position = cam().ViewportSize / 2
	circle.Visible = S.aimEnabled and S.aimShowFov

	if not S.aimEnabled or not hasMouseMove then return end
	if S.aimHoldMode and not state.aimKeyDown then return end
	local target = findAimTarget()
	if not target then return end
	local vp, onScreen, depth = worldToScreen(target.Position)
	if not onScreen or depth <= 0 then return end
	local center = cam().ViewportSize / 2
	local delta = Vector2.new(vp.X - center.X, vp.Y - center.Y)
	mousemoverel(delta.X * math.clamp(S.aimSmooth, 0.05, 1), delta.Y * math.clamp(S.aimSmooth, 0.05, 1))
end

-- //////////////////////////////////////////////////////////////// silent aim
--
-- GetAimPosition() (GunClient decompile ~line 4055):
--     Position_4 = camera.CFrame.Position
--     v240       = camera.CFrame.LookVector * weapon.Range   (default 300)
--     workspace:Raycast(Position_4, v240, BuildVisualParams())
-- That call is unique: nothing else casts >=100 studs exactly along the
-- camera LookVector from the camera position. When armed we re-cast toward
-- the locked target and hand back the REAL RaycastResult of that cast, so
-- occlusion decides everything and all downstream signatures stay valid.

local function angleBetween(a, b)
	return math.deg(math.acos(math.clamp(a:Dot(b) / math.max(a.Magnitude * b.Magnitude, 1e-6), -1, 1)))
end

local function clampedDirection(currentDir, desiredDir, maxDeg)
	local ang = angleBetween(currentDir, desiredDir)
	if ang <= maxDeg or ang < 0.01 then
		return desiredDir.Unit
	end
	local t = math.rad(maxDeg) / math.rad(ang)
	-- slerp between unit vectors
	local dot = math.clamp(currentDir.Unit:Dot(desiredDir.Unit), -1, 1)
	local theta = math.acos(dot)
	if theta < 1e-4 then
		return desiredDir.Unit
	end
	local w1 = math.sin((1 - t) * theta) / math.sin(theta)
	local w2 = math.sin(t * theta) / math.sin(theta)
	local result = currentDir.Unit * w1 + desiredDir.Unit * w2
	if result.Magnitude < 1e-4 then
		return currentDir.Unit
	end
	return result.Unit
end

local function installSilentAim()
	if not hasHook then
		state.silentStatus = "no hook support"
		return
	end
	local mt = getrawmetatable(game)
	local oldIndex = mt.__index
	local oldNamecall = mt.__namecall
	setreadonly(mt, false)

	local function isFingerprint(self, origin, direction)
		if self ~= Workspace then return false end
		local c = cam()
		if (c.CFrame.Position - origin).Magnitude > 0.1 then return false end
		if direction.Magnitude < 100 then return false end
		local lv = c.CFrame.LookVector
		if (direction.Unit:Dot(lv)) < 0.999 then return false end
		return true
	end

	state.rawNamecall = oldNamecall
	local function silentRaycastHook(self, ...)
		local method = getnamecallmethod()
		if method == "Raycast" and os.clock() < state.silentArmUntil and self == Workspace then
			local args = { ... }
			local origin, direction = args[1], args[2]
			if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and isFingerprint(self, origin, direction) then
				local target = state.silentTargetPart
				local targetModel = target and target.Parent
				if target then
					local desired = (target.Position - origin).Unit
					local finalDir = clampedDirection(direction, desired, S.silentAngleClamp)
					local castDist = math.min(direction.Magnitude, (target.Position - origin).Magnitude + 5)
					rayParams.FilterDescendantsInstances = { lp.Character }
					local realResult = oldNamecall(self, origin, finalDir * castDist, args[3])
					if realResult and realResult.Instance and targetModel and realResult.Instance:IsDescendantOf(targetModel) then
						state.silentStatus = "locked"
						return realResult
					end
					state.silentStatus = "blocked"
					-- fall through: original cast result (wall in the way)
				end
			end
		end
		return oldNamecall(self, ...)
	end
	if type(newcclosure) == "function" then
		pcall(function() silentRaycastHook = newcclosure(silentRaycastHook) end)
	end
	state.namecallHook = hookmetamethod(game, "__namecall", silentRaycastHook)
	setreadonly(mt, true)
	state.silentStatus = "ready"
end

local function uninstallSilentAim()
	pcall(function()
		if state.namecallHook and type(restoremetamethod) == "function" then
			restoremetamethod("__namecall")
		elseif state.rawNamecall and getrawmetatable then
			local mt = getrawmetatable(game)
			setreadonly(mt, false)
			mt.__namecall = state.rawNamecall
			setreadonly(mt, true)
		end
	end)
	state.namecallHook = nil
end

connect(UserInputService.InputBegan, function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and S.silentEnabled then
		if state.silentTargetPart then
			state.silentArmUntil = os.clock() + 0.15
		end
	end
end)

local function stepSilent()
	if not S.silentEnabled then
		state.silentTargetPart = nil
		return
	end
	if not hasDrawing then return end
	local circle = state.silentFovCircle
	if not circle then
		circle = Drawing.new("Circle")
		circle.Thickness = 1
		circle.NumSides = 48
		circle.Filled = false
		circle.Color = Color3.fromRGB(255, 170, 0)
		state.silentFovCircle = circle
	end
	circle.Radius = S.silentFov
	circle.Position = cam().ViewportSize / 2
	circle.Visible = S.silentShowStatus

	state.silentTargetPart = gatherTargets(S.silentTargets, S.silentHead, S.aimMaxDist, S.silentWallcheck, true)
end

-- //////////////////////////////////////////////////////////////// visuals

local LightingDefaults = {
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function applyFullbright(on)
	if on then
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(140, 140, 140)
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
	else
		Lighting.Brightness = LightingDefaults.Brightness
		Lighting.ClockTime = LightingDefaults.ClockTime
		Lighting.Ambient = LightingDefaults.Ambient
		Lighting.OutdoorAmbient = LightingDefaults.OutdoorAmbient
	end
end

local function applyNoFog(on)
	if on then
		Lighting.FogEnd = 1e6
		Lighting.FogStart = 1e6
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Atmosphere") then
				child.Density = 0
				child.Offset = 0
			end
		end
	else
		Lighting.FogEnd = LightingDefaults.FogEnd
		Lighting.FogStart = LightingDefaults.FogStart
	end
end

local function applyCrosshair()
	if not hasDrawing then return end
	while #state.chLines < 4 do
		local l = Drawing.new("Line")
		l.Thickness = 1
		l.Visible = false
		state.chLines[#state.chLines + 1] = l
	end
	while #state.chDots < 1 do
		local d = Drawing.new("Circle")
		d.Thickness = 1
		d.NumSides = 12
		d.Filled = true
		d.Radius = 2
		d.Visible = false
		state.chDots[1] = d
	end
	local c = cam()
	local cx, cy = c.ViewportSize.X / 2, c.ViewportSize.Y / 2
	local wantLines = S.crosshair and (S.crosshairStyle ~= 2)
	local wantDot = S.crosshair and (S.crosshairStyle ~= 1)
	local segs = {
		{ Vector2.new(cx - S.crosshairGap - S.crosshairSize, cy), Vector2.new(cx - S.crosshairGap, cy) },
		{ Vector2.new(cx + S.crosshairGap, cy), Vector2.new(cx + S.crosshairGap + S.crosshairSize, cy) },
		{ Vector2.new(cx, cy - S.crosshairGap - S.crosshairSize), Vector2.new(cx, cy - S.crosshairGap) },
		{ Vector2.new(cx, cy + S.crosshairGap), Vector2.new(cx, cy + S.crosshairGap + S.crosshairSize) },
	}
	for i, l in ipairs(state.chLines) do
		l.Visible = wantLines
		if wantLines then
			l.From = segs[i][1]
			l.To = segs[i][2]
			l.Color = S.crosshairColor
		end
	end
	local dot = state.chDots[1]
	dot.Visible = wantDot
	if wantDot then
		dot.Position = Vector2.new(cx, cy)
		dot.Color = S.crosshairColor
	end
end

-- //////////////////////////////////////////////////////////////// movement

local function stepHover()
	if not S.hoverEnabled then return end
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 then return end
	if hum.SeatPart then return end
	local gd = groundDistance()
	if gd < 0 then return end
	local targetY = math.min(S.hoverHeight, S.hoverMaxAlt)
	local errV = targetY - gd
	hrp.AssemblyLinearVelocity = Vector3.new(
		hrp.AssemblyLinearVelocity.X,
		math.clamp(errV * 3, -25, 30),
		hrp.AssemblyLinearVelocity.Z
	)
end

local function getDrivenVehicleRoot()
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat then return nil end
	local root = seat.AssemblyRootPart or seat
	if not (root and root:IsA("BasePart")) then return nil end
	return root, seat
end

local function stepVehicleFly(dt)
	if not S.vehicleFlyOn then return end
	local root, seat = getDrivenVehicleRoot()
	if not root then return end
	local vel = Vector3.zero
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0.05 then
		vel = hum.MoveDirection.Unit * S.vflySpeed
	end
	local vert = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vert = S.vflyVertSpeed end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vert = -S.vflyVertSpeed end
	root.AssemblyLinearVelocity = Vector3.new(vel.X, vert, vel.Z)
end

local function stepWalkBoost()
	if not S.walkBoostOn then return end
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) or hum.Health <= 0 then return end
	if hum.SeatPart then return end
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.05 then return end
	local speed = math.min(S.walkBoostSpeed, S.walkBoostMax)
	-- velocity matches the position delta it produces, so the mismatch
	-- sampler never sees an anomaly; Y untouched so gravity stays native
	hrp.AssemblyLinearVelocity = Vector3.new(dir.Unit.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Unit.Z * speed)
end

-- //////////////////////////////////////////////////////////////// auto loot open

local CR = ReplicatedStorage:FindFirstChild("CLIENT_REMOTES")

local function tryInstantLoot()
	if not S.instantLoot or not CR then return end
	local now = os.clock()
	if now - state.lastLootOpen < S.lootCooldown then return end
	local setCursor = CR:FindFirstChild("SetCursorHit")
	local updateUI = CR:FindFirstChild("UpdateStorageUI")
	if not (setCursor and updateUI) then return end

	local pg = lp:FindFirstChildOfClass("PlayerGui")
	local inv = pg and pg:FindFirstChild("Inventory")
	if inv and inv.Visible then return end

	local mypos = myPos()
	local best, bestD = nil, S.lootRange
	for _, m in ipairs(collectContainers()) do
		local okPivot, pivot = pcall(m.GetPivot, m)
		if okPivot and pivot then
			local d = (pivot.Position - mypos).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	if best then
		state.lastLootOpen = now
		setCursor:FireServer(best)
		task.wait()
		updateUI:FireServer(best)
	end
end

-- //////////////////////////////////////////////////////////////// loops

connect(RunService.RenderStepped, function(dt)
	if state.unloaded then return end
	local now = os.clock()
	if now - state.lastEspAt >= 0.033 then
		state.lastEspAt = now
		renderESP()
		if now - state.memoryScanAt >= 2 then
			state.memoryScanAt = now
			updateMemory()
		end
	end
	stepAim()
	stepSilent()
	applyCrosshair()
	tryInstantLoot()
end)

connect(RunService.Heartbeat, function(dt)
	if state.unloaded then return end
	state.frames = state.frames + 1
	local now = os.clock()
	if now - state.fpsAt >= 1 then
		state.fps = state.frames / (now - state.fpsAt)
		state.frames = 0
		state.fpsAt = now
	end
	stepHover()
	stepVehicleFly(dt)
	stepWalkBoost()
end)

-- //////////////////////////////////////////////////////////////// ui

local window = library:CreateWindow({
	Name = "twdo3fresh",
	Size = Vector2.new(640, 540),
	Key = Enum.KeyCode.Insert,
})

local pageESP = window:CreatePage({ Icon = ICONS.esp, LayoutOrder = 1 })
local pageAim = window:CreatePage({ Icon = ICONS.aim, LayoutOrder = 2 })
local pageSilent = window:CreatePage({ Icon = ICONS.silent, LayoutOrder = 3 })
local pageMove = window:CreatePage({ Icon = ICONS.move, LayoutOrder = 4 })
local pageUtil = window:CreatePage({ Icon = ICONS.util, LayoutOrder = 5 })

-- esp page

local secMaster = pageESP:CreateSection({ Name = "ESP Master", Size = 110, Side = "Left" })
secMaster:CreateToggle({ Name = "Enable ESP", State = S.espEnabled, Callback = function(v) S.espEnabled = v end })
if not hasDrawing then
	secMaster:CreateLabel({}):Set("executor lacks Drawing lib")
end
secMaster:CreateSlider({ Name = "ESP Range", State = S.espMaxDist, Min = 50, Max = 2000, Step = 10, Suffix = "st", Callback = function(v) S.espMaxDist = v end })
secMaster:CreateSlider({ Name = "Text Size", State = S.espTextSize, Min = 10, Max = 20, Step = 1, Suffix = "px", Callback = function(v) S.espTextSize = v end })

local secPlayer = pageESP:CreateSection({ Name = "Players", Size = 240, Side = "Left" })
secPlayer:CreateToggle({ Name = "Player ESP", State = S.espPlayers, Callback = function(v) S.espPlayers = v end })
secPlayer:CreateToggle({ Name = "Boxes", State = S.playerBoxes, Callback = function(v) S.playerBoxes = v end })
secPlayer:CreateToggle({ Name = "Names", State = S.playerNames, Callback = function(v) S.playerNames = v end })
secPlayer:CreateToggle({ Name = "Distance", State = S.playerDist, Callback = function(v) S.playerDist = v end })
secPlayer:CreateToggle({ Name = "Health %", State = S.playerHealth, Callback = function(v) S.playerHealth = v end })
secPlayer:CreateToggle({ Name = "Tracers", State = S.playerTracers, Callback = function(v) S.playerTracers = v end })
secPlayer:CreateColorpicker({ Name = "Player Color", State = S.espPlayerColor, Callback = function(c) S.espPlayerColor = c end })

local secLoot = pageESP:CreateSection({ Name = "Loot", Size = 250, Side = "Left" })
secLoot:CreateToggle({ Name = "Loot ESP", State = S.espLoot, Callback = function(v) S.espLoot = v end })
secLoot:CreateToggle({ Name = "Tier Colors", State = S.tierColors, Callback = function(v) S.tierColors = v end })
secLoot:CreateDropdown({
	Name = "Min Tier",
	State = 1,
	Options = { "Any", "T2+", "T3+", "T4 only" },
	Callback = function(i) S.lootMinTier = i - 1 end,
})
secLoot:CreateSlider({ Name = "Loot Range", State = S.lootDist, Min = 20, Max = 200, Step = 5, Suffix = "st", Callback = function(v) S.lootDist = v; state.lootCache = nil end })
secLoot:CreateSlider({ Name = "Draw Cap", State = S.lootCap, Min = 5, Max = 80, Step = 5, Callback = function(v) S.lootCap = v end })
secLoot:CreateColorpicker({ Name = "Base Color", State = S.lootColor, Callback = function(c) S.lootColor = c end })

local secWalker = pageESP:CreateSection({ Name = "Walkers", Size = 245, Side = "Right" })
secWalker:CreateToggle({ Name = "Walker ESP", State = S.espWalkers, Callback = function(v) S.espWalkers = v end })
secWalker:CreateToggle({ Name = "Boxes", State = S.walkerBoxes, Callback = function(v) S.walkerBoxes = v end })
secWalker:CreateToggle({ Name = "Names", State = S.walkerNames, Callback = function(v) S.walkerNames = v end })
secWalker:CreateToggle({ Name = "Distance", State = S.walkerDist, Callback = function(v) S.walkerDist = v end })
secWalker:CreateToggle({ Name = "Health %", State = S.walkerHealth, Callback = function(v) S.walkerHealth = v end })
secWalker:CreateToggle({ Name = "Tracers", State = S.walkerTracers, Callback = function(v) S.walkerTracers = v end })
secWalker:CreateSlider({ Name = "Draw Cap", State = S.walkerCap, Min = 5, Max = 100, Step = 5, Callback = function(v) S.walkerCap = v end })
secWalker:CreateColorpicker({ Name = "Walker Color", State = S.espWalkerColor, Callback = function(c) S.espWalkerColor = c end })

local secStream = pageESP:CreateSection({ Name = "World Memory (streaming)", Size = 190, Side = "Right" })
secStream:CreateToggle({ Name = "Memory ESP", State = S.memoryESP, Callback = function(v) S.memoryESP = v end })
secStream:CreateSlider({ Name = "Memory Radius", State = S.memoryRadius, Min = 40, Max = 400, Step = 10, Suffix = "st", Callback = function(v) S.memoryRadius = v end })
secStream:CreateSlider({ Name = "Draw Cap", State = S.memoryCap, Min = 5, Max = 100, Step = 5, Callback = function(v) S.memoryCap = v end })
secStream:CreateColorpicker({ Name = "Memory Color", State = S.memoryColor, Callback = function(c) S.memoryColor = c end })
secStream:CreateLabel({}):Set("remembers loot through stream gaps")

local secVehicle = pageESP:CreateSection({ Name = "Vehicles", Size = 135, Side = "Right" })
secVehicle:CreateToggle({ Name = "Vehicle ESP", State = S.espVehicles, Callback = function(v) S.espVehicles = v end })
secVehicle:CreateToggle({ Name = "Names", State = S.vehicleNames, Callback = function(v) S.vehicleNames = v end })
secVehicle:CreateToggle({ Name = "Distance", State = S.vehicleDist, Callback = function(v) S.vehicleDist = v end })
secVehicle:CreateColorpicker({ Name = "Vehicle Color", State = S.vehicleColor, Callback = function(c) S.vehicleColor = c end })

-- aim assist page

local secAim = pageAim:CreateSection({ Name = "Aim Assist", Size = 280, Side = "Left" })
secAim:CreateToggle({ Name = "Enable Aim Assist", State = S.aimEnabled, Callback = function(v) S.aimEnabled = v end })
secAim:CreateMultibox({
	Name = "Targets",
	State = { 1 },
	Options = { "Walkers", "Players" },
	Callback = function(indices) S.aimTargets = (#indices > 0) and indices or { 1 } end,
})
secAim:CreateDropdown({
	Name = "Aim Part",
	State = 1,
	Options = { "Head", "Torso" },
	Callback = function(i) S.aimHead = (i == 1) end,
})
secAim:CreateDropdown({
	Name = "Priority",
	State = 1,
	Options = { "Closest to Crosshair", "Nearest Distance" },
	Callback = function(i) S.aimPriority = i end,
})
secAim:CreateSlider({ Name = "FOV", State = S.aimFov, Min = 20, Max = 400, Step = 5, Suffix = "px", Callback = function(v) S.aimFov = v end })
secAim:CreateSlider({ Name = "Smoothing", State = S.aimSmooth * 100, Min = 5, Max = 100, Step = 5, Suffix = "%", Callback = function(v) S.aimSmooth = v / 100 end })
secAim:CreateSlider({ Name = "Max Target Dist", State = S.aimMaxDist, Min = 50, Max = 800, Step = 10, Suffix = "st", Callback = function(v) S.aimMaxDist = v end })
secAim:CreateToggle({ Name = "Wallcheck", State = S.aimWallcheck, Callback = function(v) S.aimWallcheck = v end })
secAim:CreateToggle({ Name = "Show FOV Circle", State = S.aimShowFov, Callback = function(v) S.aimShowFov = v end })
secAim:CreateToggle({ Name = "Hold Mode", State = S.aimHoldMode, Callback = function(v) S.aimHoldMode = v end })
secAim:CreateKeybind({
	Name = "Aim Hold Key",
	State = { "UserInputType", "MouseButton2" },
	Mode = "Hold",
	Callback = function(value)
		if type(value) == "boolean" then
			state.aimKeyDown = value
		end
	end,
})

local secNote = pageAim:CreateSection({ Name = "Safety Notes", Size = 130, Side = "Right" })
secNote:CreateLabel({}):Set("aim assist is input-level only")
secNote:CreateLabel({}):Set("wallcheck uses real raycasts")
secNote:CreateLabel({}):Set("silent aim lives on its own tab")
secNote:CreateLabel({}):Set("keep angle clamp small to look human")

-- silent aim page

local secSilent = pageSilent:CreateSection({ Name = "Silent Aim", Size = 260, Side = "Left" })
if not hasHook then
	secSilent:CreateLabel({}):Set("hookmetamethod unsupported here")
end
secSilent:CreateToggle({ Name = "Enable Silent Aim", State = false, Callback = function(v)
	S.silentEnabled = v
	if v and not state.namecallHook then
		installSilentAim()
	end
end })
secSilent:CreateMultibox({
	Name = "Targets",
	State = { 1 },
	Options = { "Walkers", "Players" },
	Callback = function(indices) S.silentTargets = (#indices > 0) and indices or { 1 } end,
})
secSilent:CreateDropdown({
	Name = "Hit Part",
	State = 1,
	Options = { "Head", "Torso" },
	Callback = function(i) S.silentHead = (i == 1) end,
})
secSilent:CreateSlider({ Name = "Target FOV", State = S.silentFov, Min = 30, Max = 600, Step = 10, Suffix = "px", Callback = function(v) S.silentFov = v end })
secSilent:CreateSlider({ Name = "Angle Clamp", State = S.silentAngleClamp, Min = 3, Max = 45, Step = 1, Suffix = "deg", Callback = function(v) S.silentAngleClamp = v end })
secSilent:CreateToggle({ Name = "Wallcheck", State = S.silentWallcheck, Callback = function(v) S.silentWallcheck = v end })
secSilent:CreateToggle({ Name = "Show Status Circle", State = S.silentShowStatus, Callback = function(v) S.silentShowStatus = v end })

local secHowItWorks = pageSilent:CreateSection({ Name = "How It Works", Size = 170, Side = "Right" })
secHowItWorks:CreateLabel({}):Set("hooks Raycast namecall")
secHowItWorks:CreateLabel({}):Set("GetAimPosition fingerprinted:")
secHowItWorks:CreateLabel({}):Set("cam.pos + LookVec*Range cast")
secHowItWorks:CreateLabel({}):Set("re-cast at target on click")
secHowItWorks:CreateLabel({}):Set("real result => walls respected")
secHowItWorks:CreateLabel({}):Set("tokens sign post-redirect data")
local silentStatusLabel = secHowItWorks:CreateLabel({})
silentStatusLabel:Set("status: off")

-- movement page

local secGround = pageMove:CreateSection({ Name = "On Foot", Size = 230, Side = "Left" })
secGround:CreateToggle({
	Name = "Low Hover",
	State = false,
	Callback = function(v)
		S.hoverEnabled = v
		if not v then
			local char = lp.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
			end
		end
	end,
})
secGround:CreateSlider({
	Name = "Hover Height",
	State = S.hoverHeight,
	Min = 4,
	Max = 12,
	Step = 1,
	Suffix = "st",
	Callback = function(v) S.hoverHeight = math.min(v, S.hoverMaxAlt) end,
})
secGround:CreateToggle({
	Name = "Walk Boost",
	State = false,
	Callback = function(v) S.walkBoostOn = v end,
})
secGround:CreateSlider({
	Name = "Boost Speed",
	State = S.walkBoostSpeed,
	Min = 16,
	Max = S.walkBoostMax,
	Step = 1,
	Suffix = "st/s",
	Callback = function(v) S.walkBoostSpeed = v end,
})
secGround:CreateLabel({}):Set("boost <=21 matches AC tolerance")
secGround:CreateLabel({}):Set("hover capped under height pull")

local secVehicle = pageMove:CreateSection({ Name = "Vehicle", Size = 190, Side = "Left" })
secVehicle:CreateToggle({
	Name = "Vehicle Fly (while driving)",
	State = false,
	Callback = function(v)
		S.vehicleFlyOn = v
		local root = getDrivenVehicleRoot()
		if not v and root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end,
})
secVehicle:CreateSlider({ Name = "Fly Speed", State = S.vflySpeed, Min = 20, Max = 200, Step = 5, Suffix = "st/s", Callback = function(v) S.vflySpeed = v end })
secVehicle:CreateSlider({ Name = "Vertical Speed", State = S.vflyVertSpeed, Min = 10, Max = 120, Step = 5, Suffix = "st/s", Callback = function(v) S.vflyVertSpeed = v end })
secVehicle:CreateLabel({}):Set("drive + WASD, Space up Shift down")

local secMoveNotes = pageMove:CreateSection({ Name = "Enforcement Notes", Size = 160, Side = "Right" })
secMoveNotes:CreateLabel({}):Set("rollback/mismatch: IsOnFoot gated")
secMoveNotes:CreateLabel({}):Set("height pull >~15st (server side)")
secMoveNotes:CreateLabel({}):Set("anti-TP: no blink teleports")
secMoveNotes:CreateLabel({}):Set("short roof hops via hover OK")

-- utility page

local secLootUtil = pageUtil:CreateSection({ Name = "Looting", Size = 190, Side = "Left" })
secLootUtil:CreateToggle({
	Name = "Auto Open Nearby Container",
	State = false,
	Callback = function(v) S.instantLoot = v end,
})
secLootUtil:CreateSlider({ Name = "Range", State = S.lootRange, Min = 4, Max = 12, Step = 1, Suffix = "st", Callback = function(v) S.lootRange = v end })
secLootUtil:CreateSlider({ Name = "Retry Delay", State = S.lootCooldown * 10, Min = 2, Max = 20, Step = 1, Suffix = "x0.1s", Callback = function(v) S.lootCooldown = v / 10 end })
secLootUtil:CreateLabel({}):Set("replays legit E sequence:")
secLootUtil:CreateLabel({}):Set("SetCursorHit -> UpdateStorageUI")

local secVisualsU = pageUtil:CreateSection({ Name = "Visuals", Size = 210, Side = "Left" })
secVisualsU:CreateDropdown({
	Name = "Crosshair Style",
	State = 1,
	Options = { "Cross", "Dot", "Both" },
	Callback = function(i) S.crosshairStyle = i end,
})
secVisualsU:CreateSlider({ Name = "Cross Length", State = S.crosshairSize, Min = 2, Max = 30, Step = 1, Suffix = "px", Callback = function(v) S.crosshairSize = v end })
secVisualsU:CreateSlider({ Name = "Cross Gap", State = S.crosshairGap, Min = 0, Max = 20, Step = 1, Suffix = "px", Callback = function(v) S.crosshairGap = v end })
secVisualsU:CreateColorpicker({ Name = "Cross Color", State = S.crosshairColor, Callback = function(c) S.crosshairColor = c end })
secVisualsU:CreateToggle({ Name = "Fullbright", State = false, Callback = function(v)
	S.fullbrightOn = v
	applyFullbright(v)
end })
secVisualsU:CreateToggle({ Name = "No Fog", State = false, Callback = function(v)
	S.noFogOn = v
	applyNoFog(v)
end })

local secInfo = pageUtil:CreateSection({ Name = "Status", Size = 150, Side = "Right" })
local fpsLabel = secInfo:CreateLabel({})
local walkerLabel = secInfo:CreateLabel({})
local playerLabel = secInfo:CreateLabel({})
local memoryLabel = secInfo:CreateLabel({})

connect(RunService.Heartbeat, function()
	if state.unloaded then return end
	pcall(function() fpsLabel:Set(string.format("fps %d", math.floor(state.fps + 0.5))) end)
	pcall(function()
		local wf = getWalkersFolder()
		walkerLabel:Set(string.format("walkers loaded %d", wf and #wf:GetChildren() or 0))
	end)
	pcall(function() playerLabel:Set(string.format("players %d/%d", #Players:GetPlayers(), Players.MaxPlayers)) end)
	pcall(function()
		local n = 0
		for _ in pairs(state.memory) do n = n + 1 end
		memoryLabel:Set(string.format("memory entries %d", n))
	end)
end)

local secCleanup = pageUtil:CreateSection({ Name = "Cleanup", Size = 130, Side = "Right" })
secCleanup:CreateToggle({ Name = "Crosshair", State = false, Callback = function(v) S.crosshair = v end })
secCleanup:CreateToggle({
	Name = "FOV Changer",
	State = false,
	Callback = function(v)
		S.fovChangerOn = v
		cam().FieldOfView = v and S.customFov or 70
	end,
})
secCleanup:CreateSlider({
	Name = "Custom FOV",
	State = S.customFov,
	Min = 50,
	Max = 120,
	Step = 1,
	Callback = function(v)
		S.customFov = v
		if S.fovChangerOn then cam().FieldOfView = v end
	end,
})
secCleanup:CreateButton({
	Name = "Restore Visuals",
	Callback = function()
		applyFullbright(false)
		applyNoFog(false)
		cam().FieldOfView = 70
		lp.CameraMaxZoomDistance = 40
	end,
})
secCleanup:CreateButton({
	Name = "Unload Script",
	Callback = function()
		pcall(genv.TWDO3F_SHUTDOWN)
	end,
})

-- status updater for silent aim label

do
	local acc = 0
	connect(RunService.Heartbeat, function(dt)
		if state.unloaded then return end
		acc = acc + dt
		if acc >= 0.5 then
			acc = 0
			local txt
			if not hasHook then
				txt = "status: no hook support"
			elseif not S.silentEnabled then
				txt = "status: off"
			elseif state.silentTargetPart then
				txt = "status: target acquired"
			else
				txt = "status: searching"
			end
			pcall(function() silentStatusLabel:Set(txt) end)
		end
	end)
end

-- //////////////////////////////////////////////////////////////// shutdown

genv.TWDO3F_SHUTDOWN = function()
	state.unloaded = true
	uninstallSilentAim()
	for _, c in ipairs(state.connections) do
		pcall(function() c:Disconnect() end)
	end
	state.connections = {}
	pcall(function()
		for _, group in pairs(state.groups) do
			for _, obj in ipairs(group.used) do obj:Remove() end
			for _, obj in ipairs(group.free) do obj:Remove() end
		end
	end)
	pcall(function()
		if state.fovCircle then state.fovCircle:Remove() end
		if state.silentFovCircle then state.silentFovCircle:Remove() end
		for _, l in ipairs(state.chLines) do l:Remove() end
		for _, d in ipairs(state.chDots) do d:Remove() end
	end)
	state.groups = {}
	state.fovCircle = nil
	state.chLines = {}
	state.chDots = {}
	S.hoverEnabled = false
	S.vehicleFlyOn = false
	S.walkBoostOn = false
	pcall(applyFullbright, false)
	pcall(applyNoFog, false)
	pcall(function() cam().FieldOfView = 70 end)
	pcall(function() lp.CameraMaxZoomDistance = 40 end)
	genv.TWDO3F_SHUTDOWN = nil
end

print("[TWDO3F v2] loaded - Insert toggles menu | RMB aims | LMB arms silent")
