-- The heroes players control: Swordmaster, Rune Mage and Machine Engineer.
-- Abilities on F, E and R. Hero levels and stat points are saved, one set per hero.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local GearLooks = require(ReplicatedStorage.Shared.GearLooks)
local Ground = require(ReplicatedStorage.Shared.Ground)
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
local QuestService = require(script.Parent.QuestService)
local PetService = require(script.Parent.PetService)
local ArtService = require(script.Parent.ArtService)

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

local function ascensionOf(profile)
	profile.Ascension = profile.Ascension or { Xp = 0, Points = 0, Spent = {} }
	profile.Ascension.Spent = profile.Ascension.Spent or {}
	return profile.Ascension
end

local function ascensionSpent(asc)
	local n = 0
	for _, v in asc.Spent do
		n += v
	end
	return n
end

-- adds gear + stat points + pet + Ascension together into the numbers the game uses
function HeroService.RefreshStats(player)
	local data = heroData(player)
	local points = data and data.Points or {}
	local per = {}
	for _, s in Config.StatPoints do
		per[s.Id] = (points[s.Id] or 0) * s.Per
	end
	local extra = { Power = 0, Command = 0, Engineering = 0, Crit = 0, GoldFind = 0 }
	local pet = PetService.EquippedPet(player)
	if pet then
		local stat, value = PetService.BonusOf(pet)
		if stat and extra[stat] then
			extra[stat] += value
		end
	end
	local profile = DataService.Get(player)
	if profile then
		local asc = ascensionOf(profile)
		for _, perk in Config.AscensionPerks do
			extra[perk.Id] += (asc.Spent[perk.Id] or 0) * perk.Per
		end
		player:SetAttribute("Rebirths", profile.Rebirths or 0)
		player:SetAttribute("AscensionPoints", asc.Points - ascensionSpent(asc))
		player:SetAttribute("AscensionXp", asc.Xp)
		for _, perk in Config.AscensionPerks do
			player:SetAttribute("Asc" .. perk.Id, asc.Spent[perk.Id] or 0)
		end
	end
	player:SetAttribute("BonusPower", (player:GetAttribute("GearPower") or 0) + per.Power + extra.Power)
	player:SetAttribute("BonusCommand", (player:GetAttribute("GearCommand") or 0) + per.Command + extra.Command)
	player:SetAttribute("BonusEngineering", (player:GetAttribute("GearEngineering") or 0) + per.Engineering + extra.Engineering)
	player:SetAttribute("BonusCrit", (player:GetAttribute("GearCrit") or 0) + extra.Crit)
	player:SetAttribute("BonusGoldFind", (player:GetAttribute("GearGoldFind") or 0) + extra.GoldFind)
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
	local profile = DataService.Get(player)
	if not data or not profile then
		return
	end
	amount *= 1 + (profile.Rebirths or 0) * Config.RebirthBonus / 100
	if (player:GetAttribute("BoostXpUntil") or 0) > os.time() then
		amount *= 2 -- 2x XP boost
	end
	if data.Level >= Config.HeroMaxLevel then
		-- at the cap: xp fills the Ascension bar instead
		local asc = ascensionOf(profile)
		asc.Xp += amount
		while asc.Xp >= Config.AscensionXp do
			asc.Xp -= Config.AscensionXp
			asc.Points += 1
			Remotes.Notify:FireClient(player, "Ascension Point earned! Spend it in the Heroes screen", Color3.fromRGB(255, 220, 90))
		end
		HeroService.RefreshStats(player)
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

local function hit(player, enemy, base, knock)
	local damage, crit = damageFor(player, base)
	EnemyService.Damage(enemy, damage, player, true, crit)
	EnemyService.HitStop(enemy, crit and 0.11 or 0.06)
	EnemyService.Knockback(enemy, knock or 1.5)
end

-- the boss slam: hurts heroes standing in the circle
function HeroService.DamageArea(position, radius, damage)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude <= radius then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			humanoid:TakeDamage(damage)
			root.AssemblyLinearVelocity += (root.Position - position).Unit * 40 + Vector3.new(0, 30, 0)
		end
	end
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
	p.CanTouch = false
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
		blade = newPart({ Name = "HeroWeapon", Size = Vector3.new(0.3 * thick, 0.3 * thick, length),
			Material = skin.PaintTint and Enum.Material.SmoothPlastic or Enum.Material.Neon,
			Color = color, CFrame = grip * CFrame.new(0, 0, -length / 2 - 0.2) })
		weld(character, hand, newPart({ Name = "HeroWeapon", Size = Vector3.new(1.2 * thick, 0.3, 0.3),
			Color = Color3.fromRGB(120, 80, 40), CFrame = grip }))
	end
	weld(character, hand, blade)
	if skin.Rainbow then
		rainbowParts[blade] = true
	end
end

-- Welds a painted Blender gear model (art/blender/gear.py) to a body part. `center` is where the middle of the
-- model goes and `fit` is its size along `axis`. The separate accent mesh takes the rarity or the skin's colour.
local function attachGear(character, limb, modelName, center, fit, axis, color, skin)
	local template = ArtService.Model(modelName)
	if not template or not limb then
		return false
	end
	local look = template:Clone()
	local _, size = look:GetBoundingBox()
	look:ScaleTo(look:GetScale() * fit / size[axis or "Y"])
	local box, fitted = look:GetBoundingBox()
	look:PivotTo(center * box:ToObjectSpace(look:GetPivot()))
	for _, part in look:GetChildren() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part.Name == "c_255_255_255" then
				part.Color = skin and skin.Color or color
				part.Material = skin and skin.PaintTint and Enum.Material.SmoothPlastic or Enum.Material.Neon
				if skin and skin.Rainbow then
					rainbowParts[part] = true
				end
			elseif part.Name == "Body" and skin and skin.PaintTint then
				part.Color = Color3.new(1, 1, 1):Lerp(skin.PaintTint, 0.65)
			end
			part.Name = "HeroWeapon"
			weld(character, limb, part)
		end
	end
	look:Destroy()
	return true, fitted
end

-- hides (or shows again) the avatar's own hair and hat accessories
local HEAD_ACCESSORY = { [Enum.AccessoryType.Hair] = true, [Enum.AccessoryType.Hat] = true }
local function hideHair(character, hidden)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			local onHead = HEAD_ACCESSORY[accessory.AccessoryType]
				or (handle and (handle:FindFirstChild("HairAttachment") or handle:FindFirstChild("HatAttachment")) ~= nil)
			if handle and onHead then
				handle.Transparency = hidden and 1 or 0
			end
		end
	end
end

local function wornGear(player, slot, skin)
	local base, rarity = string.match(player:GetAttribute("Worn" .. slot) or "", "^(.-):(%d+)$")
	return skin and skin[slot] or base, Items.Rarities[tonumber(rarity)] or Items.Rarities[1]
end

-- a full helm, a hood or the mage's hat cover the head; a crown sits on the hair
local function hairHidden(player)
	local skin = GearLooks.Worn(player, "HelmSkins", "HelmSkin")
	local base = skin and skin.Helm or wornGear(player, "Helmet")
	if base == "Helm" or base == "Hood" then
		return true
	elseif base == "Crown" then
		return false
	end
	return player:GetAttribute("HeroId") == "RuneMage"
end

-- A shop appearance can supply the visual even when the player has no item equipped in that slot.
local HELMET_MODEL = { Helm = { "gear_helm", 1.75, 0.45 }, Hood = { "gear_hood", 1.9, 0.3 }, Crown = { "gear_crown", 0.75, 0.85 } }
local function giveArmor(player, character)
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local helmSkin = GearLooks.Worn(player, "HelmSkins", "HelmSkin")
	local base, rarity = wornGear(player, "Helmet")
	base = helmSkin and helmSkin.Helm or base
	local helmet = HELMET_MODEL[base or ""]
	local worn = false
	if helmet and head then
		worn = attachGear(character, head, helmet[1], head.CFrame * CFrame.new(0, helmet[3] * head.Size.Y / 1.2, 0),
			helmet[2] * head.Size.Y / 1.2, "Y", rarity.Color, helmSkin)
	end
	local armorSkin = GearLooks.Worn(player, "ArmorSkins", "ArmorSkin")
	base, rarity = wornGear(player, "Armor", armorSkin)
	local armorSize
	if base and torso then
		local _, fitted = attachGear(character, torso, "gear_" .. string.lower(base), torso.CFrame, torso.Size.X * 1.22, "X",
			rarity.Color, armorSkin)
		armorSize = fitted
	end

	local bootSkin = GearLooks.Worn(player, "BootSkins", "BootSkin")
	if bootSkin then
		for _, side in { "Left", "Right" } do
			local foot = character:FindFirstChild(side .. "Foot")
			local limb = foot or character:FindFirstChild(side .. " Leg")
			if not limb then
				continue
			end
			local width, depth = limb.Size.X, limb.Size.Z
			local height = foot and limb.Size.Y or limb.Size.Y * 0.35
			local ankle = limb.CFrame * CFrame.new(0, (height - limb.Size.Y) * 0.5, 0)
			weld(character, limb, newPart({ Name = "HeroBoot",
				Size = Vector3.new(width * 1.1, height * 0.92, depth * 1.12), CFrame = ankle,
				Material = Enum.Material.Leather, Color = bootSkin.Leather }))
			weld(character, limb, newPart({ Name = "HeroBoot",
				Size = Vector3.new(width * 1.12, height * bootSkin.BootCuff, depth * 1.14),
				CFrame = ankle * CFrame.new(0, height * 0.38, 0),
				Material = Enum.Material.Metal, Color = bootSkin.Metal }))
			weld(character, limb, newPart({ Name = "HeroBoot",
				Size = Vector3.new(width * 0.38, height * 0.2, depth * 0.08),
				CFrame = ankle * CFrame.new(0, height * 0.38, -depth * 0.57),
				Color = bootSkin.Color }))
		end
	end

	local amulet = GearLooks.Worn(player, "AmuletSkins", "AmuletSkin")
	if amulet and torso then
		local unit = torso.Size.X
		local front = math.max(torso.Size.Z, armorSize and armorSize.Z or 0) * 0.5 + unit * 0.035
		local mount = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.31, -front)
		for _, side in { -1, 1 } do
			weld(character, torso, newPart({ Name = "HeroAmulet",
				Size = Vector3.new(unit * 0.028, unit * 0.21, unit * 0.025), Color = amulet.Metal,
				CFrame = mount * CFrame.new(side * unit * 0.05, 0, 0) * CFrame.Angles(0, 0, math.rad(-side * 30)) }))
		end
		local clasp = mount * CFrame.new(0, -unit * 0.105, 0)
		if amulet.Jewel == Enum.PartType.Block then
			clasp *= CFrame.Angles(0, 0, math.rad(45))
		end
		weld(character, torso, newPart({ Name = "HeroAmulet", Shape = amulet.Jewel, Color = amulet.Metal,
			Size = Vector3.new(unit * 0.14, unit * 0.14, unit * 0.075), CFrame = clasp }))
		weld(character, torso, newPart({ Name = "HeroAmulet", Shape = amulet.Jewel, Color = amulet.Color,
			Size = Vector3.new(unit * 0.096, unit * 0.096, unit * 0.05),
			CFrame = clasp * CFrame.new(0, 0, -unit * 0.045) }))
	end
	return worn
end

-- builds the hero's weapon: shape from the hero (and weapon type), colour from
-- the shop skin. The Classic skin glows in the weapon's rarity colour.
local function giveWeapon(player, character)
	for _, old in character:GetChildren() do
		if old.Name == "HeroWeapon" or old.Name == "HeroHat" or old.Name == "HeroBoot" or old.Name == "HeroAmulet" then
			rainbowParts[old] = nil
			old:Destroy()
		end
	end
	local helmetWorn = giveArmor(player, character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local skin = GearLooks.Find("Swords", player:GetAttribute("EquippedSword")) or Config.Swords[1]
	local color = skin.Color
	local rarity = Items.Rarities[player:GetAttribute("WeaponRarity") or 0]
	if skin.Id == "Classic" and rarity then
		color = rarity.Color
	end
	local accessoryColor = skin.PaintTint and (rarity and rarity.Color or Config.Swords[1].Color) or color
	local heroId = player:GetAttribute("HeroId") or "Swordmaster"
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	-- a hat or helmet replaces the avatar's own hair and hats (they poked through it), and they come back without one
	hideHair(character, hairHidden(player))

	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local up = grip * CFrame.Angles(-math.pi / 2, 0, 0) -- a model's "up" pointing forward out of the fist
	local headScale = head and head.Size.Y / 1.2 or 1
	local function hat(model, height, lift)
		if not helmetWorn and head then
			attachGear(character, head, model, head.CFrame * CFrame.new(0, lift * headScale, 0), height * headScale, "Y", accessoryColor)
		end
	end
	if heroId == "RuneMage" and attachGear(character, hand, "gear_staff", grip * CFrame.new(0, 1.4, 0), 6.2, "Y", color, skin) then
		hat("gear_hat_wizard", 2.0, 1.22)
		return
	elseif heroId == "BeastHunter" and attachGear(character, hand, "gear_bow", grip * CFrame.new(0, 0, -0.25), 4.6, "Y", color, skin) then
		-- (no hood for now: the hood model sits badly on the head; it comes back when it is rebuilt)
		if torso then
			attachGear(character, torso, "gear_quiver", torso.CFrame * CFrame.new(0.35, 0.5, 0.75) * CFrame.Angles(0, 0, math.rad(-20)),
				2.6, "Y", accessoryColor)
		end
		return
	elseif heroId == "Engineer" and attachGear(character, hand, "gear_wrench", up * CFrame.new(0, 1.5, 0), 3.4, "Y", color, skin) then
		hat("gear_goggles", 0.55, 0.25)
		if torso then
			attachGear(character, torso, "gear_pack", torso.CFrame * CFrame.new(0, 0.2, 0.95), 2.4, "Y", accessoryColor)
		end
		return
	elseif heroId == "Swordmaster" and not skin.Baguette then
		local weaponType = player:GetAttribute("WeaponType") or "Longsword"
		local model, length = "gear_sword_long", 4.6
		if weaponType == "Greatsword" then
			model, length = "gear_sword_great", 6.6
		elseif weaponType == "TwinBlades" then
			model, length = "gear_sword_twin", 3.4
		end
		if attachGear(character, hand, model, up * CFrame.new(0, length / 2 - 0.5, 0), length, "Y", color, skin) then
			local left = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
			if weaponType == "TwinBlades" and left then
				local leftUp = left.CFrame * CFrame.new(0, -left.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
				attachGear(character, left, model, leftUp * CFrame.new(0, length / 2 - 0.5, 0), length, "Y", color, skin)
			end
			return
		end
	end

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
		if head and not helmetWorn then
			local hat = newPart({ Name = "HeroHat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6),
				Color = Color3.fromRGB(80, 50, 140), CFrame = head.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2) })
			weld(character, head, hat)
			local tip = newPart({ Name = "HeroHat", Size = Vector3.new(1.2, 1.8, 1.2), Color = Color3.fromRGB(80, 50, 140),
				CFrame = head.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(45), 0) })
			weld(character, head, tip)
		end
	elseif heroId == "BeastHunter" then
		-- a bow: two bent limbs and a string
		for _, side in { 1, -1 } do
			local limb = newPart({ Name = "HeroWeapon", Size = Vector3.new(0.25, 2.2, 0.25), Color = Color3.fromRGB(110, 75, 40),
				Material = Enum.Material.Wood, CFrame = grip * CFrame.new(0, side * 1, -0.3) * CFrame.Angles(side * math.rad(20), 0, 0) })
			weld(character, hand, limb)
		end
		local bowString = newPart({ Name = "HeroWeapon", Size = Vector3.new(0.05, 3.6, 0.05), Color = color, Material = Enum.Material.Neon,
			CFrame = grip * CFrame.new(0, 0, 0.05) })
		weld(character, hand, bowString)
		if skin.Rainbow then
			rainbowParts[bowString] = true
		end
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso then
			local quiver = newPart({ Name = "HeroHat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 0.7, 0.7),
				Color = Color3.fromRGB(120, 80, 45), CFrame = torso.CFrame * CFrame.new(0.4, 0.3, 0.75) * CFrame.Angles(0, 0, math.rad(70)) })
			weld(character, torso, quiver)
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

-- The shop uses the same attachments and finishes on its display figure.
function HeroService.RenderAppearance(model)
	giveWeapon(model, model)
	for _, part in model:GetChildren() do
		rainbowParts[part] = nil
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
		gui.PlayerToHideFrom = player
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
	local rebirths = player:GetAttribute("Rebirths") or 0
	gui:FindFirstChild("Level").Text = (player:GetAttribute("PassVIP") and "[VIP] " or "")
		.. (rebirths > 0 and ("[R" .. rebirths .. "] ") or "") .. player.DisplayName .. " · "
		.. hero.Name .. " " .. (player:GetAttribute("HeroLevel") or 1)
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
	-- the avatar's hair and hats can arrive a moment after the character: hide them again once they are there
	task.delay(2, function()
		if character.Parent then
			hideHair(character, hairHidden(player))
		end
	end)
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
	QuestService.Add(player, "Abilities", 1)
	return true
end

-- melee hit in front of the hero (sword or wrench)
local function melee(player, root, damage, range, targets, color, knock)
	local front = root.Position + root.CFrame.LookVector * (range * 0.5)
	Effects.Arc(root.CFrame * CFrame.new(0, -0.5, 0), range * 0.55, color, targets >= 5)
	Sound.Play("Swing", root.Position)
	local hits = 0
	for _, e in EnemyService.InRange(front, range * 0.6) do
		Effects.Particles(e.position + Vector3.new(0, e.stats.Size * 0.6, 0), { Texture = "Sparks", Color = color, Count = 8,
			Size = 0.8, Speed = 14, Life = 0.35 })
		hit(player, e, damage, knock or (targets >= 5 and 4 or 2.5))
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
			local color = Color3.fromRGB(200, 220, 255)
			for i = 0, 2 do
				task.delay(i * 0.08, function()
					Effects.Arc(root.CFrame * CFrame.Angles(0, i * math.pi * 2 / 3, 0), Hero.Whirlwind.Radius * 0.7, color, true)
				end)
			end
			Effects.Ring(root.Position - Vector3.new(0, 2.5, 0), Hero.Whirlwind.Radius, color, 0.45)
			Effects.Particles(root.Position, { Texture = "Smoke", Color = Color3.fromRGB(230, 235, 255), Count = 18, Size = 3,
				EndSize = 2, Speed = 25, Life = 0.5, Spread = 90, LightEmission = 0.3 })
			Sound.Play("Swing", root.Position)
			for _, e in EnemyService.InRange(root.Position, Hero.Whirlwind.Radius) do
				hit(player, e, Hero.Whirlwind.Damage, 4)
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
				Effects.Shockwave(ground, Hero.Leap.Radius, Color3.fromRGB(255, 210, 140))
				Effects.Shards(ground, Hero.Leap.Radius * 0.7, Color3.fromRGB(120, 100, 80), 10, Enum.Material.Slate)
				Effects.Particles(ground + Vector3.new(0, 1, 0), { Texture = "Sparks", Color = Color3.fromRGB(255, 220, 160), Count = 25,
					Size = 1, Speed = 30, Life = 0.5 })
				Sound.Play("Land", ground)
				Sound.Play("Explosion", ground)
				for _, e in EnemyService.InRange(ground, Hero.Leap.Radius) do
					hit(player, e, Hero.Leap.Damage, 6)
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
			local from = root.Position + root.CFrame.RightVector * 1.2 + Vector3.new(0, 3, 0)
			Effects.Particles(from, { Color = Color3.fromRGB(200, 150, 255), Count = 6, Size = 0.8, Speed = 5, Life = 0.3 })
			Sound.Play("Zap", root.Position)
			Effects.Projectile(from, to, Color3.fromRGB(190, 140, 255), 1.1, math.clamp((to - from).Magnitude / 90, 0.1, 0.35), function()
				hit(player, target, info.Damage, 1)
			end)
		end,
		E = function(player, root)
			local info = Config.Heroes.RuneMage.Nova
			if not ready(player, "WhirlwindReadyAt", info.Cooldown) then
				return
			end
			local ground = root.Position - Vector3.new(0, 2.5, 0)
			Effects.Ring(ground, info.Radius, Color3.fromRGB(150, 220, 255), 0.5)
			Effects.Shards(ground + Vector3.new(0, 1, 0), info.Radius, Color3.fromRGB(170, 230, 255), 16, Enum.Material.Ice)
			Effects.Particles(root.Position, { Texture = "Sparkle", Color = Color3.fromRGB(200, 240, 255), Count = 40, Size = 1.4,
				Speed = info.Radius * 2.5, Life = 0.6, Spread = 100, Drag = 3 })
			Effects.Burst(root.Position, info.Radius * 0.4, Color3.fromRGB(200, 240, 255), 0.3, 0.6)
			Sound.Play("Frost", root.Position)
			for _, e in EnemyService.InRange(root.Position, info.Radius) do
				hit(player, e, info.Damage, 2)
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
			-- a warning circle on the ground first
			Effects.Ring(spot + Vector3.new(0, 0.3, 0), info.Radius, Color3.fromRGB(255, 80, 40), 0.9)
			local rock = Instance.new("Part")
			rock.Shape = Enum.PartType.Ball
			rock.Size = Vector3.one * 6
			rock.Material = Enum.Material.Basalt
			rock.Color = Color3.fromRGB(70, 40, 30)
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanQuery = false
			rock.Position = spot + Vector3.new(25, 70, 10)
			rock.Parent = workspace:FindFirstChild("Effects") or workspace
			local core = Instance.new("PointLight")
			core.Color = Color3.fromRGB(255, 120, 40)
			core.Range = 30
			core.Brightness = 4
			core.Parent = rock
			local fire = Instance.new("ParticleEmitter")
			fire.Texture = Effects.Textures.Fire
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20))
			fire.LightEmission = 1
			fire.Size = NumberSequence.new(5, 1)
			fire.Lifetime = NumberRange.new(0.4, 0.7)
			fire.Rate = 120
			fire.Speed = NumberRange.new(2, 6)
			fire.Parent = rock
			local smoke = Instance.new("ParticleEmitter")
			smoke.Texture = Effects.Textures.Smoke
			smoke.Color = ColorSequence.new(Color3.fromRGB(60, 50, 50))
			smoke.Size = NumberSequence.new(4, 8)
			smoke.Transparency = NumberSequence.new(0.3, 1)
			smoke.Lifetime = NumberRange.new(0.8, 1.2)
			smoke.Rate = 40
			smoke.Parent = rock
			TweenService:Create(rock, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = spot + Vector3.new(0, 2, 0) }):Play()
			task.delay(0.9, function()
				rock:Destroy()
				Effects.Burst(spot + Vector3.new(0, 2, 0), info.Radius, Color3.fromRGB(255, 120, 40), 0.5)
				Effects.Shockwave(spot, info.Radius * 1.2, Color3.fromRGB(255, 160, 60))
				Effects.Shards(spot + Vector3.new(0, 1, 0), info.Radius * 0.8, Color3.fromRGB(60, 40, 35), 12, Enum.Material.Basalt)
				Effects.Particles(spot + Vector3.new(0, 2, 0), { Texture = "Fire", Color = Color3.fromRGB(255, 180, 60),
					Color2 = Color3.fromRGB(255, 60, 20), Count = 40, Size = 4, EndSize = 0.5, Speed = 30, Life = 0.7 })
				-- burning ground for a moment
				local scorch = Instance.new("Part")
				scorch.Shape = Enum.PartType.Cylinder
				scorch.Size = Vector3.new(0.2, info.Radius * 1.6, info.Radius * 1.6)
				scorch.CFrame = CFrame.new(spot + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				scorch.Color = Color3.fromRGB(255, 90, 30)
				scorch.Material = Enum.Material.Neon
				scorch.Transparency = 0.3
				scorch.Anchored = true
				scorch.CanCollide = false
				scorch.CanQuery = false
				scorch.Parent = workspace:FindFirstChild("Effects") or workspace
				TweenService:Create(scorch, TweenInfo.new(2.5), { Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(scorch, 2.6)
				Sound.Play("Explosion", spot)
				for _, e in EnemyService.InRange(spot, info.Radius) do
					hit(player, e, info.Damage, 5)
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
			Effects.Particles(root.Position, { Texture = "Sparks", Color = Color3.fromRGB(255, 190, 80), Count = 30, Size = 1,
				Speed = 30, Life = 0.6, Gravity = -20 })
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
			TowerService.SpawnTurret(player, Vector3.new(spot.X, (Ground.At(spot.X, spot.Z)), spot.Z), info)
			Sound.Play("Build", spot)
		end,
	},
}

ABILITIES.BeastHunter = {
	F = function(player, root)
		local info = Config.Heroes.BeastHunter.Shot
		player:SetAttribute("AttackCooldown", info.Cooldown)
		local target = targetNear(root.Position, info.Range)
		if not target or not ready(player, "AttackReadyAt", info.Cooldown) then
			return
		end
		local to = target.position + Vector3.new(0, target.stats.Size * 0.6, 0)
		Effects.Projectile(root.Position + Vector3.new(0, 1.5, 0), to, Color3.fromRGB(240, 230, 180), 0.45,
			math.clamp((to - root.Position).Magnitude / 140, 0.08, 0.25), function()
				hit(player, target, info.Damage)
			end)
	end,
	E = function(player, root)
		local info = Config.Heroes.BeastHunter.Net
		-- throw it on the biggest group in range
		local best, bestCount = nil, 0
		for _, e in EnemyService.InRange(root.Position, info.Range) do
			local count = #EnemyService.InRange(e.position, info.Radius)
			if count > bestCount then
				best, bestCount = e, count
			end
		end
		if not best or not ready(player, "WhirlwindReadyAt", info.Cooldown) then
			return
		end
		local spot = best.position
		Effects.Projectile(root.Position + Vector3.new(0, 2, 0), spot + Vector3.new(0, 1, 0), Color3.fromRGB(200, 190, 150), 1.2, 0.25)
		task.delay(0.25, function()
			-- a rope grid that drops onto the goblins and stays while they're held
			local net = Instance.new("Model")
			net.Name = "Net"
			local size = info.Radius * 1.8
			for i = -3, 3 do
				for _, dirX in { true, false } do
					local rope = Instance.new("Part")
					rope.Anchored = true
					rope.CanCollide = false
					rope.CanQuery = false
					rope.Color = Color3.fromRGB(190, 170, 120)
					rope.Material = Enum.Material.Fabric
					rope.Size = dirX and Vector3.new(size, 0.2, 0.2) or Vector3.new(0.2, 0.2, size)
					rope.Position = spot + (dirX and Vector3.new(0, 1.5, i * size / 7) or Vector3.new(i * size / 7, 1.5, 0))
					rope.Parent = net
				end
			end
			net.Parent = workspace:FindFirstChild("Effects") or workspace
			game:GetService("Debris"):AddItem(net, info.Time)
			Effects.Ring(spot + Vector3.new(0, 0.5, 0), info.Radius, Color3.fromRGB(200, 190, 150), 0.6)
			for _, e in EnemyService.InRange(spot, info.Radius) do
				if e.stats.Boss then
					EnemyService.Slow(e, 0.4, info.Time)
				else
					EnemyService.Freeze(e, info.Time)
				end
			end
		end)
	end,
	R = function(player, root)
		local info = Config.Heroes.BeastHunter.Wolf
		if not ready(player, "LeapReadyAt", info.Cooldown) then
			return
		end
		-- a grey wolf that stays next to the hero and bites goblins nearby
		local wolf = Instance.new("Model")
		wolf.Name = "Wolf"
		local function wp(props)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			for k, v in props do
				p[k] = v
			end
			p.Parent = wolf
			return p
		end
		local fur = Color3.fromRGB(120, 120, 130)
		local body = wp({ Name = "Body", Size = Vector3.new(1.4, 1.4, 3), Color = fur, Material = Enum.Material.Fabric })
		local head = wp({ Name = "Head", Size = Vector3.new(1.1, 1.1, 1.3), Color = Color3.fromRGB(135, 135, 145),
			Material = Enum.Material.Fabric })
		wolf.PrimaryPart = body
		-- legs, ears, snout, tail and glowing eyes (offsets from the body)
		local extras = {}
		local function extra(props, offset)
			extras[wp(props)] = offset
		end
		for _, x in { -0.45, 0.45 } do
			for _, z in { -1, 1 } do
				extra({ Size = Vector3.new(0.35, 1, 0.35), Color = fur }, CFrame.new(x, -1, z))
			end
			extra({ Size = Vector3.new(0.3, 0.5, 0.2), Color = fur }, CFrame.new(x * 0.8, 1.3, -1.5))
			extra({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25, Color = Color3.fromRGB(120, 220, 255),
				Material = Enum.Material.Neon }, CFrame.new(x * 0.6, 0.65, -2.3))
		end
		extra({ Size = Vector3.new(0.6, 0.5, 0.7), Color = Color3.fromRGB(100, 100, 110) }, CFrame.new(0, 0.3, -2.6))
		extra({ Size = Vector3.new(0.3, 0.3, 1.4), Color = fur }, CFrame.new(0, 0.6, 2) * CFrame.Angles(math.rad(35), 0, 0))
		Effects.Particles(root.Position, { Texture = "Smoke", Color = Color3.fromRGB(200, 200, 210), Count = 12, Size = 2,
			Speed = 8, Life = 0.6, LightEmission = 0 })
		wolf.Parent = workspace:FindFirstChild("Effects") or workspace
		Sound.Play("Land", root.Position)
		local ends = Clock.now + info.Time
		local nextBite = 0
		task.spawn(function()
			while Clock.now < ends and wolf.Parent do
				local r = rootOf(player)
				if not r then
					break
				end
				local pos = r.Position + r.CFrame.RightVector * -3 + Vector3.new(0, -2.2, 0)
				local target = targetNear(r.Position, info.Range)
				if target then
					pos = target.position + Vector3.new(1.5, 0.7, 1.5)
					if Clock.now >= nextBite then
						nextBite = Clock.now + info.Every
						hit(player, target, info.Damage)
					end
				end
				local look = target and target.position or (pos + r.CFrame.LookVector)
				body.CFrame = CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
				head.CFrame = body.CFrame * CFrame.new(0, 0.5, -1.8)
				for part, offset in extras do
					part.CFrame = body.CFrame * offset
				end
				task.wait()
			end
			Effects.Burst(body.Position, 3, Color3.fromRGB(150, 150, 160), 0.3)
			wolf:Destroy()
		end)
	end,
}

-- cooldowns of each hero's E and R, for the screen
local function abilityCooldowns(heroId)
	if heroId == "RuneMage" then
		local h = Config.Heroes.RuneMage
		return h.Nova.Cooldown, h.Meteor.Cooldown
	elseif heroId == "Engineer" then
		local h = Config.Heroes.Engineer
		return h.Overclock.Cooldown, h.Turret.AbilityCooldown
	elseif heroId == "BeastHunter" then
		local h = Config.Heroes.BeastHunter
		return h.Net.Cooldown, h.Wolf.Cooldown
	end
	return Hero.Whirlwind.Cooldown, Hero.Leap.Cooldown
end

local function useAbility(player, slot)
	local root = rootOf(player)
	if not root then
		return
	end
	if State.Get("Mode") == "Pacifist" and State.Get("State") ~= "Lobby" then
		return -- challenge: hands off!
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
	local info = Config.Heroes[heroId]
	if info.UnlockWins and (profile.Wins or 0) < info.UnlockWins then
		return false, info.UnlockText or "Locked"
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

-- Rebirth: a max-level hero goes back to level 1 for a permanent bonus
local function rebirth(player)
	local data = heroData(player)
	local profile = DataService.Get(player)
	if not data or not profile then
		return false, "Still loading"
	end
	if data.Level < Config.HeroMaxLevel then
		return false, "Reach level " .. Config.HeroMaxLevel .. " first"
	end
	if State.Get("State") == "Wave" then
		return false, "Wait for the break between waves"
	end
	data.Level, data.Xp, data.Points = 1, 0, {}
	profile.Rebirths = (profile.Rebirths or 0) + 1
	profile.Owned.Swords.Starforged = true
	DataService.Publish(player)
	publish(player)
	task.spawn(DataService.Save, player)
	Remotes.Notify:FireAllClients(player.DisplayName .. " was reborn! (Rebirth " .. profile.Rebirths .. ")", Color3.fromRGB(255, 240, 160))
	return true, profile.Rebirths
end

local function spendAscension(player, perkId)
	local profile = DataService.Get(player)
	if not profile or not Config.FindById(Config.AscensionPerks, perkId) then
		return false, "Unknown perk"
	end
	local asc = ascensionOf(profile)
	if asc.Points - ascensionSpent(asc) <= 0 then
		return false, "No Ascension Points"
	end
	asc.Spent[perkId] = (asc.Spent[perkId] or 0) + 1
	HeroService.RefreshStats(player)
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
	Remotes.Rebirth.OnServerInvoke = rebirth
	Remotes.SpendAscension.OnServerInvoke = spendAscension
	PetService.OnPetChanged = HeroService.RefreshStats

	ItemService.OnGearChanged = HeroService.RefreshStats
	local pendingLooks = {}
	local function refreshLook(player)
		if pendingLooks[player] then
			return
		end
		pendingLooks[player] = true
		task.defer(function()
			pendingLooks[player] = nil
			if player.Character then
				giveWeapon(player, player.Character)
			end
		end)
	end
	task.spawn(function()
		ServerStorage:WaitForChild("ArtModels").ChildAdded:Connect(function(model)
			if model.Name:match("^gear_") then
				for _, player in Players:GetPlayers() do
					refreshLook(player)
				end
			end
		end)
	end)

	local appearanceAttributes = { "WeaponType", "WeaponRarity", "WornHelmet", "WornArmor" }
	for _, slot in GearLooks.Slots do
		table.insert(appearanceAttributes, "Equipped" .. slot.Field)
	end
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
		for _, attr in appearanceAttributes do
			player:GetAttributeChangedSignal(attr):Connect(function()
				refreshLook(player)
			end)
		end
		for _, attr in { "EquippedTitle", "HeroLevel", "Rebirths", "PassVIP" } do
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
					if not e.dead and (Vector3.new(e.position.X, 0, e.position.Z) - flat).Magnitude < 2.5 + e.stats.Size * 0.6 then
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
