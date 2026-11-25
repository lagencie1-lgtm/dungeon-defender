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
-- a long first break, so every look is shot before goblins arrive (the wave comes after the branch shots)
Config.FirstBreakTime = 70
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

local function heroAt(wall, away, aside)
	-- on the player's side (further along the path), facing back at the wall; `away` keeps the hero out of repair range;
	-- `aside` moves the hero off the path's middle so the camera behind the hero sees the wall, not the hero's back
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local p = wall.PrimaryPart.Position
		local side = walk:Cross(Vector3.yAxis).Unit
		local stand = p + walk * (away or 7) + side * (aside or 0) + Vector3.new(0, 3, 0)
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
-- each look is shot by the client (test/shots/LookCheck.client.luau) once it has really loaded there
local ShotDone = Instance.new("RemoteEvent")
ShotDone.Name = "ShotDone"
ShotDone.Parent = game:GetService("ReplicatedStorage")
local shotDone = nil
ShotDone.OnServerEvent:Connect(function(_, name)
	shotDone = name
end)
local function shootLook(name, model)
	heroAt(wall, 9, 6)
	task.wait(1)
	report(name)
	shotDone = nil
	player:SetAttribute("CheckLook", "")
	player:SetAttribute("CheckLook", name .. "|" .. model)
	for _ = 1, 120 do
		if shotDone == name then
			break
		end
		task.wait(0.5)
	end
	print("[SHOT] state", State.Get("State"), "next wave in", State.Get("NextWaveIn"))
	task.wait(1)
end

shootLook("l1_look", "tower_barricade_l1")
TowerService.Upgrade(player, wall)
shootLook("l2_new", "tower_barricade_l2")
TowerService.Upgrade(player, wall, "Thornwall")
shootLook("thornwall_look", "tower_barricade_thorn")
TowerService.Sell(player, wall)
task.wait(1)
ok, why = TowerService.Place(player, "Barricade", spotAt)
print("[SHOT] placed again", ok, why)
wall = findWall()
TowerService.Upgrade(player, wall)
task.wait(1)
TowerService.Upgrade(player, wall, "Rootwall")
shootLook("rootwall_look", "tower_barricade_root")

-- then the wave: goblins at the Rootwall, its health bar checked, and whatever shows in the top right named
local d = wall:GetAttribute("PathDistance")
for _ = 1, 200 do
	if State.Get("State") == "Wave" then
		break
	end
	task.wait(0.5)
end
print("[SHOT] state", State.Get("State"))
heroAt(wall, 18, 6) -- (a hero next to the wall repairs it faster than goblins hurt it)
for i = 1, 6 do
	EnemyService.Spawn("Goblin", 400, math.max(0, d - 4 - i * 1.5))
end
task.wait(1)
for _ = 1, 60 do
	if (wall:GetAttribute("Health") or 0) < (wall:GetAttribute("MaxHealth") or 0) * 0.8 then
		break
	end
	task.wait(0.5)
end
print("[SHOT] health", wall:GetAttribute("Health"), "/", wall:GetAttribute("MaxHealth"))
player:SetAttribute("CheckBar", true)
-- the same view as the earlier wave shots (hero on the path's middle, 7 studs back), where a bar showed in the top right
heroAt(wall, 7)
task.wait(1)
player:SetAttribute("CheckBar", os.clock())
for k = 1, 3 do
	player:SetAttribute("WhatBar", os.clock()) -- (a new value each time: false then true in one frame never reaches the client)
	task.wait(0.5)
	shot("rootwall_wave" .. k)
	task.wait(2)
end
-- the first run's view again (a Thornwall made during the wave, goblins at it, hero in the path's middle 7 studs
-- back), where a green bar showed in the top right: name what is drawn there
TowerService.Sell(player, wall)
task.wait(1)
TowerService.Place(player, "Barricade", spotAt)
wall = findWall()
TowerService.Upgrade(player, wall)
task.wait(1)
TowerService.Upgrade(player, wall, "Thornwall")
for i = 1, 6 do
	EnemyService.Spawn("Goblin", 400, math.max(0, d - 4 - i * 1.5))
end
task.wait(6)
heroAt(wall, 7)
task.wait(2)
player:SetAttribute("CheckBar", os.clock())
for k = 1, 3 do
	player:SetAttribute("WhatBar", os.clock()) -- (a new value each time: false then true in one frame never reaches the client)
	task.wait(0.5)
	shot("thornwall_wave" .. k)
	task.wait(2)
end
shot("done")
