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

local function heroAt(wall, away)
	-- on the player's side (further along the path), facing back at the wall; `away` keeps the hero out of repair range
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local p = wall.PrimaryPart.Position
		local stand = p + walk * (away or 7) + Vector3.new(0, 3, 0)
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
-- the new level 2 look first, then its health bar: enemies only fight a wall once a wave runs, so wait for the
-- first wave (the break counts down by itself) and send goblins straight at it
TowerService.Upgrade(player, wall)
task.wait(6) -- (the new look streams in)
heroAt(wall)
task.wait(2)
report("l2")
shot("l2_new")
for _ = 1, 80 do
	if State.Get("State") == "Wave" then
		break
	end
	task.wait(0.5)
end
print("[SHOT] state", State.Get("State"))
heroAt(wall, 18) -- (a hero next to the wall repairs it faster than goblins hurt it)
local goblins = {}
for i = 1, 6 do
	table.insert(goblins, EnemyService.Spawn("Goblin", 400, math.max(0, d - 4 - i * 1.5)))
end
-- a hurt goblin shows its own health bar (EnemyService.HealthBar): if no bar shows in a capture either, the capture
-- misses BillboardGuis, not the wall
task.wait(1)
for _ = 1, 60 do
	if (wall:GetAttribute("Health") or 0) < (wall:GetAttribute("MaxHealth") or 0) * 0.8 then
		break
	end
	task.wait(0.5)
end
print("[SHOT] health", wall:GetAttribute("Health"), "/", wall:GetAttribute("MaxHealth"))
player:SetAttribute("CheckBar", true)
task.wait(0.5)
shot("l2_health")
for k = 2, 3 do
	task.wait(2)
	print("[SHOT] health", wall:GetAttribute("Health"), "/", wall:GetAttribute("MaxHealth"))
	shot("l2_health" .. k)
end
task.wait(3)
shot("done")
