-- Film rig client: the same route every take, filmed from the real player camera where a player would look.
--  1 spawn view (hold), 2 walk to the campfire, 3 walk to the portal, 4 run: place, upgrade, sell a Ranger,
--  5 a wave from the hero, 6 ground close-ups (towers' feet, monsters on the path).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local cue = ReplicatedStorage.FilmCue
local player = Players.LocalPlayer

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end
local waiting = {}
cue.OnClientEvent:Connect(function(step)
	waiting[step] = true
end)
local function ask(step, arg)
	cue:FireServer(step, arg)
end
local function await(step, limit)
	local deadline = os.clock() + (limit or 60)
	while not waiting[step] and os.clock() < deadline do
		task.wait(0.1)
	end
	waiting[step] = nil
end

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
workspace:WaitForChild("Outpost")
task.wait(12) -- art streams in; ffmpeg starts on the "film start" mark
mark("film start")

local function walk(target, limit)
	humanoid:MoveTo(target)
	local done = false
	local c = humanoid.MoveToFinished:Connect(function()
		done = true
	end)
	local deadline = os.clock() + (limit or 8)
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	c:Disconnect()
end

-- 1-3 the hub at player height, the default follow camera
local c = Config.OutpostCenter
mark("hub spawn")
task.wait(4)
mark("hub campfire")
walk(c + Vector3.new(0, 0, 8), 6)
task.wait(1.5)
mark("hub portal")
walk(c + Vector3.new(0, 0, -2), 7) -- the plaza, short of the map pads
task.wait(2)
-- a slow look around from the portal back to spawn (what a player does with the camera)
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
local eye = root.Position + Vector3.new(0, 4, 0)
for i = 0, 90 do
	local a = math.rad(i * 2)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(eye + Vector3.new(math.sin(a) * 14, 5, math.cos(a) * 14), eye)
	task.wait(1 / 30)
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

-- the Beacon Tower's crystal close up (proof of the Tripo fix: violet glowing crystal, no white egg)
local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
local tower = c + HubLayout.Portal
local top = tower + Vector3.new(0, HubLayout.BeaconHeight * 0.74, 0)
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
for _, shot in { Vector3.new(0, 2, 26), Vector3.new(20, 4, 14), Vector3.new(-18, 3, -16) } do
	mark("beacon close")
	workspace.CurrentCamera.CFrame = CFrame.lookAt(top + shot, top)
	task.wait(2)
end
-- every station's building, as a player walking up to it sees it
for _, s in HubLayout.Stations do
	local at = c + s.At
	local inward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(at.X, 0, at.Z)).Unit
	mark("station " .. s.Id)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(at + inward * (s.Height * 1.6 + 6) + Vector3.new(0, 6, 0),
		at + Vector3.new(0, s.Height * 0.45, 0))
	task.wait(1.6)
end
-- each station's ring from above, at an angle (layout check: ring clear of the building and of decor)
for _, s in HubLayout.Stations do
	local at = c + s.At
	local inward = (Vector3.new(c.X, 0, c.Z) - Vector3.new(at.X, 0, at.Z)).Unit
	local ringAt = at + inward * (s.RingOffset or HubLayout.RingOffset)
	mark("ring " .. s.Id)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(ringAt + inward * 14 + Vector3.new(0, 22, 0), (at + ringAt) / 2)
	task.wait(1.4)
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

-- 4 the run
mark("run start")
ask("StartRun", "CursedForest")
await("RunReady", 60)
character = player.Character
task.wait(6)
mark("run map")
ask("Mana")
task.wait(0.5)
local spot = Config.SpawnPoint + Vector3.new(-4, 0, 6) -- (an open build spot beside the hero on the new path)
mark("place ranger")
local ok, reason = Remotes.PlaceTower:InvokeServer("Ranger", spot)
-- (something can stand on the first spot, a pet for one: try a few more beside it)
local tries = {}
for r = 6, 30, 6 do
	for k = 0, 7 do
		local a = math.rad(k * 45)
		table.insert(tries, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
end
for _, off in tries do
	if ok then
		break
	end
	spot = Config.SpawnPoint + off
	ok, reason = Remotes.PlaceTower:InvokeServer("Ranger", spot)
end
print("[FILM] place", ok, reason)
task.wait(2.5)
-- the archer in open daylight, close, from the front: his colours against the painting (no roof, no tower)
do
	local at = spot + Vector3.new(14, 0, -10)
	ask("OpenArcher", at)
	await("OpenArcherReady", 10)
	task.wait(1)
	local m = workspace:FindFirstChild("OpenArcher")
	if m then
		local cf, size = m:GetBoundingBox()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		local front = m:GetPivot().LookVector   -- (his front is the model's -Z)
		workspace.CurrentCamera.CFrame = CFrame.lookAt(cf.Position + front * size.Y * 1.6 + Vector3.new(0, size.Y * 0.15, 0), cf.Position + Vector3.new(0, size.Y * 0.1, 0))
		mark("archer open light")
		task.wait(1.5)
		m:Destroy()
		local dr = workspace:FindFirstChild("OpenDragon")
		if dr then
			local dcf, dsize = dr:GetBoundingBox()
			workspace.CurrentCamera.CFrame = CFrame.lookAt(dcf.Position + dr:GetPivot().LookVector * dsize.Y * 1.8 + Vector3.new(0, dsize.Y * 0.2, 0), dcf.Position)
			mark("dragon open light")
			task.wait(1.5)
			dr:Destroy()
		end
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end
local ranger
for _, t in workspace.Towers:GetChildren() do
	ranger = t
end
if ranger then
	-- the Ranger at each level, seen from the player's height at a short distance (the upgrade look pipeline)
	local base = ranger:GetPivot().Position
	local function closeUp(tag)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = CFrame.lookAt(base + Vector3.new(-14, 9, -20), base + Vector3.new(0, 7, 0))
		mark(tag)
	end
	-- the archer close-ups (2026-11-23): a camera per level at the archer's height, near enough to judge him
	local function archerShot(tag, feet)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = CFrame.lookAt(base + Vector3.new(-5, feet + 2.2, -7), base + Vector3.new(0, feet + 1.7, 0))
		mark(tag)
	end
	closeUp("ranger level 1")
	task.wait(1.6)
	archerShot("archer level 1", 4.4)
	task.wait(1.4)
	do   -- his face up close (2026-11-23: it read black in game; is it the paint, the light or the mesh?)
		local archer = ranger:FindFirstChild("Archer", true)
		local head = archer and archer:FindFirstChild("Head")
		if head then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = CFrame.lookAt(head.Position + head.CFrame.LookVector * 5 + Vector3.new(0, 0.6, 0), head.Position)
			mark("archer face")
			task.wait(1.2)
		end
	end
	Remotes.UpgradeTower:InvokeServer(ranger)
	mark("upgrade ranger")
	task.wait(1.6)
	closeUp("ranger level 2")
	task.wait(1.2)
	archerShot("archer level 2", 6.5)
	task.wait(1.4)
	Remotes.UpgradeTower:InvokeServer(ranger)
	task.wait(1.6)
	closeUp("ranger level 3")
	task.wait(1.6)
	archerShot("archer level 3", 10.8)
	task.wait(1.4)
	-- the archer from four sides on the level 3 tower (2026-11-23 painterly pass): front, his left, back, his right,
	-- from outside the tower with a long lens; the way he faces is read from his head (he turns while he aims)
	local function archerSides()
		local archer = ranger:FindFirstChild("Archer", true)
		local head = archer and archer:FindFirstChild("Head")
		if not head then
			return
		end
		local _, size = archer:GetBoundingBox()
		local centre = head.Position - Vector3.new(0, size.Y * 0.25, 0)
		local fov = workspace.CurrentCamera.FieldOfView
		workspace.CurrentCamera.FieldOfView = 16
		for i, side in { "front", "left", "back", "right" } do
			local dir = (head.CFrame * CFrame.Angles(0, math.rad(({ 0, 90, 180, 270 })[i]), 0)).LookVector
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = CFrame.lookAt(centre + dir * 16 + Vector3.new(0, size.Y * 0.6, 0), centre)
			mark("archer " .. side)
			task.wait(1.2)
		end
		workspace.CurrentCamera.FieldOfView = fov
	end
	archerSides()
	-- a test (coordinator 2026-11-23, the front-right view hid him): from the run camera (20.5 studs, 42 degrees down)
	-- at 8 directions round the level 3 tower, at least one archer's head is at least half visible in 7 of 8
	do
		local heads = {}
		local here = ranger:GetPivot().Position
		for _, d in workspace:GetDescendants() do   -- (the level 3 look is a new model: search near the tower)
			if d:IsA("BasePart") and d.Name == "Head" and d.Parent and d.Parent.Name == "Archer" and (d.Position - here).Magnitude < 15 then
				table.insert(heads, d)
			end
		end
		mark("archer heads found " .. #heads)
		local focus = ranger:GetPivot().Position + Vector3.new(0, 4, 0)
		local passed, detail = 0, {}
		for k = 0, 7 do
			local a = math.rad(k * 45)
			local look = Vector3.new(math.sin(a), 0, math.cos(a))
			local eye = focus - look * 20.5 * math.cos(math.rad(42)) + Vector3.new(0, 20.5 * math.sin(math.rad(42)), 0)
			local best = 0
			for _, h in heads do
				local seen, total = 0, 0
				for _, off in { Vector3.new(0, 0, 0), Vector3.new(0.35, 0, 0), Vector3.new(-0.35, 0, 0), Vector3.new(0, 0.35, 0),
					Vector3.new(0, -0.3, 0), Vector3.new(0.25, 0.25, 0), Vector3.new(-0.25, 0.25, 0), Vector3.new(0.25, -0.2, 0),
					Vector3.new(-0.25, -0.2, 0) } do
					-- points on the head's side that faces the camera
					local toward = (eye - h.Position) * Vector3.new(1, 0, 1)
					toward = toward.Magnitude > 0 and toward.Unit or Vector3.new(0, 0, 1)
					local right = Vector3.new(0, 1, 0):Cross(toward).Unit
					local pt = h.Position + right * off.X * h.Size.X + Vector3.new(0, off.Y * h.Size.Y, 0) + toward * h.Size.Z * 0.3
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { player.Character }
					local hit = workspace:Raycast(eye, (pt - eye) * 1.02, params)
					local skip = { player.Character }
					for _ = 1, 6 do   -- see-through parts (a tower's tap box) do not hide him
						if not (hit and hit.Instance.Transparency >= 0.9) then
							break
						end
						table.insert(skip, hit.Instance)
						params.FilterDescendantsInstances = skip
						hit = workspace:Raycast(eye, (pt - eye) * 1.02, params)
					end
					total += 1
					if k == 0 and total == 1 then
						print(string.format("[FILM] ray debug: head at %s size %s, point dist %.1f, hit %s at %.1f", tostring(h.Position), tostring(h.Size),
							(pt - eye).Magnitude, hit and hit.Instance:GetFullName() or "nothing", hit and (hit.Position - eye).Magnitude or -1))
					end
					-- (the archer's parts are not hit by rays: seen = nothing in the way before the point)
					if not hit or hit.Instance == h or (hit.Position - eye).Magnitude >= (pt - eye).Magnitude - 0.2 then
						seen += 1
					end
				end
				best = math.max(best, seen / total)
			end
			if best >= 0.5 then
				passed += 1
			end
			table.insert(detail, string.format("%d:%.0f%%", k * 45, best * 100))
		end
		mark(string.format("archer visible %d of 8 (%s) %s", passed, table.concat(detail, " "), passed >= 7 and "PASS" or "FAIL"))
		-- round C (coordinator: "the game is the truth for the visibility test"): what the camera really draws. The
		-- rays above meet the tower's collision shape, which is not what you see. Here each archer's head gets a flat
		-- colour (magenta, cyan) drawn only where it is seen (Highlight, Occluded), then drawn whole (AlwaysOnTop);
		-- scripts/film_probe.py counts both in the clip: a head is seen when at least half of it shows.
		local colours = { Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255) }
		local lights = {}
		for i, h in heads do
			local hl = Instance.new("Highlight")
			hl.Adornee = h
			hl.FillColor = colours[i] or Color3.new(1, 1, 0)
			hl.FillTransparency = 0
			hl.OutlineTransparency = 1
			hl.Enabled = false
			hl.Parent = h
			table.insert(lights, hl)
		end
		-- (the HUD is hidden while it measures: it covered the gallery; and the camera is put back every frame, as the
		-- run camera takes over when a wave starts)
		local hidden = {}
		for _, g in player:WaitForChild("PlayerGui"):GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		local probeCam = CFrame.new()
		game:GetService("RunService"):BindToRenderStep("FilmProbe", Enum.RenderPriority.Last.Value + 10, function()
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = probeCam
		end)
		-- round C decision: as in play. The hero stands 15, 25 or 40 studs from the tower's foot; the run camera
		-- (RunCamera: 20.5 studs, 42 degrees down, looking at the hero's middle) is behind him, the tower beyond.
		-- (the hero is not moved: the camera alone is placed, so he does not stand in the way)
		local foot = ranger:GetPivot().Position
		for _, dist in { 15, 25, 40 } do
			for k = 0, 7 do
				local a = math.rad(k * 45)
				local look = Vector3.new(math.sin(a), 0, math.cos(a))
				local hero = foot - look * dist + Vector3.new(0, 3, 0)
				local rc = Config.RunCamera
				local aim = hero + Vector3.new(0, rc.AimHeight, 0)
				local eye = aim - look * rc.Distance * math.cos(math.rad(rc.Pitch)) + Vector3.new(0, rc.Distance * math.sin(math.rad(rc.Pitch)), 0)
				probeCam = CFrame.lookAt(eye, aim)
				for _, mode in { "Occluded", "AlwaysOnTop" } do
					for _, hl in lights do
						hl.DepthMode = Enum.HighlightDepthMode[mode]
						hl.Enabled = true
					end
					task.wait(0.8)   -- (0.4 s caught frames from before the camera or the highlight changed)
					mark(string.format("probe %d %d %s", dist, k * 45, mode))
					task.wait(0.5)
				end
			end
		end
		for _, hl in lights do
			hl:Destroy()
		end
		game:GetService("RunService"):UnbindFromRenderStep("FilmProbe")
		for _, g in hidden do
			g.Enabled = true
		end
	end
	-- the archers at work (2026-11-23): a wave starts while the level 3 Ranger stands, the camera stays on it
	Remotes.StartWave:FireServer()
	mark("ranger shooting")
	-- (the run camera takes over at a wave start: hold this shot after it, every frame)
	local held = CFrame.lookAt(base + Vector3.new(-10, 13.5, 2), base + Vector3.new(0, 12.2, -1))   -- from the side: the draw shows
	game:GetService("RunService"):BindToRenderStep("FilmHold", Enum.RenderPriority.Last.Value + 5, function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = held
	end)
	-- a test, not only a picture (2026-11-23: the archers once never moved and nothing said so): an archer's bow arm
	-- must move during the wave
	local arm, start, moved = nil, nil, 0
	for _, d in workspace:GetDescendants() do
		if d.Name == "ArmL" and d.Parent and d.Parent.Name == "Archer" then
			arm = d
			break
		end
	end
	start = arm and arm.Position
	for _ = 1, 100 do
		task.wait(0.2)
		if arm and arm.Parent then
			moved = math.max(moved, (arm.Position - start).Magnitude)
		end
	end
	mark(string.format("archer arm moved %.2f studs %s", moved, moved > 0.2 and "PASS" or "FAIL"))
	game:GetService("RunService"):UnbindFromRenderStep("FilmHold")
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	mark("sell ranger")
	Remotes.SellTower:InvokeServer(ranger)
	task.wait(2)
end
-- (2026-11-24, research brief as numbers): each level from the run camera's start, as a player sees it on the phone:
-- a picture, then the tower alone in a flat colour (Highlight, AlwaysOnTop) for its outline, with the HUD hidden;
-- at level 3 also at Roblox's lowest graphics level ("low effects"), when a LocalScript may set it
local function runViewShots(kind, level, tower, base)
	local rc = Config.RunCamera
	local look = Vector3.new(0.6, 0, 0.8).Unit
	local aim = base + Vector3.new(0, rc.AimHeight, 0)
	local eye = aim - look * rc.Distance * math.cos(math.rad(rc.Pitch)) + Vector3.new(0, rc.Distance * math.sin(math.rad(rc.Pitch)), 0)
	local cf = CFrame.lookAt(eye, aim)
	local hidden = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	game:GetService("RunService"):BindToRenderStep("FilmTowerView", Enum.RenderPriority.Last.Value + 5, function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = cf
	end)
	task.wait(0.6)
	mark(string.format("view %s %d", kind, level))
	task.wait(0.5)
	local hl = Instance.new("Highlight")
	hl.Adornee = tower:FindFirstChild("Look") or tower
	hl.FillColor = Color3.fromRGB(255, 0, 255)
	hl.FillTransparency = 0
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = tower
	task.wait(0.6)
	mark(string.format("mask %s %d", kind, level))
	task.wait(0.5)
	hl:Destroy()
	if level == 3 then
		local ok, err = pcall(function()
			UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
		end)
		-- (a LocalScript may not set the graphics level, Roblox says "lacking capability RobloxScript": what level 1
		-- turns off is turned off here by hand, on this client only: shadows, bloom, sun rays, colour grading,
		-- depth of field and the atmosphere's haze; materials and the draw distance cannot be changed)
		local Lighting = game:GetService("Lighting")
		local undo = { shadows = Lighting.GlobalShadows }
		Lighting.GlobalShadows = false
		for _, e in Lighting:GetChildren() do
			if e:IsA("PostEffect") and e.Enabled then
				e.Enabled = false
				table.insert(undo, e)
			end
		end
		task.wait(1.2)
		mark(string.format("low %s %s", kind, ok and "set" or "approximated (shadows and post effects off)"))
		task.wait(0.5)
		Lighting.GlobalShadows = undo.shadows
		for _, e in ipairs(undo) do
			e.Enabled = true
		end
		pcall(function()
			UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.Automatic
		end)
	end
	game:GetService("RunService"):UnbindFromRenderStep("FilmTowerView")
	for _, g in hidden do
		g.Enabled = true
	end
end
-- every other defender at its three levels (2026-11-23: the kit-built level looks), a close camera on each
ask("Own")
for _, kind in { "FlameCannon", "FrostCrystal", "StormObelisk", "Ballista" } do
	ask("Mana")
	task.wait(0.4)
	-- (2026-11-24, research brief: "towers must be visible while art loads"): from the tap to something tower-shaped
	-- and tower-coloured on screen. Measured every frame on this client: when the tower's model arrives, when its
	-- first part is drawn (a part with a size), and when every mesh and texture of its look has been fetched
	local tTap = os.clock()
	local tModel, tPart, tMeshes, tStand, tSwap = nil, nil, nil, nil, nil
	local ContentProvider = game:GetService("ContentProvider")
	local watch = game:GetService("RunService").RenderStepped:Connect(function()
		local now = os.clock() - tTap
		local t
		for _, m in workspace.Towers:GetChildren() do
			if m:GetAttribute("TowerType") == kind or m.Name == kind then
				t = m
			end
		end
		if not t then
			return
		end
		tModel = tModel or now
		local look = t:FindFirstChild("Look")
		local any, all = false, look ~= nil
		for _, d in (look or t):GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				any = true
			end
			if d:IsA("MeshPart") then
				local ok1 = ContentProvider:GetAssetFetchStatus(d.MeshId) == Enum.AssetFetchStatus.Success
				local ok2 = d.TextureID == "" or ContentProvider:GetAssetFetchStatus(d.TextureID) == Enum.AssetFetchStatus.Success
				all = all and ok1 and ok2
			end
		end
		if any then
			tPart = tPart or now
		end
		if all and any then
			tMeshes = tMeshes or now
		end
		local si = t:FindFirstChild("StandIn")
		if si and si:FindFirstChild("Body") and si.Body.LocalTransparencyModifier < 1 then
			tStand = tStand or now   -- (the stand-in is drawn)
		end
		if si and si:GetAttribute("Hidden") then
			tSwap = tSwap or now     -- (and swapped for the real look)
		end
	end)
	local okPlace = Remotes.PlaceTower:InvokeServer(kind, spot)
	task.wait(2.2)
	watch:Disconnect()
	mark(string.format("load %s: model %.2f s, first part drawn %.2f s, every mesh and texture %s, stand-in drawn %s, swapped %s after the tap", kind,
		tModel or -1, tPart or -1, tMeshes and string.format("%.2f s", tMeshes) or "not within 2.2 s",
		tStand and string.format("%.2f s", tStand) or "never", tSwap and string.format("%.2f s", tSwap) or "not within 2.2 s"))
	local tower
	for _, t in workspace.Towers:GetChildren() do
		if t:GetAttribute("TowerType") == kind or t.Name == kind then
			tower = t
		end
	end
	print("[FILM] place", kind, okPlace, tower ~= nil)
	if tower then
		local base = tower:GetPivot().Position
		for level = 1, 3 do
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = CFrame.lookAt(base + Vector3.new(-8, 6.5, -11), base + Vector3.new(0, 3.5, 0))
			mark(kind .. " level " .. level)
			task.wait(1.6)
			runViewShots(kind, level, tower, base)
			if level < 3 then
				Remotes.UpgradeTower:InvokeServer(tower)
				task.wait(1.0)
			end
		end
		Remotes.SellTower:InvokeServer(tower)
		task.wait(1.2)
	end
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
ask("Defenders")
await("DefendersReady", 10)
-- the starting view (coordinator 2026-11-24: three run-camera starts are filmed, Config.RunCamera): what is on the
-- phone screen at a wave's start and in the middle of it
local function cameraReport(tag)
	local cam = workspace.CurrentCamera
	local vs = cam.ViewportSize
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local function onScreen(pos)
		local p, vis = cam:WorldToViewportPoint(pos)
		return vis and p.Z > 0 and p.X >= 0 and p.X <= vs.X and p.Y >= 0 and p.Y <= vs.Y, p
	end
	-- 1. towers within 40 studs: their top (roof tip or highest archer) on screen
	local near, topsSeen = 0, 0
	for _, t in workspace.Towers:GetChildren() do
		local cf, size = t:GetBoundingBox()
		if ((cf.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= 40 then
			near += 1
			if onScreen(cf.Position + Vector3.new(0, size.Y / 2, 0)) then
				topsSeen += 1
			end
		end
	end
	-- 2. the wave's centre and the lane ahead (path points within 40 studs) on screen
	local sum, n = Vector3.zero, 0
	for _, m in (workspace:FindFirstChild("Enemies") or workspace):GetChildren() do
		if m:IsA("Model") and m:FindFirstChild("Look") then
			sum += m:GetPivot().Position
			n += 1
		end
	end
	local waveOn = n > 0 and onScreen(sum / n) or false
	local lane, laneSeen = 0, 0
	for _, pt in Config.Path do
		local w = Vector3.new(pt.X, root.Position.Y - 3, pt.Z)
		if (w - root.Position).Magnitude <= 40 then
			lane += 1
			laneSeen += onScreen(w) and 1 or 0
		end
	end
	-- 3. the hero's height on screen, and whether a HUD element covers him
	local hcf, hsize = char:GetBoundingBox()
	local _, top = onScreen(hcf.Position + Vector3.new(0, hsize.Y / 2, 0))
	local _, bottom = onScreen(hcf.Position - Vector3.new(0, hsize.Y / 2, 0))
	local heroShare = math.abs(top.Y - bottom.Y) / vs.Y
	local covered = 0
	local gui = player:WaitForChild("PlayerGui")
	for _, frac in { 0.1, 0.5, 0.9 } do
		local p = top:Lerp(bottom, frac)
		for _, g in gui:GetGuiObjectsAtPosition(p.X, p.Y) do
			if g.Visible and ((g:IsA("ImageLabel") or g:IsA("ImageButton")) and g.ImageTransparency < 0.9 or g.BackgroundTransparency < 0.9) then
				covered += 1
				break
			end
		end
	end
	-- 4. ground, world above ground, sky (a 16 x 9 grid of rays)
	local ground, world, sky = 0, 0, 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	for i = 0, 15 do
		for j = 0, 8 do
			local ray = cam:ViewportPointToRay((i + 0.5) / 16 * vs.X, (j + 0.5) / 9 * vs.Y)
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
			if not hit then
				sky += 1
			elseif hit.Normal.Y > 0.7 and hit.Position.Y < root.Position.Y + 1 then
				ground += 1
			else
				world += 1
			end
		end
	end
	mark(string.format("camera %s: tower tops %d of %d, wave centre %s, lane %d of %d, hero %.1f%% (HUD over him %d of 3), ground %.0f%% world %.0f%% sky %.0f%%",
		tag, topsSeen, near, n > 0 and (waveOn and "on" or "off") or "none", laneSeen, lane, heroShare * 100, covered,
		ground / 1.44, world / 1.44, sky / 1.44))
end
-- (the film's own close shots leave the camera low and near: for the measure the run camera's start is put back as
-- RunCamera.client.luau sets it, behind the hero facing the wave, and held while it is measured)
local function runView(tag, rc)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sum, n = Vector3.zero, 0
	for _, m in (workspace:FindFirstChild("Enemies") or workspace):GetChildren() do
		if m:IsA("Model") then
			sum += m:GetPivot().Position
			n += 1
		end
	end
	local toward = n > 0 and sum / n or Vector3.new(Config.Path[1].X, root.Position.Y, Config.Path[1].Z)
	local look = ((toward - root.Position) * Vector3.new(1, 0, 1))
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	rc = rc or Config.RunCamera
	local aim = root.Position + Vector3.new(0, rc.AimHeight, 0)
	local eye = aim - look * rc.Distance * math.cos(math.rad(rc.Pitch)) + Vector3.new(0, rc.Distance * math.sin(math.rad(rc.Pitch)), 0)
	local cf = CFrame.lookAt(eye, aim)
	game:GetService("RunService"):BindToRenderStep("FilmRunView", Enum.RenderPriority.Last.Value + 5, function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = cf
	end)
	task.wait(0.8)
	cameraReport(tag)
	task.wait(1.2)
	game:GetService("RunService"):UnbindFromRenderStep("FilmRunView")
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end
mark("wave")
Remotes.StartWave:FireServer()
-- (the three starting views from the camera trial, at the same moment and spot, one after the other)
local VIEWS = { { "42 deg", { Pitch = 42, Distance = 20.5, AimHeight = 0 } }, { "32 deg", { Pitch = 32, Distance = 20.5, AimHeight = 0 } },
	{ "32 deg aim 3", { Pitch = 32, Distance = 20.5, AimHeight = 3 } } }
task.delay(2.5, function()
	for _, v in VIEWS do
		runView(v[1] .. " wave start", v[2])
	end
end)
task.delay(12, function()
	for _, v in VIEWS do
		runView(v[1] .. " mid wave", v[2])
	end
	-- the player's own control after the run camera's start (2026-11-24: the right stick must still tilt and turn
	-- it): the camera is the follow camera on the hero, with the zoom range open
	local cam = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	mark(string.format("camera control: type %s, subject %s, zoom %.1f-%.1f, offset %s", tostring(cam.CameraType),
		cam.CameraSubject and cam.CameraSubject.ClassName or "none", player.CameraMinZoomDistance, player.CameraMaxZoomDistance,
		hum and tostring(hum.CameraOffset) or "?"))
end)
-- framing measured while the wave runs, with the player's own camera (rule, 2026-11-22: the hero is 12-15% of the
-- screen height, a monster is on screen for at least 80% of the wave, and a monster is at least 6% tall)
local samples, withMonster, heroSum, heroN, monsterMax = 0, 0, 0, 0, 0
local function screenHeight(cf, size)
	local cam = workspace.CurrentCamera
	local top = cam:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y / 2, 0))
	local bottom = cam:WorldToViewportPoint(cf.Position - Vector3.new(0, size.Y / 2, 0))
	return math.abs(top.Y - bottom.Y) / cam.ViewportSize.Y
end
local waveStart = os.clock()
while os.clock() - waveStart < 22 do
	task.wait(0.5)
	local cam = workspace.CurrentCamera
	local char = player.Character
	if char then
		local cf, size = char:GetBoundingBox()
		heroSum += screenHeight(cf, size)
		heroN += 1
	end
	if (workspace:GetAttribute("WaveRunning") ~= false) then
		local seen = false
		for _, m in (workspace:FindFirstChild("Enemies") or workspace):GetChildren() do
			if m:IsA("Model") and m:FindFirstChild("Look") then
				local cf, size = m.Look:GetBoundingBox()
				local p, onScreen = cam:WorldToViewportPoint(cf.Position)
				if onScreen and p.Z > 0 then
					seen = true
					monsterMax = math.max(monsterMax, screenHeight(cf, size))
				end
			end
		end
		if #((workspace:FindFirstChild("Enemies") or workspace):GetChildren()) > 0 then
			samples += 1
			withMonster += seen and 1 or 0
		end
	end
end
print(string.format("[FILM] framing: hero %.1f%% of screen height, monster on screen %d of %d samples (%.0f%%), biggest monster %.1f%%",
	heroSum / math.max(1, heroN) * 100, withMonster, samples, withMonster / math.max(1, samples) * 100, monsterMax * 100))

-- 6 ground close-ups: low cameras at towers' feet and along the path (where sinking shows)
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
for i, t in workspace.Towers:GetChildren() do
	if i > 4 then
		break
	end
	local base = t:GetPivot().Position
	mark("tower feet " .. t.Name)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(base + Vector3.new(9, 2.2, 9), base + Vector3.new(0, 1.2, 0))
	task.wait(2.5)
end
local pts = Config.Path
for i = 2, math.min(#pts, 5) do
	mark("path ground " .. i)
	local p = pts[i]
	workspace.CurrentCamera.CFrame = CFrame.lookAt(p + Vector3.new(12, 2.5, 10), p + Vector3.new(0, 1, 0))
	task.wait(4)
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
mark("film end")
task.wait(1)
ask("Done")
