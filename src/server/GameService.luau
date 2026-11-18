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
	local reward = math.floor((cleared * Config.GemsPerWave + (won and Config.GemsForWin or 0)) * diff.Gems + 0.5)
	ItemService.CollectAllPlayers()
	for _, player in Players:GetPlayers() do
		DataService.AddGems(player, reward)
		-- gold (kept between games) for the upgrades at the blacksmith
		local goldFind = (player:GetAttribute("BonusGoldFind") or 0) / 100
		local gold = math.floor((cleared * Config.GoldPerWave + (State.Get("Kills") or 0) * Config.GoldPerKill)
			* diff.Gems * (1 + goldFind))
		DataService.AddGold(player, gold)
		player:SetAttribute("LastGold", gold)
		DataService.RecordGame(player, cleared, won, State.Get("Kills") or 0)
		player:SetAttribute("LastReward", reward)
	end
	State.Set("EndMeme", Memes.Pick(won and Memes.Win or Memes.Lose))
	if won then
		notify("Victory! The Cursed Forest is safe! +" .. reward .. " gems", Color3.fromRGB(255, 220, 90))
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
		local healthMultiplier = (1 + (wave - 1) * Config.WaveHealthGrowth) * difficulty().Health
			* (1 + extraPlayers * Config.HealthPerExtraPlayer)
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

function GameService.NewGame()
	runId += 1
	EnemyService.Clear()
	TowerService.Clear()
	LootService.Clear()
	Clock.scale = 1
	State.Set("Gold", Config.StartGold)
	State.Set("PortalHealth", Config.PortalHealth)
	State.Set("MaxPortalHealth", Config.PortalHealth)
	State.Set("Wave", 0)
	State.Set("WaveTitle", "")
	State.Set("MaxWave", #Config.Waves)
	State.Set("Kills", 0)
	State.Set("NextWaveIn", 0)
	State.Set("Speed", 1)
	State.Set("EndMeme", "")
	if not State.Get("Difficulty") then
		State.Set("Difficulty", "Normal")
	end
	for _, player in Players:GetPlayers() do
		HeroService.Reset(player)
		player:SetAttribute("LastReward", 0)
	end
	task.spawn(runGame, runId)
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
		if table.find(Config.Speeds, speed) and not isOver() then
			Clock.scale = speed
			State.Set("Speed", speed)
		end
	end)
	-- difficulty can only be changed before the first wave
	Remotes.PickDifficulty.OnServerEvent:Connect(function(player, id)
		local diff = Config.FindById(Config.Difficulties, id)
		if diff and (State.Get("Wave") or 0) == 0 and State.Get("Difficulty") ~= id then
			State.Set("Difficulty", id)
			notify(player.DisplayName .. " picked " .. diff.Name .. ": " .. diff.Subtitle, diff.Color)
		end
	end)
	Remotes.PlayAgain.OnServerEvent:Connect(function()
		if isOver() then
			GameService.NewGame()
			notify("New game! Build your defenders.", Color3.fromRGB(200, 200, 255))
		end
	end)

	GameService.NewGame()
end

return GameService
