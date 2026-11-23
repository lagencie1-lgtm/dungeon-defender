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
player:SetAttribute("TestRewardReady", true)

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
local fetchTested = false
local mapPropNames = { CursedForest = "Bramble Waystone", MagmaFortress = "Forge Vent", CrystalCaves = "Crystal Survey Cairn" }
-- the Baby Dragon follows the test player, for the pet look check
step("equip baby dragon", function()
	local ArtService = require(Server.ArtService)
	ArtService.WaitModel("pet_babydragon", 60)
	local profile = DataService.Get(player)
	profile.Pets = profile.Pets or {}
	table.insert(profile.Pets, { id = "testdragon", kind = "BabyDragon", level = 1, xp = 0, evolved = false })
	player:SetAttribute("TestPetLocked", true) -- the test client equips it (only a client can call that remote)
	require(Server.PetService).Equip(player, "testdragon") -- and on the server, so the runs below have a pet
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
-- a row of every pet model at the Outpost, for the pet look check
step("pet line-up", function()
	local ArtService = require(Server.ArtService)
	local kinds = {}
	for kind in Config.Pets do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	local row = Instance.new("Folder")
	row.Name = "PetRow"
	row.Parent = workspace
	local c = Config.OutpostCenter
	for i, kind in kinds do
		local template = ArtService.WaitModel("pet_" .. string.lower(kind), 30)
		if template then
			local look = template:Clone()
			local _, size = look:GetBoundingBox()
			look:ScaleTo(look:GetScale() * 3.2 / size.Y)
			local box, newSize = look:GetBoundingBox()
			local x = (i - (#kinds + 1) / 2) * 4.2
			local y = newSize.Y / 2 + 1.6 -- (the plaza ground sits a little above zero)
			local target = CFrame.lookAt(c + Vector3.new(x, y, 15), c + Vector3.new(x, y, 40))
			look:PivotTo(target * box:ToObjectSpace(look:GetPivot()))
			look.Parent = row
		end
	end
	log("pet row", #row:GetChildren())
end)
task.wait(95) -- time for the Outpost look check on the client
step("painted oak", function()
	local art = require(Server.ArtService)
	local oak = assert(art.WaitModel("tree_oak", 20), "oak model did not load")
	local body = oak:FindFirstChild("Body")
	local paint = art.Image("paint_tree_oak", 5)
	assert(body and body:IsA("MeshPart") and #oak:GetChildren() == 1, "expected one painted MeshPart")
	assert(paint and body.TextureID == paint, "oak is missing its painted atlas")
end)
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
		step("map prop " .. mapId, function()
			local prop = workspace.Map.Decor:FindFirstChild(mapPropNames[mapId])
			assert(prop, "missing trail marker")
			for _, part in prop:GetChildren() do
				assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
				assert(Config.DistanceToPath(part.Position) > Config.PathWidth / 2 + 2)
			end
		end)
		State.Set("Gold", 100000)
		placeTowers()
		if not fetchTested then
			fetchTested = true
			-- pets fetch loot (PetMoves): gems and a gear drop 14 studs from the hero, out of the hero's own reach
			local LootService = require(Server.LootService)
			local ItemService = require(Server.ItemService)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local spot = root.Position + Vector3.new(14, 0, 0)
			-- (the place's owner has the Auto Collect pass in Studio: off for this check, or the pass takes the loot first)
			local hadAuto = player:GetAttribute("PassAutoCollect")
			player:SetAttribute("PassAutoCollect", false)
			local before = #DataService.Get(player).Items
			local gemsBefore = DataService.Get(player).Gems
			LootService.DropGems(spot, 3)
			ItemService.OnEnemyKilled({ name = "Test", stats = { DropChance = 50 }, position = spot + Vector3.new(0, 0, 3) },
				State.Get("Difficulty"), 1)
			local pet = require(Server.PetService).FollowerOf(player)
			local waited = 0
			while waited < 12 and (#DataService.Get(player).Items == before or DataService.Get(player).Gems == gemsBefore) do
				task.wait(0.25)
				waited += 0.25
			end
			task.wait(0.3)
			player:SetAttribute("PassAutoCollect", hadAuto)
			log("pet fetch: items", #DataService.Get(player).Items - before, "gems", DataService.Get(player).Gems - gemsBefore,
				"after", waited, "s, trips", pet and pet:GetAttribute("PetFetched") or 0, "phase", pet and pet:GetAttribute("FetchPhase"))
			assert(#DataService.Get(player).Items > before, "the pet did not fetch the gear drop")
			assert(DataService.Get(player).Gems > gemsBefore, "the pet did not fetch the gems")
			assert((pet:GetAttribute("PetFetched") or 0) > 0, "the loot came in, but not by the pet")
		end
		Clock.scale = 8
		local started = os.clock()
		local lastWave = 0
		while os.clock() - started < seconds do
			local s = State.Get("State")
			if s == "Won" or s == "Lost" then
				break
			end
			-- keep the hero next to the fight, so the pet has enemies to pounce on and loot to fetch
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local target = require(Server.EnemyService).GetActive()[1]
			if root and target and not target.dead then
				root.CFrame = CFrame.new(target.position + Vector3.new(6, 4, 6))
			end
			if State.Get("Wave") ~= lastWave then
				lastWave = State.Get("Wave")
				log(mapId, "wave", lastWave, "portal", State.Get("PortalHealth"), "kills", State.Get("Kills"))
			end
			task.wait(0.5)
		end
		log(mapId, "result", State.Get("State"), "wave", State.Get("Wave"), "kills", State.Get("Kills"),
			"portal", State.Get("PortalHealth"), "gold", player:GetAttribute("Gold"), "items", #DataService.Get(player).Items)
		-- pets do something in a fight (PetMoves): the equipped Baby Dragon should have pounced during the waves
		local pet = require(Server.PetService).FollowerOf(player)
		log(mapId, "pet moves", pet and pet:GetAttribute("PetAct") or "no pet", pet and pet:GetAttribute("PetActMove") or "",
			"fetch trips", pet and pet:GetAttribute("PetFetched") or 0)
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

step("mythic tiers and might", function()
	local t5 = Config.DifficultyFor("Mythic", 5)
	assert(t5.Health > Config.DifficultyFor("Insane").Health, "mythic 5 is not tougher than insane")
	log("mythic 5", t5.Name, "health x", string.format("%.2f", t5.Health), "gems x", t5.Gems)
	log("might", player:GetAttribute("Might"), "rank", player:GetAttribute("MightRank"))
	-- a Mythic-rank hero is really bigger (measured, then back to its own rank)
	local character = player.Character
	local rankBefore = player:GetAttribute("MightRank")
	local heightBefore = character:GetExtentsSize().Y
	player:SetAttribute("MightRank", 6)
	task.wait(1)
	local heightAfter = character:GetExtentsSize().Y
	log("hero height", string.format("%.2f -> %.2f", heightBefore, heightAfter), "rank", rankBefore, "-> 6")
	player:SetAttribute("MightRank", rankBefore)
	task.wait(0.5)
	assert(heightAfter > heightBefore * 1.05, "the hero did not grow at Mythic rank")
end)

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
