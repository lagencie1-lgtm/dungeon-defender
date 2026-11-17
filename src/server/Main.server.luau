-- Starts the game: builds the map, then switches everything on.
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local HeroService = require(script.Parent.HeroService)
local LootService = require(script.Parent.LootService)
local GameService = require(script.Parent.GameService)

MapBuilder.Build()
DataService.Start()
EnemyService.Start()
TowerService.Start()
HeroService.Start()
LootService.Start()
GameService.Start()

print("Realm Guardians is running!")
