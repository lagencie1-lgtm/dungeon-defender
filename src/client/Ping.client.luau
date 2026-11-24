-- A one-tap ping for playing together without voice (research report: a lane or target ping, a clear marker).
-- Only shown with two or more heroes in the game. Phone: the Ping button marks the ground at the middle of the
-- screen (where the camera looks). Controller: LS (left stick click) marks the spot in front of the hero.
-- Keyboard: G marks the ground under the mouse. Everyone sees a ring with the player's name for a few seconds.
-- 6A: one quiet ring, no sound storm, at most one ping a second (PingService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ground = require(ReplicatedStorage.Shared.Ground)
local Ui = require(script.Parent.Ui)
local Gamepad = Ui.Gamepad

local player = Players.LocalPlayer
local COLOR = Color3.fromRGB(120, 220, 255)
local SHOW = 4 -- seconds a ping stays
local BEADS = 14

-- where a ping from this device lands
local function aimPoint()
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local ray
	if Gamepad.active and root then
		-- the spot a few steps ahead of the hero
		local p = root.Position + root.CFrame.LookVector * 12
		return Vector3.new(p.X, (Ground.At(p.X, p.Z)), p.Z)
	elseif UserInputService.TouchEnabled and camera then
		local v = camera.ViewportSize
		ray = camera:ViewportPointToRay(v.X / 2, v.Y / 2)
	elseif camera then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	end
	if not ray then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	return hit and hit.Position or nil
end

local function send()
	local at = aimPoint()
	if at then
		Remotes.Ping:FireServer(at)
	end
end

-------------------------------------------------------------------------------
-- the button (phones), only with company
-------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PingHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = Ui.make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
Ui.fitRoot(gui, root, 930, 480) -- the same scale as the HUD's left column
local pingButton = Ui.button({ Name = "PingButton", Size = UDim2.fromOffset(64, 44), Position = UDim2.fromOffset(10, 226),
	Text = "Ping", BackgroundColor3 = Color3.fromRGB(45, 80, 100), Visible = false, Parent = root })
pingButton.Activated:Connect(send)
Gamepad.Hint(pingButton, Enum.KeyCode.ButtonL3, UDim2.new(1, -4, 0, 2))

local function company()
	local many = #Players:GetPlayers() >= 2
	pingButton.Visible = many and UserInputService.TouchEnabled
end
Players.PlayerAdded:Connect(company)
Players.PlayerRemoving:Connect(function()
	task.defer(company)
end)
company()

Gamepad.Bind("Ping", { Enum.KeyCode.ButtonL3 }, function()
	if #Players:GetPlayers() < 2 then
		return false
	end
	send()
	return true
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.G and #Players:GetPlayers() >= 2 then
		send()
	end
end)

-------------------------------------------------------------------------------
-- the marks
-------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "Pings"
folder.Parent = workspace
local marks = {} -- [userId] = { beads, tag, at, born }

local function clear(mark)
	for _, b in mark.beads do
		b:Destroy()
	end
	mark.tag:Destroy()
end

Remotes.Ping.OnClientEvent:Connect(function(userId, name, at)
	if marks[userId] then
		clear(marks[userId])
	end
	local mark = { beads = {}, at = at, born = os.clock() }
	for i = 1, BEADS do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 0.5
		p.Material = Enum.Material.Neon
		p.Color = COLOR
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = false
		p.Parent = folder
		mark.beads[i] = p
	end
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Position = at + Vector3.new(0, 4, 0)
	anchor.Parent = folder
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 24)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 400
	tag.Parent = anchor
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = name, TextColor3 = COLOR, TextStrokeTransparency = 0.2, Parent = tag })
	mark.tag = anchor
	marks[userId] = mark
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for userId, mark in marks do
		local age = now - mark.born
		if age > SHOW then
			clear(mark)
			marks[userId] = nil
			continue
		end
		-- grows in quickly (eased, settles), turns slowly, fades in the last second
		local grow = 1 - math.exp(-8 * age)
		local fade = math.clamp(SHOW - age, 0, 1)
		for i, b in mark.beads do
			local a = now * 0.7 + i / #mark.beads * math.pi * 2
			b.Position = mark.at + Vector3.new(math.cos(a) * 3.2 * grow, 0.4, math.sin(a) * 3.2 * grow)
			b.Transparency = 1 - 0.8 * fade
		end
	end
end)
