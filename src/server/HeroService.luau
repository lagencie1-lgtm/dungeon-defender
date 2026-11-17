-- The hero every player controls: the Swordmaster.
-- F = sword hit, E = whirlwind. Killing goblins gives xp, levels give more damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)

local HeroService = {}
local Hero = Config.Hero

local function damageFor(player, base)
	local level = player:GetAttribute("HeroLevel") or 1
	return base * (1 + (level - 1) * Hero.DamagePerLevel)
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
			Effects.Text(root.Position + Vector3.new(0, 4, 0), "LEVEL UP!", Color3.fromRGB(255, 220, 90))
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
end

-- give the character a glowing sword in the right hand
local function giveSword(character)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local blade = Instance.new("Part")
	blade.Name = "HeroSword"
	blade.Size = Vector3.new(0.3, 0.3, 4.5)
	blade.Color = Color3.fromRGB(200, 220, 255)
	blade.Material = Enum.Material.Neon
	blade.CanCollide = false
	blade.Massless = true
	local hilt = Instance.new("Part")
	hilt.Name = "HeroSwordHilt"
	hilt.Size = Vector3.new(1.2, 0.3, 0.3)
	hilt.Color = Color3.fromRGB(120, 80, 40)
	hilt.CanCollide = false
	hilt.Massless = true

	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	hilt.CFrame = grip
	blade.CFrame = grip * CFrame.new(0, 0, -2.4)
	for _, p in { blade, hilt } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = character
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Hero.WalkSpeed
	end
	giveSword(character)
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
	player:SetAttribute("AttackReadyAt", now + Hero.Attack.Cooldown)
	local front = root.Position + root.CFrame.LookVector * (Hero.Attack.Range * 0.5)
	Effects.Burst(front, 3, Color3.fromRGB(200, 220, 255), 0.2, 0.5)
	local damage = damageFor(player, Hero.Attack.Damage)
	-- hits the goblins in front of the hero, up to 3 at once
	local hits = 0
	for _, e in EnemyService.InRange(front, Hero.Attack.Range * 0.6) do
		EnemyService.Damage(e, damage, player)
		hits += 1
		if hits >= 3 then
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
	local damage = damageFor(player, Hero.Whirlwind.Damage)
	for _, e in EnemyService.InRange(root.Position, Hero.Whirlwind.Radius) do
		EnemyService.Damage(e, damage, player)
	end
end

function HeroService.Start()
	Remotes.HeroAttack.OnServerEvent:Connect(attack)
	Remotes.HeroWhirlwind.OnServerEvent:Connect(whirlwind)

	local function onPlayer(player)
		HeroService.Reset(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return HeroService
