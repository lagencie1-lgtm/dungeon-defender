-- Builds the Cursed Forest map out of simple parts when the game starts,
-- so nothing has to be built by hand yet.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function setupLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 60, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 80, 110)
	Lighting.FogColor = Color3.fromRGB(40, 35, 60)
	Lighting.FogStart = 120
	Lighting.FogEnd = 400
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(110, 90, 140)
		atmosphere.Decay = Color3.fromRGB(60, 40, 80)
		atmosphere.Glare = 0
		atmosphere.Haze = 2
		atmosphere.Parent = Lighting
	end
end

function MapBuilder.Build()
	-- remove the default Baseplate / SpawnLocation if the place has them
	for _, name in { "Baseplate", "SpawnLocation", "Map" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	setupLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	-- dark forest floor
	part({
		Name = "Ground",
		Size = Vector3.new(Config.MapSize.X, 2, Config.MapSize.Y),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(45, 70, 40),
		Material = Enum.Material.Grass,
		Parent = map,
	})
	-- invisible walls so nobody falls off the edge
	local half = Config.MapSize / 2
	for _, w in {
		{ Vector3.new(half.X, 20, 0), Vector3.new(2, 40, Config.MapSize.Y) },
		{ Vector3.new(-half.X, 20, 0), Vector3.new(2, 40, Config.MapSize.Y) },
		{ Vector3.new(0, 20, half.Y), Vector3.new(Config.MapSize.X, 40, 2) },
		{ Vector3.new(0, 20, -half.Y), Vector3.new(Config.MapSize.X, 40, 2) },
	} do
		part({ Name = "Wall", Position = w[1], Size = w[2], Transparency = 1, CanQuery = false, Parent = map })
	end

	-- the dirt path, one piece between each pair of points
	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "Path"
	pathFolder.Parent = map
	local points = Config.Path
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude + Config.PathWidth
		part({
			Name = "Segment" .. i,
			Size = Vector3.new(Config.PathWidth, 0.2, length),
			CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.1, 0),
			Color = Color3.fromRGB(110, 85, 55),
			Material = Enum.Material.Ground,
			CanCollide = false,
			Parent = pathFolder,
		})
	end

	-- goblin camp at the start: a hut with a spiky fence
	local camp = points[1] + Vector3.new(-12, 0, 0)
	part({ Name = "CampHut", Size = Vector3.new(12, 7, 12), Position = camp + Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(80, 50, 30), Material = Enum.Material.Wood, Parent = map })
	part({ ClassName = "WedgePart", Name = "CampRoof", Size = Vector3.new(13, 4, 7),
		CFrame = CFrame.new(camp + Vector3.new(0, 9, 3.25)), Color = Color3.fromRGB(60, 40, 25),
		Material = Enum.Material.WoodPlanks, Parent = map })
	part({ ClassName = "WedgePart", Name = "CampRoof", Size = Vector3.new(13, 4, 7),
		CFrame = CFrame.new(camp + Vector3.new(0, 9, -3.25)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.WoodPlanks, Parent = map })
	local fire = part({ Name = "CampFire", Size = Vector3.new(2, 1, 2), Position = camp + Vector3.new(8, 0.5, 9),
		Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, Parent = map })
	Instance.new("Fire", fire).Size = 4

	-- the magic portal at the end (a glowing purple ring standing up)
	local portalPos = points[#points] + Vector3.new(4, 9, 0)
	local portal = part({
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(portalPos),
		Color = Color3.fromRGB(140, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = map,
	})
	local glow = Instance.new("PointLight")
	glow.Color = portal.Color
	glow.Range = 30
	glow.Brightness = 3
	glow.Parent = portal
	for _, z in { -9, 9 } do
		part({ Name = "PortalPillar", Size = Vector3.new(3, 20, 3), Position = points[#points] + Vector3.new(4, 10, z),
			Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Slate, Parent = map })
	end

	-- the place where players appear
	local spawn = part({
		ClassName = "SpawnLocation",
		Name = "HeroSpawn",
		Size = Vector3.new(8, 1, 8),
		Position = Config.SpawnPoint + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 170, 80),
		Material = Enum.Material.Marble,
		Parent = map,
	})
	spawn.Duration = 0

	-- simple trees so it looks like a forest (kept off the path and the spawn)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = map
	local rng = Random.new(7)
	local placed = 0
	while placed < 70 do
		local pos = Vector3.new(rng:NextNumber(-half.X + 5, half.X - 5), 0, rng:NextNumber(-half.Y + 5, half.Y - 5))
		local farFromThings = Config.DistanceToPath(pos) > Config.PathWidth + 6
			and (pos - Config.SpawnPoint).Magnitude > 14
			and (pos - camp).Magnitude > 14
		if farFromThings then
			local h = rng:NextNumber(8, 15)
			local dead = rng:NextNumber() < 0.25 -- some dead, leafless trees
			part({
				Name = "Trunk",
				Size = Vector3.new(2, h, 2),
				Position = pos + Vector3.new(0, h / 2, 0),
				Color = Color3.fromRGB(70, 45, 30),
				Material = Enum.Material.Wood,
				Parent = trees,
			})
			if not dead then
				local s = rng:NextNumber(7, 11)
				part({
					Name = "Leaves",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(s, s, s),
					Position = pos + Vector3.new(0, h + 2, 0),
					Color = Color3.fromRGB(30 + rng:NextInteger(0, 20), 55 + rng:NextInteger(0, 30), 40),
					Material = Enum.Material.Grass,
					Parent = trees,
				})
			end
			placed += 1
		end
	end

	-- folders the game fills while you play
	for _, name in { "Towers", "Enemies", "Effects" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end

	return map
end

return MapBuilder
