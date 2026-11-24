-- Defenders: placing, upgrading, selling, and shooting at goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Clock = require(script.Parent.Clock)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local ArtService = require(script.Parent.ArtService)
local StoreService = require(script.Parent.StoreService)
local SeasonService = require(script.Parent.SeasonService)
local Ground = require(ReplicatedStorage.Shared.Ground)
local MapOutline = require(ReplicatedStorage.Shared.MapOutline)

local TowerService = {}

-- [model] = { type, level, spent, nextShot, position, muzzle, kicker, turners }
local towers = {}
local turrets = {} -- the Engineer's mini turrets

local function newPart(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- what each defender looks like. Each returns:
-- muzzle offset (where shots come from), the part that kicks when shooting,
-- and parts that turn to face the target (optional)
local BUILDERS = {
	Ranger = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5, 1, 5), CFrame = at * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Cobblestone })
		newPart(model, { Name = "Post", Size = Vector3.new(3, 7, 3), CFrame = at * CFrame.new(0, 4.5, 0),
			Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.WoodPlanks })
		newPart(model, { Name = "Platform", Size = Vector3.new(4.5, 0.6, 4.5), CFrame = at * CFrame.new(0, 8.3, 0),
			Color = Color3.fromRGB(90, 60, 35), Material = Enum.Material.Wood })
		local archer = newPart(model, { Name = "Archer", Size = Vector3.new(1.4, 2.4, 1.4), CFrame = at * CFrame.new(0, 9.8, 0),
			Color = color })
		local hood = newPart(model, { Name = "Hood", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4,
			CFrame = at * CFrame.new(0, 11.4, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.3) })
		local bow = newPart(model, { Name = "Bow", Size = Vector3.new(2.4, 0.2, 0.2), CFrame = at * CFrame.new(0, 10, -0.9),
			Color = Color3.fromRGB(120, 80, 40), Material = Enum.Material.Wood })
		return Vector3.new(0, 10.5, 0), archer, { archer, hood, bow }
	end,
	FlameCannon = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5.5, 1.5, 5.5), CFrame = at * CFrame.new(0, 0.75, 0),
			Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
		newPart(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 4,
			CFrame = at * CFrame.new(0, 3, 0), Color = Color3.fromRGB(50, 45, 45), Material = Enum.Material.Metal })
		local barrel = newPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.8, 1.8),
			CFrame = at * CFrame.new(0, 4.2, -1.5) * CFrame.Angles(0, math.pi / 2, math.rad(25)),
			Color = Color3.fromRGB(70, 60, 55), Material = Enum.Material.Metal })
		local glow = newPart(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3,
			CFrame = at * CFrame.new(0, 5.3, -3.2), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		Instance.new("Fire", glow).Size = 2
		return Vector3.new(0, 5.3, -3.2), barrel, nil
	end,
	FrostCrystal = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5, 1, 5), CFrame = at * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(200, 210, 230), Material = Enum.Material.Ice })
		local crystal = newPart(model, { Name = "Crystal", Size = Vector3.new(2.2, 6, 2.2),
			CFrame = at * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color = color, Material = Enum.Material.Glass, Transparency = 0.2 })
		for i = 0, 2 do
			newPart(model, { Name = "Shard", Size = Vector3.new(1, 3, 1),
				CFrame = at * CFrame.Angles(0, i * math.pi * 2 / 3, 0) * CFrame.new(1.8, 2.2, 0) * CFrame.Angles(0, 0, math.rad(-20)),
				Color = color, Material = Enum.Material.Glass, Transparency = 0.2 })
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Parent = crystal
		return Vector3.new(0, 5, 0), crystal, nil
	end,
	StormObelisk = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5, 1.2, 5), CFrame = at * CFrame.new(0, 0.6, 0),
			Color = Color3.fromRGB(50, 45, 70), Material = Enum.Material.Slate })
		newPart(model, { Name = "Pillar", Size = Vector3.new(2, 9, 2), CFrame = at * CFrame.new(0, 5.7, 0),
			Color = Color3.fromRGB(70, 60, 100), Material = Enum.Material.Slate })
		newPart(model, { Name = "Tip", Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = at * CFrame.new(0, 10.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = Color3.fromRGB(70, 60, 100), Material = Enum.Material.Slate })
		local orb = newPart(model, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2,
			CFrame = at * CFrame.new(0, 12.2, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 2
		light.Parent = orb
		return Vector3.new(0, 12.2, 0), orb, nil
	end,
	Ballista = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(6, 1, 6), CFrame = at * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.Cobblestone })
		newPart(model, { Name = "Stand", Size = Vector3.new(1.6, 3, 1.6), CFrame = at * CFrame.new(0, 2.5, 0),
			Color = color, Material = Enum.Material.Wood })
		local rail = newPart(model, { Name = "Rail", Size = Vector3.new(1, 0.8, 7), CFrame = at * CFrame.new(0, 4.4, 0),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.WoodPlanks })
		local arms = newPart(model, { Name = "Arms", Size = Vector3.new(7, 0.5, 0.5), CFrame = at * CFrame.new(0, 4.6, -2.5),
			Color = color, Material = Enum.Material.Wood })
		local bolt = newPart(model, { Name = "BoltRest", Size = Vector3.new(0.3, 0.3, 4), CFrame = at * CFrame.new(0, 5, -1),
			Color = Color3.fromRGB(180, 180, 190), Material = Enum.Material.Metal })
		return Vector3.new(0, 5, -3), rail, { rail, arms, bolt }
	end,
}

-- the Blender-built look of a defender, scaled to its height, standing on `at`.
-- Returns true when the model was used (otherwise the part-built look is used).
-- heights and shot origins of the hand-built models (art/blender/towers_hand.py prints each HEIGHT)
local MODEL_HEIGHT = { Ranger = 15.65, FlameCannon = 5.5, FrostCrystal = 8.28, StormObelisk = 13.08, Ballista = 5.93 }
local MODEL_NAME = { Ranger = "tower_ranger", FlameCannon = "tower_flame", FrostCrystal = "tower_frost",
	StormObelisk = "tower_storm", Ballista = "tower_ballista" }
local MODEL_MUZZLE = { Ranger = Vector3.new(0, 8.25, -2.8), FlameCannon = Vector3.new(0, 4.6, -3.2), FrostCrystal = Vector3.new(0, 6.6, 0),
	StormObelisk = Vector3.new(0, 11.75, 0), Ballista = Vector3.new(0, 5.6, -4.6) }
-- a look per level (docs/tower-pipeline.md): the tower grows and changes as it is upgraded. Heights and muzzles
-- from the Blender builds (art/blender/tower_ranger_detail.py prints HEIGHT and MUZZLE, the archer's arrow tip). Towers without a level set keep one look.
local LEVEL_LOOKS = {
	Ranger = {
		-- Archers: where the archer (its own model, ranger_archer) stands: feet relative to the look's bottom centre,
		-- the yaw his front looks to, his height (the paintings make him about a third of the tower on level 1: oversized so he reads on a phone, and as
		-- tall as the lookout allows under the roof; standing on a hidden step so chest and bow show above the rail,
		-- as in the paintings)
		{ Name = "tower_ranger_l1", Height = 10.92, Muzzle = Vector3.new(0.51, 5.7, -1.6),
			Archers = { { Vector3.new(0.51, 4.4, -1.13), 4, 3.2 } } },
		{ Name = "tower_ranger_l2", Height = 15.63, Muzzle = Vector3.new(-0.68, 8.0, -2.2),
			Archers = { { Vector3.new(-0.68, 6.5, -1.64), 30, 3.2 } } },
		{ Name = "tower_ranger_l3", Height = 19.64, Muzzle = Vector3.new(0.54, 12.3, -3.9),
			-- two archers, not mirror copies: different turns, and the game gives them different breathing
			Archers = { { Vector3.new(0.54, 10.8, -3.35), 11, 3.2 }, { Vector3.new(-2.15, 10.8, -2.63), 39, 3.1 } } },
	},
	-- the other four, built with the tower kit (art/blender/tower_<kind>_detail.py prints HEIGHT and MUZZLE; levels
	-- scaled so each one is a step taller than the last)
	FlameCannon = {
		{ Name = "tower_flame_l1", Height = 5.22, Muzzle = Vector3.new(-1.48, 4.23, -0.74) },
		{ Name = "tower_flame_l2", Height = 6.42, Muzzle = Vector3.new(-2.61, 5.37, -0.25) },
		{ Name = "tower_flame_l3", Height = 8.47, Muzzle = Vector3.new(-3.31, 6.03, -1.09) },
	},
	FrostCrystal = {
		{ Name = "tower_frost_l1", Height = 7.84, Muzzle = Vector3.new(0.00, 6.98, 0.00) },
		{ Name = "tower_frost_l2", Height = 8.70, Muzzle = Vector3.new(0.00, 7.50, 0.00) },
		{ Name = "tower_frost_l3", Height = 9.92, Muzzle = Vector3.new(0.00, 7.68, 0.00) },
	},
	StormObelisk = {
		{ Name = "tower_storm_l1", Height = 7.34, Muzzle = Vector3.new(0.00, 6.05, 0.00) },
		{ Name = "tower_storm_l2", Height = 10.40, Muzzle = Vector3.new(0.00, 10.12, 0.00) },
		{ Name = "tower_storm_l3", Height = 12.05, Muzzle = Vector3.new(0.00, 11.11, 0.00) },
	},
	Ballista = {
		{ Name = "tower_ballista_l1", Height = 5.85, Muzzle = Vector3.new(-3.31, 5.93, -1.71) },
		{ Name = "tower_ballista_l2", Height = 6.38, Muzzle = Vector3.new(-3.65, 6.44, -2.34) },
		{ Name = "tower_ballista_l3", Height = 8.05, Muzzle = Vector3.new(-1.36, 7.95, -2.40) },
	},
}
TowerService.LevelLooks = LEVEL_LOOKS

local function lookFor(towerType, level)
	local set = LEVEL_LOOKS[towerType]
	local entry = set and set[level or 1]
	if entry and ArtService.Model(entry.Name) then
		return entry.Name, entry.Height, entry.Muzzle
	end
	return MODEL_NAME[towerType], MODEL_HEIGHT[towerType], MODEL_MUZZLE[towerType]
end

local function levelEntry(towerType, level)
	local set = LEVEL_LOOKS[towerType]
	return set and set[math.clamp(level or 1, 1, #set)]
end

-- the archers of a look (the Ranger): their own painted model, standing on the look's floor, each with its own
-- breathing phase; the client (ArcherLife) turns them, draws and releases
local function placeArchers(look, entry, at, scale)
	local template = ArtService.Model("ranger_archer")
	if not template or not entry or not entry.Archers then
		return
	end
	for i, a in entry.Archers do
		local archer = template:Clone()
		archer.Name = "Archer"
		local _, size = archer:GetBoundingBox()
		archer:ScaleTo(archer:GetScale() * a[3] * scale / size.Y)
		local box, newSize = archer:GetBoundingBox()
		local feet = CFrame.new(box.Position - Vector3.new(0, newSize.Y / 2, 0))
		local spot = CFrame.new(at.Position + a[1] * scale) * CFrame.Angles(0, math.rad(a[2]), 0)
		archer:PivotTo(spot * feet:Inverse() * archer:GetPivot())
		for _, part in archer:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		archer:SetAttribute("Phase", i * 1.7)
		archer:SetAttribute("Yaw", a[2])
		archer.Parent = look
	end
end

local function useModel(model, towerType, at, drop, level, noArchers)
	local name, height = lookFor(towerType, level)
	local template = name and ArtService.Model(name)
	if not template or not height then
		return false
	end
	local look = template:Clone()
	look.Name = "Look"
	local _, size = look:GetBoundingBox()
	look:ScaleTo(look:GetScale() * height / size.Y)
	-- stand it on the spot: move the bottom centre of its box to `at`
	local box, newSize = look:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, newSize.Y / 2, 0)
	look:PivotTo(look:GetPivot() + (at.Position - bottom))
	for _, part in look:GetChildren() do
		part.Anchored = true
		part.CanCollide = true
	end
	look.Parent = model
	if not noArchers then
		placeArchers(look, levelEntry(towerType, level), at, 1) -- (the looks are built at their game height: anchors are studs)
	end
	-- the stone plinth keeps upgrades, labels and effects working; on a gentle slope it reaches down to the
	-- lowest ground under the footprint (drop studs below the stand), so no edge ever floats
	drop = drop or 0
	if model:FindFirstChild("Base") then
		return true -- an upgrade swaps only the look; the plinth stays
	end
	newPart(model, { Name = "Base", Size = Vector3.new(5, 0.55 + drop, 5), CFrame = at * CFrame.new(0, (0.55 - drop) / 2, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(81, 74, 66),
		CanCollide = false })
	return true
end

local function setLevelLabel(model, level)
	local gui = model:FindFirstChild("LevelLabel")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "LevelLabel"
		gui.Size = UDim2.fromOffset(112, 20)
		local _, lookHeight = lookFor(model:GetAttribute("TowerType"), level)
		-- clear of the top (the level 3 gem sat under the text): 2.4 studs above the look's own height
		gui.StudsOffsetWorldSpace = Vector3.new(0, (lookHeight or MODEL_HEIGHT[model:GetAttribute("TowerType")] or 9) + 2.4, 0)
		gui.MaxDistance = 26 -- only up close: from the run camera the names piled up under the wave bar
		gui.Adornee = model.PrimaryPart
		gui.Parent = model
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 220, 90)
		label.TextStrokeTransparency = 0.4
		label.TextScaled = true
		label.Parent = gui
	end
	gui:FindFirstChild("Text").Text = model.Name .. "  Lv " .. level
end

-- how wide each defender stands (radius of the ground it needs)
local FOOT = Ground.Foot
TowerService.Foot = FOOT

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- can a defender stand here? returns ok, reason
function TowerService.CanPlace(position)
	local half = Config.MapSize / 2
	if math.abs(position.X) > half.X - 4 or math.abs(position.Z) > half.Y - 4 then
		return false, "Too close to the edge"
	end
	-- the map's real outline (MapOutline): the valley side, crater wall or cave wall beyond it is scenery
	local map = Config.Maps[Config.CurrentMap]
	if map and MapOutline.OutsideOf(map.Theme, position.X, position.Z) > -MapOutline.BuildStop then
		return false, "Too close to the edge"
	end
	if Config.DistanceToPath(position) < Config.PathWidth / 2 + 3 then
		return false, "Can't build on the path"
	end
	if (Vector3.new(position.X, 0, position.Z) - Config.Path[#Config.Path]).Magnitude < 14 then
		return false, "Too close to the portal"
	end
	for _, t in towers do
		if (flat(t.position) - flat(position)).Magnitude < Config.TowerSpacing then
			return false, "Too close to another defender"
		end
	end
	-- rocks, bushes, the ruin: whatever stands on the field says how much room it takes (BlockRadius)
	local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	if decor then
		for _, d in decor:GetChildren() do
			local r = d:GetAttribute("BlockRadius")
			if r and (flat(d:GetPivot().Position) - flat(position)).Magnitude < r + 2.5 then
				return false, d:GetAttribute("BlockWhy") or "Something is in the way"
			end
		end
	end
	return true
end

function TowerService.Place(player, towerType, position)
	local info = Config.Towers[towerType]
	if not info or typeof(position) ~= "Vector3" then
		return false, "Unknown defender"
	end
	local gameState = State.Get("State")
	if gameState == "Won" or gameState == "Lost" then
		return false, "The game is over"
	end
	if State.Get("Mode") == "RangersOnly" and towerType ~= "Ranger" then
		return false, "Challenge: Rangers only!"
	end
	if info.UnlockGems and not DataService.Owns(player, "Towers", towerType) then
		return false, "Unlock the " .. info.DisplayName .. " in the Shop first"
	end
	position = Vector3.new(position.X, 0, position.Z)
	local ok, reason = TowerService.CanPlace(position)
	if not ok then
		return false, reason
	end
	-- stand on the real ground (highest point under the footprint), never on y = 0
	local height, why = Ground.Pad(position, FOOT[towerType] or 2.5)
	if not height then
		return false, why
	end
	position = Vector3.new(position.X, height, position.Z)
	local _, low = Ground.Footprint(position, FOOT[towerType] or 2.5)
	local points = Config.BuildPoints[towerType] or 0
	local used = State.Get("BuildUsed") or 0
	local limit = State.Get("BuildMax") or Config.BuildLimit
	if used + points > limit then
		return false, "Build Points full (" .. used .. "/" .. limit .. "). Sell a defender first"
	end
	if not State.TrySpend(info.Cost) then
		return false, "Not enough mana"
	end
	State.Set("BuildUsed", used + points)

	local model = Instance.new("Model")
	model.Name = info.DisplayName
	local at = CFrame.new(position)
	local muzzle, kicker, turners
	if useModel(model, towerType, at, height - low + 0.02, 1) then
		muzzle = select(3, lookFor(towerType, 1))
		-- a look's own barrel part (the Flame Cannon's "Skin_barrel") kicks back on every shot
		kicker = model.Look:FindFirstChild("Skin_barrel")
	else
		muzzle, kicker, turners = BUILDERS[towerType](model, at, info.Color)
	end
	model.PrimaryPart = model:FindFirstChild("Base")
	if typeof(player) == "Instance" then
		StoreService.ApplyModelSkin(model, StoreService.SkinFor(player, towerType))
	end
	local pickHeight = MODEL_HEIGHT[towerType] or 8
	newPart(model, { Name = "SelectionVolume", Size = Vector3.new(6, pickHeight, 6),
		CFrame = at * CFrame.new(0, pickHeight / 2, 0), Transparency = 1,
		CanCollide = false, CanTouch = false, CanQuery = true, CastShadow = false })
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("TowerType", towerType)
	model:SetAttribute("Level", 1)
	model:SetAttribute("Range", info.Levels[1].Range)
	model:SetAttribute("Spent", info.Cost)
	model:SetAttribute("Owner", player.UserId)
	setLevelLabel(model, 1)
	model.Parent = workspace.Towers

	local turnInfo = nil
	if turners then
		turnInfo = {}
		for _, part in turners do
			-- remember where each turning part sits compared to the tower's middle
			table.insert(turnInfo, { part = part, offset = at:ToObjectSpace(part.CFrame) })
		end
	end
	towers[model] = {
		owner = player,
		type = towerType,
		level = 1,
		spent = info.Cost,
		nextShot = 0,
		position = position,
		muzzle = position + muzzle,
		kicker = kicker,
		turners = turnInfo,
	}
	Effects.Ring(position + Vector3.new(0, 0.3, 0), 6, Color3.fromRGB(255, 230, 150), 0.4)
	Effects.Burst(position + Vector3.new(0, 1, 0), 4, Color3.fromRGB(200, 180, 140), 0.3, 0.4)
	Sound.Play("Build", position)
	if typeof(player) == "Instance" then
		QuestService.Add(player, "Build", 1)
		SeasonService.Funnel(player, 3)
	end
	return true
end

function TowerService.Upgrade(_player, model)
	local t = towers[model]
	if not t then
		return false, "That's not a defender"
	end
	local info = Config.Towers[t.type]
	local nextLevel = info.Levels[t.level + 1]
	if not nextLevel then
		return false, "Already at max level"
	end
	if not State.TrySpend(nextLevel.Cost) then
		return false, "Not enough mana"
	end
	t.level += 1
	t.spent += nextLevel.Cost
	model:SetAttribute("Level", t.level)
	model:SetAttribute("Range", nextLevel.Range)
	model:SetAttribute("Spent", t.spent)
	setLevelLabel(model, t.level)
	local base = model.PrimaryPart
	local name, height, muzzle = lookFor(t.type, t.level)
	local oldLook = model:FindFirstChild("Look")
	if LEVEL_LOOKS[t.type] and oldLook and name and ArtService.Model(name) then
		-- the new level's own look: swap the model and let it settle on a spring (90% -> 100% size in about 0.35 s,
		-- a little overshoot), with a small dust ring; no ceremony
		oldLook:Destroy()
		local at = CFrame.new(t.position)
		useModel(model, t.type, at, 0, t.level, true) -- (the archers step up after the settle, so they never stretch)
		local look = model:FindFirstChild("Look")
		if muzzle then
			t.muzzle = t.position + muzzle
		end
		t.kicker = look and look:FindFirstChild("Skin_barrel") or t.kicker
		local label = model:FindFirstChild("LevelLabel")
		if label then
			label.StudsOffsetWorldSpace = Vector3.new(0, height + 2.4, 0)
		end
		local volume = model:FindFirstChild("SelectionVolume")
		if volume then
			volume.Size = Vector3.new(6, height, 6)
			volume.CFrame = at * CFrame.new(0, height / 2, 0)
		end
		if look then
			local full = look:GetScale()
			local started = os.clock()
			local connection
			connection = RunService.Heartbeat:Connect(function()
				local s = os.clock() - started
				local done = not look.Parent or s > 0.45
				if done then
					connection:Disconnect()
					s = 10
				end
				-- a damped spring: starts at 90%, overshoots a touch, settles
				look:ScaleTo(full * (1 - 0.1 * math.exp(-9 * s) * math.cos(14 * s)))
				local box, size = look:GetBoundingBox()
				look:PivotTo(look:GetPivot() + (t.position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
				if done and look.Parent then
					placeArchers(look, levelEntry(t.type, t.level), at, 1)
				end
			end)
		end
		Effects.Ring(t.position + Vector3.new(0, 0.25, 0), 5, Color3.fromRGB(205, 190, 160), 0.35)
		if typeof(t.owner) == "Instance" then
			StoreService.ApplyModelSkin(model, StoreService.SkinFor(t.owner, t.type))
		end
	else
		-- towers with one look grow their plinth a little, and glow at the top level
		base.Size += Vector3.new(0.6, 0.2, 0.6)
		if t.level == #info.Levels then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 210, 80)
			glow.Range = 10
			glow.Parent = base
		end
		Effects.Burst(t.position + Vector3.new(0, 4, 0), 6, Color3.fromRGB(255, 220, 90), 0.4)
	end
	Effects.Text(t.position + Vector3.new(0, (height or 10) + 1.5, 0), "LEVEL " .. t.level, Color3.fromRGB(255, 220, 90))
	Sound.Play("Coin", t.position)
	return true
end

function TowerService.Sell(_player, model)
	local t = towers[model]
	if not t then
		return false, "That's not a defender"
	end
	local refund = math.floor(t.spent * Config.SellRefund)
	State.AddGold(refund)
	Effects.Text(t.position + Vector3.new(0, 6, 0), "+" .. refund .. " mana", Color3.fromRGB(170, 150, 255))
	Effects.Burst(t.position + Vector3.new(0, 2, 0), 5, Color3.fromRGB(200, 180, 140), 0.3, 0.4)
	Sound.Play("Coin", t.position)
	State.Set("BuildUsed", math.max(0, (State.Get("BuildUsed") or 0) - (Config.BuildPoints[t.type] or 0)))
	towers[model] = nil
	model:Destroy()
	return true, refund
end

-- a boss slam knocks defenders out for a moment
function TowerService.Stun(position, radius, seconds)
	for _, t in towers do
		if (flat(t.position) - flat(position)).Magnitude <= radius then
			t.nextShot = math.max(t.nextShot, Clock.now + seconds)
			Effects.Text(t.position + Vector3.new(0, 9, 0), "Stunned", Color3.fromRGB(255, 200, 120), 0.9)
		end
	end
end

function TowerService.Clear()
	for model in towers do
		model:Destroy()
	end
	table.clear(towers)
	for _, tur in turrets do
		tur.model:Destroy()
	end
	table.clear(turrets)
	State.Set("BuildUsed", 0)
	State.Set("BuildMax", Config.BuildLimit)
end

local function faceTarget(t, targetPos)
	if not t.turners then
		return
	end
	local flatTarget = Vector3.new(targetPos.X, t.position.Y, targetPos.Z)
	if (flatTarget - t.position).Magnitude < 0.5 then
		return
	end
	local turn = CFrame.lookAt(t.position, flatTarget)
	for _, item in t.turners do
		item.part.CFrame = turn * item.offset
		item.part:SetAttribute("HomeCFrame", nil)
	end
end

-- the owner's gear and stat points (Command = damage, Engineering = speed and range),
-- plus the Engineer's Overclock
local function boosted(t)
	local base = Config.Towers[t.type].Levels[t.level]
	local owner = t.owner
	local command, engineering = 0, 0
	if owner and owner.Parent then
		command = (owner:GetAttribute("BonusCommand") or 0) / 100
		engineering = (owner:GetAttribute("BonusEngineering") or 0) / 100
	end
	local overclock = (t.overclockUntil and Clock.now < t.overclockUntil) and t.overclockSpeed or 1
	-- a pet's Rally (damage) and Spark (speed), see PetMoves
	if t.petRallyUntil and Clock.now < t.petRallyUntil then
		command += t.petRally
	end
	if t.petSparkUntil and Clock.now < t.petSparkUntil then
		overclock *= 1 + t.petSpark
	end
	local eventDamage = Config.WeeklyEvent().TowerDamage or 1
	if command == 0 and engineering == 0 and overclock == 1 and eventDamage == 1 then
		return base
	end
	local stats = table.clone(base)
	stats.Damage = base.Damage * (1 + command) * eventDamage
	stats.Cooldown = base.Cooldown / (1 + engineering) / overclock
	stats.Range = base.Range * (1 + engineering / 2)
	return stats
end

-- Engineer's Overclock: defenders near a spot shoot faster for a while
function TowerService.Overclock(position, radius, speed, seconds)
	local count = 0
	for model, t in towers do
		if (flat(t.position) - flat(position)).Magnitude <= radius then
			t.overclockUntil = Clock.now + seconds
			t.overclockSpeed = speed
			count += 1
			Effects.Burst(t.position + Vector3.new(0, 5, 0), 4, Color3.fromRGB(255, 170, 60), 0.4)
			local base = model.PrimaryPart
			if base and not base:FindFirstChild("OverclockFire") then
				local fire = Instance.new("Sparkles")
				fire.Name = "OverclockFire"
				fire.SparkleColor = Color3.fromRGB(255, 170, 60)
				fire.Parent = base
				task.delay(seconds, function()
					fire:Destroy()
				end)
			end
		end
	end
	return count
end

-- a pet cheers on the defender nearest to a spot: kind = "Rally" (+damage) or "Spark" (+speed).
-- Prefers a defender that isn't boosted yet. Returns the defender's top position, or nil when none is near.
function TowerService.PetBoost(position, radius, kind, amount, seconds)
	local best, bestScore = nil, math.huge
	for _, t in towers do
		local d = (flat(t.position) - flat(position)).Magnitude
		if d <= radius then
			local busy = t["pet" .. kind .. "Until"] and Clock.now < t["pet" .. kind .. "Until"]
			local score = d + (busy and 1000 or 0)
			if score < bestScore then
				best, bestScore = t, score
			end
		end
	end
	if not best then
		return nil
	end
	best["pet" .. kind] = amount
	best["pet" .. kind .. "Until"] = Clock.now + seconds
	return best.position + Vector3.new(0, 5, 0)
end

-- Engineer's mini turret: shoots on its own for a while, then breaks down
function TowerService.SpawnTurret(owner, position, info)
	local model = Instance.new("Model")
	model.Name = "MiniTurret"
	local base = newPart(model, { Name = "Base", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal })
	newPart(model, { Name = "Leg", Size = Vector3.new(0.8, 2, 0.8), CFrame = CFrame.new(position + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal })
	local head = newPart(model, { Name = "Head", Size = Vector3.new(1.6, 1.2, 2.2), CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0)),
		Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Metal })
	model.PrimaryPart = base
	model.Parent = workspace:FindFirstChild("Effects") or workspace
	Effects.Burst(position + Vector3.new(0, 2, 0), 4, Color3.fromRGB(255, 190, 90), 0.3)
	table.insert(turrets, { owner = owner, model = model, head = head, position = position, info = info,
		expires = Clock.now + info.Time, nextShot = 0 })
end

local function runTurrets(now)
	for i = #turrets, 1, -1 do
		local tur = turrets[i]
		if now > tur.expires or not tur.model.Parent then
			Effects.Burst(tur.position + Vector3.new(0, 2, 0), 4, Color3.fromRGB(150, 150, 150), 0.3)
			tur.model:Destroy()
			table.remove(turrets, i)
		elseif now >= tur.nextShot then
			local target = EnemyService.InRange(tur.position, tur.info.Range)[1]
			if target then
				tur.nextShot = now + tur.info.Cooldown
				local from = tur.position + Vector3.new(0, 3.4, 0)
				local to = target.position + Vector3.new(0, target.stats.Size * 0.6, 0)
				tur.head.CFrame = CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
				Effects.Bolt(from, to, Color3.fromRGB(255, 200, 90), 0.25, 0.1)
				local command = tur.owner.Parent and (tur.owner:GetAttribute("BonusCommand") or 0) / 100 or 0
				EnemyService.Damage(target, tur.info.Damage * (1 + command))
			end
		end
	end
end

local function shoot(t, now, model)
	if now < t.nextShot then
		return
	end
	local stats = boosted(t)
	local targets = EnemyService.InRange(t.position, stats.Range)
	if #targets == 0 then
		return
	end
	t.nextShot = now + stats.Cooldown
	local first = targets[1]
	local hitAt = first.position + Vector3.new(0, first.stats.Size * 0.6, 0)

	if t.type == "Ranger" then
		faceTarget(t, first.position)
		-- the archers turn to the target, draw and release (client: ArcherLife); the arrow leaves the first one's bow
		local look = model and model:FindFirstChild("Look")
		local from = t.muzzle
		for _, archer in look and look:GetChildren() or {} do
			if archer.Name == "Archer" then
				archer:SetAttribute("AimX", hitAt.X)
				archer:SetAttribute("AimZ", hitAt.Z)
				archer:SetAttribute("Shots", (archer:GetAttribute("Shots") or 0) + 1)
				if from == t.muzzle then
					local box, size = archer:GetBoundingBox()
					local flat = Vector3.new(hitAt.X - box.Position.X, 0, hitAt.Z - box.Position.Z)
					from = box.Position + Vector3.new(0, size.Y * 0.12, 0) + (flat.Magnitude > 0.1 and flat.Unit * size.Y * 0.35 or Vector3.zero)
				end
			end
		end
		Effects.Bolt(from, hitAt, Color3.fromRGB(230, 255, 200), 0.3, 0.12)
		EnemyService.Damage(first, stats.Damage)
	elseif t.type == "FlameCannon" then
		Effects.Kick(t.kicker, 0.5)
		Effects.Bolt(t.muzzle, hitAt, Color3.fromRGB(255, 140, 40), 1, 0.2)
		task.delay(0.2, function()
			-- fire and sparks instead of a solid ball
			Effects.Ring(hitAt - Vector3.new(0, 0.8, 0), stats.Radius, Color3.fromRGB(255, 120, 40), 0.35)
			Effects.Particles(hitAt, { Texture = "Fire", Color = Color3.fromRGB(255, 190, 80), Color2 = Color3.fromRGB(255, 70, 20),
				Count = 16, Size = 2.2, EndSize = 0.4, Speed = stats.Radius * 2.2, Life = 0.45, Spread = 70 })
			Sound.Play("Explosion", hitAt)
			for _, e in EnemyService.InRange(hitAt, stats.Radius) do
				EnemyService.Damage(e, stats.Damage)
				EnemyService.Burn(e, stats.BurnDps, stats.BurnTime)
			end
		end)
	elseif t.type == "FrostCrystal" then
		Effects.Kick(t.kicker, -0.4)
		Effects.Ring(t.position + Vector3.new(0, 0.4, 0), stats.Range, Color3.fromRGB(150, 220, 255), 0.5)
		Sound.Play("Frost", t.position)
		for _, e in targets do
			EnemyService.Damage(e, stats.Damage)
			EnemyService.Slow(e, stats.Slow, stats.SlowTime)
			if stats.FreezeChance and math.random() < stats.FreezeChance and not e.stats.Boss then
				EnemyService.Freeze(e, 1)
			end
		end
	elseif t.type == "StormObelisk" then
		Effects.Kick(t.kicker, -0.5)
		Sound.Play("Zap", t.muzzle)
		-- lightning jumps from goblin to goblin
		local hit = {}
		local from = t.muzzle
		local current = first
		for _ = 1, stats.Chains do
			hit[current] = true
			local to = current.position + Vector3.new(0, current.stats.Size * 0.6, 0)
			Effects.Lightning(from, to, Color3.fromRGB(190, 170, 255))
			EnemyService.Damage(current, stats.Damage, nil, true)
			from = to
			local nextOne = nil
			for _, e in EnemyService.InRange(current.position, 14) do
				if not hit[e] then
					nextOne = e
					break
				end
			end
			if not nextOne then
				break
			end
			current = nextOne
		end
	elseif t.type == "Ballista" then
		-- aims at the toughest goblin in range
		local target = first
		for _, e in targets do
			if e.health > target.health then
				target = e
			end
		end
		faceTarget(t, target.position)
		Effects.Kick(t.kicker, -0.6)
		local aim = target.position + Vector3.new(0, target.stats.Size * 0.6, 0)
		Effects.Bolt(t.muzzle, aim, Color3.fromRGB(220, 220, 230), 0.6, 0.15)
		local damage = stats.Damage * (target.stats.Boss and stats.BossBonus or 1)
		task.delay(0.15, function()
			EnemyService.Damage(target, damage, nil, true)
			Effects.Burst(aim, 3, Color3.fromRGB(255, 255, 255), 0.2)
		end)
	end
end

function TowerService.Start()
	Remotes.PlaceTower.OnServerInvoke = TowerService.Place
	Remotes.UpgradeTower.OnServerInvoke = TowerService.Upgrade
	Remotes.SellTower.OnServerInvoke = TowerService.Sell

	RunService.Heartbeat:Connect(function()
		local now = Clock.now
		runTurrets(now)
		for model, t in towers do
			if model.Parent then
				shoot(t, now, model)
			else
				towers[model] = nil
			end
		end
	end)
end

return TowerService
