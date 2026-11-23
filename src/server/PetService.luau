-- Pets: hatch eggs with gold, equip one pet, it follows your hero and gives
-- a small bonus. Pets level up while you play and can evolve once.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Effects = require(script.Parent.Effects)
local ArtService = require(script.Parent.ArtService)
local StoreService = require(script.Parent.StoreService)

local PetService = {}

local followers = {} -- [player] = model following the hero
local rng = Random.new()

-- set by HeroService: recomputes stats when the pet changes
PetService.OnPetChanged = function(_player) end

local function findPet(profile, id)
	for i, pet in profile.Pets or {} do
		if pet.id == id then
			return pet, i
		end
	end
	return nil, nil
end

-- the bonus a pet gives right now, as { stat, percent }
function PetService.BonusOf(pet)
	local info = Config.Pets[pet.kind]
	if not info then
		return nil, 0
	end
	local value = info.Bonus * (1 + 0.1 * ((pet.level or 1) - 1)) * (pet.evolved and 2 or 1)
	return info.Stat, value
end

function PetService.EquippedPet(player)
	local profile = DataService.Get(player)
	if not profile or not profile.EquippedPet then
		return nil
	end
	return findPet(profile, profile.EquippedPet)
end

local function send(player)
	local profile = DataService.Get(player)
	if profile then
		Remotes.Pets:FireClient(player, profile.Pets or {}, profile.EquippedPet)
	end
end

-------------------------------------------------------------------------------
-- the pet model following the hero
-------------------------------------------------------------------------------
local function buildModel(pet, skin)
	local info = Config.Pets[pet.kind]
	local color = skin and skin.Primary or info.Color
	local scale = pet.evolved and 1.6 or 1
	local model = Instance.new("Model")
	model.Name = "Pet"
	local function p(props)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		for k, v in props do
			part[k] = v
		end
		part.Parent = model
		return part
	end
	local body = p({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6 * scale, Color = color,
		Material = info.Shape == "Bug" and Enum.Material.Neon or Enum.Material.SmoothPlastic })
	model.PrimaryPart = body
	local offsets = {} -- [part] = offset from the body
	local function add(props, offset)
		local part = p(props)
		offsets[part] = offset
	end
	-- the painted Blender model of this pet (art/blender/pets.py); the simple shapes below are the fallback
	local template = ArtService.Model("pet_" .. string.lower(pet.kind))
	if template then
		local look = template:Clone()
		local _, size = look:GetBoundingBox()
		look:ScaleTo(look:GetScale() * (2.3 * scale) / size.Y)
		local box = look:GetBoundingBox()
		StoreService.ApplyModelSkin(look, skin)
		for _, part in look:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				offsets[part] = CFrame.new(-box.Position) * part.CFrame
				part.Parent = model
			end
		end
		look:Destroy()
		body.Transparency = 1
	end
	if not template then
		for side = -1, 1, 2 do
			add({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35 * scale, Color = Color3.new(0, 0, 0) },
				CFrame.new(side * 0.35 * scale, 0.25 * scale, -0.7 * scale))
		end
		if info.Shape == "Pup" then
			for side = -1, 1, 2 do
				add({ Name = "Ear", Size = Vector3.new(0.3, 0.7, 0.3) * scale, Color = color }, CFrame.new(side * 0.5 * scale, 0.9 * scale, 0))
			end
		elseif info.Shape == "Sprout" then
			add({ Name = "Leaf", Size = Vector3.new(0.9, 0.15, 0.5) * scale, Color = Color3.fromRGB(60, 200, 60) },
				CFrame.new(0, 1 * scale, 0) * CFrame.Angles(0, 0, math.rad(20)))
		elseif info.Shape == "Bug" then
			for side = -1, 1, 2 do
				add({ Name = "Wing", Size = Vector3.new(1, 0.1, 0.6) * scale, Color = Color3.new(1, 1, 1), Transparency = 0.4 },
					CFrame.new(side * 0.9 * scale, 0.4 * scale, 0.2))
			end
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 8
			light.Parent = body
		elseif info.Shape == "Golem" then
			body.Material = Enum.Material.Basalt
			add({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6 * scale, Color = Color3.fromRGB(255, 140, 40),
				Material = Enum.Material.Neon }, CFrame.new(0, 0, -0.6 * scale))
		elseif info.Shape == "Dragon" then
			for side = -1, 1, 2 do
				add({ Name = "Wing", Size = Vector3.new(1.4, 0.15, 0.8) * scale, Color = color:Lerp(Color3.new(0, 0, 0), 0.3) },
					CFrame.new(side * 1.1 * scale, 0.5 * scale, 0.2) * CFrame.Angles(0, 0, side * math.rad(25)))
				add({ Name = "Horn", Size = Vector3.new(0.2, 0.5, 0.2) * scale, Color = Color3.fromRGB(255, 220, 120) },
					CFrame.new(side * 0.35 * scale, 0.85 * scale, -0.2 * scale))
			end
		end
	end
	if pet.evolved then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = skin and skin.Accent or info.Color
		sparkles.Parent = body
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 22)
	tag.StudsOffset = Vector3.new(0, 1.8 * scale, 0)
	tag.MaxDistance = 60
	tag.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Items.Rarities[info.Rarity].Color
	label.TextStrokeTransparency = 0.3
	label.Text = info.Name .. " Lv " .. (pet.level or 1)
	label.Parent = tag
	return model, offsets
end

local function refreshFollower(player)
	local old = followers[player]
	if old then
		old.model:Destroy()
		followers[player] = nil
	end
	local pet = PetService.EquippedPet(player)
	if not pet then
		return
	end
	local model, offsets = buildModel(pet, StoreService.SkinFor(player, "Pet"))
	-- The server only places the pet once, as one welded piece. Every player's own device then moves it
	-- (src/client/PetFollow.client.luau): motion sent from the server stutters on phones.
	local body = model.PrimaryPart
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	body.CFrame = root and root.CFrame * CFrame.new(3, 0, 2.5) or CFrame.new(0, -200, 0)
	for part, offset in offsets do
		part.CFrame = body.CFrame * offset
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	model:SetAttribute("PetOwner", player.UserId)
	model:SetAttribute("PetKind", pet.kind)
	model:SetAttribute("PetScale", pet.evolved and 1.6 or 1)
	CollectionService:AddTag(model, "PetFollower")
	model.Parent = workspace
	followers[player] = { model = model }
end

-------------------------------------------------------------------------------
-- actions
-------------------------------------------------------------------------------
local function hatch(player, eggId)
	local profile = DataService.Get(player)
	local egg = Config.FindById(Config.Eggs, eggId)
	if not profile or not egg then
		return false, "Unknown egg"
	end
	profile.Pets = profile.Pets or {}
	if #profile.Pets >= Config.PetBagSize then
		return false, "Pet bag full (" .. Config.PetBagSize .. "). Release a pet first"
	end
	if profile.Gold < egg.Price then
		return false, "Not enough gold (need " .. egg.Price .. ")"
	end
	profile.Gold -= egg.Price
	local total = 0
	for _, c in egg.Chances do
		total += c[2]
	end
	local roll = rng:NextNumber() * total
	local kind = egg.Chances[1][1]
	for _, c in egg.Chances do
		roll -= c[2]
		if roll <= 0 then
			kind = c[1]
			break
		end
	end
	local pet = { id = HttpService:GenerateGUID(false):sub(1, 12), kind = kind, level = 1, xp = 0, evolved = false }
	table.insert(profile.Pets, pet)
	if not profile.EquippedPet then
		profile.EquippedPet = pet.id
		refreshFollower(player)
		PetService.OnPetChanged(player)
	end
	DataService.Publish(player)
	send(player)
	task.spawn(DataService.Save, player)
	local info = Config.Pets[kind]
	if info.Rarity >= 5 then
		-- a big moment for the whole server
		local chance = 0
		for _, c in egg.Chances do
			if c[1] == kind then
				chance = c[2] / total * 100
			end
		end
		Remotes.Notify:FireAllClients(string.format("%s hatched a %s %s! (%.2f%% chance)", player.DisplayName,
			Items.Rarities[info.Rarity].Name, info.Name, chance), Items.Rarities[info.Rarity].Color)
	end
	return true, pet
end

local function equip(player, id)
	local profile = DataService.Get(player)
	if not profile or not findPet(profile, id) then
		return false, "Pet not found"
	end
	profile.EquippedPet = id
	refreshFollower(player)
	PetService.OnPetChanged(player)
	send(player)
	return true
end

local function evolve(player, id)
	local profile = DataService.Get(player)
	local pet = profile and findPet(profile, id)
	if not pet then
		return false, "Pet not found"
	end
	if pet.evolved then
		return false, "Already evolved"
	end
	if (pet.level or 1) < Config.PetMaxLevel then
		return false, "Needs level " .. Config.PetMaxLevel
	end
	if profile.Gold < Config.PetEvolveGold then
		return false, "Evolving costs " .. Config.PetEvolveGold .. " gold"
	end
	profile.Gold -= Config.PetEvolveGold
	pet.evolved = true
	DataService.Publish(player)
	if profile.EquippedPet == id then
		refreshFollower(player)
		PetService.OnPetChanged(player)
	end
	send(player)
	return true
end

local function release(player, id)
	local profile = DataService.Get(player)
	local pet, index = nil, nil
	if profile then
		pet, index = findPet(profile, id)
	end
	if not pet then
		return false, "Pet not found"
	end
	if profile.EquippedPet == id then
		return false, "Equip another pet first"
	end
	table.remove(profile.Pets, index)
	local gold = Config.PetReleaseGold[Config.Pets[pet.kind].Rarity] or 50
	DataService.AddGold(player, gold)
	send(player)
	return true, gold
end

-- the equipped pet learns from every enemy defeated
function PetService.AddXpAll(amount)
	for _, player in Players:GetPlayers() do
		local pet = PetService.EquippedPet(player)
		if pet and (pet.level or 1) < Config.PetMaxLevel then
			pet.xp = (pet.xp or 0) + amount
			if pet.xp >= Config.PetXpPerLevel * pet.level then
				pet.xp -= Config.PetXpPerLevel * pet.level
				pet.level += 1
				Remotes.Notify:FireClient(player, Config.Pets[pet.kind].Name .. " is now level " .. pet.level .. "!",
					Config.Pets[pet.kind].Color)
				refreshFollower(player)
				PetService.OnPetChanged(player)
				send(player)
			end
		end
	end
end

function PetService.Start()
	Remotes.HatchEgg.OnServerInvoke = hatch
	Remotes.EquipPet.OnServerInvoke = equip
	Remotes.EvolvePet.OnServerInvoke = evolve
	Remotes.ReleasePet.OnServerInvoke = release
	Remotes.GetPets.OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		return profile and profile.Pets or {}, profile and profile.EquippedPet
	end
	table.insert(DataService.OnLoaded, function(player)
		player:GetAttributeChangedSignal("EquippedPetSkin"):Connect(function()
			refreshFollower(player)
		end)
		refreshFollower(player)
		send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local f = followers[player]
		if f then
			f.model:Destroy()
			followers[player] = nil
		end
	end)
end

return PetService
