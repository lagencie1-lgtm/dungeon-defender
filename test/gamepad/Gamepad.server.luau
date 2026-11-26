-- Only in the gamepad test build: drives the steps the client checks (open panels from the server like the
-- Outpost stations do, start a run, give mana) and ends the play test with the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local State = require(Server.State)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local probe = ReplicatedStorage.GamepadTest

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

local completed
local failures = 0
probe.OnServerEvent:Connect(function(sender, name, failure)
	if sender == player and name == probe:GetAttribute("Check") then
		if failure then
			failures += 1
		end
		completed = name
	end
end)

local function check(name)
	probe:SetAttribute("Check", name)
	local ok = pcall(waitFor, function() return completed == name end, 40, name)
	if not ok then
		failures += 1
		print("[GAMEPAD]", name, "FAILED: no answer from the client")
	end
end

local ok, err = pcall(function()
	waitFor(function() return State.Get("State") == "Lobby" and player.Character ~= nil end, 60, "the Outpost")
	task.wait(3) -- the client scripts build their screens
	-- every screen a station opens, the way the stations open it
	for _, panel in { "Shop", "Daily", "Maps", "Backpack", "Heroes", "Pets", "Quests" } do
		probe:SetAttribute("Panel", panel)
		Remotes.OpenPanel:FireClient(player, panel)
		check("Panel " .. panel)
	end
	check("Menu")
	check("Dock")
	probe:SetAttribute("Where", "Outpost")
	check("Reach")
	State.Set("Map", "CursedForest")
	GameService.StartRun()
	waitFor(function() return State.Get("State") == "Break" end, 60, "the run")
	task.wait(2)
	State.Set("Gold", 5000) -- enough mana to build and upgrade
	check("Build")
	check("Upgrade")
	check("Sell")
	probe:SetAttribute("Where", "run")
	check("Reach")
	check("Run buttons")
	check("Readable")
end)
if not ok then
	failures += 1
	print("[GAMEPAD] server FAILED:", err)
end
local result = failures == 0 and "all checks passed" or (failures .. " checks failed")
print("[GAMEPAD] DONE", result)
pcall(function()
	game:GetService("StudioTestService"):EndTest(result)
end)
