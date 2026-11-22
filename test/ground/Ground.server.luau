-- Ground test (test/ground.project.json): every defender at 30 random legal spots per map and every enemy kind
-- along each whole path. The lowest visible point must sit within -0.05..+0.3 studs of the terrain under it.
-- Prints "[GROUND]" lines and ends the play test. Lemp: "Towers are sometimes underneath the ground ...
-- Monsters running under the ground" (2026-11-22).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(ReplicatedStorage.Shared.Ground)
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local EnemyService = require(Server.EnemyService)
local DataService = require(Server.DataService)
local ArtService = require(Server.ArtService)
local State = require(Server.State)

local LOW, HIGH = -0.05, 0.3
local function log(...)
	print("[GROUND]", ...)
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = false
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or -math.huge
end

-- lowest visible point of a model: the bottom of each visible part's box in world space
local function lowest(model)
	local low = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.95 and p.Name ~= "SelectionVolume" then
			local cf, s = p.CFrame, p.Size / 2
			local down = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
			low = math.min(low, cf.Position.Y - down)
		end
	end
	return low
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
while not DataService.Get(player) do
	task.wait(0.2)
end
local p = DataService.Get(player)
for kind in Config.Towers do
	p.Owned.Towers[kind] = true
end
for _, name in { "tower_ranger", "tower_flame", "tower_frost", "tower_storm", "tower_ballista" } do
	ArtService.WaitModel(name, 30)
end

local failures, checks = 0, 0
local function judge(what, gap)
	checks += 1
	if gap < LOW or gap > HIGH then
		failures += 1
		if failures <= 60 then
			log("FAIL", what, string.format("gap %.2f", gap))
		end
	end
end

local rng = Random.new(42)
for _, mapId in Config.MapOrder do
	State.Set("Map", mapId)
	GameService.StartRun()
	task.wait(1)
	State.Set("BuildMax", 100000)
	local half = Config.MapSize / 2
	local worst = { tower = 0, enemy = 0 }
	local reasons = {}
	-- what the buildable ground looks like: heights on a 4-stud grid away from the path
	local buckets = {}
	for x = -half.X + 6, half.X - 6, 4 do
		for z = -half.Y + 6, half.Y - 6, 4 do
			if Config.DistanceToPath(Vector3.new(x, 0, z)) > Config.PathWidth / 2 + 4 then
				local y = groundAt(x, z)
				local key = string.format("%.1f", math.floor(y * 10 + 0.5) / 10)
				buckets[key] = (buckets[key] or 0) + 1
			end
		end
	end
	local list = {}
	for k, n in buckets do
		if n > 3 then
			table.insert(list, k .. ":" .. n)
		end
	end
	table.sort(list)
	log(mapId, "ground heights", table.concat(list, " "))
	for _, kind in Config.TowerOrder do
		local placed, tries = 0, 0
		while placed < 30 and tries < 3000 do
			tries += 1
			State.AddGold(100000)
			local pos = Vector3.new(rng:NextNumber(-half.X + 5, half.X - 5), 0, rng:NextNumber(-half.Y + 5, half.Y - 5))
			local ok, why = TowerService.Place(player, kind, pos)
			reasons[why or "ok"] = (reasons[why or "ok"] or 0) + 1
			if ok then
				placed += 1
				local model = workspace.Towers:GetChildren()[#workspace.Towers:GetChildren()]
				for _, m in workspace.Towers:GetChildren() do
					if m:GetAttribute("TowerType") == kind and math.abs(m:GetPivot().Position.X - pos.X) < 0.01 then
						model = m
					end
				end
				local look = model:FindFirstChild("Look") or model
				local base = model:FindFirstChild("Base")
				local at = base.Position
				local top, low = Ground.Footprint(at, Ground.Foot[kind])
				-- the defender stands on the highest ground under it: not sunk, not floating
				local gap = lowest(look) - top
				if math.abs(gap) > math.abs(worst.tower) then
					worst.tower = gap
				end
				judge(string.format("%s %s at (%.0f, %.0f)", mapId, kind, at.X, at.Z), gap)
				-- and its plinth reaches the lowest ground, so no edge floats (it may go into the ground a little)
				local plinth = base.Position.Y - base.Size.Y / 2
				judge(string.format("%s %s plinth at (%.0f, %.0f)", mapId, kind, at.X, at.Z), plinth - low + 0.2) -- passes for -0.25..+0.1
				TowerService.Sell(player, model)
			end
		end
		log(mapId, kind, "placed", placed, "of", tries, "tries")
	end
	local tally = {}
	for why, n in reasons do
		table.insert(tally, why .. " " .. n)
	end
	log(mapId, "placement answers:", table.concat(tally, ", "))
	-- enemies: every kind, frozen at a spot every 6 studs along the whole path
	local length = 0
	for i = 2, #Config.Path do
		length += (Config.Path[i] - Config.Path[i - 1]).Magnitude
	end
	for name, stats in Config.Enemies do
		if not stats.Summon then
			EnemyService.Clear()
			for d = 2, length - 2, 6 do
				EnemyService.Spawn(name, 1000, d)
			end
			task.wait(0.2)
			for _, e in EnemyService.GetActive() do
				EnemyService.Freeze(e, 1000)
			end
			task.wait(0.4)
			for _, e in EnemyService.GetActive() do
				local look = e.model:FindFirstChild("Look") or e.model
				local at = e.model:GetPivot().Position
				local gap = lowest(look) - groundAt(at.X, at.Z) - (e.hop or 0) -- the walking hop lifts it on purpose
				if math.abs(gap) > math.abs(worst.enemy) then
					worst.enemy = gap
				end
				judge(string.format("%s %s (size %.1f) at %.0f studs", mapId, name, stats.Size, e.distance), gap)
			end
		end
	end
	EnemyService.Clear()
	log(mapId, string.format("worst tower gap %.2f, worst enemy gap %.2f", worst.tower, worst.enemy))
	GameService.EndGame(false)
	GameService.ToOutpost()
	task.wait(1)
end
local result = failures == 0 and "PASS" or "FAIL"
log("DONE", result, failures, "of", checks, "checks outside", LOW, "..", HIGH)
pcall(function()
	game:GetService("StudioTestService"):EndTest(result)
end)
