local M = Enum.Material

local GroundLooks = {}

GroundLooks.Themes = {
	Outpost = { [M.Grass] = "t_grass", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble", [M.Rock] = "t_moss_rock" },
	Forest = { [M.Grass] = "t_grass", [M.Mud] = "t_forest_dirt", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble", [M.Rock] = "t_moss_rock" },
	Magma = { [M.Basalt] = "t_ash", [M.Cobblestone] = "t_cobble", [M.Rock] = "t_cliff", [M.Slate] = "basalt", [M.CrackedLava] = "lava_rock" },
	Crystal = { [M.Slate] = "t_cave_floor", [M.Basalt] = "t_cave_wall", [M.Cobblestone] = "t_cobble" },
}

-- The terrain renderer can fall back to its tint at low graphics quality.
GroundLooks.Colors = {
	t_ash = Color3.fromRGB(119, 100, 92),
	t_ground = Color3.fromRGB(163, 94, 48),
	t_cobble = Color3.fromRGB(111, 88, 74),
	t_cliff = Color3.fromRGB(124, 55, 41),
	basalt = Color3.fromRGB(82, 49, 48),
	lava_rock = Color3.fromRGB(99, 40, 18),
	t_grass = Color3.fromRGB(80, 109, 41),
	t_forest_dirt = Color3.fromRGB(87, 45, 23),
	t_moss_rock = Color3.fromRGB(102, 103, 78),
	t_cave_floor = Color3.fromRGB(58, 67, 100),
	t_cave_wall = Color3.fromRGB(62, 52, 90),
}

return GroundLooks
