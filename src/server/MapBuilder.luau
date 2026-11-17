-- Builds the Cursed Forest map out of simple parts when the game starts,
-- so nothing has to be built by hand yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

-- how far a point is from the path (used to keep trees off it)
local function distanceToPath(pos)
	local best = math.huge
	local pts = Config.Path
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local t = math.clamp((pos - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		best = math.min(best, (pos - (a + (b - a) * t)).Magnitude)
	end
	return best
end

MapBuilder.DistanceToPath = distanceToPath

function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	-- dark forest floor
	part({
		Name = "Ground",
		Size = Vector3.new(240, 2, 180),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(45, 70, 40),
		Material = Enum.Material.Grass,
		Parent = map,
	})

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

	-- invisible waypoints (handy to see the path in the Explorer)
	local waypoints = Instance.new("Folder")
	waypoints.Name = "Waypoints"
	waypoints.Parent = map
	for i, pos in points do
		part({
			Name = tostring(i),
			Size = Vector3.new(1, 1, 1),
			Position = pos + Vector3.new(0, 0.5, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = waypoints,
		})
	end

	-- goblin camp at the start
	part({
		Name = "GoblinCamp",
		Size = Vector3.new(12, 6, 12),
		Position = points[1] + Vector3.new(-10, 3, 0),
		Color = Color3.fromRGB(80, 50, 30),
		Material = Enum.Material.Wood,
		Parent = map,
	})

	-- the magic portal at the end (a glowing purple disc standing up)
	local portal = part({
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(points[#points] + Vector3.new(4, 8, 0)),
		Color = Color3.fromRGB(140, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		Parent = map,
	})
	portal:SetAttribute("Health", Config.PortalHealth)

	-- simple trees so it looks like a forest
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = map
	local rng = Random.new(7)
	local placed = 0
	while placed < 60 do
		local pos = Vector3.new(rng:NextNumber(-115, 115), 0, rng:NextNumber(-85, 85))
		if distanceToPath(pos) > Config.PathWidth + 4 then
			local h = rng:NextNumber(8, 14)
			part({
				Name = "Trunk",
				Size = Vector3.new(2, h, 2),
				Position = pos + Vector3.new(0, h / 2, 0),
				Color = Color3.fromRGB(70, 45, 30),
				Material = Enum.Material.Wood,
				Parent = trees,
			})
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(9, 9, 9),
				Position = pos + Vector3.new(0, h + 2, 0),
				Color = Color3.fromRGB(30, 60 + rng:NextInteger(0, 30), 35),
				Material = Enum.Material.Grass,
				Parent = trees,
			})
			placed += 1
		end
	end

	return map
end

return MapBuilder
