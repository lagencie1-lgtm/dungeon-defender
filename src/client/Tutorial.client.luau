-- A short first-minute guide for new players: one hint at a time and a
-- bouncing arrow showing where to go. Ends after the first wave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label = Ui.make, Ui.corner, Ui.stroke, Ui.label

local player = Players.LocalPlayer
local GameState = ReplicatedStorage:WaitForChild("GameState")
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- wait until we know if this player is new
local waited = 0
while player:GetAttribute("TutorialDone") == nil and waited < 20 do
	task.wait(0.5)
	waited += 0.5
end
if player:GetAttribute("TutorialDone") ~= false then
	return
end

local gui = make("ScreenGui", { Name = "TutorialHud", ResetOnSpawn = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
local box = make("Frame", { Size = UDim2.fromOffset(520, 64), Position = UDim2.new(0.5, 0, 0.2, 0), AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Ui.DARK, BackgroundTransparency = 0.1, Parent = gui }, { corner(14), stroke(Ui.GOLD, 3) })
local hint = label({ Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), Text = "", TextWrapped = true, Parent = box })
make("UIScale", { Scale = isTouch and 0.8 or 1, Parent = box })

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
end

RunService.RenderStepped:Connect(function()
	if arrowTarget then
		local t = os.clock()
		arrow.Transparency = 0
		arrow.CFrame = CFrame.new(arrowTarget + Vector3.new(0, 7 + math.sin(t * 4), 0)) * CFrame.Angles(math.pi, t * 2, 0)
	else
		arrow.Transparency = 1
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
		show(isTouch and "Welcome, hero! Walk to the glowing circle and tap Start run" or
			"Welcome, hero! Walk to the glowing circle and press E to start a run", pad and pad.Position)
	elseif s == "Break" and wave == 0 and myTowers() == 0 then
		show(isTouch and "Tap Ranger at the bottom, tap near the arrow, then Build here" or
			"Press 1 (or click Ranger), then click near the arrow to build", goodSpot())
	elseif s == "Break" and wave == 0 then
		show("Nice! Build a few more if you like, then press Start wave now", nil)
	elseif s == "Wave" and wave == 1 then
		show(isTouch and "Goblins! Run to them and tap Sword to hit them" or "Goblins! Run to them and press F to hit them (E and R are big attacks)", nil)
	elseif (s == "Break" and wave >= 1) or s == "Won" or s == "Lost" then
		show("You've got it! Kill goblins, grab loot, upgrade gear at the Blacksmith. Have fun!", nil)
		task.wait(6)
		finished = true
	end
	task.wait(0.3)
end
Remotes.FinishTutorial:FireServer()
arrow:Destroy()
gui:Destroy()
