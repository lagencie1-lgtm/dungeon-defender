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
	State.AddGold(stats.Gold)
	State.Set("Kills", (State.Get("Kills") or 0) + 1)
	Effects.Text(enemy.position + Vector3.new(0, stats.Size + 2, 0), "+" .. stats.Gold, Color3.fromRGB(170, 150, 255))
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
	local health = math.max(0, State.Get("PortalHealth") - enemy.stats.Damage)
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
	local reward = math.floor((cleared * Config.GemsPerWave + (won and Config.GemsForWin or 0)) * diff.Gems * mapInfo.Gems + 0.5)
	ItemService.CollectAllPlayers()
	for _, player in Players:GetPlayers() do
		DataService.AddGems(player, reward)
		-- gold (kept between games) for the upgrades at the blacksmith
		local goldFind = (player:GetAttribute("BonusGoldFind") or 0) / 100
		local gold = math.floor((cleared * Config.GoldPerWave + (State.Get("Kills") or 0) * Config.GoldPerKill)
			* diff.Gems * mapInfo.Gems * (1 + goldFind))
		DataService.AddGold(player, gold)
		player:SetAttribute("LastGold", gold)
		DataService.RecordGame(player, cleared, won, State.Get("Kills") or 0)
		player:SetAttribute("LastReward", reward)
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
	State.Set("MaxWave", #waves)
	for wave = 1, #waves do
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
		State.Set("Wave", wave)
		State.Set("WaveTitle", waveInfo.Title or "")
		State.Set("State", "Wave")
		local extraPlayers = math.max(0, #Players:GetPlayers() - 1)
		local mapInfo = Config.Maps[State.Get("Map") or ""] or Config.Maps.CursedForest
		local healthMultiplier = (1 + (wave - 1) * Config.WaveHealthGrowth) * difficulty().Health
			* (1 + extraPlayers * Config.HealthPerExtraPlayer) * mapInfo.Health
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
				EnemyService.Spawn(group.Enemy, healthMultiplier)
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
		ItemService.CollectAllPlayers()
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
	ItemService.CollectAllPlayers()
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
	for i = 1, math.min(6, #list) do
		local e = list[i]
		table.insert(lines, i .. ". " .. e.name .. "  ·  " .. e.wins .. " wins  ·  best wave " .. e.best)
	end
	MapBuilder.UpdateTrophies(lines)
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
	State.Set("PortalHealth", Config.PortalHealth)
	State.Set("MaxPortalHealth", Config.PortalHealth)
	State.Set("Wave", 0)
	State.Set("WaveTitle", "")
	State.Set("MaxWave", #Config.Waves)
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
	end
	notify("To the " .. Config.Maps[mapId].Name .. "! Build your defenders.", Color3.fromRGB(200, 200, 255))
	task.spawn(runGame, runId)
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

	Remotes.StartWave.OnServerEvent:Connect(function()
		if State.Get("State") == "Break" then
			skipBreak = true
		end
	end)
	Remotes.SetSpeed.OnServerEvent:Connect(function(_player, speed)
		if table.find(Config.Speeds, speed) and (State.Get("State") == "Break" or State.Get("State") == "Wave") then
			Clock.scale = speed
			State.Set("Speed", speed)
		end
	end)
	-- difficulty and map can only be changed before the first wave
	Remotes.PickDifficulty.OnServerEvent:Connect(function(player, id)
		local diff = Config.FindById(Config.Difficulties, id)
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

	State.Set("Difficulty", "Normal")
	State.Set("Map", "CursedForest")
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
