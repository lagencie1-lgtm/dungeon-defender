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

local EnemyService = {}

-- every enemy on the map (see Spawn for what each one holds)
local active = {}

-- set by GameService
EnemyService.OnKilled = function(_enemy, _player) end
EnemyService.OnLeaked = function(_enemy) end

-- total length of the path, and how far along it each corner is
local corners = { 0 }
local pathLength = 0
for i = 2, #Config.Path do
	pathLength += (Config.Path[i] - Config.Path[i - 1]).Magnitude
	corners[i] = pathLength
end

-- where an enemy stands after walking `distance` studs, and which way it faces
local function positionAt(distance)
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

-- builds a goblin out of blocks. Big ones get a club, the king a crown,
-- the Loot Goblin a big bag of gems.
local function makeGoblin(name, stats)
	local s = stats.Size
	local model = Instance.new("Model")
	model.Name = name

	local body = newPart(model, { Name = "Body", Size = Vector3.new(s, s, s * 0.8), Color = stats.Color })
	model.PrimaryPart = body
	local head = newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s * 0.7,
		Color = stats.Color,
		CFrame = body.CFrame * CFrame.new(0, s * 0.8, 0),
	})
	for side = -1, 1, 2 do
		newPart(model, { -- pointy ear
			ClassName = "WedgePart",
			Name = "Ear",
			Size = Vector3.new(0.3, s * 0.3, s * 0.4),
			Color = stats.Color,
			CFrame = head.CFrame * CFrame.new(side * s * 0.4, s * 0.1, 0) * CFrame.Angles(0, 0, side * math.rad(-30)),
		})
		newPart(model, { -- red eye
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.15,
			Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
			CFrame = head.CFrame * CFrame.new(side * s * 0.15, s * 0.05, -s * 0.32),
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
		Name = "Nose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s * 0.2,
		Color = stats.Color:Lerp(Color3.new(0, 0, 0), 0.25),
		CFrame = head.CFrame * CFrame.new(0, -s * 0.08, -s * 0.36),
	})
	if s >= 4 then
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

	-- health bar (and name for special goblins) over the head
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = stats.Boss and UDim2.fromOffset(180, 30) or UDim2.fromOffset(50, 6)
	gui.StudsOffset = Vector3.new(0, s * 0.9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Adornee = head
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

	return model, fill, head
end

function EnemyService.Spawn(name, healthMultiplier)
	local stats = Config.Enemies[name]
	local model, fill, head = makeGoblin(name, stats)
	local hp = math.floor(stats.Health * (healthMultiplier or 1))
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)
	model:PivotTo(CFrame.new(Config.Path[1] + Vector3.new(0, stats.Size, 0)))
	model.Parent = workspace:FindFirstChild("Enemies") or workspace
	local enemy = {
		name = name,
		model = model,
		fill = fill,
		head = head,
		stats = stats,
		health = hp,
		maxHealth = hp,
		distance = 0,
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
end

-- player is optional: who hit it (the hero), for xp.
-- showNumber shows a floating damage number.
function EnemyService.Damage(enemy, amount, player, showNumber, crit)
	if enemy.dead then
		return
	end
	enemy.health -= amount
	enemy.model:SetAttribute("Health", enemy.health)
	enemy.fill.Size = UDim2.fromScale(math.max(enemy.health / enemy.maxHealth, 0), 1)
	if amount >= 1 then
		enemy.flashUntil = Clock.now + 0.08 -- quick white flash
	end
	if showNumber then
		local big = amount >= 60 or crit
		local color = crit and Color3.fromRGB(255, 230, 60) or big and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(255, 255, 255)
		Effects.Text(enemy.position + Vector3.new(math.random() * 2 - 1, enemy.stats.Size * 1.3, 0),
			(crit and "CRIT " or "") .. tostring(math.floor(amount)), color, big and 1.4 or 0.8)
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
	enemy.burnDps = math.max(enemy.burnDps, dps)
	enemy.burnUntil = math.max(enemy.burnUntil, Clock.now + seconds)
end

function EnemyService.GetActive()
	return active
end

-- enemies within `radius` of a point, the one furthest along the path first
function EnemyService.InRange(position, radius)
	local found = {}
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, e in active do
		if not e.dead and (e.position - flat).Magnitude <= radius then
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

function EnemyService.Count()
	return #active
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
				e.model:Destroy()
				table.remove(active, i)
				continue
			end

			local speed = e.stats.Speed
			if now < e.frozenUntil then
				speed = 0
			elseif now < e.slowUntil then
				speed *= e.slowFactor
			else
				e.slowFactor = 1
			end
			e.distance += speed * dt

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
				local hop = math.abs(math.sin(e.distance * 0.8)) * 0.3 * s / 3 -- little hop while walking
				local up = Vector3.new(0, s * 0.74 + hop, 0)
				-- the Loot Goblin zig-zags, the king stomps
				local side = Vector3.zero
				if e.stats.Loot then
					side = Vector3.new(-dir.Z, 0, dir.X) * math.sin(e.distance * 0.35) * 2.5
				end
				e.model:PivotTo(CFrame.lookAt(pos + up + side, pos + up + side + dir))

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
				end
			end
		end
	end)
end

return EnemyService
