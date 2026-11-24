-- Film rig client for the research batch: plays it like a player would, from the player camera.
--  1 the first wave: the Ranger shoots the slow goblins, the Sneak slips past, the hero runs to the ring and catches it
--  2 the Goblin King's charge at the Ranger: the tell, then three hits break it (the second charge is left to land)
--  3 the Outpost: the King's Cleaver on the training knight
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
local function hero()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end
-- run to a point, at most `limit` seconds
local function runTo(target, limit)
	local humanoid, root = hero()
	if not humanoid then
		return
	end
	humanoid:MoveTo(target)
	local deadline = os.clock() + (limit or 4)
	while os.clock() < deadline and (root.Position * Vector3.new(1, 0, 1) - target * Vector3.new(1, 0, 1)).Magnitude > 3 do
		task.wait(0.1)
		humanoid:MoveTo(target)
	end
end
-- face something and swing (the F attack, as the Sword button does)
local function swingAt(position, times)
	for _ = 1, times do
		local humanoid, root = hero()
		if root then
			local flat = Vector3.new(position.X, root.Position.Y, position.Z)
			root.CFrame = CFrame.lookAt(root.Position, flat)
			if (flat - root.Position).Magnitude > 7 then
				humanoid:MoveTo(position)
			end
		end
		Remotes.HeroAttack:FireServer()
		task.wait(0.55)
	end
end
local function enemyNamed(name)
	local folder = workspace:FindFirstChild("Enemies")
	for _, m in folder and folder:GetChildren() or {} do
		if m:IsA("Model") and string.find(m.Name, name) then
			return m
		end
	end
	return nil
end

player.CharacterAdded:Wait()
workspace:WaitForChild("Outpost")
task.wait(12) -- art streams in
ask("Setup")
await("SetupReady", 20)
ask("StartRun")
await("RunReady", 60)
task.wait(2)
mark("film start")

-- 1 the first wave
mark("wave 1")
Remotes.StartWave:FireServer()
local deadline = os.clock() + 50
local rescued = false
while os.clock() < deadline do
	local at = player:GetAttribute("RescueAt")
	if typeof(at) == "Vector3" then
		mark("ring shown")
		runTo(at, 6)
		mark("at the ring")
		-- wait for the Sneak to come close, then catch it
		local until_ = os.clock() + 10
		while os.clock() < until_ do
			local sneak = nil
			for _, m in workspace:WaitForChild("Enemies"):GetChildren() do
				if m:FindFirstChild("RescueMark", true) then
					sneak = m
				end
			end
			if not sneak then
				rescued = true
				break
			end
			local _, root = hero()
			local p = sneak:GetPivot().Position
			if root and (p - root.Position).Magnitude < 16 then
				swingAt(p, 1)
			else
				task.wait(0.1)
			end
		end
		break
	end
	task.wait(0.2)
end
mark(rescued and "sneak caught" or "sneak not caught")
task.wait(3)

-- 2 the King's charge (the hero walks back to the keep hill's Ranger first)
do
	local folder = workspace:FindFirstChild("Towers")
	local ranger = folder and folder:GetChildren()[1]
	if ranger then
		runTo(ranger:GetPivot().Position + Vector3.new(8, 0, 8), 8)
	end
end
ask("Boss")
await("BossReady", 10)
mark("boss")
local tower = nil
local tellDeadline = os.clock() + 25
while os.clock() < tellDeadline and not tower do
	for _, t in workspace.Towers:GetChildren() do
		if t:FindFirstChild("ChargeTarget") then
			tower = t
		end
	end
	task.wait(0.1)
end
if tower then
	mark("charge tell")
	task.wait(1.2) -- the tell, seen from the player camera
	local kingModel = enemyNamed("GoblinKing") or enemyNamed("Goblin King")
	local _, root = hero()
	if kingModel and root then
		local p = kingModel:GetPivot().Position
		runTo(p + (root.Position - p).Unit * 8, 3)
		mark("break the charge")
		swingAt(p, 4)
	end
	task.wait(2.5)
	-- the next charge is left alone: it lands on the defender
	mark("second charge left alone")
	local wait2 = os.clock() + 20
	while os.clock() < wait2 do
		local any = false
		for _, t in workspace.Towers:GetChildren() do
			any = any or t:FindFirstChild("ChargeTarget") ~= nil
		end
		if any then
			mark("second tell")
			task.wait(5.5)
			break
		end
		task.wait(0.2)
	end
else
	mark("no charge tell seen")
end
mark("jam")
task.wait(3)

-- 3 the Outpost: the cleaver on the training knight
ask("BossGone")
await("OutpostReady", 30)
task.wait(2)
mark("outpost")
local knight = nil
for _ = 1, 50 do
	knight = enemyNamed("TrainingKnight") or enemyNamed("Training Knight")
	if knight then
		break
	end
	task.wait(0.2)
end
if knight then
	local p = knight:GetPivot().Position
	-- through the plaza (not past the station rings, which open their screens)
	local centre = require(ReplicatedStorage.Shared.Config).OutpostCenter
	runTo(Vector3.new(centre.X - 6, p.Y, p.Z + 2), 8)
	runTo(p + Vector3.new(7, 0, 0), 4)
	mark("knight")
	swingAt(p, 5)
end
task.wait(2)
mark("film end")
task.wait(1)
ask("Done")
