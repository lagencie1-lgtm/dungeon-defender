-- Spawns enemies and moves them along the path.
-- Enemies are plain models we move ourselves (no Humanoid), which keeps
-- the game fast even with lots of goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)

local EnemyService = {}

-- every enemy on the map:
-- { model, stats, health, maxHealth, distance, position, slowUntil, slowFactor,
--   frozenUntil, burnUntil, burnDps, dead }
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

-- builds a goblin out of blocks. Bigger goblins get a club, the king gets a crown.
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
	if s >= 4 then
		newPart(model, { -- club
			Name = "Club",
			Size = Vector3.new(s * 0.25, s * 0.25, s * 1.1),
			Color = Color3.fromRGB(100, 70, 40),
			Material = Enum.Material.Wood,
			CFrame = body.CFrame * CFrame.new(s * 0.7, s * 0.1, -s * 0.3) * CFrame.Angles(math.rad(30), 0, 0),
		})
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
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(200, 120, 255)
		light.Range = 20
		light.Parent = body
	end

	-- health bar over the head
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = stats.Boss and UDim2.fromOffset(160, 14) or UDim2.fromOffset(50, 6)
	gui.StudsOffset = Vector3.new(0, s * 0.9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Adornee = head
	gui.Parent = model
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = stats.Boss and Color3.fromRGB(200, 60, 255) or Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back

	return model, fill
end

function EnemyService.Spawn(name, healthMultiplier)
	local stats = Config.Enemies[name]
	local model, fill = makeGoblin(name, stats)
	local hp = math.floor(stats.Health * (healthMultiplier or 1))
	model:SetAttribute("Health", hp)
	model:PivotTo(CFrame.new(Config.Path[1] + Vector3.new(0, stats.Size, 0)))
	model.Parent = workspace:FindFirstChild("Enemies") or workspace
	local enemy = {
		name = name,
		model = model,
		fill = fill,
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
		dead = false,
	}
	table.insert(active, enemy)
	return enemy
end

local function kill(enemy, player)
	if enemy.dead then
		return
	end
	enemy.dead = true
	Effects.Burst(enemy.position + Vector3.new(0, enemy.stats.Size / 2, 0), enemy.stats.Size, enemy.stats.Color, 0.3)
	EnemyService.OnKilled(enemy, player)
end

-- player is optional: who hit it (the hero), for xp
function EnemyService.Damage(enemy, amount, player)
	if enemy.dead then
		return
	end
	enemy.health -= amount
	enemy.model:SetAttribute("Health", enemy.health)
	enemy.fill.Size = UDim2.fromScale(math.max(enemy.health / enemy.maxHealth, 0), 1)
	if enemy.health <= 0 then
		kill(enemy, player)
	end
end

function EnemyService.Slow(enemy, factor, seconds)
	local now = os.clock()
	if factor <= enemy.slowFactor or now > enemy.slowUntil then
		enemy.slowFactor = factor
	end
	enemy.slowUntil = math.max(enemy.slowUntil, now + seconds)
end

function EnemyService.Freeze(enemy, seconds)
	enemy.frozenUntil = math.max(enemy.frozenUntil, os.clock() + seconds)
end

function EnemyService.Burn(enemy, dps, seconds)
	enemy.burnDps = math.max(enemy.burnDps, dps)
	enemy.burnUntil = math.max(enemy.burnUntil, os.clock() + seconds)
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

function EnemyService.Start()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
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
				EnemyService.OnLeaked(e)
				e.model:Destroy()
				table.remove(active, i)
			else
				local pos, dir = positionAt(e.distance)
				e.position = pos
				local hop = math.abs(math.sin(e.distance * 0.8)) * 0.3 * e.stats.Size / 3 -- little hop while walking
				local up = Vector3.new(0, e.stats.Size * 0.5 + e.stats.Size * 0.6 * 0.4 + hop, 0)
				e.model:PivotTo(CFrame.lookAt(pos + up, pos + up + dir))
				-- frozen goblins turn blue, burning ones glow orange
				local tint = e.stats.Color
				if now < e.frozenUntil then
					tint = Color3.fromRGB(150, 220, 255)
				elseif now < e.burnUntil then
					tint = e.stats.Color:Lerp(Color3.fromRGB(255, 120, 30), 0.5)
				elseif now < e.slowUntil then
					tint = e.stats.Color:Lerp(Color3.fromRGB(120, 200, 255), 0.4)
				end
				if e.tint ~= tint then
					e.tint = tint
					e.model.Body.Color = tint
					e.model.Head.Color = tint
				end
			end
		end
	end)
end

return EnemyService
