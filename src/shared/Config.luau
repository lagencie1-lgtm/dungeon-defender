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
Config.WaveHealthGrowth = 0.12 -- enemies get 12% more health each wave
Config.WaveBonusGold = 40 -- gold for clearing a wave

-------------------------------------------------------------------------------
-- Enemies (the Goblin tribe)
-------------------------------------------------------------------------------
Config.Enemies = {
	Goblin = {
		DisplayName = "Goblin",
		Health = 30, Speed = 9, Damage = 1, Gold = 4, Xp = 2,
		Color = Color3.fromRGB(90, 160, 60), Size = 3,
	},
	Runner = {
		DisplayName = "Goblin Runner",
		Health = 18, Speed = 16, Damage = 1, Gold = 3, Xp = 2,
		Color = Color3.fromRGB(190, 200, 70), Size = 2.4,
	},
	Brute = {
		DisplayName = "Goblin Brute",
		Health = 160, Speed = 6, Damage = 5, Gold = 15, Xp = 8,
		Color = Color3.fromRGB(50, 100, 40), Size = 4.5,
	},
	GoblinKing = {
		DisplayName = "Goblin King",
		Health = 2600, Speed = 4, Damage = 100, Gold = 250, Xp = 100,
		Color = Color3.fromRGB(120, 60, 140), Size = 7, Boss = true,
	},
}

-------------------------------------------------------------------------------
-- Waves: each wave is a list of groups that come one after another.
-- Count = how many, Gap = seconds between each one.
-------------------------------------------------------------------------------
Config.Waves = {
	{ { Enemy = "Goblin", Count = 8, Gap = 1.2 } },
	{ { Enemy = "Goblin", Count = 14, Gap = 0.9 } },
	{ { Enemy = "Goblin", Count = 10, Gap = 0.9 }, { Enemy = "Runner", Count = 6, Gap = 0.6 } },
	{ { Enemy = "Goblin", Count = 15, Gap = 0.8 }, { Enemy = "Brute", Count = 2, Gap = 3 } },
	{ { Enemy = "Runner", Count = 14, Gap = 0.45 }, { Enemy = "Goblin", Count = 10, Gap = 0.8 } },
	{ { Enemy = "Goblin", Count = 20, Gap = 0.6 }, { Enemy = "Brute", Count = 4, Gap = 2.5 } },
	{ { Enemy = "Runner", Count = 16, Gap = 0.4 }, { Enemy = "Goblin", Count = 16, Gap = 0.5 }, { Enemy = "Brute", Count = 3, Gap = 2 } },
	{ { Enemy = "Brute", Count = 8, Gap = 2 }, { Enemy = "Goblin", Count = 20, Gap = 0.5 } },
	{ { Enemy = "Goblin", Count = 25, Gap = 0.4 }, { Enemy = "Runner", Count = 15, Gap = 0.35 }, { Enemy = "Brute", Count = 6, Gap = 1.5 } },
	{ { Enemy = "Goblin", Count = 10, Gap = 0.5 }, { Enemy = "GoblinKing", Count = 1, Gap = 2 }, { Enemy = "Brute", Count = 5, Gap = 1.5 } },
}

-------------------------------------------------------------------------------
-- Defenders. Levels[1] is what you get when you place it.
-- Cost on level 2 and 3 is the upgrade price.
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
		Description = "Blasts groups and sets them on fire",
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
}
Config.TowerOrder = { "Ranger", "FlameCannon", "FrostCrystal" }
Config.SellRefund = 0.7 -- you get back 70% of what you paid
Config.TowerSpacing = 6 -- defenders can't stand closer than this

-------------------------------------------------------------------------------
-- Hero: Swordmaster
-------------------------------------------------------------------------------
Config.Hero = {
	Name = "Swordmaster",
	Attack = { Damage = 12, Range = 10, Cooldown = 0.5 }, -- F
	Whirlwind = { Damage = 30, Radius = 14, Cooldown = 8 }, -- E
	DamagePerLevel = 0.15, -- +15% damage each level
	MaxLevel = 10,
	WalkSpeed = 20,
}
function Config.XpForLevel(level)
	return 20 + level * 15
end

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

return Config
