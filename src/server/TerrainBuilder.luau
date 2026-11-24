-- Real terrain for the battlefields (6A world guide): ground with height and no edge, cliff walls around the
-- play area, a backdrop on the horizon, sunken lava, a bordered path. Gameplay still uses the invisible
-- Ground/Path parts of MapBuilder for clicks; this only shapes what you see.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")
local Config = require(ReplicatedStorage.Shared.Config)
local GroundLooks = require(ReplicatedStorage.Shared.GroundLooks)
local MapLayouts = require(script.Parent.MapLayouts)

local TerrainBuilder = {}
local M = Enum.Material

-- Roblox draws a terrain surface 2 studs above the top of a filled block (measured: a block filled to y = 0 shows
-- its ground at y = 2.0; filled to -2 it shows at 0.02). Everything here is written as "top at y", and the game
-- (spawns, the click ground, defenders, enemies) expects flat ground at y = 0, so every fill goes 2 studs lower.
-- Ground.luau measures the real surface for everything that isn't flat.
local SINK = Vector3.new(0, -2, 0)
local sunk = setmetatable({}, {
	__index = function(_, key)
		local real = workspace.Terrain
		if key == "FillBlock" then
			return function(_, cframe, size, material)
				real:FillBlock(cframe + SINK, size, material)
			end
		elseif key == "FillBall" then
			return function(_, center, radius, material)
				real:FillBall(center + SINK, radius, material)
			end
		elseif key == "FillCylinder" then
			return function(_, cframe, height, radius, material)
				real:FillCylinder(cframe + SINK, height, radius, material)
			end
		end
		local value = real[key]
		if type(value) == "function" then
			return function(_, ...)
				return value(real, ...)
			end
		end
		return value
	end,
	__newindex = function(_, key, value)
		workspace.Terrain[key] = value
	end,
})
local function terrain()
	return sunk
end

-- deterministic random so every server builds the same map
local function rngFor(seed)
	return Random.new(seed)
end

-- a cliff wall around the play area: overlapping rock balls, higher towards the outside
local function cliffs(rng, material, topMaterial)
	local t = terrain()
	local half = Config.MapSize / 2
	local function wallAt(x, z)
		local h = rng:NextNumber(14, 30)
		t:FillBall(Vector3.new(x, h * 0.35, z), h * 0.7, material)
		if rng:NextNumber() < 0.35 then
			t:FillBall(Vector3.new(x + rng:NextNumber(-6, 6), h * 0.9, z + rng:NextNumber(-6, 6)), h * 0.35, topMaterial)
		end
	end
	for x = -half.X - 10, half.X + 10, 12 do
		wallAt(x, -half.Y - 16 - rng:NextNumber(0, 8))
		wallAt(x, half.Y + 16 + rng:NextNumber(0, 8))
	end
	for z = -half.Y - 10, half.Y + 10, 12 do
		wallAt(-half.X - 16 - rng:NextNumber(0, 8), z)
		wallAt(half.X + 16 + rng:NextNumber(0, 8), z)
	end
end

-- a cone-shaped mountain far away, made of stacked discs
local function mountain(center, radius, height, material, craterMaterial)
	local t = terrain()
	local steps = 10
	for i = 0, steps - 1 do
		local f = i / steps
		local r = radius * (1 - f) ^ 1.15 + 6
		t:FillCylinder(CFrame.new(center + Vector3.new(0, f * height + height / steps / 2, 0)), height / steps + 1, r, material)
	end
	if craterMaterial then
		t:FillCylinder(CFrame.new(center + Vector3.new(0, height - 2, 0)), 6, radius * 0.14 + 4, craterMaterial)
	end
end

-- Apply the palette even if a variant is unavailable. Reuse valid overrides across maps.
local overridden = {}
local function applyLooks(theme)
	local looks = GroundLooks.Themes[theme]
	local t = terrain()
	for material in overridden do
		if not looks[material] then
			MaterialService:SetBaseMaterialOverride(material, "")
			overridden[material] = nil
		end
	end
	for material, texture in looks do
		local name = "HTD_" .. texture
		local variant = MaterialService:GetMaterialVariant(material, name)
		if variant and overridden[material] ~= name then
			MaterialService:SetBaseMaterialOverride(material, name)
			overridden[material] = name
		end
		local own = GroundLooks.Colors[texture]
		-- This tint is also what low-detail clients see when Roblox omits the image.
		t:SetMaterialColor(material, variant and GroundLooks.Tint(texture) or own)
	end
end

-- wipes the battlefield's terrain only (the Outpost has its own terrain far away and keeps it)
local function clearBattlefield()
	terrain():FillBlock(CFrame.new(0, 100, 0), Vector3.new(980, 280, 980), M.Air)
end

local function farFromPath(pos, margin)
	return Config.DistanceToPath(pos) > Config.PathWidth / 2 + margin
end

-- the band along the field's edge, at the foot of the cliffs. Loose boulders belong there and nowhere else: the
-- floor inside stays clean (reviews/maps/placement-rules.md, rule 1)
local function border(pos)
	local half = Config.MapSize / 2
	return math.abs(pos.X) > half.X - 16 or math.abs(pos.Z) > half.Y - 16
end

-------------------------------------------------------------------------------
-- The designed layout (MapLayouts): raised ground, channels, rock masses and a lane that climbs.
-- Everything stays solid terrain (no caves, no overhangs): Ground.At sees one surface everywhere, so defenders and
-- enemies always stand on what you see.
-------------------------------------------------------------------------------
-- A flat-topped plateau of `top` material. Measured in the terrain lab (scripts/terrain_lab.py), for a block
-- filled 4 high with its edge at x: on grass and the ash floors the ground is 0 at x - 4, 1.0 at x - 1, 2.0 at x and
-- only reaches 4.0 at x + 4 (an 8-stud bevel centred on the edge); the caves' smooth floor is 4.0 at x and falls to 0
-- at x - 4. No rock skirt any more: it only pushed the foot of the slope 3 studs further out. The bevel is covered
-- by the retaining walls' flagstone rim instead (MapBuilder; `layout.WallOut` = how far outside the edge they stand).
-- `p.Round` rounds its corners (hills; built floors stay square).
local function plateau(p, top)
	local t = terrain()
	local w, d = p.X1 - p.X0, p.Z1 - p.Z0
	local cx, cz = (p.X0 + p.X1) / 2, (p.Z0 + p.Z1) / 2
	local r = math.min(p.Round or 0, w / 2 - 1, d / 2 - 1)
	-- the shape: BLOCKS only (a filled disc stands up to 1.5 studs higher than a block filled to the same height,
	-- and shaving the top with an Air block halves it: both measured). Rounded corners are three crossing blocks,
	-- an eight-sided outline that the terrain's own smoothing rounds off.
	local function shape(topY, bottomY, material)
		local mid, height = (topY + bottomY) / 2, topY - bottomY
		if r <= 0 then
			t:FillBlock(CFrame.new(cx, mid, cz), Vector3.new(w, height, d), material)
			return
		end
		t:FillBlock(CFrame.new(cx, mid, cz), Vector3.new(w, height, d - r * 2), material)
		t:FillBlock(CFrame.new(cx, mid, cz), Vector3.new(w - r * 2, height, d), material)
		t:FillBlock(CFrame.new(cx, mid, cz), Vector3.new(w - r * 0.6, height, d - r * 0.6), material)
	end
	-- (a new material only replaces empty voxels: dig the body out of the ground, then fill it)
	shape(p.H, -2, M.Air)
	shape(p.H, -2, top)
end

-- A river, lava stream or canal along a line of points. Built from WHOLE blocks only: thin fills (a 1.6-stud rim,
-- a 2-stud layer of water) do not do what they say on a 4-stud voxel grid. Measured in the terrain lab
-- (scripts/terrain_lab.py): the old recipe of thin discs left a cobble ridge 1.8 studs HIGH and no water at all.
--   banks   the top layer either side of the channel becomes `rim`
--   trench  dug `c.Width` wide, with a `bed` whose surface lies at bedY
--   liquid  filled up to liquidY (water shows exactly where it is filled to; nil = the bed itself is the lava)
local function channel(c, bed, rim, bedY, liquid, liquidY)
	local t = terrain()
	local points = c.Points
	local function all(width, top, bottom, material)
		local mid, height = (top + bottom) / 2, top - bottom
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local centre = (a + b) / 2
			-- each stretch reaches a third of its width past its ends, which closes the bends (the line only turns
			-- gently). No discs at the joints: a filled disc stands higher than a block filled to the same height.
			t:FillBlock(CFrame.lookAt(Vector3.new(centre.X, mid, centre.Z), Vector3.new(b.X, mid, b.Z)),
				Vector3.new(width, height, (b - a).Magnitude + width * 0.66), material)
		end
	end
	all(c.Width + 6, 2, -4, M.Air)
	all(c.Width + 6, 0, -4, rim)
	all(c.Width, 12, -9, M.Air)
	all(c.Width + 4, bedY, -16, bed)
	if liquid then
		all(c.Width, liquidY + 2, bedY, liquid) -- (+2: a liquid is not lifted like solid ground is)
	end
end

-- the lane: a kerb with the road inside, following the layout's height profile (ramps onto plateaus, dams across
-- channels). One block per run of equal height, so flat stretches are single fills like before.
local function lane(layout, kerb, road)
	local t = terrain()
	local points = Config.Path
	local samples = MapLayouts.LaneProfile(layout, points)
	for _, pass in { { Config.PathWidth + 5, kerb, 0.1 }, { Config.PathWidth, road, 0.2 } } do
		local width, material, lift = pass[1], pass[2], pass[3]
		local i = 1
		while i <= #samples do
			local first = samples[i]
			local j = i
			while samples[j + 1] and samples[j + 1].Segment == first.Segment and samples[j + 1].Y == first.Y do
				j += 1
			end
			local last = samples[j]
			local a, b = points[first.Segment], points[first.Segment + 1]
			local dir = first.Direction
			-- the first and last run of a segment reach half a road past its ends, so corners are whole
			local from = first.Position - dir * ((first.Position - a).Magnitude < 0.01 and width / 2 or 0)
			local to = last.Position + dir * 2
			if (to - a).Magnitude >= (b - a).Magnitude - 0.01 then
				to = b + dir * width / 2
			end
			local mid = (from + to) / 2 + Vector3.new(0, first.Y, 0)
			local length = (to - from).Magnitude
			local along = CFrame.lookAt(mid, mid + dir)
			t:FillBlock(along + Vector3.new(0, 3.5, 0), Vector3.new(width, 13, length), M.Air) -- room over the road
			t:FillBlock(along + Vector3.new(0, lift - 3.1, 0), Vector3.new(width, 6.2, length), material)
			i = j + 1
		end
	end
end

-- a bridge's abutment: solid ground from bank to bank, 18.6 wide (the deck and both parapets stand on it).
-- Where the lane crosses, the lane is laid over it afterwards.
local function abutment(b, material)
	local t = terrain()
	local along = CFrame.lookAt(b.At, b.At + b.Along)
	t:FillBlock(along + Vector3.new(0, 3.5, 0), Vector3.new(18.6, 13, 17), M.Air)
	t:FillBlock(along + Vector3.new(0, -3, 0), Vector3.new(18.6, 6.2, 17), material)
end

-- everything in the layout except the lane (call before the lane and before anything scattered)
local function shapeLayout(layout, look)
	local t = terrain()
	for _, m in layout.Masses do
		-- a solid mound of stacked discs: a wide foot, a blunt top
		local steps = math.max(4, math.floor(m.H / 2.5))
		for i = 0, steps - 1 do
			local f = i / steps
			t:FillCylinder(CFrame.new(m.At + Vector3.new(0, f * m.H + m.H / steps / 2, 0)), m.H / steps + 1,
				m.Radius * (1 - f) ^ 0.8 + 3, look.Mass)
		end
	end
	for _, p in layout.Plateaus do
		plateau(p, look.Top)
	end
	for _, c in layout.Channels do
		channel(c, look.Bed, look.Rim, look.BedY, look.Liquid, look.LiquidY)
	end
	for _, b in layout.Bridges or {} do
		abutment(b, look.Kerb)
	end
	-- footpaths: a strip of the kerb's packed earth, laid the way the lane is (dug from above the ground, filled a
	-- tenth of a stud proud of it). Measured in the terrain lab: a strip filled exactly level with the ground does
	-- not show at all (4 wide) or only its middle (8 wide); filled 0.1 proud, a strip written 4 wide shows about 7
	-- wide, and one written 2 wide does not show. Flat and smooth, so defenders can stand on it.
	for _, path in layout.Paths or {} do
		for i = 1, #path.Points - 1 do
			local a, b = path.Points[i], path.Points[i + 1]
			local mid = (a + b) / 2
			local strip = CFrame.lookAt(mid, Vector3.new(b.X, mid.Y, b.Z))
			local length = (b - a).Magnitude
			t:FillBlock(strip + Vector3.new(0, 3.5, 0), Vector3.new(path.Width, 13, length), M.Air)
			t:FillBlock(strip + Vector3.new(0, -3, 0), Vector3.new(path.Width, 6.2, length), look.Kerb)
		end
	end
end

-------------------------------------------------------------------------------
-- Magma Fortress
-------------------------------------------------------------------------------
function TerrainBuilder.Magma(map, camp)
	local t = terrain()
	clearBattlefield()
	local rng = rngFor(11)
	local half = Config.MapSize / 2

	-- the ground: a wide basalt plain with no edge in sight (top at y = 0)
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Sand) -- smooth (see GroundLooks), painted as ash
	-- lighter ash patches so the floor isn't one flat colour
	for _ = 1, 40 do
		-- flat discs that only recolour the surface (balls made grey bumps)
		local pos = Vector3.new(rng:NextNumber(-half.X, half.X), -1, rng:NextNumber(-half.Y, half.Y))
		t:FillCylinder(CFrame.new(pos), 2, rng:NextNumber(5, 10), M.Salt)
	end

	-- the path: a cobbled border with packed ground inside, so it reads at a glance
	-- (grey cobbles inside a dark basalt kerb: the path never looks like lava on this red map)
	local layout = MapLayouts.Magma
	shapeLayout(layout, { Top = M.Salt, Skirt = M.Slate, Bed = M.CrackedLava, BedY = -1.6, Rim = M.Basalt, Mass = M.Rock, Kerb = M.Salt })
	lane(layout, M.Salt, M.Cobblestone)

	-- (the lava is the river now, MapLayouts: the old scattered pools were thin fills that came out as rock bumps)
	local tries

	-- basalt boulders that give the floor shape (never on the path or the spawn)
	local rocks = 0
	tries = 0
	while rocks < 12 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if border(pos) and MapLayouts.Flat(layout, pos, 6) and farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
			local r = rng:NextNumber(2.5, 5.5)
			t:FillBall(pos + Vector3.new(0, r * 0.25, 0), r, rng:NextNumber() < 0.7 and M.Basalt or M.Rock)
			rocks += 1
		end
	end

	-- cliff walls around the battlefield and volcanoes on the horizon
	cliffs(rng, M.Basalt, M.Rock)
	mountain(Vector3.new(-230, 0, -260), 140, 150, M.Basalt, M.CrackedLava)
	mountain(Vector3.new(200, 0, -300), 170, 190, M.Basalt, M.CrackedLava)
	mountain(Vector3.new(320, 0, 120), 130, 120, M.Rock, nil)
	mountain(Vector3.new(-320, 0, 180), 120, 110, M.Basalt, nil)
	-- a lava river winding around the outside, between the cliffs and the volcanoes
	for i = 0, 70 do
		local a = i / 70 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * (half.X + 70), 0, math.sin(a) * (half.Y + 70))
		t:FillBall(pos + Vector3.new(0, 1, 0), 9, M.Air)
		t:FillCylinder(CFrame.new(pos + Vector3.new(0, -3.5, 0)), 3, 8, M.CrackedLava)
	end

	-- terrain colours: warm basalt, cobbles that stand out from the ground
	t:SetMaterialColor(M.Basalt, Color3.fromRGB(104, 88, 82))
	t:SetMaterialColor(M.Slate, Color3.fromRGB(128, 112, 104))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(128, 112, 100))
	t:SetMaterialColor(M.Ground, Color3.fromRGB(178, 136, 98))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(92, 80, 78))
	t:SetMaterialColor(M.CrackedLava, Color3.fromRGB(255, 120, 40))
	-- painted looks (the painting has its own colours, so no tint)
	applyLooks("Magma")
	map:SetAttribute("GroundTheme", "Magma")
end

-------------------------------------------------------------------------------
-- Cursed Forest
-------------------------------------------------------------------------------
function TerrainBuilder.Forest(map, camp)
	local t = terrain()
	clearBattlefield()
	local rng = rngFor(7)
	local half = Config.MapSize / 2

	-- a meadow with no edge in sight (top at y = 0)
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Grass)
	-- (no random soil patches any more: from above they were dark blots on a clean lawn)

	-- the path: packed sandy dirt inside a cobbled kerb (leafy soil read as a red carpet in the violet light)
	-- a cobbled road with a packed-earth verge (the old orange dirt road read as a red carpet on the phone)
	local layout = MapLayouts.Forest
	shapeLayout(layout, { Top = M.Grass, Skirt = M.Rock, Bed = M.Mud, BedY = -3, Rim = M.Cobblestone, Liquid = M.Water, LiquidY = -1.1, Mass = M.Rock,
		Kerb = M.Mud })
	lane(layout, M.Mud, M.Cobblestone)

	local tries

	-- mossy boulders
	local rocks = 0
	tries = 0
	while rocks < 8 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if border(pos) and MapLayouts.Flat(layout, pos, 6) and farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
			local r = rng:NextNumber(2, 4.5)
			t:FillBall(pos + Vector3.new(0, r * 0.2, 0), r, M.Rock)
			rocks += 1
		end
	end

	-- grassy, rocky hills around the battlefield and rolling hills on the horizon
	cliffs(rng, M.Grass, M.Rock)
	mountain(Vector3.new(-240, 0, -270), 160, 90, M.Grass, nil)
	mountain(Vector3.new(220, 0, -290), 180, 110, M.Grass, nil)
	mountain(Vector3.new(330, 0, 130), 140, 80, M.Rock, nil)
	mountain(Vector3.new(-330, 0, 170), 130, 70, M.Grass, nil)

	t:SetMaterialColor(M.Grass, Color3.fromRGB(86, 120, 64))
	t:SetMaterialColor(M.Mud, Color3.fromRGB(120, 92, 66))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(128, 120, 110))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(110, 112, 104))
	t.WaterColor = Color3.fromRGB(40, 80, 90)
	t.WaterTransparency = 0.5
	t.WaterWaveSize = 0.05
	t.WaterReflectance = 0.6
	applyLooks("Forest")
	map:SetAttribute("GroundTheme", "Forest")
end

-------------------------------------------------------------------------------
-- Crystal Caves: a deep cavern floor open to the night sky, ringed by tall cave walls,
-- with glowing pools (the crystal clusters themselves are Blender models, see MapBuilder)
-------------------------------------------------------------------------------
function TerrainBuilder.Crystal(map, camp)
	local t = terrain()
	clearBattlefield()
	local rng = rngFor(23)
	local half = Config.MapSize / 2

	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Asphalt) -- smooth, painted as cave floor
	-- the path: smooth cobbles inside a dark rock kerb
	local layout = MapLayouts.Crystal
	shapeLayout(layout, { Top = M.Concrete, Skirt = M.Basalt, Bed = M.Slate, BedY = -3, Rim = M.Basalt, Liquid = M.Water,
		LiquidY = -1.1, Mass = M.Basalt, Kerb = M.Concrete })
	lane(layout, M.Concrete, M.Cobblestone) -- kerb: smooth, painted as cave wall

	local tries

	-- rock spires on the floor
	local rocks = 0
	tries = 0
	while rocks < 9 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if border(pos) and MapLayouts.Flat(layout, pos, 6) and farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
			local r = rng:NextNumber(2, 4)
			t:FillBall(pos + Vector3.new(0, r * 0.3, 0), r, M.Basalt)
			if rng:NextNumber() < 0.5 then
				t:FillCylinder(CFrame.new(pos + Vector3.new(0, r * 1.4, 0)), r * 2.2, r * 0.45, M.Basalt)
			end
			rocks += 1
		end
	end

	-- tall cave walls all around, and far cliffs beyond them
	local function wall(x, z)
		local h = rng:NextNumber(30, 55)
		t:FillCylinder(CFrame.new(x, h / 2, z), h, rng:NextNumber(10, 16), M.Basalt)
		t:FillBall(Vector3.new(x + rng:NextNumber(-5, 5), h, z + rng:NextNumber(-5, 5)), rng:NextNumber(7, 11), M.Basalt)
	end
	for x = -half.X - 10, half.X + 10, 14 do
		wall(x, -half.Y - 22 - rng:NextNumber(0, 8))
		wall(x, half.Y + 22 + rng:NextNumber(0, 8))
	end
	for z = -half.Y - 10, half.Y + 10, 14 do
		wall(-half.X - 22 - rng:NextNumber(0, 8), z)
		wall(half.X + 22 + rng:NextNumber(0, 8), z)
	end
	mountain(Vector3.new(-240, 0, -270), 150, 160, M.Basalt, nil)
	mountain(Vector3.new(230, 0, -280), 170, 190, M.Basalt, nil)
	mountain(Vector3.new(320, 0, 140), 130, 140, M.Basalt, nil)
	mountain(Vector3.new(-320, 0, 170), 120, 130, M.Basalt, nil)

	t:SetMaterialColor(M.Slate, Color3.fromRGB(70, 74, 100))
	t:SetMaterialColor(M.Basalt, Color3.fromRGB(56, 52, 80))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(120, 118, 140))
	t.WaterColor = Color3.fromRGB(60, 200, 230)
	t.WaterTransparency = 0.35
	t.WaterWaveSize = 0.03
	t.WaterReflectance = 0.4
	applyLooks("Crystal")
	map:SetAttribute("GroundTheme", "Crystal")
end

-------------------------------------------------------------------------------
-- The Outpost: a sunny meadow plateau with a dirt plaza, a cobbled ring road and hills around
-------------------------------------------------------------------------------
function TerrainBuilder.Outpost(c)
	local t = terrain()
	local rng = rngFor(3)
	t:FillBlock(CFrame.new(c + Vector3.new(0, 60, 0)), Vector3.new(420, 140, 420), M.Air)
	t:FillBlock(CFrame.new(c + Vector3.new(0, -6, 0)), Vector3.new(420, 12, 420), M.Grass)
	-- the plaza: packed dirt with a cobbled ring road and four cobbled spokes
	-- (dig the top layer out first: a new material only replaces voxels that are empty)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4, 30, M.Air)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4, 30, M.Cobblestone)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4.2, 26, M.Air)
	t:FillCylinder(CFrame.new(c + Vector3.new(0, -2, 0)), 4, 26, M.Ground)
	for _, d in { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		t:FillBlock(CFrame.lookAt(c + d * 40 + Vector3.new(0, -0.7, 0), c + d * 60 + Vector3.new(0, -0.7, 0)), Vector3.new(8, 2.6, 22),
			M.Cobblestone)
	end
	-- Light flagstones lead from spawn to the portal between painted cobbled shoulders.
	local lane = CFrame.new(c + Vector3.new(0, -2, 4))
	t:FillBlock(lane, Vector3.new(16, 4, 64), M.Air)
	t:FillBlock(lane, Vector3.new(16, 4, 64), M.Cobblestone)
	t:FillBlock(lane, Vector3.new(8, 4, 64), M.Air)
	t:FillBlock(lane, Vector3.new(8, 4, 64), M.Limestone)
	-- a few mossy rocks and soft hills all around, higher further out
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(40, 56)
		local pos = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		t:FillBall(pos + Vector3.new(0, 0.5, 0), rng:NextNumber(1.8, 3.2), M.Rock)
	end
	for i = 0, 40 do
		local a = i / 40 * math.pi * 2
		local d = rng:NextNumber(86, 100)
		local h = rng:NextNumber(14, 30)
		t:FillBall(c + Vector3.new(math.cos(a) * d, h * 0.2, math.sin(a) * d), h, M.Grass)
		if rng:NextNumber() < 0.3 then
			t:FillBall(c + Vector3.new(math.cos(a) * (d + 6), h * 0.7, math.sin(a) * (d + 6)), h * 0.4, M.Rock)
		end
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.3
		mountain(c + Vector3.new(math.cos(a) * 170, 0, math.sin(a) * 170), 70, rng:NextNumber(40, 70), M.Grass, nil)
	end
end

-------------------------------------------------------------------------------
-- The Watch Keep (the new Outpost): a flat courtyard of packed earth inside the walls, a cobbled avenue from the
-- spawn to the gate and a round cobbled plaza; grass outside, hills and mountains behind as the skyline.
-- Smooth materials only where people walk and stand (see GroundLooks).
-------------------------------------------------------------------------------
function TerrainBuilder.Keep(c)
	local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
	local t = terrain()
	local rng = rngFor(5)
	t:FillBlock(CFrame.new(c + Vector3.new(0, 60, 0)), Vector3.new(460, 140, 460), M.Air)
	t:FillBlock(CFrame.new(c + Vector3.new(0, -6, 0)), Vector3.new(460, 12, 460), M.Grass)
	-- a new material only replaces empty voxels: dig the top layer out first, then fill it
	local function surface(cframe, size, material)
		t:FillBlock(cframe, size, M.Air)
		t:FillBlock(cframe, size, material)
	end
	local size = HubLayout.Size
	-- the courtyard stays bright meadow grass (an earth floor read as one big orange-red stain on the phone)
	local avenue = HubLayout.Avenue
	local mid = c + (avenue.From + avenue.To) / 2
	surface(CFrame.lookAt(mid + Vector3.new(0, -2, 0), c + avenue.To + Vector3.new(0, -2, 0)),
		Vector3.new(avenue.Width, 4, (avenue.From - avenue.To).Magnitude), M.Cobblestone)
	t:FillCylinder(CFrame.new(c + HubLayout.Plaza.At + Vector3.new(0, -2, 0)), 4, HubLayout.Plaza.Radius, M.Air)
	t:FillCylinder(CFrame.new(c + HubLayout.Plaza.At + Vector3.new(0, -2, 0)), 4, HubLayout.Plaza.Radius, M.Cobblestone)
	-- the forecourt of the Beacon Tower (pads and showcase stand on stone) and a path to every station
	surface(CFrame.new(c + Vector3.new(0, -2, -24)), Vector3.new(76, 4, 30), M.Cobblestone)
	for _, s in HubLayout.Stations do
		local station = Vector3.new(s.At.X, 0, s.At.Z)
		local inward = -station.Unit
		local ringAt = station + inward * (s.RingOffset or HubLayout.RingOffset)
		local from = HubLayout.Plaza.At + (ringAt - HubLayout.Plaza.At).Unit * (HubLayout.Plaza.Radius - 2)
		local to = station
		surface(CFrame.lookAt(c + (from + to) / 2 + Vector3.new(0, -2, 0), c + to + Vector3.new(0, -2, 0)),
			Vector3.new(HubLayout.PathWidth, 4, (to - from).Magnitude), M.Cobblestone)
	end
	-- rolling hills outside the walls, higher further out, and a ring of mountains as the far skyline
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(85, 150)
		local h = rng:NextNumber(10, 22) * (d / 110)
		t:FillBall(c + Vector3.new(math.cos(a) * d, h * 0.15, math.sin(a) * d), h, M.Grass)
		if rng:NextNumber() < 0.35 then
			t:FillBall(c + Vector3.new(math.cos(a) * (d + 8), h * 0.65, math.sin(a) * (d + 8)), h * 0.4, M.Rock)
		end
	end
	-- rock cliffs breaking the hills behind the woods, so no bald hill shows over the wall
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local d = rng:NextNumber(100, 135)
		local h = rng:NextNumber(26, 44)
		t:FillBall(c + Vector3.new(math.cos(a) * d, h * 0.35, math.sin(a) * d), h * 0.55, M.Rock)
		t:FillBall(c + Vector3.new(math.cos(a) * (d + 10), h * 0.2, math.sin(a) * (d + 10)), h * 0.6, M.Grass)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.4
		mountain(c + Vector3.new(math.cos(a) * 240, 0, math.sin(a) * 230), rng:NextNumber(70, 100), rng:NextNumber(60, 95), M.Grass, nil)
	end
	TerrainBuilder.OutpostLooks()
end

-- painted looks for the Outpost's materials (while the players are in the hub)
function TerrainBuilder.OutpostLooks()
	local t = terrain()
	t:SetMaterialColor(M.Grass, Color3.fromRGB(96, 140, 70))
	t:SetMaterialColor(M.Ground, Color3.fromRGB(170, 130, 92))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(130, 124, 114))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(110, 112, 104))
	applyLooks("Outpost")
end

return TerrainBuilder
