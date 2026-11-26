-- The camera at the start of a run: tower defense is played by watching the lane, so the camera starts high and
-- far enough to see the defenders and the wave around the hero (the phone film showed a 12-stud follow camera with
-- the wave off screen). The player can still zoom in and out as they like; this only sets where it starts.
-- In the hub the camera goes back to a normal walking distance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = ReplicatedStorage:WaitForChild("GameState")
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer

local RUN_DISTANCE = Config.RunCamera.Distance -- studs from the hero in a run: the hero is 12-15% of the screen height (film rig measures it)
local HUB_DISTANCE = 14
local MAX_DISTANCE = 60

local PITCH = math.rad(Config.RunCamera.Pitch) -- in a run the camera looks down on the lane, not along the ground

local function zoomTo(distance, pitch, toward)
	-- forcing the minimum to the wanted distance moves the camera out at once; letting it go next frame keeps it there
	player.CameraMaxZoomDistance = math.max(MAX_DISTANCE, distance)
	player.CameraMinZoomDistance = distance
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local hum0 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum0 and not pitch then
		hum0.CameraOffset = Vector3.zero   -- (the hub: the normal aim)
	end
	if pitch and root and camera then
		-- tilt the follow camera down once; the default camera keeps the angle it is given after a scripted frame
		-- facing where the hero faces, or (at a wave's start) towards the wave
		local look = (toward and (toward - root.Position) or root.CFrame.LookVector) * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
		-- (aimed AimHeight above the hero: the follow camera keeps that through the humanoid's camera offset)
		local aimUp = Vector3.new(0, Config.RunCamera.AimHeight, 0)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = aimUp
		end
		local eye = root.Position + aimUp - look * distance * math.cos(pitch) + Vector3.new(0, distance * math.sin(pitch), 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(eye, root.Position + aimUp)
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

-- (Lemp 2026-11-26, option C2) while a wall the hero can see is under attack, the camera looks down WallTilt degrees
-- more, so the pile shows above the wall; springs in and out. The player's own camera moves stay theirs: each frame
-- only the change of the tilt is applied, about the camera's focus, after the camera has updated.
local tilt, tiltVel, applied = 0, 0, 0
local function wallUnderAttack()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local towers = workspace:FindFirstChild("Towers")
	local enemies = workspace:FindFirstChild("Enemies")
	if not (root and camera and towers and enemies) then
		return false
	end
	for _, wall in towers:GetChildren() do
		if wall:IsA("Model") and wall:GetAttribute("TowerType") == "Barricade" and not wall:GetAttribute("Broken") then
			local at = wall:GetPivot().Position
			local _, onScreen = camera:WorldToViewportPoint(at)
			if onScreen and (at - root.Position).Magnitude < Config.RunCamera.WallRange then
				for _, m in enemies:GetChildren() do
					if m:GetAttribute("PileRow") ~= nil and m:GetAttribute("Bashing")
						and (m:GetPivot().Position - at).Magnitude < 20 then
						return true
					end
				end
			end
		end
	end
	return false
end
local nextCheck, attacked = 0, false
RunService:BindToRenderStep("WallTilt", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + 0.25
		local state = GameState:GetAttribute("State")
		attacked = (state == "Break" or state == "Wave") and wallUnderAttack()
	end
	local goal = attacked and Config.RunCamera.WallTilt or 0
	local w = 2 * math.pi / Config.RunCamera.TiltTime * 0.6
	tiltVel += ((goal - tilt) * w * w - tiltVel * 2 * 0.9 * w) * dt
	tilt += tiltVel * dt
	local delta = tilt - applied
	if math.abs(delta) < 1e-3 then
		return
	end
	applied = tilt
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local right = camera.CFrame.RightVector
	-- (down more: the eye swings up about the focus; never past straight down)
	local turned = CFrame.fromAxisAngle(right, math.rad(-delta)) * offset
	if turned.Unit.Y < 0.97 then
		camera.CFrame = CFrame.lookAt(focus + turned, focus)
	end
end)
player.CharacterAdded:Connect(function()
	last = nil
	task.wait(0.5)
	update()
end)
update()
