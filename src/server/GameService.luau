-- Runs a game: breaks, waves, gold, the portal's health, winning and losing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local HeroService = require(script.Parent.HeroService)
local Effects = require(script.Parent.Effects)

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

local function onKilled(enemy, player)
	local stats = enemy.stats
	State.AddGold(stats.Gold)
	State.Set("Kills", (State.Get("Kills") or 0) + 1)
	Effects.Text(enemy.position + Vector3.new(0, stats.Size + 2, 0), "+" .. stats.Gold, Color3.fromRGB(255, 215, 0))
	if player then
		HeroService.AddXp(player, stats.Xp)
	else
		-- defenders' kills give every hero a little xp too
		for _, p in Players:GetPlayers() do
			HeroService.AddXp(p, math.max(1, math.floor(stats.Xp / 2)))
		end
	end
	if stats.Boss then
		notify("The " .. stats.DisplayName .. " has fallen!", Color3.fromRGB(255, 220, 90))
	end
end

local function onLeaked(enemy)
	if isOver() then
		return
	end
	local health = math.max(0, State.Get("PortalHealth") - enemy.stats.Damage)
	State.Set("PortalHealth", health)
	local portal = workspace.Map:FindFirstChild("Portal")
	if portal then
		Effects.Burst(portal.Position, 10, Color3.fromRGB(255, 60, 60), 0.4)
	end
	if health <= 0 then
		State.Set("State", "Lost")
		EnemyService.Clear()
		notify("The portal has fallen... Press Play again to retry.", Color3.fromRGB(255, 90, 90))
	end
end

local function runGame(myRun)
	local waves = Config.Waves
	State.Set("MaxWave", #waves)
	for wave = 1, #waves do
		-- break before the wave: build and upgrade defenders
		State.Set("State", "Break")
		skipBreak = false
		local breakTime = wave == 1 and Config.BreakTime + 10 or Config.BreakTime
		local endsAt = os.clock() + breakTime
		while os.clock() < endsAt and not skipBreak do
			State.Set("NextWaveIn", math.ceil(endsAt - os.clock()))
			task.wait(0.25)
			if myRun ~= runId then
				return
			end
		end

		-- the wave itself
		State.Set("Wave", wave)
		State.Set("State", "Wave")
		local healthMultiplier = 1 + (wave - 1) * Config.WaveHealthGrowth
		notify("Wave " .. wave .. " is coming!", Color3.fromRGB(255, 180, 80))
		for _, group in waves[wave] do
			local enemyStats = Config.Enemies[group.Enemy]
			if enemyStats.Boss then
				notify("The " .. enemyStats.DisplayName .. " is coming! Protect the portal!", Color3.fromRGB(220, 120, 255))
			end
			for _ = 1, group.Count do
				if myRun ~= runId or isOver() then
					return
				end
				EnemyService.Spawn(group.Enemy, healthMultiplier)
				task.wait(group.Gap)
			end
		end
		-- wait until every goblin of this wave is gone
		while EnemyService.Count() > 0 do
			task.wait(0.25)
			if myRun ~= runId or isOver() then
				return
			end
		end

		local bonus = Config.WaveBonusGold + wave * 10
		State.AddGold(bonus)
		notify("Wave " .. wave .. " cleared! +" .. bonus .. " gold", Color3.fromRGB(120, 255, 120))
	end
	State.Set("State", "Won")
	notify("Victory! The Cursed Forest is safe!", Color3.fromRGB(255, 220, 90))
end

function GameService.NewGame()
	runId += 1
	EnemyService.Clear()
	TowerService.Clear()
	State.Set("Gold", Config.StartGold)
	State.Set("PortalHealth", Config.PortalHealth)
	State.Set("MaxPortalHealth", Config.PortalHealth)
	State.Set("Wave", 0)
	State.Set("MaxWave", #Config.Waves)
	State.Set("Kills", 0)
	State.Set("NextWaveIn", 0)
	for _, player in Players:GetPlayers() do
		HeroService.Reset(player)
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
	Remotes.PlayAgain.OnServerEvent:Connect(function()
		if isOver() then
			GameService.NewGame()
			notify("New game! Build your defenders.", Color3.fromRGB(200, 200, 255))
		end
	end)

	GameService.NewGame()
end

return GameService
