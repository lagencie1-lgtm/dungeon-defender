-- The designed shape of each battlefield (2026-11-24, Lemp: "improve the map layouts ... obstacle courses, look at
-- Dungeon Defenders: much more obstacles and environment"). Their maps are never an open field: raised floors with
-- stairs, pits of lava the lanes cross on bridges, walls that leave a few good building spots at each chokepoint.
-- Here every map gets that as DATA, placed by hand for a reason (6A: a person leads the concept, nothing random):
--   Plateaus  raised, flat ground you can build on (high ground beside a lane); the lane climbs any it crosses.
--             Stone retaining walls stand on its straight edges (Walls = which sides, "NSEW" unless given; N is the
--             edge at Z0, S at Z1, W at X0, E at X1) so the height reads from above, with Stairs where a hero goes
--             up ({ Side, At = how far along that edge, 0..1 })
--   Channels  a river, a lava stream or a glowing canal: nothing builds there, the lane crosses on a bridge
--   Masses    solid rock or wood that fills the corners no lane uses, so the field is not a rectangle
--   Bridges   where a channel is crossed: a stone abutment with a plank deck and parapets (the lane's, or a hero's)
--   Kit       the building kit (art/blender/map_kit.py): ruined walls, low battlements, gate arches over the lane,
--             broken pillars and one set piece per map. `Look` is where the piece's front faces; a wall runs across it.
--   Pieces    other models standing on the field (rocks, stumps, the old props ...) with the room they block
-- TerrainBuilder shapes the ground from it, MapBuilder stands the pieces on it. Heights are "top at y" in studs;
-- flat ground is y = 0. Height rule: 4 studs (one terrain voxel) is exact for every material; 5 is fine on grass and
-- the ash floors, but the caves' smooth floor material swells to 6 at 5 (measured in the terrain lab). Camera rule: nothing raised inside the field is higher than 5 studs, because the run camera
-- sits 14 studs up and 15 back and a taller cliff behind the hero would push it in (phone first).
local MapLayouts = {}

local v = Vector3.new

MapLayouts.Forest = {
	Plateaus = {
		-- the old keep's hill inside the loop of the road: the hero starts on it and sees three lanes below
		{ Name = "Keep Hill", X0 = -14, X1 = 2, Z0 = -34, Z1 = 0, H = 4, Round = 5,
			Stairs = { { Side = "E", At = 0.8 }, { Side = "W", At = 0.2 } } },
		-- the Hollow Road: two wooded banks either side of the first stretch, so the goblins march in below you
		{ Name = "North Bank", X0 = -88, X1 = -40, Z0 = -76, Z1 = -54, H = 5, Round = 7, Walls = "S",
			Stairs = { { Side = "S", At = 0.25 } } },
		{ Name = "South Bank", X0 = -84, X1 = -42, Z0 = -34, Z1 = -14, H = 5, Round = 7, Walls = "N",
			Stairs = { { Side = "N", At = 0.75 } } },
		-- the portal stands on a rise: the last stretch climbs to it
		{ Name = "Portal Rise", X0 = 72, X1 = 116, Z0 = 26, Z1 = 58, H = 4, Round = 8, Walls = "NSE",
			Stairs = { { Side = "S", At = 0.3 } } },
	},
	Channels = {
		-- the Witchwater: comes down from the north, the road crosses it twice
		{ Name = "Witchwater", Width = 7, Points = { v(36, 0, -100), v(33, 0, -62), v(32, 0, -34), v(36, 0, -16), v(52, 0, -6),
			v(72, 0, 2), v(98, 0, -4), v(130, 0, 6) } },
	},
	Masses = {
		-- the south-west is deep wood on a rocky rise: no lane goes there
		{ At = v(-92, 0, 62), Radius = 26, H = 16 }, { At = v(-60, 0, 78), Radius = 20, H = 13 },
		{ At = v(-112, 0, 22), Radius = 16, H = 12 },
		-- the north-east corner behind the river
		{ At = v(100, 0, -70), Radius = 24, H = 15 }, { At = v(66, 0, -84), Radius = 14, H = 10 },
		-- north, between the banks and the river
		{ At = v(-6, 0, -84), Radius = 16, H = 11 },
		-- south-east below the rise
		{ At = v(20, 0, 82), Radius = 18, H = 12 },
	},
	Pieces = {
		-- the ruined watchtower stands on the south bank over the Hollow Road (the hill you start on stays free to build)
		{ Model = "keep_field_ruin", At = v(-74, 0, -23), Height = 7.5, Block = 6, Turn = 0.4 },
		-- the old well and a watchtower on the green between the last two lanes
		{ Model = "keep_well", At = v(40, 0, 30), Height = 6.5, Block = 3 },
		{ Model = "keep_watchtower", At = v(64, 0, 20), Height = 15, Block = 4, Turn = 2.2 },
		-- boulders at the feet of the banks and beside the fords
		{ Model = "keep_field_rock", At = v(-36, 0, -24), Height = 4.2, Block = 3.4, Turn = 1 },
		{ Model = "keep_field_rock", At = v(24, 0, -44), Height = 3.8, Block = 3.2, Turn = 2 },
		{ Model = "keep_field_rock", At = v(42, 0, -24), Height = 4.4, Block = 3.4, Turn = 4 },
		{ Model = "keep_field_rock", At = v(62, 0, -14), Height = 3.6, Block = 3.2, Turn = 5 },
		{ Model = "keep_field_rock", At = v(-34, 0, 22), Height = 4.6, Block = 3.6, Turn = 3 },
		{ Model = "keep_field_stump", At = v(-46, 0, 2), Height = 2.6, Block = 1.9, Turn = 1 },
		{ Model = "keep_field_stump", At = v(24, 0, 34), Height = 2.6, Block = 1.9, Turn = 2 },
		{ Model = "keep_field_bush", At = v(-30, 0, -62), Height = 3.2, Block = 3.2, Turn = 0 },
		{ Model = "keep_field_bush", At = v(2, 0, 22), Height = 3.2, Block = 3.2, Turn = 3 },
		{ Model = "keep_field_bush", At = v(64, 0, 56), Height = 3.2, Block = 3.2, Turn = 1 },
		{ Model = "keep_field_mushrooms", At = v(-20, 0, 24), Height = 2.2, Block = 1.2, Turn = 0 },
		{ Model = "keep_field_mushrooms", At = v(40, 0, 8), Height = 2.2, Block = 1.2, Turn = 2 },
	},
	Bridges = {
		{ At = v(32, 0, -34), Along = v(1, 0, 0) }, -- the first ford
		{ At = v(52, 0, -6), Along = v(0, 0, 1) }, -- the second ford
	},
	Kit = {
		-- two gates: where the Hollow Road opens into the field, and at the foot of the portal's rise
		{ Piece = "arch", At = v(-38, 0, -44), Look = v(1, 0, 0), Sink = 0.3 },
		{ Piece = "arch", At = v(64, 0, 42), Look = v(1, 0, 0), Sink = 0.9 },
		-- the chapel wall splits the green: defenders west of it guard one lane, east of it the other
		{ Piece = "wall", At = v(32, 0, 10), Look = v(1, 0, 0) },
		{ Piece = "pillar", At = v(32, 0, 22), Look = v(0, 0, 1) },
		-- an old wall on the north bank, looking down on the Hollow Road
		{ Piece = "wall", At = v(-64, 0, -61), Look = v(0, 0, 1) },
		-- the keep hill's battlements at its two ends (its long sides stay open for defenders)
		{ Piece = "low", At = v(-6, 0, -31), Look = v(0, 0, -1) },
		{ Piece = "low", At = v(-6, 0, -3), Look = v(0, 0, 1) },
		-- the rise's battlements either side of the last stretch, and two pillars behind the portal
		{ Piece = "low", At = v(86, 0, 31), Look = v(0, 0, -1) },
		{ Piece = "low", At = v(86, 0, 53), Look = v(0, 0, 1) },
		{ Piece = "pillar", At = v(109, 0, 33), Look = v(-1, 0, 0) },
		{ Piece = "pillar", At = v(109, 0, 51), Look = v(-1, 0, 0) },
		-- a milestone pillar on the outside of every turn (so you can call a place: "the second turn")
		{ Piece = "pillar", At = v(-14, 0, -54), Look = v(0, 0, 1) },
		{ Piece = "pillar", At = v(22, 0, 20), Look = v(-1, 0, 0) },
		{ Piece = "pillar", At = v(62, 0, -44), Look = v(-1, 0, 0) },
		{ Piece = "pillar", At = v(42, 0, 52), Look = v(0, 0, -1) },
		-- the standing stones south-west of the road
		{ Piece = "set", At = v(-48, 0, 22), Look = v(0.9, 0, -0.4) },
	},
	-- single trees inside the field, each placed (they block building: you can't stand a defender in a trunk)
	Trees = {
		v(-70, 0, -66), v(-52, 0, -68), v(-64, 0, -22), v(-50, 0, -24), v(-40, 0, 12), v(-56, 0, 26), v(-30, 0, 44),
		v(-6, 0, 30), v(18, 0, 50), v(22, 0, -60), v(-22, 0, -68), v(44, 0, -54), v(72, 0, -38), v(84, 0, 12),
		v(40, 0, 62), v(-102, 0, -20), v(-98, 0, -66),
	},
}

MapLayouts.Magma = {
	Plateaus = {
		-- three bastions of the old fortress: flat basalt floors a step above the ash
		{ Name = "West Bastion", X0 = -50, X1 = -20, Z0 = -40, Z1 = -28, H = 5, Stairs = { { Side = "N", At = 0.5 } } },
		{ Name = "Heart Bastion", X0 = 0, X1 = 30, Z0 = -12, Z1 = 30, H = 4,
			Stairs = { { Side = "W", At = 0.6 }, { Side = "E", At = 0.4 } } },
		{ Name = "East Bastion", X0 = 50, X1 = 70, Z0 = -50, Z1 = -30, H = 5, Stairs = { { Side = "W", At = 0.5 } } },
		{ Name = "Gate Yard", X0 = -50, X1 = -20, Z0 = 6, Z1 = 40, H = 4,
			Stairs = { { Side = "E", At = 0.5 }, { Side = "W", At = 0.5 } } },
		-- the portal's keep: the last stretch climbs to it
		{ Name = "Portal Keep", X0 = 90, X1 = 116, Z0 = 4, Z1 = 36, H = 4, Stairs = { { Side = "N", At = 0.3 } } },
	},
	Channels = {
		-- the lava river cuts the whole fortress in two: four bridges
		{ Name = "Lava River", Width = 11, Points = { v(-132, 0, -14), v(-85, 0, -10), v(-60, 0, -12), v(-35, 0, -18), v(-10, 0, -16),
			v(14, 0, -24), v(40, 0, -22), v(60, 0, -16), v(80, 0, -18), v(132, 0, -12) } },
	},
	Masses = {
		{ At = v(-100, 0, -60), Radius = 24, H = 18 }, { At = v(-104, 0, 16), Radius = 16, H = 13 },
		{ At = v(-20, 0, 80), Radius = 20, H = 14 }, { At = v(60, 0, 78), Radius = 22, H = 16 },
		{ At = v(110, 0, -62), Radius = 16, H = 14 }, { At = v(108, 0, 70), Radius = 16, H = 12 },
		{ At = v(12, 0, -84), Radius = 14, H = 11 },
	},
	Bridges = {
		{ At = v(-60, 0, -12), Along = v(0, 0, 1) }, { At = v(-10, 0, -16), Along = v(0, 0, 1) },
		{ At = v(40, 0, -22), Along = v(0, 0, 1) }, { At = v(80, 0, -18), Along = v(0, 0, 1) },
	},
	Kit = {
		-- the south gate under the heart bastion, and the gate of the portal's keep
		{ Piece = "arch", At = v(15, 0, 40), Look = v(1, 0, 0), Sink = 0.3 },
		{ Piece = "arch", At = v(88, 0, 20), Look = v(1, 0, 0), Sink = 0.9 },
		-- battlements on the river side of every bastion (the fortress held the lava river's line)
		{ Piece = "low", At = v(-35, 0, -30.5), Look = v(0, 0, 1) },
		{ Piece = "low", At = v(8, 0, -9.5), Look = v(0, 0, -1) },
		{ Piece = "low", At = v(60, 0, -32.5), Look = v(0, 0, 1) },
		{ Piece = "low", At = v(-35, 0, 8.5), Look = v(0, 0, -1) },
		-- what is left of the outer curtain wall, behind the lanes
		{ Piece = "wall", At = v(-82, 0, 44), Look = v(0, 0, 1) },
		{ Piece = "wall", At = v(60, 0, -76), Look = v(0, 0, 1) },
		{ Piece = "wall", At = v(98, 0, -36), Look = v(-1, 0, 0) },
		{ Piece = "wall", At = v(-78, 0, -32), Look = v(1, 0, 0) },
		-- pillars at the demon gate's road and behind the portal
		{ Piece = "pillar", At = v(-92, 0, 49), Look = v(0, 0, 1) },
		{ Piece = "pillar", At = v(-92, 0, 71), Look = v(0, 0, -1) },
		{ Piece = "pillar", At = v(110, 0, 10), Look = v(-1, 0, 0) },
		{ Piece = "pillar", At = v(110, 0, 30), Look = v(-1, 0, 0) },
		-- a fire brazier on the outside of every turn
		{ Piece = "set", At = v(-50, 0, 70), Look = v(0, 0, -1) }, { Piece = "set", At = v(-70, 0, -60), Look = v(1, 0, 0) },
		{ Piece = "set", At = v(0, 0, -60), Look = v(0, 0, 1) }, { Piece = "set", At = v(-20, 0, 50), Look = v(0, 0, -1) },
		{ Piece = "set", At = v(50, 0, 50), Look = v(0, 0, -1) }, { Piece = "set", At = v(30, 0, -70), Look = v(0, 0, 1) },
		{ Piece = "set", At = v(90, 0, -70), Look = v(0, 0, 1) }, { Piece = "set", At = v(70, 0, 30), Look = v(0, 0, -1) },
	},
	Pieces = {},
	Trees = {},
}

MapLayouts.Crystal = {
	Plateaus = {
		{ Name = "West Terrace", X0 = -56, X1 = -34, Z0 = -32, Z1 = 40, H = 4, Round = 4,
			Stairs = { { Side = "W", At = 0.3 }, { Side = "E", At = 0.7 } } },
		{ Name = "East Terrace", X0 = 24, X1 = 46, Z0 = -22, Z1 = 50, H = 4, Round = 4,
			Stairs = { { Side = "W", At = 0.7 }, { Side = "E", At = 0.3 } } },
		{ Name = "Portal Ledge", X0 = 84, X1 = 116, Z0 = 26, Z1 = 56, H = 4, Round = 6, Stairs = { { Side = "S", At = 0.3 } } },
	},
	Channels = {
		-- two glowing canals between the tunnels: one row of defenders fits on each bank
		{ Name = "West Canal", Width = 7, Points = { v(-85, 0, -100), v(-86, 0, -40), v(-84, 0, 0), v(-85, 0, 32) } },
		{ Name = "Deep Canal", Width = 7, Points = { v(-5, 0, -100), v(-4, 0, -40), v(-6, 0, 0), v(-5, 0, 34) } },
		-- and one across the great hall in the east
		{ Name = "Hall Stream", Width = 6, Points = { v(132, 0, 2), v(100, 0, 6), v(78, 0, 4), v(68, 0, 12) } },
	},
	Masses = {
		{ At = v(-85, 0, 84), Radius = 14, H = 16 }, { At = v(-45, 0, -84), Radius = 14, H = 16 },
		{ At = v(-5, 0, 86), Radius = 12, H = 14 }, { At = v(35, 0, -86), Radius = 14, H = 16 },
		{ At = v(104, 0, -70), Radius = 20, H = 18 }, { At = v(84, 0, 78), Radius = 16, H = 14 },
	},
	Bridges = {
		-- a hero's crossing over each canal (the monsters keep to the road)
		{ At = v(-84.6, 0, -10), Along = v(1, 0, 0) },
		{ At = v(-5.7, 0, 10), Along = v(1, 0, 0) },
	},
	Kit = {
		-- the mouth of the rift tunnel, and the gate of the portal's ledge
		{ Piece = "arch", At = v(-105, 0, -54), Look = v(0, 0, 1), Sink = 0.3 },
		{ Piece = "arch", At = v(80, 0, 40), Look = v(1, 0, 0), Sink = 0.9 },
		-- low walls close the two ends of each terrace (their long sides stay open for defenders)
		{ Piece = "low", At = v(-45, 0, -29.5), Look = v(0, 0, -1) },
		{ Piece = "low", At = v(-45, 0, 37.5), Look = v(0, 0, 1) },
		{ Piece = "low", At = v(35, 0, -19.5), Look = v(0, 0, -1) },
		{ Piece = "low", At = v(35, 0, 47.5), Look = v(0, 0, 1) },
		-- old mine walls at the edges of the cavern
		{ Piece = "wall", At = v(-116, 0, 0), Look = v(1, 0, 0) },
		{ Piece = "wall", At = v(92, 0, -44), Look = v(0, 0, 1) },
		{ Piece = "wall", At = v(58, 0, 66), Look = v(0, 0, -1) },
		-- the colonnade of the great hall, either side of the last stretch
		{ Piece = "pillar", At = v(66, 0, 51), Look = v(0, 0, -1) },
		{ Piece = "pillar", At = v(73, 0, 51), Look = v(0, 0, -1) },
		{ Piece = "pillar", At = v(66, 0, 29), Look = v(0, 0, 1) },
		{ Piece = "pillar", At = v(73, 0, 29), Look = v(0, 0, 1) },
		-- crystal carts left on their rails
		{ Piece = "set", At = v(-45, 0, 54), Look = v(0, 0, -1) },
		{ Piece = "set", At = v(35, 0, -36), Look = v(0, 0, 1) },
		{ Piece = "set", At = v(90, 0, 16), Look = v(0.3, 0, 1) },
	},
	Pieces = {},
	Trees = {},
}

function MapLayouts.For(theme)
	return MapLayouts[theme]
end

-- The straight part of one side of a plateau: where it starts, which way it runs, how long it is and which way
-- is out. (Rounded corners take `Round` studs off each end.)
function MapLayouts.Edge(p, side)
	local r = p.Round or 0
	if side == "N" then
		return v(p.X0 + r, 0, p.Z0), v(1, 0, 0), p.X1 - p.X0 - r * 2, v(0, 0, -1)
	elseif side == "S" then
		return v(p.X0 + r, 0, p.Z1), v(1, 0, 0), p.X1 - p.X0 - r * 2, v(0, 0, 1)
	elseif side == "W" then
		return v(p.X0, 0, p.Z0 + r), v(0, 0, 1), p.Z1 - p.Z0 - r * 2, v(-1, 0, 0)
	end
	return v(p.X1, 0, p.Z0 + r), v(0, 0, 1), p.Z1 - p.Z0 - r * 2, v(1, 0, 0)
end

-- the designed height of the ground at (x, z): the highest plateau there, else 0
function MapLayouts.HeightAt(layout, x, z)
	local h = 0
	for _, p in layout.Plateaus do
		if x >= p.X0 and x <= p.X1 and z >= p.Z0 and z <= p.Z1 then
			h = math.max(h, p.H)
		end
	end
	return h
end

local function distanceToPolyline(points, pos)
	local best = math.huge
	local flat = v(pos.X, 0, pos.Z)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local t = math.clamp((flat - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		best = math.min(best, (flat - (a + (b - a) * t)).Magnitude)
	end
	return best
end

-- is this spot plain open ground: not on a slope, in a channel or inside a mass? (for anything scattered)
function MapLayouts.Open(layout, pos, margin)
	margin = margin or 0
	for _, p in layout.Plateaus do
		-- the slope band round each plateau (4 studs either side of its edge)
		local dx = math.max(p.X0 - pos.X, 0, pos.X - p.X1)
		local dz = math.max(p.Z0 - pos.Z, 0, pos.Z - p.Z1)
		local outside = math.sqrt(dx * dx + dz * dz)
		local inside = math.min(pos.X - p.X0, p.X1 - pos.X, pos.Z - p.Z0, p.Z1 - pos.Z)
		if (outside > 0 and outside < 6 + margin) or (outside == 0 and inside < 4 + margin) then
			return false
		end
	end
	for _, c in layout.Channels do
		if distanceToPolyline(c.Points, pos) < c.Width / 2 + 5 + margin then
			return false
		end
	end
	for _, m in layout.Masses do
		if (v(pos.X, 0, pos.Z) - m.At).Magnitude < m.Radius + 2 + margin then
			return false
		end
	end
	for _, k in layout.Kit or {} do
		if (v(pos.X, 0, pos.Z) - k.At).Magnitude < 9 + margin then
			return false
		end
	end
	for _, b in layout.Bridges or {} do
		if (v(pos.X, 0, pos.Z) - b.At).Magnitude < 12 + margin then
			return false
		end
	end
	return true
end

-- open AND on the plain floor (y = 0): for boulders, pools and anything else that is dug into or piled on the ground
function MapLayouts.Flat(layout, pos, margin)
	return MapLayouts.HeightAt(layout, pos.X, pos.Z) == 0 and MapLayouts.Open(layout, pos, margin)
end

-- The lane's height along the path: it rides over every plateau it crosses, with ramps about 30 studs long.
-- Returns samples every 2 studs: { Distance, Position (flat), Direction, Y } and a function distance -> y.
function MapLayouts.LaneProfile(layout, path)
	local STEP = 2
	local raw = {}
	local total = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		for d = 0, length - 0.001, STEP do
			local p = a + dir * d
			table.insert(raw, { Distance = total + d, Position = p, Direction = dir, Segment = i,
				Raw = MapLayouts.HeightAt(layout, p.X, p.Z) })
		end
		total += length
	end
	local last = path[#path]
	table.insert(raw, { Distance = total, Position = last, Direction = (last - path[#path - 1]).Unit, Segment = #path - 1,
		Raw = MapLayouts.HeightAt(layout, last.X, last.Z) })
	-- samples either side: a triangle window 44 studs wide, so a 4-stud rise climbs over about 30 studs. Gentle on
	-- purpose: enemies walk a height profile sampled every 2 studs, and on a steeper ramp (window 28) the three
	-- biggest monsters stood 0.11-0.14 studs into the ground where the ramp bends (test/ground allows 0.05)
	local reach = 11
	for i, s in raw do
		local sum, weight = 0, 0
		for k = -reach, reach do
			local other = raw[math.clamp(i + k, 1, #raw)]
			local w = reach + 1 - math.abs(k)
			sum += other.Raw * w
			weight += w
		end
		s.Y = math.floor(sum / weight * 4 + 0.5) / 4 -- quarter studs: long flat runs merge into one fill
	end
	return raw, function(distance)
		local f = math.clamp(distance / STEP, 0, #raw - 1)
		local i = math.floor(f)
		local a, b = raw[i + 1], raw[math.min(i + 2, #raw)]
		return a.Y + (b.Y - a.Y) * (f - i)
	end
end

return MapLayouts
