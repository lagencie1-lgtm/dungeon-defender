-- Barricade screenshots (test/shots.project.json only; scripts/barricade_shots.ps1 grabs the Studio window at every
-- "[SHOT] <unix ms> <name>" line). The place's name starts with htd-film-phone, so the film plugin runs it in the
-- iPhone 13 simulator at graphics level 1. One wall on the longest straight of the path: level 1 with goblins stopped
-- at it (its health bar shows), level 2, the Thornwall, then a fresh wall upgraded to the Rootwall. The hero stands on
-- the player's side, so the run camera sees it the way a player does.
local Players = game:GetService("Players")
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local function shot(name)
	print("[SHOT]", DateTime.now().UnixTimestampMillis, name)
end

task.wait(4)
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local EnemyService = require(Server.EnemyService)
local DataService = require(Server.DataService)
local State = require(Server.State)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
for _ = 1, 40 do
	if DataService.Get(player) then
		break
	end
	task.wait(0.5)
end
for _ = 1, 60 do
	if State.Get("State") == "Lobby" then
		break
	end
	task.wait(0.5)
end
State.Set("Map", "CursedForest")
State.Set("Mode", "Campaign")
State.Set("Difficulty", "Easy")
GameService.StartRun()
task.wait(3)
State.Set("Gold", 100000)

local pts = Config.Path
-- the longest straight that runs east-west (the run camera looks along the X axis's cross direction: a wall across
-- a north-south stretch is seen end-on)
local best, bestLength = 1, 0
for i = 1, #pts - 1 do
	local d = pts[i + 1] - pts[i]
	local length = d.Magnitude
	if length > bestLength and math.abs(d.X) > 0.8 * length then
		best, bestLength = i, length
	end
end
local a, b = pts[best], pts[best + 1]
local spotAt = a:Lerp(b, 0.5)
local walk = (b - a).Unit

local function heroAt(wall)
	-- on the player's side (further along the path), facing back at the wall
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local p = wall.PrimaryPart.Position
		local stand = p + walk * 7 + Vector3.new(0, 3, 0)
		root.CFrame = CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z))
	end
end

local function findWall()
	for _, m in workspace.Towers:GetChildren() do
		if m:GetAttribute("TowerType") == "Barricade" then
			return m
		end
	end
end

local ok, why = TowerService.Place(player, "Barricade", spotAt)
print("[SHOT] placed", ok, why)
local wall = findWall()
local function report(tag)
	-- which way the look's long side runs: across the path (as it should) or along it
	local look = wall:FindFirstChild("Look")
	if not look then
		print("[SHOT] no Look on", tag)
		return
	end
	local box, size = look:GetBoundingBox()
	local ax = { box.RightVector * size.X, box.UpVector * size.Y, box.LookVector * size.Z }
	local along, across, up = 0, 0, 0
	for _, v in ax do
		along = math.max(along, math.abs(v:Dot(walk)))
		across = math.max(across, math.abs(v:Dot(walk:Cross(Vector3.yAxis).Unit)))
		up = math.max(up, math.abs(v.Y))
	end
	print("[SHOT] look", tag, "size", size, "extent along path", along, "across path", across, "height", up,
		"walk", walk, "wall bottom y", box.Position.Y - up / 2, "path y", spotAt.Y)
end
report("l1")
heroAt(wall)
task.wait(10) -- (the models and paints stream in)
heroAt(wall)
local d = wall:GetAttribute("PathDistance")
local goblins = {}
for i = 1, 6 do
	table.insert(goblins, EnemyService.Spawn("Goblin", 400, math.max(0, d - 4 - i * 1.5)))
end
-- wait until they hit it (the health bar shows once it is hurt)
for _ = 1, 40 do
	if (wall:GetAttribute("Health") or 0) < (wall:GetAttribute("MaxHealth") or 0) * 0.85 then
		break
	end
	task.wait(0.5)
end
print("[SHOT] health", wall:GetAttribute("Health"), "/", wall:GetAttribute("MaxHealth"))
shot("l1_goblins")
task.wait(3)
for _, e in goblins do
	EnemyService.Damage(e, 1e9)
end
TowerService.Upgrade(player, wall)
task.wait(2)
heroAt(wall)
task.wait(2)
report("l2")
shot("l2")
task.wait(3)
TowerService.Upgrade(player, wall, "Thornwall")
task.wait(2)
heroAt(wall)
task.wait(2)
shot("thornwall")
task.wait(3)
TowerService.Sell(player, wall)
task.wait(1)
State.Set("Gold", 100000)
TowerService.Place(player, "Barricade", spotAt)
wall = findWall()
TowerService.Upgrade(player, wall)
TowerService.Upgrade(player, wall, "Rootwall")
task.wait(2)
heroAt(wall)
task.wait(2)
shot("rootwall")
task.wait(3)
shot("done")
