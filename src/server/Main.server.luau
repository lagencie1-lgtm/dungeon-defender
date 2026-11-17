-- Starts the game: builds the map, then switches on goblins, defenders, heroes and waves.
local MapBuilder = require(script.Parent.MapBuilder)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local HeroService = require(script.Parent.HeroService)
local GameService = require(script.Parent.GameService)

MapBuilder.Build()
EnemyService.Start()
TowerService.Start()
HeroService.Start()
GameService.Start()

print("Realm Guardians is running!")
