-- The camera at the start of a run: tower defense is played by watching the lane, so the camera starts high and
-- far enough to see the defenders and the wave around the hero (the phone film showed a 12-stud follow camera with
-- the wave off screen). The player can still zoom in and out as they like; this only sets where it starts.
-- In the hub the camera goes back to a normal walking distance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer

local RUN_DISTANCE = 34 -- studs behind the hero when a run starts
local HUB_DISTANCE = 14
local MAX_DISTANCE = 60

local function zoomTo(distance)
	-- forcing the minimum to the wanted distance moves the camera out at once; letting it go next frame keeps it there
	player.CameraMaxZoomDistance = math.max(MAX_DISTANCE, distance)
	player.CameraMinZoomDistance = distance
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	player.CameraMinZoomDistance = 0.5
end

local last = nil
local function update()
	local state = GameState:GetAttribute("State")
	local inRun = state == "Break" or state == "Wave"
	if inRun ~= last then
		last = inRun
		task.spawn(zoomTo, inRun and RUN_DISTANCE or HUB_DISTANCE)
	end
end

GameState:GetAttributeChangedSignal("State"):Connect(update)
player.CharacterAdded:Connect(function()
	last = nil
	task.wait(0.5)
	update()
end)
update()
