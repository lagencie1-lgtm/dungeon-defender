-- Film rig for the research batch (test/batchfilm.project.json, scripts/film_route.ps1): the first-wave rescue on
-- Cursed Forest, the Goblin King's charge (tell, break, jam) and the training knight in the Outpost with the King's
-- Cleaver. Marks are printed as "[FILM] <unix ms> <name>".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local DataService = require(Server.DataService)
local EnemyService = require(Server.EnemyService)
local ItemService = require(Server.ItemService)
local State = require(Server.State)
local Clock = require(Server.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MapOutline = require(ReplicatedStorage.Shared.MapOutline)
local cue = ReplicatedStorage.FilmCue

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local deadline = os.clock() + 20
while not DataService.Get(player) and os.clock() < deadline do
	task.wait(0.2)
end

local king = nil
cue.OnServerEvent:Connect(function(sender, step, arg)
	if sender ~= player then
		return
	end
	mark(step)
	local profile = DataService.Get(player)
	if step == "Setup" then
		profile.Owned.Towers = profile.Owned.Towers or {}
		for _, kind in Config.TowerOrder do
			profile.Owned.Towers[kind] = true
		end
		player:SetAttribute("PassAutoCollect", false)
		cue:FireClient(player, "SetupReady")
	elseif step == "StartRun" then
		State.Set("Map", "CursedForest")
		State.Set("Mode", "Campaign")
		State.Set("Difficulty", "Normal")
		GameService.StartRun()
		task.wait(1.5)
		State.Set("Gold", 2000)
		local ok = TowerService.Place(player, "Ranger", MapOutline.Start.Forest.FirstSpot)
		print("[FILM]", DateTime.now().UnixTimestampMillis, "ranger on the first spot " .. tostring(ok))
		cue:FireClient(player, "RunReady")
	elseif step == "Boss" then
		-- the King at the second corner, near the keep hill's Ranger, his first charge soon
		king = EnemyService.Spawn("GoblinKing", 0.4, EnemyService.CornerDistance(2) - 10)
		king.nextCharge = Clock.now + 3
		cue:FireClient(player, "BossReady")
	elseif step == "BossGone" then
		GameService.EndGame(false)
		GameService.ToOutpost()
		task.wait(3)
		-- the King's Cleaver, as a first win would give it, put on
		profile.BossFirst = {}
		ItemService.BossReward(player, "GoblinKing", "Normal")
		local item = profile.Items[#profile.Items]
		profile.Gear.Weapon = item.id
		ItemService.ApplyBonuses(player)
		cue:FireClient(player, "OutpostReady")
	elseif step == "Done" then
		pcall(function()
			game:GetService("StudioTestService"):EndTest("film done")
		end)
	end
end)
mark("server ready")
