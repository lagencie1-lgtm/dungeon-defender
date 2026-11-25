-- Builds the world out of simple parts: the battlefield for the chosen map
-- (Cursed Forest or Magma Fortress) and The Outpost, the hub where runs start.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local ArtService = require(script.Parent.ArtService)
local MapLayouts = require(script.Parent.MapLayouts)
local MapOutline = require(ReplicatedStorage.Shared.MapOutline)
local MapKit = require(script.Parent.MapKit)
local Ground = require(ReplicatedStorage.Shared.Ground)

-- puts a Blender model (from ArtService) into the map, scaled to `height`, standing on `cframe`
-- (its front facing the cframe's look direction). Returns the model, or nil when it isn't loaded yet.
-- painted wood and leaves are matte (Lemp 2026-11-25: the trees looked like bubble gum; the smooth plastic every
-- model gets put white shine spots on their crowns, art/STYLE.md: "never glossy 3D-render plastic")
local MATTE = { tree_oak = true, tree_dead = true, keep_field_bush = true }

local function placeModel(parent, name, cframe, height)
	local template = ArtService.Model(name)
	if not template then
		return nil
	end
	local look = template:Clone()
	if MATTE[name] then
		for _, p in look:GetDescendants() do
			if p:IsA("MeshPart") and p.Material ~= Enum.Material.Neon then
				p.Material = Enum.Material.Fabric
				p.Reflectance = 0
			end
		end
	end
	local _, size = look:GetBoundingBox()
	look:ScaleTo(look:GetScale() * height / size.Y)
	-- stand the bottom centre on the spot, then turn it to face the right way
	local box, newSize = look:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, newSize.Y / 2, 0)
	local offset = look:GetPivot().Position - bottom
	look:PivotTo(cframe * CFrame.new(offset))
	for _, p in look:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	look.Parent = parent
	return look
end

-- puts a map kit piece (MapKit) with its own origin on `origin` (front along its look direction), at its true
-- size. Returns the model, or nil when it isn't loaded.
local function placeKit(parent, name, origin)
	local template = ArtService.Model(name)
	local box = MapKit.Boxes[name]
	if not template or not box then
		return nil
	end
	local look = template:Clone()
	local _, size = look:GetBoundingBox()
	look:ScaleTo(look:GetScale() * (box.Max.Y - box.Min.Y) / size.Y)
	-- the model's box centre goes where the measured box centre lies in the piece's own space
	local now = look:GetBoundingBox()
	local pivot = look:GetPivot()
	look:PivotTo(origin * CFrame.new((box.Min + box.Max) / 2) * CFrame.new(pivot.Position - now.Position))
	for _, p in look:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			-- the picture never collides or stops a tap; MapKit.Solid says what is solid
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	look.Parent = parent
	return look
end

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

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function nameTag(parentPart, text, color, height)
	local gui = Instance.new("BillboardGui")
	-- 6A: short labels that only show up close, never a wall of floating signs
	gui.Size = UDim2.fromOffset(150, 28)
	gui.StudsOffset = Vector3.new(0, height or 6, 0)
	gui.MaxDistance = 26
	gui.Parent = parentPart
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = gui
end

local function setupLighting(theme)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Glare = 0
		atmosphere.Haze = 2
		atmosphere.Parent = Lighting
	end
	Lighting:SetAttribute("Theme", theme)
	Lighting.Brightness = 2
	-- no mirror-like sky reflections: they made faceted rocks flash white (painted look stays matte)
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	atmosphere.Offset = 0
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	-- 6A: maps stay bright and readable on a phone; mood comes from colour, not darkness
	Lighting.ExposureCompensation = 0.25
	if theme == "Outpost" then
		-- the hub: a warm, sunny late afternoon (the first thing a player sees)
		-- the Watch Keep: bright warm daylight, the sun high enough that the walls don't shade the courtyard
		-- (the top hubs are all bright and saturated; benchmark.md point 6)
		local keep = Config.HubVersion == "Keep"
		Lighting.ClockTime = keep and 14.4 or 15.2
		Lighting.Brightness = keep and 2.6 or 2
		Lighting.ExposureCompensation = keep and 0.18 or 0.08
		Lighting.ColorShift_Top = Color3.fromRGB(20, 12, 6)
		Lighting.Ambient = keep and Color3.fromRGB(150, 142, 132) or Color3.fromRGB(140, 135, 130)
		Lighting.OutdoorAmbient = keep and Color3.fromRGB(178, 170, 158) or Color3.fromRGB(165, 160, 150)
		Lighting.FogColor = Color3.fromRGB(190, 200, 220)
		atmosphere.Density = keep and 0.24 or 0.28
		atmosphere.Offset = 0.05
		atmosphere.Color = Color3.fromRGB(215, 205, 190)
		atmosphere.Decay = Color3.fromRGB(150, 160, 190)
		atmosphere.Haze = 1.4
		atmosphere.Glare = 0.4
	elseif theme == "Crystal" then
		-- moonlit cavern: bright cool moonlight and strong ambient so the dark rock stays readable on a phone
		Lighting.ClockTime = 0
		Lighting.Brightness = 3.4
		Lighting.ExposureCompensation = 0.7
		Lighting.ColorShift_Top = Color3.fromRGB(9, 14, 24)
		Lighting.Ambient = Color3.fromRGB(170, 170, 220)
		Lighting.OutdoorAmbient = Color3.fromRGB(190, 185, 235)
		Lighting.FogColor = Color3.fromRGB(20, 20, 45)
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(90, 100, 180)
		atmosphere.Decay = Color3.fromRGB(30, 30, 80)
	elseif theme == "Magma" then
		-- volcanic dusk: red-orange haze on the horizon, bright warm light on the action
		-- (a low sun at full strength blew the faces turned to it out to white: softer, warmer sun, more ambient)
		Lighting.ClockTime = 16.2
		Lighting.Brightness = 2.1
		Lighting.ExposureCompensation = 0.3
		Lighting.ColorShift_Top = Color3.fromRGB(22, 11, 4)
		Lighting.Ambient = Color3.fromRGB(150, 136, 130)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 158, 148)
		Lighting.FogColor = Color3.fromRGB(80, 30, 20)
		-- thick ash haze turns the whole sky orange-red (no plain blue sky over a volcano)
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(255, 165, 110)
		atmosphere.Decay = Color3.fromRGB(140, 60, 40)
		atmosphere.Glare = 0.6
		atmosphere.Haze = 2.5
	else
		-- the Cursed Forest in the hub's bright daylight family (the hub is the target exposure on a phone); the curse
		-- is carried by colour: a violet haze on the horizon and violet fog, never by darkness (cycle 6 film: muddy)
		Lighting.ClockTime = 14.6
		Lighting.ColorShift_Top = Color3.fromRGB(20, 12, 6)
		Lighting.Brightness = 2.7
		Lighting.ExposureCompensation = 0.45 -- measured: the battle still read 17% darker than the hub (cycle 8)
		Lighting.Ambient = Color3.fromRGB(152, 146, 150)
		Lighting.OutdoorAmbient = Color3.fromRGB(182, 175, 180)
		Lighting.FogColor = Color3.fromRGB(150, 120, 190)
		atmosphere.Density = 0.26
		atmosphere.Offset = 0.08
		atmosphere.Color = Color3.fromRGB(205, 185, 225)
		atmosphere.Decay = Color3.fromRGB(130, 100, 170)
		atmosphere.Haze = 1.6
		atmosphere.Glare = 0.3
	end
	Lighting.FogStart = 120
	Lighting.FogEnd = 400
end

-- invisible walls around a rectangle so nobody falls off
local function walls(parent, center, sizeX, sizeZ)
	local hx, hz = sizeX / 2, sizeZ / 2
	for _, w in {
		{ Vector3.new(hx, 20, 0), Vector3.new(2, 40, sizeZ) },
		{ Vector3.new(-hx, 20, 0), Vector3.new(2, 40, sizeZ) },
		{ Vector3.new(0, 20, hz), Vector3.new(sizeX, 40, 2) },
		{ Vector3.new(0, 20, -hz), Vector3.new(sizeX, 40, 2) },
	} do
		part({ Name = "Wall", Position = center + w[1], Size = w[2], Transparency = 1, CanQuery = false, Parent = parent })
	end
end

-------------------------------------------------------------------------------
-- decorations per theme
-------------------------------------------------------------------------------
local function forestDecor(parent, rng, pos)
	local h = rng:NextNumber(8, 15)
	part({ Name = "Trunk", Size = Vector3.new(2, h, 2), Position = pos + Vector3.new(0, h / 2, 0),
		Color = Color3.fromRGB(70, 45, 30), Material = Enum.Material.Wood, Parent = parent })
	if rng:NextNumber() > 0.25 then -- some trees are dead and leafless
		local s = rng:NextNumber(7, 11)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = pos + Vector3.new(0, h + 2, 0),
			Color = Color3.fromRGB(30 + rng:NextInteger(0, 20), 55 + rng:NextInteger(0, 30), 40),
			Material = Enum.Material.Grass, Parent = parent })
	end
end

local function crystalDecor(parent, rng, pos)
	-- a cluster of glowing crystals
	local colors = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 255, 210) }
	local color = colors[rng:NextInteger(1, #colors)]
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(4, 12)
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		part({ Name = "Crystal", Size = Vector3.new(rng:NextNumber(1.5, 3), h, rng:NextNumber(1.5, 3)),
			CFrame = CFrame.new(pos + offset + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Color = color, Material = Enum.Material.Neon, Transparency = 0.25, Parent = parent })
	end
	if rng:NextNumber() < 0.4 then
		local glow = part({ Name = "Glow", Size = Vector3.one * 0.5, Position = pos + Vector3.new(0, 3, 0), Transparency = 1,
			CanCollide = false, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = glow
	end
end

local function magmaDecor(parent, rng, pos)
	if rng:NextNumber() < 0.45 then
		-- a lava pool
		local r = rng:NextNumber(6, 12)
		local pool = part({ Name = "Lava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r, r),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = r * 1.5
		light.Parent = pool
		if rng:NextNumber() < 0.3 then
			Instance.new("Fire", pool).Size = 5
		end
	else
		-- a black rock spike
		local h = rng:NextNumber(6, 16)
		part({ Name = "Rock", ClassName = "WedgePart", Size = Vector3.new(rng:NextNumber(4, 8), h, rng:NextNumber(4, 8)),
			CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Color = Color3.fromRGB(35, 30, 35), Material = Enum.Material.Basalt, Parent = parent })
	end
end

-------------------------------------------------------------------------------
-- the battlefield
-------------------------------------------------------------------------------
function MapBuilder.BuildBattlefield(mapId)
	for _, name in { "Baseplate", "SpawnLocation", "Map" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local mapInfo = Config.SetMap(mapId)
	local magma = mapInfo.Theme == "Magma"
	local crystal = mapInfo.Theme == "Crystal"
	setupLighting(mapInfo.Theme)

	local map = folder("Map", workspace)
	-- (each map clears only its own terrain region: the Outpost keeps its own)
	local forest = not magma and not crystal
	local terrainLook = true -- every map is real terrain now (the Ground/Path parts stay for clicks)
	part({
		Transparency = terrainLook and 1 or 0,
		CanCollide = not terrainLook, -- heroes walk on the terrain itself
		Name = "Ground",
		Size = Vector3.new(Config.MapSize.X, 2, Config.MapSize.Y),
		Position = Vector3.new(0, -1, 0),
		Color = crystal and Color3.fromRGB(40, 40, 60) or magma and Color3.fromRGB(45, 35, 35) or Color3.fromRGB(45, 70, 40),
		Material = crystal and Enum.Material.Slate or magma and Enum.Material.Basalt or Enum.Material.Grass,
		Parent = map,
	})
	walls(map, Vector3.zero, Config.MapSize.X, Config.MapSize.Y)
	-- and inside the field's real outline (MapOutline): the rise beyond it is scenery. Heroes stop HeroStop studs
	-- short of it, so the camera behind them stays over the rise's first steps. (See-through and not solid for the
	-- camera: the follow camera only stops at things you can see.)
	local outline = MapOutline.For(mapInfo.Theme)
	local heroLine = outline and MapOutline.Inset(outline, MapOutline.HeroStop)
	for i, a in heroLine or {} do
		local b = heroLine[i % #heroLine + 1]
		local mid = (a + b) / 2 + Vector3.new(0, 28, 0)
		part({ Name = "Wall", Size = Vector3.new(2, 60, (b - a).Magnitude + 2),
			CFrame = CFrame.lookAt(mid, Vector3.new(b.X, mid.Y, b.Z)), Transparency = 1, CanQuery = false, Parent = map })
	end

	-- the path, one piece between each pair of points
	local pathFolder = folder("Path", map)
	local points = Config.Path
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		part({
			Name = "Segment" .. i,
			Size = Vector3.new(Config.PathWidth, 0.2, (b - a).Magnitude + Config.PathWidth),
			CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.1, 0),
			Color = crystal and Color3.fromRGB(80, 80, 105) or magma and Color3.fromRGB(95, 70, 60) or Color3.fromRGB(110, 85, 55),
			Material = magma and Enum.Material.Slate or Enum.Material.Ground,
			Transparency = terrainLook and 1 or 0,
			CanCollide = false,
			Parent = pathFolder,
		})
	end

	-- where the enemies come from
	local camp = points[1] + (points[1] - points[2]).Unit * 12
	if magma then
		TerrainBuilder.Magma(map, camp)
	elseif forest then
		TerrainBuilder.Forest(map, camp)
	else
		TerrainBuilder.Crystal(map, camp)
	end
	-- Fresh terrain is not ready for decor raycasts until it has reached the physics engine.
	task.wait(0.3)
	local gateFacing = CFrame.lookAt(camp, camp + (points[1] - camp).Unit)
	ArtService.WaitModel(magma and "map_gate" or crystal and "map_rift" or "map_camp", 8)
	ArtService.WaitModel("map_portal", 4)
	if magma and placeModel(map, "map_gate", gateFacing, 20) then
		-- the Blender demon gate (with a glow from its lava maw)
		local glowPart = part({ Name = "GateGlow", Size = Vector3.one, Position = camp + Vector3.new(0, 6, 0), Transparency = 1,
			CanCollide = false, Parent = map })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = 26
		light.Brightness = 2
		light.Parent = glowPart
	elseif crystal and placeModel(map, "map_rift", gateFacing, 20) then
		-- the Blender shadow rift, glowing violet
		local glowPart = part({ Name = "GateGlow", Size = Vector3.one, Position = camp + Vector3.new(0, 7, 0), Transparency = 1,
			CanCollide = false, Parent = map })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(170, 90, 255)
		light.Range = 26
		light.Brightness = 2
		light.Parent = glowPart
	elseif forest and placeModel(map, "map_camp", gateFacing, 19) then
		-- the Blender goblin camp gate, lit by its campfire
		local glowPart = part({ Name = "GateGlow", Size = Vector3.one, Position = camp + Vector3.new(0, 3, 0), Transparency = 1,
			CanCollide = false, Parent = map })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 70)
		light.Range = 22
		light.Brightness = 1.6
		light.Parent = glowPart
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = glowPart
		glowPart.Position = (gateFacing * CFrame.new(0, 1, -5)).Position
	elseif magma then
		part({ Name = "Gate", Size = Vector3.new(4, 16, 18), Position = camp + Vector3.new(0, 8, 0),
			Color = Color3.fromRGB(40, 35, 40), Material = Enum.Material.Basalt, Parent = map })
		local glow = part({ Name = "GateGlow", Size = Vector3.new(4.2, 10, 10), Position = camp + Vector3.new(0, 5, 0),
			Color = Color3.fromRGB(255, 90, 20), Material = Enum.Material.Neon, Parent = map })
		Instance.new("Fire", glow).Size = 8
	else
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
	end

	-- the magic portal at the end (a glowing purple ring standing up)
	local last, before = points[#points], points[#points - 1]
	local dir = (last - before).Unit
	-- the portal stands on the real ground: the last stretch climbs a rise on every map (MapLayouts)
	last += Vector3.new(0, (Ground.At(last.X + dir.X * 4, last.Z + dir.Z * 4)), 0)
	local portalPos = last + dir * 4 + Vector3.new(0, 9, 0)
	local portal = part({
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.lookAt(portalPos, portalPos + dir) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(140, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = map,
	})
	local glow = Instance.new("PointLight")
	glow.Color = portal.Color
	glow.Range = magma and 20 or 30
	glow.Brightness = magma and 1.4 or 3
	glow.Parent = portal
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local arch = placeModel(map, "map_portal", CFrame.lookAt(last + dir * 4, last + dir * 5), 22)
	if arch then
		-- the disc sits inside the stone ring
		portal.CFrame = CFrame.lookAt(last + dir * 4 + Vector3.new(0, 11.4, 0), last + dir * 5 + Vector3.new(0, 11.4, 0))
			* CFrame.Angles(0, math.pi / 2, 0)
		portal.Size = Vector3.new(0.6, 15.5, 15.5)
	end
	for _, k in arch and {} or { -9, 9 } do
		part({ Name = "PortalPillar", Size = Vector3.new(3, 20, 3), Position = last + dir * 4 + side * k + Vector3.new(0, 10, 0),
			Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Slate, Parent = map })
	end

	-- where players appear during a run
	local spawn = part({
		ClassName = "SpawnLocation",
		Name = "HeroSpawn",
		Size = Vector3.new(8, 1, 8),
		Position = Config.SpawnPoint + Vector3.new(0, (Ground.At(Config.SpawnPoint.X, Config.SpawnPoint.Z)) + 0.5, 0),
		Color = Color3.fromRGB(200, 170, 80),
		Material = Enum.Material.Marble,
		-- invisible: a gold marble square under the hero read as a placeholder in the top-down view (cycle 2)
		Transparency = 1,
		CanCollide = false,
		Enabled = false,
		Parent = map,
	})
	spawn.Duration = 0

	-- decorations, kept off the path and the spawn
	local decor = folder("Decor", map)
	local rng = Random.new(crystal and 23 or magma and 11 or 7)
	local half = Config.MapSize / 2
	local placed, tries = 0, 0
	while placed < (terrainLook and 0 or 70) and tries < 2000 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 5, half.X - 5), 0, rng:NextNumber(-half.Y + 5, half.Y - 5))
		if Config.DistanceToPath(pos) > Config.PathWidth + 6 and (pos - Config.SpawnPoint).Magnitude > 14
			and (pos - camp).Magnitude > 14 then
			if crystal then
				crystalDecor(decor, rng, pos)
			elseif magma then
				magmaDecor(decor, rng, pos)
			else
				forestDecor(decor, rng, pos)
			end
			placed += 1
		end
	end

	-- the forest's painted trees: a few inside the battlefield, a thick wood all around it
	if forest or crystal then
		ArtService.WaitModel(forest and "tree_oak" or "crystal_cluster", 8)
		ArtService.WaitModel("tree_dead", 2)
		local trees = folder("Trees", map)
		local treeRng = Random.new(77)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local function plant(pos, big)
			-- stand on the ground (hills too), never in water
			local hit = workspace:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
			if hit and hit.Material == Enum.Material.Water then
				return
			end
			pos = hit and hit.Position - Vector3.new(0, 0.5, 0) or pos
			local kind = crystal and "crystal_cluster" or treeRng:NextNumber() < 0.25 and "tree_dead" or "tree_oak"
			local h = crystal and (big and treeRng:NextNumber(14, 26) or treeRng:NextNumber(6, 11))
				or big and treeRng:NextNumber(22, 32) or treeRng:NextNumber(14, 20)
			placeModel(trees, kind, CFrame.new(pos) * CFrame.Angles(0, treeRng:NextNumber(0, math.pi * 2), 0), h)
		end
		local inside, outside, n = 0, 0, 0
		local layout = MapLayouts.For(mapInfo.Theme)
		-- (inside the field: MapLayouts groves only. Outside it: massed on the rise, below, when the map has an outline)
		local wantInside, wantOutside = 0, layout.Border and 0 or crystal and 45 or 70
		while (inside < wantInside or outside < wantOutside) and n < 3000 do
			n += 1
			local pos = Vector3.new(treeRng:NextNumber(-half.X - 40, half.X + 40), 0, treeRng:NextNumber(-half.Y - 40, half.Y + 40))
			local inPlay = math.abs(pos.X) < half.X and math.abs(pos.Z) < half.Y
			if inPlay and inside < wantInside and Config.DistanceToPath(pos) > Config.PathWidth + 10
				and MapLayouts.Open(layout, pos, 2)
				and (pos - Config.SpawnPoint).Magnitude > 18 and (pos - camp).Magnitude > 18 then
				plant(pos, false)
				inside += 1
			elseif not inPlay and outside < wantOutside then
				plant(pos, true)
				outside += 1
			end
		end
		local first = trees:GetChildren()[1]
		print("Map: forest trees", #trees:GetChildren(), "inside", inside, "outside", outside,
			first and first:GetFullName(), first and tostring(first:GetPivot().Position))
	end

	-- (no "trail marker" any more: it was five plain blocks standing alone on the floor, against the no-primitives
	-- rule and the clean-floor rule. The tests that looked for it now check the designed layout instead.)

	-- the enclosure: a wall of tall trees just outside the build area (dead trees on Magma), so the battlefield is a
	-- clearing with no empty horizon (the same rule as the hub's tree ring)
	task.spawn(function()
		local layout = MapLayouts.For(mapInfo.Theme)
		if layout.Border then
			-- A map with an outline: its wood (dead trees on Magma, crystals in the caves) is MASSED on the rise
			-- outside the outline, close together near the field and taller further up, and follows the map's
			-- shape. (Before: one ring of trees round a rectangle, and single ones dotted beyond it.)
			local kind = crystal and "crystal_cluster" or magma and "tree_dead" or "tree_oak"
			if not ArtService.WaitModel(kind, 30) then
				return
			end
			local Ground = require(ReplicatedStorage.Shared.Ground)
			local half = Config.MapSize / 2
			local rng = Random.new(77)
			local spacing = crystal and 10 or magma and 13 or 11
			local planted = 0
			for gx = -half.X - 44, half.X + 44, spacing do
				for gz = -half.Y - 44, half.Y + 44, spacing do
					local x = gx + rng:NextNumber(-0.35, 0.35) * spacing
					local z = gz + rng:NextNumber(-0.35, 0.35) * spacing
					local roll, size, turn, dead = rng:NextNumber(), rng:NextNumber(), rng:NextNumber(0, math.pi * 2), rng:NextNumber()
					local rise, out, face = MapLayouts.RiseAt(layout, x, z)
					if rise > 0 and out >= 3 and out <= 46 and roll < (out < 20 and 0.85 or out < 34 and 0.6 or 0.4) and planted < 170 then
						local y = Ground.At(x, z)
						-- (on the treads, not on a step's rock face; the gorges have no rise)
						if not face then
							local step = out < 10 and 1 or out < 20 and 2 or 3
							local height = crystal and (2 + step * 4 + size * (3 + step * 2))
								or magma and (18 + step * 2 + size * 10)
								or (14 + step * 4 + size * (6 + step * 2))
							local model = (forest and dead < 0.2) and "tree_dead" or kind
							local look = placeModel(decor, model, CFrame.new(x, y - 0.4, z) * CFrame.Angles(0, turn, 0), height)
							if look then
								look:SetAttribute("Tall", true) -- fades while it hides the hero (MapFade)
								-- scenery only: nothing walks there, and the follow camera must pass through it
								for _, p in look:GetDescendants() do
									if p:IsA("BasePart") then
										p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
									end
								end
							end
							planted += 1
							if planted % 10 == 0 then
								task.wait()
							end
						end
					end
				end
			end
			print("Map: massed on the rise", planted, kind)
			return
		end
		local treeModel = magma and "tree_dead" or (not crystal and "tree_oak") or nil
		if not treeModel or not ArtService.WaitModel(treeModel, 30) then
			return
		end
		local Ground = require(ReplicatedStorage.Shared.Ground)
		local half = Config.MapSize / 2
		local rng = Random.new(77)
		local perimeter = 2 * (half.X + half.Y) * 2
		local count = math.floor(perimeter / 14)
		for i = 1, count do
			local f = (i - 1) / count * perimeter
			local x, z
			if f < 2 * half.X then
				x, z = -half.X + f, -half.Y
			elseif f < 2 * half.X + 2 * half.Y then
				x, z = half.X, -half.Y + (f - 2 * half.X)
			elseif f < 4 * half.X + 2 * half.Y then
				x, z = half.X - (f - 2 * half.X - 2 * half.Y), half.Y
			else
				x, z = -half.X, half.Y - (f - 4 * half.X - 2 * half.Y)
			end
			-- pushed a little outward (never into the build area), never onto the path where it leaves the map
			local out = Vector3.new(x, 0, z).Unit * rng:NextNumber(4, 12)
			local pos = Vector3.new(x, 0, z) + out
			if Config.DistanceToPath(pos) > Config.PathWidth + 6 then
				pos = Vector3.new(pos.X, (Ground.At(pos.X, pos.Z)) - 0.4, pos.Z)
				placeModel(decor, treeModel, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
					rng:NextNumber(26, 38))
			end
			if i % 10 == 0 then
				task.wait()
			end
		end
	end)

	-- what stands on the field (MapLayouts): each piece is placed by hand for a reason and says honestly how much
	-- room it takes, so nothing can be built inside it (BlockRadius: TowerService.CanPlace and the build preview)
	task.spawn(function()
		local layout = MapLayouts.For(mapInfo.Theme)
		-- what a refused build says (research briefs: "every invalid placement must say why, in a reason the player
		-- can repeat"): the thing that is in the way, by name
		local WHY = {
			wall = "A wall is in the way", low = "A wall is in the way", face = "A wall is in the way",
			arch = "The gate is in the way", pillar = "A column is in the way", bridge = "The bridge is in the way",
			set_forest = "The standing stones are in the way", set_magma = "A fire is in the way",
			set_crystal = "A mine cart is in the way", stairs = "The stairs are in the way", tower = "The tower is in the way",
			furnace = "The furnace is in the way",
			keep_well = "The well is in the way", keep_field_bush = "A bush is in the way",
			keep_field_mushrooms = "Mushrooms are in the way", keep_field_ruin = "The ruin is in the way",
			tree_oak = "A tree is in the way", tree_dead = "A tree is in the way", crystal_cluster = "Crystals are in the way",
		}
		local function blocker(pos, r, why)
			local mark = part({ Name = "Blocked", Size = Vector3.one, Position = pos, Transparency = 1, CanCollide = false,
				CanQuery = false, CanTouch = false, Parent = decor })
			mark:SetAttribute("BlockRadius", r)
			if why then
				mark:SetAttribute("BlockWhy", why)
			end
		end
		local function stand(name, at, height, turn, block)
			if not ArtService.WaitModel(name, 30) then
				return nil
			end
			local y = (Ground.At(at.X, at.Z))
			local look = placeModel(decor, name, CFrame.new(at.X, y - 0.15, at.Z) * CFrame.Angles(0, turn or 0, 0), height)
			if look and block then
				look:SetAttribute("BlockRadius", block)
				look:SetAttribute("BlockWhy", WHY[name])
			end
			return look
		end
		-- the building kit: the picture at its true size, invisible boxes for what is solid in it, and build
		-- blockers along those boxes
		local themeKey = magma and "magma" or crystal and "crystal" or "forest"
		local function kit(piece, at, look, sink, height)
			local name = "mapkit_" .. piece .. "_" .. themeKey
			if not ArtService.WaitModel(name, 30) then
				return
			end
			-- on the ground where it stands, or at a given height (pieces built into the edge of raised ground)
			local y = height or ((Ground.At(at.X, at.Z)) - (sink or 0.05))
			local flat = Vector3.new(look.X, 0, look.Z).Unit
			local origin = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X, y, at.Z) + flat)
			local model = placeKit(decor, name, origin)
			if not model then
				return nil
			end
			-- tall pieces fade for a player while they hide that player's hero (client/MapFade)
			if MapKit.Boxes[name].Max.Y > 5 then
				model:SetAttribute("Tall", true)
			end
			local why = WHY[piece] or WHY[piece .. "_" .. themeKey]
			for _, solid in MapKit.Solid[piece] or MapKit.Solid[piece .. "_" .. themeKey] or {} do
				part({ Name = "Solid", Size = solid.Size, CFrame = origin * CFrame.new(solid.Centre), Transparency = 1,
					CanQuery = false, CanTouch = false, Parent = model })
				-- blockers every 3 studs along the box's long side
				local long = math.max(solid.Size.X, solid.Size.Z)
				local short = math.min(solid.Size.X, solid.Size.Z)
				local axis = solid.Size.X >= solid.Size.Z and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
				local count = math.max(1, math.ceil(long / 3))
				for i = 1, count do
					local along = (i - 0.5) / count * long - long / 2
					blocker((origin * CFrame.new(solid.Centre + axis * along)).Position, short / 2, why)
				end
			end
			return model, origin
		end
		-- Raised ground. Along each straight edge: a retaining wall whose flagstone rim covers the terrain's bevel
		-- (so the floor ends in stone and its height reads, also from straight above), a parapet on top where the
		-- layout asks for one, and flights of stairs that run along the wall. The pieces are built for ground raised
		-- 5: they sink a stud for 4. The wall line stands `WallOut` outside the edge, where the ground is 1 high.
		local wallOut = layout.WallOut or 1
		for _, p in layout.Plateaus do
			for _, side in { "N", "S", "W", "E" } do
				local start, along, length, out = MapLayouts.Edge(p, side)
				if length >= 8 and string.find(p.Walls or "NSEW", side, 1, true) then
					-- 12-stud pieces from end to end, overlapping where the edge is not a whole number of them
					local count = math.max(1, math.ceil((length - 1.5) / 12))
					for i = 1, count do
						local d = count == 1 and length / 2 or 6 + (length - 12) * (i - 1) / (count - 1)
						local at = start + along * d
						-- not where the lane climbs through this edge (a wall ALONG a lane, 9 studs off, stays)
						local clear = true
						for _, reach in { -5, 0, 5 } do
							clear = clear and Config.DistanceToPath(at + along * reach) > Config.PathWidth / 2 + 1
						end
						if clear then
							-- (every other piece stands a hair further out: two overlapping pieces never share a face)
							local line = at + out * (wallOut + i % 2 * 0.06)
							kit("face", line, out, nil, p.H - 5)
							if string.find(p.Parapet or "", side, 1, true) then
								kit("low", line - out * 0.9, out, nil, p.H + 0.15)
							end
						end
					end
					for _, st in p.Stairs or {} do
						if st.Side == side then
							local at = start + along * (4 + st.At * (length - 8)) + out * wallOut
							local _, origin = kit("stairs", at, out, nil, p.H - 5)
							if origin then
								-- what feet walk on: one smooth invisible ramp over the drawn steps (6A: stairs that walk
								-- smoothly), from the rim's level at the flight's top end down along the wall
								local top = (origin * CFrame.new(3.25, 5.05, -2.05)).Position
								local foot = (origin * CFrame.new(-3.25, 0.05, -2.05)).Position
								part({ Name = "StairRamp", Size = Vector3.new(2.8, 0.4, (top - foot).Magnitude),
									CFrame = CFrame.lookAt((top + foot) / 2 - Vector3.new(0, 0.2, 0), top - Vector3.new(0, 0.2, 0)),
									Transparency = 1, CanQuery = false, CanTouch = false, Parent = decor })
								blocker((origin * CFrame.new(1.8, 0, -2.05)).Position, 1.6, WHY.stairs)
								blocker((origin * CFrame.new(-1.8, 0, -2.05)).Position, 1.6, WHY.stairs)
							end
						end
					end
				end
			end
			task.wait()
		end
		for _, b in layout.Bridges or {} do
			-- the bridge model runs along its X: its front looks across the crossing
			kit("bridge", b.At, Vector3.new(b.Along.Z, 0, -b.Along.X), -0.02)
		end
		-- the sets: a few named compositions (MapLayouts.Sets). Kit pieces, older props, and groves: clumps of trees
		-- (dead ones on Magma) or of crystals in the caves, never single ones dotted over the field
		local rng = Random.new(31)
		local treeModel = magma and "tree_dead" or "tree_oak"
		for _, set in layout.Sets or {} do
			for _, k in set.Kit or {} do
				kit(k.Piece, k.At, k.Look, k.Sink)
			end
			for _, piece in set.Props or {} do
				stand(piece.Model, piece.At, piece.Height, piece.Turn, piece.Block)
			end
			for i, g in set.Grove or {} do
				local kind = crystal and "crystal_cluster" or (not magma and i % 3 == 0) and "tree_dead" or treeModel
				local tree = stand(kind, g.At, g.H, rng:NextNumber(0, math.pi * 2), crystal and math.clamp(g.H / 5, 1.4, 3) or 2.2)
				if tree and g.H > 8 then
					tree:SetAttribute("Tall", true)
				end
			end
			task.wait()
		end
		-- the rock masses in the corners carry wood (dead trees on Magma, crystals in the caves)
		local onMass = crystal and "crystal_cluster" or treeModel
		for _, mass in layout.Masses do
			blocker(mass.At, mass.Radius + 1, "Rocks are in the way")
			for _ = 1, math.max(2, math.floor(mass.Radius / (crystal and 5 or 3.5))) do
				local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, mass.Radius * 0.85)
				local at = mass.At + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				stand(onMass, at, crystal and rng:NextNumber(9, 18) or rng:NextNumber(18, 28), rng:NextNumber(0, math.pi * 2), nil)
			end
			task.wait()
		end
		-- stepping-stone paths (MapLayouts.Paths with Stones): a `flags` piece every 4.5 studs along the route, not on
		-- the road itself (the road is the path there)
		for _, path in layout.Paths or {} do
			if path.Stones then
				for i = 1, #path.Points - 1 do
					local a, b = path.Points[i], path.Points[i + 1]
					local length = (b - a).Magnitude
					local n = math.max(1, math.floor(length / 4.5))
					for k = 0, n - 1 do
						local at = a + (b - a) * ((k + 0.5) / n)
						if Config.DistanceToPath(at) > Config.PathWidth / 2 + 3 then
							-- (the piece's long side runs along the route: its front looks across it)
							local along = (b - a).Unit
							kit("flags", at, Vector3.new(along.Z, 0, -along.X), -0.02)
						end
					end
				end
				task.wait()
			end
		end
		-- nothing is built in a gorge: the strip of floor beside a channel where it comes through the rise
		for _, channel in layout.Channels do
			for i = 1, #channel.Points - 1 do
				local a, b = channel.Points[i], channel.Points[i + 1]
				for d = 0, (b - a).Magnitude, 6 do
					local pos = a + (b - a).Unit * d
					if MapLayouts.Outside(layout, pos.X, pos.Z) > -6 and math.abs(pos.X) < half.X and math.abs(pos.Z) < half.Y then
						blocker(pos, channel.Width / 2 + MapLayouts.Gorge + 1, magma and "Too close to the lava" or "Too close to the water")
					end
				end
			end
		end
		-- the lava river glows: a thin sheet of light just over its bed, the dark crust shows through it
		if magma then
			for _, channel in layout.Channels do
				for i = 1, #channel.Points - 1 do
					local a, b = channel.Points[i], channel.Points[i + 1]
					-- (the bed is rough, its surface runs from -1.9 to -1.2. At -1.3 the glow was one flat orange sheet, at
					-- -1.62 a few loose patches that read as scattered blobs from above: at -1.45 it is one river with
					-- the highest crust standing out of it)
					local mid = (a + b) / 2 + Vector3.new(0, -1.45, 0)
					part({ Name = "LavaGlow", Size = Vector3.new(channel.Width - 2.5, 0.1, (b - a).Magnitude + 2),
						CFrame = CFrame.lookAt(mid, Vector3.new(b.X, mid.Y, b.Z)), Color = Color3.fromRGB(255, 104, 26),
						Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false, CanTouch = false,
						CastShadow = false, Parent = map })
				end
			end
		end
		-- a little light from the lava river and the glowing canals, every 36 studs (few lights: phones)
		if magma or crystal then
			for _, channel in layout.Channels do
				local travelled, nextAt = 0, 18
				for i = 1, #channel.Points - 1 do
					local a, b = channel.Points[i], channel.Points[i + 1]
					local length = (b - a).Magnitude
					while nextAt <= travelled + length do
						local pos = a + (b - a).Unit * (nextAt - travelled)
						if math.abs(pos.X) < half.X and math.abs(pos.Z) < half.Y then
							local glowPart = part({ Name = "ChannelGlow", Size = Vector3.one, Position = pos + Vector3.new(0, 1.5, 0),
								Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = map })
							local light = Instance.new("PointLight")
							light.Color = magma and Color3.fromRGB(255, 120, 40) or Color3.fromRGB(90, 220, 255)
							light.Range = 16
							light.Brightness = magma and 1.2 or 1
							light.Shadows = false
							light.Parent = glowPart
						end
						nextAt += 36
					end
					travelled += length
				end
			end
		end
	end)

	-- lane dressing: lanterns along the path (every ~28 studs, alternating sides), inside the no-build band beside
	-- the road so they never stand where a defender goes. One thing in a rhythm on a line; no barrels or crates
	-- sprinkled between them any more (reviews/maps/placement-rules.md, rule 6)
	task.spawn(function()
		ArtService.WaitModel("keep_lantern", 20)
		local Ground = require(ReplicatedStorage.Shared.Ground)
		local pts = Config.Path
		local n = 0
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local length = (b - a).Magnitude
			local dir = (b - a).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for d = 14, length - 8, 28 do
				n += 1
				local s = (n % 2 == 0) and 1 or -1
				local spot = a + dir * d + side * s * (Config.PathWidth / 2 + 1.8)
				spot = Vector3.new(spot.X, (Ground.At(spot.X, spot.Z)), spot.Z)
				local look = placeModel(decor, "keep_lantern", CFrame.lookAt(spot, spot - side * s), 6.5)
				if look then
					for _, p in look:GetDescendants() do
						if p:IsA("BasePart") and p.Material == Enum.Material.Neon and n % 2 == 0 then
							local light = Instance.new("PointLight")
							light.Color = Color3.fromRGB(255, 200, 120)
							light.Range = 12
							light.Brightness = 0.7
							light.Parent = p
						end
					end
				end
			end
		end
	end)

	-- folders the game fills while you play
	for _, name in { "Towers", "Enemies" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		folder(name, workspace)
	end
	if not workspace:FindFirstChild("Effects") then
		folder("Effects", workspace)
	end
	return map
end

-------------------------------------------------------------------------------
-- The Outpost (hub)
-------------------------------------------------------------------------------
-- calls onPrompt(player, action) when someone uses a stall
function MapBuilder.BuildOutpost(onPrompt)
	local old = workspace:FindFirstChild("Outpost")
	if old then
		old:Destroy()
	end
	local hub = folder("Outpost", workspace)
	local c = Config.OutpostCenter
	if Config.HubVersion == "Keep" then
		-- the Watch Keep (server/OutpostKeep, shared/HubLayout); the old meadow below stays one switch away
		local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
		TerrainBuilder.Keep(c)
		hub:SetAttribute("GroundTheme", "Outpost")
		hub:SetAttribute("HubVersion", "Keep")
		part({ Name = "Ground", Size = Vector3.new(150, 2, 150), Position = c - Vector3.new(0, 1, 0), Transparency = 1,
			CanCollide = false, Parent = hub })
		walls(hub, c, HubLayout.Size.X + 2, HubLayout.Size.Y + 2)
		return require(script.Parent.OutpostKeep).Build(hub, c, {
			part = part,
			placeModel = placeModel,
			onPrompt = onPrompt,
			prompt = function(target, actionText, objectText, action, hold)
				local p = Instance.new("ProximityPrompt")
				p.ActionText = actionText
				p.ObjectText = objectText
				p.MaxActivationDistance = 12
				p.HoldDuration = hold or 0
				p.RequiresLineOfSight = false
				p.Parent = target
				p.Triggered:Connect(function(player)
					onPrompt(player, action)
				end)
				return p
			end,
		})
	end
	TerrainBuilder.Outpost(c)
	hub:SetAttribute("GroundTheme", "Outpost")
	-- invisible floor and walls keep clicks and players inside (the terrain is what you see)
	part({ Name = "Ground", Size = Vector3.new(150, 2, 150), Position = c - Vector3.new(0, 1, 0), Transparency = 1,
		CanCollide = false, Parent = hub })
	walls(hub, c, 150, 150)

	-- the spawn, south of the campfire, looking north at the portal
	local spawn = part({ ClassName = "SpawnLocation", Name = "OutpostSpawn", Size = Vector3.new(10, 1, 10),
		Position = c + Vector3.new(0, 0.3, 36), Transparency = 1, CanCollide = false, Enabled = true, Parent = hub })
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local function prompt(target, actionText, objectText, action, hold)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = actionText
		p.ObjectText = objectText
		p.MaxActivationDistance = 12
		p.HoldDuration = hold or 0
		p.RequiresLineOfSight = false
		p.Parent = target
		p.Triggered:Connect(function(player)
			onPrompt(player, action)
		end)
	end

	-- each station: a painted Blender prop (placed when it has loaded), an invisible anchor with the prompt
	-- and a short label that only shows when you're close
	local function station(model, offset, height, label, color, actionText, action)
		local pos = c + offset
		local facing = CFrame.lookAt(pos, Vector3.new(c.X, 0, c.Z))
		local anchor = part({ Name = model, Size = Vector3.new(4, 4, 4), CFrame = facing * CFrame.new(0, 2, -2),
			Transparency = 1, CanCollide = false, Parent = hub })
		if label then
			-- The native interaction prompt already names this station.
			prompt(anchor, actionText, label, action)
		end
		task.spawn(function()
			ArtService.WaitModel(model, 30)
			placeModel(hub, model, facing, height)
		end)
		return anchor
	end

	-- the campfire in the middle, with real fire and warm light
	local fireAnchor = station("outpost_campfire", Vector3.new(9, 0, 6), 4)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 7
	fire.Parent = fireAnchor
	fireAnchor.CFrame = CFrame.new(c + Vector3.new(9, 0.6, 6))
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 170, 90)
	fireLight.Range = 24
	fireLight.Brightness = 1.4
	fireLight.Parent = fireAnchor

	-- Glowing coals remain legible when phone graphics reduce the fire particles.
	for index = 1, 7 do
		local angle = index * 2.4
		local radius = 0.36 * math.sqrt(index)
		part({ Name = "HearthCoal", Shape = Enum.PartType.Ball, Size = Vector3.new(1.15, 0.65, 0.9),
			Position = fireAnchor.Position + Vector3.new(math.cos(angle) * radius, 0.25, math.sin(angle) * radius),
			Color = Color3.fromRGB(242, 73 + index * 10, 18), Material = Enum.Material.Neon,
			CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Parent = hub })
	end

	-- START: the stone portal arch at the north end, with a glowing disc and a pad in front
	local portalPos = c + Vector3.new(0, 0, -30)
	task.spawn(function()
		ArtService.WaitModel("map_portal", 30)
		placeModel(hub, "map_portal", CFrame.lookAt(portalPos, portalPos + Vector3.new(0, 0, 1)), 20)
	end)
	part({ Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 14, 14),
		CFrame = CFrame.new(portalPos + Vector3.new(0, 10.4, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(150, 90, 255), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = hub })
	-- Show the destination inside the arch using the forest's existing painted sky.
	local window = part({ Name = "PortalView", Size = Vector3.new(12.7, 12.7, 0.05),
		Position = portalPos + Vector3.new(0, 10.4, 1.75), Transparency = 1,
		CanCollide = false, CanTouch = false, CanQuery = false, Parent = hub })
	local view = Instance.new("SurfaceGui")
	view.Face = Enum.NormalId.Back
	view.CanvasSize = Vector2.new(384, 384)
	view.LightInfluence = 0
	view.Parent = window
	local vista = Instance.new("ImageLabel")
	vista.BackgroundTransparency = 1
	vista.Size = UDim2.fromScale(1, 1)
	task.spawn(function()
		local image = ArtService.Image("sky_forest_side", 30)
		if image then vista.Image = image end
	end)
	vista.ScaleType = Enum.ScaleType.Crop
	vista.ImageColor3 = Color3.fromRGB(219, 196, 255)
	local mask = Instance.new("UICorner")
	mask.CornerRadius = UDim.new(0.5, 0)
	mask.Parent = vista
	vista.Parent = view
	local pad = part({ Name = "StartPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(portalPos + Vector3.new(0, 0.25, 10)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(150, 90, 255), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, Parent = hub })
	local padLight = Instance.new("PointLight")
	padLight.Color = Color3.fromRGB(170, 120, 255)
	padLight.Range = 18
	padLight.Brightness = 1.5
	padLight.Parent = pad
	nameTag(pad, "Start run", Color3.fromRGB(215, 190, 255), 4)
	prompt(pad, "Start run", "Portal", "Start", 0.5)

	-- Paired blue-and-gold standards mark the entrance from across the courtyard.
	for _, side in { -1, 1 } do
		local mast = portalPos + Vector3.new(side * 20, 0, 4)
		local function trim(name, offset, size, color, material)
			part({ Name = name, Position = mast + offset, Size = size,
				Material = material, Color = color, CanCollide = false, CanTouch = false, CanQuery = false,
				Parent = hub })
		end
		local gold = Color3.fromRGB(196, 149, 67)
		trim("BannerMast", Vector3.new(0, 7, 0), Vector3.new(0.45, 14, 0.45), Color3.fromRGB(85, 54, 35), Enum.Material.Wood)
		trim("BannerCrossbar", Vector3.new(side * 2, 13, 0), Vector3.new(5, 0.3, 0.35), gold, Enum.Material.Metal)
		trim("OutpostStandard", Vector3.new(side * 2, 9.5, 0), Vector3.new(3.8, 6.8, 0.17),
			Color3.fromRGB(36, 83, 119), Enum.Material.Fabric)
		trim("StandardHem", Vector3.new(side * 2, 6.5, 0.12), Vector3.new(3.8, 0.36, 0.1), gold, Enum.Material.Fabric)
		part({ Name = "GateSigil", Size = Vector3.new(1.35, 1.35, 0.15),
			CFrame = CFrame.new(mast + Vector3.new(side * 2, 10, 0.14)) * CFrame.Angles(0, 0, math.pi / 4),
			Color = gold, Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, CanQuery = false, Parent = hub })
	end

	require(script.Parent.OutpostGatehouse).build(hub, c, function(gate, facing)
		ArtService.WaitModel("tower_ranger", 30)
		return placeModel(gate, "tower_ranger", facing, 19)
	end)

	-- the stations around the plaza
	station("outpost_forge", Vector3.new(-23, 0, -12), 13, "Blacksmith", Color3.fromRGB(255, 200, 120), "Upgrade gear", "Backpack")
	station("outpost_stall", Vector3.new(24, 0, -10), 9, "Gem Shop", Color3.fromRGB(90, 220, 255), "Open shop", "Shop")
	station("outpost_altar", Vector3.new(-26, 0, 10), 12, "Hero Altar", Color3.fromRGB(140, 255, 140), "Pick hero and stats", "Heroes")
	station("outpost_mapboard", Vector3.new(26, 0, 10), 8.5, "Map Board", Color3.fromRGB(255, 210, 90), "Choose map", "Maps")
	station("outpost_questboard", Vector3.new(-27, 0, 22), 8.5, "Quest Board", Color3.fromRGB(255, 220, 140), "Daily quests", "Quests")
	station("outpost_chest", Vector3.new(34, 0, 15), 5, "Daily Chest", Color3.fromRGB(255, 210, 90), "Daily reward", "Daily")
	station("outpost_nest", Vector3.new(17, 0, -22), 5, "Pet Corner", Color3.fromRGB(160, 255, 160), "Hatch eggs", "Pets")

	-- trees all around the hills
	task.spawn(function()
		ArtService.WaitModel("tree_oak", 30)
		local treeRng = Random.new(41)
		for i = 1, 46 do
			local a = treeRng:NextNumber(0, math.pi * 2)
			local d = i <= 6 and treeRng:NextNumber(46, 60) or treeRng:NextNumber(66, 110)
			local pos = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			local hit = workspace:Raycast(pos + Vector3.new(0, 120, 0), Vector3.new(0, -240, 0))
			pos = hit and hit.Position - Vector3.new(0, 0.5, 0) or pos
			placeModel(hub, "tree_oak", CFrame.new(pos) * CFrame.Angles(0, treeRng:NextNumber(0, math.pi * 2), 0),
				treeRng:NextNumber(14, 24))
		end
	end)

	-- trophy wall with the best players on this server, behind the pet corner
	local wall = part({ Name = "TrophyWall", Size = Vector3.new(16, 9, 0.6), CFrame = CFrame.lookAt(c + Vector3.new(-30, 4.5, -32),
		c + Vector3.new(0, 4.5, 0)), Color = Color3.fromRGB(92, 66, 44), Material = Enum.Material.WoodPlanks, Parent = hub })
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.Parent = wall
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 225, 150)
	text.Text = "TROPHY WALL"
	text.Parent = surface

	return hub
end

-- only one spawn is on at a time: the hub's, or the battlefield's during a run
function MapBuilder.UseSpawn(where)
	-- the hub and the battlefield each have their own light and painted looks
	if where == "Outpost" then
		setupLighting("Outpost")
		TerrainBuilder.OutpostLooks()
	end
	local hubSpawn = workspace:FindFirstChild("Outpost") and workspace.Outpost:FindFirstChild("OutpostSpawn")
	local battleSpawn = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("HeroSpawn")
	if hubSpawn then
		hubSpawn.Enabled = where == "Outpost"
	end
	if battleSpawn then
		battleSpawn.Enabled = where == "Battle"
	end
end

-- moves a player's character to the hub or the battlefield
function MapBuilder.Teleport(player, where)
	local character = player.Character
	if not character then
		return
	end
	local target = where == "Outpost" and (Config.OutpostCenter + Vector3.new(math.random(-2, 2), 4, 36))
		or (Config.SpawnPoint + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
	local look = Vector3.new(0, 0, -1)
	if where ~= "Outpost" then
		-- the battle spawn can be on raised ground: 4 studs above whatever is there
		target += Vector3.new(0, (Ground.At(target.X, target.Z)), 0)
		-- facing the way the map's first view is framed (MapOutline.Start: the landmark and a bridge in view)
		local map = Config.Maps[Config.CurrentMap]
		local start = map and MapOutline.Start[map.Theme]
		look = start and start.Look or look
	end
	character:PivotTo(CFrame.lookAt(target, target + look))
end

-- writes the best players onto the trophy wall
function MapBuilder.UpdateTrophies(lines)
	local wall = workspace:FindFirstChild("Outpost") and workspace.Outpost:FindFirstChild("TrophyWall")
	local text = wall and wall:FindFirstChild("Board") and wall.Board:FindFirstChild("Text")
	if text then
		text.Text = "TROPHY WALL\n" .. table.concat(lines, "\n")
	end
end

return MapBuilder
