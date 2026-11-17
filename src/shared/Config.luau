-- All the numbers for the game in one place, so they are easy to change.
local Config = {}

-- The Cursed Forest path. Goblins walk from the first point to the last one.
Config.Path = {
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
Config.SpawnPoint = Vector3.new(-10, 0, -20) -- where players appear

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
Config.Waves = {
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
function Config.XpForLevel(level)
	return 20 + level * 15
end

-------------------------------------------------------------------------------
-- Things to buy with gems. Gems are saved between games.
-------------------------------------------------------------------------------
Config.Swords = {
	{ Id = "Classic", Name = "Classic Blade", Price = 0, Color = Color3.fromRGB(200, 220, 255) },
	{ Id = "Gold", Name = "Drip Blade", Price = 50, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Toxic", Name = "Toxic Blade", Price = 80, Color = Color3.fromRGB(80, 255, 80) },
	{ Id = "Baguette", Name = "Le Baguette", Price = 120, Color = Color3.fromRGB(215, 160, 90), Baguette = true },
	{ Id = "Rainbow", Name = "RGB Gamer Blade", Price = 250, Color = Color3.fromRGB(255, 0, 255), Rainbow = true },
}
Config.Titles = {
	{ Id = "None", Name = "No title", Price = 0 },
	{ Id = "Noob", Name = "Certified Noob", Price = 10 },
	{ Id = "Grass", Name = "Has Never Touched Grass", Price = 40 },
	{ Id = "Bonker", Name = "Professional Goblin Bonker", Price = 75 },
	{ Id = "Npc", Name = "Main Character Energy", Price = 120 },
	{ Id = "Legend", Name = "Portal Protector Supreme", Price = 300 },
}

-- daily reward: day 1, 2, 3 ... of your streak (after the last day it stays at the last one)
Config.DailyRewards = { 20, 30, 40, 50, 60, 80, 150 }
Config.DailyCooldownHours = 20 -- how long until you can claim again
Config.DailyStreakHours = 48 -- miss it longer than this and the streak resets

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

function Config.FindById(list, id)
	for _, item in list do
		if item.Id == id then
			return item
		end
	end
	return nil
end

return Config
