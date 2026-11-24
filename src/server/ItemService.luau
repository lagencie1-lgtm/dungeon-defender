-- Loot! Rolls gear, drops it for each player separately (everyone gets their
-- own drops, nobody steals yours), the Victory Chest, and the backpack:
-- equip, upgrade with gold, salvage into scrap.
-- The server decides every drop, so nobody can cheat loot in.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.State)
local QuestService = require(script.Parent.QuestService)
local Telemetry = require(script.Parent.Telemetry)

local ItemService = {}

local pending = {} -- [player] = { [dropId] = { item, position } }
local PICKUP_RANGE = 10 -- a bit bigger than the client's, for lag

-- drop chances per goblin type (the boss always gives the Victory Chest)
local DROP_CHANCE = { Goblin = 0.018, Runner = 0.018, Brute = 0.09, LootGoblin = 0.6, GoblinKing = 0 }
-- item level bonus and rarity luck per difficulty
-- Easy drops much worse loot; Insane the best
local DIFF_LEVEL = { Easy = -4, Normal = 3, Hard = 9, Insane = 16 }
local DIFF_LUCK = { Easy = 0.25, Normal = 1, Hard = 1.8, Insane = 3.2 }
local DIFF_DROPS = { Easy = 0.5, Normal = 1, Hard = 1.2, Insane = 1.5, Mythic = 1.5 }
DIFF_LEVEL.Mythic, DIFF_LUCK.Mythic = DIFF_LEVEL.Insane, DIFF_LUCK.Insane

-- item level bonus and luck, with the Mythic tier on top (Config.Mythic)
local function levelBonus(difficultyId)
	local bonus = DIFF_LEVEL[difficultyId] or 0
	if difficultyId == "Mythic" then
		bonus += Config.Mythic.ItemLevel * (State.Get("Tier") or 1)
	end
	return bonus
end
local function luckOf(difficultyId)
	local luck = DIFF_LUCK[difficultyId] or 1
	if difficultyId == "Mythic" then
		luck += Config.Mythic.Luck * (State.Get("Tier") or 1)
	end
	return luck
end

local rng = Random.new()

local function pickWeighted(weights)
	local total = 0
	for _, w in weights do
		total += w
	end
	local r = rng:NextNumber() * total
	for key, w in weights do
		r -= w
		if r <= 0 then
			return key
		end
	end
	return next(weights)
end

local function rollRarity(luck, minRarity)
	local weights = {}
	for i, r in Items.Rarities do
		if i >= (minRarity or 1) then
			-- luck makes the better rarities more likely
			weights[i] = i >= 3 and r.Weight * luck or r.Weight
		end
	end
	return pickWeighted(weights)
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- makes a brand-new item
function ItemService.Roll(itemLevel, luck, minRarity, slot)
	slot = slot or pickWeighted(Items.SlotWeights)
	local rarity = rollRarity(luck or 1, minRarity)
	local r = Items.Rarities[rarity]

	-- which stats: the slot's main stat, plus random others
	local stats = {}
	local mainStat = Items.SlotMainStat[slot]
	local chosen = { mainStat }
	local others = {}
	for _, s in Items.StatOrder do
		if s ~= mainStat then
			table.insert(others, s)
		end
	end
	while #chosen < r.Stats and #others > 0 do
		table.insert(chosen, table.remove(others, rng:NextInteger(1, #others)))
	end
	for _, s in chosen do
		local info = Items.Stats[s]
		local value = (info.Base + itemLevel * info.PerLevel) * r.Mult * rng:NextNumber(0.8, 1.2)
		stats[s] = math.floor(value * 10 + 0.5) / 10
	end

	local base, name
	if slot == "Weapon" then
		base = pick(Items.WeaponTypeOrder)
		name = pick(Items.Prefixes[rarity]) .. " " .. Items.WeaponTypes[base].Name
	else
		base = pick(Items.ArmorNames[slot])
		name = pick(Items.Prefixes[rarity]) .. " " .. base
	end
	if rarity == #Items.Rarities and rng:NextNumber() < 0.5 then
		name = pick(Items.MemeNames[slot])
	end

	return {
		id = HttpService:GenerateGUID(false):sub(1, 12),
		slot = slot,
		base = base,
		rarity = rarity,
		ilvl = itemLevel,
		stats = stats,
		plus = 0,
		name = name,
		new = true,
	}
end

-------------------------------------------------------------------------------
-- backpack helpers
-------------------------------------------------------------------------------
local function findItem(profile, id)
	for i, item in profile.Items do
		if item.id == id then
			return item, i
		end
	end
	return nil, nil
end

local function equippedItems(profile)
	local result = {}
	for slot, id in profile.Gear do
		local item = findItem(profile, id)
		if item then
			result[slot] = item
		end
	end
	return result
end

-- puts gear bonuses on the player so the hero and defenders can use them
function ItemService.ApplyBonuses(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local equipped = equippedItems(profile)
	local totals = Items.Totals(equipped)
	for stat, value in totals do
		player:SetAttribute("Gear" .. stat, value)
	end
	-- Might: one number for how strong the gear is; it drives how grand the hero looks (Config.MightRanks)
	local might = Items.Might(equipped)
	player:SetAttribute("Might", might)
	player:SetAttribute("MightRank", Config.MightRankOf(might))
	local weapon = equipped.Weapon
	player:SetAttribute("WeaponType", weapon and weapon.base or "Longsword")
	player:SetAttribute("WeaponRarity", weapon and weapon.rarity or 0)
	-- what shows on the hero: "Helm:3" = a Rare helm ("" = nothing worn)
	for _, slot in { "Helmet", "Armor" } do
		local item = equipped[slot]
		player:SetAttribute("Worn" .. slot, item and (item.base .. ":" .. item.rarity) or "")
	end
	ItemService.OnGearChanged(player)
end

-- set by HeroService: adds gear and stat points together
ItemService.OnGearChanged = function(_player) end

local function sendInventory(player)
	local profile = DataService.Get(player)
	if profile then
		Remotes.Inventory:FireClient(player, profile.Items, profile.Gear)
	end
end

-- adds an item to the backpack. A full backpack salvages it into scrap.
local function addItem(player, item)
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local capacity = player:GetAttribute("PassBigBackpack") and Items.BackpackSize * 2 or Items.BackpackSize
	player:SetAttribute("BackpackSize", capacity)
	if #profile.Items >= capacity then
		profile.Scrap += Items.SalvageValue(item)
		DataService.Publish(player)
		Remotes.Notify:FireClient(player, "Backpack full! " .. item.name .. " was turned into scrap", Color3.fromRGB(255, 160, 80))
		return false
	end
	-- auto-salvage (the player's choice, Items.AutoSalvageSteps): a plain drop worse than what is worn in its slot
	local worn = profile.Gear[item.slot] and findItem(profile, profile.Gear[item.slot])
	if worn and item.rarity <= (profile.AutoSalvage or 0) and not item.boss
		and Items.Might({ item }) < Items.Might({ worn }) then
		local scrap = Items.SalvageValue(item)
		profile.Scrap += scrap
		DataService.Publish(player)
		Remotes.Notify:FireClient(player, string.format("Auto-salvaged %s (+%d scrap)", item.name, scrap), Items.Rarities[item.rarity].Color)
		return false
	end
	table.insert(profile.Items, item)
	QuestService.Add(player, "Loot", 1)
	-- nothing in that slot yet? put it on straight away
	if not profile.Gear[item.slot] then
		profile.Gear[item.slot] = item.id
		ItemService.ApplyBonuses(player)
	end
	sendInventory(player)
	return true
end

-------------------------------------------------------------------------------
-- drops in the world (each player sees only their own)
-------------------------------------------------------------------------------
local function dropFor(player, item, position)
	if player:GetAttribute("PassAutoCollect") and (player:GetAttribute("PetTeamSize") or 0) == 0 then
		-- Auto Collect pass without a pet: straight into the backpack. With pets, they fetch it (twice as fast, from
		-- the whole map: Config.PetCarryPass)
		addItem(player, item)
		Remotes.LootPicked:FireClient(player, item.id, item)
		return
	end
	pending[player] = pending[player] or {}
	local dropId = item.id
	pending[player][dropId] = { item = item, position = position }
	Remotes.LootDrop:FireClient(player, dropId, position, item.rarity, Items.DisplayName(item), item.slot)
end

-- called by the game when a goblin dies
function ItemService.OnEnemyKilled(enemy, difficultyId, wave)
	local chance = enemy.stats.DropChance or DROP_CHANCE[enemy.name] or 0
	if chance <= 0 then
		return
	end
	local map = Config.Maps[State.Get("Map") or ""]
	local level = math.max(1, wave * 2 + levelBonus(difficultyId) + (map and map.ItemLevel or 0))
	chance *= DIFF_DROPS[difficultyId] or 1
	if State.Get("Map") == Config.RiftMap() then
		chance *= Config.ComeBack.RiftDrops -- this week's Rift map
	end
	local luck = luckOf(difficultyId) * (Config.WeeklyEvent().Luck or 1)
	for _, player in Players:GetPlayers() do
		if rng:NextNumber() < chance then
			local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			dropFor(player, ItemService.Roll(level, luck), enemy.position + offset)
		end
	end
end

-- the Goblin King's chest: a guaranteed Rare or better item for everyone
function ItemService.VictoryChest(difficultyId)
	local map = Config.Maps[State.Get("Map") or ""]
	local level = 22 + levelBonus(difficultyId) + (map and map.ItemLevel or 0)
	local luck = luckOf(difficultyId) * 2
	for _, player in Players:GetPlayers() do
		local item = ItemService.Roll(level, luck, 3)
		local kept = addItem(player, item)
		Remotes.VictoryChest:FireClient(player, item, kept)
		task.spawn(DataService.Save, player)
	end
end

-------------------------------------------------------------------------------
-- a boss's own reward (Config.BossRewards): first win for sure, then a meter that fills with every kill
-------------------------------------------------------------------------------
-- the boss's unique weapon at an item level: its fixed stats, the numbers like any item of its rarity
function ItemService.RollBossItem(bossName, itemLevel)
	local reward = Config.BossRewards[bossName]
	local weapon = Items.WeaponTypes[reward.Item]
	local r = Items.Rarities[reward.Rarity]
	local stats = {}
	for _, stat in reward.Stats do
		local info = Items.Stats[stat]
		stats[stat] = math.floor((info.Base + itemLevel * info.PerLevel) * r.Mult * rng:NextNumber(0.95, 1.1) * 10 + 0.5) / 10
	end
	return {
		id = HttpService:GenerateGUID(false):sub(1, 12),
		slot = "Weapon",
		base = reward.Item,
		rarity = reward.Rarity,
		ilvl = itemLevel,
		stats = stats,
		plus = 0,
		name = weapon.Name,
		boss = bossName,
		new = true,
	}
end

local function publishMeter(player, profile)
	for bossName, reward in Config.BossRewards do
		local meter = profile.BossMeter and profile.BossMeter[bossName] or 0
		player:SetAttribute("BossMeter_" .. bossName, meter)
		player:SetAttribute("BossMeterMax_" .. bossName, reward.Meter)
		player:SetAttribute("BossFirst_" .. bossName, profile.BossFirst and profile.BossFirst[bossName] == true or false)
	end
end
ItemService.PublishBossMeters = function(player)
	local profile = DataService.Get(player)
	if profile then
		publishMeter(player, profile)
	end
end

-- every player gets this when a boss falls: the first win's reward, a step on the meter, maybe a surprise
function ItemService.BossReward(player, bossName, difficultyId)
	local reward = Config.BossRewards[bossName]
	local profile = DataService.Get(player)
	if not reward or not profile then
		return
	end
	profile.BossMeter = profile.BossMeter or {}
	profile.BossFirst = profile.BossFirst or {}
	local map = Config.Maps[State.Get("Map") or ""]
	local level = 22 + levelBonus(difficultyId) + (map and map.ItemLevel or 0)
	local give, why = false, nil
	if not profile.BossFirst[bossName] then
		profile.BossFirst[bossName] = true
		give, why = true, "first"
	else
		local meter = (profile.BossMeter[bossName] or 0) + (reward.Fill[difficultyId] or 1)
		if meter >= reward.Meter then
			meter -= reward.Meter
			give, why = true, "meter"
		elseif rng:NextNumber() < reward.DropChance then
			give, why = true, "luck"
		end
		profile.BossMeter[bossName] = meter
	end
	publishMeter(player, profile)
	if give then
		local item = ItemService.RollBossItem(bossName, level)
		local kept = addItem(player, item)
		-- shown once, with the chest's reveal (a little after the Victory Chest so the two don't overlap)
		task.delay(3.5, function()
			if player.Parent then
				Remotes.VictoryChest:FireClient(player, item, kept)
				Remotes.Notify:FireClient(player, why == "first" and ("First win: the " .. item.name .. " is yours! Try it on the training knight")
					or why == "meter" and ("Boss meter full: a new " .. item.name .. " at your level")
					or ("Lucky! Another " .. item.name), Items.Rarities[item.rarity].Color)
			end
		end)
		task.spawn(DataService.Save, player)
	end
end

-- the first win of the day: one more chest item, as good as this difficulty's Victory Chest
function ItemService.BonusChest(player, difficultyId)
	if not player.Parent then
		return
	end
	local map = Config.Maps[State.Get("Map") or ""]
	ItemService.GiveReward(player, 3, 22 + levelBonus(difficultyId) + (map and map.ItemLevel or 0))
end

-- a reward item straight into the backpack, shown like the Victory Chest
function ItemService.GiveReward(player, minRarity, itemLevel)
	local item = ItemService.Roll(itemLevel or 20, 2, minRarity)
	local kept = addItem(player, item)
	Remotes.VictoryChest:FireClient(player, item, kept)
	task.spawn(DataService.Save, player)
end

-- picks up everything still lying around (end of a wave or game, leaving)
function ItemService.CollectAll(player)
	local list = pending[player]
	if not list then
		return
	end
	local count = 0
	for dropId, drop in list do
		addItem(player, drop.item)
		Remotes.LootPicked:FireClient(player, dropId)
		count += 1
	end
	pending[player] = {}
	if count > 0 then
		Remotes.Notify:FireClient(player, count .. " dropped item" .. (count == 1 and " was" or "s were") .. " put in your backpack",
			Color3.fromRGB(200, 220, 255))
	end
end

-- end of a run: drops nobody picked up are gone
function ItemService.LeaveBehindAll()
	for _, player in Players:GetPlayers() do
		local list = pending[player]
		local count = 0
		for dropId in list or {} do
			Remotes.LootPicked:FireClient(player, dropId)
			count += 1
		end
		pending[player] = {}
		if count > 0 then
			Remotes.Notify:FireClient(player, count .. " item" .. (count == 1 and " was" or "s were") .. " left on the battlefield",
				Color3.fromRGB(255, 160, 120))
		end
	end
end

-- for pets fetching loot (PetMoves): this player's drops near a spot, up to a rarity, and taking one
function ItemService.DropsNear(player, position, radius, maxRarity)
	local found = {}
	for dropId, drop in pending[player] or {} do
		if drop.item.rarity <= maxRarity and (Vector3.new(drop.position.X - position.X, 0, drop.position.Z - position.Z)).Magnitude <= radius then
			table.insert(found, { dropId = dropId, position = drop.position, rarity = drop.item.rarity })
		end
	end
	return found
end

-- carrier: the pet model that fetched it (the drop rides on it to the hero on the screen, PetMoves)
function ItemService.TakeDrop(player, dropId, carrier)
	local list = pending[player]
	local drop = list and list[dropId]
	if not drop then
		return false
	end
	list[dropId] = nil
	addItem(player, drop.item)
	Remotes.LootPicked:FireClient(player, dropId, drop.item, carrier)
	Sound.Play("Coin", drop.position)
	return true
end

function ItemService.CollectAllPlayers()
	for _, player in Players:GetPlayers() do
		ItemService.CollectAll(player)
	end
end

local function onPickup(player, dropId)
	local list = pending[player]
	local drop = list and list[dropId]
	if not drop then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	if (flat - Vector3.new(drop.position.X, 0, drop.position.Z)).Magnitude > PICKUP_RANGE then
		return
	end
	list[dropId] = nil
	addItem(player, drop.item)
	Remotes.LootPicked:FireClient(player, dropId, drop.item)
	Sound.Play("Coin", drop.position)
end

-------------------------------------------------------------------------------
-- backpack actions from the inventory screen
-------------------------------------------------------------------------------
local function equip(player, id)
	local profile = DataService.Get(player)
	local item = profile and findItem(profile, id)
	if not item then
		return false, "Item not found"
	end
	profile.Gear[item.slot] = item.id
	item.new = nil
	ItemService.ApplyBonuses(player)
	sendInventory(player)
	Telemetry.First(player, "FirstGearEquip")
	return true
end

local function upgrade(player, id)
	local profile = DataService.Get(player)
	local item = profile and findItem(profile, id)
	if not item then
		return false, "Item not found"
	end
	local gold, scrap = Items.UpgradeCost(item)
	if not gold then
		return false, "Already +" .. Items.MaxPlus
	end
	if profile.Gold < gold then
		return false, "Not enough gold (need " .. gold .. ")"
	end
	if profile.Scrap < scrap then
		return false, "Not enough scrap (need " .. scrap .. ")"
	end
	-- upgrades never fail and never break anything
	profile.Gold -= gold
	profile.Scrap -= scrap
	item.plus = (item.plus or 0) + 1
	item.new = nil
	QuestService.Add(player, "Upgrade", 1)
	DataService.Publish(player)
	ItemService.ApplyBonuses(player)
	sendInventory(player)
	return true, item.plus
end

local function salvage(player, id)
	local profile = DataService.Get(player)
	local item, index = nil, nil
	if profile then
		item, index = findItem(profile, id)
	end
	if not item then
		return false, "Item not found"
	end
	if profile.Gear[item.slot] == item.id then
		return false, "Take it off first (equip something else)"
	end
	table.remove(profile.Items, index)
	local scrap = Items.SalvageValue(item)
	profile.Scrap += scrap
	DataService.Publish(player)
	sendInventory(player)
	return true, scrap
end

-- gear sets: "save" what is worn now into set i, "use" puts set i back on (items still in the backpack)
local function gearSet(player, action, index)
	local profile = DataService.Get(player)
	if not profile or type(index) ~= "number" or index < 1 or index > Items.GearSets or index % 1 ~= 0 then
		return false, "No such set"
	end
	profile.GearSets = profile.GearSets or {}
	if action == "save" then
		profile.GearSets[index] = table.clone(profile.Gear)
		player:SetAttribute("GearSet" .. index, true)
		return true, "Saved as set " .. index
	elseif action == "use" then
		local set = profile.GearSets[index]
		if not set then
			return false, "Set " .. index .. " is empty: save one first"
		end
		local missing = 0
		for _, slot in Items.Slots do
			local id = set[slot]
			if id == nil then
				profile.Gear[slot] = nil -- the set had nothing in this slot
			elseif findItem(profile, id) then
				profile.Gear[slot] = id
			else
				missing += 1 -- salvaged since: the slot keeps what it has
			end
		end
		ItemService.ApplyBonuses(player)
		sendInventory(player)
		return true, "Set " .. index .. " on" .. (missing > 0 and (" (" .. missing .. " piece" .. (missing == 1 and "" or "s") .. " gone)") or "")
	end
	return false, "Unknown"
end

ItemService.GearSet = gearSet
ItemService.AddForTest = function(player, item) -- (the autotest: an item arriving like any drop)
	return addItem(player, item)
end

-- auto-salvage: the next step of Items.AutoSalvageSteps
local function autoSalvage(player)
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local steps = Items.AutoSalvageSteps
	local at = table.find(steps, profile.AutoSalvage or 0) or 1
	profile.AutoSalvage = steps[at % #steps + 1]
	player:SetAttribute("AutoSalvage", profile.AutoSalvage)
	return true, profile.AutoSalvage
end

local function seen(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, item in profile.Items do
		item.new = nil
	end
end

function ItemService.Start()
	table.insert(DataService.OnLoaded, function(player, profile)
		publishMeter(player, profile)
		player:SetAttribute("AutoSalvage", profile.AutoSalvage or 0)
		for i = 1, Items.GearSets do
			player:SetAttribute("GearSet" .. i, profile.GearSets ~= nil and profile.GearSets[i] ~= nil)
		end
	end)
	Remotes.PickupLoot.OnServerEvent:Connect(onPickup)
	Remotes.EquipGear.OnServerInvoke = equip
	Remotes.GearSet.OnServerInvoke = gearSet
	Remotes.AutoSalvage.OnServerInvoke = autoSalvage
	Remotes.UpgradeGear.OnServerInvoke = upgrade
	Remotes.SalvageGear.OnServerInvoke = salvage
	Remotes.SeenGear.OnServerEvent:Connect(seen)
	Remotes.GetInventory.OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		if not profile then
			return nil, nil
		end
		return profile.Items, profile.Gear
	end

	table.insert(DataService.OnLoaded, function(player)
		ItemService.ApplyBonuses(player)
		sendInventory(player)
	end)
	-- leaving mid-run: whatever was dropped for you still goes in the backpack
	table.insert(DataService.BeforeSave, function(player)
		if player:GetAttribute("Leaving") then
			ItemService.CollectAll(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			pending[player] = nil
		end)
	end)
end

return ItemService
