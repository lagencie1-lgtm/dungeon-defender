-- Pets: hatch eggs with gold, equip up to three (Config.PetTeamLevels), they follow your hero and give
-- a small bonus. The first one is the lead. Pets level up while you play and can evolve once.
-- New kinds go into the Pet Index and pay a one-off reward.
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

local followers = {} -- [player] = list of { pet = the pet's data, model = its model following the hero }, lead first
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

-- how many pets may walk with this player: by the level of their best hero
function PetService.SlotsOf(player)
	local profile = DataService.Get(player)
	local best = 1
	for _, hero in (profile and profile.Heroes) or {} do
		best = math.max(best, type(hero) == "table" and hero.Level or 1)
	end
	if profile and (profile.Rebirths or 0) > 0 then
		best = math.huge -- a reborn hero starts at level 1 again, but keeps its pet team
	end
	local slots = 0
	for _, level in Config.PetTeamLevels do
		if best >= level then
			slots += 1
		end
	end
	return math.max(slots, 1)
end

-- the ids of the team, lead first. Older saves only know EquippedPet: that one is the lead.
local function teamIds(profile, slots)
	local ids = {}
	local function add(id)
		if id and #ids < slots and not table.find(ids, id) and findPet(profile, id) then
			table.insert(ids, id)
		end
	end
	add(profile.EquippedPet)
	for _, id in profile.PetTeam or {} do
		add(id)
	end
	return ids
end

local function setTeam(profile, ids)
	profile.EquippedPet = ids[1]
	profile.PetTeam = ids
end

-- the pets walking with this player, lead first
function PetService.Team(player)
	local profile = DataService.Get(player)
	local team = {}
	if profile then
		for _, id in teamIds(profile, PetService.SlotsOf(player)) do
			table.insert(team, (findPet(profile, id)))
		end
	end
	return team
end

-- every bonus of the team as { stat, percent }: the lead in full, helpers a part (Config.PetHelperBonus)
function PetService.TeamBonuses(player)
	local list = {}
	for i, pet in PetService.Team(player) do
		local stat, value = PetService.BonusOf(pet)
		if stat then
			table.insert(list, { stat, value * (i == 1 and 1 or Config.PetHelperBonus) })
		end
	end
	return list
end

-- the lead pet's model following this player's hero (or nil)
function PetService.FollowerOf(player)
	local f = followers[player]
	return f and f[1] and f[1].model
end

-- every pet of the team with its model: a list of { pet, model }
function PetService.FollowersOf(player)
	return followers[player] or {}
end

function PetService.EquippedPet(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local lead = teamIds(profile, 1)[1]
	if not lead then
		return nil
	end
	return findPet(profile, lead)
end

-- kinds this player has ever hatched (older saves: the pets they still have)
local function indexOf(profile)
	if type(profile.PetIndex) ~= "table" then
		profile.PetIndex = {}
	end
	for _, pet in profile.Pets or {} do
		profile.PetIndex[pet.kind] = true
	end
	return profile.PetIndex
end

local function send(player)
	local profile = DataService.Get(player)
	if profile then
		Remotes.Pets:FireClient(player, profile.Pets or {}, profile.EquippedPet,
			teamIds(profile, PetService.SlotsOf(player)), indexOf(profile), PetService.SlotsOf(player))
	end
end

-------------------------------------------------------------------------------
-- the pet model following the hero
-------------------------------------------------------------------------------
local function buildModel(pet, skin, withTag)
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
	if withTag == false then
		return model, offsets -- helpers of the team carry no name tag: three labels round one hero is clutter
	end
	-- (sized in studs, not pixels: from the far battle camera on a phone a pixel-sized tag was bigger than the pet)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(5, 0.8)
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

local function placeFollower(player, pet, slot)
	local model, offsets = buildModel(pet, StoreService.SkinFor(player, "Pet"), slot == 1)
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
	model:SetAttribute("PetSlot", slot) -- 1 = lead; where it walks (PetFollow.client.luau)
	CollectionService:AddTag(model, "PetFollower")
	model.Parent = workspace
	return model
end

local function refreshFollower(player)
	for _, f in followers[player] or {} do
		f.model:Destroy()
	end
	followers[player] = nil
	local list = {}
	for slot, pet in PetService.Team(player) do
		table.insert(list, { pet = pet, model = placeFollower(player, pet, slot) })
	end
	if #list > 0 then
		followers[player] = list
	end
	player:SetAttribute("PetTeamSize", #list) -- (the Auto Collect pass works through the pets, ItemService and LootService)
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
	local index = indexOf(profile)
	local isNew = not index[kind]
	table.insert(profile.Pets, pet)
	index[kind] = true
	local indexGold, indexGems = 0, 0
	if isNew then
		-- a new kind for the Pet Index: a one-off reward, and maybe a milestone
		local rarity = Config.Pets[kind].Rarity
		indexGold, indexGems = Config.PetIndexGold[rarity] or 0, Config.PetIndexGems[rarity] or 0
		local found = 0
		for _ in index do
			found += 1
		end
		for _, m in Config.PetIndexMilestones do
			if found == m.At then
				indexGold += m.Gold or 0
				indexGems += m.Gems or 0
			end
		end
		profile.Gold += indexGold
		DataService.AddGems(player, indexGems)
	end
	local ids = teamIds(profile, PetService.SlotsOf(player))
	if #ids < PetService.SlotsOf(player) then
		-- a free place in the team: it joins straight away
		table.insert(ids, pet.id)
		setTeam(profile, ids)
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
	-- (a copy for the hatch screen, with what the Pet Index paid)
	local shown = table.clone(pet)
	shown.indexGold, shown.indexGems = indexGold, indexGems
	return true, shown
end

-- action: nil = join the team (when it is full, it takes the last place), "Lead" = becomes the lead,
-- "Off" = leaves the team
local function equip(player, id, action)
	local profile = DataService.Get(player)
	if not profile or not findPet(profile, id) then
		return false, "Pet not found"
	end
	local slots = PetService.SlotsOf(player)
	local ids = teamIds(profile, slots)
	local at = table.find(ids, id)
	if action == "Off" then
		if at then
			table.remove(ids, at)
		end
	elseif action == "Lead" then
		if at then
			table.remove(ids, at)
		end
		table.insert(ids, 1, id)
		while #ids > slots do
			table.remove(ids)
		end
	elseif not at then
		if #ids >= slots then
			table.remove(ids)
		end
		table.insert(ids, id)
	end
	setTeam(profile, ids)
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
	if table.find(teamIds(profile, PetService.SlotsOf(player)), id) then
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
	if table.find(teamIds(profile, PetService.SlotsOf(player)), id) then
		return false, "Take it out of your team first"
	end
	table.remove(profile.Pets, index)
	local gold = Config.PetReleaseGold[Config.Pets[pet.kind].Rarity] or 50
	DataService.AddGold(player, gold)
	send(player)
	return true, gold
end

-- every pet of the team learns from every enemy defeated
function PetService.AddXpAll(amount)
	for _, player in Players:GetPlayers() do
		local leveled = false
		local gain = amount * (StoreService.Boosted(player, "PetXp") and 2 or 1) -- the Pet Trainer boost
		for _, pet in PetService.Team(player) do
			if (pet.level or 1) < Config.PetMaxLevel then
				pet.xp = (pet.xp or 0) + gain
				if pet.xp >= Config.PetXpPerLevel * pet.level then
					pet.xp -= Config.PetXpPerLevel * pet.level
					pet.level += 1
					leveled = true
					Remotes.Notify:FireClient(player, Config.Pets[pet.kind].Name .. " is now level " .. pet.level .. "!",
						Config.Pets[pet.kind].Color)
				end
			end
		end
		if leveled then
			refreshFollower(player)
			PetService.OnPetChanged(player)
			send(player)
		end
	end
end

PetService.Equip = function(player, id, action)
	return equip(player, id, action)
end

function PetService.Start()
	-- count 3 = Hatch x3: three eggs in one tap (research report: automate low-value steps). Same price each, same
	-- odds, gold only (gold is earned by playing, never bought). Returns the three pets, rarest first.
	Remotes.HatchEgg.OnServerInvoke = function(player, eggId, count)
		if count ~= 3 then
			return hatch(player, eggId)
		end
		local profile = DataService.Get(player)
		local egg = Config.FindById(Config.Eggs, eggId)
		if not profile or not egg then
			return false, "Unknown egg"
		end
		if #(profile.Pets or {}) + 3 > Config.PetBagSize then
			return false, "Not enough room in the pet bag for 3 (" .. Config.PetBagSize .. " max)"
		end
		if profile.Gold < egg.Price * 3 then
			return false, "Not enough gold (need " .. egg.Price * 3 .. ")"
		end
		local hatched = {}
		for _ = 1, 3 do
			local ok, pet = hatch(player, eggId)
			if ok then
				table.insert(hatched, pet)
			end
		end
		table.sort(hatched, function(a, b)
			return Config.Pets[a.kind].Rarity > Config.Pets[b.kind].Rarity
		end)
		return #hatched > 0, hatched
	end
	Remotes.EquipPet.OnServerInvoke = equip
	Remotes.EvolvePet.OnServerInvoke = evolve
	Remotes.ReleasePet.OnServerInvoke = release
	Remotes.GetPets.OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		if not profile then
			return {}, nil, {}, {}, 1
		end
		return profile.Pets or {}, profile.EquippedPet, teamIds(profile, PetService.SlotsOf(player)), indexOf(profile),
			PetService.SlotsOf(player)
	end
	table.insert(DataService.OnLoaded, function(player)
		-- what the equipped pet dug up while its owner was away (Config.ComeBack)
		local profile = DataService.Get(player)
		local pet = PetService.EquippedPet(player)
		local cb = Config.ComeBack
		if profile and pet and Config.Pets[pet.kind] and (profile.LastSeen or 0) > 0 then
			local hours = math.min((os.time() - profile.LastSeen) / 3600, cb.AwayMaxHours)
			if hours * 60 >= cb.AwayMinMinutes then
				local info = Config.Pets[pet.kind]
				local gold = math.floor(hours * (cb.AwayGoldPerHour[info.Rarity] or cb.AwayGoldPerHour[1])
					* (1 + 0.1 * ((pet.level or 1) - 1)) * (pet.evolved and 2 or 1) + 0.5)
				profile.LastSeen = os.time() -- counted once, also when this server keeps running
				DataService.AddGold(player, gold)
				task.delay(6, function() -- after the loading screen
					if player.Parent then
						Remotes.Notify:FireClient(player, string.format("Welcome back! %s dug up %d gold while you were away",
							info.Name, gold), info.Color)
					end
				end)
			end
		end
		player:GetAttributeChangedSignal("EquippedPetSkin"):Connect(function()
			refreshFollower(player)
		end)
		-- a new team slot may open with a hero level
		local slotsBefore = PetService.SlotsOf(player)
		player:GetAttributeChangedSignal("HeroLevel"):Connect(function()
			local slotsNow = PetService.SlotsOf(player)
			if slotsNow ~= slotsBefore then
				if slotsNow > slotsBefore then
					Remotes.Notify:FireClient(player, "Pet team slot " .. slotsNow .. " unlocked! Equip another pet",
						Color3.fromRGB(140, 255, 160))
				end
				slotsBefore = slotsNow
				refreshFollower(player)
				PetService.OnPetChanged(player)
				send(player)
			end
		end)
		refreshFollower(player)
		send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, f in followers[player] or {} do
			f.model:Destroy()
		end
		followers[player] = nil
	end)
end

return PetService
