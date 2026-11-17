-- The hero every player controls: the Swordmaster.
-- F = sword hit, E = whirlwind, R = leap strike.
-- Killing goblins gives xp, levels give more damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local HeroService = {}
local Hero = Config.Hero

local rainbowBlades = {} -- blades that cycle through colours

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

-- the sword in the right hand, in the look the player picked in the shop
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

	local blade = Instance.new("Part")
	blade.Name = "HeroSword"
	blade.CanCollide = false
	blade.CanQuery = false
	blade.Massless = true
	blade.Color = skin.Color
	if skin.Baguette then
		blade.Shape = Enum.PartType.Cylinder
		blade.Size = Vector3.new(5, 0.9, 0.9)
		blade.Material = Enum.Material.Sand
	else
		blade.Size = Vector3.new(0.3, 0.3, 4.5)
		blade.Material = Enum.Material.Neon
	end
	local hilt = Instance.new("Part")
	hilt.Name = "HeroSwordHilt"
	hilt.Size = Vector3.new(1.2, 0.3, 0.3)
	hilt.Color = Color3.fromRGB(120, 80, 40)
	hilt.CanCollide = false
	hilt.CanQuery = false
	hilt.Massless = true
	hilt.Transparency = skin.Baguette and 1 or 0

	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	hilt.CFrame = grip
	if skin.Baguette then
		blade.CFrame = grip * CFrame.new(0, 0, -2.4) * CFrame.Angles(0, math.pi / 2, 0)
	else
		blade.CFrame = grip * CFrame.new(0, 0, -2.4)
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
	player:SetAttribute("AttackReadyAt", now + Hero.Attack.Cooldown)
	local front = root.Position + root.CFrame.LookVector * (Hero.Attack.Range * 0.5)
	Effects.Burst(front, 3.5, Color3.fromRGB(200, 220, 255), 0.2, 0.5)
	Sound.Play("Swing", root.Position)
	local damage = damageFor(player, Hero.Attack.Damage)
	-- hits the goblins in front of the hero, up to 3 at once
	local hits = 0
	for _, e in EnemyService.InRange(front, Hero.Attack.Range * 0.6) do
		EnemyService.Damage(e, damage, player, true)
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
	Sound.Play("Swing", root.Position)
	local damage = damageFor(player, Hero.Whirlwind.Damage)
	for _, e in EnemyService.InRange(root.Position, Hero.Whirlwind.Radius) do
		EnemyService.Damage(e, damage, player, true)
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
		local damage = damageFor(player, Hero.Leap.Damage)
		for _, e in EnemyService.InRange(ground, Hero.Leap.Radius) do
			EnemyService.Damage(e, damage, player, true)
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
		player:GetAttributeChangedSignal("EquippedSword"):Connect(function()
			if player.Character then
				giveSword(player, player.Character)
			end
		end)
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
