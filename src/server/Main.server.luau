-- Starts the game: builds the map and sends a test wave of goblins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local EnemyService = require(script.Parent.EnemyService)

local map = MapBuilder.Build()
local portal = map.Portal
EnemyService.Start(portal)

portal:GetAttributeChangedSignal("Health"):Connect(function()
	print("Portal health:", portal:GetAttribute("Health"))
end)

task.wait(3)
local wave = Config.TestWave
print("Test wave: " .. wave.Count .. " goblins!")
for _ = 1, wave.Count do
	EnemyService.Spawn(wave.Enemy)
	task.wait(wave.Gap)
end
