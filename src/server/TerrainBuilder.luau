-- Real terrain for the battlefields (6A world guide): ground with height and no edge, cliff walls around the
-- play area, a backdrop on the horizon, sunken lava, a bordered path. Gameplay still uses the invisible
-- Ground/Path parts of MapBuilder for clicks; this only shapes what you see.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")
local Config = require(ReplicatedStorage.Shared.Config)
local ArtService = require(script.Parent.ArtService)

local TerrainBuilder = {}
local M = Enum.Material

local function terrain()
	return workspace.Terrain
end

-- deterministic random so every server builds the same map
local function rngFor(seed)
	return Random.new(seed)
end

-- a strip along each path segment
local function pathStrip(width, material, y, height)
	local t = terrain()
	local points = Config.Path
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude + width
		t:FillBlock(CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, y, 0), Vector3.new(width, height, length), material)
	end
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

-- gives a terrain material our painted texture (art/textures, the same set the models use).
-- The MaterialVariants live in the place file (src/materials, scripts can't make them): HTD_<texture>.
-- Returns true when it worked; the material then shows the painting instead of Roblox's own look.
local overridden = {}
local function paintedTerrain(material, textureName)
	local variant = MaterialService:FindFirstChild("HTD_" .. textureName)
	if not variant then
		return false
	end
	local ok, err = pcall(function()
		MaterialService:SetBaseMaterialOverride(material, variant.Name)
	end)
	if ok then
		overridden[material] = true
	else
		warn("Art: painted terrain off for " .. material.Name .. ": " .. tostring(err))
	end
	return ok
end

-- Old looks are only dropped once the new set is known (see applyLooks): clearing an override and setting it
-- again in the same moment left the grass plain white.
function TerrainBuilder.ResetLooks() end

-- switches the painted looks to this set: { [material] = texture name }. Materials not in the set go back
-- to Roblox's own look. Returns nothing; painted materials get a white tint (the painting has its colours).
local function applyLooks(looks)
	local t = terrain()
	for material in overridden do
		if not looks[material] then
			pcall(function()
				MaterialService:SetBaseMaterialOverride(material, "")
			end)
			overridden[material] = nil
		end
	end
	for material, texture in looks do
		if paintedTerrain(material, texture) then
			t:SetMaterialColor(material, Color3.new(1, 1, 1))
		end
	end
end

-- wipes the battlefield's terrain only (the Outpost has its own terrain far away and keeps it)
local function clearBattlefield()
	terrain():FillBlock(CFrame.new(0, 100, 0), Vector3.new(980, 280, 980), M.Air)
end

local function farFromPath(pos, margin)
	return Config.DistanceToPath(pos) > Config.PathWidth / 2 + margin
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
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Basalt)
	-- lighter ash patches so the floor isn't one flat colour
	for _ = 1, 40 do
		-- flat discs that only recolour the surface (balls made grey bumps)
		local pos = Vector3.new(rng:NextNumber(-half.X, half.X), -1, rng:NextNumber(-half.Y, half.Y))
		t:FillCylinder(CFrame.new(pos), 2, rng:NextNumber(5, 10), M.Slate)
	end

	-- the path: a cobbled border with packed ground inside, so it reads at a glance
	-- (grey cobbles inside a dark basalt kerb: the path never looks like lava on this red map)
	pathStrip(Config.PathWidth + 5, M.Slate, -1.2, 2.6)
	pathStrip(Config.PathWidth, M.Cobblestone, -1.0, 2.4)

	-- lava pools sunk into the ground, kept away from the path and from building spots near it
	local pools = 0
	local tries = 0
	while pools < 7 and tries < 400 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 14, half.X - 14), 0, rng:NextNumber(-half.Y + 14, half.Y - 14))
		if farFromPath(pos, 22) and (pos - Config.SpawnPoint).Magnitude > 24 and (pos - camp).Magnitude > 24 then
			local r = rng:NextNumber(7, 11)
			t:FillBall(pos + Vector3.new(0, 1, 0), r, M.Air) -- dig the hollow
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -3.5, 0)), 3, r * 0.85, M.CrackedLava)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.2, 0)), 1.6, r + 1.5, M.Basalt) -- dark rim
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.4, 0)), 2.2, r * 0.8, M.Air)
			-- warm light and a few rising embers
			local glow = Instance.new("Part")
			glow.Name = "LavaGlow"
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.Transparency = 1
			glow.Size = Vector3.one
			glow.Position = pos + Vector3.new(0, 1, 0)
			glow.Parent = map
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 120, 40)
			light.Range = r * 2.2
			light.Brightness = 1.6
			light.Parent = glow
			local embers = Instance.new("ParticleEmitter")
			embers.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
			embers.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 20))
			embers.LightEmission = 1
			embers.Rate = 4
			embers.Lifetime = NumberRange.new(2, 3.5)
			embers.Speed = NumberRange.new(2, 5)
			embers.SpreadAngle = Vector2.new(25, 25)
			embers.Size = NumberSequence.new(0.35, 0)
			embers.Acceleration = Vector3.new(0, 1.5, 0)
			embers.Parent = glow
			pools += 1
		end
	end

	-- basalt boulders that give the floor shape (never on the path or the spawn)
	local rocks = 0
	tries = 0
	while rocks < 26 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
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
	applyLooks({ [M.Basalt] = "t_ash", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble",
		[M.Rock] = "t_cliff", [M.Slate] = "basalt", [M.CrackedLava] = "lava_rock" })
end

-------------------------------------------------------------------------------
-- Cursed Forest
-------------------------------------------------------------------------------
function TerrainBuilder.Forest(map, camp)
	local t = terrain()
	clearBattlefield()
	local rng = rngFor(7)
	local half = Config.MapSize / 2

	-- a meadow with no edge in sight (top at y = 0), bare soil patches
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Grass)
	for _ = 1, 30 do
		local pos = Vector3.new(rng:NextNumber(-half.X, half.X), -1, rng:NextNumber(-half.Y, half.Y))
		if farFromPath(pos, 6) then
			t:FillCylinder(CFrame.new(pos), 2, rng:NextNumber(2.5, 5), M.Mud)
		end
	end

	-- the path: packed sandy dirt inside a cobbled kerb (leafy soil read as a red carpet in the violet light)
	pathStrip(Config.PathWidth + 5, M.Cobblestone, -1.2, 2.6)
	pathStrip(Config.PathWidth, M.Ground, -1.0, 2.4)

	-- a few still ponds away from the path
	local ponds, tries = 0, 0
	while ponds < 3 and tries < 400 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 16, half.X - 16), 0, rng:NextNumber(-half.Y + 16, half.Y - 16))
		if farFromPath(pos, 22) and (pos - Config.SpawnPoint).Magnitude > 24 and (pos - camp).Magnitude > 24 then
			local r = rng:NextNumber(7, 10)
			t:FillBall(pos + Vector3.new(0, 1, 0), r, M.Air)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -3, 0)), 2, r * 0.9, M.Mud)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.2, 0)), 1.6, r + 1.5, M.Cobblestone) -- stony rim
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.3, 0)), 1.8, r * 0.85, M.Water)
			ponds += 1
		end
	end

	-- mossy boulders
	local rocks = 0
	tries = 0
	while rocks < 22 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
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
	applyLooks({ [M.Grass] = "t_grass", [M.Mud] = "t_forest_dirt", [M.Ground] = "t_ground",
		[M.Cobblestone] = "t_cobble", [M.Rock] = "t_moss_rock" })
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

	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(900, 12, 900), M.Slate)
	-- the path: smooth cobbles inside a dark rock kerb
	pathStrip(Config.PathWidth + 5, M.Basalt, -1.2, 2.6)
	pathStrip(Config.PathWidth, M.Cobblestone, -1.0, 2.4)

	-- glowing pools
	local pools, tries = 0, 0
	while pools < 5 and tries < 400 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 14, half.X - 14), 0, rng:NextNumber(-half.Y + 14, half.Y - 14))
		if farFromPath(pos, 20) and (pos - Config.SpawnPoint).Magnitude > 24 and (pos - camp).Magnitude > 24 then
			local r = rng:NextNumber(6, 9)
			t:FillBall(pos + Vector3.new(0, 1, 0), r, M.Air)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -3, 0)), 2, r * 0.9, M.Slate)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.2, 0)), 1.6, r + 1.5, M.Basalt)
			t:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.3, 0)), 1.8, r * 0.85, M.Water)
			local glow = Instance.new("Part")
			glow.Name = "PoolGlow"
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.Transparency = 1
			glow.Size = Vector3.one
			glow.Position = pos
			glow.Parent = map
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(90, 220, 255)
			light.Range = r * 2.4
			light.Brightness = 1.5
			light.Parent = glow
			pools += 1
		end
	end

	-- rock spires on the floor
	local rocks = 0
	tries = 0
	while rocks < 18 and tries < 600 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 6, half.X - 6), 0, rng:NextNumber(-half.Y + 6, half.Y - 6))
		if farFromPath(pos, 10) and (pos - Config.SpawnPoint).Magnitude > 16 and (pos - camp).Magnitude > 16 then
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
	applyLooks({ [M.Slate] = "t_cave_floor", [M.Basalt] = "t_cave_wall", [M.Cobblestone] = "t_cobble" })
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

-- painted looks for the Outpost's materials (while the players are in the hub)
function TerrainBuilder.OutpostLooks()
	local t = terrain()
	t:SetMaterialColor(M.Grass, Color3.fromRGB(96, 140, 70))
	t:SetMaterialColor(M.Ground, Color3.fromRGB(170, 130, 92))
	t:SetMaterialColor(M.Cobblestone, Color3.fromRGB(130, 124, 114))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(110, 112, 104))
	applyLooks({ [M.Grass] = "t_grass", [M.Ground] = "t_ground", [M.Cobblestone] = "t_cobble",
		[M.Rock] = "t_moss_rock" })
end

return TerrainBuilder
