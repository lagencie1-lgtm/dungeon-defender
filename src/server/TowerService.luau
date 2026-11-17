-- Defenders: placing, upgrading, selling, and shooting at goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)

local TowerService = {}

local towers = {} -- [model] = { type, level, spent, nextShot, position }

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

-- what each defender looks like
local BUILDERS = {
	Ranger = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5, 1, 5), CFrame = at * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Cobblestone })
		newPart(model, { Name = "Post", Size = Vector3.new(3, 7, 3), CFrame = at * CFrame.new(0, 4.5, 0),
			Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.WoodPlanks })
		newPart(model, { Name = "Platform", Size = Vector3.new(4.5, 0.6, 4.5), CFrame = at * CFrame.new(0, 8.3, 0),
			Color = Color3.fromRGB(90, 60, 35), Material = Enum.Material.Wood })
		newPart(model, { Name = "Archer", Size = Vector3.new(1.4, 2.4, 1.4), CFrame = at * CFrame.new(0, 9.8, 0),
			Color = color })
		newPart(model, { Name = "Hood", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4,
			CFrame = at * CFrame.new(0, 11.4, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.3) })
		return Vector3.new(0, 10.5, 0) -- where shots come from
	end,
	FlameCannon = function(model, at, color)
		newPart(model, { Name = "Base", Size = Vector3.new(5.5, 1.5, 5.5), CFrame = at * CFrame.new(0, 0.75, 0),
			Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
		newPart(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 4,
			CFrame = at * CFrame.new(0, 3, 0), Color = Color3.fromRGB(50, 45, 45), Material = Enum.Material.Metal })
		newPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.8, 1.8),
			CFrame = at * CFrame.new(0, 4.2, -1.5) * CFrame.Angles(0, math.pi / 2, math.rad(25)),
			Color = Color3.fromRGB(70, 60, 55), Material = Enum.Material.Metal })
		local glow = newPart(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3,
			CFrame = at * CFrame.new(0, 5.3, -3.2), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		Instance.new("Fire", glow).Size = 2
		return Vector3.new(0, 5.3, -3.2)
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
		return Vector3.new(0, 5, 0)
	end,
}

local function setLevelLabel(model, level)
	local gui = model:FindFirstChild("LevelLabel")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "LevelLabel"
		gui.Size = UDim2.fromOffset(60, 20)
		gui.StudsOffset = Vector3.new(0, 13, 0)
		gui.MaxDistance = 90
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
	gui:FindFirstChild("Text").Text = "Lv " .. level
end

-- can a defender stand here? returns ok, reason
function TowerService.CanPlace(position)
	local half = Config.MapSize / 2
	if math.abs(position.X) > half.X - 4 or math.abs(position.Z) > half.Y - 4 then
		return false, "Too close to the edge"
	end
	if Config.DistanceToPath(position) < Config.PathWidth / 2 + 3 then
		return false, "Can't build on the path"
	end
	if (Vector3.new(position.X, 0, position.Z) - Config.Path[#Config.Path]).Magnitude < 14 then
		return false, "Too close to the portal"
	end
	for _, t in towers do
		if (t.position - position).Magnitude < Config.TowerSpacing then
			return false, "Too close to another defender"
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
	position = Vector3.new(position.X, 0, position.Z)
	local ok, reason = TowerService.CanPlace(position)
	if not ok then
		return false, reason
	end
	if not State.TrySpend(info.Cost) then
		return false, "Not enough gold"
	end

	local model = Instance.new("Model")
	model.Name = info.DisplayName
	local at = CFrame.new(position)
	local muzzle = BUILDERS[towerType](model, at, info.Color)
	model.PrimaryPart = model:FindFirstChild("Base")
	model:SetAttribute("TowerType", towerType)
	model:SetAttribute("Level", 1)
	model:SetAttribute("Range", info.Levels[1].Range)
	model:SetAttribute("Spent", info.Cost)
	model:SetAttribute("Owner", player.UserId)
	setLevelLabel(model, 1)
	model.Parent = workspace.Towers

	towers[model] = {
		type = towerType,
		level = 1,
		spent = info.Cost,
		nextShot = 0,
		position = position,
		muzzle = position + muzzle,
	}
	Effects.Ring(position + Vector3.new(0, 0.3, 0), 5, Color3.fromRGB(255, 230, 150), 0.4)
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
		return false, "Not enough gold"
	end
	t.level += 1
	t.spent += nextLevel.Cost
	model:SetAttribute("Level", t.level)
	model:SetAttribute("Range", nextLevel.Range)
	model:SetAttribute("Spent", t.spent)
	setLevelLabel(model, t.level)
	-- grow a little with each level
	local base = model.PrimaryPart
	base.Size += Vector3.new(0.5, 0, 0.5)
	Effects.Burst(t.position + Vector3.new(0, 4, 0), 5, Color3.fromRGB(255, 220, 90), 0.4)
	return true
end

function TowerService.Sell(_player, model)
	local t = towers[model]
	if not t then
		return false, "That's not a defender"
	end
	local refund = math.floor(t.spent * Config.SellRefund)
	State.AddGold(refund)
	Effects.Text(t.position + Vector3.new(0, 6, 0), "+" .. refund .. " gold", Color3.fromRGB(255, 215, 0))
	towers[model] = nil
	model:Destroy()
	return true, refund
end

function TowerService.Clear()
	for model in towers do
		model:Destroy()
	end
	table.clear(towers)
end

local function shoot(t, now)
	local stats = Config.Towers[t.type].Levels[t.level]
	if now < t.nextShot then
		return
	end
	local targets = EnemyService.InRange(t.position, stats.Range)
	if #targets == 0 then
		return
	end
	t.nextShot = now + stats.Cooldown

	if t.type == "Ranger" then
		local target = targets[1]
		local hitAt = target.position + Vector3.new(0, target.stats.Size * 0.6, 0)
		Effects.Bolt(t.muzzle, hitAt, Color3.fromRGB(230, 255, 200), 0.3, 0.12)
		EnemyService.Damage(target, stats.Damage)
	elseif t.type == "FlameCannon" then
		local target = targets[1]
		local hitAt = target.position + Vector3.new(0, 1, 0)
		Effects.Bolt(t.muzzle, hitAt, Color3.fromRGB(255, 140, 40), 1, 0.2)
		task.delay(0.2, function()
			Effects.Burst(hitAt, stats.Radius, Color3.fromRGB(255, 110, 30), 0.4)
			for _, e in EnemyService.InRange(hitAt, stats.Radius) do
				EnemyService.Damage(e, stats.Damage)
				EnemyService.Burn(e, stats.BurnDps, stats.BurnTime)
			end
		end)
	elseif t.type == "FrostCrystal" then
		Effects.Ring(t.position + Vector3.new(0, 0.4, 0), stats.Range, Color3.fromRGB(150, 220, 255), 0.5)
		for _, e in targets do
			EnemyService.Damage(e, stats.Damage)
			EnemyService.Slow(e, stats.Slow, stats.SlowTime)
			if stats.FreezeChance and math.random() < stats.FreezeChance and not e.stats.Boss then
				EnemyService.Freeze(e, 1)
			end
		end
	end
end

function TowerService.Start()
	Remotes.PlaceTower.OnServerInvoke = TowerService.Place
	Remotes.UpgradeTower.OnServerInvoke = TowerService.Upgrade
	Remotes.SellTower.OnServerInvoke = TowerService.Sell

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, t in towers do
			if model.Parent then
				shoot(t, now)
			else
				towers[model] = nil
			end
		end
	end)
end

return TowerService
