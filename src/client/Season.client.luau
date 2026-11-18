-- The Season screen (battle pass): your season level, and a free and a paid
-- reward on every level to claim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Store = require(ReplicatedStorage.Shared.Store)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local S = Store.Season

local gui = make("ScreenGui", { Name = "SeasonHud", ResetOnSpawn = false, DisplayOrder = 3,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local rootScale = make("UIScale", { Parent = root })
local function fitScreen()
	local size = camera.ViewportSize
	local s = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.3)
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen)
fitScreen()

local seasonButton, dot = require(script.Parent.Menu).Add("Season", "Season", 7)

local panel = make("Frame", { Size = UDim2.fromOffset(900, 400), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 30, Parent = root },
	{ corner(18), stroke(Color3.fromRGB(255, 120, 200), 3) })
label({ Size = UDim2.fromOffset(500, 34), Position = UDim2.fromOffset(16, 10), Text = S.Name,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local levelLabel = label({ Size = UDim2.fromOffset(400, 22), Position = UDim2.fromOffset(16, 48), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local barBack = make("Frame", { Size = UDim2.fromOffset(400, 10), Position = UDim2.fromOffset(16, 76),
	BackgroundColor3 = Color3.fromRGB(50, 45, 60), ZIndex = 31, Parent = panel }, { corner(4) })
local bar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 120, 200), ZIndex = 32, Parent = barBack },
	{ corner(4) })
local passLabel = label({ Size = UDim2.fromOffset(360, 22), Position = UDim2.new(1, -70, 0, 50), AnchorPoint = Vector2.new(1, 0),
	Text = "", TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })
label({ Size = UDim2.fromOffset(60, 20), Position = UDim2.fromOffset(16, 150), Text = "FREE", Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(120, 255, 160), ZIndex = 31, Parent = panel })
label({ Size = UDim2.fromOffset(60, 20), Position = UDim2.fromOffset(16, 266), Text = "PASS", Font = Enum.Font.GothamBlack,
	TextColor3 = Ui.GOLD, ZIndex = 31, Parent = panel })

local strip = make("ScrollingFrame", { Size = UDim2.new(1, -100, 0, 290), Position = UDim2.fromOffset(84, 98),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 31, Parent = panel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })

local function rewardText(r)
	if r.Kind == "Gems" then
		return r.Amount .. " gems"
	elseif r.Kind == "Gold" then
		return r.Amount .. " gold"
	elseif r.Kind == "Skin" then
		return (Store.Skins[r.Id] and Store.Skins[r.Id].Name or r.Id) .. " skin"
	elseif r.Kind == "Title" then
		local t = Config.FindById(Config.Titles, r.Id)
		return "Title: " .. (t and t.Name or r.Id)
	end
	return "?"
end

local state = nil

local function rewardBox(column, reward, level, track, y)
	local claimed = state and (track == "Paid" and state.PaidClaimed[tostring(level)] or track == "Free" and state.Free[tostring(level)])
	local reached = state and state.Level >= level
	local locked = track == "Paid" and not (state and state.Paid)
	local box = make("Frame", { Size = UDim2.fromOffset(110, 108), Position = UDim2.fromOffset(0, y), ZIndex = 32,
		BackgroundColor3 = reward.Kind == "Skin" and Color3.fromRGB(80, 50, 110) or Ui.PANEL, Parent = column },
		{ corner(10), stroke(track == "Paid" and Ui.GOLD or Color3.fromRGB(120, 255, 160), 1) })
	label({ Size = UDim2.new(1, -8, 0, 52), Position = UDim2.fromOffset(4, 6), Text = rewardText(reward), TextWrapped = true,
		ZIndex = 33, Parent = box })
	local b = button({ Size = UDim2.new(1, -12, 0, 36), Position = UDim2.new(0, 6, 1, -42), ZIndex = 33, Parent = box,
		Text = claimed and "Got it" or (not reached and "Lv " .. level) or (locked and "Pass") or "Claim",
		BackgroundColor3 = (reached and not claimed and not locked) and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(70, 70, 80) })
	b.Activated:Connect(function()
		local ok = Remotes.ClaimSeason:InvokeServer(level, track)
		if ok then
			Ui.playSound("Coin")
		end
	end)
end

local function refresh()
	if not state then
		return
	end
	levelLabel.Text = "Season level " .. state.Level .. " / " .. S.Levels .. " · " .. state.Xp .. "/" .. S.XpPerLevel
		.. " pass xp (waves, wins and quests)"
	bar.Size = UDim2.fromScale(state.Level >= S.Levels and 1 or math.clamp(state.Xp / S.XpPerLevel, 0, 1), 1)
	passLabel.Text = state.Paid and "Season Pass: active" or "Get the Season Pass in Shop > Robux"
	for _, child in strip:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for level = 1, S.Levels do
		local free, paid = Store.SeasonReward(level)
		local column = make("Frame", { Size = UDim2.fromOffset(110, 270), BackgroundTransparency = 1, LayoutOrder = level,
			ZIndex = 31, Parent = strip })
		label({ Size = UDim2.new(1, 0, 0, 20), Text = "Level " .. level, Font = Enum.Font.GothamBold,
			TextColor3 = state.Level >= level and Color3.new(1, 1, 1) or Ui.TEXT_DIM, ZIndex = 32, Parent = column })
		rewardBox(column, free, level, "Free", 26)
		rewardBox(column, paid, level, "Paid", 142)
	end
end

Remotes.Season.OnClientEvent:Connect(function(s)
	state = s
	if panel.Visible then
		refresh()
	end
end)
player:GetAttributeChangedSignal("SeasonReady"):Connect(function()
	dot.Visible = (player:GetAttribute("SeasonReady") or 0) > 0
end)

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		state = Remotes.GetSeason:InvokeServer() or state
		Ui.pop(panel, 0.85)
		refresh()
	end
end
seasonButton.Activated:Connect(toggle)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Q then
		panel.Visible = false
	end
end)
