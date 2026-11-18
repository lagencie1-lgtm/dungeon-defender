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
local StoreService = require(script.Parent.StoreService)
local SeasonService = require(script.Parent.SeasonService)

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

local function setLevelLabel(model, level)
	local gui = model:FindFirstChild("LevelLabel")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "LevelLabel"
		gui.Size = UDim2.fromOffset(60, 20)
		gui.StudsOffset = Vector3.new(0, 14, 0)
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
	local muzzle, kicker, turners = BUILDERS[towerType](model, at, info.Color)
	model.PrimaryPart = model:FindFirstChild("Base")
	if typeof(player) == "Instance" then
		StoreService.ApplyTowerSkin(model, StoreService.SkinFor(player, towerType))
	end
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
	-- grow a little with each level
	local base = model.PrimaryPart
	base.Size += Vector3.new(0.6, 0.2, 0.6)
	if t.level == #info.Levels then
		-- max level: a golden glow
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 210, 80)
		glow.Range = 10
		glow.Parent = base
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 90)
		sparkles.Parent = base
	end
	Effects.Burst(t.position + Vector3.new(0, 4, 0), 6, Color3.fromRGB(255, 220, 90), 0.4)
	Effects.Text(t.position + Vector3.new(0, 10, 0), "LEVEL UP", Color3.fromRGB(255, 220, 90))
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
	local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
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
	if command == 0 and engineering == 0 and overclock == 1 then
		return base
	end
	local stats = table.clone(base)
	stats.Damage = base.Damage * (1 + command)
	stats.Cooldown = base.Cooldown / (1 + engineering) / overclock
	stats.Range = base.Range * (1 + engineering / 2)
	return stats
end

-- Engineer's Overclock: defenders near a spot shoot faster for a while
function TowerService.Overclock(position, radius, speed, seconds)
	local count = 0
	for model, t in towers do
		if (t.position - Vector3.new(position.X, 0, position.Z)).Magnitude <= radius then
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

local function shoot(t, now)
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
		Effects.Bolt(t.muzzle, hitAt, Color3.fromRGB(230, 255, 200), 0.3, 0.12)
		EnemyService.Damage(first, stats.Damage)
	elseif t.type == "FlameCannon" then
		Effects.Kick(t.kicker, 0.5)
		Effects.Bolt(t.muzzle, hitAt, Color3.fromRGB(255, 140, 40), 1, 0.2)
		task.delay(0.2, function()
			Effects.Burst(hitAt, stats.Radius, Color3.fromRGB(255, 110, 30), 0.4)
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
				shoot(t, now)
			else
				towers[model] = nil
			end
		end
	end)
end

return TowerService
