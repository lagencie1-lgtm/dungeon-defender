-- The heroes players control: Swordmaster, Rune Mage and Machine Engineer.
-- Abilities on F, E and R. Hero levels and stat points are saved, one set per hero.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local State = require(script.Parent.State)
local Clock = require(script.Parent.Clock)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local HeroService = {}
local Hero = Config.Hero

local rainbowParts = {} -- weapon parts that cycle through colours

-------------------------------------------------------------------------------
-- saved hero data
-------------------------------------------------------------------------------
local function selectedId(player)
	local profile = DataService.Get(player)
	local id = profile and profile.SelectedHero or "Swordmaster"
	return Config.Heroes[id] and id or "Swordmaster"
end

local function heroData(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local id = selectedId(player)
	local data = profile.Heroes[id]
	if not data then
		data = { Level = 1, Xp = 0, Points = {} }
		profile.Heroes[id] = data
	end
	data.Points = data.Points or {}
	return data
end

local function pointsUsed(data)
	local n = 0
	for _, v in data.Points do
		n += v
	end
	return n
end

-- adds gear + stat points together into the numbers the game uses
function HeroService.RefreshStats(player)
	local data = heroData(player)
	local points = data and data.Points or {}
	local per = {}
	for _, s in Config.StatPoints do
		per[s.Id] = (points[s.Id] or 0) * s.Per
	end
	player:SetAttribute("BonusPower", (player:GetAttribute("GearPower") or 0) + per.Power)
	player:SetAttribute("BonusCommand", (player:GetAttribute("GearCommand") or 0) + per.Command)
	player:SetAttribute("BonusEngineering", (player:GetAttribute("GearEngineering") or 0) + per.Engineering)
	player:SetAttribute("BonusCrit", player:GetAttribute("GearCrit") or 0)
	player:SetAttribute("BonusGoldFind", player:GetAttribute("GearGoldFind") or 0)
	local level = data and data.Level or 1
	local maxHealth = Config.HeroBaseHealth + per.Vitality + (level - 1) * 2
	player:SetAttribute("HeroMaxHealth", maxHealth)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MaxHealth ~= maxHealth then
		local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth * ratio
	end
end

-- shows the selected hero's level, xp and points on the player
local function publish(player)
	local data = heroData(player)
	if not data then
		return
	end
	player:SetAttribute("HeroId", selectedId(player))
	player:SetAttribute("HeroLevel", data.Level)
	player:SetAttribute("HeroXp", data.Xp)
	player:SetAttribute("HeroXpNeeded", Config.XpForLevel(data.Level))
	player:SetAttribute("StatPointsFree", (data.Level - 1) - pointsUsed(data))
	for _, s in Config.StatPoints do
		player:SetAttribute("Stat" .. s.Id, data.Points[s.Id] or 0)
	end
	HeroService.RefreshStats(player)
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

function HeroService.AddXp(player, amount)
	local data = heroData(player)
	if not data or data.Level >= Config.HeroMaxLevel then
		return
	end
	data.Xp += amount
	local leveled = false
	while data.Xp >= Config.XpForLevel(data.Level) and data.Level < Config.HeroMaxLevel do
		data.Xp -= Config.XpForLevel(data.Level)
		data.Level += 1
		leveled = true
	end
	if data.Level >= Config.HeroMaxLevel then
		data.Xp = 0
	end
	if leveled then
		local root = rootOf(player)
		if root then
			Effects.Burst(root.Position, 8, Color3.fromRGB(255, 220, 90), 0.6)
			Effects.Text(root.Position + Vector3.new(0, 4, 0), "LEVEL UP!", Color3.fromRGB(255, 220, 90), 1.4)
			Sound.Play("Coin", root.Position)
		end
		Remotes.Notify:FireClient(player, "Level " .. data.Level .. "! You got a stat point (Hero button)", Color3.fromRGB(255, 220, 90))
	end
	publish(player)
end

-- a new game: only the cooldowns start over (levels are kept)
function HeroService.Reset(player)
	player:SetAttribute("AttackReadyAt", 0)
	player:SetAttribute("WhirlwindReadyAt", 0)
	player:SetAttribute("LeapReadyAt", 0)
end

-------------------------------------------------------------------------------
-- damage
-------------------------------------------------------------------------------
-- level, Power and a chance to crit (double damage)
local function damageFor(player, base)
	local level = player:GetAttribute("HeroLevel") or 1
	local power = (player:GetAttribute("BonusPower") or 0) / 100
	local damage = base * (1 + (level - 1) * Config.DamagePerHeroLevel) * (1 + power)
	if math.random() * 100 < (player:GetAttribute("BonusCrit") or 0) then
		return damage * 2, true
	end
	return damage, false
end

local function hit(player, enemy, base)
	local damage, crit = damageFor(player, base)
	EnemyService.Damage(enemy, damage, player, true, crit)
end

local function weaponOf(player)
	return Items.WeaponTypes[player:GetAttribute("WeaponType") or "Longsword"] or Items.WeaponTypes.Longsword
end

-------------------------------------------------------------------------------
-- what each hero holds
-------------------------------------------------------------------------------
local function weld(character, hand, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = part
	w.Parent = part
	part.Parent = character
end

local function newPart(props)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	for k, v in props do
		p[k] = v
	end
	return p
end

local function makeBlade(character, hand, skin, color, length, thick)
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	local blade
	if skin.Baguette then
		blade = newPart({ Name = "HeroWeapon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length + 0.5, 0.9 * thick, 0.9 * thick),
			Material = Enum.Material.Sand, Color = color,
			CFrame = grip * CFrame.new(0, 0, -length / 2 - 0.2) * CFrame.Angles(0, math.pi / 2, 0) })
	else
		blade = newPart({ Name = "HeroWeapon", Size = Vector3.new(0.3 * thick, 0.3 * thick, length), Material = Enum.Material.Neon,
			Color = color, CFrame = grip * CFrame.new(0, 0, -length / 2 - 0.2) })
		weld(character, hand, newPart({ Name = "HeroWeapon", Size = Vector3.new(1.2 * thick, 0.3, 0.3),
			Color = Color3.fromRGB(120, 80, 40), CFrame = grip }))
	end
	weld(character, hand, blade)
	if skin.Rainbow then
		rainbowParts[blade] = true
	end
end

-- builds the hero's weapon: shape from the hero (and weapon type), colour from
-- the shop skin. The Classic skin glows in the weapon's rarity colour.
local function giveWeapon(player, character)
	for _, old in character:GetChildren() do
		if old.Name == "HeroWeapon" or old.Name == "HeroHat" then
			rainbowParts[old] = nil
			old:Destroy()
		end
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local skin = Config.FindById(Config.Swords, player:GetAttribute("EquippedSword") or "Classic") or Config.Swords[1]
	local color = skin.Color
	local rarity = Items.Rarities[player:GetAttribute("WeaponRarity") or 0]
	if skin.Id == "Classic" and rarity then
		color = rarity.Color
	end
	local heroId = player:GetAttribute("HeroId") or "Swordmaster"
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)

	if heroId == "RuneMage" then
		local staff = newPart({ Name = "HeroWeapon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.35, 0.35),
			Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood,
			CFrame = grip * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.pi / 2) })
		weld(character, hand, staff)
		local orb = newPart({ Name = "HeroWeapon", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1,
			Color = color, Material = Enum.Material.Neon, CFrame = grip * CFrame.new(0, 4.9, 0) })
		weld(character, hand, orb)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Parent = orb
		if skin.Rainbow then
			rainbowParts[orb] = true
		end
		local head = character:FindFirstChild("Head")
		if head then
			local hat = newPart({ Name = "HeroHat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6),
				Color = Color3.fromRGB(80, 50, 140), CFrame = head.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2) })
			weld(character, head, hat)
			local tip = newPart({ Name = "HeroHat", Size = Vector3.new(1.2, 1.8, 1.2), Color = Color3.fromRGB(80, 50, 140),
				CFrame = head.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(45), 0) })
			weld(character, head, tip)
		end
	elseif heroId == "Engineer" then
		local handle = newPart({ Name = "HeroWeapon", Size = Vector3.new(0.35, 0.35, 3.2), Color = Color3.fromRGB(90, 90, 100),
			Material = Enum.Material.Metal, CFrame = grip * CFrame.new(0, 0, -1.6) })
		weld(character, hand, handle)
		local head = newPart({ Name = "HeroWeapon", Size = Vector3.new(1.3, 0.4, 0.8), Color = color, Material = Enum.Material.Metal,
			CFrame = grip * CFrame.new(0, 0, -3.3) })
		weld(character, hand, head)
		if skin.Rainbow then
			rainbowParts[head] = true
		end
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso then
			local pack = newPart({ Name = "HeroHat", Size = Vector3.new(1.6, 1.8, 0.8), Color = Color3.fromRGB(150, 110, 50),
				Material = Enum.Material.Metal, CFrame = torso.CFrame * CFrame.new(0, 0, 0.9) })
			weld(character, torso, pack)
		end
	else
		local weaponType = player:GetAttribute("WeaponType") or "Longsword"
		if weaponType == "Greatsword" then
			makeBlade(character, hand, skin, color, 6.5, 1.8)
		elseif weaponType == "TwinBlades" then
			makeBlade(character, hand, skin, color, 3.2, 0.9)
			local left = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
			if left then
				makeBlade(character, left, skin, color, 3.2, 0.9)
			end
		else
			makeBlade(character, hand, skin, color, 4.5, 1)
		end
	end
end

-- name tag over the head: title from the shop, name, hero and level
local function giveNameTag(player, character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("HeroTag")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "HeroTag"
		gui.Size = UDim2.fromOffset(240, 44)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		gui.MaxDistance = 120
		gui.Parent = head
		for i, name in { "Title", "Level" } do
			local l = Instance.new("TextLabel")
			l.Name = name
			l.Size = UDim2.new(1, 0, 0.48, 0)
			l.Position = UDim2.fromScale(0, (i - 1) * 0.5)
			l.BackgroundTransparency = 1
			l.Font = i == 1 and Enum.Font.GothamBold or Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = i == 1 and Color3.fromRGB(255, 200, 90) or Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0.3
			l.Parent = gui
		end
	end
	local titleItem = Config.FindById(Config.Titles, player:GetAttribute("EquippedTitle") or "None")
	gui:FindFirstChild("Title").Text = (titleItem and titleItem.Id ~= "None") and titleItem.Name or ""
	local hero = Config.Heroes[player:GetAttribute("HeroId") or "Swordmaster"]
	gui:FindFirstChild("Level").Text = player.DisplayName .. " · " .. hero.Name .. " " .. (player:GetAttribute("HeroLevel") or 1)
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Hero.WalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- we draw our own name tag
	end
	character:WaitForChild("RightHand", 5)
	character:WaitForChild("Head", 5)
	if humanoid then
		local maxHealth = player:GetAttribute("HeroMaxHealth") or Config.HeroBaseHealth
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
		humanoid.Died:Connect(function()
			Remotes.Notify:FireAllClients(player.DisplayName .. " got bonked by goblins! Back in a few seconds",
				Color3.fromRGB(255, 140, 140))
		end)
	end
	giveWeapon(player, character)
	giveNameTag(player, character)
end

-------------------------------------------------------------------------------
-- abilities: F (slot 1), E (slot 2), R (slot 3)
-------------------------------------------------------------------------------
local function ready(player, attr, cooldown)
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute(attr) or 0) then
		return false
	end
	player:SetAttribute(attr, now + cooldown)
	return true
end

-- melee hit in front of the hero (sword or wrench)
local function melee(player, root, damage, range, targets, color)
	local front = root.Position + root.CFrame.LookVector * (range * 0.5)
	Effects.Burst(front, range * 0.35, color, 0.2, 0.5)
	Sound.Play("Swing", root.Position)
	local hits = 0
	for _, e in EnemyService.InRange(front, range * 0.6) do
		hit(player, e, damage)
		hits += 1
		if hits >= targets then
			break
		end
	end
end

-- the goblin furthest along the path within range (the most dangerous one)
local function targetNear(position, range)
	return EnemyService.InRange(position, range)[1]
end

local ABILITIES = {
	Swordmaster = {
		F = function(player, root)
			local weapon = weaponOf(player)
			player:SetAttribute("AttackCooldown", weapon.Cooldown)
			if not ready(player, "AttackReadyAt", weapon.Cooldown) then
				return
			end
			melee(player, root, Hero.Attack.Damage * weapon.Damage, weapon.Range, weapon.Targets, Color3.fromRGB(200, 220, 255))
		end,
		E = function(player, root)
			if not ready(player, "WhirlwindReadyAt", Hero.Whirlwind.Cooldown) then
				return
			end
			Effects.Ring(root.Position - Vector3.new(0, 2.5, 0), Hero.Whirlwind.Radius, Color3.fromRGB(200, 220, 255), 0.45)
			Effects.Burst(root.Position, Hero.Whirlwind.Radius * 0.6, Color3.fromRGB(220, 230, 255), 0.35, 0.6)
			Sound.Play("Swing", root.Position)
			for _, e in EnemyService.InRange(root.Position, Hero.Whirlwind.Radius) do
				hit(player, e, Hero.Whirlwind.Damage)
			end
		end,
		-- the player's own computer makes the jump, the server waits for the landing
		R = function(player, root)
			if not ready(player, "LeapReadyAt", Hero.Leap.Cooldown) then
				return
			end
			Sound.Play("Swing", root.Position)
			task.delay(0.6, function()
				local r = rootOf(player)
				if not r then
					return
				end
				local ground = r.Position - Vector3.new(0, 2.8, 0)
				Effects.Ring(ground, Hero.Leap.Radius, Color3.fromRGB(255, 200, 120), 0.4)
				Effects.Burst(ground, Hero.Leap.Radius * 0.7, Color3.fromRGB(255, 220, 160), 0.3, 0.5)
				Sound.Play("Land", ground)
				Sound.Play("Explosion", ground)
				for _, e in EnemyService.InRange(ground, Hero.Leap.Radius) do
					hit(player, e, Hero.Leap.Damage)
					if not e.stats.Boss then
						EnemyService.Freeze(e, 0.6) -- stunned
					end
				end
			end)
		end,
	},
	RuneMage = {
		F = function(player, root)
			local info = Config.Heroes.RuneMage.Bolt
			player:SetAttribute("AttackCooldown", info.Cooldown)
			local target = targetNear(root.Position, info.Range)
			if not target or not ready(player, "AttackReadyAt", info.Cooldown) then
				return
			end
			local to = target.position + Vector3.new(0, target.stats.Size * 0.6, 0)
			Effects.Bolt(root.Position + Vector3.new(0, 2, 0), to, Color3.fromRGB(190, 140, 255), 0.6, 0.15)
			Sound.Play("Zap", root.Position)
			task.delay(0.15, function()
				hit(player, target, info.Damage)
				Effects.Burst(to, 2, Color3.fromRGB(190, 140, 255), 0.2)
			end)
		end,
		E = function(player, root)
			local info = Config.Heroes.RuneMage.Nova
			if not ready(player, "WhirlwindReadyAt", info.Cooldown) then
				return
			end
			Effects.Ring(root.Position - Vector3.new(0, 2.5, 0), info.Radius, Color3.fromRGB(150, 220, 255), 0.5)
			Effects.Burst(root.Position, info.Radius * 0.5, Color3.fromRGB(200, 240, 255), 0.4, 0.5)
			Sound.Play("Frost", root.Position)
			for _, e in EnemyService.InRange(root.Position, info.Radius) do
				hit(player, e, info.Damage)
				EnemyService.Slow(e, info.Slow, info.SlowTime)
			end
		end,
		R = function(player, root)
			local info = Config.Heroes.RuneMage.Meteor
			-- aim at the goblin with the most friends around it
			local best, bestCount = nil, 0
			for _, e in EnemyService.InRange(root.Position, info.Range) do
				local count = #EnemyService.InRange(e.position, info.Radius)
				if count > bestCount then
					best, bestCount = e, count
				end
			end
			if not best or not ready(player, "LeapReadyAt", info.Cooldown) then
				return
			end
			local spot = best.position
			local rock = Instance.new("Part")
			rock.Shape = Enum.PartType.Ball
			rock.Size = Vector3.one * 5
			rock.Material = Enum.Material.Neon
			rock.Color = Color3.fromRGB(255, 110, 40)
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanQuery = false
			rock.Position = spot + Vector3.new(15, 60, 0)
			rock.Parent = workspace:FindFirstChild("Effects") or workspace
			Instance.new("Fire", rock).Size = 10
			TweenService:Create(rock, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = spot + Vector3.new(0, 2, 0) }):Play()
			task.delay(0.8, function()
				rock:Destroy()
				Effects.Burst(spot + Vector3.new(0, 2, 0), info.Radius, Color3.fromRGB(255, 120, 40), 0.5)
				Effects.Ring(spot + Vector3.new(0, 0.5, 0), info.Radius, Color3.fromRGB(255, 180, 80), 0.5)
				Sound.Play("Explosion", spot)
				for _, e in EnemyService.InRange(spot, info.Radius) do
					hit(player, e, info.Damage)
					EnemyService.Burn(e, 6, 3)
				end
			end)
		end,
	},
	Engineer = {
		F = function(player, root)
			local info = Config.Heroes.Engineer.Wrench
			player:SetAttribute("AttackCooldown", info.Cooldown)
			if not ready(player, "AttackReadyAt", info.Cooldown) then
				return
			end
			melee(player, root, info.Damage, info.Range, info.Targets, Color3.fromRGB(255, 190, 90))
		end,
		E = function(player, root)
			local info = Config.Heroes.Engineer.Overclock
			if not ready(player, "WhirlwindReadyAt", info.Cooldown) then
				return
			end
			Effects.Ring(root.Position - Vector3.new(0, 2.5, 0), info.Radius, Color3.fromRGB(255, 170, 60), 0.6)
			Sound.Play("Zap", root.Position)
			local count = TowerService.Overclock(root.Position, info.Radius, info.Speed, info.Time)
			Effects.Text(root.Position + Vector3.new(0, 5, 0), "OVERCLOCK x" .. count, Color3.fromRGB(255, 190, 90), 1.2)
		end,
		R = function(player, root)
			local info = Config.Heroes.Engineer.Turret
			if not ready(player, "LeapReadyAt", info.AbilityCooldown) then
				return
			end
			local spot = root.Position + root.CFrame.LookVector * 4
			TowerService.SpawnTurret(player, Vector3.new(spot.X, 0, spot.Z), info)
			Sound.Play("Build", spot)
		end,
	},
}

-- cooldowns of each hero's E and R, for the screen
local function abilityCooldowns(heroId)
	if heroId == "RuneMage" then
		local h = Config.Heroes.RuneMage
		return h.Nova.Cooldown, h.Meteor.Cooldown
	elseif heroId == "Engineer" then
		local h = Config.Heroes.Engineer
		return h.Overclock.Cooldown, h.Turret.AbilityCooldown
	end
	return Hero.Whirlwind.Cooldown, Hero.Leap.Cooldown
end

local function useAbility(player, slot)
	local root = rootOf(player)
	if not root then
		return
	end
	local heroId = selectedId(player)
	local ability = ABILITIES[heroId] and ABILITIES[heroId][slot]
	if ability then
		ability(player, root)
	end
end

-------------------------------------------------------------------------------
-- hero select and stat points
-------------------------------------------------------------------------------
local function selectHero(player, heroId)
	local profile = DataService.Get(player)
	if not profile or not Config.Heroes[heroId] then
		return false, "Unknown hero"
	end
	if State.Get("State") == "Wave" then
		return false, "Wait for the break between waves"
	end
	profile.SelectedHero = heroId
	publish(player)
	local e, r = abilityCooldowns(heroId)
	player:SetAttribute("CooldownE", e)
	player:SetAttribute("CooldownR", r)
	HeroService.Reset(player)
	if player.Character then
		giveWeapon(player, player.Character)
		giveNameTag(player, player.Character)
	end
	return true
end

local function spendPoint(player, statId)
	local data = heroData(player)
	if not data then
		return false, "Still loading"
	end
	local valid = false
	for _, s in Config.StatPoints do
		valid = valid or s.Id == statId
	end
	if not valid then
		return false, "Unknown stat"
	end
	if (data.Level - 1) - pointsUsed(data) <= 0 then
		return false, "No free points. Level up to get more"
	end
	data.Points[statId] = (data.Points[statId] or 0) + 1
	publish(player)
	return true
end

local function resetPoints(player)
	local data = heroData(player)
	local profile = DataService.Get(player)
	if not data or not profile then
		return false, "Still loading"
	end
	if pointsUsed(data) == 0 then
		return false, "Nothing to reset"
	end
	local cost = data.Level * Config.StatResetGoldPerLevel
	if profile.Gold < cost then
		return false, "Reset costs " .. cost .. " gold"
	end
	profile.Gold -= cost
	data.Points = {}
	DataService.Publish(player)
	publish(player)
	return true, cost
end

-------------------------------------------------------------------------------
-- start
-------------------------------------------------------------------------------
function HeroService.Start()
	Remotes.HeroAttack.OnServerEvent:Connect(function(player)
		useAbility(player, "F")
	end)
	Remotes.HeroWhirlwind.OnServerEvent:Connect(function(player)
		useAbility(player, "E")
	end)
	Remotes.HeroLeap.OnServerEvent:Connect(function(player)
		useAbility(player, "R")
	end)
	Remotes.SelectHero.OnServerInvoke = selectHero
	Remotes.SpendPoint.OnServerInvoke = spendPoint
	Remotes.ResetPoints.OnServerInvoke = resetPoints

	ItemService.OnGearChanged = HeroService.RefreshStats
	table.insert(DataService.OnLoaded, function(player)
		publish(player)
		local e, r = abilityCooldowns(selectedId(player))
		player:SetAttribute("CooldownE", e)
		player:SetAttribute("CooldownR", r)
		if player.Character then
			giveWeapon(player, player.Character)
			giveNameTag(player, player.Character)
		end
	end)

	local function onPlayer(player)
		HeroService.Reset(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		-- a new look picked in the shop or new gear: swap the weapon right away
		for _, attr in { "EquippedSword", "WeaponType", "WeaponRarity" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				if player.Character then
					giveWeapon(player, player.Character)
				end
			end)
		end
		for _, attr in { "EquippedTitle", "HeroLevel" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				if player.Character then
					giveNameTag(player, player.Character)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	RunService.Heartbeat:Connect(function(dt)
		-- rainbow weapons
		local hue = (os.clock() * 0.4) % 1
		for part in rainbowParts do
			if part.Parent then
				part.Color = Color3.fromHSV(hue, 1, 1)
			else
				rainbowParts[part] = nil
			end
		end
		-- goblins hurt heroes that stand in their way
		local gameDt = dt * Clock.scale
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
				local hurt = 0
				for _, e in EnemyService.GetActive() do
					if not e.dead and (e.position - flat).Magnitude < 2.5 + e.stats.Size * 0.6 then
						hurt += (Config.ContactDamage[e.name] or 5) * gameDt
					end
				end
				if hurt > 0 then
					humanoid:TakeDamage(hurt)
				end
			end
		end
	end)
end

return HeroService
