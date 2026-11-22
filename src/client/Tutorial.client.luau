-- A short first-minute guide for new players: one hint at a time and a
-- bouncing arrow showing where to go. Ends after the first wave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label = Ui.make, Ui.corner, Ui.stroke, Ui.label

local player = Players.LocalPlayer
local GameState = ReplicatedStorage:WaitForChild("GameState")
local isTouch = Ui.isTouch

-- wait until we know if this player is new
local waited = 0
while player:GetAttribute("TutorialDone") == nil and waited < 20 do
	task.wait(0.5)
	waited += 0.5
end
if player:GetAttribute("TutorialDone") ~= false then
	return
end

local gui = make("ScreenGui", { Name = "TutorialHud", ResetOnSpawn = false, DisplayOrder = 5,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, Parent = player:WaitForChild("PlayerGui") })
local Gamepad = Ui.Gamepad
-- the hint in the words of the device in use: a controller, a phone, or a keyboard and mouse
local function pick(pad, touch, pc)
	if Gamepad.active then
		return pad
	end
	return isTouch and touch or pc
end
local function key(keyCode)
	return Gamepad.Name(keyCode)
end
local box = make("Frame", { Size = UDim2.new(isTouch and 0.23 or 0.6, 0, 0, isTouch and 52 or 56),
	Position = isTouch and UDim2.new(0, 8, 0.42, 0) or UDim2.new(0.5, 0, 1, -150),
	AnchorPoint = isTouch and Vector2.zero or Vector2.new(0.5, 1),
	BackgroundColor3 = Ui.DARK, BackgroundTransparency = 0.1, Parent = gui }, { corner(14), stroke(Ui.GOLD, 3) })
local hint = label({ Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), Text = "", TextWrapped = true, Parent = box })

-- the arrow floating over the place to go
local arrow = make("Part", { Name = "TutorialArrow", Size = Vector3.new(3, 4, 1), Anchored = true, CanCollide = false, CanQuery = false,
	CanTouch = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 60), Transparency = 1, Parent = workspace })
make("SpecialMesh", { MeshType = Enum.MeshType.Wedge, Scale = Vector3.new(1, 1, 1), Parent = arrow })
local arrowTarget = nil

local function show(text, target)
	if hint.Text ~= text then
		hint.Text = text
		Ui.pop(box, 1.1)
	end
	arrowTarget = target
	arrow.Transparency = target and 0 or 1
end

local animateArrow = RunService.RenderStepped:Connect(function()
	if arrowTarget then
		local t = os.clock()
		arrow.CFrame = CFrame.new(arrowTarget + Vector3.new(0, 7 + math.sin(t * 4), 0)) * CFrame.Angles(math.pi, t * 2, 0)
	end
end)

-- a good first spot for a Ranger: next to the first bend of the path
local function goodSpot()
	local a, b = Config.Path[2], Config.Path[3]
	local dir = (b - a).Unit
	return a:Lerp(b, 0.3) + Vector3.new(-dir.Z, 0, dir.X) * 11
end

local function myTowers()
	local n = 0
	local towers = workspace:FindFirstChild("Towers")
	if towers then
		for _, t in towers:GetChildren() do
			if t:GetAttribute("Owner") == player.UserId then
				n += 1
			end
		end
	end
	return n
end

local finished = false
while not finished do
	local s = GameState:GetAttribute("State")
	local wave = GameState:GetAttribute("Wave") or 0
	if s == "Lobby" then
		local pad = workspace:FindFirstChild("Outpost") and workspace.Outpost:FindFirstChild("StartPad")
		show(pick("Welcome, hero! Walk to the glowing circle to start a run", "Tap Start run or walk to the portal",
			"Welcome, hero! Walk to the glowing circle and press E to start a run"), pad and pad.Position)
	elseif s == "Break" and wave == 0 and myTowers() == 0 then
		show(pick("Press " .. key(Enum.KeyCode.ButtonX) .. " for a Ranger, walk to the arrow, then press " .. key(Enum.KeyCode.ButtonA),
			"Tap Ranger, tap by the arrow, then tap Build here",
			"Press 1 (or click Ranger), then click near the arrow to build"), goodSpot())
	elseif s == "Break" and wave == 0 then
		show(pick("Nice! Build a few more if you like, then press " .. key(Enum.KeyCode.ButtonL2) .. " to start the wave",
			"Tap Start wave when ready", "Nice! Build a few more if you like, then press Start wave now"), nil)
	elseif s == "Wave" and wave == 1 then
		show(pick("Goblins! Run to them and press " .. key(Enum.KeyCode.ButtonR2) .. " to hit them ("
			.. key(Enum.KeyCode.ButtonR1) .. " and " .. key(Enum.KeyCode.ButtonL1) .. " are big attacks)",
			"Goblins! Run to them and tap Sword to hit them",
			"Goblins! Run to them and press F to hit them (E and R are big attacks)"), nil)
	elseif (s == "Break" and wave >= 1) or s == "Won" or s == "Lost" then
		show("You've got it! Kill goblins, grab loot, upgrade gear at the Blacksmith. Have fun!", nil)
		task.wait(6)
		finished = true
	end
	task.wait(0.3)
end
Remotes.FinishTutorial:FireServer()
animateArrow:Disconnect()
arrow:Destroy()
gui:Destroy()
