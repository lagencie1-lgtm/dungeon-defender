-- All the numbers for the game in one place, so they are easy to change.
local Config = {}

-- The Cursed Forest path. Goblins walk from the first point to the last one.
-- (2026-11-22, phone first: the old loop ran 30+ studs from the hero, so on a phone the wave was never on screen;
-- this one wraps a 36-stud yard round the hero's spawn, so the lanes on three sides are always close)
local ForestPath = {
	Vector3.new(-95, 0, -44), -- start (goblin camp)
	Vector3.new(-24, 0, -44),
	Vector3.new(-24, 0, 10),
	Vector3.new(12, 0, 10),
	Vector3.new(12, 0, -34),
	Vector3.new(52, 0, -34),
	Vector3.new(52, 0, 42),
	Vector3.new(95, 0, 42), -- the magic portal you defend
}
Config.PathWidth = 10

-- the first-wave rescue (RescueService, RescueCue.client): when the Sneak has walked EscapeAt of the path it counts
-- as slipping past and every hero is shown where they can still catch it (heroes run 20; HeroSpeed allows for
-- turns and stairs, Margin is seconds to spare)
Config.Rescue = { EscapeAt = 0.55, HeroSpeed = 16, Margin = 0.8 }
Config.MapSize = Vector2.new(240, 180) -- ground size (X, Z)
Config.OutpostCenter = Vector3.new(0, 0, 1600) -- the hub, far from the battlefield (its own terrain and hills)
-- which hub: "Keep" (the Watch Keep, 2026-11-22, layout in HubLayout.luau) or "Meadow" (the old open meadow)
Config.HubVersion = "Keep"

-- the camera at a run's start (src/client/RunCamera.client.luau): degrees down, studs from the hero, and how far above
-- the hero it aims (raised, the hero sits lower on the screen and more of what is ahead shows). Was 42, 20.5, 0;
-- 2026-11-24 the camera trial (reviews/camera/starting_views.png): 32 degrees aimed 3 studs up, in the test build.
Config.RunCamera = { Pitch = 32, Distance = 20.5, AimHeight = 3 }

Config.StartGold = 200
Config.PortalHealth = 100
Config.BreakTime = 20 -- seconds between waves (press "Start wave" to skip)
Config.FirstBreakTime = 35
Config.WaveHealthGrowth = 0.12 -- enemies get 12% more health each wave
Config.WaveBonusGold = 40 -- gold for clearing a wave
Config.Speeds = { 1, 2 } -- the speed button switches between these

-------------------------------------------------------------------------------
-- Difficulty: picked before wave 1. Harder = tougher goblins, more gems.
-------------------------------------------------------------------------------
Config.Difficulties = {
	{ Id = "Easy", Name = "Easy", Subtitle = "Just vibing. Weak loot", Health = 0.55, Gems = 0.5, Gold = 0.5,
		Color = Color3.fromRGB(90, 200, 110) },
	{ Id = "Normal", Name = "Normal", Subtitle = "The real game", Health = 1, Gems = 1, Gold = 1,
		Color = Color3.fromRGB(240, 190, 70) },
	{ Id = "Hard", Name = "Hard", Subtitle = "No cap, it's hard", Health = 1.6, Gems = 1.8, Gold = 1.5, Unlock = "Normal",
		Color = Color3.fromRGB(230, 80, 80) },
	{ Id = "Insane", Name = "Insane", Subtitle = "Bring gear, pets and upgrades", Health = 2.6, Gems = 3, Gold = 2.2, Unlock = "Hard",
		Color = Color3.fromRGB(180, 60, 220) },
	{ Id = "Mythic", Name = "Mythic", Subtitle = "Endless tiers. Tap again for the next", Health = 2.6, Gems = 3, Gold = 2.2,
		Unlock = "Insane", Tiers = true, Color = Color3.fromRGB(255, 70, 120) },
}
Config.DefaultDifficulty = "Normal"

-- Mythic Tiers: the endless ladder above Insane (Lemp 2026-11-23: "an ultimate grind"). Tier 1 opens after Insane;
-- winning a Campaign run on a tier opens the next one, for the whole account. Per tier: monsters' health x HealthGrowth
-- (it compounds, so somewhere the wall comes), item level +ItemLevel, rarity luck +Luck, gems and gold a bit more.
Config.Mythic = { HealthGrowth = 1.2, ItemLevel = 8, Luck = 0.5, Gems = 0.25, Gold = 0.15 }

-- Might ranks: how grand a hero looks, from the Might of the gear it wears (Items.Might). Colours follow the rarities.
-- 6A: every step is small and quiet on its own; together they read "this one is strong" from across the map.
--   Glow   a soft light around the hero       Motes  a few slow sparks rising from the gear
--   Ring   a thin ring of light at the feet   Halo   a thin ring of light over the head
--   Scale  the hero grows a little (1.0 = normal size)
Config.MightRanks = {
	{ Name = "Common", At = 0 },
	{ Name = "Uncommon", At = 60, Glow = true },
	{ Name = "Rare", At = 160, Glow = true, Motes = true },
	{ Name = "Epic", At = 400, Glow = true, Motes = true, Ring = true, Scale = 1.04 },
	{ Name = "Legendary", At = 900, Glow = true, Motes = true, Ring = true, Scale = 1.08 },
	{ Name = "Mythic", At = 1800, Glow = true, Motes = true, Ring = true, Halo = true, Scale = 1.12 },
	{ Name = "Ascendant", At = 4000, Glow = true, Motes = true, Ring = true, Halo = true, Scale = 1.16, Color = Color3.fromRGB(255, 240, 170) },
}
function Config.MightRankOf(might)
	local rank = 1
	for i, r in Config.MightRanks do
		if (might or 0) >= r.At then
			rank = i
		end
	end
	return rank
end

-- a difficulty with its Mythic tier worked in (the plain entry for the others)
function Config.DifficultyFor(id, tier)
	local d = Config.FindById(Config.Difficulties, id) or Config.FindById(Config.Difficulties, Config.DefaultDifficulty)
	if not d.Tiers then
		return d
	end
	tier = math.max(1, math.floor(tier or 1))
	local m = Config.Mythic
	local t = table.clone(d)
	t.Tier = tier
	t.Name = d.Name .. " " .. tier
	t.Health = d.Health * m.HealthGrowth ^ tier
	t.Gems = d.Gems + m.Gems * tier
	t.Gold = d.Gold + m.Gold * tier
	return t
end


-------------------------------------------------------------------------------
-- Modes: the normal 10 waves, Endless, or a challenge with a twist
-------------------------------------------------------------------------------
Config.Modes = {
	{ Id = "Campaign", Name = "Campaign", Text = "10 waves and a boss" },
	{ Id = "Endless", Name = "Endless", Text = "Waves never stop. How far can you get? Best wave goes on the leaderboard" },
	{ Id = "RangersOnly", Name = "Challenge: Rangers Only", Text = "You can only build Rangers", Challenge = true },
	{ Id = "Pacifist", Name = "Challenge: Hands Off", Text = "Your hero can't attack. Defenders only", Challenge = true },
	{ Id = "GlassPortal", Name = "Challenge: Glass Portal", Text = "The portal has only 10 health", Challenge = true, PortalHealth = 10 },
	{ Id = "BossRush", Name = "Boss Rush", Text = "Bosses back to back. Win for a big chest (Epic or better)", BossRush = true,
		Waves = {
			{ Title = "The King returns", { Enemy = "GoblinKing", Count = 1, Gap = 1 }, { Enemy = "Brute", Count = 4, Gap = 1.5 } },
			{ Title = "Rock and roll", { Enemy = "MoltenGolem", Count = 1, Gap = 1 }, { Enemy = "ObsidianKnight", Count = 4, Gap = 1.5 } },
			{ Title = "Double trouble", { Enemy = "GoblinKing", Count = 2, Gap = 6 } },
			{ Title = "Hot rocks", { Enemy = "MoltenGolem", Count = 2, Gap = 6 }, { Enemy = "EmberImp", Count = 15, Gap = 0.4 } },
			{ Title = "FINAL: everybody, all at once", { Enemy = "GoblinKing", Count = 2, Gap = 3 }, { Enemy = "MoltenGolem", Count = 2, Gap = 3 } },
		} },
}
Config.ChallengeReward = { Gems = 60, MinRarity = 4 } -- first clear of each challenge on each map: gems + an Epic or better item
Config.EndlessBossEvery = 10

-------------------------------------------------------------------------------
-- Daily quests: 3 new ones every day (UTC midnight)
-------------------------------------------------------------------------------
Config.Quests = {
	{ Id = "Kills", Text = "Defeat %d enemies", Goal = 250, Gold = 200, Gems = 10 },
	{ Id = "Waves", Text = "Clear %d waves", Goal = 15, Gold = 200, Gems = 10 },
	{ Id = "Win", Text = "Win %d run", Goal = 1, Gold = 300, Gems = 15 },
	{ Id = "WinHard", Text = "Win %d run on Hard or Insane", Goal = 1, Gold = 500, Gems = 25 },
	{ Id = "Build", Text = "Build %d defenders", Goal = 20, Gold = 150, Gems = 8 },
	{ Id = "Loot", Text = "Pick up %d items", Goal = 4, Gold = 200, Gems = 10 },
	{ Id = "Upgrade", Text = "Upgrade gear %d times", Goal = 3, Gold = 150, Gems = 10 },
	{ Id = "Boss", Text = "Defeat %d boss", Goal = 1, Gold = 300, Gems = 15 },
	{ Id = "Abilities", Text = "Use hero abilities %d times", Goal = 60, Gold = 150, Gems = 8 },
	{ Id = "LootGoblin", Text = "Catch %d Loot Goblins", Goal = 2, Gold = 250, Gems = 12 },
}
Config.QuestsPerDay = 3

-- codes players can type in the shop (Codes tab). Each works once per player.
-- Put a new one in every update note!
Config.Codes = {
	RELEASE = { Gems = 50, Text = "+50 gems" },
	GOBLINMODE = { Gold = 500, Text = "+500 gold" },
	BAGUETTE = { Gems = 25, Gold = 250, Text = "+25 gems and 250 gold" },
}

-------------------------------------------------------------------------------
-- Pets: hatch from eggs bought with gold (gold can't be bought, only earned).
-- Bonus is a percent that grows 10% per pet level. Evolving doubles it.
-------------------------------------------------------------------------------
-- Rarity 1-6 = Common, Uncommon, Rare, Epic, Legendary, Mythic (Items.Rarities). The Legendary and Mythic pets
-- are the ones to chase: dragons, a unicorn and a phoenix, with tiny chances (Lemp 2026-11-19: "make them ultra
-- rares so people want to farm them"). Picture = art/icons/pet_*.png.
Config.Pets = {
	Slimey = { Name = "Slimey", Rarity = 1, Stat = "GoldFind", Bonus = 5, Color = Color3.fromRGB(110, 220, 110), Shape = "Blob" },
	Leafling = { Name = "Leafling", Rarity = 1, Stat = "Power", Bonus = 3, MoveSlow = true, Color = Color3.fromRGB(90, 170, 70), Shape = "Sprout" },
	Stonepup = { Name = "Stonepup", Rarity = 2, Stat = "Command", Bonus = 4, Color = Color3.fromRGB(140, 130, 120), Shape = "Pup" },
	MossKitten = { Name = "Moss Kitten", Rarity = 2, Stat = "Crit", Bonus = 2, Color = Color3.fromRGB(150, 200, 120), Shape = "Pup" },
	Glowbug = { Name = "Glowbug", Rarity = 3, Stat = "Crit", Bonus = 3, Color = Color3.fromRGB(255, 240, 120), Shape = "Bug" },
	EmberFox = { Name = "Ember Fox", Rarity = 3, Stat = "Engineering", Bonus = 5, Color = Color3.fromRGB(255, 120, 40), Shape = "Pup" },
	CrystalOwl = { Name = "Crystal Owl", Rarity = 3, Stat = "Command", Bonus = 6, Color = Color3.fromRGB(150, 210, 255), Shape = "Bug" },
	MiniGolem = { Name = "Mini Golem", Rarity = 4, Stat = "Command", Bonus = 8, Color = Color3.fromRGB(100, 70, 60), Shape = "Golem" },
	BabyDragon = { Name = "Baby Dragon", Rarity = 5, Stat = "Power", Bonus = 9, MoveBurn = true, Color = Color3.fromRGB(170, 60, 220), Shape = "Dragon" },
	StarUnicorn = { Name = "Star Unicorn", Rarity = 5, Stat = "GoldFind", Bonus = 16, Color = Color3.fromRGB(255, 235, 250), Shape = "Pup" },
	Phoenix = { Name = "Sunfire Phoenix", Rarity = 6, Stat = "Power", Bonus = 14, MoveBurn = true, Color = Color3.fromRGB(255, 150, 40), Shape = "Dragon" },
	VoidDrake = { Name = "Void Drake", Rarity = 6, Stat = "Command", Bonus = 14, Color = Color3.fromRGB(70, 40, 130), Shape = "Dragon" },
}
-- the chances are shown in the game before buying (with a picture of every pet)
Config.Eggs = {
	{ Id = "ForestEgg", Name = "Forest Egg", Price = 600, Color = Color3.fromRGB(120, 200, 100),
		Chances = { { "Slimey", 38 }, { "Leafling", 33 }, { "Stonepup", 14 }, { "MossKitten", 8 }, { "Glowbug", 5 },
			{ "MiniGolem", 1.7 }, { "BabyDragon", 0.25 }, { "StarUnicorn", 0.05 } } },
	{ Id = "MagmaEgg", Name = "Magma Egg", Price = 1500, Color = Color3.fromRGB(255, 110, 40),
		Chances = { { "Stonepup", 40 }, { "EmberFox", 34 }, { "Glowbug", 15 }, { "MiniGolem", 8.8 }, { "BabyDragon", 2 },
			{ "Phoenix", 0.2 } } },
	{ Id = "CrystalEgg", Name = "Crystal Egg", Price = 4000, Color = Color3.fromRGB(150, 210, 255),
		Chances = { { "MossKitten", 40 }, { "CrystalOwl", 36 }, { "MiniGolem", 18 }, { "BabyDragon", 4.6 },
			{ "StarUnicorn", 1 }, { "VoidDrake", 0.4 } } },
}
Config.PetMaxLevel = 10
Config.PetXpPerLevel = 60 -- pet xp per level (pets get 1 xp per enemy defeated)
Config.PetEvolveGold = 2500
Config.PetBagSize = 30
Config.PetReleaseGold = { 50, 80, 150, 400, 1000, 4000 }

-- Pet team: up to three pets walk with the hero. Slot 2 and 3 open with the level of your best hero.
-- The first pet is the LEAD: full bonus, and it does its move in a fight. Helpers give half their bonus.
-- Every pet of the team fetches loot (Config.PetCarry) and learns from kills.
Config.PetTeamLevels = { 1, 10, 25 }
Config.PetHelperBonus = 0.5

-- Pet Index: the first time you hatch each kind of pet pays a reward, by its rarity. Milestones pay extra.
Config.PetIndexGold = { 100, 200, 500, 1500, 5000, 15000 }
Config.PetIndexGems = { 5, 10, 20, 40, 100, 250 }
Config.PetIndexMilestones = { { At = 4, Gold = 500 }, { At = 8, Gold = 2500 }, { At = 12, Gold = 12000, Gems = 300 } }

-- What the equipped pet does in a fight, picked by its bonus stat (server: PetMoves.luau, looks: PetFollow.client.luau).
-- 6A: rare and small, no button needed. Every = seconds between moves (game time). Numbers grow 10% per pet level
-- and x1.5 when evolved; evolved pets also move a third more often. Damage scales like the hero's own hits.
Config.PetMoves = {
	Power = { Name = "Pounce", Text = "Pounces on nearby enemies", Every = 5, Range = 22, Damage = 10 },
	Command = { Name = "Rally", Text = "Boosts a nearby defender's damage", Every = 8, Range = 30, Boost = 0.15, Time = 4 },
	Engineering = { Name = "Spark", Text = "Makes a nearby defender shoot faster", Every = 8, Range = 30, Speed = 0.2, Time = 4 },
	Crit = { Name = "Mark", Text = "Marks an enemy for a sure crit", Every = 6, Range = 26 },
	GoldFind = { Name = "Dig", Text = "Digs up mana for the team", Every = 20, Mana = 4 },
}
Config.PetEvolvedEvery = 0.75 -- evolved pets wait only 75% as long between moves

-- Every pet also fetches loot from the ground: it trots over, grabs it and brings it to its hero.
-- By pet rarity (1 Common ... 6 Mythic). A pet in Config.Pets can override any of these with its own `Carry = { ... }`.
--   Gems          picks up gems
--   MaxItemRarity the best gear rarity it may pick up (6 = everything); better gear you fetch yourself
--   Range         how far from the hero it looks (studs)
--   Speed         how fast it trots there and back (studs per second)
--   Carry         drops per trip (lying close together)
--   Rest          seconds between trips
-- Evolved pets: 25% faster, one more per trip, rest 25% shorter.
-- The Auto Collect pass (Lemp 2026-11-23: "pets fetch twice as fast, from the whole map"): Config.PetCarryPass.
-- It sells time, not loot: the same drops, only sooner. (An owner without any pet gets the loot at once, as before.)
Config.PetCarryPass = { Speed = 2, Rest = 0.5, Range = 2000 }
Config.PetCarry = {
	{ Gems = true, MaxItemRarity = 2, Range = 18, Speed = 8, Carry = 1, Rest = 3 },
	{ Gems = true, MaxItemRarity = 3, Range = 22, Speed = 9, Carry = 1, Rest = 2.6 },
	{ Gems = true, MaxItemRarity = 4, Range = 26, Speed = 11, Carry = 2, Rest = 2.2 },
	{ Gems = true, MaxItemRarity = 5, Range = 30, Speed = 13, Carry = 2, Rest = 1.8 },
	{ Gems = true, MaxItemRarity = 6, Range = 36, Speed = 15, Carry = 3, Rest = 1.4 },
	{ Gems = true, MaxItemRarity = 6, Range = 44, Speed = 18, Carry = 4, Rest = 1 },
}
function Config.PetCarryOf(kind, evolved, pass)
	local info = Config.Pets[kind]
	if not info then
		return nil
	end
	local carry = table.clone(Config.PetCarry[info.Rarity] or Config.PetCarry[1])
	for k, v in info.Carry or {} do
		carry[k] = v
	end
	if evolved then
		carry.Speed *= 1.25
		carry.Carry += 1
		carry.Rest *= 0.75
	end
	if pass then
		carry.Speed *= Config.PetCarryPass.Speed
		carry.Rest *= Config.PetCarryPass.Rest
		carry.Range = Config.PetCarryPass.Range
		carry.Pass = true
	end
	return carry
end

-------------------------------------------------------------------------------
-- Rebirth and Ascension (for heroes at the level cap)
-------------------------------------------------------------------------------
Config.RebirthBonus = 10 -- +10% xp and gold per rebirth, forever
Config.AscensionXp = 2500 -- xp for one Ascension Point after the level cap
Config.AscensionPerks = {
	{ Id = "Power", Name = "Hero damage", Per = 1 },
	{ Id = "Command", Name = "Defender damage", Per = 1 },
	{ Id = "GoldFind", Name = "Gold find", Per = 2 },
	{ Id = "Crit", Name = "Crit chance", Per = 0.5 },
}

-------------------------------------------------------------------------------
-- Enemies (the Goblin tribe)
-- Gems = how many gems it drops (gems are saved and buy things in the shop)
-- GemChance = chance it drops them at all
-------------------------------------------------------------------------------
Config.Enemies = {
	Goblin = {
		DisplayName = "Goblin",
		Health = 30, Speed = 9, Damage = 1, Gold = 4, Xp = 2, Gems = 1, GemChance = 0.03,
		Color = Color3.fromRGB(90, 160, 60), Size = 3,
	},
	-- the first-wave rescue (RescueService): slips out past the first Ranger's reach, too tough for one Ranger,
	-- slow enough for a hero to catch. Caught: a handful of gems. Missed: a small, recoverable hit on the portal.
	Sneak = {
		DisplayName = "Goblin Sneak", Rescue = true, DropChance = 0.25,
		Health = 60, Speed = 12, Damage = 8, Gold = 15, Xp = 12, Gems = 5, GemChance = 1,
		Color = Color3.fromRGB(230, 150, 60), Size = 2.5,
	},
	Runner = {
		DisplayName = "Goblin Speedrunner",
		Health = 18, Speed = 16, Damage = 1, Gold = 3, Xp = 2, Gems = 1, GemChance = 0.03,
		Color = Color3.fromRGB(190, 200, 70), Size = 2.4,
	},
	Brute = {
		DisplayName = "Absolute Unit",
		Health = 160, Speed = 6, Damage = 5, Gold = 15, Xp = 8, Gems = 2, GemChance = 0.35,
		Color = Color3.fromRGB(50, 100, 40), Size = 4.5,
	},
	LootGoblin = {
		DisplayName = "Loot Goblin",
		Health = 70, Speed = 13, Damage = 0, Gold = 60, Xp = 10, Gems = 12, GemChance = 1,
		Color = Color3.fromRGB(255, 200, 50), Size = 2.6, Loot = true,
	},
	-- Magma Fortress
	EmberImp = {
		DisplayName = "Ember Imp", Look = "Imp", FireImmune = true, DropChance = 0.018,
		Health = 22, Speed = 15, Damage = 1, Gold = 4, Xp = 2, Gems = 1, GemChance = 0.03,
		Color = Color3.fromRGB(255, 120, 40), Size = 2.4,
	},
	ObsidianKnight = {
		DisplayName = "Obsidian Knight", Look = "Knight", Armor = 6, DropChance = 0.08,
		Health = 120, Speed = 6.5, Damage = 4, Gold = 14, Xp = 7, Gems = 2, GemChance = 0.3,
		Color = Color3.fromRGB(70, 62, 85), Size = 4,
	},
	MagmaSlime = {
		DisplayName = "Magma Slime", Look = "Slime", FireImmune = true, SplitInto = "SlimeBit", SplitCount = 2, DropChance = 0.03,
		Health = 70, Speed = 8, Damage = 2, Gold = 8, Xp = 4, Gems = 1, GemChance = 0.08,
		Color = Color3.fromRGB(255, 90, 30), Size = 3.5,
	},
	SlimeBit = {
		DisplayName = "Slime Bit", Look = "Slime", FireImmune = true, DropChance = 0,
		Health = 20, Speed = 11, Damage = 1, Gold = 2, Xp = 1,
		Color = Color3.fromRGB(255, 140, 60), Size = 1.8,
	},
	MoltenGolem = {
		DisplayName = "Molten Golem", Look = "Golem", Model = "boss_molten_golem", Armor = 10, FireImmune = true, DropChance = 0,
		Health = 3000, Speed = 3.5, Damage = 100, Gold = 300, Xp = 140, Gems = 50, GemChance = 1,
		Color = Color3.fromRGB(90, 50, 40), Size = 8, Boss = true,
	},
	-- Crystal Caves: shadow creatures
	Gloomling = {
		DisplayName = "Gloomling", Look = "Shade", DropChance = 0.01,
		Health = 12, Speed = 13, Damage = 1, Gold = 2, Xp = 1, Gems = 1, GemChance = 0.02,
		Color = Color3.fromRGB(70, 50, 110), Size = 1.8,
	},
	Shade = {
		DisplayName = "Shade", Look = "Shade", Blink = { Every = 4, Distance = 14 }, DropChance = 0.03,
		Health = 45, Speed = 8, Damage = 2, Gold = 6, Xp = 3, Gems = 1, GemChance = 0.06,
		Color = Color3.fromRGB(40, 30, 70), Size = 3,
	},
	CrystalBrute = {
		DisplayName = "Crystal Brute", Look = "Golem", Armor = 5, DropChance = 0.08,
		Health = 150, Speed = 6, Damage = 4, Gold = 14, Xp = 7, Gems = 2, GemChance = 0.3,
		Color = Color3.fromRGB(120, 200, 230), Size = 4.2,
	},
	ShadowQueen = {
		DisplayName = "Shadow Queen", Look = "Shade", Model = "boss_shadow_queen", Boss = true, DropChance = 0,
		Blink = { Every = 6, Distance = 18 }, Summon = { Every = 7, Enemy = "Gloomling", Count = 4 },
		Health = 2800, Speed = 4.5, Damage = 100, Gold = 300, Xp = 150, Gems = 55, GemChance = 1,
		Color = Color3.fromRGB(120, 40, 160), Size = 6.5,
	},
	-- the Outpost's training knight (EnemyService.SpawnDummy): armored like an Obsidian Knight, stands still, never
	-- falls. Hit it to see what a weapon does (the King's Cleaver cracks its armor) before the next run.
	TrainingKnight = {
		DisplayName = "Training Knight", Look = "Knight", Dummy = true, Armor = 6, DropChance = 0,
		Health = 400, Speed = 0, Damage = 0, Gold = 0, Xp = 0,
		Color = Color3.fromRGB(190, 160, 110), Size = 3.6,
	},
	GoblinKing = {
		DisplayName = "Goblin King", Model = "boss_goblin_king", -- its own image-to-3D model (art/ref3d)
		-- two jobs (BossService): every Every seconds (First after he appears) he winds up a charge at the nearest
		-- defender within Range. BreakHits hero hits during the Windup break it: he staggers back Knock studs and takes
		-- Weak x damage for WeakTime seconds. Unanswered, the charge jams that defender for Stun seconds.
		Charge = { First = 7, Every = 14, Windup = 6, Range = 45, BreakHits = 3, Knock = 6, Weak = 1.5, WeakTime = 3.5, Stun = 6 },
		Health = 2600, Speed = 4, Damage = 100, Gold = 250, Xp = 100, Gems = 40, GemChance = 1,
		Color = Color3.fromRGB(120, 60, 140), Size = 7, Boss = true,
	},
}

-------------------------------------------------------------------------------
-- Waves: each wave is a list of groups that come one after another.
-- Count = how many, Gap = seconds between each one.
-------------------------------------------------------------------------------
-- Delay = seconds before the group starts; StartCorner = the group appears at that corner of the path, not the start.
local ForestWaves = {
	-- the first-wave rescue: slow goblins the first Ranger can watch and shoot, then a Sneak that comes out of the
	-- woods past the keep hill (corner 5) and runs for the portal, then a few more slow ones
	{ Title = "The tutorial nobody asked for",
		{ Enemy = "Goblin", Count = 5, Gap = 1.6 }, { Enemy = "Sneak", Count = 1, Gap = 1, Delay = 6, StartCorner = 5 },
		{ Enemy = "Goblin", Count = 3, Gap = 1.6 } },
	{ Title = "They brought friends",
		{ Enemy = "Goblin", Count = 14, Gap = 0.9 } },
	{ Title = "Any% portal speedrun",
		{ Enemy = "Goblin", Count = 10, Gap = 0.9 }, { Enemy = "Runner", Count = 6, Gap = 0.6 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 } },
	{ Title = "Chonky boys incoming",
		{ Enemy = "Goblin", Count = 15, Gap = 0.8 }, { Enemy = "Brute", Count = 2, Gap = 3 } },
	{ Title = "Gotta go fast",
		{ Enemy = "Runner", Count = 14, Gap = 0.45 }, { Enemy = "Goblin", Count = 10, Gap = 0.8 } },
	{ Title = "Goblin mode: activated",
		{ Enemy = "Goblin", Count = 20, Gap = 0.6 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 }, { Enemy = "Brute", Count = 4, Gap = 2.5 } },
	{ Title = "The group chat got leaked",
		{ Enemy = "Runner", Count = 16, Gap = 0.4 }, { Enemy = "Goblin", Count = 16, Gap = 0.5 }, { Enemy = "Brute", Count = 3, Gap = 2 } },
	{ Title = "Gym day for goblins",
		{ Enemy = "Brute", Count = 8, Gap = 2 }, { Enemy = "Goblin", Count = 20, Gap = 0.5 } },
	{ Title = "The goblins have unionized",
		{ Enemy = "Goblin", Count = 25, Gap = 0.4 }, { Enemy = "Runner", Count = 15, Gap = 0.35 }, { Enemy = "LootGoblin", Count = 2, Gap = 1 }, { Enemy = "Brute", Count = 6, Gap = 1.5 } },
	{ Title = "FINAL BOSS: the Goblin King",
		{ Enemy = "Goblin", Count = 10, Gap = 0.5 }, { Enemy = "GoblinKing", Count = 1, Gap = 2 }, { Enemy = "Brute", Count = 5, Gap = 1.5 } },
}

local MagmaWaves = {
	{ Title = "Spicy start",
		{ Enemy = "EmberImp", Count = 10, Gap = 1 } },
	{ Title = "Slime time",
		{ Enemy = "EmberImp", Count = 12, Gap = 0.8 }, { Enemy = "MagmaSlime", Count = 3, Gap = 2 } },
	{ Title = "Knights in shiny armor (not shiny)",
		{ Enemy = "ObsidianKnight", Count = 3, Gap = 3 }, { Enemy = "EmberImp", Count = 12, Gap = 0.7 } },
	{ Title = "The floor is lava. For real",
		{ Enemy = "MagmaSlime", Count = 8, Gap = 1.5 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 } },
	{ Title = "Somebody turn on the AC",
		{ Enemy = "EmberImp", Count = 20, Gap = 0.4 }, { Enemy = "ObsidianKnight", Count = 4, Gap = 2.5 } },
	{ Title = "Heavy metal",
		{ Enemy = "MagmaSlime", Count = 10, Gap = 1.2 }, { Enemy = "ObsidianKnight", Count = 5, Gap = 2 } },
	{ Title = "Lava lamp party",
		{ Enemy = "EmberImp", Count = 25, Gap = 0.35 }, { Enemy = "MagmaSlime", Count = 6, Gap = 1.2 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 } },
	{ Title = "Tin can army",
		{ Enemy = "ObsidianKnight", Count = 10, Gap = 1.6 }, { Enemy = "EmberImp", Count = 15, Gap = 0.5 } },
	{ Title = "Hot take incoming",
		{ Enemy = "MagmaSlime", Count = 14, Gap = 0.9 }, { Enemy = "ObsidianKnight", Count = 8, Gap = 1.4 }, { Enemy = "EmberImp", Count = 20, Gap = 0.35 } },
	{ Title = "FINAL BOSS: the Molten Golem",
		{ Enemy = "EmberImp", Count = 12, Gap = 0.5 }, { Enemy = "MoltenGolem", Count = 1, Gap = 2 }, { Enemy = "ObsidianKnight", Count = 6, Gap = 1.5 } },
}

local CaveWaves = {
	{ Title = "Something is in the dark", { Enemy = "Gloomling", Count = 20, Gap = 0.5 } },
	{ Title = "Now you see me", { Enemy = "Shade", Count = 8, Gap = 1.2 }, { Enemy = "Gloomling", Count = 15, Gap = 0.4 } },
	{ Title = "Crystal clear threat", { Enemy = "CrystalBrute", Count = 3, Gap = 3 }, { Enemy = "Gloomling", Count = 25, Gap = 0.35 } },
	{ Title = "Who turned off the lights", { Enemy = "Shade", Count = 14, Gap = 0.9 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 } },
	{ Title = "Swarm season", { Enemy = "Gloomling", Count = 50, Gap = 0.2 } },
	{ Title = "Rock solid", { Enemy = "CrystalBrute", Count = 7, Gap = 2 }, { Enemy = "Shade", Count = 10, Gap = 0.8 } },
	{ Title = "Teleport spam", { Enemy = "Shade", Count = 22, Gap = 0.6 }, { Enemy = "Gloomling", Count = 25, Gap = 0.25 } },
	{ Title = "Crystal crowd", { Enemy = "CrystalBrute", Count = 10, Gap = 1.4 }, { Enemy = "LootGoblin", Count = 1, Gap = 1 } },
	{ Title = "Everything, everywhere", { Enemy = "Gloomling", Count = 60, Gap = 0.15 }, { Enemy = "Shade", Count = 16, Gap = 0.6 },
		{ Enemy = "CrystalBrute", Count = 6, Gap = 1.2 } },
	{ Title = "FINAL BOSS: the Shadow Queen", { Enemy = "Shade", Count = 10, Gap = 0.6 }, { Enemy = "ShadowQueen", Count = 1, Gap = 2 },
		{ Enemy = "CrystalBrute", Count = 5, Gap = 1.5 } },
}

-------------------------------------------------------------------------------
-- Maps. Each has its own path, waves, look and spawn point.
-- Health / Gems / ItemLevel make harder maps more rewarding.
-------------------------------------------------------------------------------
Config.Maps = {
	CursedForest = {
		Name = "Cursed Forest", Description = "Goblins. Lots of goblins. The starter map",
		Theme = "Forest", Path = ForestPath, Waves = ForestWaves, SpawnPoint = Vector3.new(-6, 0, -12),
		Health = 1, Gems = 1, ItemLevel = 0, Color = Color3.fromRGB(90, 160, 60),
	},
	MagmaFortress = {
		Name = "Magma Fortress", Description = "Fire-proof imps, armored knights, slimes that split. Bring a Ballista",
		Theme = "Magma",
		Path = {
			Vector3.new(-100, 0, 60), Vector3.new(-60, 0, 60), Vector3.new(-60, 0, -50), Vector3.new(-10, 0, -50),
			Vector3.new(-10, 0, 40), Vector3.new(40, 0, 40), Vector3.new(40, 0, -60), Vector3.new(80, 0, -60),
			Vector3.new(80, 0, 20), Vector3.new(100, 0, 20),
		},
		Waves = MagmaWaves, SpawnPoint = Vector3.new(15, 0, -5),
		Health = 1.25, Gems = 1.4, ItemLevel = 6, Color = Color3.fromRGB(255, 110, 40),
	},
}
Config.Maps.CrystalCaves = {
	Name = "Crystal Caves", Description = "Tight tunnels, swarms and shadows that teleport. Area damage wins here",
	Theme = "Crystal",
	Path = {
		Vector3.new(-105, 0, -70), Vector3.new(-105, 0, 60), Vector3.new(-65, 0, 60), Vector3.new(-65, 0, -60),
		Vector3.new(-25, 0, -60), Vector3.new(-25, 0, 60), Vector3.new(15, 0, 60), Vector3.new(15, 0, -60),
		Vector3.new(55, 0, -60), Vector3.new(55, 0, 40), Vector3.new(100, 0, 40),
	},
	Waves = CaveWaves, SpawnPoint = Vector3.new(80, 0, -20),
	Health = 1.35, Gems = 1.6, ItemLevel = 10, Color = Color3.fromRGB(130, 210, 255),
}
Config.MapOrder = { "CursedForest", "MagmaFortress", "CrystalCaves" }

-- switch every map-related setting to another map (server and screens both call this)
function Config.SetMap(mapId)
	local map = Config.Maps[mapId] or Config.Maps.CursedForest
	Config.CurrentMap = Config.Maps[mapId] and mapId or "CursedForest"
	Config.Path = map.Path
	Config.Waves = map.Waves
	Config.SpawnPoint = map.SpawnPoint
	return map
end

-------------------------------------------------------------------------------
-- Defenders. Levels[1] is what you get when you place it.
-- Cost on level 2 and 3 is the upgrade price.
-- UnlockGems = has to be bought once in the shop (with gems) before you can build it.
-------------------------------------------------------------------------------
Config.Towers = {
	Ranger = {
		DisplayName = "Ranger",
		Description = "Cheap, long range, hits one goblin",
		Cost = 60,
		Color = Color3.fromRGB(60, 140, 70),
		Levels = {
			{ Damage = 8, Range = 28, Cooldown = 0.8 },
			{ Cost = 70, Damage = 14, Range = 32, Cooldown = 0.7 },
			{ Cost = 130, Damage = 24, Range = 36, Cooldown = 0.55 },
		},
	},
	FlameCannon = {
		DisplayName = "Flame Cannon",
		Description = "Blasts groups, sets them on fire",
		Cost = 120,
		Color = Color3.fromRGB(200, 80, 30),
		Levels = {
			{ Damage = 10, Range = 20, Cooldown = 1.6, Radius = 7, BurnDps = 4, BurnTime = 3 },
			{ Cost = 110, Damage = 16, Range = 22, Cooldown = 1.4, Radius = 8, BurnDps = 7, BurnTime = 3 },
			{ Cost = 190, Damage = 26, Range = 24, Cooldown = 1.2, Radius = 10, BurnDps = 12, BurnTime = 4 },
		},
	},
	FrostCrystal = {
		DisplayName = "Frost Crystal",
		Description = "Slows every goblin near it",
		Cost = 90,
		Color = Color3.fromRGB(110, 190, 255),
		Levels = {
			{ Damage = 2, Range = 16, Cooldown = 1.0, Slow = 0.6, SlowTime = 1.5 },
			{ Cost = 80, Damage = 4, Range = 18, Cooldown = 0.9, Slow = 0.5, SlowTime = 1.8 },
			{ Cost = 150, Damage = 7, Range = 21, Cooldown = 0.8, Slow = 0.35, SlowTime = 2.2, FreezeChance = 0.12 },
		},
	},
	StormObelisk = {
		DisplayName = "Storm Obelisk",
		Description = "Lightning jumps between goblins",
		Cost = 160,
		UnlockGems = 60,
		Color = Color3.fromRGB(150, 120, 255),
		Levels = {
			{ Damage = 12, Range = 22, Cooldown = 1.3, Chains = 3 },
			{ Cost = 140, Damage = 18, Range = 24, Cooldown = 1.15, Chains = 4 },
			{ Cost = 240, Damage = 28, Range = 26, Cooldown = 1.0, Chains = 6 },
		},
	},
	Ballista = {
		DisplayName = "Ballista",
		Description = "Huge damage, slow. Boss killer",
		Cost = 200,
		UnlockGems = 100,
		Color = Color3.fromRGB(150, 110, 70),
		Levels = {
			{ Damage = 70, Range = 40, Cooldown = 3.0, BossBonus = 1.5 },
			{ Cost = 170, Damage = 120, Range = 44, Cooldown = 2.7, BossBonus = 1.75 },
			{ Cost = 300, Damage = 210, Range = 48, Cooldown = 2.4, BossBonus = 2 },
		},
	},
}
-- How a defender's shot moves (Lemp 2026-11-27: the shooting animations need polish; src/client/TowerLife.client.luau).
-- Three beats, all on the client with springs: a wind-up (seconds), the release in one frame, a recoil that settles
-- by spring. Projectiles fly at Speed (studs a second) on a slight arc (Arc of the distance); the server lands the
-- damage when the projectile arrives (wind-up + distance / Speed), so damage per second is unchanged.
Config.TowerShots = {
	-- (step 2: Codex saw no wind-up or recoil at phone size (2/10): a longer, deeper pull and a harder kick)
	Ballista = { WindUp = 0.2, Speed = 65,   -- (Speed 65: the bolt in flight for at least 4 frames at 20 fps)
				 Arc = 0.05, Pull = 0.7, Kick = 1.1, TurnSpeed = 70, TurnDamp = 14 },
}
-- Build Points: every defender uses some, each map has a limit for the whole team
Config.BuildLimit = 30
Config.BuildPoints = { Ranger = 2, FlameCannon = 3, FrostCrystal = 3, StormObelisk = 4, Ballista = 5 }
-- more players = tougher goblins (+35% health for each extra player)
Config.HealthPerExtraPlayer = 0.35

-- which painted icon belongs to which defender / hero (src/shared/Art.luau)
Config.TowerIcons = { Ranger = "tower_ranger", FlameCannon = "tower_flame", FrostCrystal = "tower_frost",
	StormObelisk = "tower_storm", Ballista = "tower_ballista" }
Config.HeroIcons = { Swordmaster = "hero_swordmaster", BeastHunter = "hero_hunter", RuneMage = "hero_mage",
	Engineer = "hero_engineer" }

Config.TowerOrder = { "Ranger", "FlameCannon", "FrostCrystal", "StormObelisk", "Ballista" }
Config.SellRefund = 0.7 -- you get back 70% of what you paid
-- Trying a build must never cost you (research report: "get the early investment back"): before the first wave,
-- and for RefundWindow seconds after placing or upgrading, selling gives back everything that was paid.
Config.RefundWindow = 10
Config.TowerSpacing = 6 -- defenders can't stand closer than this

-------------------------------------------------------------------------------
-- Hero: Swordmaster
-------------------------------------------------------------------------------
Config.Hero = {
	Name = "Swordmaster",
	Attack = { Damage = 12, Range = 10, Cooldown = 0.5 }, -- F
	Whirlwind = { Damage = 30, Radius = 14, Cooldown = 8 }, -- E
	Leap = { Damage = 45, Radius = 10, Distance = 30, Cooldown = 10 }, -- R
	DamagePerLevel = 0.15, -- +15% damage each level
	MaxLevel = 10,
	WalkSpeed = 20,
	GemPickupRange = 10,
}
-- hero levels are kept between games (one level and set of stat points per hero)
Config.HeroMaxLevel = 50
Config.DamagePerHeroLevel = 0.03 -- +3% hero damage for every level
function Config.XpForLevel(level)
	return 40 + level * 25
end

-- 1 stat point per level. What one point gives:
Config.StatPoints = {
	{ Id = "Power", Name = "Power", Per = 2, Text = "% hero damage" },
	{ Id = "Vitality", Name = "Vitality", Per = 10, Text = " hero health" },
	{ Id = "Command", Name = "Command", Per = 2, Text = "% defender damage" },
	{ Id = "Engineering", Name = "Engineering", Per = 1.5, Text = "% defender speed and range" },
}
Config.HeroBaseHealth = 100
Config.StatResetGoldPerLevel = 20
Config.FreeStatResetBelow = 10 -- resetting stat points is free until the hero reaches this level

-- the heroes. Abilities are on F, E and R.
Config.Heroes = {
	Swordmaster = {
		Name = "Swordmaster", Color = Color3.fromRGB(200, 220, 255),
		Role = "Close-range fighter, strong against bosses",
		Abilities = { F = "Sword", E = "Whirl", R = "Leap" },
		Help = "F: sword hit (depends on your weapon)  E: spin and hit everything around you  R: jump forward and slam",
	},
	RuneMage = {
		Name = "Rune Mage", Color = Color3.fromRGB(170, 120, 255),
		Role = "Area damage from range, slows groups",
		Abilities = { F = "Bolt", E = "Nova", R = "Meteor" },
		Help = "F: magic bolt at the closest goblin  E: frost nova that slows everything near you  R: meteor on the biggest group",
		Bolt = { Damage = 14, Range = 34, Cooldown = 0.6 },
		Nova = { Damage = 18, Radius = 18, Slow = 0.4, SlowTime = 3, Cooldown = 9 },
		Meteor = { Damage = 80, Radius = 12, Range = 50, Cooldown = 12 },
	},
	Engineer = {
		Name = "Machine Engineer", Color = Color3.fromRGB(255, 170, 60),
		UnlockWins = 1, UnlockText = "Win one run to unlock",
		Role = "Makes defenders stronger, builds turrets",
		Abilities = { F = "Wrench", E = "Overclock", R = "Turret" },
		Help = "F: wrench smack  E: defenders near you shoot 60% faster for 6s  R: build a mini turret for 20s",
		Wrench = { Damage = 10, Range = 9, Targets = 2, Cooldown = 0.55 },
		Overclock = { Radius = 26, Speed = 1.6, Time = 6, Cooldown = 14 },
		Turret = { Damage = 9, Range = 24, Cooldown = 0.4, Time = 20, AbilityCooldown = 18 },
	},
}
Config.Heroes.BeastHunter = {
	Name = "Beast Hunter", Color = Color3.fromRGB(150, 200, 90),
	Role = "Fast single-target damage, nets and a wolf friend",
	Abilities = { F = "Shot", E = "Net", R = "Wolf" },
	Help = "F: quick bow shot at the most dangerous goblin  E: net that holds a group in place  R: call a wolf that bites for 15s",
	Shot = { Damage = 11, Range = 38, Cooldown = 0.35 },
	Net = { Radius = 9, Range = 40, Time = 2.5, Cooldown = 10 },
	Wolf = { Damage = 16, Range = 14, Every = 0.6, Time = 15, Cooldown = 20 },
}
-- free from the start: one of each type (melee, ranged, mage). Others unlock by playing.
Config.HeroOrder = { "Swordmaster", "BeastHunter", "RuneMage", "Engineer" }

-- goblins hurt heroes that stand in their way (damage per second)
Config.ContactDamage = { Goblin = 6, Runner = 4, Brute = 18, LootGoblin = 0, GoblinKing = 45,
	EmberImp = 5, ObsidianKnight = 16, MagmaSlime = 8, SlimeBit = 3, MoltenGolem = 50,
	Gloomling = 3, Shade = 7, CrystalBrute = 15, ShadowQueen = 50 }

-------------------------------------------------------------------------------
-- Things to buy with gems. Gems are saved between games.
-------------------------------------------------------------------------------
Config.Swords = {
	{ Id = "Classic", Name = "Classic Blade", Price = 0, Color = Color3.fromRGB(200, 220, 255) },
	{ Id = "Gold", Name = "Drip Blade", Price = 50, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Toxic", Name = "Toxic Blade", Price = 80, Color = Color3.fromRGB(80, 255, 80) },
	{ Id = "Baguette", Name = "Le Baguette", Price = 120, Color = Color3.fromRGB(215, 160, 90), Baguette = true },
	{ Id = "Rainbow", Name = "RGB Gamer Blade", Price = 250, Color = Color3.fromRGB(255, 0, 255), Rainbow = true },
	{ Id = "Starforged", Name = "Starforged (Rebirth)", Price = 0, RebirthOnly = true, Color = Color3.fromRGB(255, 250, 200) },
}
Config.Titles = {
	{ Id = "None", Name = "No title", Price = 0 },
	{ Id = "Noob", Name = "Certified Noob", Price = 10 },
	{ Id = "Grass", Name = "Has Never Touched Grass", Price = 40 },
	{ Id = "Bonker", Name = "Professional Goblin Bonker", Price = 75 },
	{ Id = "Npc", Name = "Main Character Energy", Price = 120 },
	{ Id = "Legend", Name = "Portal Protector Supreme", Price = 300 },
	{ Id = "Uprising", Name = "Goblin Uprising Survivor", Price = 0, SeasonOnly = true },
}

-- daily reward: day 1, 2, 3 ... of your streak (after the last day it stays at the last one)
Config.DailyRewards = { 20, 30, 40, 50, 60, 80, 150 }
Config.DailyCooldownHours = 20 -- how long until you can claim again
Config.DailyStreakHours = 48 -- miss it longer than this and the streak resets

-- A loot hunt you can follow (research report, priority three): each boss shows the one reward it carries.
-- The first win against it gives that reward for sure. After that every boss kill fills a meter (Fill by
-- difficulty) and a full meter gives it again at your current item level, so a bad roll never wastes a run;
-- DropChance is the small extra surprise per kill. Item = an Items.WeaponTypes id (a unique weapon).
Config.BossRewards = {
	GoblinKing = { Item = "KingsCleaver", Rarity = 5, Stats = { "Power", "Command", "Crit" }, Meter = 8,
		Fill = { Easy = 1, Normal = 2, Hard = 3, Insane = 4, Mythic = 4 }, DropChance = 0.08 },
}

-- gold on top of the gems on some days of the streak (day 7 is the big one)
Config.DailyGold = { [3] = 300, [5] = 500, [7] = 1500 }

-- Reasons to come back (Lemp 2026-11-23: "increase the player return rate"). All of it is earned by playing.
Config.ComeBack = {
	-- the first win of each day (UTC): the run's gold is multiplied and a bonus chest (Rare or better) is added
	FirstWinGold = 2,
	-- while you are away your equipped pet digs up gold: per hour by pet rarity, +10% per pet level, x2 evolved.
	-- Counted from MinMinutes away, up to MaxHours, so a night's sleep fills it and a week away gives no more.
	AwayGoldPerHour = { 25, 35, 50, 80, 120, 180 },
	AwayMinMinutes = 30,
	AwayMaxHours = 10,
	-- the Rift map changes every Monday: gear drops this many times as often there
	RiftDrops = 2,
}
function Config.Today()
	return os.date("!%Y-%m-%d")
end
-- this week's Rift map (a different map each week, in Config.MapOrder)
function Config.RiftMap()
	local week = (os.time() - 4 * 86400) // (7 * 86400)
	return Config.MapOrder[week % #Config.MapOrder + 1]
end

-- gold (kept between games, spent on gear upgrades) at the end of a game
Config.GoldPerWave = 25
Config.GoldPerKill = 1

-- gems at the end of a game
Config.GemsPerWave = 3
Config.GemsForWin = 40

-------------------------------------------------------------------------------
-- Sounds. The rbxasset ones come with Roblox. You can swap in sounds from
-- the Creator Store later: "rbxassetid://123456".
-------------------------------------------------------------------------------
Config.Sounds = {
	Explosion = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.35 },
	GoblinDie = { Id = "rbxasset://sounds/oof.ogg", Volume = 0.35, Pitch = { 1.4, 1.9 } },
	BossDie = { Id = "rbxasset://sounds/oof.ogg", Volume = 1, Pitch = { 0.5, 0.5 } },
	PortalHit = { Id = "rbxasset://sounds/ouch.ogg", Volume = 0.6, Pitch = { 0.9, 1.1 } },
	Swing = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.5, Pitch = { 1.8, 2.2 } },
	Build = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.8, Pitch = { 0.8, 0.9 } },
	Frost = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.25, Pitch = { 1.6, 1.8 } },
	Zap = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.2, Pitch = { 2.5, 3 } },
	Click = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.5, Pitch = { 1, 1.1 } },
	Coin = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, Pitch = { 1.8, 2.1 } },
	Sneak = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.9, Pitch = { 1.7, 1.8 } }, -- quick feet
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = { 0.6, 0.7 } },
	-- pet moves (made from code: art/sounds/pet_sounds.py; played by PetFollow at the pet, quiet, a few times a minute)
	PetPounce = { Id = "rbxassetid://108573592683800", Volume = 0.45, Pitch = { 0.96, 1.04 } },
	PetRally = { Id = "rbxassetid://138761381729872", Volume = 0.3, Pitch = { 0.96, 1.04 } },
	PetMark = { Id = "rbxassetid://99606147842320", Volume = 0.3, Pitch = { 0.96, 1.04 } },
	PetSpark = { Id = "rbxassetid://107579833673360", Volume = 0.3, Pitch = { 0.96, 1.04 } },
	PetDig = { Id = "rbxassetid://73012526581803", Volume = 0.4, Pitch = { 0.96, 1.04 } },
}

-- how far a point is from the middle line of the path
function Config.DistanceToPath(pos)
	local best = math.huge
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local pts = Config.Path
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local t = math.clamp((flat - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		best = math.min(best, (flat - (a + (b - a) * t)).Magnitude)
	end
	return best
end

-------------------------------------------------------------------------------
-- Weekly event: one twist for every run, changes each week (Monday, UTC)
-------------------------------------------------------------------------------
Config.WeeklyEvents = {
	{ Id = "GoldRush", Name = "Goblin Gold Rush", Text = "+50% mana from every kill", Mana = 1.5 },
	{ Id = "Zoomies", Name = "Zoomies Week", Text = "Enemies are 25% faster, +30% gems", Speed = 1.25, Gems = 1.3 },
	{ Id = "Chonky", Name = "Chonky Week", Text = "Enemies have 40% more health, better loot", Health = 1.4, Luck = 1.6 },
	{ Id = "GlassCannons", Name = "Glass Cannons", Text = "Defenders deal +30% damage, the portal has 50 health",
		TowerDamage = 1.3, PortalHealth = 50 },
}
function Config.WeeklyEvent()
	-- weeks counted from a Monday so the event changes on Monday
	local week = (os.time() - 4 * 86400) // (7 * 86400)
	return Config.WeeklyEvents[week % #Config.WeeklyEvents + 1]
end

Config.SetMap("CursedForest")

function Config.FindById(list, id)
	for _, item in list do
		if item.Id == id then
			return item
		end
	end
	return nil
end

return Config
