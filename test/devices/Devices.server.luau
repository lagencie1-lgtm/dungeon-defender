-- Only in the device pass builds: walks one player through the same route as Rule 1 of CLAUDE.md (the Outpost,
-- the big screens, a run with a Ranger, the Ranger's upgrade panel). At each step the client measures and the
-- runner takes a screenshot. Ends the play test with the number of problems.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local State = require(Server.State)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local probe = ReplicatedStorage.DeviceTest

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local function waitFor(predicate, limit, what)
	local deadline = os.clock() + limit
	repeat
		if predicate() then
			return true
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("timed out waiting for " .. what)
end

local answered = {}
probe.OnServerEvent:Connect(function(sender, step, count)
	if sender == player then
		answered[step] = count
	end
end)

local total, steps = 0, 0
local function step(name)
	probe:SetAttribute("Step", name)
	local ok = pcall(waitFor, function() return answered[name] ~= nil end, 60, name)
	steps += 1
	if not ok or answered[name] < 0 then
		print("[DEVICES] step", name, "FAILED")
		total += 1
	else
		total += answered[name]
	end
end

local ok, err = pcall(function()
	waitFor(function() return State.Get("State") == "Lobby" and player.Character ~= nil end, 90, "the Outpost")
	task.wait(6) -- screens built, pictures loaded
	step("Outpost")
	for _, panel in { "Shop", "Pets", "Backpack" } do
		step("Clear-" .. panel) -- the screen before closes first (one panel at a time, as a player sees it)
		Remotes.OpenPanel:FireClient(player, panel)
		step(panel)
	end
	State.Set("Map", "CursedForest")
	GameService.StartRun()
	waitFor(function() return State.Get("State") == "Break" end, 60, "the run")
	task.wait(2)
	State.Set("Gold", 5000)
	-- a Ranger on the first building spot, the hero 11 studs from it on its own side (Y picks the nearest defender)
	-- the map's own first building spot (the one the tutorial points at), else rings round the hero
	local spot = require(ReplicatedStorage.Shared.MapOutline).Start.Forest.FirstSpot
	local rootPart = player.Character:WaitForChild("HumanoidRootPart")
	local y = rootPart.Position.Y
	-- (rings of spots round the spawn, nearest first: some maps have rocks or the path right next to it)
	local placedAt, why
	for _, distance in { 0, 6, 10, 14 } do
		for i = 0, (distance == 0 and 0 or 7) do
			local angle = i * math.pi / 4
			local at = spot + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local ok, message = TowerService.Place(player, "Ranger", at)
			if ok then
				placedAt = at
				break
			end
			why = message
		end
		if placedAt then
			break
		end
	end
	assert(placedAt, "could not build a Ranger near the spawn: " .. tostring(why))
	local flat = Vector3.new(rootPart.Position.X - placedAt.X, 0, rootPart.Position.Z - placedAt.Z)
	local away = flat.Magnitude > 0.5 and flat.Unit or Vector3.xAxis
	local stand = Vector3.new(placedAt.X, y, placedAt.Z) + away * 11
	rootPart.CFrame = CFrame.lookAt(stand, Vector3.new(placedAt.X, y, placedAt.Z))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(6) -- (on phones the next-goal chip shows for 5 s when a run starts, then leaves the road clear)
	step("Run")
	step("Defender")
end)
if not ok then
	total += 1
	print("[DEVICES] server FAILED:", err)
end
print(string.format("[DEVICES] DONE %s %d steps, %d problems", tostring(probe:GetAttribute("Device")), steps, total))
pcall(function()
	game:GetService("StudioTestService"):EndTest("done")
end)
