-- Only in the test build (test.project.json): plays the game by itself at high
-- speed and prints [AUTOTEST] lines, so errors show up in Studio's log.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local function log(...)
	print("[AUTOTEST]", ...)
end

local function step(name, fn)
	local ok, err = pcall(fn)
	log(name, ok and "OK" or ("FAILED: " .. tostring(err)))
	return ok
end

task.wait(4)
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local ItemService = require(Server.ItemService)
local DataService = require(Server.DataService)
local State = require(Server.State)
local Clock = require(Server.Clock)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local waited = 0
while not DataService.Get(player) and waited < 20 do
	task.wait(0.5)
	waited += 0.5
end
log("player", player.Name, "profile", DataService.Get(player) ~= nil, "state", State.Get("State"))

step("give gold and unlocks", function()
	local p = DataService.Get(player)
	p.Gold = 100000
	p.Scrap = 1000
	p.Gems = 1000
	p.Owned.Towers.StormObelisk = true
	p.Owned.Towers.Ballista = true
	DataService.Publish(player)
end)

step("roll items", function()
	for _ = 1, 40 do
		local item = ItemService.Roll(math.random(1, 30), 3)
		assert(item.name and item.slot and item.rarity)
	end
	ItemService.VictoryChest("Hard")
end)

local function placeTowers()
	local types = { "Ranger", "FlameCannon", "FrostCrystal", "StormObelisk", "Ballista", "Ranger", "Ranger" }
	local placed = 0
	local pts = Config.Path
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for _, t in { 0.3, 0.7 } do
			for _, k in { -11, 11 } do
				local pos = a:Lerp(b, t) + side * k
				local ok, reason = TowerService.Place(player, types[placed % #types + 1], pos)
				if ok then
					placed += 1
				elseif reason ~= "Can't build on the path" and reason ~= "Too close to another defender"
					and reason ~= "Too close to the portal" and reason ~= "Too close to the edge" then
					log("place failed:", reason)
				end
			end
		end
	end
	-- upgrade every other defender twice
	for i, model in workspace.Towers:GetChildren() do
		if i % 2 == 0 then
			TowerService.Upgrade(player, model)
			TowerService.Upgrade(player, model)
		end
	end
	log("placed", placed, "build points", State.Get("BuildUsed"), "/", State.Get("BuildMax"))
end

local RUNS = {
	{ "MagmaFortress", "Campaign", 120 },
	{ "CrystalCaves", "Campaign", 120 },
	{ "CursedForest", "Campaign", 90 },
	{ "CursedForest", "BossRush", 40 },
	{ "CursedForest", "Endless", 40 },
}
-- the Baby Dragon follows the test player, for the pet look check
step("equip baby dragon", function()
	local ArtService = require(Server.ArtService)
	ArtService.WaitModel("pet_babydragon", 60)
	local profile = DataService.Get(player)
	profile.Pets = profile.Pets or {}
	table.insert(profile.Pets, { id = "testdragon", kind = "BabyDragon", level = 1, xp = 0, evolved = false })
	player:SetAttribute("TestPetLocked", true) -- the test client equips it (only a client can call that remote)
end)

-- a line-up of every enemy type at the Outpost, for the look check
step("enemy line-up", function()
	local EnemyService = require(Server.EnemyService)
	local ArtService = require(Server.ArtService)
	local started = os.clock()
	for _, look in { "goblin", "imp", "knight", "slime", "golem", "shade" } do
		ArtService.WaitModel("enemy_" .. look, 60)
	end
	for _, boss in { "boss_goblin_king", "boss_molten_golem", "boss_shadow_queen" } do
		ArtService.WaitModel(boss, 30)
	end
	log("enemy models loaded after", math.floor(os.clock() - started), "s")
	local names = {}
	for name in Config.Enemies do
		table.insert(names, name)
	end
	table.sort(names)
	local lineup = Instance.new("Folder")
	lineup.Name = "LineUp"
	lineup.Parent = workspace
	local c = Config.OutpostCenter
	for i, name in names do
		local e = EnemyService.Spawn(name, 1, 0)
		local model = e and e.model or nil
		if model then
			local x = (i - (#names + 1) / 2) * 9
			local copy = model:Clone() -- (Clear below destroys the real ones)
			copy:PivotTo(CFrame.lookAt(c + Vector3.new(x, Config.Enemies[name].Size, -4), c + Vector3.new(x, Config.Enemies[name].Size, 40)))
			copy.Parent = lineup
			local look = copy:FindFirstChild("Look")
			local bits = {}
			for _, part in look and look:GetChildren() or {} do
				table.insert(bits, part.Name .. "=" .. tostring(part.Color))
			end
			log("line-up", name, tostring(Config.Enemies[name].Color), table.concat(bits, " | "))
		end
	end
	EnemyService.Clear()
	log("line-up", #lineup:GetChildren())
end)
task.wait(75) -- time for the Outpost look check on the client
for _, run in RUNS do
	local mapId, mode, seconds = run[1], run[2], run[3]
	step("run " .. mapId .. " " .. mode, function()
		-- the game only starts a run from the lobby (it may still be setting up the Outpost)
		for _ = 1, 60 do
			if State.Get("State") == "Lobby" then
				break
			end
			task.wait(0.5)
		end
		State.Set("Map", mapId)
		State.Set("Mode", mode)
		State.Set("Difficulty", "Easy")
		GameService.StartRun()
		task.wait(1)
		State.Set("Gold", 100000)
		placeTowers()
		Clock.scale = 8
		local started = os.clock()
		local lastWave = 0
		while os.clock() - started < seconds do
			local s = State.Get("State")
			if s == "Won" or s == "Lost" then
				break
			end
			if State.Get("Wave") ~= lastWave then
				lastWave = State.Get("Wave")
				log(mapId, "wave", lastWave, "portal", State.Get("PortalHealth"), "kills", State.Get("Kills"))
			end
			task.wait(0.5)
		end
		log(mapId, "result", State.Get("State"), "wave", State.Get("Wave"), "kills", State.Get("Kills"),
			"portal", State.Get("PortalHealth"), "gold", player:GetAttribute("Gold"), "items", #DataService.Get(player).Items)
		Clock.scale = 1
		if State.Get("State") == "Won" or State.Get("State") == "Lost" then
			GameService.ToOutpost()
		else
			GameService.EndGame(false)
			GameService.ToOutpost()
		end
		task.wait(2)
	end)
end

step("rebirth and ascension", function()
	local HeroService = require(Server.HeroService)
	local p = DataService.Get(player)
	local hero = p.Heroes[p.SelectedHero or "Swordmaster"]
	hero.Level = Config.HeroMaxLevel
	HeroService.AddXp(player, Config.AscensionXp * 2 + 5)
	log("ascension points", player:GetAttribute("AscensionPoints"), "rebirths", player:GetAttribute("Rebirths"))
end)

step("quests", function()
	local q = DataService.Get(player).Quests
	for _, quest in q.List do
		log("quest", quest.Id, quest.Progress, quest.Claimed)
	end
end)
log("DONE")
pcall(function()
	game:GetService("StudioTestService"):EndTest("done")
end)
