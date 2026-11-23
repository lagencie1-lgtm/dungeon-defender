-- Film rig client for pets and Might: the same route every take, from the real player camera.
--  1 the pet team at the hero's side, 2 a wave: the lead pet's move, 3 loot on the ground: the pets fetch it,
--  4 a Mythic-rank hero (glow, sparks, ring, halo, size), 5 a Might style, 6 the pets screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
character:WaitForChild("HumanoidRootPart")
workspace:WaitForChild("Outpost")
task.wait(12) -- art streams in; ffmpeg starts on the "film start" mark
ask("Setup")
await("SetupReady", 20)
ask("StartRun", "CursedForest")
await("RunReady", 60)
task.wait(3)
ask("Stand")
await("StandReady", 20)
task.wait(2)
mark("film start")

-- 0 the two crowned bosses up close (their faces: the old floating crown bars sat across the eyes)
ask("Bosses")
await("BossesReady", 60)
task.wait(1)
do
	local camera = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("FilmBosses")
	camera.CameraType = Enum.CameraType.Scriptable
	for _, boss in folder and folder:GetChildren() or {} do
		local box, size = boss:GetBoundingBox()
		local face = box.Position + Vector3.new(0, size.Y * 0.22, 0)
		local front = boss:GetPivot().LookVector
		camera.CFrame = CFrame.lookAt(face + front * size.Y * 0.9 + Vector3.new(0, 1, 0), face)
		mark("boss face")
		task.wait(3)
	end
	camera.CameraType = Enum.CameraType.Custom
	ask("BossesGone")
	task.wait(1)
end

-- 1 the team: stand, then a short walk so the pets hop along
mark("team stand")
task.wait(3)
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or humanoid
if root then
	local home = root.Position
	mark("team walk")
	humanoid:MoveTo(home + root.CFrame.RightVector * 10)
	task.wait(2.2)
	humanoid:MoveTo(home)
	task.wait(2.6)
end

-- 2 a wave passes: the lead pet pounces
mark("wave")
Remotes.StartWave:FireServer()
task.wait(16)

-- 3 loot on the ground: the pets fetch it
mark("loot")
ask("Loot")
task.wait(9)

-- 4 a Mythic-rank hero: first from the battle camera, then close from the front (before and after)
local function closeUp(seconds)
	local camera = workspace.CurrentCamera
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local at = r.Position + Vector3.new(0, 1.2, 0)
	camera.CFrame = CFrame.lookAt(at + r.CFrame.LookVector * 11 + r.CFrame.RightVector * 3 + Vector3.new(0, 2.5, 0), at)
	task.wait(seconds)
	camera.CameraType = Enum.CameraType.Custom
end
mark("hero plain close")
closeUp(2.5)
mark("might")
ask("Might", 6)
task.wait(3)
mark("might close")
closeUp(3.5)

-- 5 a Might style
mark("style")
ask("Style", "AuraVoid")
task.wait(2)
mark("style close")
closeUp(3)

-- 6 the pets screen
mark("panel")
ask("Panel", "Pets")
task.wait(5)
mark("film end")
task.wait(1)
ask("Done")
