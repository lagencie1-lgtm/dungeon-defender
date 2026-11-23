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
print("[FILM] place", ok, reason)
task.wait(2.5)
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
	-- the rebuilt archer from four sides (2026-11-23, Lemp: "ripped apart face ... cut head ... missing piece on
	-- the hoody"): front, his left, back, his right, close, at his own height
	local archer = ranger:FindFirstChild("Archer", true)
	if archer then
		local pivot = archer:GetPivot()
		local _, size = archer:GetBoundingBox()
		local centre = pivot.Position + Vector3.new(0, size.Y * 0.15, 0)
		local fov = workspace.CurrentCamera.FieldOfView
		workspace.CurrentCamera.FieldOfView = 16
		for i, side in { "front", "left", "back", "right" } do
			local dir = (pivot * CFrame.Angles(0, math.rad(({ 0, 90, 165, 245 })[i]), 0)).LookVector   -- (corner posts hide the exact back and right)
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = CFrame.lookAt(centre + dir * 14 + Vector3.new(0, size.Y * 0.25, 0), centre)   -- (from outside the tower, a long lens)
			mark("archer " .. side)
			task.wait(1.2)
		end
		workspace.CurrentCamera.FieldOfView = fov
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
-- every other defender at its three levels (2026-11-23: the kit-built level looks), a close camera on each
ask("Own")
for _, kind in { "FlameCannon", "FrostCrystal", "StormObelisk", "Ballista" } do
	ask("Mana")
	task.wait(0.4)
	local okPlace = Remotes.PlaceTower:InvokeServer(kind, spot)
	task.wait(2.2)
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
mark("wave")
Remotes.StartWave:FireServer()
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
