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

-- then wave 1 against a fresh level 1 wall with no hero near (Lemp 2026-11-26: the whole pile smashes the wall):
-- a phone shot of the goblins piled at it, and how long the wall lasts
TowerService.Sell(player, wall)
task.wait(1)
ok, why = TowerService.Place(player, "Barricade", spotAt)
print("[SHOT] placed level 1 for the wave", ok, why)
wall = findWall()
heroAt(wall, 11) -- (out of repair range: Config.Barricade.RepairRange is 9)
for _ = 1, 240 do
	if State.Get("State") == "Wave" then
		break
	end
	task.wait(0.5)
end
local t0 = os.clock()
print("[SHOT] wave 1 starts, wall", wall:GetAttribute("Health"), "/", wall:GetAttribute("MaxHealth"))
local firstHit, shotTaken, most = nil, false, 0
while wall.Parent and (wall:GetAttribute("Health") or 0) > 0 and os.clock() - t0 < 150 do
	heroAt(wall, 11)
	local hp, max = wall:GetAttribute("Health") or 0, wall:GetAttribute("MaxHealth") or 1
	if not firstHit and hp < max then
		firstHit = os.clock()
		print(string.format("[SHOT] first hit %.1f s into the wave", firstHit - t0))
	end
	local piled, smashing = 0, 0
	for _, e in EnemyService.GetActive() do
		if not e.dead and e.wall then
			piled += 1
			if e.bashing then
				smashing += 1
			end
		end
	end
	if piled > most then
		most = piled
		print(string.format("[SHOT] pile %d at the wall, %d smashing, wall %.0f / %.0f at %.1f s", piled, smashing, hp, max, os.clock() - t0))
	end
	if not shotTaken and piled >= 7 then
		shotTaken = true
		shot("pile_wave1")
	end
	task.wait(0.25)
end
local gone = os.clock()
print(string.format("[SHOT] level 1 wall %s after %.1f s of the wave, %.1f s after the first hit; most piled %d",
	(wall.Parent and (wall:GetAttribute("Health") or 0) > 0) and "still standing" or "broken", gone - t0,
	firstHit and gone - firstHit or -1, most))
if not shotTaken then
	shot("pile_wave1")
end
-- the broken wall: the hero walks up, picks it (the gamepad's Y, as a player would) and the panel offers the paid
-- rebuild; then halfway through the rebuild (Config.Barricade.RebuildTime of game time)
print("[SHOT] broken", wall:GetAttribute("Broken"), "rebuilding", wall:GetAttribute("Rebuilding"))
heroAt(wall, 5)
task.wait(1)
player:SetAttribute("PickWall", os.clock())
task.wait(2)
shot("broken_repair")
task.wait(3) -- (the screen grab follows the log line by a second or two)
local paid = TowerService.Rebuild(player, wall)
print("[SHOT] rebuild paid", paid, "mana left", State.Get("Gold"))
local r0 = os.clock()
for _ = 1, 160 do
	if (wall:GetAttribute("RebuildProgress") or 0) >= 0.5 then
		break
	end
	heroAt(wall, 5)
	task.wait(0.25)
end
print(string.format("[SHOT] rebuild at %.0f%% after %.1f s", (wall:GetAttribute("RebuildProgress") or 0) * 100, os.clock() - r0))
shot("rebuild_half")
for _ = 1, 160 do
	if not wall:GetAttribute("Broken") then
		break
	end
	task.wait(0.25)
end
print(string.format("[SHOT] rebuilt after %.1f s, health %s / %s", os.clock() - r0, tostring(wall:GetAttribute("Health")),
	tostring(wall:GetAttribute("MaxHealth"))))
shot("rebuilt")
task.wait(2)
shot("done")
