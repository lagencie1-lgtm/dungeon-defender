-- Runs a game: breaks, waves, gold, the portal's health, winning and losing,
-- difficulty, game speed and the gems you earn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Memes = require(ReplicatedStorage.Shared.Memes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Clock = require(script.Parent.Clock)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local HeroService = require(script.Parent.HeroService)
local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)
local ItemService = require(script.Parent.ItemService)
local Effects = require(script.Parent.Effects)
local MapBuilder = require(script.Parent.MapBuilder)
local QuestService = require(script.Parent.QuestService)
local PetService = require(script.Parent.PetService)
local SeasonService = require(script.Parent.SeasonService)
local Store = require(ReplicatedStorage.Shared.Store)
local DataStoreService = game:GetService("DataStoreService")

-- the global Endless leaderboard (only works in the real game or with API access on)
local endlessBoard = nil
pcall(function()
	endlessBoard = DataStoreService:GetOrderedDataStore("EndlessBestWave_v1")
end)
local globalTop = {} -- lines for the trophy wall
local Sound = require(script.Parent.Sound)

local GameService = {}

local runId = 0 -- goes up on every new game, so an old game's loop knows to stop
local skipBreak = false

local function notify(text, color)
	Remotes.Notify:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function isOver()
	local s = State.Get("State")
	return s == "Won" or s == "Lost"
end

local function difficulty()
	return Config.FindById(Config.Difficulties, State.Get("Difficulty")) or Config.Difficulties[2]
end

local function onKilled(enemy, player)
	local stats = enemy.stats
	local event = Config.WeeklyEvent()
	State.AddGold(math.floor(stats.Gold * (event.Mana or 1) + 0.5))
	State.Set("Kills", (State.Get("Kills") or 0) + 1)
	-- 6A: the payout shows once, in the mana counter; only big ones float up in the world
	if stats.Gold >= 10 then
		Effects.Text(enemy.position + Vector3.new(0, stats.Size + 2, 0), "+" .. stats.Gold, Color3.fromRGB(170, 150, 255))
	end
	if player then
		HeroService.AddXp(player, stats.Xp)
	else
		-- defenders' kills give every hero a little xp too
		for _, p in Players:GetPlayers() do
			HeroService.AddXp(p, math.max(1, math.floor(stats.Xp / 2)))
		end
	end
	if stats.Gems and math.random() < (stats.GemChance or 0) then
		LootService.DropGems(enemy.position, math.max(1, math.floor(stats.Gems * difficulty().Gems + 0.5)))
	end
	ItemService.OnEnemyKilled(enemy, State.Get("Difficulty"), State.Get("Wave") or 1)
	QuestService.AddAll("Kills", 1)
	PetService.AddXpAll(1)
	if stats.Boss then
		QuestService.AddAll("Boss", 1)
	elseif stats.Loot then
		QuestService.AddAll("LootGoblin", 1)
	end
	if stats.Boss then
		notify("The " .. stats.DisplayName .. " has been absolutely bonked!", Color3.fromRGB(255, 220, 90))
		ItemService.VictoryChest(State.Get("Difficulty"))
	elseif stats.Loot then
		notify("Loot Goblin caught! Grab the gems!", Color3.fromRGB(120, 230, 255))
	end
end

local function onLeaked(enemy)
	if isOver() then
		return
	end
	if enemy.stats.Loot then
		notify("The Loot Goblin escaped with the gems...", Color3.fromRGB(255, 200, 80))
		return
	end
	-- Easy is for fun: the portal only takes half damage
	local damage = enemy.stats.Damage * ((State.Get("Difficulty") == "Easy") and 0.5 or 1)
	local health = math.max(0, State.Get("PortalHealth") - math.ceil(damage))
	State.Set("PortalHealth", health)
	local portal = workspace.Map:FindFirstChild("Portal")
	if portal then
		Effects.Burst(portal.Position, 10, Color3.fromRGB(255, 60, 60), 0.4)
		Sound.Play("PortalHit", portal.Position)
	end
	if health <= 0 then
		GameService.EndGame(false)
	end
end

-- hand out gems for the game that just ended and save stats
function GameService.EndGame(won)
	if isOver() then
		return
	end
	State.Set("State", won and "Won" or "Lost")
	State.Set("Speed", 1)
	Clock.scale = 1
	EnemyService.Clear()
	local wave = State.Get("Wave") or 0
	local cleared = won and wave or math.max(0, wave - 1)
	local diff = difficulty()
	local mapInfo = Config.Maps[State.Get("Map") or ""] or Config.Maps.CursedForest
	local reward = math.floor((cleared * Config.GemsPerWave + (won and Config.GemsForWin or 0)) * diff.Gems * mapInfo.Gems
		* (Config.WeeklyEvent().Gems or 1) + 0.5)
	for _, player in Players:GetPlayers() do
		DataService.AddGems(player, reward)
		-- gold (kept between games) for the upgrades at the blacksmith
		local goldFind = (player:GetAttribute("BonusGoldFind") or 0) / 100
		local gold = math.floor((cleared * Config.GoldPerWave + (State.Get("Kills") or 0) * Config.GoldPerKill)
			* (diff.Gold or 1) * mapInfo.Gems * (1 + goldFind) * (1 + (player:GetAttribute("Rebirths") or 0) * Config.RebirthBonus / 100)
			* (((player:GetAttribute("BoostGoldUntil") or 0) > os.time()) and 2 or 1))
		DataService.AddGold(player, gold)
		player:SetAttribute("LastGold", gold)
		DataService.RecordGame(player, cleared, won, State.Get("Kills") or 0)
		player:SetAttribute("LastReward", reward)
	end
	local mode = State.Get("Mode") or "Campaign"
	local modeInfo = Config.FindById(Config.Modes, mode)
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		SeasonService.LogRunEnded(player, State.Get("Map") or "", mode, cleared, won)
		if won then
			SeasonService.AddXp(player, Store.Season.XpPerWin)
			SeasonService.Funnel(player, 6)
			QuestService.Add(player, "Win", 1)
			if diff.Id == "Hard" or diff.Id == "Insane" then
				QuestService.Add(player, "WinHard", 1)
			end
		end
		if profile and won and mode == "Campaign" then
			profile.Cleared = profile.Cleared or {}
			local mapId = State.Get("Map") or "CursedForest"
			profile.Cleared[mapId] = profile.Cleared[mapId] or {}
			if not profile.Cleared[mapId][diff.Id] then
				profile.Cleared[mapId][diff.Id] = true
				for _, d in Config.Difficulties do
					if d.Unlock == diff.Id then
						Remotes.Notify:FireClient(player, d.Name .. " unlocked on " .. mapInfo.Name .. "!", d.Color)
					end
				end
			end
			DataService.Publish(player)
		end
		if profile and mode == "Endless" then
			if cleared > (profile.BestEndless or 0) then
				profile.BestEndless = cleared
				Remotes.Notify:FireClient(player, "New Endless record: wave " .. cleared .. "!", Color3.fromRGB(255, 220, 90))
			end
			player:SetAttribute("BestEndless", profile.BestEndless)
			task.spawn(function()
				pcall(function()
					endlessBoard:UpdateAsync(tostring(player.UserId), function(old)
						return math.max(old or 0, cleared)
					end)
				end)
			end)
		end
		-- Boss Rush win: a big chest every time
		if profile and won and modeInfo and modeInfo.BossRush then
			ItemService.GiveReward(player, 4, 26 + mapInfo.ItemLevel)
		end
		-- first clear of a challenge on this map: gems and an Epic or better item
		if profile and won and modeInfo and modeInfo.Challenge then
			profile.ChallengesDone = profile.ChallengesDone or {}
			local key = (State.Get("Map") or "") .. "_" .. mode
			if not profile.ChallengesDone[key] then
				profile.ChallengesDone[key] = true
				DataService.AddGems(player, Config.ChallengeReward.Gems)
				ItemService.GiveReward(player, Config.ChallengeReward.MinRarity, 24 + mapInfo.ItemLevel)
				Remotes.Notify:FireClient(player, "Challenge beaten for the first time! +" .. Config.ChallengeReward.Gems .. " gems",
					Color3.fromRGB(255, 220, 90))
			end
		end
	end
	GameService.UpdateTrophies()
	State.Set("EndMeme", Memes.Pick(won and Memes.Win or Memes.Lose))
	if won then
		notify("Victory! The " .. mapInfo.Name .. " is safe! +" .. reward .. " gems", Color3.fromRGB(255, 220, 90))
	else
		notify("The portal has fallen... +" .. reward .. " gems for trying", Color3.fromRGB(255, 90, 90))
	end
end

local function runGame(myRun)
	local waves = Config.Waves
	local modeNow = Config.FindById(Config.Modes, State.Get("Mode") or "Campaign")
	if modeNow and modeNow.Waves then
		waves = modeNow.Waves -- Boss Rush has its own waves
	end
	local endless = State.Get("Mode") == "Endless"
	State.Set("MaxWave", endless and 0 or #waves)
	local wave = 0
	while true do
		wave += 1
		if wave > #waves and not endless then
			break
		end
		-- break before the wave: build and upgrade defenders
		State.Set("State", "Break")
		skipBreak = false
		local breakTime = wave == 1 and Config.FirstBreakTime or Config.BreakTime
		local endsAt = Clock.now + breakTime
		while Clock.now < endsAt and not skipBreak do
			State.Set("NextWaveIn", math.ceil(endsAt - Clock.now))
			task.wait(0.2)
			if myRun ~= runId then
				return
			end
		end

		-- the wave itself
		local waveInfo = waves[wave]
		if not waveInfo then
			-- Endless: the map's waves again, with more enemies every round
			local base = waves[(wave - 1) % #waves + 1]
			local round = (wave - 1) // #waves
			waveInfo = { Title = "Endless wave " .. wave .. ": " .. (base.Title or "") }
			for _, group in ipairs(base) do
				table.insert(waveInfo, { Enemy = group.Enemy, Gap = group.Gap / (1 + round * 0.3),
					Count = Config.Enemies[group.Enemy].Boss and group.Count or math.ceil(group.Count * (1 + round * 0.5)) })
			end
		end
		State.Set("Wave", wave)
		State.Set("WaveTitle", waveInfo.Title or "")
		State.Set("State", "Wave")
		local extraPlayers = math.max(0, #Players:GetPlayers() - 1)
		local mapInfo = Config.Maps[State.Get("Map") or ""] or Config.Maps.CursedForest
		local healthMultiplier = (1 + (wave - 1) * Config.WaveHealthGrowth) * difficulty().Health
			* (1 + extraPlayers * Config.HealthPerExtraPlayer) * mapInfo.Health * (Config.WeeklyEvent().Health or 1)
		for _, group in ipairs(waveInfo) do
			local enemyStats = Config.Enemies[group.Enemy]
			if enemyStats.Boss then
				State.Set("BossAlert", (State.Get("BossAlert") or 0) + 1)
				notify("The " .. enemyStats.DisplayName .. " is coming! Protect the portal!", Color3.fromRGB(220, 120, 255))
			elseif enemyStats.Loot then
				notify("A Loot Goblin appeared! Catch it for gems!", Color3.fromRGB(255, 210, 60))
			end
			for _ = 1, group.Count do
				if myRun ~= runId or isOver() then
					return
				end
				local spawned = EnemyService.Spawn(group.Enemy, healthMultiplier)
				spawned.speedMult = Config.WeeklyEvent().Speed or 1
				Clock.Wait(group.Gap)
			end
		end
		-- wait until every goblin of this wave is gone
		while EnemyService.Count() > 0 do
			task.wait(0.2)
			if myRun ~= runId or isOver() then
				return
			end
		end

		local bonus = Config.WaveBonusGold + wave * 10
		State.AddGold(bonus)
		QuestService.AddAll("Waves", 1)
		SeasonService.AddXpAll(Store.Season.XpPerWave)
		if wave == 1 then
			SeasonService.FunnelAll(4)
		elseif wave == 5 then
			SeasonService.FunnelAll(5)
		end
		notify("Wave " .. wave .. " cleared! +" .. bonus .. " mana", Color3.fromRGB(120, 255, 120))
	end
	GameService.EndGame(true)
end

-- clears everything from the last run
local function cleanUp()
	runId += 1
	EnemyService.Clear()
	TowerService.Clear()
	LootService.Clear()
	ItemService.LeaveBehindAll() -- loot you didn't pick up stays on the battlefield
	Clock.scale = 1
	State.Set("Speed", 1)
end

-- the trophy wall in the hub: the best players on this server
function GameService.UpdateTrophies()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, { name = player.DisplayName, best = player:GetAttribute("BestWave") or 0, wins = player:GetAttribute("Wins") or 0 })
	end
	table.sort(list, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		return a.best > b.best
	end)
	local lines = {}
	for i = 1, math.min(4, #list) do
		local e = list[i]
		table.insert(lines, i .. ". " .. e.name .. "  ·  " .. e.wins .. " wins  ·  best wave " .. e.best)
	end
	if #globalTop > 0 then
		table.insert(lines, "")
		table.insert(lines, "ENDLESS · BEST IN THE WORLD")
		for _, line in globalTop do
			table.insert(lines, line)
		end
	end
	MapBuilder.UpdateTrophies(lines)
end

-- reads the top 5 of the Endless leaderboard (in the background)
local function refreshGlobalTop()
	if not endlessBoard then
		return
	end
	pcall(function()
		local page = endlessBoard:GetSortedAsync(false, 5):GetCurrentPage()
		local lines = {}
		for i, entry in page do
			local name = entry.key
			pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
			end)
			table.insert(lines, i .. ". " .. name .. "  ·  wave " .. entry.value)
		end
		globalTop = lines
	end)
end

-- back to the hub: pick a map, a hero, upgrade gear, then start a run
function GameService.ToOutpost()
	cleanUp()
	State.Set("State", "Lobby")
	State.Set("Wave", 0)
	State.Set("WaveTitle", "")
	State.Set("EndMeme", "")
	MapBuilder.UseSpawn("Outpost")
	for _, player in Players:GetPlayers() do
		MapBuilder.Teleport(player, "Outpost")
	end
	GameService.UpdateTrophies()
end

-- a new run on the chosen map
function GameService.StartRun()
	if State.Get("State") ~= "Lobby" then
		return
	end
	cleanUp()
	local mapId = State.Get("Map") or "CursedForest"
	MapBuilder.BuildBattlefield(mapId)
	EnemyService.SetPath()
	State.Set("Gold", Config.StartGold)
	local modeInfo = Config.FindById(Config.Modes, State.Get("Mode") or "Campaign")
	local portalHealth = modeInfo and modeInfo.PortalHealth or Config.WeeklyEvent().PortalHealth or Config.PortalHealth
	State.Set("PortalHealth", portalHealth)
	State.Set("MaxPortalHealth", portalHealth)
	State.Set("Wave", 0)
	State.Set("WaveTitle", "")
	State.Set("MaxWave", State.Get("Mode") == "Endless" and 0 or (modeInfo and modeInfo.Waves and #modeInfo.Waves) or #Config.Waves)
	State.Set("Kills", 0)
	State.Set("NextWaveIn", 0)
	State.Set("EndMeme", "")
	State.Set("BuildUsed", 0)
	State.Set("BuildMax", Config.BuildLimit)
	State.Set("State", "Break")
	MapBuilder.UseSpawn("Battle")
	for _, player in Players:GetPlayers() do
		HeroService.Reset(player)
		player:SetAttribute("LastReward", 0)
		MapBuilder.Teleport(player, "Battle")
		SeasonService.Funnel(player, 2)
	end
	notify("To the " .. Config.Maps[mapId].Name .. "! " .. (modeInfo and modeInfo.Text or "Build your defenders."),
		Color3.fromRGB(200, 200, 255))
	local event = Config.WeeklyEvent()
	notify("This week: " .. event.Name .. " (" .. event.Text .. ")", Color3.fromRGB(255, 200, 120))
	task.spawn(runGame, runId)
end

-- has this player won the given difficulty on this map?
function GameService.HasCleared(player, mapId, difficultyId)
	local profile = DataService.Get(player)
	local cleared = profile and profile.Cleared and profile.Cleared[mapId or "CursedForest"]
	return cleared ~= nil and cleared[difficultyId] == true
end

local function onPrompt(player, action)
	if action == "Start" then
		GameService.StartRun()
	else
		Remotes.OpenPanel:FireClient(player, action)
	end
end

function GameService.Start()
	EnemyService.OnKilled = onKilled
	EnemyService.OnLeaked = onLeaked
	EnemyService.OnBossSlam = function(position, radius)
		HeroService.DamageArea(position, radius, 35)
		TowerService.Stun(position, radius, 2.5)
	end

	Remotes.StartWave.OnServerEvent:Connect(function()
		if State.Get("State") == "Break" then
			skipBreak = true
		end
	end)
	Remotes.SetSpeed.OnServerEvent:Connect(function(_player, speed)
		local allowed = table.find(Config.Speeds, speed) or (speed == 3 and _player:GetAttribute("PassSpeed3x"))
		if allowed and (State.Get("State") == "Break" or State.Get("State") == "Wave") then
			Clock.scale = speed
			State.Set("Speed", speed)
		end
	end)
	-- difficulty and map can only be changed before the first wave
	Remotes.PickDifficulty.OnServerEvent:Connect(function(player, id)
		local diff = Config.FindById(Config.Difficulties, id)
		if diff and diff.Unlock and not GameService.HasCleared(player, State.Get("Map"), diff.Unlock) then
			Remotes.Notify:FireClient(player, "Beat this map on " .. diff.Unlock .. " to unlock " .. diff.Name, Color3.fromRGB(255, 140, 140))
			return
		end
		if diff and (State.Get("Wave") or 0) == 0 and State.Get("Difficulty") ~= id then
			State.Set("Difficulty", id)
			notify(player.DisplayName .. " picked " .. diff.Name .. ": " .. diff.Subtitle, diff.Color)
		end
	end)
	Remotes.PickMap.OnServerEvent:Connect(function(player, mapId)
		local mapInfo = Config.Maps[mapId]
		if mapInfo and State.Get("State") == "Lobby" and State.Get("Map") ~= mapId then
			State.Set("Map", mapId)
			notify(player.DisplayName .. " picked the " .. mapInfo.Name, mapInfo.Color)
			local diff = Config.FindById(Config.Difficulties, State.Get("Difficulty"))
			if diff and diff.Unlock and not GameService.HasCleared(player, mapId, diff.Unlock) then
				State.Set("Difficulty", Config.DefaultDifficulty)
			end
		end
	end)
	Remotes.PickMode.OnServerEvent:Connect(function(player, modeId)
		local modeInfo = Config.FindById(Config.Modes, modeId)
		if modeInfo and State.Get("State") == "Lobby" and State.Get("Mode") ~= modeId then
			State.Set("Mode", modeId)
			notify(player.DisplayName .. " picked " .. modeInfo.Name, Color3.fromRGB(200, 200, 255))
		end
	end)
	Remotes.PlayAgain.OnServerEvent:Connect(function()
		if isOver() then
			GameService.ToOutpost()
		end
	end)
	Remotes.StartRun.OnServerEvent:Connect(function()
		GameService.StartRun()
	end)

	State.Set("Difficulty", Config.DefaultDifficulty)
	State.Set("Map", "CursedForest")
	State.Set("Mode", "Campaign")
	task.spawn(function()
		while true do
			refreshGlobalTop()
			GameService.UpdateTrophies()
			task.wait(120)
		end
	end)
	MapBuilder.BuildOutpost(onPrompt)
	MapBuilder.BuildBattlefield("CursedForest")
	-- new players start in the hub, or join the run that's going on
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Wait()
		task.wait(1)
		local s = State.Get("State")
		MapBuilder.Teleport(player, (s == "Lobby") and "Outpost" or "Battle")
		GameService.UpdateTrophies()
	end)
	GameService.ToOutpost()
end

return GameService
