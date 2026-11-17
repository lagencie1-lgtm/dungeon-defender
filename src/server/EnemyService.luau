-- Spawns enemies and moves them along the path.
-- Enemies are plain models we move ourselves (no Humanoid), which keeps
-- the game fast even with lots of goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local EnemyService = {}

local active = {} -- each entry: { model, stats, health, distance }
local folder

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
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function makeGoblin(stats)
	local s = stats.Size
	local model = Instance.new("Model")
	model.Name = "Goblin"

	local body = newPart(model, { Name = "Body", Size = Vector3.new(s, s, s * 0.8), Color = stats.Color })
	model.PrimaryPart = body
	local head = newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s * 0.7,
		Color = stats.Color,
		CFrame = body.CFrame * CFrame.new(0, s * 0.8, 0),
	})
	-- two pointy ears
	for side = -1, 1, 2 do
		newPart(model, {
			ClassName = "WedgePart",
			Name = "Ear",
			Size = Vector3.new(0.3, s * 0.3, s * 0.4),
			Color = stats.Color,
			CFrame = head.CFrame * CFrame.new(side * s * 0.4, s * 0.1, 0) * CFrame.Angles(0, 0, side * math.rad(-30)),
		})
	end
	-- red eyes
	for side = -1, 1, 2 do
		newPart(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.15,
			Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
			CFrame = head.CFrame * CFrame.new(side * s * 0.15, s * 0.05, -s * 0.32),
		})
	end
	return model
end

function EnemyService.Spawn(enemyName)
	local stats = Config.Enemies[enemyName]
	local model = makeGoblin(stats)
	model:SetAttribute("Health", stats.Health)
	model.Parent = folder
	table.insert(active, { model = model, stats = stats, health = stats.Health, distance = 0 })
	return model
end

-- later the defenders call this to hurt an enemy
function EnemyService.Damage(model, amount)
	for _, e in active do
		if e.model == model then
			e.health -= amount
			model:SetAttribute("Health", e.health)
			return
		end
	end
end

function EnemyService.GetActive()
	return active
end

function EnemyService.Start(portal)
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace

	RunService.Heartbeat:Connect(function(dt)
		for i = #active, 1, -1 do
			local e = active[i]
			if e.health <= 0 then
				e.model:Destroy()
				table.remove(active, i)
			else
				e.distance += e.stats.Speed * dt
				if e.distance >= pathLength then
					-- it reached the portal
					portal:SetAttribute("Health", portal:GetAttribute("Health") - e.stats.Damage)
					e.model:Destroy()
					table.remove(active, i)
				else
					local pos, dir = positionAt(e.distance)
					local hop = math.abs(math.sin(e.distance * 0.8)) * 0.4 -- little hop while walking
					local up = Vector3.new(0, e.stats.Size / 2 + 0.2 + hop, 0)
					e.model:PivotTo(CFrame.lookAt(pos + up, pos + up + dir))
				end
			end
		end
	end)
end

return EnemyService
