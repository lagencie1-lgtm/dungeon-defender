-- Map tour (test/maptour.project.json): builds each battle map, checks its designed layout (MapLayouts) and holds
-- a fixed set of camera views so scripts/map_tour.py can cut stills for the review sheet.
-- Prints "[MAPTOUR] <unix ms> <text>". Checks: every plateau's top is flat at its height and takes a defender that
-- stands on it; the lane's ground is continuous (no step over 1.2 studs per 2 studs walked); how much of the
-- field can be built on; enemies stand on the lane's real ground.
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
-- (absent in older copies of the game: the tour then only films, for "before" pictures)
local MapLayouts = Server:FindFirstChild("MapLayouts") and require(Server.MapLayouts)
local State = require(Server.State)
local cue = ReplicatedStorage:WaitForChild("TourCue")

local function log(...)
	print("[MAPTOUR]", DateTime.now().UnixTimestampMillis, ...)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
while not DataService.Get(player) do
	task.wait(0.2)
end
local save = DataService.Get(player)
for kind in Config.Towers do
	save.Owned.Towers[kind] = true
end
local deadline = os.clock() + 45
repeat
	task.wait(0.2)
until (State.Get("State") == "Lobby" and player.Character) or os.clock() > deadline
for _, name in { "tower_ranger", "tower_flame", "tower_frost", "tower_storm", "tower_ballista" } do
	ArtService.WaitModel(name, 30)
end

local done = nil
cue.OnServerEvent:Connect(function(sender, what)
	if sender == player then
		done = what
	end
end)

local failures = 0
local function fail(...)
	failures += 1
	log("FAIL", ...)
end

local only = ReplicatedStorage:GetAttribute("TourOnly")
for _, mapId in Config.MapOrder do
	if only and only ~= mapId then
		continue
	end
	-- (a run only starts from the lobby: after the last map's run the game may still be on its way back)
	local ready = os.clock() + 20
	while State.Get("State") ~= "Lobby" and os.clock() < ready do
		task.wait(0.25)
	end
	State.Set("Map", mapId)
	GameService.StartRun()
	task.wait(1)
	if Config.CurrentMap ~= mapId then
		fail(mapId, "the run did not start (state " .. tostring(State.Get("State")) .. ")")
	end
	State.Set("BuildMax", 100000)
	local info = Config.Maps[mapId]
	local layout = MapLayouts and MapLayouts.For(info.Theme) or { Plateaus = {} }
	local half = Config.MapSize / 2

	-- 0. the first spot (MapOutline.Start, the one the tutorial points at): free for a Ranger, near the spawn, and
	-- room around it (a tap that lands a little off still finds it). Research briefs: a fresh phone player places a
	-- defender within 90 seconds; "no wall may block the first tower spot"
	local Outline = ReplicatedStorage.Shared:FindFirstChild("MapOutline") and require(ReplicatedStorage.Shared.MapOutline)
	local start = Outline and Outline.Start and Outline.Start[info.Theme]
	if start and start.FirstSpot then
		local spot = start.FirstSpot
		local ok, why = TowerService.CanPlace(spot)
		local height, ground = Ground.Pad(spot, 2.5)
		local around = 0
		for i = 0, 7 do
			local a = i * math.pi / 4
			local near = spot + Vector3.new(math.cos(a), 0, math.sin(a)) * 1.5
			around += (TowerService.CanPlace(near) and Ground.Pad(near, 2.5)) and 1 or 0
		end
		local fromSpawn = (Config.SpawnPoint - spot).Magnitude
		local note = string.format("%s first spot at %d, %d: %s, %.0f studs from the spawn, %d of 8 spots 1.5 studs round it free too",
			mapId, spot.X, spot.Z, ok and height and "free" or tostring(why or ground), fromSpawn, around)
		if not (ok and height) or fromSpawn > 16 or around < 3 then
			fail(note)
		else
			log("ok", note)
		end
	end

	-- 1. plateaus: flat at their height, and a Ranger stands on each
	for _, p in layout.Plateaus do
		local cx, cz = (p.X0 + p.X1) / 2, (p.Z0 + p.Z1) / 2
		local low, high = math.huge, -math.huge
		-- (rounded corners slope: measure inside them, but always leave a strip to measure)
		local inset = math.min(math.max(5, (p.Round or 0) + 3), math.min(p.X1 - p.X0, p.Z1 - p.Z0) / 2 - 2)
		for x = p.X0 + inset, p.X1 - inset, 2 do
			for z = p.Z0 + inset, p.Z1 - inset, 2 do
				if Config.DistanceToPath(Vector3.new(x, 0, z)) > Config.PathWidth / 2 + 4 then
					local y = (Ground.At(x, z))
					low, high = math.min(low, y), math.max(high, y)
				end
			end
		end
		local note = string.format("%s %s: top %.2f..%.2f (wanted %d)", mapId, p.Name, low, high, p.H)
		if low == math.huge then
			-- (a narrow floor the lane runs along: every spot of its top is within the lane's reach, checked below)
			log("ok", mapId, p.Name, "top is the lane's")
		elseif math.abs(low - p.H) > 0.35 or math.abs(high - p.H) > 0.35 then
			fail(note)
		else
			log("ok", note)
		end
		-- a legal spot near the middle (the lane or a piece may sit on the middle itself)
		local placed = false
		for _, offset in { Vector3.zero, Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -6) } do
			State.AddGold(1000)
			local ok = TowerService.Place(player, "Ranger", Vector3.new(cx, 0, cz) + offset)
			if ok then
				placed = true
				break
			end
		end
		if not placed and Config.DistanceToPath(Vector3.new(cx, 0, cz)) > 20 then
			fail(mapId, p.Name, "takes no defender near its middle")
		end
	end

	-- 1b. channels: liquid (or lava) all along, below the floor, except where the lane crosses on its dam
	for _, c in layout.Channels or {} do
		local seen, wet, low, high = 0, 0, math.huge, -math.huge
		local kinds = {}
		for i = 1, #c.Points - 1 do
			local a, b = c.Points[i], c.Points[i + 1]
			for d = 0, (b - a).Magnitude, 4 do
				local pos = a + (b - a).Unit * d
				local onBridge = false
				for _, bridge in layout.Bridges or {} do
					onBridge = onBridge or (pos - bridge.At).Magnitude < 13
				end
				if not onBridge and math.abs(pos.X) < half.X - 6 and math.abs(pos.Z) < half.Y - 6
					and Config.DistanceToPath(pos) > Config.PathWidth / 2 + 6 then
					local y, material = Ground.At(pos.X, pos.Z)
					seen += 1
					kinds[material.Name] = (kinds[material.Name] or 0) + 1
					if material == Enum.Material.Water or material == Enum.Material.CrackedLava then
						wet += 1
					else
						kinds[string.format("dry at %d, %d (%.1f)", pos.X, pos.Z, y)] = 1
					end
					low, high = math.min(low, y), math.max(high, y)
				end
			end
		end
		local names = {}
		for name, n in kinds do
			table.insert(names, name .. " " .. n)
		end
		local note = string.format("%s %s: %d of %d spots are liquid, surface %.2f..%.2f (%s)", mapId, c.Name, wet, seen, low, high,
			table.concat(names, ", "))
		if wet < seen * 0.9 or high > -0.1 then
			fail(note)
		else
			log("ok", note)
		end
	end

	-- 1c. nothing built stands alone (reviews/maps/placement-rules.md)
	if MapLayouts and MapLayouts.Loose then
		local loose = MapLayouts.Loose(layout)
		local names = {}
		for _, t in loose do
			table.insert(names, string.format("%s of %s at %d, %d", t.Name, t.Set, t.At.X, t.At.Z))
		end
		local things = MapLayouts.Things(layout)
		local sets = 0
		for _ in layout.Sets or {} do
			sets += 1
		end
		local note = string.format("%s placement: %d things in %d sets, %d stand alone %s", mapId, #things, sets, #loose,
			table.concat(names, "; "))
		if #loose > 0 then
			fail(note)
		else
			log("ok", note)
		end
	end

	-- 1d. the outline (MapOutline): the lane and the hero's spawn lie well inside it, nothing beyond it takes a
	-- defender, and the rise stays under the camera's line: a hero stopped at the invisible wall who looks back into
	-- the field keeps the camera free
	if MapLayouts and layout.Border then
		local MapOutline = require(ReplicatedStorage.Shared.MapOutline)
		local problems = {}
		local nearest = math.huge
		for i = 1, #Config.Path - 1 do
			local a, b = Config.Path[i], Config.Path[i + 1]
			for d = 0, (b - a).Magnitude, 4 do
				local pos = a + (b - a).Unit * d
				nearest = math.min(nearest, -MapLayouts.Outside(layout, pos.X, pos.Z))
			end
		end
		if nearest < 10 then
			table.insert(problems, string.format("the lane comes within %.1f studs of the outline", nearest))
		end
		if MapLayouts.Outside(layout, Config.SpawnPoint.X, Config.SpawnPoint.Z) > -6 then
			table.insert(problems, "the hero's spawn is not inside")
		end
		local line = MapLayouts.CameraLine
		local seen, buildable, where = 0, 0, ""
		local tight = {} -- spots where the rise comes closest to the camera's line
		for x = -half.X - 30, half.X + 30, 4 do
			for z = -half.Y - 30, half.Y + 30, 4 do
				local rise, out = MapLayouts.RiseAt(layout, x, z)
				local pos = Vector3.new(x, 0, z)
				if out > -MapOutline.BuildStop and TowerService.CanPlace(pos) then
					buildable += 1
					where = string.format("%d, %d", x, z)
				end
				if rise > 0 and out <= line.Reach then
					seen += 1
					local y = (Ground.At(x, z))
					local room = line.Focus + math.tan(math.rad(line.Degrees)) * (out + MapOutline.HeroStop) - y
					table.insert(tight, { room = room, text = string.format("%.1f at %d, %d (%.0f out, ground %.1f)", room, x, z, out, y) })
				end
			end
		end
		table.sort(tight, function(a, b)
			return a.room < b.room
		end)
		if buildable > 0 then
			table.insert(problems, string.format("%d spots by or beyond the outline take a defender (one at %s)", buildable, where))
		end
		local tooHigh = {}
		for i = 1, math.min(4, #tight) do
			if tight[i].room < line.Clear then
				table.insert(tooHigh, tight[i].text)
			end
		end
		if #tooHigh > 0 then
			table.insert(problems, "the rise stands in the camera's line: " .. table.concat(tooHigh, "; "))
		end
		local note = string.format("%s outline: the lane keeps %.0f studs from it, %d spots of rise checked, least room under the camera's line %s",
			mapId, nearest, seen, tight[1] and tight[1].text or "-")
		if #problems > 0 then
			fail(note, "BUT", table.concat(problems, "; "))
		else
			log("ok", note)
		end
	end

	-- 2. the lane: continuous ground
	local length = 0
	for i = 2, #Config.Path do
		length += (Config.Path[i] - Config.Path[i - 1]).Magnitude
	end
	local laneY = function()
		return 0
	end
	if MapLayouts then
		laneY = select(2, MapLayouts.LaneProfile(layout, Config.Path))
	end
	local worstStep, worstOff, previous = 0, 0, nil
	local travelled = 0
	local lowLane, highLane = math.huge, -math.huge
	for i = 1, #Config.Path - 1 do
		local a, b = Config.Path[i], Config.Path[i + 1]
		local segment = (b - a).Magnitude
		for d = 0, segment, 2 do
			local pos = a + (b - a).Unit * d
			local y = (Ground.At(pos.X, pos.Z))
			if previous then
				worstStep = math.max(worstStep, math.abs(y - previous))
			end
			previous = y
			worstOff = math.max(worstOff, math.abs(y - laneY(travelled + d)))
			lowLane, highLane = math.min(lowLane, y), math.max(highLane, y)
		end
		travelled += segment
	end
	local laneNote = string.format("%s lane: ground %.2f..%.2f, biggest step %.2f per 2 studs, furthest from the plan %.2f",
		mapId, lowLane, highLane, worstStep, worstOff)
	-- (the step is the rule that matters: enemies walk the real ground. "From the plan" may reach 1.4 where a long
	-- ramp is cut into raised ground and the terrain's own smoothing rounds the cut)
	if worstStep > 1.2 or worstOff > 1.6 then
		fail(laneNote)
	else
		log("ok", laneNote)
	end

	-- 3. how much of the field takes a defender (and why not), on a 4-stud grid
	local answers, spots = {}, 0
	-- and the same for the ring beside the lane where most defenders go (8.5 to 18 studs from its middle)
	local near, nearOk = 0, 0
	for x = -half.X + 6, half.X - 6, 4 do
		for z = -half.Y + 6, half.Y - 6, 4 do
			spots += 1
			local pos = Vector3.new(x, 0, z)
			local ok, why = TowerService.CanPlace(pos)
			if ok then
				local height, ground = Ground.Pad(pos, 2.5)
				why = height and "ok" or ground
			end
			answers[why] = (answers[why] or 0) + 1
			local d = Config.DistanceToPath(pos)
			if d >= 8.5 and d <= 18 then
				near += 1
				nearOk += why == "ok" and 1 or 0
			end
		end
	end
	-- (each grid spot stands for 16 square studs; a defender needs about 36, its spacing is 6 studs)
	local room = math.floor(nearOk * 16 / 36)
	local nearNote = string.format("%s beside the lane (8.5 to 18 studs): %d%% of the ground takes a defender, room for about %d",
		mapId, math.floor(nearOk / near * 100 + 0.5), room)
	-- a rule with a number: obstacles must leave at least a third of that ring to build on, and room for three
	-- times as many defenders as a run can ever hold (the build limit is 30 points: 15 Rangers at most)
	if nearOk / near < 0.33 or room < 45 then
		fail(nearNote)
	else
		log("ok", nearNote)
	end
	local list = {}
	for why, n in answers do
		table.insert(list, string.format("%s %d%%", why, math.floor(n / spots * 100 + 0.5)))
	end
	table.sort(list)
	log(mapId, "field:", table.concat(list, ", "))

	-- 4. a wave standing along the whole lane (frozen), so the stills show monsters on ramps and bridges
	local names = {}
	for name, stats in Config.Enemies do
		-- (small ones only: a frozen boss or a giant slime hides the map it stands on)
		if not stats.Summon and not stats.Boss and (stats.Size or 3) <= 3 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	local n = 0
	for d = 6, length - 10, 13 do
		n += 1
		EnemyService.Spawn(names[n % #names + 1], 1000, d)
	end
	task.wait(0.3)
	for _, e in EnemyService.GetActive() do
		EnemyService.Freeze(e, 1000)
	end
	task.wait(0.5)
	local worstEnemy = 0
	for _, e in EnemyService.GetActive() do
		local at = e.model:GetPivot().Position
		local gap = e.position.Y - (Ground.At(at.X, at.Z))
		worstEnemy = math.max(worstEnemy, math.abs(gap))
	end
	if worstEnemy > 0.6 then
		fail(mapId, string.format("an enemy stands %.2f studs off the lane's ground", worstEnemy))
	end
	-- a few defenders beside the lane as a player would build them
	local rng = Random.new(5)
	local built, tries = 0, 0
	while built < 9 and tries < 4000 do
		tries += 1
		local pos = Vector3.new(rng:NextNumber(-half.X + 8, half.X - 8), 0, rng:NextNumber(-half.Y + 8, half.Y - 8))
		local d = Config.DistanceToPath(pos)
		if d > 9 and d < 20 then
			State.AddGold(1000)
			if TowerService.Place(player, Config.TowerOrder[built % 3 + 1], pos) then
				built += 1
			end
		end
	end

	-- 5. the camera views (the client holds each one and marks it)
	task.wait(10) -- models and trees stream in
	done = nil
	cue:FireClient(player, mapId)
	local wait = os.clock() + 120
	repeat
		task.wait(0.2)
	until done == mapId or os.clock() > wait
	EnemyService.Clear()
	GameService.EndGame(false)
	GameService.ToOutpost()
	task.wait(1.5)
end
log("DONE", failures == 0 and "PASS" or "FAIL", failures, "failures")
task.wait(1)
pcall(function()
	game:GetService("StudioTestService"):EndTest(failures == 0 and "PASS" or "FAIL")
end)
