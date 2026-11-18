-- Builds the world out of simple parts: the battlefield for the chosen map
-- (Cursed Forest or Magma Fortress) and The Outpost, the hub where runs start.
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

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function nameTag(parentPart, text, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, height or 6, 0)
	gui.MaxDistance = 90
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
	Lighting.Brightness = 2
	if theme == "Magma" then
		Lighting.ClockTime = 19
		Lighting.Ambient = Color3.fromRGB(110, 60, 50)
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 70, 60)
		Lighting.FogColor = Color3.fromRGB(80, 30, 20)
		atmosphere.Density = 0.4
		atmosphere.Color = Color3.fromRGB(200, 100, 70)
		atmosphere.Decay = Color3.fromRGB(120, 40, 20)
	else
		Lighting.ClockTime = 17.6
		Lighting.Ambient = Color3.fromRGB(70, 60, 90)
		Lighting.OutdoorAmbient = Color3.fromRGB(90, 80, 110)
		Lighting.FogColor = Color3.fromRGB(40, 35, 60)
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(110, 90, 140)
		atmosphere.Decay = Color3.fromRGB(60, 40, 80)
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
	setupLighting(mapInfo.Theme)

	local map = folder("Map", workspace)
	part({
		Name = "Ground",
		Size = Vector3.new(Config.MapSize.X, 2, Config.MapSize.Y),
		Position = Vector3.new(0, -1, 0),
		Color = magma and Color3.fromRGB(45, 35, 35) or Color3.fromRGB(45, 70, 40),
		Material = magma and Enum.Material.Basalt or Enum.Material.Grass,
		Parent = map,
	})
	walls(map, Vector3.zero, Config.MapSize.X, Config.MapSize.Y)

	-- the path, one piece between each pair of points
	local pathFolder = folder("Path", map)
	local points = Config.Path
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		part({
			Name = "Segment" .. i,
			Size = Vector3.new(Config.PathWidth, 0.2, (b - a).Magnitude + Config.PathWidth),
			CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.1, 0),
			Color = magma and Color3.fromRGB(95, 70, 60) or Color3.fromRGB(110, 85, 55),
			Material = magma and Enum.Material.Slate or Enum.Material.Ground,
			CanCollide = false,
			Parent = pathFolder,
		})
	end

	-- where the enemies come from
	local camp = points[1] + (points[1] - points[2]).Unit * 12
	if magma then
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
	glow.Range = 30
	glow.Brightness = 3
	glow.Parent = portal
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for _, k in { -9, 9 } do
		part({ Name = "PortalPillar", Size = Vector3.new(3, 20, 3), Position = last + dir * 4 + side * k + Vector3.new(0, 10, 0),
			Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Slate, Parent = map })
	end

	-- where players appear during a run
	local spawn = part({
		ClassName = "SpawnLocation",
		Name = "HeroSpawn",
		Size = Vector3.new(8, 1, 8),
		Position = Config.SpawnPoint + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 170, 80),
		Material = Enum.Material.Marble,
		Enabled = false,
		Parent = map,
	})
	spawn.Duration = 0

	-- decorations, kept off the path and the spawn
	local decor = folder("Decor", map)
	local rng = Random.new(magma and 11 or 7)
	local half = Config.MapSize / 2
	local placed, tries = 0, 0
	while placed < 70 and tries < 2000 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 5, half.X - 5), 0, rng:NextNumber(-half.Y + 5, half.Y - 5))
		if Config.DistanceToPath(pos) > Config.PathWidth + 6 and (pos - Config.SpawnPoint).Magnitude > 14
			and (pos - camp).Magnitude > 14 then
			if magma then
				magmaDecor(decor, rng, pos)
			else
				forestDecor(decor, rng, pos)
			end
			placed += 1
		end
	end

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
	local sizeX, sizeZ = 110, 76

	part({ Name = "Ground", Size = Vector3.new(sizeX, 2, sizeZ), Position = c - Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(120, 110, 95), Material = Enum.Material.Cobblestone, Parent = hub })
	walls(hub, c, sizeX, sizeZ)
	-- wooden fence posts around the edge
	for i = -5, 5 do
		for _, z in { -sizeZ / 2 + 1, sizeZ / 2 - 1 } do
			part({ Name = "Post", Size = Vector3.new(1, 4, 1), Position = c + Vector3.new(i * 10, 2, z),
				Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood, Parent = hub })
		end
	end
	nameTag(part({ Name = "SignPost", Size = Vector3.new(1, 1, 1), Position = c + Vector3.new(0, 14, 0),
		Transparency = 1, CanCollide = false, Parent = hub }), "THE OUTPOST", Color3.fromRGB(255, 210, 90), 0)

	-- the spawn in the hub
	local spawn = part({ ClassName = "SpawnLocation", Name = "OutpostSpawn", Size = Vector3.new(10, 1, 10),
		Position = c + Vector3.new(0, 0.5, 26), Color = Color3.fromRGB(200, 170, 80), Material = Enum.Material.Marble,
		Enabled = true, Parent = hub })
	spawn.Duration = 0

	-- campfire in the middle
	local fire = part({ Name = "Campfire", Size = Vector3.new(3, 1, 3), Position = c + Vector3.new(0, 0.5, 10),
		Color = Color3.fromRGB(255, 130, 40), Material = Enum.Material.Neon, Parent = hub })
	Instance.new("Fire", fire).Size = 6
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 160, 80)
	fireLight.Range = 30
	fireLight.Parent = fire

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

	-- the start pad: a glowing circle in front of the fire
	local pad = part({ Name = "StartPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 16, 16),
		CFrame = CFrame.new(c + Vector3.new(0, 0.2, -12)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(140, 80, 255), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, Parent = hub })
	nameTag(pad, "START RUN", Color3.fromRGB(200, 160, 255), 5)
	prompt(pad, "Start run", "Portal", "Start", 0.5)

	-- blacksmith: anvil and forge (opens the backpack)
	local anvil = part({ Name = "Anvil", Size = Vector3.new(4, 3, 2), Position = c + Vector3.new(-38, 1.5, -14),
		Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal, Parent = hub })
	local forge = part({ Name = "Forge", Size = Vector3.new(8, 6, 6), Position = c + Vector3.new(-46, 3, -18),
		Color = Color3.fromRGB(90, 80, 75), Material = Enum.Material.Brick, Parent = hub })
	Instance.new("Fire", forge).Size = 5
	nameTag(anvil, "Blacksmith", Color3.fromRGB(255, 200, 120), 6)
	prompt(anvil, "Upgrade gear", "Blacksmith", "Backpack")

	-- gem shop: a tent
	local tent = part({ ClassName = "WedgePart", Name = "Tent", Size = Vector3.new(12, 8, 6),
		CFrame = CFrame.new(c + Vector3.new(40, 4, -17)), Color = Color3.fromRGB(60, 110, 170), Material = Enum.Material.Fabric, Parent = hub })
	part({ ClassName = "WedgePart", Name = "Tent", Size = Vector3.new(12, 8, 6),
		CFrame = CFrame.new(c + Vector3.new(40, 4, -11)) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(60, 110, 170),
		Material = Enum.Material.Fabric, Parent = hub })
	local counter = part({ Name = "Counter", Size = Vector3.new(8, 3, 2), Position = c + Vector3.new(40, 1.5, -6),
		Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.WoodPlanks, Parent = hub })
	nameTag(tent, "Gem Shop", Color3.fromRGB(90, 220, 255), 7)
	prompt(counter, "Open shop", "Gem Shop", "Shop")

	-- hero altar: a statue
	local altar = part({ Name = "Altar", Size = Vector3.new(6, 2, 6), Position = c + Vector3.new(-38, 1, 16),
		Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble, Parent = hub })
	part({ Name = "Statue", Size = Vector3.new(2, 7, 2), Position = c + Vector3.new(-38, 5.5, 16),
		Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Marble, Parent = hub })
	part({ Name = "StatueHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Position = c + Vector3.new(-38, 10, 16),
		Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Marble, Parent = hub })
	nameTag(altar, "Hero Altar", Color3.fromRGB(120, 255, 120), 11)
	prompt(altar, "Pick hero and stats", "Hero Altar", "Heroes")

	-- map board
	local board = part({ Name = "MapBoard", Size = Vector3.new(10, 7, 1), Position = c + Vector3.new(40, 4.5, 16),
		Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.WoodPlanks, Parent = hub })
	nameTag(board, "Map Board", Color3.fromRGB(255, 210, 90), 6)
	prompt(board, "Choose map", "Map Board", "Maps")

	-- daily reward chest
	local chest = part({ Name = "DailyChest", Size = Vector3.new(4, 3, 3), Position = c + Vector3.new(14, 1.5, 22),
		Color = Color3.fromRGB(170, 120, 40), Material = Enum.Material.WoodPlanks, Parent = hub })
	nameTag(chest, "Daily Chest", Color3.fromRGB(255, 210, 90), 4)
	prompt(chest, "Daily reward", "Daily Chest", "Daily")

	-- pet corner: a nest with eggs
	local nest = part({ Name = "PetNest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 8, 8),
		CFrame = CFrame.new(c + Vector3.new(26, 0.75, 4)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(130, 100, 60), Material = Enum.Material.Grass, Parent = hub })
	for i, egg in Config.Eggs do
		part({ Name = "Egg", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2.6, 2), Position = c + Vector3.new(24 + i * 1.6, 2.5, 4),
			Color = egg.Color, Material = Enum.Material.SmoothPlastic, Parent = hub })
	end
	nameTag(nest, "Pet Corner", Color3.fromRGB(160, 255, 160), 5)
	prompt(nest, "Hatch eggs", "Pet Corner", "Pets")

	-- quest board
	local questBoard = part({ Name = "QuestBoard", Size = Vector3.new(7, 6, 1), Position = c + Vector3.new(-14, 3.5, 22),
		Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks, Parent = hub })
	for i = 1, 3 do
		part({ Name = "Note", Size = Vector3.new(1.6, 2, 0.1), Position = c + Vector3.new(-16.5 + i * 1.8, 3.8, 21.4),
			Color = Color3.fromRGB(240, 230, 200), Material = Enum.Material.SmoothPlastic, Parent = hub })
	end
	nameTag(questBoard, "Quest Board", Color3.fromRGB(255, 220, 140), 5)
	prompt(questBoard, "Daily quests", "Quest Board", "Quests")

	-- trophy wall with the best players on this server
	local wall = part({ Name = "TrophyWall", Size = Vector3.new(26, 12, 1), Position = c + Vector3.new(0, 6, -36),
		Color = Color3.fromRGB(60, 45, 35), Material = Enum.Material.WoodPlanks, Parent = hub })
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.Parent = wall
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 220, 140)
	text.Text = "TROPHY WALL"
	text.Parent = surface

	return hub
end

-- only one spawn is on at a time: the hub's, or the battlefield's during a run
function MapBuilder.UseSpawn(where)
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
	local target = where == "Outpost" and (Config.OutpostCenter + Vector3.new(math.random(-6, 6), 4, 26 + math.random(-3, 3)))
		or (Config.SpawnPoint + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
	character:PivotTo(CFrame.new(target))
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
