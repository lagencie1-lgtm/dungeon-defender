-- Map tour, client side: holds each camera view for a moment and marks it ("[MAPTOUR] <unix ms> shot <map> <view>").
-- Views: the plan from straight above, a slanted overview, the real run camera at the hero's start, and the run
-- camera's angle (20.5 studs, 42 degrees down) at seven places along the lane, which is what a phone player sees.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(ReplicatedStorage.Shared.Ground)
local cue = ReplicatedStorage:WaitForChild("TourCue")
local camera = workspace.CurrentCamera

local function mark(...)
	print("[MAPTOUR]", DateTime.now().UnixTimestampMillis, ...)
end

local HOLD = 2.6
local v = Vector3.new
local SPOTS = {
	CursedForest = {
		{ name = "yard", hero = v(23, 0, 14), toward = v(34, 0, 36) }, -- the stepping stones down to the chapel yard
		{ name = "bridge", hero = v(64, 0, -26), toward = v(52, 0, -4) }, -- the shrine bridge's near landing
	},
}
local function hold(mapId, name, cframe, fov)
	camera.CameraType = Enum.CameraType.Scriptable
	local old = camera.FieldOfView
	camera.FieldOfView = fov or old
	local stop = os.clock() + HOLD
	local marked = false
	while os.clock() < stop do
		camera.CFrame = cframe
		if not marked and os.clock() > stop - HOLD + 1.6 then
			marked = true
			mark("shot", mapId, name)
		end
		RunService.RenderStepped:Wait()
	end
	camera.FieldOfView = old
end

cue.OnClientEvent:Connect(function(mapId)
	Config.SetMap(mapId)
	task.wait(1.5)
	-- the run camera as the game sets it at the hero's start
	mark("shot", mapId, "hero")
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local function bearing(v)
		return math.floor(math.deg(math.atan2(-v.Z, v.X)) + 0.5) -- 0 = east, 90 = north
	end
	mark("start", mapId, "camera looks to bearing", bearing(camera.CFrame.LookVector),
		"hero faces bearing", root and bearing(root.CFrame.LookVector) or "-", "at", root and tostring(root.Position) or "-")
	task.wait(1.2)
	-- the plan: straight down
	-- (from this far up the map's haze would hide it: the two far views are taken without it)
	local Lighting = game:GetService("Lighting")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local density, fogEnd = atmosphere and atmosphere.Density, Lighting.FogEnd
	if atmosphere then
		atmosphere.Density = 0
	end
	Lighting.FogEnd = 100000
	hold(mapId, "plan", CFrame.lookAt(Vector3.new(0, 300, 0), Vector3.zero, Vector3.new(0, 0, -1)), 50)
	hold(mapId, "overview", CFrame.lookAt(Vector3.new(-30, 150, 170), Vector3.new(0, 0, 10)), 60)
	if atmosphere then
		atmosphere.Density = density
	end
	Lighting.FogEnd = fogEnd
	-- along the lane at the run camera's angle
	local path = Config.Path
	local total = 0
	for i = 2, #path do
		total += (path[i] - path[i - 1]).Magnitude
	end
	local function at(distance)
		for i = 2, #path do
			local length = (path[i] - path[i - 1]).Magnitude
			if distance <= length then
				return path[i - 1] + (path[i] - path[i - 1]).Unit * distance, (path[i] - path[i - 1]).Unit
			end
			distance -= length
		end
		return path[#path], (path[#path] - path[#path - 1]).Unit
	end
	local pitch = math.rad(42)
	for i, f in { 0.06, 0.2, 0.34, 0.48, 0.62, 0.78, 0.95 } do
		local pos, dir = at(total * f)
		local y = (Ground.At(pos.X, pos.Z))
		-- the hero stands beside the lane, looking along it (as a player defending this stretch does)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local hero = pos + side * 9
		hero = Vector3.new(hero.X, (Ground.At(hero.X, hero.Z)) + 3, hero.Z)
		local look = (pos + dir * 10 - hero) * Vector3.new(1, 0, 1)
		look = look.Unit
		local eye = hero - look * 20.5 * math.cos(pitch) + Vector3.new(0, 20.5 * math.sin(pitch), 0)
		local _ = y
		hold(mapId, "lane" .. i, CFrame.lookAt(eye, hero))
	end
	-- the places a map's design is about (Lemp's map audit), at the run camera's angle: the hero stands at `hero`
	-- and looks towards `toward`
	for _, view in SPOTS[mapId] or {} do
		local hero = Vector3.new(view.hero.X, (Ground.At(view.hero.X, view.hero.Z)) + 3, view.hero.Z)
		local look = ((view.toward - hero) * Vector3.new(1, 0, 1)).Unit
		local eye = hero - look * 20.5 * math.cos(pitch) + Vector3.new(0, 20.5 * math.sin(pitch), 0)
		hold(mapId, view.name, CFrame.lookAt(eye, hero))
	end
	camera.CameraType = Enum.CameraType.Custom
	cue:FireServer(mapId)
end)
