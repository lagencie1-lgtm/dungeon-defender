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
walk(c + Vector3.new(0, 0, -18), 7)
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

-- 4 the run
mark("run start")
ask("StartRun", "CursedForest")
await("RunReady", 60)
character = player.Character
task.wait(6)
mark("run map")
ask("Mana")
task.wait(0.5)
local spot = Config.SpawnPoint + Vector3.new(14, 0, 4)
mark("place ranger")
local ok, reason = Remotes.PlaceTower:InvokeServer("Ranger", spot)
print("[FILM] place", ok, reason)
task.wait(2.5)
local ranger
for _, t in workspace.Towers:GetChildren() do
	ranger = t
end
if ranger then
	mark("upgrade ranger")
	Remotes.UpgradeTower:InvokeServer(ranger)
	task.wait(2)
	mark("sell ranger")
	Remotes.SellTower:InvokeServer(ranger)
	task.wait(2)
end
ask("Defenders")
await("DefendersReady", 10)
mark("wave")
Remotes.StartWave:FireServer()
task.wait(22)

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
