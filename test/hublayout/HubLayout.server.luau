-- Hub layout test (test/hublayout.project.json): builds the Watch Keep, waits for its buildings, and checks the
-- rules from Lemp's three layout bugs (2026-11-22: Magma pad cut by the paving, hero statue and chest standing on
-- their rings, lanterns and a prop inside rings):
--  * every walk-in ring and map pad lies on top of the ground (0.02..0.3 studs proud), fully visible
--  * a ring's edge is at least 2 studs from its building's footprint
--  * no decor (lanterns, crates, beds, signs, banners, props) inside a ring or pad or within 2 studs of its edge
--  * nothing stands on the straight line from the spawn to a ring or pad (2 studs either side)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
local Ground = require(ReplicatedStorage.Shared.Ground)

local failures = 0
local function fail(...)
	failures += 1
	print("[HUBLAYOUT] FAIL", ...)
end

local hub = workspace:WaitForChild("Outpost", 30)
task.wait(25) -- buildings and decor load in the background
local c = Config.OutpostCenter

local function flat(v)
	return Vector2.new(v.X, v.Z)
end
-- distance from a point to a model's footprint (its box on the ground, turned with the model)
local function toFootprint(point, model)
	local cf, size = model:GetBoundingBox()
	local localP = cf:PointToObjectSpace(Vector3.new(point.X, cf.Position.Y, point.Y))
	local dx = math.max(math.abs(localP.X) - size.X / 2, 0)
	local dz = math.max(math.abs(localP.Z) - size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end
local function segmentDistance(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (a + ab * t - p).Magnitude
end

-- the circles: station rings and map pads
local circles = {}
for _, s in HubLayout.Stations do
	local ring = hub:FindFirstChild(s.Id .. "Ring")
	if not ring then
		fail(s.Id, "ring missing")
	else
		table.insert(circles, { name = s.Id .. " ring", part = ring, r = HubLayout.RingRadius, building = s.Model, station = s })
	end
end
for _, p in HubLayout.Pads do
	local pad = hub:FindFirstChild(p.Map == Config.MapOrder[1] and "StartPad" or "Pad_" .. p.Map)
	if pad then
		table.insert(circles, { name = p.Map .. " pad", part = pad, r = HubLayout.PadRadius + 0.6 })
	end
end

-- 1. on top of the ground
for _, circle in circles do
	local pos = circle.part.Position
	local top = -math.huge
	for k = 0, 8 do
		local a = k / 8 * math.pi * 2
		local d = k == 0 and 0 or circle.r * 0.95
		top = math.max(top, (Ground.At(pos.X + math.cos(a) * d, pos.Z + math.sin(a) * d)))
	end
	local surface = pos.Y + circle.part.Size.Y / 2 * (circle.part.Shape == Enum.PartType.Cylinder and 0 or 1)
	local proud = (circle.part.Shape == Enum.PartType.Cylinder) and (pos.Y + 0.1 - top) or (surface - top)
	if proud < 0.02 or proud > 0.3 then
		fail(circle.name, string.format("is %.2f studs over the highest ground under it (wants 0.02..0.3)", proud))
	end
end

-- the buildings and the decor in the hub
local buildings, decor = {}, {}
local stationModels = {}
for _, s in HubLayout.Stations do
	stationModels[s.Model] = s
end
for _, child in hub:GetChildren() do
	if child:IsA("Model") then
		if stationModels[child.Name] then
			buildings[child.Name] = child
		elseif not child.Name:match("RuneRing$") and child.Name ~= "keep_palisade" and child.Name ~= "keep_watchtower"
			and child.Name ~= "tree_oak" then
			table.insert(decor, child)
		end
	elseif child:IsA("BasePart") and child.Transparency < 1 and not child.Name:match("Ring$") and not child.Name:match("^Pad")
		and child.Name ~= "StartPad" and child.Name ~= "Ground" and child.Name ~= "Wall" then
		table.insert(decor, child)
	end
end

local spawnAt = flat(c + HubLayout.Spawn)
for _, circle in circles do
	local center = flat(circle.part.Position)
	-- 2. clear of its building
	if circle.building then
		local model = buildings[circle.building]
		if not model then
			fail(circle.name, "its building", circle.building, "has not loaded")
		else
			local gap = toFootprint(center, model) - circle.r
			if gap < 2 then
				fail(circle.name, string.format("edge is %.1f studs from %s (wants 2+)", gap, circle.building))
			end
		end
	end
	-- 3. no decor in or near it, 4. nothing on the line from the spawn
	for _, d in decor do
		local isModel = d:IsA("Model")
		-- signs hanging high over a building are not in the way of anyone walking
		local lowCf, lowSize = isModel and d:GetBoundingBox() or d.CFrame, isModel and select(2, d:GetBoundingBox()) or d.Size
		local overhead = (lowCf.Position.Y - lowSize.Y / 2) - circle.part.Position.Y > 6
		if overhead then
			continue
		end
		local gap
		if isModel then
			gap = toFootprint(center, d) - circle.r
		else
			gap = (flat(d.Position) - center).Magnitude - math.max(d.Size.X, d.Size.Z) / 2 - circle.r
		end
		if gap < 2 then
			fail(circle.name, string.format("has %s %.1f studs from its edge (wants 2+)", d.Name, gap))
		end
		local p = isModel and flat(d:GetPivot().Position) or flat(d.Position)
		if segmentDistance(p, spawnAt, center) < 2 and (p - center).Magnitude > circle.r then
			fail(circle.name, "has", d.Name, "on the line from the spawn")
		end
	end
end

-- 5. rings and pads never touch each other (2 studs apart)
for i, a in circles do
	for j = i + 1, #circles do
		local b = circles[j]
		local gap = (flat(a.part.Position) - flat(b.part.Position)).Magnitude - a.r - b.r
		if gap < 2 then
			fail(a.name, string.format("is %.1f studs from %s (wants 2+)", gap, b.name))
		end
	end
end

local result = failures == 0 and "PASS" or "FAIL"
print("[HUBLAYOUT] DONE", result, failures, "problems")
pcall(function()
	game:GetService("StudioTestService"):EndTest(result)
end)
