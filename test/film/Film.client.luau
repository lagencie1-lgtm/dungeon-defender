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
	closeUp("ranger level 1")
	task.wait(1.6)
	Remotes.UpgradeTower:InvokeServer(ranger)
	mark("upgrade ranger")
	task.wait(1.6)
	closeUp("ranger level 2")
	task.wait(1.2)
	Remotes.UpgradeTower:InvokeServer(ranger)
	task.wait(1.6)
	closeUp("ranger level 3")
	task.wait(1.6)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	mark("sell ranger")
	Remotes.SellTower:InvokeServer(ranger)
	task.wait(2)
end
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
