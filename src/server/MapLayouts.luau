-- The designed shape of each battlefield (2026-11-24, Lemp: "improve the map layouts ... obstacle courses, look at
-- Dungeon Defenders: much more obstacles and environment"). Their maps are never an open field: raised floors with
-- stairs, pits of lava the lanes cross on bridges, walls that leave a few good building spots at each chokepoint.
-- Here every map gets that as DATA, placed by hand for a reason (6A: a person leads the concept, nothing random):
--   Plateaus  raised, flat ground you can build on (high ground beside a lane); the lane climbs any it crosses.
--             Stone retaining walls with a flagstone rim stand along its straight edges (Walls = which sides,
--             "NSEW" unless given; N is the edge at Z0, S at Z1, W at X0, E at X1), a Parapet (low battlement) on
--             top of the walls of the sides named, and Stairs: flights that run along a wall ({ Side, At = where
--             along that side, 0 = its start, 1 = its end })
--   Channels  a river, a lava stream or a glowing canal: nothing builds there, the lane crosses on a bridge
--   Border    the field's real outline: a closed line of points about 24 studs behind the lanes and round the set
--             pieces. Outside it the ground rises away in rock steps (MapLayouts.Rise): the forest is a valley, the
--             fortress a crater, the caves have cave walls. The rivers and the lava come out of gorges in it.
--             (Before: a rectangle of open floor inside a ring of trees, with the lanes in its middle.)
--   Masses    (cycles 1 to 5: rock mounds that filled the unused corners. The Border does that now.)
--   Bridges   where a channel is crossed: a stone abutment with a plank deck and parapets (the lane's, or a hero's)
--   Paths     footpaths painted on the ground from a set piece to the road (flat: they block nothing)
--   Sets      everything else that stands on the field, as a few named compositions (reviews/maps/placement-rules.md:
--             the floor stays clean, pieces connect, few big set pieces, soft things are massed). A set has Kit
--             pieces (art/blender/map_kit.py; `Look` is where a piece's front faces, a wall runs across it and is
--             tall at its right-hand end seen from the front... measured: tall end = Look x up), Props (older
--             models with the room they block) and a Grove (a clump of trees or crystals, each { At, H }).
--             MapLayouts.Loose lists anything that stands alone; the map tour fails on it.
-- TerrainBuilder shapes the ground from it, MapBuilder stands the pieces on it. Heights are "top at y" in studs;
-- flat ground is y = 0. Height rule: 4 studs (one terrain voxel) is exact for every material; 5 is fine on grass and
-- the ash floors, but the caves' smooth floor material swells to 6 at 5 (measured in the terrain lab). Camera rule: nothing raised inside the field is higher than 5 studs, because the run camera
-- sits 14 studs up and 15 back and a taller cliff behind the hero would push it in (phone first).
local MapLayouts = {}

local MapOutline = require(game:GetService("ReplicatedStorage").Shared.MapOutline)
local v = Vector3.new

MapLayouts.Forest = {
	-- how far outside a plateau's edge its retaining wall stands (see TerrainBuilder: the ground is 1 stud high there)
	WallOut = 1,
	Plateaus = {
		-- the old keep's hill inside the loop of the road: the hero starts on it and sees three lanes below
		{ Name = "Keep Hill", X0 = -14, X1 = 2, Z0 = -34, Z1 = 0, H = 4, Parapet = "S",
			Stairs = { { Side = "E", At = 1 }, { Side = "W", At = 1 } } },
		-- the Hollow Road: two wooded banks either side of the first stretch, so the goblins march in below you.
		-- Walled on the road's side only: a canyon of masonry; their backs stay natural hillside
		{ Name = "North Bank", X0 = -88, X1 = -40, Z0 = -76, Z1 = -54, H = 5, Round = 7, Walls = "S",
			Stairs = { { Side = "S", At = 0 } } },
		{ Name = "South Bank", X0 = -84, X1 = -42, Z0 = -34, Z1 = -14, H = 5, Round = 7, Walls = "N",
			Stairs = { { Side = "N", At = 0 } } },
		-- the shrine the portal stands on: the last stretch climbs to it through the gate in its west wall
		-- (its east end is the valley side itself: no wall there)
		{ Name = "Portal Rise", X0 = 72, X1 = 116, Z0 = 30, Z1 = 54, H = 4, Walls = "NS", Parapet = "NS" },
	},
	-- the field's outline (src/shared/MapOutline.luau, shared with the build ghost)
	Border = MapOutline.Forest,
	Channels = {
		-- the Witchwater: comes down from the north, the road crosses it twice
		{ Name = "Witchwater", Width = 7, Points = { v(36, 0, -100), v(33, 0, -62), v(32, 0, -34), v(36, 0, -16), v(52, 0, -6),
			v(72, 0, 2), v(98, 0, -4), v(130, 0, 6) } },
	},
	Masses = {},
	Bridges = {
		{ At = v(32, 0, -34), Along = v(1, 0, 0) }, -- the first ford
		{ At = v(52, 0, -6), Along = v(0, 0, 1) }, -- the second ford
	},
	Sets = {
		-- Lemp's map audit (2026-11-24), "Keep lookout": the landmark that frames the first view, and one clear build
		-- spot. The heroes arrive facing north-east (MapOutline.Start): the tower at the left of the view, the first
		-- ford ahead, the build spot just behind them on the right. A Ranger on it covers the road on three sides of
		-- the hill (the hill is narrow: its middle strip is all that is free of the walls' flagstone rims)
		{ Name = "The keep", Why = "the hill you start on is the old keep: its tower (an old tree grown up through it) at the north end, the first build spot where you arrive, parapet and stairs at the south end",
			Kit = {
				{ Piece = "tower", At = v(-6, 0, -25), Look = v(0, 0, 1) },
				{ Piece = "pad", At = v(-6, 0, -8.5), Look = v(0, 0, 1), Sink = -0.02 },
			} },
		{ Name = "The Hollow Gate", Why = "a gate IN the canyon wall: its two piers are the ends of the banks' retaining walls",
			Kit = { { Piece = "arch", At = v(-49, 0, -44), Look = v(1, 0, 0), Sink = 0.3 } } },
		-- "Chapel yard": a wide flat yard before the door (Paths), the well in it, one build spot beside the road
		{ Name = "The chapel", Why = "one ruin in the pocket between the last two lanes: three walls, the two columns of its door, a yard with the well and a build spot before the door, trees behind",
			Kit = {
				{ Piece = "wall", At = v(32, 0, 8), Look = v(0, 0, 1) }, -- the back wall (tall at its west corner)
				{ Piece = "wall", At = v(26.6, 0, 16.5), Look = v(-1, 0, 0) }, -- the west wall, tall where it meets the back wall
				{ Piece = "low", At = v(37.4, 0, 15), Look = v(1, 0, 0) }, -- what is left of the east wall
				{ Piece = "pillar", At = v(28, 0, 27), Look = v(0, 0, 1) },
				{ Piece = "pillar", At = v(36, 0, 27), Look = v(0, 0, 1) },
				{ Piece = "pad", At = v(40, 0, 33), Look = v(0, 0, -1), Sink = -0.02 },
			},
			Props = {
				{ Model = "keep_well", At = v(32, 0, 34.5), Height = 6.5, Block = 3 },
				{ Model = "keep_field_bush", At = v(25.5, 0, 4.8), Height = 3.2, Block = 2.6, Turn = 1 },
				{ Model = "keep_field_bush", At = v(38.5, 0, 4.6), Height = 2.8, Block = 2.4, Turn = 4 },
			},
			Grove = { { At = v(29, 0, -1.5), H = 19 }, { At = v(35.5, 0, 0.5), H = 15 }, { At = v(31, 0, -7), H = 13 } } },
		{ Name = "The standing stones", Why = "a ring of three trilithons round a mushroom ring, with its own trees, in the pocket west of the road",
			Kit = {
				{ Piece = "set", At = v(-49.6, 0, 22.9), Look = v(0.17, 0, -0.98) },
				{ Piece = "set", At = v(-54.9, 0, 8.2), Look = v(0.77, 0, 0.64) },
				{ Piece = "set", At = v(-39.5, 0, 10.9), Look = v(-0.94, 0, 0.34) },
			},
			Props = {
				{ Model = "keep_field_mushrooms", At = v(-48, 0, 15.6), Height = 2.2, Block = 1.2, Turn = 0 },
				{ Model = "keep_field_mushrooms", At = v(-49.4, 0, 13.2), Height = 1.9, Block = 1.2, Turn = 2 },
				{ Model = "keep_field_mushrooms", At = v(-46.6, 0, 13.2), Height = 2.0, Block = 1.2, Turn = 4 },
			},
			Grove = { { At = v(-66, 0, 8), H = 18 }, { At = v(-70.5, 0, 15), H = 14 }, { At = v(-64, 0, 19.5), H = 16 } } },
		{ Name = "The shrine", Why = "the portal's platform: a gate in its west wall, parapets either side of the last stretch, two columns flanking the portal",
			Kit = {
				{ Piece = "arch", At = v(71, 0, 42), Look = v(1, 0, 0), Sink = 0.9 },
				{ Piece = "pillar", At = v(109, 0, 35.5), Look = v(-1, 0, 0) },
				{ Piece = "pillar", At = v(109, 0, 48.5), Look = v(-1, 0, 0) },
			} },
		-- the woods: trees stand in clumps on the far halves of the banks and at the field's edge, never one by one
		{ Name = "The north wood", Why = "the far half of the north bank (its road side stays free for defenders)",
			Grove = { { At = v(-72, 0, -70), H = 19 }, { At = v(-63.5, 0, -72), H = 15 }, { At = v(-55, 0, -69.5), H = 17 } } },
		{ Name = "The south wood", Why = "the far half of the south bank",
			Grove = { { At = v(-72, 0, -19.5), H = 17 }, { At = v(-63, 0, -17.5), H = 19 }, { At = v(-54.5, 0, -20), H = 14 } } },
		{ Name = "The river wood", Why = "where the Witchwater comes out of the north-east rocks",
			Grove = { { At = v(46, 0, -58), H = 18 }, { At = v(52, 0, -64), H = 15 }, { At = v(42, 0, -65.5), H = 13 } } },
		{ Name = "The camp wood", Why = "behind the goblin camp",
			Grove = { { At = v(-103, 0, -22), H = 17 }, { At = v(-108, 0, -14.5), H = 14 }, { At = v(-99, 0, -12), H = 19 } } },
		-- two lane sides had no edge at all (the judge on cycle 4: "lane edges remain bare"): a wood closes each,
		-- 20 studs back from the road so the building ground beside the lane stays clear
		-- "Shrine bridge": the second ford is the last place to cut off a wave before the portal. A build spot at its
		-- near landing; its far side (where the east wood stood) is open ground for the fight near the portal, closed
		-- by the valley side behind it
		{ Name = "The shrine bridge", Why = "a build spot at the near landing of the last bridge before the shrine",
			Kit = { { Piece = "pad", At = v(61, 0, -15), Look = v(-1, 0, 0), Sink = -0.02 } } },
		{ Name = "The south wood", Why = "closes the south side of the road below the keep",
			Grove = { { At = v(-16, 0, 31), H = 17 }, { At = v(-8, 0, 34.5), H = 19 }, { At = v(0, 0, 30.5), H = 14 },
				{ At = v(6.5, 0, 35), H = 16 } } },
	},
	-- footpaths of trodden earth: flat (they block nothing), they tie a set piece to the road so it does not sit
	-- on the lawn like a dropped object. Width is what TerrainBuilder writes, and 4 is the least that shows (as a
	-- track about 7 studs wide); a line must lie on 4k + 2 and run along X or Z (the terrain's 4-stud cells).
	-- (a strip's ends lie on multiples of 4 too: a half-covered cell keeps its old ground)
	-- `Stones = true`: a line of flat stepping stones (kit piece `flags`) instead of painted earth, for a route that
	-- runs beside the road (painted earth there merged with the road's own verge: cycle 6's first film)
	Paths = {
		-- the hero's shortcut (Lemp's map audit: "connect the keep and chapel with a short hero footpath so a player
		-- can see a wave advance and get ahead of it"): stepping stones from the foot of the keep's east stairs (its
		-- north end) across the road, down between the road and the chapel's west wall, into its yard, which opens
		-- onto the road before the shrine bridge. The goblins go the long way round by both fords (about 130
		-- studs), the hero's way is about 70
		{ Name = "the hero's shortcut from the keep to the chapel yard", Stones = true,
			Points = { v(5.5, 0, -9.5), v(20.5, 0, -9.5), v(22.5, 0, -5), v(22.5, 0, 24), v(26, 0, 29) } },
		-- the yard: trodden earth before the door, a grass gap from the road on its east
		{ Name = "the chapel yard", Width = 16, Points = { v(24, 0, 36), v(40, 0, 36) } },
		{ Name = "from the standing stones to the road", Width = 4, Points = { v(-44, 0, 14), v(-32, 0, 14) } },
	},
}

MapLayouts.Magma = {
	WallOut = 1,
	Plateaus = {
		-- the bastions of the old fortress: flat basalt floors a step above the ash, walled all round, with a
		-- parapet on the side that faces the lava river (the fortress held the river's line)
		-- (no bastion between the first two lanes north of the river: only 12 studs fit there, and a walled floor
		-- that shallow has no room left to build on. That pocket is open floor.)
		{ Name = "Heart Bastion", X0 = 0, X1 = 30, Z0 = -12, Z1 = 30, H = 4, Parapet = "N",
			Stairs = { { Side = "W", At = 0.6 }, { Side = "E", At = 0.4 } } },
		{ Name = "East Bastion", X0 = 50, X1 = 70, Z0 = -50, Z1 = -30, H = 5, Parapet = "S", Stairs = { { Side = "W", At = 0 } } },
		{ Name = "Gate Yard", X0 = -50, X1 = -20, Z0 = 6, Z1 = 40, H = 4, Parapet = "N",
			Stairs = { { Side = "E", At = 0.5 }, { Side = "W", At = 0.5 } } },
		-- the portal's keep: the last stretch climbs to it through the gate that is its whole west side
		-- (built against the crater wall: no wall of its own on the east)
		{ Name = "Portal Keep", X0 = 90, X1 = 116, Z0 = 10, Z1 = 30, H = 4, Walls = "NS", Parapet = "NS" },
	},
	-- the field's outline (src/shared/MapOutline.luau, shared with the build ghost)
	Border = MapOutline.Magma,
	Channels = {
		-- the lava river cuts the whole fortress in two: four bridges
		{ Name = "Lava River", Width = 11, Points = { v(-132, 0, -14), v(-85, 0, -10), v(-60, 0, -12), v(-35, 0, -18), v(-10, 0, -16),
			v(14, 0, -24), v(40, 0, -22), v(60, 0, -16), v(80, 0, -18), v(132, 0, -12) } },
	},
	Masses = {},
	Bridges = {
		{ At = v(-60, 0, -12), Along = v(0, 0, 1) }, { At = v(-10, 0, -16), Along = v(0, 0, 1) },
		{ At = v(40, 0, -22), Along = v(0, 0, 1) }, { At = v(80, 0, -18), Along = v(0, 0, 1) },
	},
	Sets = {
		{ Name = "The south gate", Why = "a gate between the heart bastion's wall and the south curtain, which runs on to the rocks at the field's edge",
			Kit = {
				{ Piece = "arch", At = v(15, 0, 40), Look = v(1, 0, 0), Sink = 0.3 },
				{ Piece = "wall", At = v(15, 0, 57.2), Look = v(-1, 0, 0) }, -- tall at the gate, breached in the middle
				{ Piece = "wall", At = v(15, 0, 71.2), Look = v(1, 0, 0) }, -- tall again at the rocks
			} },
		{ Name = "The keep gate", Why = "the portal keep's west side is its gate, a fire either side of it",
			Kit = {
				{ Piece = "arch", At = v(89, 0, 20), Look = v(1, 0, 0), Sink = 0.9 },
				{ Piece = "set", At = v(84.5, 0, 10.6), Look = v(-1, 0, 0) },
				{ Piece = "set", At = v(84.5, 0, 29.4), Look = v(-1, 0, 0) },
			} },
		{ Name = "The demon gate's fires", Why = "two fires flank the road where it leaves the demon gate",
			Kit = {
				{ Piece = "set", At = v(-99, 0, 50), Look = v(1, 0, 0) },
				{ Piece = "set", At = v(-99, 0, 70), Look = v(1, 0, 0) },
			} },
	},
}

MapLayouts.Crystal = {
	-- (the caves' smooth floor material stands up steeper than grass or ash: its walls stand 3 studs out)
	WallOut = 3,
	Plateaus = {
		-- two long mine terraces between the tunnels: walled, a low wall across each end
		{ Name = "West Terrace", X0 = -53, X1 = -37, Z0 = -32, Z1 = 40, H = 4, Parapet = "NS",
			Stairs = { { Side = "W", At = 0.3 }, { Side = "E", At = 0.7 } } },
		{ Name = "East Terrace", X0 = 27, X1 = 43, Z0 = -22, Z1 = 50, H = 4, Parapet = "NS",
			Stairs = { { Side = "W", At = 0.7 }, { Side = "E", At = 0.3 } } },
		-- (cut into the cave wall: no wall of its own on the east)
		{ Name = "Portal Ledge", X0 = 84, X1 = 112, Z0 = 30, Z1 = 50, H = 4, Walls = "NS", Parapet = "NS" },
	},
	-- a cave wall, so beyond the camera's reach it climbs steeply, to 50 studs
	Rise = { { 0, 5 }, { 8, 10 }, { 18, 16 }, { 30, 26 }, { 38, 38 }, { 46, 50 } },
	-- the field's outline (src/shared/MapOutline.luau, shared with the build ghost)
	Border = MapOutline.Crystal,
	Channels = {
		-- two glowing canals between the tunnels: one row of defenders fits on each bank
		{ Name = "West Canal", Width = 7, Points = { v(-85, 0, -100), v(-86, 0, -40), v(-84, 0, 0), v(-85, 0, 32) } },
		{ Name = "Deep Canal", Width = 7, Points = { v(-5, 0, -100), v(-4, 0, -40), v(-6, 0, 0), v(-5, 0, 34) } },
		-- and one across the great hall in the east
		{ Name = "Hall Stream", Width = 6, Points = { v(132, 0, 2), v(100, 0, 6), v(78, 0, 4), v(68, 0, 12) } },
	},
	Masses = {},
	Bridges = {
		-- a hero's crossing over each canal (the monsters keep to the road)
		{ At = v(-84.6, 0, -10), Along = v(1, 0, 0) },
		{ At = v(-5.7, 0, 10), Along = v(1, 0, 0) },
	},
	Sets = {
		{ Name = "The ledge gate", Why = "the portal ledge's west side is its gate; a colonnade of four columns lines the last stretch up to it",
			Kit = {
				{ Piece = "arch", At = v(81, 0, 40), Look = v(1, 0, 0), Sink = 0.9 },
				{ Piece = "pillar", At = v(66, 0, 51), Look = v(0, 0, -1) },
				{ Piece = "pillar", At = v(73.5, 0, 51), Look = v(0, 0, -1) },
				{ Piece = "pillar", At = v(66, 0, 29), Look = v(0, 0, 1) },
				{ Piece = "pillar", At = v(73.5, 0, 29), Look = v(0, 0, 1) },
			} },
		{ Name = "The loading dock", Why = "the mine's one working place: three carts on one track along the dock wall, the crystals they were loading at its end",
			Kit = {
				{ Piece = "set", At = v(68, 0, -40), Look = v(0, 0, 1) },
				{ Piece = "set", At = v(75.5, 0, -40), Look = v(0, 0, 1) },
				{ Piece = "set", At = v(83, 0, -40), Look = v(0, 0, 1) },
				{ Piece = "wall", At = v(75, 0, -46), Look = v(0, 0, 1) },
				{ Piece = "wall", At = v(89, 0, -46), Look = v(0, 0, -1) },
			},
			Grove = { { At = v(93, 0, -38.5), H = 16 }, { At = v(96.5, 0, -42.5), H = 10 }, { At = v(91, 0, -35), H = 6 } } },
		-- crystals grow where the glowing water rises and where it pools: in clumps of big, middle, small
		{ Name = "The west spring", Why = "where the west canal comes out of the rock",
			Grove = { { At = v(-79, 0, -82), H = 15 }, { At = v(-76, 0, -77.5), H = 9 }, { At = v(-80.5, 0, -76), H = 5 } } },
		{ Name = "The west pool", Why = "where the west canal ends",
			Grove = { { At = v(-85, 0, 39), H = 16 }, { At = v(-80.5, 0, 42), H = 9 }, { At = v(-89, 0, 43), H = 6 } } },
		{ Name = "The deep spring", Why = "where the deep canal comes out of the rock",
			Grove = { { At = v(1, 0, -82), H = 15 }, { At = v(4, 0, -77.5), H = 9 }, { At = v(-0.5, 0, -76), H = 5 } } },
		{ Name = "The deep pool", Why = "where the deep canal ends",
			Grove = { { At = v(-5, 0, 41), H = 16 }, { At = v(-0.5, 0, 44), H = 9 }, { At = v(-9, 0, 45), H = 6 } } },
		{ Name = "The hall spring", Why = "where the hall stream comes in from the east",
			Grove = { { At = v(113, 0, -4), H = 15 }, { At = v(108.5, 0, 13.5), H = 9 }, { At = v(116, 0, -8), H = 6 } } },
	},
}

function MapLayouts.For(theme)
	return MapLayouts[theme]
end

-- every placed thing of a layout, flat: { At, Radius, Kind = "kit" | "prop" | "grove", Set, Name }
function MapLayouts.Things(layout)
	local things = {}
	for _, set in layout.Sets or {} do
		for _, k in set.Kit or {} do
			table.insert(things, { At = k.At, Radius = 9, Kind = "kit", Set = set.Name, Name = k.Piece,
				Reach = k.Piece == "arch" and 9 or k.Piece == "wall" and 7 or 0 })
		end
		for _, p in set.Props or {} do
			table.insert(things, { At = p.At, Radius = (p.Block or 2) + 2, Kind = "prop", Set = set.Name, Name = p.Model })
		end
		for _, g in set.Grove or {} do
			table.insert(things, { At = g.At, Radius = 4, Kind = "grove", Set = set.Name, Name = "grove" })
		end
	end
	return things
end

-- Rule 3 and 4 of reviews/maps/placement-rules.md as a check: nothing built stands alone. A thing is "loose" when
-- no other thing of its own set stands within 22 studs of it (two pieces that flank a lane are about 20 apart), it
-- does not touch a plateau (on it, or within 4 studs of its edge, counting an arch's or a wall's own length) and
-- it is not at a bridge. Returns the loose ones.
function MapLayouts.Loose(layout)
	local things = MapLayouts.Things(layout)
	local loose = {}
	for i, t in things do
		local attached = false
		for j, other in things do
			if i ~= j and other.Set == t.Set and (other.At - t.At).Magnitude <= 22 then
				attached = true
				break
			end
		end
		for _, p in layout.Plateaus do
			local dx = math.max(p.X0 - t.At.X, 0, t.At.X - p.X1)
			local dz = math.max(p.Z0 - t.At.Z, 0, t.At.Z - p.Z1)
			if math.sqrt(dx * dx + dz * dz) <= 4 + (t.Reach or 0) then
				attached = true
			end
		end
		for _, b in layout.Bridges or {} do
			attached = attached or (b.At - t.At).Magnitude <= 14
		end
		if not attached then
			table.insert(loose, t)
		end
	end
	return loose
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

-- where each flight of stairs stands (the middle of the flight, on its wall's line) and which way is out
function MapLayouts.StairSpots(layout)
	local spots = {}
	for _, p in layout.Plateaus do
		for _, st in p.Stairs or {} do
			local start, along, length, out = MapLayouts.Edge(p, st.Side)
			table.insert(spots, { At = start + along * (4 + st.At * (length - 8)) + out * (layout.WallOut or 1), Out = out,
				Plateau = p })
		end
	end
	return spots
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

-- How far (x, z) lies outside the field's outline, in studs: negative inside, and far inside for a layout
-- without a Border.
function MapLayouts.Outside(layout, x, z)
	return MapOutline.Outside(layout.Border, x, z)
end

-- The rise outside the outline: { how far outside it starts, how high the ground is from there }. The rule behind
-- the numbers is the camera: in a run it looks down at the hero at 32 to 42 degrees from 20.5 studs away
-- (Config.RunCamera), and heroes are stopped MapOutline.HeroStop studs inside the outline. The line from the
-- camera's focus (3 studs over the hero's feet) going up and away at 32 degrees stays over every step out to 30
-- studs (the camera pulled back to 1.7 times its run distance), so the rise never pushes the camera in. Steeper
-- would look more like a wall, and would do exactly that on a phone. Beyond 30 studs a layout may climb as it likes
-- (`Rise` in the layout: the caves' wall does).
MapLayouts.Rise = { { 0, 5 }, { 8, 10 }, { 18, 16 }, { 32, 22 }, { 44, 30 } } -- (the crater's rough rock stood 0.4 into the line at 28 with 24 from 30)
MapLayouts.CameraLine = { Degrees = 32, Focus = 3, Clear = 0.5, Reach = 30 }
-- the first studs of every step are its face: rock (TerrainBuilder), the rest its tread (grass, ash, cave floor)
MapLayouts.Face = 4
-- how far a channel's gorge reaches either side of its line, beyond the channel itself
MapLayouts.Gorge = 5

-- The designed height of the rise at (x, z), how far outside the outline that is, and whether it is a step's
-- face (its first MapLayouts.Face studs). 0 inside, and 0 in the gorges the channels come through. The first step starts exactly on the outline; the edges of the higher steps
-- wander up to 6 studs further out (never in), so the terraces are not parallel copies of the outline.
function MapLayouts.RiseAt(layout, x, z)
	local d = MapLayouts.Outside(layout, x, z)
	if d <= 0 then
		return 0, d, false
	end
	for _, c in layout.Channels do
		if distanceToPolyline(c.Points, v(x, 0, z)) < c.Width / 2 + MapLayouts.Gorge then
			return 0, d, false
		end
	end
	local wander = math.clamp((math.noise(x / 34, z / 34, 4.7) + 0.5) * 6, 0, 6)
	local steps = layout.Rise or MapLayouts.Rise
	local h, from = steps[1][2], 0
	for i = 2, #steps do
		if d - wander >= steps[i][1] then
			h, from = steps[i][2], steps[i][1] + wander
		end
	end
	return h, d, d - from < MapLayouts.Face
end

-- is this spot plain open ground: not on a slope, in a channel or inside a mass? (for anything scattered)
function MapLayouts.Open(layout, pos, margin)
	margin = margin or 0
	-- (the rise outside the outline, and the 8 studs of floor at its foot, are never open ground)
	if MapLayouts.Outside(layout, pos.X, pos.Z) > -8 - margin then
		return false
	end
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
	for _, t in MapLayouts.Things(layout) do
		if (v(pos.X, 0, pos.Z) - t.At).Magnitude < t.Radius + margin then
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
