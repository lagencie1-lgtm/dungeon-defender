-- The camera at the start of a run: tower defense is played by watching the lane, so the camera starts high and
-- far enough to see the defenders and the wave around the hero (the phone film showed a 12-stud follow camera with
-- the wave off screen). The player can still zoom in and out as they like; this only sets where it starts.
-- In the hub the camera goes back to a normal walking distance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer

local RUN_DISTANCE = 30 -- studs from the hero when a run starts: the hero is about 13% of the screen height
local HUB_DISTANCE = 14
local MAX_DISTANCE = 60

local PITCH = math.rad(40) -- in a run the camera looks down on the lane at 40 degrees, not along the ground

local function zoomTo(distance, pitch, toward)
	-- forcing the minimum to the wanted distance moves the camera out at once; letting it go next frame keeps it there
	player.CameraMaxZoomDistance = math.max(MAX_DISTANCE, distance)
	player.CameraMinZoomDistance = distance
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if pitch and root and camera then
		-- tilt the follow camera down once; the default camera keeps the angle it is given after a scripted frame
		-- facing where the hero faces, or (at a wave's start) towards the wave
		local look = (toward and (toward - root.Position) or root.CFrame.LookVector) * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		local eye = root.Position - look * distance * math.cos(pitch) + Vector3.new(0, distance * math.sin(pitch), 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(eye, root.Position)
		RunService.RenderStepped:Wait()
		camera.CameraType = Enum.CameraType.Custom
	end
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
		-- (a run teleports the hero right after the state changes: wait for it to land)
		task.delay(inRun and 1.2 or 0, zoomTo, inRun and RUN_DISTANCE or HUB_DISTANCE, inRun and PITCH or nil)
	end
end


-- when a wave starts, turn the camera once (behind the hero) towards the monsters, so the wave is in frame:
-- on a phone they walked in far from the hero, off screen (cycle 6 film). The player can turn away freely.
local function enemyCentre()
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return nil
	end
	local sum, n = Vector3.zero, 0
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			sum += m:GetPivot().Position
			n += 1
		end
	end
	return n > 0 and sum / n or nil
end
GameState:GetAttributeChangedSignal("State"):Connect(function()
	if GameState:GetAttribute("State") ~= "Wave" then
		return
	end
	local centre
	for _ = 1, 20 do
		task.wait(0.25)
		centre = enemyCentre()
		if centre then
			break
		end
	end
	if centre then
		zoomTo(RUN_DISTANCE, PITCH, centre)
	end
end)GameState:GetAttributeChangedSignal("State"):Connect(update)
player.CharacterAdded:Connect(function()
	last = nil
	task.wait(0.5)
	update()
end)
update()
