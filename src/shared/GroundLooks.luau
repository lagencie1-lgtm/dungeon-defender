local M = Enum.Material

local GroundLooks = {}

-- Where defenders stand and enemies walk the base material must be smooth: Basalt, Slate, Rock, Ice and
-- CrackedLava have bumpy ground of their own (measured +-0.4 to +-1.1 studs on a flat fill), which sank defenders
-- and made most of Magma and Crystal unbuildable. Those floors use a smooth material with the same painting
-- (the *_flat variants); the rough ones stay for boulders, cliffs and walls.
GroundLooks.Themes = {
	Outpost = { [M.Grass] = "t_grass", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble", [M.Rock] = "t_moss_rock" },
	Forest = { [M.Grass] = "t_grass", [M.Mud] = "t_forest_dirt", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble", [M.Rock] = "t_moss_rock" },
	Magma = { [M.Sand] = "t_ash_flat", [M.Salt] = "basalt_flat", [M.Basalt] = "t_ash", [M.Cobblestone] = "t_cobble",
		[M.Rock] = "t_cliff", [M.Slate] = "basalt", [M.CrackedLava] = "lava_rock" },
	Crystal = { [M.Asphalt] = "t_cave_floor_flat", [M.Concrete] = "t_cave_wall_flat", [M.Slate] = "t_cave_floor",
		[M.Basalt] = "t_cave_wall", [M.Cobblestone] = "t_cobble" },
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
for _, name in { "t_ash", "basalt", "t_cave_floor", "t_cave_wall" } do
	GroundLooks.Colors[name .. "_flat"] = GroundLooks.Colors[name]
end

-- how far each painting's tint goes towards white (white shows the painting as painted). The meadow grass is lifted
-- more: from the run camera it was a dark green carpet on a phone (cycle 5 film).
GroundLooks.Lift = { t_grass = 0.55 }
function GroundLooks.Tint(texture)
	return GroundLooks.Colors[texture]:Lerp(Color3.new(1, 1, 1), GroundLooks.Lift[texture] or 0.15)
end

return GroundLooks
