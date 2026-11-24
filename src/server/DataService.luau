-- Saves each player's progress between games: gems, wins, best wave,
-- what they bought in the shop and their daily reward streak.
-- In Studio saving only works after: Game Settings > Security >
-- "Enable Studio Access to API Services" (the game must be published first).
-- Without it the game still works, it just forgets everything when you stop.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GearLooks = require(ReplicatedStorage.Shared.GearLooks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

local store = nil
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore("RealmGuardians_v1")
end)

local profiles = {} -- [player] = profile table

local equippedFields = { Titles = "Title" }
for _, slot in GearLooks.Slots do
	equippedFields[slot.Id] = slot.Field
end

local function defaultProfile()
	return {
		Gems = 0,
		Wins = 0,
		BestWave = 0,
		GamesPlayed = 0,
		TotalKills = 0,
		Owned = { Swords = { Classic = true }, Titles = { None = true }, Towers = {} },
		Equipped = { Sword = "Classic", Title = "None" },
		DailyLast = 0,
		DailyStreak = 0,
		Gold = 0, -- earned only by playing, never bought
		Scrap = 0, -- from salvaging gear
		Items = {}, -- the backpack: a list of items (see shared/Items)
		Gear = {}, -- [slot] = id of the equipped item
		Heroes = {}, -- [heroId] = { Level, Xp, Points = { Power, Vitality, Command, Engineering } }
		SelectedHero = "Swordmaster",
	}
end

-- fill in anything an older save is missing
local function fixUp(data)
	local fresh = defaultProfile()
	for k, v in fresh do
		if data[k] == nil then
			data[k] = v
		end
	end
	if type(data.Gear) ~= "table" then
		data.Gear = {}
	end
	if type(data.Heroes) ~= "table" then
		data.Heroes = {}
	end
	if type(data.Owned) ~= "table" then
		data.Owned = fresh.Owned
	end
	for k, v in fresh.Owned do
		if type(data.Owned[k]) ~= "table" then
			data.Owned[k] = v
		end
	end
	if type(data.Equipped) ~= "table" then
		data.Equipped = fresh.Equipped
	end
	for _, slot in GearLooks.Slots do
		if type(data.Owned[slot.Id]) ~= "table" then
			data.Owned[slot.Id] = {}
		end
		local owned = data.Owned[slot.Id]
		owned[slot.Default] = true
		for _, look in GearLooks.Items[slot.Id] do
			if look.Free then
				owned[look.Id] = true
			end
		end
		if not GearLooks.Find(slot.Id, data.Equipped[slot.Field])
			or owned[data.Equipped[slot.Field]] ~= true then
			data.Equipped[slot.Field] = slot.Default
		end
	end
	return data
end

-- copy the profile onto the player so their screen can show it
local function publish(player)
	local p = profiles[player]
	if not p then
		return
	end
	player:SetAttribute("Gems", p.Gems)
	player:SetAttribute("Wins", p.Wins)
	player:SetAttribute("BestWave", p.BestWave)
	player:SetAttribute("Owned", HttpService:JSONEncode(p.Owned))
	for _, slot in GearLooks.Slots do
		player:SetAttribute("Equipped" .. slot.Field, p.Equipped[slot.Field])
	end
	player:SetAttribute("EquippedTitle", p.Equipped.Title)
	player:SetAttribute("DailyStreak", p.DailyStreak)
	player:SetAttribute("DailyNextAt", p.DailyLast + Config.DailyCooldownHours * 3600)
	player:SetAttribute("Gold", p.Gold)
	player:SetAttribute("Scrap", p.Scrap)
	player:SetAttribute("BestEndless", p.BestEndless or 0)
	player:SetAttribute("MythicBest", p.MythicBest or 0)
	player:SetAttribute("FirstWinReady", p.FirstWinDay ~= Config.Today())
	player:SetAttribute("Cleared", HttpService:JSONEncode(p.Cleared or {}))
	player:SetAttribute("TutorialDone", p.TutorialDone == true or (p.GamesPlayed or 0) > 0)

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Gems.Value = p.Gems
		stats.Wins.Value = p.Wins
		stats["Best Wave"].Value = p.BestWave
	end
end

local function makeLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- this exact name shows the numbers in the player list
	for _, name in { "Gems", "Wins", "Best Wave" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player
end

local function load(player)
	local data = nil
	if storeOk and store then
		local ok, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			player:SetAttribute("SavesOff", true)
		end
	else
		player:SetAttribute("SavesOff", true)
	end
	profiles[player] = fixUp(type(data) == "table" and data or defaultProfile())
	makeLeaderstats(player)
	publish(player)
	for _, callback in DataService.OnLoaded do
		task.spawn(callback, player, profiles[player])
	end
	if player:GetAttribute("SavesOff") then
		task.delay(4, function()
			Remotes.Notify:FireClient(player, "Saving is off in Studio (turn on API access to save gems)", Color3.fromRGB(200, 200, 200))
		end)
	end
end

local function save(player)
	local p = profiles[player]
	if not p or player:GetAttribute("SaveLocked") then
		return -- (locked: the save was just reset, nothing may write the old progress back)
	end
	for _, callback in DataService.BeforeSave do
		pcall(callback, player, p)
	end
	if player:GetAttribute("SavesOff") or not store then
		return
	end
	pcall(function()
		store:SetAsync("player_" .. player.UserId, p)
	end)
end

DataService.OnLoaded = {} -- functions called with (player, profile) once a profile is loaded
DataService.BeforeSave = {} -- functions called with (player, profile) just before saving
-- when the player was last here (for what their pet dug up while they were away, PetService)
table.insert(DataService.BeforeSave, function(_player, profile)
	profile.LastSeen = os.time()
end)

function DataService.Publish(player)
	publish(player)
end

function DataService.Save(player)
	save(player)
end

-- saves right now and says if it worked (used before confirming a Robux purchase)
function DataService.SaveNow(player)
	local p = profiles[player]
	if not p or player:GetAttribute("SavesOff") or player:GetAttribute("SaveLocked") or not store then
		return false
	end
	local ok = pcall(function()
		store:SetAsync("player_" .. player.UserId, p)
	end)
	return ok
end

function DataService.AddGold(player, amount)
	local p = profiles[player]
	if not p or amount <= 0 then
		return
	end
	p.Gold += math.floor(amount)
	publish(player)
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.AddGems(player, amount)
	local p = profiles[player]
	if not p or amount <= 0 then
		return
	end
	p.Gems += amount
	publish(player)
end

function DataService.Owns(player, kind, id)
	local p = profiles[player]
	return p ~= nil and p.Owned[kind] ~= nil and p.Owned[kind][id] == true
end

-- called by the game when it ends
function DataService.RecordGame(player, waveReached, won, kills)
	local p = profiles[player]
	if not p then
		return
	end
	p.GamesPlayed += 1
	p.TotalKills += kills
	p.BestWave = math.max(p.BestWave, waveReached)
	if won then
		p.Wins += 1
	end
	publish(player)
	task.spawn(save, player)
end

local function findItem(kind, id)
	if GearLooks.Items[kind] then
		local item = GearLooks.Find(kind, id)
		return item, item and item.Price
	elseif kind == "Titles" then
		local item = Config.FindById(Config.Titles, id)
		return item, item and item.Price
	elseif kind == "Towers" then
		local item = Config.Towers[id]
		return item, item and item.UnlockGems
	end
	return nil, nil
end

local function buy(player, kind, id)
	if type(kind) ~= "string" or type(id) ~= "string" then
		return false, "Unknown item"
	end
	local p = profiles[player]
	local item, price = findItem(kind, id)
	if not p or not item or not price then
		return false, "Unknown item"
	end
	if p.Owned[kind][id] then
		return false, "You already own this"
	end
	if item.RebirthOnly then
		return false, "This one is a Rebirth reward"
	end
	if item.SeasonOnly then
		return false, "This one is a Season reward"
	end
	if p.Gems < price then
		return false, "Not enough gems (need " .. price .. ")"
	end
	p.Gems -= price
	p.Owned[kind][id] = true
	local field = equippedFields[kind]
	if field then
		p.Equipped[field] = id
	end
	publish(player)
	task.spawn(save, player)
	return true
end

local function equip(player, kind, id)
	if type(kind) ~= "string" or type(id) ~= "string" then
		return false, "Unknown item"
	end
	local p = profiles[player]
	local field = equippedFields[kind]
	local item = findItem(kind, id)
	if not p or not item or not p.Owned[kind] or p.Owned[kind][id] ~= true then
		return false, "You don't own this yet"
	end
	if not field then
		return false, "Can't equip that"
	end
	p.Equipped[field] = id
	publish(player)
	return true
end

-- "Start over" for the game's owner only (Lemp 2026-11-19: reset my own save from the phone). Typed in the
-- Codes box: RESETMYSAVE, then once more within a minute to confirm. Deletes the whole save (and the Endless
-- leaderboard entry) and sends the owner out, so the next join starts like a brand-new player. For every other
-- player the code simply doesn't exist. Robux game passes come back by themselves; bought gems do not.
local resetAsked = {} -- [player] = when they typed it the first time
local function ownerReset(player)
	local isOwner = game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
	if not isOwner and not game:GetService("RunService"):IsStudio() then
		return false, "That code doesn't exist (yet)"
	end
	local asked = resetAsked[player]
	if not asked or os.clock() - asked > 60 then
		resetAsked[player] = os.clock()
		return false, "This DELETES all your progress. Type the code again within 1 minute to confirm"
	end
	resetAsked[player] = nil
	player:SetAttribute("SaveLocked", true)
	local ok = true
	if storeOk and store and not player:GetAttribute("SavesOff") then
		ok = pcall(function()
			store:RemoveAsync("player_" .. player.UserId)
		end)
		pcall(function()
			DataStoreService:GetOrderedDataStore("EndlessBestWave_v1"):RemoveAsync(tostring(player.UserId))
		end)
	end
	if not ok then
		player:SetAttribute("SaveLocked", nil)
		return false, "Couldn't reach the save right now. Try again in a moment"
	end
	task.delay(2, function()
		if player.Parent then
			player:Kick("Your save was reset. Join again to start fresh.")
		end
	end)
	return true, "Save reset. Join again to start fresh"
end

local function redeemCode(player, text)
	local p = profiles[player]
	if not p or type(text) ~= "string" then
		return false, "Still loading"
	end
	local code = string.upper((text:gsub("%s", "")))
	if code == "RESETMYSAVE" then
		return ownerReset(player)
	end
	local info = Config.Codes[code]
	if not info then
		return false, "That code doesn't exist (yet)"
	end
	p.UsedCodes = p.UsedCodes or {}
	if p.UsedCodes[code] then
		return false, "You already used this code"
	end
	p.UsedCodes[code] = true
	p.Gems += info.Gems or 0
	p.Gold += info.Gold or 0
	publish(player)
	task.spawn(save, player)
	return true, info.Text
end

local function claimDaily(player)
	local p = profiles[player]
	if not p then
		return false, "Still loading"
	end
	local now = os.time()
	if now < p.DailyLast + Config.DailyCooldownHours * 3600 then
		return false, "Come back later for your next reward"
	end
	if now > p.DailyLast + Config.DailyStreakHours * 3600 then
		p.DailyStreak = 0 -- missed a day, streak starts over
	end
	p.DailyStreak += 1
	local reward = Config.DailyRewards[math.min(p.DailyStreak, #Config.DailyRewards)]
	if player:GetAttribute("PassVIP") then
		reward = math.floor(reward * 1.5) -- VIP bonus
	end
	p.Gems += reward
	local gold = Config.DailyGold[math.min(p.DailyStreak, #Config.DailyRewards)] or 0
	p.Gold += gold
	p.DailyLast = now
	publish(player)
	task.spawn(save, player)
	return true, reward, gold
end

function DataService.Start()
	Remotes.BuyItem.OnServerInvoke = buy
	Remotes.EquipItem.OnServerInvoke = equip
	Remotes.ClaimDaily.OnServerInvoke = claimDaily
	Remotes.RedeemCode.OnServerInvoke = redeemCode
	Remotes.FinishTutorial.OnServerEvent:Connect(function(player)
		local p = profiles[player]
		if p then
			p.TutorialDone = true
			player:SetAttribute("TutorialDone", true)
		end
	end)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("Leaving", true)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
	-- save everyone every minute, just in case
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)
end

return DataService
