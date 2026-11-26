-- Spawns enemies and moves them along the path.
-- Enemies are plain models we move ourselves (no Humanoid), which keeps
-- the game fast even with lots of goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Memes = require(ReplicatedStorage.Shared.Memes)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Clock = require(script.Parent.Clock)
local ArtService = require(script.Parent.ArtService)
local Ground = require(ReplicatedStorage.Shared.Ground)

-- the Blender goblin, scaled to a goblin's size and painted in its colour.
-- Returns the skin parts (for hit flashes) or nil when the model isn't loaded.
local SKIN_MARKER = "c_0_255_0"
local LOOK_SCALE = 1.35 -- monsters are drawn this much bigger than their hit size (see goblinMesh)
-- the enemy each image-to-3D model was painted as: it keeps the model's own colours, its variants get a tint
local PLAIN_KIND = { Goblin = true, ["Ember Imp"] = true, ["Obsidian Knight"] = true, ["Magma Slime"] = true, Shade = true }
local function goblinMesh(model, body, stats)
	-- a rigged version (bones, art/blender/rig_monster.py) wins once it has loaded; the solid one stays the fallback
	local base = stats.Model or ("enemy_" .. string.lower(stats.Look or "Goblin"))
	local template = ArtService.Model(base .. "_rigged") or ArtService.Model(base)
	if not template then
		return nil
	end
	local s = stats.Size
	local look = template:Clone()
	look.Name = "Look"
	local _, size = look:GetBoundingBox()
	-- drawn 1.35x the hit size: from the top-down run camera on a phone the goblins were specks (cycle 6 film);
	-- hits, health and speed stay as they were
	look:ScaleTo(look:GetScale() * (s * 1.95 * LOOK_SCALE) / size.Y)
	local box, newSize = look:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, newSize.Y / 2, 0)
	-- the feet: the body rides s * 0.74 over the ground (see the walk in Start), so the model's bottom goes there
	look:PivotTo(look:GetPivot() + ((body.Position - Vector3.new(0, s * 0.74, 0)) - bottom))
	model:SetAttribute("FootHalfWidth", newSize.X / 2)
	model:SetAttribute("FootHalfDepth", newSize.Z / 2)
	local skin = {}
	for _, part in look:GetChildren() do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if part.Name == SKIN_MARKER then
			part.Color = stats.Color
			table.insert(skin, part)
		elseif part.Name == "Body" and not template:FindFirstChild(SKIN_MARKER) then
			-- an image-to-3D model has its colours painted in: the plain kind keeps them, the variants
			-- (Runner, Brute, Loot Goblin...) get a tint of their own colour over the whole model
			local plain = stats.Model ~= nil or PLAIN_KIND[stats.DisplayName or "Goblin"] -- the one the model was painted as
			part.Color = plain and Color3.new(1, 1, 1) or Color3.new(1, 1, 1):Lerp(stats.Color, 0.55)
			skin.painted = skin.painted or {}
			skin.painted[part] = part.Color -- its own tint, to come back to after freeze / burn colours
		end
	end
	look.Parent = model
	-- a skinned model with the rig's bones (art/blender/rig_monster.py): its walk, attack, hits and fall are played
	-- by MonsterAnim on every computer, so the whole-model waddle and the topple below stay off for it
	if look:FindFirstChildWhichIsA("Bone", true) then
		model:SetAttribute("Rigged", true)
	end
	return skin
end

local EnemyService = {}

-- every enemy on the map (see Spawn for what each one holds)
local active = {}

-- set by GameService
EnemyService.OnKilled = function(_enemy, _player) end
EnemyService.OnLeaked = function(_enemy) end

-- total length of the path, and how far along it each corner is
local corners = { 0 }
local pathLength = 0

-- call after Config.SetMap, so enemies follow the new map's path
function EnemyService.SetPath()
	corners = { 0 }
	pathLength = 0
	for i = 2, #Config.Path do
		pathLength += (Config.Path[i] - Config.Path[i - 1]).Magnitude
		corners[i] = pathLength
	end
end
EnemyService.SetPath()

-- where an enemy would stand on flat ground after walking `distance` studs, and which way it faces
local function flatAt(distance)
	local pts = Config.Path
	for i = 2, #pts do
		if distance <= corners[i] then
			local a, b = pts[i - 1], pts[i]
			local t = (distance - corners[i - 1]) / (corners[i] - corners[i - 1])
			return a:Lerp(b, t), (b - a).Unit
		end
	end
	return pts[#pts], (pts[#pts] - pts[#pts - 1]).Unit
end

-- the ground along the path, sampled every 2 studs once the map's terrain is built (SampleGround)
local STEP = 2
local profile = {}
function EnemyService.SampleGround()
	profile = {}
	for d = 0, pathLength + STEP, STEP do
		local p = flatAt(d)
		profile[#profile + 1] = (Ground.At(p.X, p.Z))
	end
end

local function groundAt(distance)
	if #profile == 0 then
		return 0
	end
	local f = math.clamp(distance / STEP, 0, #profile - 1)
	local i = math.floor(f)
	local a, b = profile[i + 1], profile[math.min(i + 2, #profile)]
	return a + (b - a) * (f - i)
end

-- where an enemy stands (on the real ground) after walking `distance` studs, and which way it faces
local function positionAt(distance)
	local pos, dir = flatAt(distance)
	return Vector3.new(pos.X, groundAt(distance), pos.Z), dir
end

-- the path for other services (RescueService): its length, a point on the real ground at a distance along it,
-- and how far along it a corner is
function EnemyService.PathLength()
	return pathLength
end
function EnemyService.PathPoint(distance)
	return (positionAt(distance))
end
function EnemyService.CornerDistance(index)
	return corners[math.clamp(index, 1, #corners)] or 0
end

local function newPart(model, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- health bar (and the name for bosses) over the head. Returns the fill bar.
function EnemyService.HealthBar(model, head, stats)
	local s = stats.Size
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = stats.Boss and UDim2.fromOffset(180, 30) or UDim2.fromOffset(50, 6)
	gui.StudsOffset = Vector3.new(0, s * (0.9 + (LOOK_SCALE - 1) * 1.6), 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Adornee = head
	-- small bars only once a monster is hurt (EnemyService.Damage shows it); bosses always show theirs
	gui.Enabled = stats.Boss == true
	gui.Parent = model
	local back = Instance.new("Frame")
	back.Size = stats.Boss and UDim2.new(1, 0, 0, 14) or UDim2.fromScale(1, 1)
	back.Position = stats.Boss and UDim2.fromOffset(0, 16) or UDim2.new()
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = stats.Boss and Color3.fromRGB(200, 60, 255)
		or stats.Loot and Color3.fromRGB(255, 210, 60)
		or Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	if stats.Boss then
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 16)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 220, 90)
		title.TextStrokeTransparency = 0.3
		title.Text = stats.DisplayName
		title.Parent = gui
	end

	return fill
end

-- builds a goblin out of blocks. Big ones get a club, the king a crown,
-- the Loot Goblin a big bag of gems.
local function makeGoblin(name, stats)
	local s = stats.Size
	local model = Instance.new("Model")
	model.Name = name

	local look = stats.Look or "Goblin"
	-- the painted Blender model, when it has loaded (every look has one); the block looks below are the fallback
	if ArtService.Model(stats.Model or ("enemy_" .. string.lower(look))) then
		local body = newPart(model, { Name = "Body", Size = Vector3.new(s, s, s * 0.8), Transparency = 1 })
		model.PrimaryPart = body
		local head = newPart(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.7, Transparency = 1,
			CFrame = body.CFrame * CFrame.new(0, s * 0.8, 0) })
		local ok, skin = pcall(goblinMesh, model, body, stats)
		if ok and skin then
			model:SetAttribute("Mesh", true)
			if stats.Boss then
				-- a glow, so the boss stands out in a crowd. A boss with its own painted model wears its own crown;
				-- only one without gets the floating golden one, above the head of the bigger drawn look.
				-- (2026-11-23, Lemp: "yellow bars in front of the bosses face": the six crown bars were placed for the
				-- old size and sat across the eyes since monsters are drawn 1.35x.)
				if not stats.Model then
					for i = 0, 5 do
						local angle = i / 6 * math.pi * 2
						newPart(model, { Name = "Crown", Size = Vector3.new(s * 0.1, s * 0.28, s * 0.1), Color = Color3.fromRGB(255, 205, 60),
							Material = Enum.Material.Neon,
							CFrame = head.CFrame * CFrame.new(math.cos(angle) * s * 0.24, s * (0.62 + (LOOK_SCALE - 1) * 1.6),
								math.sin(angle) * s * 0.24) })
					end
				end
				local light = Instance.new("PointLight")
				light.Color = stats.Color
				light.Range = s * 3
				light.Brightness = 1.5
				light.Parent = body
			end
			return model, EnemyService.HealthBar(model, head, stats), head, skin
		end
		model:ClearAllChildren()
	end
	if look == "Shade" then
		local body = newPart(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * s, Color = stats.Color,
			Material = Enum.Material.Neon, Transparency = 0.35 })
		model.PrimaryPart = body
		local head = newPart(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.55, Color = stats.Color,
			Transparency = 0.2, CFrame = body.CFrame * CFrame.new(0, s * 0.35, -s * 0.1) })
		for side = -1, 1, 2 do
			newPart(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.16, Color = Color3.fromRGB(180, 120, 255),
				Material = Enum.Material.Neon, CFrame = body.CFrame * CFrame.new(side * s * 0.16, s * 0.35, -s * 0.38) })
		end
		newPart(model, { Name = "Tail", ClassName = "WedgePart", Size = Vector3.new(s * 0.3, s * 0.5, s * 0.9), Color = stats.Color,
			Material = Enum.Material.Neon, Transparency = 0.5, CFrame = body.CFrame * CFrame.new(0, -s * 0.2, s * 0.6) })
		if stats.Boss then
			for i = 0, 4 do
				local angle = i / 5 * math.pi * 2
				newPart(model, { Name = "Crown", Size = Vector3.new(s * 0.1, s * 0.3, s * 0.1), Color = Color3.fromRGB(200, 140, 255),
					Material = Enum.Material.Neon, CFrame = head.CFrame * CFrame.new(math.cos(angle) * s * 0.2, s * 0.35, math.sin(angle) * s * 0.2) })
			end
		end
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(160, 100, 255)
		light.Range = s * 3
		light.Parent = body
		return model, EnemyService.HealthBar(model, head, stats), head
	end
	if look == "Slime" then
		-- a wobbly blob with two eyes
		local body = newPart(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Color = stats.Color,
			Material = Enum.Material.Neon, Transparency = 0.15 })
		model.PrimaryPart = body
		local head = newPart(model, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.5, Color = stats.Color,
			Material = Enum.Material.Neon, CFrame = body.CFrame * CFrame.new(0, s * 0.35, 0) })
		for side = -1, 1, 2 do
			newPart(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.18, Color = Color3.new(0, 0, 0),
				CFrame = body.CFrame * CFrame.new(side * s * 0.18, s * 0.15, -s * 0.42) })
		end
		return model, EnemyService.HealthBar(model, head, stats), head
	end
	local body = newPart(model, { Name = "Body", Size = Vector3.new(s, s, s * 0.8), Color = stats.Color,
		Material = look == "Golem" and Enum.Material.Basalt or look == "Knight" and Enum.Material.Metal or Enum.Material.Plastic })
	model.PrimaryPart = body
	local head = newPart(model, {
		Name = "Head",
		Shape = look == "Knight" and Enum.PartType.Block or Enum.PartType.Ball,
		Size = Vector3.one * s * 0.7,
		Color = stats.Color,
		CFrame = body.CFrame * CFrame.new(0, s * 0.8, 0),
	})
	local skin = nil
	do -- every enemy type has a painted Blender model (the block look is only the fallback while it loads)
		local ok, result = pcall(goblinMesh, model, body, stats)
		if ok then
			skin = result
		else
			warn("Art: goblin mesh failed: " .. tostring(result))
		end
	end
	if skin then
		body.Transparency = 1
		head.Transparency = 1
		model:SetAttribute("Mesh", true)
	end
	for side = -1, 1, 2 do
		if skin then
			break -- the mesh already has ears, eyes and legs
		end
		if look == "Imp" then
			newPart(model, { -- little horn
				Name = "Horn",
				Size = Vector3.new(s * 0.12, s * 0.35, s * 0.12),
				Color = Color3.fromRGB(40, 30, 30),
				CFrame = head.CFrame * CFrame.new(side * s * 0.2, s * 0.38, 0) * CFrame.Angles(0, 0, side * math.rad(-20)),
			})
		elseif look == "Knight" then
			newPart(model, { -- shoulder plate
				Name = "Shoulder",
				Size = Vector3.new(s * 0.4, s * 0.2, s * 0.6),
				Color = Color3.fromRGB(120, 110, 130),
				Material = Enum.Material.Metal,
				CFrame = body.CFrame * CFrame.new(side * s * 0.6, s * 0.45, 0),
			})
		elseif look == "Golem" then
			newPart(model, { -- huge rock fist
				Name = "Fist",
				Size = Vector3.one * s * 0.45,
				Color = stats.Color,
				Material = Enum.Material.Basalt,
				CFrame = body.CFrame * CFrame.new(side * s * 0.75, -s * 0.1, -s * 0.2),
			})
		else
			newPart(model, { -- pointy ear
				ClassName = "WedgePart",
				Name = "Ear",
				Size = Vector3.new(0.3, s * 0.3, s * 0.4),
				Color = stats.Color,
				CFrame = head.CFrame * CFrame.new(side * s * 0.4, s * 0.1, 0) * CFrame.Angles(0, 0, side * math.rad(-30)),
			})
		end
		newPart(model, { -- red eye
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.15,
			Color = (look == "Golem" or look == "Imp") and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
			CFrame = head.CFrame * CFrame.new(side * s * 0.15, s * 0.05, -s * 0.36),
		})
		newPart(model, { -- leg
			Name = "Leg",
			Size = Vector3.new(s * 0.3, s * 0.4, s * 0.3),
			Color = Color3.fromRGB(70, 50, 35),
			CFrame = body.CFrame * CFrame.new(side * s * 0.25, -s * 0.6, 0),
		})
	end
	-- a big goofy nose
	newPart(model, {
		Transparency = skin and 1 or 0,
		Name = "Nose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s * 0.2,
		Color = stats.Color:Lerp(Color3.new(0, 0, 0), 0.25),
		CFrame = head.CFrame * CFrame.new(0, -s * 0.08, -s * 0.36),
	})
	if look == "Golem" then
		-- glowing lava cracks
		newPart(model, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.45, Color = Color3.fromRGB(255, 120, 30),
			Material = Enum.Material.Neon, CFrame = body.CFrame * CFrame.new(0, 0, -s * 0.3) })
		Instance.new("Fire", body).Size = s
	elseif look == "Knight" then
		newPart(model, { Name = "Visor", Size = Vector3.new(s * 0.5, s * 0.08, 0.2), Color = Color3.fromRGB(255, 120, 40),
			Material = Enum.Material.Neon, CFrame = head.CFrame * CFrame.new(0, s * 0.05, -s * 0.36) })
		newPart(model, { Name = "Shield", Size = Vector3.new(0.3, s * 0.8, s * 0.6), Color = Color3.fromRGB(110, 100, 120),
			Material = Enum.Material.Metal, CFrame = body.CFrame * CFrame.new(-s * 0.65, 0, -s * 0.2) })
	elseif look == "Imp" then
		Instance.new("Fire", head).Size = s * 0.8
	elseif s >= 4 then
		newPart(model, { -- club
			Name = "Club",
			Size = Vector3.new(s * 0.25, s * 0.25, s * 1.1),
			Color = Color3.fromRGB(100, 70, 40),
			Material = Enum.Material.Wood,
			CFrame = body.CFrame * CFrame.new(s * 0.7, s * 0.1, -s * 0.3) * CFrame.Angles(math.rad(30), 0, 0),
		})
	end
	if stats.Loot then
		local bag = newPart(model, {
			Name = "Bag",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 1.1,
			Color = Color3.fromRGB(140, 100, 60),
			Material = Enum.Material.Fabric,
			CFrame = body.CFrame * CFrame.new(0, s * 0.3, s * 0.7),
		})
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(120, 230, 255)
		sparkles.Parent = bag
	end
	if stats.Boss then
		for i = 0, 4 do -- crown spikes
			local angle = i / 5 * math.pi * 2
			newPart(model, {
				Name = "Crown",
				Size = Vector3.new(s * 0.12, s * 0.25, s * 0.12),
				Color = Color3.fromRGB(255, 200, 40),
				Material = Enum.Material.Neon,
				CFrame = head.CFrame * CFrame.new(math.cos(angle) * s * 0.25, s * 0.38, math.sin(angle) * s * 0.25),
			})
		end
		-- a cape
		newPart(model, {
			Name = "Cape",
			Size = Vector3.new(s * 0.9, s * 1.1, 0.2),
			Color = Color3.fromRGB(170, 30, 50),
			Material = Enum.Material.Fabric,
			CFrame = body.CFrame * CFrame.new(0, -s * 0.05, s * 0.45),
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(200, 120, 255)
		light.Range = 20
		light.Parent = body
	end

	return model, EnemyService.HealthBar(model, head, stats), head, skin
end

function EnemyService.Spawn(name, healthMultiplier, startDistance)
	local stats = Config.Enemies[name]
	local model, fill, head, skin = makeGoblin(name, stats)
	-- a soft dark blob under the feet: separates the monster from the grass on a phone even with shadows off
	-- (no Highlight outlines: they crash weak phones, 6A)
	local blob = newPart(model, { Name = "Blob", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, stats.Size * 1.5 * LOOK_SCALE, stats.Size * 1.5 * LOOK_SCALE),
		CFrame = model:GetPivot() * CFrame.new(0, -stats.Size * 0.74 + 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(25, 30, 20), Material = Enum.Material.SmoothPlastic, Transparency = 0.55, CastShadow = false })
	blob.CanQuery = false
	local hp = math.floor(stats.Health * (healthMultiplier or 1))
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)
	model:PivotTo(CFrame.new(positionAt(startDistance or 0) + Vector3.new(0, stats.Size * 0.74 + Ground.Feet, 0)))
	model.Parent = workspace:FindFirstChild("Enemies") or workspace
	local enemy = {
		name = name,
		model = model,
		fill = fill,
		head = head,
		skin = skin,
		stats = stats,
		health = hp,
		maxHealth = hp,
		distance = startDistance or 0,
		healthMultiplier = healthMultiplier or 1,
		position = Config.Path[1],
		slowUntil = 0,
		slowFactor = 1,
		frozenUntil = 0,
		burnUntil = 0,
		burnDps = 0,
		flashUntil = 0,
		saidHurt = false,
		nextQuote = Clock.now + 3,
		dead = false,
		rigged = model:GetAttribute("Rigged") == true,
	}
	table.insert(active, enemy)

	if stats.Boss then
		Effects.Bubble(head, Memes.Pick(Memes.Boss), Color3.fromRGB(120, 20, 120), 3)
	elseif stats.Loot then
		Effects.Bubble(head, Memes.Pick(Memes.Loot), Color3.fromRGB(150, 110, 0))
	elseif math.random() < 0.18 then
		Effects.Bubble(head, Memes.Pick(Memes.Spawn))
	end
	return enemy
end

local function kill(enemy, player)
	if enemy.dead then
		return
	end
	enemy.dead = true
	local center = enemy.position + Vector3.new(0, enemy.stats.Size / 2, 0)
	Effects.Burst(center, enemy.stats.Size * 1.2, enemy.stats.Color, 0.3)
	if enemy.stats.Boss then
		Effects.Burst(center, 30, Color3.fromRGB(255, 220, 90), 1.2, 0.2)
		Sound.Play("BossDie", center)
		Sound.Play("Explosion", center)
	else
		Sound.Play("GoblinDie", center)
	end
	EnemyService.OnKilled(enemy, player)
	-- slimes split into smaller slimes
	local split = enemy.stats.SplitInto
	if split and Config.Enemies[split] then
		for i = 1, enemy.stats.SplitCount or 2 do
			local bit = EnemyService.Spawn(split, enemy.healthMultiplier, math.max(0, enemy.distance - i * 2))
			bit.position = enemy.position
		end
	end
end

-- player is optional: who hit it (the hero), for xp.
-- showNumber shows a floating damage number.
-- from is optional: where the blow came from (the hero, the tower, the blast), so a rigged monster rocks away from it
function EnemyService.Damage(enemy, amount, player, showNumber, crit, from)
	if enemy.dead then
		return
	end
	-- armor takes a flat bite out of every hit (but never more than 75%)
	local armor = enemy.stats.Armor
	if enemy.crackedUntil and Clock.now < enemy.crackedUntil then
		armor = nil -- cracked by the King's Cleaver: full damage from everyone for a moment
	end
	if armor and amount >= 1 then
		amount = math.max(amount - armor, amount * 0.25)
	end
	-- a boss that staggered out of a broken charge takes more damage for a moment (BossService)
	if enemy.weakUntil and Clock.now < enemy.weakUntil then
		amount *= enemy.stats.Charge.Weak
	end
	-- heroes hitting a boss during its charge wind-up: enough hits break the charge
	local charging = enemy.charging
	if charging and player and amount >= 1 then
		charging.hits += 1
		if charging.hits >= enemy.stats.Charge.BreakHits then
			enemy.charging = nil
			enemy.weakUntil = Clock.now + enemy.stats.Charge.WeakTime
			enemy.knockLeft = (enemy.knockLeft or 0) + enemy.stats.Charge.Knock
			enemy.hitStopUntil = math.max(enemy.hitStopUntil or 0, Clock.now + 0.6)
			enemy.nextCharge = Clock.now + enemy.stats.Charge.Every
			enemy.nextSlam = math.max(enemy.nextSlam or 0, enemy.weakUntil + 1) -- the opening stays safe
			EnemyService.OnChargeEnd(enemy, charging.target, true, player)
		end
	end
	-- a pet's Mark (PetMoves): the next real hit is a sure crit, and the mark goes away
	if enemy.petMark and amount >= 1 then
		if not crit then
			amount *= 2
			crit = true
		end
		showNumber = true
		enemy.petMark:Destroy()
		enemy.petMark = nil
	end
	enemy.health -= amount
	enemy.model:SetAttribute("Health", enemy.health)
	enemy.fill.Size = UDim2.fromScale(math.max(enemy.health / enemy.maxHealth, 0), 1)
	local bar = enemy.model:FindFirstChild("HealthBar")
	if bar and not bar.Enabled then
		bar.Enabled = true
	end
	if amount >= 1 then
		enemy.flashUntil = Clock.now + 0.08 -- quick white flash
		if enemy.rigged then
			if from then
				enemy.model:SetAttribute("HitFromX", from.X)
				enemy.model:SetAttribute("HitFromZ", from.Z)
			end
			enemy.model:SetAttribute("HitAt", workspace:GetServerTimeNow()) -- MonsterAnim rocks it back, away from "from"
		end
	end
	if showNumber then
		local big = amount >= 60 or crit
		local color = crit and Color3.fromRGB(255, 230, 60) or big and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(255, 255, 255)
		Effects.Text(enemy.position + Vector3.new(math.random() * 2 - 1, enemy.stats.Size * 1.3, 0),
			(crit and "CRIT " or "") .. tostring(math.floor(amount)), color, big and 1.4 or 0.8)
	end
	if enemy.stats.Dummy and enemy.health <= 0 then
		enemy.health = enemy.maxHealth -- the training knight never falls
		enemy.model:SetAttribute("Health", enemy.health)
		enemy.fill.Size = UDim2.fromScale(1, 1)
	end
	if enemy.health <= 0 then
		kill(enemy, player)
	elseif not enemy.saidHurt and enemy.health < enemy.maxHealth * 0.35 then
		enemy.saidHurt = true
		if math.random() < 0.25 and not enemy.stats.Boss then
			Effects.Bubble(enemy.head, Memes.Pick(Memes.Hurt), Color3.fromRGB(160, 30, 30), 1.8)
		end
	end
end

-- pushes an enemy back along the path, eased over about 0.28 s (bosses barely move)
-- the enemy is hitting something (a hero in its way; the barricade branch: the barricade it bashes): MonsterAnim
-- plays the attack while this is on. Written only when it changes.
function EnemyService.SetBashing(enemy, on)
	on = on == true
	if (enemy.bashingShown or false) ~= on then
		enemy.bashingShown = on
		enemy.model:SetAttribute("Bashing", on)
	end
end

function EnemyService.Knockback(enemy, studs)
	if enemy.dead or not studs or studs <= 0 then
		return
	end
	if enemy.stats.Boss then
		studs *= 0.15
	end
	enemy.knockLeft = (enemy.knockLeft or 0) + studs
end

-- a tiny freeze on heavy hits so they feel solid
function EnemyService.HitStop(enemy, seconds)
	enemy.hitStopUntil = math.max(enemy.hitStopUntil or 0, Clock.now + (seconds or 0.07))
end

-- set by GameService: a boss slam hits heroes and stuns defenders near it
EnemyService.OnBossSlam = function(_position, _radius) end
-- set by BossService: a boss's charge at a defender (stats.Charge): who it aims at, the tell, and the end of it
EnemyService.PickChargeTarget = function(_enemy, _range) return nil end
EnemyService.OnChargeTell = function(_enemy, _target, _seconds) end
EnemyService.OnChargeEnd = function(_enemy, _target, _broken, _by) end

function EnemyService.Slow(enemy, factor, seconds)
	local now = Clock.now
	if factor <= enemy.slowFactor or now > enemy.slowUntil then
		enemy.slowFactor = factor
	end
	enemy.slowUntil = math.max(enemy.slowUntil, now + seconds)
end

function EnemyService.Freeze(enemy, seconds)
	enemy.frozenUntil = math.max(enemy.frozenUntil, Clock.now + seconds)
end

function EnemyService.Burn(enemy, dps, seconds)
	if enemy.stats.FireImmune then
		return
	end
	enemy.burnDps = math.max(enemy.burnDps, dps)
	enemy.burnUntil = math.max(enemy.burnUntil, Clock.now + seconds)
end

function EnemyService.GetActive()
	return active
end

-- enemies within `radius` of a point, the one furthest along the path first
-- bodies = true: count from the enemy's body, not its middle (a sword reaches a big boss's belly; the batch film
-- showed a hero swinging beside the Goblin King and missing, because his middle was out of reach)
function EnemyService.InRange(position, radius, bodies)
	local found = {}
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, e in active do
		local reach = radius + (bodies and e.stats.Size * 0.5 or 0)
		if not e.dead and (Vector3.new(e.position.X, 0, e.position.Z) - flat).Magnitude <= reach then
			table.insert(found, e)
		end
	end
	table.sort(found, function(a, b)
		return a.distance > b.distance
	end)
	return found
end

-- removes every enemy (they leave the list on the next frame)
function EnemyService.Clear()
	for _, e in active do
		e.dead = true
		e.model:Destroy()
	end
end

-- enemies of the run (the Outpost's training knight doesn't count)
function EnemyService.Count()
	local n = 0
	for _, e in active do
		if not e.stats.Dummy then
			n += 1
		end
	end
	return n
end

-- the training knight at a spot on the ground, facing `look` (Config.Enemies.TrainingKnight)
function EnemyService.SpawnDummy(position, look)
	local e = EnemyService.Spawn("TrainingKnight", 1, 0)
	local stats = e.stats
	e.position = position
	e.model:PivotTo(CFrame.lookAt(position + Vector3.new(0, stats.Size * 0.74 + Ground.Feet, 0),
		position + Vector3.new(look.X, stats.Size * 0.74 + Ground.Feet, look.Z)))
	return e
end

local WHITE = Color3.new(1, 1, 1)

function EnemyService.Start()
	RunService.Heartbeat:Connect(function(realDt)
		local dt = realDt * Clock.scale
		local now = Clock.now
		for i = #active, 1, -1 do
			local e = active[i]
			if not e.dead and now < e.burnUntil then
				EnemyService.Damage(e, e.burnDps * dt)
			end
			if e.dead then
				table.remove(active, i)
				-- a short fall instead of vanishing (6A: nothing just pops): the body topples backwards over 0.3 s,
				-- sinks a little, a small dust ring, then it is gone. Bosses keep their own big burst.
				local model = e.model
				local health = model:FindFirstChild("HealthBar")
				if health then
					health:Destroy()
				end
				local start = model:GetPivot()
				local s = e.stats.Size
				local t0 = os.clock()
				Effects.Ring(e.position + Vector3.new(0, 0.2, 0), s * 0.9, Color3.fromRGB(190, 175, 150), 0.3)
				if e.rigged then
					-- MonsterAnim plays the fall on the bones (knees give, forward onto the face, 0.6 s); the body
					-- stays where it fell until then
					model:SetAttribute("Dead", true)
					task.delay(0.7, function()
						model:Destroy()
					end)
					continue
				end
				local fall
				fall = RunService.Heartbeat:Connect(function()
					local t = math.min(1, (os.clock() - t0) / 0.3)
					local ease = 1 - (1 - t) ^ 3
					if model.Parent then
						model:PivotTo(start * CFrame.new(0, -s * 0.35 * ease, 0) * CFrame.Angles(math.rad(75) * ease, 0, 0))
					end
					if t >= 1 then
						fall:Disconnect()
						model:Destroy()
					end
				end)
				continue
			end
			if e.stats.Dummy then
				e.knockLeft = 0 -- the training knight stands where it was put (SpawnDummy)
				continue
			end

			local speed = e.stats.Speed * (e.speedMult or 1) * (e.enraged and 1.4 or 1)
			if e.knockLeft and e.knockLeft > 0.01 then
				-- knockback: ease backwards (1 - exp(-k*dt), about 0.28 s to settle)
				local move = e.knockLeft * (1 - math.exp(-12 * dt))
				e.knockLeft -= move
				e.distance = math.max(0, e.distance - move)
				speed = 0
			end
			if now < (e.hitStopUntil or 0) then
				speed = 0
			end
			-- bosses: get angry at half health, and slam the ground every few seconds
			if e.stats.Boss then
				if not e.enraged and e.health < e.maxHealth * 0.5 then
					e.enraged = true
					e.nextSlam = math.min(e.nextSlam or now, now + 1.5)
					Effects.Text(e.position + Vector3.new(0, e.stats.Size * 1.6, 0), "ENRAGED!", Color3.fromRGB(255, 80, 80), 1.6)
					Sound.Play("PortalHit", e.position)
				end
				-- the charge at a defender (stats.Charge, BossService draws it): stands still while winding up
				local charge = e.stats.Charge
				if charge then
					e.nextCharge = e.nextCharge or (now + charge.First)
					if e.charging then
						speed = 0
						if now >= e.charging.endsAt then
							local done = e.charging
							e.charging = nil
							e.nextCharge = now + charge.Every
							EnemyService.OnChargeEnd(e, done.target, false, nil)
						end
					elseif now >= e.nextCharge and not e.slamming then
						local target = EnemyService.PickChargeTarget(e, charge.Range)
						if target then
							e.charging = { target = target, endsAt = now + charge.Windup, hits = 0 }
							e.nextSlam = math.max(e.nextSlam or now, now + charge.Windup + 1.5) -- no slam in the middle
							EnemyService.OnChargeTell(e, target, charge.Windup)
						else
							e.nextCharge = now + 2 -- nothing in reach yet: look again soon
						end
					end
				end
				e.nextSlam = e.nextSlam or (now + 5)
				if now >= e.nextSlam and not e.slamming and not e.charging then
					e.slamming = true
					local spot = e.position
					local radius = 14
					-- the warning: a red circle 0.9 s before the hit, escapable by stepping out
					Effects.Ring(spot + Vector3.new(0, 0.3, 0), radius, Color3.fromRGB(255, 40, 40), 0.9)
					task.delay(0.9, function()
						e.slamming = false
						e.slamRecoverUntil = Clock.now + 0.7 -- (stands while it rises from the smash; MonsterMoves.Slam)
						e.nextSlam = Clock.now + (e.enraged and 3.5 or 6)
						if e.dead then
							return
						end
						Effects.Shockwave(spot, radius, Color3.fromRGB(255, 120, 80))
						Sound.Play("Explosion", spot)
						EnemyService.OnBossSlam(spot, radius)
					end)
				end
				if e.slamming or (e.slamRecoverUntil and now < e.slamRecoverUntil) then
					speed = 0 -- it stops to wind up the slam, and to rise from it
				end
				-- what the boss is winding up, for MonsterAnim's tells (written only when it changes)
				local tell = e.slamming and "slam" or e.charging and "charge" or ""
				if e.rigged and e.tellShown ~= tell then
					e.tellShown = tell
					e.model:SetAttribute("Tell", tell)
				end
			end
			if now < e.frozenUntil then
				speed = 0
			elseif now < e.slowUntil then
				speed *= e.slowFactor
			else
				e.slowFactor = 1
			end
			e.distance += speed * dt
			-- shadows teleport forward now and then
			local blink = e.stats.Blink
			if blink and speed > 0 then
				e.nextBlink = e.nextBlink or (now + blink.Every)
				if now >= e.nextBlink then
					e.nextBlink = now + blink.Every
					Effects.Burst(e.position + Vector3.new(0, e.stats.Size * 0.5, 0), e.stats.Size, Color3.fromRGB(140, 80, 220), 0.3)
					e.distance += blink.Distance
				end
			end
			-- the Shadow Queen calls helpers
			local summon = e.stats.Summon
			if summon then
				e.nextSummon = e.nextSummon or (now + summon.Every)
				if now >= e.nextSummon then
					e.nextSummon = now + summon.Every
					if e.rigged then
						e.model:SetAttribute("SummonAt", workspace:GetServerTimeNow()) -- MonsterAnim: the summon tell
					end
					for i = 1, summon.Count do
						EnemyService.Spawn(summon.Enemy, e.healthMultiplier, math.max(0, e.distance - i * 3))
					end
					Effects.Ring(e.position + Vector3.new(0, 0.5, 0), 10, Color3.fromRGB(160, 80, 255), 0.5)
				end
			end

			if e.distance >= pathLength then
				-- it reached the portal
				e.dead = true
				if e.stats.Damage > 0 and math.random() < 0.3 then
					Effects.Text(Config.Path[#Config.Path] + Vector3.new(0, 8, 0), Memes.Pick(Memes.Leak), Color3.fromRGB(255, 120, 120), 1.2)
				end
				EnemyService.OnLeaked(e)
				e.model:Destroy()
				table.remove(active, i)
			else
				local pos, dir = positionAt(e.distance)
				e.position = pos
				local s = e.stats.Size
				-- little hop while walking (rigged monsters walk on their own legs: MonsterAnim)
				local hop = e.rigged and 0 or math.abs(math.sin(e.distance * 0.8)) * 0.3 * s / 3
				-- the Loot Goblin zig-zags, the king stomps
				local side = Vector3.zero
				if e.stats.Loot then
					side = Vector3.new(-dir.Z, 0, dir.X) * math.sin(e.distance * 0.35) * 2.5
					-- off the middle of the path: stand on the ground where it really is (the kerb is higher)
					local x, z = pos.X + side.X, pos.Z + side.Z
					pos = Vector3.new(pos.X, (Ground.At(x, z)), pos.Z)
				end
				-- turn smoothly at corners, waddle from foot to foot, lean into the walk (solid models, no skeleton)
				-- (a rigged boss turns slower: its feet step round instead of sliding, MonsterAnim)
				local turnRate = (e.rigged and e.stats.Boss) and 3.5 or 9
				e.facing = e.facing and e.facing:Lerp(dir, math.min(1, dt * turnRate)) or dir
				if e.facing.Magnitude < 0.01 then
					e.facing = dir
				end
				local step = e.distance * 0.8
				local moving = speed > 0 and 1 or 0
				local waddle = (e.stats.Look == "Slime" or e.rigged) and 0 or math.sin(step) * 0.13 * moving
				local lean = e.rigged and 0 or e.stats.Look == "Shade" and -0.18 or -0.07 * moving
				-- tilting swings the model's lower edge down: lift by exactly that, so feet stay Ground.Feet over the ground
				local tilt = (e.model:GetAttribute("FootHalfWidth") or s * 0.4) * math.abs(math.sin(waddle))
					+ (e.model:GetAttribute("FootHalfDepth") or s * 0.4) * math.abs(math.sin(lean))
				e.hop = hop
				local up = Vector3.new(0, s * 0.74 + hop + tilt + Ground.Feet, 0)
				e.model:PivotTo(CFrame.lookAt(pos + up + side, pos + up + side + e.facing.Unit) * CFrame.Angles(lean, 0, waddle))

				-- boss says things from time to time
				if e.stats.Boss and now > e.nextQuote then
					e.nextQuote = now + 7
					Effects.Bubble(e.head, Memes.Pick(Memes.Boss), Color3.fromRGB(120, 20, 120), 3)
				end

				-- white when hit, blue when frozen, orange when burning
				local tint = e.stats.Color
				if now < e.flashUntil then
					tint = WHITE
				elseif now < e.frozenUntil then
					tint = Color3.fromRGB(150, 220, 255)
				elseif now < e.burnUntil then
					tint = e.stats.Color:Lerp(Color3.fromRGB(255, 120, 30), 0.5)
				elseif now < e.slowUntil then
					tint = e.stats.Color:Lerp(Color3.fromRGB(120, 200, 255), 0.4)
				end
				if e.tint ~= tint then
					e.tint = tint
					e.model.Body.Color = tint
					e.head.Color = tint
					if e.skin then
						for _, part in ipairs(e.skin) do
							part.Color = tint
						end
						-- painted models can't go "whiter", so a hit makes them pop bigger for a moment instead;
						-- freeze, burn and slow tint the paint
						if e.skin.painted then
							local effect = tint ~= e.stats.Color and tint ~= WHITE
							for part, base in e.skin.painted do
								part.Color = effect and base:Lerp(tint, 0.55) or base
							end
							local pop = tint == WHITE and 1.12 or 1
							if e.pop ~= pop then
								e.pop = pop
								e.model:ScaleTo(pop)
							end
						end
					end
				end
			end
		end
	end)
end

return EnemyService
