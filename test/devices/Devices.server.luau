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
		Remotes.OpenPanel:FireClient(player, panel)
		step(panel)
	end
	State.Set("Map", "CursedForest")
	GameService.StartRun()
	waitFor(function() return State.Get("State") == "Break" end, 60, "the run")
	task.wait(2)
	State.Set("Gold", 5000)
	-- a Ranger 7 studs east of the hero's spot, the hero beside it (the Y button picks the nearest defender)
	local spot = Config.Maps.CursedForest.SpawnPoint
	local rootPart = player.Character:WaitForChild("HumanoidRootPart")
	local y = rootPart.Position.Y
	local placed = false
	for _, offset in { Vector3.new(7, 0, 0), Vector3.new(-7, 0, 0), Vector3.new(0, 0, 7), Vector3.new(0, 0, -7) } do
		if TowerService.Place(player, "Ranger", spot + offset) then
			placed = true
			break
		end
	end
	assert(placed, "could not build a Ranger near the spawn")
	rootPart.CFrame = CFrame.lookAt(Vector3.new(spot.X - 4, y, spot.Z), Vector3.new(spot.X + 7, y, spot.Z))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(1)
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
