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
Config.PortalHealth = 100

Config.Enemies = {
	Goblin = {
		Health = 20,
		Speed = 10, -- studs per second
		Damage = 1, -- portal health lost when it gets through
		Gold = 5, -- reward for killing it (used later)
		Color = Color3.fromRGB(90, 160, 60),
		Size = 3,
	},
}

-- A first test wave, until the real 10-wave list comes in a later step.
Config.TestWave = { Enemy = "Goblin", Count = 8, Gap = 1.2 }

return Config
