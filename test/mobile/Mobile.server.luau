local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local MapLayouts = require(Server.MapLayouts)
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(ReplicatedStorage.Shared.Ground)
local State = require(Server.State)
local Effects = require(Server.Effects)
local probe = ReplicatedStorage.MobileTest

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local function waitFor(predicate, limit)
	local deadline = os.clock() + limit
	repeat
		if predicate() then
			return
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("timed out waiting for " .. tostring(probe:GetAttribute("Check")))
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
	waitFor(function() return completed == name end, 90)
end

waitFor(function() return State.Get("State") == "Lobby" and player.Character ~= nil end, 45)
check("Outpost")
for _, mapId in { "MagmaFortress", "CursedForest", "CrystalCaves" } do
	State.Set("Map", mapId)
	GameService.StartRun()
	-- the map's designed layout is on the ground after terrain generation: its first raised floor stands at its
	-- height (this used to look for a "trail marker" of plain blocks, which is gone)
	local floor = MapLayouts.For(Config.Maps[mapId].Theme).Plateaus[1]
	local y = (Ground.At((floor.X0 + floor.X1) / 2, (floor.Z0 + floor.Z1) / 2))
	assert(math.abs(y - floor.H) < 0.5, "missing " .. floor.Name .. " after terrain generation")
	check(mapId)
	GameService.EndGame(false)
	GameService.ToOutpost()
end

local function worldEffects()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		Effects.Arc(root.CFrame, 3, Color3.new(1, 1, 1), false)
		Effects.Ring(root.Position, 5, Color3.new(1, 0, 0), 1)
	end
end
task.defer(function()
	while probe:GetAttribute("Check") == "Combat" do
		worldEffects()
		task.wait(0.25)
	end
end)
check("Combat")
local result = failures == 0 and "all checks passed" or (failures .. " checks failed")
print("[MOBILE] DONE", result)
pcall(function()
	game:GetService("StudioTestService"):EndTest(result)
end)
