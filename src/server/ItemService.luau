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

local ItemService = {}

local pending = {} -- [player] = { [dropId] = { item, position } }
local PICKUP_RANGE = 14 -- a bit bigger than the client's, for lag

-- drop chances per goblin type (the boss always gives the Victory Chest)
local DROP_CHANCE = { Goblin = 0.018, Runner = 0.018, Brute = 0.09, LootGoblin = 0.6, GoblinKing = 0 }
-- item level bonus and rarity luck per difficulty
local DIFF_LEVEL = { Easy = 0, Normal = 3, Hard = 8 }
local DIFF_LUCK = { Easy = 0.6, Normal = 1, Hard = 1.8 }

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
	local weapon = equipped.Weapon
	player:SetAttribute("WeaponType", weapon and weapon.base or "Longsword")
	player:SetAttribute("WeaponRarity", weapon and weapon.rarity or 0)
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
	if #profile.Items >= Items.BackpackSize then
		profile.Scrap += Items.SalvageValue(item)
		DataService.Publish(player)
		Remotes.Notify:FireClient(player, "Backpack full! " .. item.name .. " was turned into scrap", Color3.fromRGB(255, 160, 80))
		return false
	end
	table.insert(profile.Items, item)
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
	pending[player] = pending[player] or {}
	local dropId = item.id
	pending[player][dropId] = { item = item, position = position }
	Remotes.LootDrop:FireClient(player, dropId, position, item.rarity, Items.DisplayName(item), item.slot)
end

-- called by the game when a goblin dies
function ItemService.OnEnemyKilled(enemy, difficultyId, wave)
	local chance = DROP_CHANCE[enemy.name] or 0
	if chance <= 0 then
		return
	end
	local level = wave * 2 + (DIFF_LEVEL[difficultyId] or 0)
	local luck = DIFF_LUCK[difficultyId] or 1
	for _, player in Players:GetPlayers() do
		if rng:NextNumber() < chance then
			local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			dropFor(player, ItemService.Roll(level, luck), enemy.position + offset)
		end
	end
end

-- the Goblin King's chest: a guaranteed Rare or better item for everyone
function ItemService.VictoryChest(difficultyId)
	local level = 22 + (DIFF_LEVEL[difficultyId] or 0)
	local luck = (DIFF_LUCK[difficultyId] or 1) * 2
	for _, player in Players:GetPlayers() do
		local item = ItemService.Roll(level, luck, 3)
		local kept = addItem(player, item)
		Remotes.VictoryChest:FireClient(player, item, kept)
		task.spawn(DataService.Save, player)
	end
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
	Remotes.PickupLoot.OnServerEvent:Connect(onPickup)
	Remotes.EquipGear.OnServerInvoke = equip
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
