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
			for _, sign in { -1, 1 } do
				-- 11 studs off the lane, then further out: the raised ground leaves less room beside the lanes
				local reasons = {}
				for _, k in { 11, 14, 17 } do
					local pos = a:Lerp(b, t) + side * (k * sign)
					local ok, reason = TowerService.Place(player, types[placed % #types + 1], pos)
					if ok then
						placed += 1
						reasons = {}
						break
					end
					table.insert(reasons, tostring(reason))
				end
				for _, reason in reasons do
					if reason ~= "Can't build on the path" and reason ~= "Too close to another defender"
						and reason ~= "Too close to the portal" and reason ~= "Too close to the edge" then
						log("place failed:", reason)
						break
					end
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

-- three pets walk with the hero: the lead and two helpers (slots opened for the test)
step("pet team", function()
	local PetService = require(Server.PetService)
	Config.PetTeamLevels = { 1, 1, 1 }
	local profile = DataService.Get(player)
	table.insert(profile.Pets, { id = "testslime", kind = "Slimey", level = 1, xp = 0, evolved = false })
	table.insert(profile.Pets, { id = "testowl", kind = "CrystalOwl", level = 1, xp = 0, evolved = false })
	PetService.Equip(player, "testdragon", "Lead")
	PetService.Equip(player, "testslime")
	PetService.Equip(player, "testowl")
	local team = PetService.Team(player)
	log("team", #team, team[1] and team[1].kind, "followers", #PetService.FollowersOf(player), "slots", PetService.SlotsOf(player))
	assert(#team == 3 and #PetService.FollowersOf(player) == 3, "three pets should walk with the hero")
	assert(team[1].kind == "BabyDragon", "the dragon should lead")
	local bonuses = PetService.TeamBonuses(player)
	log("bonuses", #bonuses, bonuses[1][1], bonuses[1][2], bonuses[2][1], bonuses[2][2])
	assert(bonuses[2][2] == Config.Pets.Slimey.Bonus * Config.PetHelperBonus, "a helper gives half its bonus")
	PetService.Equip(player, "testslime", "Off")
	assert(#PetService.Team(player) == 2, "a pet can rest")
	PetService.Equip(player, "testslime")
	assert(#PetService.FollowersOf(player) == 3)
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
-- The first-wave rescue (RescueService): Cursed Forest, wave 1, one Ranger on the tutorial's first spot, the hero
-- standing still at the keep. The Sneak must come out at corner 5, get past that Ranger alive, and every hero must be
-- shown a spot where it can still be caught; then the hero catches it there (a hit by the player counts as a rescue).
step("first-wave rescue", function()
	local EnemyService = require(Server.EnemyService)
	local MapOutline = require(game:GetService("ReplicatedStorage").Shared.MapOutline)
	for _ = 1, 60 do
		if State.Get("State") == "Lobby" then
			break
		end
		task.wait(0.5)
	end
	State.Set("Map", "CursedForest")
	State.Set("Mode", "Campaign")
	State.Set("Difficulty", "Normal")
	GameService.StartRun()
	task.wait(2)
	State.Set("Gold", 1000)
	local spot = MapOutline.Start.Forest.FirstSpot
	local placed, why = TowerService.Place(player, "Ranger", spot)
	log("rescue: Ranger on the first spot", placed, why or "")
	-- before the first wave a defender sells for everything it cost (Config.RefundWindow)
	do
		local manaBefore = State.Get("Gold")
		local model = nil
		for _, m in workspace.Towers:GetChildren() do
			model = m
		end
		local ok, refund = TowerService.Sell(player, model)
		log("refund before wave 1:", ok, refund, "of", Config.Towers.Ranger.Cost, "mana", manaBefore, "->", State.Get("Gold"))
		assert(ok and refund == Config.Towers.Ranger.Cost, "selling before the first wave didn't give everything back")
		placed, why = TowerService.Place(player, "Ranger", spot)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local home = root and root.Position
	Clock.scale = 2
	-- skip the break (the server's own Start wave button)
	for _ = 1, 40 do
		if State.Get("State") == "Break" then
			break
		end
		task.wait(0.25)
	end
	local sneak, escapedAt, spotSeen = nil, nil, nil
	local deadline = os.clock() + 90
	while os.clock() < deadline do
		if root and home then
			root.CFrame = CFrame.new(home) -- the hero stands still at the keep (no help from it)
		end
		for _, e in EnemyService.GetActive() do
			if e.stats.Rescue and not e.dead then
				sneak = e
			end
		end
		local at = player:GetAttribute("RescueAt")
		if sneak and typeof(at) == "Vector3" then
			spotSeen = at
			escapedAt = sneak.health .. "/" .. sneak.maxHealth
			break
		end
		task.wait(0.1)
	end
	assert(sneak, "no Sneak in Cursed Forest's first wave")
	log("rescue: Sneak started at", math.floor(EnemyService.CornerDistance(5)), "studs; past the Ranger with health",
		escapedAt or "?", "catch spot", spotSeen)
	assert(spotSeen, "the Sneak never slipped past, or no catch spot was shown")
	-- the hero runs to the spot and catches it
	root.CFrame = CFrame.new(spotSeen + Vector3.new(0, 4, 0))
	local rescuesBefore = player:GetAttribute("Rescues") or 0
	for _ = 1, 60 do
		if sneak.dead then
			break
		end
		if (sneak.position - spotSeen).Magnitude < 14 then
			EnemyService.Damage(sneak, 25, player, true, false)
		end
		task.wait(0.1)
	end
	log("rescue: caught", sneak.dead, "rescues", player:GetAttribute("Rescues") or 0, "spot cleared",
		player:GetAttribute("RescueAt") == nil, "portal", State.Get("PortalHealth"))
	assert((player:GetAttribute("Rescues") or 0) == rescuesBefore + 1, "catching the Sneak was not counted as a rescue")
	Clock.scale = 1
	GameService.EndGame(false)
	GameService.ToOutpost()
	task.wait(2)
end)

-- Trying a build never costs (research report): gear sets put a saved set back on in one go, auto-salvage turns a
-- worse plain drop into scrap. (Refunds are checked in the rescue run below, before its first wave.)
step("gear sets and auto-salvage", function()
	local profile = DataService.Get(player)
	local weaponBefore = profile.Gear.Weapon
	-- save set 1, wear another weapon, put set 1 back on
	local other = ItemService.Roll(5, 1, 1, "Weapon")
	table.insert(profile.Items, other)
	assert(ItemService.GearSet(player, "save", 1), "saving set 1 failed")
	profile.Gear.Weapon = other.id
	ItemService.ApplyBonuses(player)
	local ok, text = ItemService.GearSet(player, "use", 1)
	log("gear sets:", ok, text, "weapon back", profile.Gear.Weapon == weaponBefore)
	assert(ok and profile.Gear.Weapon == weaponBefore, "the saved set didn't come back")
	table.remove(profile.Items, table.find(profile.Items, other))
	-- auto-salvage Common: a Common weapon weaker than the one worn becomes scrap on arrival
	local strong = ItemService.Roll(30, 1, 3, "Weapon")
	table.insert(profile.Items, strong)
	local wornBefore = profile.Gear.Weapon
	profile.Gear.Weapon = strong.id
	profile.AutoSalvage = 1
	local scrapBefore, count = profile.Scrap, #profile.Items
	local weak = ItemService.Roll(1, 0.01, 1, "Weapon")
	weak.rarity, weak.stats = 1, { Power = 0.1 }

	local kept = ItemService.AddForTest(player, weak)
	log("auto-salvage: kept", kept, "scrap", scrapBefore, "->", profile.Scrap, "items", count, "->", #profile.Items)
	profile.AutoSalvage = 0
	profile.Gear.Weapon = wornBefore
	table.remove(profile.Items, table.find(profile.Items, strong))
	ItemService.ApplyBonuses(player)
	assert(not kept and profile.Scrap > scrapBefore, "a weaker Common wasn't auto-salvaged")
end)

-- The training knight in the Outpost (EnemyService.SpawnDummy): stands, never falls, doesn't hold up a wave; armor
-- takes a bite out of every hit unless a King's Cleaver cracked it.
step("training knight and the cleaver's crack", function()
	local EnemyService = require(Server.EnemyService)
	for _ = 1, 60 do
		if State.Get("State") == "Lobby" then
			break
		end
		task.wait(0.5)
	end
	local knight = nil
	for _, e in EnemyService.GetActive() do
		if e.stats.Dummy then
			knight = e
		end
	end
	assert(knight, "no training knight in the Outpost")
	assert(EnemyService.Count() == 0, "the training knight counts as an enemy of the run")
	local before = knight.health
	EnemyService.Damage(knight, 10, player, false, false)
	local plain = before - knight.health
	knight.crackedUntil = Clock.now + 3
	before = knight.health
	EnemyService.Damage(knight, 10, player, false, false)
	local cracked = before - knight.health
	EnemyService.Damage(knight, 99999, player, false, false)
	log("training knight: 10 damage does", plain, "armored,", cracked, "cracked; alive after a huge hit", not knight.dead,
		"at", knight.position - Config.OutpostCenter)
	assert(plain < 10 and cracked == 10, "armor and the crack don't work as written")
	assert(not knight.dead, "the training knight fell")
end)

-- A boss's own reward (Config.BossRewards): the first win gives the King's Cleaver for sure; after that the meter
-- fills (Normal = 2 of 8) and a full meter gives it again.
step("boss reward and meter", function()
	local profile = DataService.Get(player)
	profile.BossFirst, profile.BossMeter = {}, {}
	local count = #profile.Items
	ItemService.BossReward(player, "GoblinKing", "Normal")
	local first = profile.Items[#profile.Items]
	assert(#profile.Items == count + 1 and first.base == "KingsCleaver", "the first win didn't give the King's Cleaver")
	ItemService.BossReward(player, "GoblinKing", "Normal")
	local meter = player:GetAttribute("BossMeter_GoblinKing")
	profile.BossMeter.GoblinKing = 7
	local before = #profile.Items
	ItemService.BossReward(player, "GoblinKing", "Normal")
	log("boss reward: first", first.name, first.rarity, "stats", first.stats.Power, first.stats.Command, first.stats.Crit,
		"meter after one more", meter, "full meter gave", #profile.Items - before, "meter now", player:GetAttribute("BossMeter_GoblinKing"))
	assert(meter == 2 or #profile.Items > count + 1, "the meter didn't fill")
	assert(#profile.Items == before + 1, "a full meter didn't give the reward")
end)

-- One boss, two jobs (BossService): the Goblin King winds up a charge at the nearest defender; three hero hits break
-- it (he staggers and is weak for a moment); left alone, the charge jams that defender.
step("boss charge: tell, break, jam", function()
	local EnemyService = require(Server.EnemyService)
	for _ = 1, 60 do
		if State.Get("State") == "Lobby" then
			break
		end
		task.wait(0.5)
	end
	State.Set("Map", "CursedForest")
	State.Set("Mode", "Campaign")
	State.Set("Difficulty", "Normal")
	GameService.StartRun()
	task.wait(2)
	State.Set("Gold", 2000)
	-- a Ranger beside the path 60 studs in, the King walking up to it
	local a, b = Config.Path[2], Config.Path[3]
	local dir = (b - a).Unit
	local spot = a:Lerp(b, 0.4) + Vector3.new(-dir.Z, 0, dir.X) * 12
	local placed = TowerService.Place(player, "Ranger", spot)
	if not placed then
		placed = TowerService.Place(player, "Ranger", require(game:GetService("ReplicatedStorage").Shared.MapOutline).Start.Forest.FirstSpot)
	end
	assert(placed, "no Ranger for the King to charge")
	Clock.scale = 3
	local king = EnemyService.Spawn("GoblinKing", 1, 0)
	local function waitCharge()
		for _ = 1, 150 do
			if king.charging or king.dead then
				break
			end
			task.wait(0.1)
		end
		return king.charging
	end
	local charging = waitCharge()
	assert(charging, "the King never wound up a charge")
	local marker = charging.target:FindFirstChild("ChargeTarget")
	local beads = 0
	for _, d in (workspace:FindFirstChild("Effects") or workspace):GetChildren() do
		if d.Name == "ChargeLine" then
			beads += 1
		end
	end
	for _ = 1, 3 do
		EnemyService.Damage(king, 5, player, true, false)
	end
	log("boss charge: tell marker", marker ~= nil, "line beads", beads, "broken", king.charging == nil,
		"weak", king.weakUntil ~= nil and king.weakUntil > Clock.now)
	assert(marker and beads > 0, "the charge had no tell")
	assert(king.charging == nil and king.weakUntil and king.weakUntil > Clock.now, "three hero hits didn't break the charge")
	-- the next one: nobody answers
	charging = waitCharge()
	assert(charging, "no second charge")
	local towerModel = charging.target
	for _ = 1, 100 do
		if not king.charging then
			break
		end
		task.wait(0.1)
	end
	task.wait(0.6)
	local jammed = towerModel:FindFirstChild("ChargeTarget") == nil
	log("boss charge: unanswered charge landed; marker gone", jammed, "king alive", not king.dead)
	Clock.scale = 1
	GameService.EndGame(false)
	GameService.ToOutpost()
	task.wait(2)
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
		step("map layout " .. mapId, function()
			-- the designed layout is on the ground (its first raised floor stands at its height) and nothing in it
			-- stands alone (this used to look for a "trail marker" of plain blocks, which is gone)
			local MapLayouts = require(Server.MapLayouts)
			local Ground = require(game:GetService("ReplicatedStorage").Shared.Ground)
			local layout = MapLayouts.For(Config.Maps[mapId].Theme)
			local floor = layout.Plateaus[1]
			local y = (Ground.At((floor.X0 + floor.X1) / 2, (floor.Z0 + floor.Z1) / 2))
			assert(math.abs(y - floor.H) < 0.5, "missing " .. floor.Name)
			assert(#MapLayouts.Loose(layout) == 0, "a map piece stands alone")
		end)
		State.Set("Gold", 100000)
		placeTowers()
		if not fetchTested then
			fetchTested = true
			-- pets fetch loot (PetMoves): gems and a gear drop 14 studs from the hero, out of the hero's own reach
			local LootService = require(Server.LootService)
			local ItemService = require(Server.ItemService)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local Ground = require(game:GetService("ReplicatedStorage").Shared.Ground)
			local function onGround(v)
				return Vector3.new(v.X, (Ground.At(v.X, v.Z)), v.Z)
			end
			local spot = onGround(root.Position + Vector3.new(14, 0, 0))
			-- (the place's owner has the Auto Collect pass in Studio: off for this check, or the pass takes the loot first)
			local hadAuto = player:GetAttribute("PassAutoCollect")
			player:SetAttribute("PassAutoCollect", false)
			local before = #DataService.Get(player).Items
			local gemsBefore = DataService.Get(player).Gems
			LootService.DropGems(spot, 3)
			ItemService.OnEnemyKilled({ name = "Test", stats = { DropChance = 50 }, position = spot + Vector3.new(0, 0, 3) },
				State.Get("Difficulty"), 1)
			local pet = require(Server.PetService).FollowerOf(player)
			-- trips of the whole team (any of the three pets may be the one that goes)
			local function teamTrips()
				local trips = 0
				for _, f in require(Server.PetService).FollowersOf(player) do
					trips += f.model:GetAttribute("PetFetched") or 0
				end
				return trips
			end
			local waited = 0
			while waited < 12 and (#DataService.Get(player).Items == before or DataService.Get(player).Gems == gemsBefore) do
				task.wait(0.25)
				waited += 0.25
			end
			task.wait(0.3)
			player:SetAttribute("PassAutoCollect", hadAuto)
			log("pet fetch: items", #DataService.Get(player).Items - before, "gems", DataService.Get(player).Gems - gemsBefore,
				"after", waited, "s, trips", teamTrips(), "lead's phase", pet and pet:GetAttribute("FetchPhase"))
			assert(#DataService.Get(player).Items > before, "the pet did not fetch the gear drop")
			assert(DataService.Get(player).Gems > gemsBefore, "the pet did not fetch the gems")
			assert(teamTrips() > 0, "the loot came in, but not by a pet")
			-- with the Auto Collect pass the pets still do the fetching: twice as fast, from the whole map
			player:SetAttribute("PassAutoCollect", true)
			local far = onGround(root.Position + Vector3.new(60, 0, 0))
			local itemsBefore = #DataService.Get(player).Items
			ItemService.OnEnemyKilled({ name = "Test", stats = { DropChance = 50 }, position = far }, State.Get("Difficulty"), 1)
			task.wait(0.3)
			assert(#DataService.Get(player).Items == itemsBefore, "with a pet, the pass must not put loot in the backpack at once")
			local waitedPass = 0.3
			while waitedPass < 12 and #DataService.Get(player).Items == itemsBefore do
				task.wait(0.25)
				waitedPass += 0.25
			end
			log("pet fetch with the pass, 60 studs away: items", #DataService.Get(player).Items - itemsBefore, "after", waitedPass, "s")
			assert(#DataService.Get(player).Items > itemsBefore, "the pet did not fetch the far drop with the pass")
			player:SetAttribute("PassAutoCollect", hadAuto)
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
	-- a Mythic-rank hero is really bigger (measured on its torso, then back to its own rank).
	-- (The whole-body height was flaky: the runs before leave the hero next to monsters, and a hero that is down or
	-- respawning in that second has another body. So: wait for a living hero, measure that same body's torso.)
	local character, torso = nil, nil
	for _ = 1, 40 do
		character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		torso = character and character:FindFirstChild("UpperTorso")
		if humanoid and humanoid.Health > 0 and torso then
			break
		end
		task.wait(0.25)
	end
	assert(torso, "no living hero to measure")
	local rankBefore = player:GetAttribute("MightRank")
	player:SetAttribute("MightRank", 1)
	task.wait(1)
	local torsoBefore = torso.Size.Y
	player:SetAttribute("MightRank", 6)
	local torsoAfter = torsoBefore
	for _ = 1, 20 do
		task.wait(0.25)
		torsoAfter = torso.Size.Y
		if torsoAfter > torsoBefore * 1.08 then
			break
		end
	end
	log("hero torso", string.format("%.3f -> %.3f", torsoBefore, torsoAfter), "rank 1 -> 6, back to", rankBefore,
		"same body", torso.Parent == character and player.Character == character)
	player:SetAttribute("MightRank", rankBefore)
	task.wait(0.5)
	assert(torsoAfter > torsoBefore * 1.08, "the hero did not grow at Mythic rank")
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
-- the pets screen (team, Pet Index) and the shop are built on the player's device: open them once, so an error
-- in them shows in the log; a Might style is put on and taken off
step("screens and a Might style", function()
	local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
	Remotes.OpenPanel:FireClient(player, "Pets")
	task.wait(2)
	local profile = DataService.Get(player)
	assert(profile.Owned.Skins and profile.Owned.Skins.AuraForest, "the free Might style should be owned")
	player:SetAttribute("MightRank", 6)
	profile.Equipped.Skins.Aura = "AuraForest"
	player:SetAttribute("EquippedAura", "AuraForest")
	task.wait(1.5)
	player:SetAttribute("EquippedAura", "")
	profile.Equipped.Skins.Aura = nil
	require(Server.ItemService).ApplyBonuses(player)
	log("might style worn and taken off, rank back to", player:GetAttribute("MightRank"))
end)
log("DONE")
pcall(function()
	game:GetService("StudioTestService"):EndTest("done")
end)
