-- The hero every player controls: the Swordmaster.
-- F = sword hit, E = whirlwind, R = leap strike.
-- Killing goblins gives xp, levels give more damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local HeroService = {}
local Hero = Config.Hero

local rainbowBlades = {} -- blades that cycle through colours

-- hero damage: level, gear Power, and a chance to crit (double damage)
local function damageFor(player, base)
	local level = player:GetAttribute("HeroLevel") or 1
	local power = (player:GetAttribute("BonusPower") or 0) / 100
	local damage = base * (1 + (level - 1) * Hero.DamagePerLevel) * (1 + power)
	if math.random() * 100 < (player:GetAttribute("BonusCrit") or 0) then
		return damage * 2, true
	end
	return damage, false
end

local function weaponOf(player)
	return Items.WeaponTypes[player:GetAttribute("WeaponType") or "Longsword"] or Items.WeaponTypes.Longsword
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
	local level = player:GetAttribute("HeroLevel") or 1
	if level >= Hero.MaxLevel then
		return
	end
	local xp = (player:GetAttribute("HeroXp") or 0) + amount
	local needed = Config.XpForLevel(level)
	while xp >= needed and level < Hero.MaxLevel do
		xp -= needed
		level += 1
		needed = Config.XpForLevel(level)
		local root = rootOf(player)
		if root then
			Effects.Burst(root.Position, 8, Color3.fromRGB(255, 220, 90), 0.6)
			Effects.Text(root.Position + Vector3.new(0, 4, 0), "LEVEL UP!", Color3.fromRGB(255, 220, 90), 1.4)
			Sound.Play("Coin", root.Position)
		end
		Remotes.Notify:FireClient(player, "Level up! Your hero is now level " .. level, Color3.fromRGB(255, 220, 90))
	end
	player:SetAttribute("HeroLevel", level)
	player:SetAttribute("HeroXp", level >= Hero.MaxLevel and 0 or xp)
	player:SetAttribute("HeroXpNeeded", needed)
end

function HeroService.Reset(player)
	player:SetAttribute("HeroLevel", 1)
	player:SetAttribute("HeroXp", 0)
	player:SetAttribute("HeroXpNeeded", Config.XpForLevel(1))
	player:SetAttribute("AttackReadyAt", 0)
	player:SetAttribute("WhirlwindReadyAt", 0)
	player:SetAttribute("LeapReadyAt", 0)
end

-- one sword (blade + hilt) welded to a hand
local function makeBlade(character, hand, skin, color, length, thick)
	local blade = Instance.new("Part")
	blade.Name = "HeroSword"
	blade.CanCollide = false
	blade.CanQuery = false
	blade.Massless = true
	blade.Color = color
	if skin.Baguette then
		blade.Shape = Enum.PartType.Cylinder
		blade.Size = Vector3.new(length + 0.5, 0.9 * thick, 0.9 * thick)
		blade.Material = Enum.Material.Sand
	else
		blade.Size = Vector3.new(0.3 * thick, 0.3 * thick, length)
		blade.Material = Enum.Material.Neon
	end
	local hilt = Instance.new("Part")
	hilt.Name = "HeroSwordHilt"
	hilt.Size = Vector3.new(1.2 * thick, 0.3, 0.3)
	hilt.Color = Color3.fromRGB(120, 80, 40)
	hilt.CanCollide = false
	hilt.CanQuery = false
	hilt.Massless = true
	hilt.Transparency = skin.Baguette and 1 or 0

	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	hilt.CFrame = grip
	if skin.Baguette then
		blade.CFrame = grip * CFrame.new(0, 0, -length / 2 - 0.2) * CFrame.Angles(0, math.pi / 2, 0)
	else
		blade.CFrame = grip * CFrame.new(0, 0, -length / 2 - 0.2)
	end
	for _, p in { blade, hilt } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = character
	end
	if skin.Rainbow then
		rainbowBlades[blade] = true
	end
end

-- the sword(s): shape from the equipped weapon type, colour from the shop skin
-- (the Classic skin glows in the weapon's rarity colour)
local function giveSword(player, character)
	for _, old in character:GetChildren() do
		if old.Name == "HeroSword" or old.Name == "HeroSwordHilt" then
			rainbowBlades[old] = nil
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

-- name tag over the head: level and the title from the shop
local function giveNameTag(player, character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("HeroTag")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "HeroTag"
		gui.Size = UDim2.fromOffset(220, 44)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = 120
		gui.Parent = head
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.45, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 200, 90)
		title.TextStrokeTransparency = 0.3
		title.Parent = gui
		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.Size = UDim2.new(1, 0, 0.5, 0)
		level.Position = UDim2.fromScale(0, 0.5)
		level.BackgroundTransparency = 1
		level.Font = Enum.Font.GothamBlack
		level.TextScaled = true
		level.TextColor3 = Color3.new(1, 1, 1)
		level.TextStrokeTransparency = 0.3
		level.Parent = gui
	end
	local titleItem = Config.FindById(Config.Titles, player:GetAttribute("EquippedTitle") or "None")
	gui:FindFirstChild("Title").Text = (titleItem and titleItem.Id ~= "None") and titleItem.Name or ""
	gui:FindFirstChild("Level").Text =player.DisplayName .. "  Lv " .. (player:GetAttribute("HeroLevel") or 1)
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Hero.WalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- we draw our own name tag
	end
	character:WaitForChild("RightHand", 5)
	character:WaitForChild("Head", 5)
	giveSword(player, character)
	giveNameTag(player, character)
end

local function attack(player)
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("AttackReadyAt") or 0) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local weapon = weaponOf(player)
	player:SetAttribute("AttackReadyAt", now + weapon.Cooldown)
	player:SetAttribute("AttackCooldown", weapon.Cooldown)
	local front = root.Position + root.CFrame.LookVector * (weapon.Range * 0.5)
	Effects.Burst(front, weapon.Range * 0.35, Color3.fromRGB(200, 220, 255), 0.2, 0.5)
	Sound.Play("Swing", root.Position)
	-- hits the goblins in front of the hero (how many depends on the weapon)
	local hits = 0
	for _, e in EnemyService.InRange(front, weapon.Range * 0.6) do
		local damage, crit = damageFor(player, Hero.Attack.Damage * weapon.Damage)
		EnemyService.Damage(e, damage, player, true, crit)
		hits += 1
		if hits >= weapon.Targets then
			break
		end
	end
end

local function whirlwind(player)
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("WhirlwindReadyAt") or 0) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	player:SetAttribute("WhirlwindReadyAt", now + Hero.Whirlwind.Cooldown)
	Effects.Ring(root.Position - Vector3.new(0, 2.5, 0), Hero.Whirlwind.Radius, Color3.fromRGB(200, 220, 255), 0.45)
	Effects.Burst(root.Position, Hero.Whirlwind.Radius * 0.6, Color3.fromRGB(220, 230, 255), 0.35, 0.6)
	Sound.Play("Swing", root.Position)
	for _, e in EnemyService.InRange(root.Position, Hero.Whirlwind.Radius) do
		local damage, crit = damageFor(player, Hero.Whirlwind.Damage)
		EnemyService.Damage(e, damage, player, true, crit)
	end
end

-- the player's own computer makes the jump (it moves the character),
-- the server waits for the landing and does the damage
local function leap(player)
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("LeapReadyAt") or 0) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	player:SetAttribute("LeapReadyAt", now + Hero.Leap.Cooldown)
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
			local damage, crit = damageFor(player, Hero.Leap.Damage)
			EnemyService.Damage(e, damage, player, true, crit)
			if not e.stats.Boss then
				EnemyService.Freeze(e, 0.6) -- stunned
			end
		end
	end)
end

function HeroService.Start()
	Remotes.HeroAttack.OnServerEvent:Connect(attack)
	Remotes.HeroWhirlwind.OnServerEvent:Connect(whirlwind)
	Remotes.HeroLeap.OnServerEvent:Connect(leap)

	local function onPlayer(player)
		HeroService.Reset(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		-- new look picked in the shop: swap the sword / title right away
		for _, attr in { "EquippedSword", "WeaponType", "WeaponRarity" } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				if player.Character then
					giveSword(player, player.Character)
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

	RunService.Heartbeat:Connect(function()
		local hue = (os.clock() * 0.4) % 1
		for blade in rainbowBlades do
			if blade.Parent then
				blade.Color = Color3.fromHSV(hue, 1, 1)
			else
				rainbowBlades[blade] = nil
			end
		end
	end)
end

return HeroService
