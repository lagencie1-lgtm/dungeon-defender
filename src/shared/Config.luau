-- All the numbers for the game in one place, so they are easy to change.
local Config = {}

-- The Cursed Forest path. Goblins walk from the first point to the last one.
local ForestPath = {
	Vector3.new(-90, 0, -60), -- start (goblin camp)
	Vector3.new(-40, 0, -60),
	Vector3.new(-40, 0, 20),
	Vector3.new(20, 0, 20),
	Vector3.new(20, 0, -40),
	Vector3.new(70, 0, -40),
	Vector3.new(70, 0, 50),
	Vector3.new(95, 0, 50), -- the magic portal you defend
}
Config.PathWidth = 10
Config.MapSize = Vector2.new(240, 180) -- ground size (X, Z)
Config.OutpostCenter = Vector3.new(0, 0, -215) -- the hub, south of the battlefield

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
	{ Id = "Easy", Name = "Easy", Subtitle = "Just vibing", Health = 0.7, Gems = 0.6, Color = Color3.fromRGB(90, 200, 110) },
	{ Id = "Normal", Name = "Normal", Subtitle = "The intended experience", Health = 1, Gems = 1, Color = Color3.fromRGB(240, 190, 70) },
	{ Id = "Hard", Name = "Hard", Subtitle = "No cap, it's hard", Health = 1.5, Gems = 1.8, Color = Color3.fromRGB(230, 80, 80) },
	{ Id = "Nightmare", Name = "Nightmare", Subtitle = "Absolutely cooked", Health = 2.3, Gems = 2.8, Color = Color3.fromRGB(180, 60, 220) },
}

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
	{ Id = "WinHard", Text = "Win %d run on Hard or Nightmare", Goal = 1, Gold = 500, Gems = 25 },
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
Config.Pets = {
	Slimey = { Name = "Slimey", Rarity = 1, Stat = "GoldFind", Bonus = 5, Color = Color3.fromRGB(110, 220, 110), Shape = "Blob" },
	Leafling = { Name = "Leafling", Rarity = 1, Stat = "Power", Bonus = 3, Color = Color3.fromRGB(90, 170, 70), Shape = "Sprout" },
	Stonepup = { Name = "Stonepup", Rarity = 2, Stat = "Command", Bonus = 4, Color = Color3.fromRGB(140, 130, 120), Shape = "Pup" },
	Glowbug = { Name = "Glowbug", Rarity = 3, Stat = "Crit", Bonus = 3, Color = Color3.fromRGB(255, 240, 120), Shape = "Bug" },
	EmberFox = { Name = "Ember Fox", Rarity = 3, Stat = "Engineering", Bonus = 5, Color = Color3.fromRGB(255, 120, 40), Shape = "Pup" },
	MiniGolem = { Name = "Mini Golem", Rarity = 4, Stat = "Command", Bonus = 8, Color = Color3.fromRGB(100, 70, 60), Shape = "Golem" },
	BabyDragon = { Name = "Baby Dragon", Rarity = 5, Stat = "Power", Bonus = 9, Color = Color3.fromRGB(170, 60, 220), Shape = "Dragon" },
}
-- the chances are shown in the game before buying
Config.Eggs = {
	{ Id = "ForestEgg", Name = "Forest Egg", Price = 600, Color = Color3.fromRGB(120, 200, 100),
		Chances = { { "Slimey", 40 }, { "Leafling", 35 }, { "Stonepup", 17 }, { "Glowbug", 6 }, { "MiniGolem", 1.8 }, { "BabyDragon", 0.2 } } },
	{ Id = "MagmaEgg", Name = "Magma Egg", Price = 1500, Color = Color3.fromRGB(255, 110, 40),
		Chances = { { "Stonepup", 40 }, { "EmberFox", 35 }, { "Glowbug", 15 }, { "MiniGolem", 8 }, { "BabyDragon", 2 } } },
}
Config.PetMaxLevel = 10
Config.PetXpPerLevel = 60 -- pet xp per level (pets get 1 xp per enemy defeated)
Config.PetEvolveGold = 2500
Config.PetBagSize = 30
Config.PetReleaseGold = { 50, 80, 150, 400, 1000 }

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
		DisplayName = "Molten Golem", Look = "Golem", Armor = 10, FireImmune = true, DropChance = 0,
		Health = 3000, Speed = 3.5, Damage = 100, Gold = 300, Xp = 140, Gems = 50, GemChance = 1,
		Color = Color3.fromRGB(90, 50, 40), Size = 8, Boss = true,
	},
	GoblinKing = {
		DisplayName = "Goblin King",
		Health = 2600, Speed = 4, Damage = 100, Gold = 250, Xp = 100, Gems = 40, GemChance = 1,
		Color = Color3.fromRGB(120, 60, 140), Size = 7, Boss = true,
	},
}

-------------------------------------------------------------------------------
-- Waves: each wave is a list of groups that come one after another.
-- Count = how many, Gap = seconds between each one.
-------------------------------------------------------------------------------
local ForestWaves = {
	{ Title = "The tutorial nobody asked for",
		{ Enemy = "Goblin", Count = 8, Gap = 1.2 } },
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

-------------------------------------------------------------------------------
-- Maps. Each has its own path, waves, look and spawn point.
-- Health / Gems / ItemLevel make harder maps more rewarding.
-------------------------------------------------------------------------------
Config.Maps = {
	CursedForest = {
		Name = "Cursed Forest", Description = "Goblins. Lots of goblins. The starter map",
		Theme = "Forest", Path = ForestPath, Waves = ForestWaves, SpawnPoint = Vector3.new(-10, 0, -20),
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
Config.MapOrder = { "CursedForest", "MagmaFortress" }

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
-- Build Points: every defender uses some, each map has a limit for the whole team
Config.BuildLimit = 30
Config.BuildPoints = { Ranger = 2, FlameCannon = 3, FrostCrystal = 3, StormObelisk = 4, Ballista = 5 }
-- more players = tougher goblins (+35% health for each extra player)
Config.HealthPerExtraPlayer = 0.35

Config.TowerOrder = { "Ranger", "FlameCannon", "FrostCrystal", "StormObelisk", "Ballista" }
Config.SellRefund = 0.7 -- you get back 70% of what you paid
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
	EmberImp = 5, ObsidianKnight = 16, MagmaSlime = 8, SlimeBit = 3, MoltenGolem = 50 }

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
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = { 0.6, 0.7 } },
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
