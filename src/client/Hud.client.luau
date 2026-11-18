-- The game screen on each player's computer or phone: gold, waves, portal
-- health, defender buttons, placing/upgrading/selling, hero abilities, shop,
-- daily reward, banners, combos and screen shake.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Memes = require(ReplicatedStorage.Shared.Memes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local Store = require(ReplicatedStorage.Shared.Store)
local MarketplaceService = game:GetService("MarketplaceService")
local GameState = ReplicatedStorage:WaitForChild("GameState")

workspace:WaitForChild("Map"):WaitForChild("Ground")
workspace:WaitForChild("Towers")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

-- phones and tablets get bigger buttons in different places
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-------------------------------------------------------------------------------
-- the screen, scaled to fit any size (phones get everything a bit smaller)
-------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "RealmGuardiansHud",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
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

-- red flash over the whole screen when the portal is hit
local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	BackgroundTransparency = 1, ZIndex = 50, Active = false, Parent = gui })

-------------------------------------------------------------------------------
-- top bar: wave, gold, portal health
-------------------------------------------------------------------------------
local top = make("Frame", {
	Size = UDim2.fromOffset(600, 64),
	Position = UDim2.new(0.5, 0, 0, 8),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.15,
	Parent = root,
}, { corner(14), stroke() })

local waveLabel = label({ Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(14, 6), Text = "Wave 0/10",
	TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local stateLabel = label({ Size = UDim2.fromOffset(180, 20), Position = UDim2.fromOffset(14, 38), Text = "",
	TextColor3 = Ui.TEXT_DIM, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local goldLabel = label({ Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(200, 6), Text = "200 mana",
	TextColor3 = Ui.MANA, Parent = top })
local buildLabel = label({ Size = UDim2.fromOffset(150, 18), Position = UDim2.fromOffset(200, 40), Text = "Build 0/30",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, Parent = top })
label({ Size = UDim2.fromOffset(220, 16), Position = UDim2.fromOffset(366, 6), Text = "Portal",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 170, 255), Parent = top })
local portalBack = make("Frame", { Size = UDim2.fromOffset(220, 24), Position = UDim2.fromOffset(366, 26),
	BackgroundColor3 = Color3.fromRGB(50, 30, 40), Parent = top }, { corner(6) })
local portalFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 90, 255),
	Parent = portalBack }, { corner(6) })
local portalText = label({ Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.08), Text = "100 / 100",
	ZIndex = 2, Parent = portalBack })

-- start wave + speed buttons under the bar
local controls = make("Frame", {
	Size = UDim2.fromOffset(420, 44),
	Position = UDim2.new(0.5, 0, 0, 80),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local startButton = button({ Size = UDim2.fromOffset(210, 44), BackgroundColor3 = Color3.fromRGB(160, 60, 40),
	Text = "Start wave now", LayoutOrder = 1, Parent = controls })
local speedButton = button({ Size = UDim2.fromOffset(110, 44), BackgroundColor3 = Color3.fromRGB(50, 90, 140),
	Text = "Speed 1x", LayoutOrder = 2, Parent = controls })

-- difficulty picker, only before the first wave
local diffPanel = make("Frame", {
	Size = UDim2.fromOffset(#Config.Difficulties * 156 + 12, 92),
	Position = UDim2.new(0.5, 0, 0, 132),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.15,
	Parent = root,
}, { corner(12), stroke() })
label({ Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 4), Text = "Pick a difficulty",
	Parent = diffPanel })
local diffButtons = {}
for i, diff in Config.Difficulties do
	local b = button({ Size = UDim2.fromOffset(148, 56), Position = UDim2.fromOffset(10 + (i - 1) * 156, 30),
		Text = "", BackgroundColor3 = Ui.PANEL, Parent = diffPanel })
	label({ Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 4), Text = diff.Name,
		TextColor3 = diff.Color, Parent = b })
	label({ Name = "Sub", Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 32),
		Text = diff.Subtitle .. " · gems x" .. diff.Gems, Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, Parent = b })
	b.Activated:Connect(function()
		Remotes.PickDifficulty:FireServer(diff.Id)
	end)
	diffButtons[diff.Id] = b
end

-------------------------------------------------------------------------------
-- left side: gems, shop, daily reward
-------------------------------------------------------------------------------
local Menu = require(script.Parent.Menu)
local shopButton = Menu.Add("Shop", "Shop", 1)
local dailyButton, dailyDot = Menu.Add("Daily", "Daily", 2)
local Icons = require(script.Parent.Icons)
local gemsLabel = label({ Size = UDim2.fromOffset(1, 1), Text = "", Visible = false, Parent = root }) -- gems show in the wallet now

-------------------------------------------------------------------------------
-- messages, banners and combo counter
-------------------------------------------------------------------------------
local messages = make("Frame", {
	Size = UDim2.fromOffset(640, 170),
	Position = UDim2.new(0.5, 0, 0, 232),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }) })

local function showMessage(text, color)
	local l = label({ Size = UDim2.fromOffset(640, 28), Text = text, TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2, Parent = messages })
	Ui.pop(l, 1.15)
	task.delay(3.2, function()
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.6)
		l:Destroy()
	end)
	local count = 0
	for _, child in messages:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in messages:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end
Remotes.Notify.OnClientEvent:Connect(showMessage)

local banner = make("Frame", {
	Size = UDim2.fromOffset(800, 130),
	Position = UDim2.fromScale(0.5, 0.36),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = root,
})
local bannerTitle = label({ Size = UDim2.new(1, 0, 0, 80), Text = "", Font = Enum.Font.GothamBlack,
	TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(40, 10, 50), Parent = banner })
local bannerSub = label({ Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 84), Text = "",
	TextColor3 = Color3.fromRGB(255, 230, 180), TextStrokeTransparency = 0.2, Parent = banner })
local bannerToken = 0

local function showBanner(title, subtitle, color)
	bannerToken += 1
	local my = bannerToken
	banner.Visible = true
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color or Color3.new(1, 1, 1)
	bannerSub.Text = subtitle or ""
	bannerTitle.TextTransparency = 0
	bannerSub.TextTransparency = 0
	bannerTitle.TextStrokeTransparency = 0
	banner.Position = UDim2.fromScale(0.5, 0.3)
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.36) }):Play()
	Ui.pop(banner, 1.4)
	task.delay(2.4, function()
		if my ~= bannerToken then
			return
		end
		TweenService:Create(bannerTitle, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(bannerSub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.5)
		if my == bannerToken then
			banner.Visible = false
		end
	end)
end

local comboLabel = label({
	Size = UDim2.fromOffset(300, 46),
	Position = UDim2.new(1, -20, 0, isTouch and 80 or 150),
	AnchorPoint = Vector2.new(1, 0),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	TextStrokeTransparency = 0,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = root,
})
local comboShout = label({
	Size = UDim2.fromOffset(420, 30),
	Position = UDim2.new(1, -20, 0, isTouch and 128 or 198),
	AnchorPoint = Vector2.new(1, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 140, 220),
	TextStrokeTransparency = 0.1,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = root,
})

-------------------------------------------------------------------------------
-- screen shake
-------------------------------------------------------------------------------
local shakeAmount = 0
local function shake(amount)
	shakeAmount = math.max(shakeAmount, amount)
end
RunService.RenderStepped:Connect(function(dt)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if shakeAmount > 0.01 then
		local function r()
			return (math.random() - 0.5) * 2 * shakeAmount * 0.35
		end
		humanoid.CameraOffset = Vector3.new(r(), r(), r())
		shakeAmount = math.max(0, shakeAmount - dt * 3)
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end
end)

-------------------------------------------------------------------------------
-- defender buttons (bottom middle)
-------------------------------------------------------------------------------
local BUTTON_W = 112
local towerBar = make("Frame", {
	Size = UDim2.fromOffset(#Config.TowerOrder * (BUTTON_W + 8), 100),
	Position = UDim2.new(0.5, 0, 1, isTouch and -14 or -10),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom }) })

local owned = { Swords = {}, Titles = {}, Towers = {} }
local towerButtons = {}
for i, towerType in Config.TowerOrder do
	local info = Config.Towers[towerType]
	local b = button({ Size = UDim2.fromOffset(BUTTON_W, 100), Text = "", LayoutOrder = i, Parent = towerBar })
	make("Frame", { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = info.Color,
		Parent = b }, { corner(3) })
	label({ Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 18), Text = info.DisplayName, Parent = b })
	local cost = label({ Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 40),
		Text = info.Cost .. " mana · " .. (Config.BuildPoints[towerType] or 0) .. " bp",
		TextColor3 = Ui.MANA, Parent = b })
	label({ Size = UDim2.new(1, -10, 0, 32), Position = UDim2.fromOffset(5, 62), Text = info.Description,
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextWrapped = true, Parent = b })
	if not isTouch then
		label({ Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -18, 0, -8), Text = tostring(i),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(90, 70, 130), ZIndex = 3, Parent = b }, {})
	end
	local lock = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 4, Parent = b }, { corner(10) })
	Icons.Draw(lock, "Lock", Color3.fromRGB(230, 200, 140), { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, -15, 0, 18), ZIndex = 5 })
	label({ Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 56),
		Text = (info.UnlockGems or 0) .. " gems", TextColor3 = Ui.GEM, ZIndex = 5, Parent = lock })
	towerButtons[towerType] = { button = b, cost = cost, lock = lock }
end

local function isUnlocked(towerType)
	local info = Config.Towers[towerType]
	return not info.UnlockGems or owned.Towers[towerType] == true
end

-------------------------------------------------------------------------------
-- hero panel and ability buttons
-------------------------------------------------------------------------------
local heroPanel = make("Frame", {
	Size = UDim2.fromOffset(230, 52),
	Position = isTouch and UDim2.fromOffset(170, 70) or UDim2.new(0, 10, 1, -132),
	AnchorPoint = Vector2.new(0, 0),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.15,
	Parent = root,
}, { corner(12), stroke() })
local heroName = label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 4),
	Text = Config.Hero.Name .. "  Lv 1", TextXAlignment = Enum.TextXAlignment.Left, Parent = heroPanel })
local xpBack = make("Frame", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 34),
	BackgroundColor3 = Color3.fromRGB(50, 45, 60), Parent = heroPanel }, { corner(4) })
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 200, 255),
	Parent = xpBack }, { corner(4) })

local abilityHolder
if isTouch then
	-- a column on the right, above the jump button
	abilityHolder = make("Frame", {
		Size = UDim2.fromOffset(96, 320),
		Position = UDim2.new(1, -16, 1, -150),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	}, { make("UIListLayout", { Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
else
	abilityHolder = make("Frame", {
		Size = UDim2.fromOffset(230, 64),
		Position = UDim2.new(0, 10, 1, -64),
		BackgroundTransparency = 1,
		Parent = root,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
end

local function abilityButton(text, key, order)
	local size = isTouch and UDim2.fromOffset(92, 92) or UDim2.fromOffset(71, 58)
	local b = button({ Size = size, Text = "", LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(70, 50, 100),
		Parent = abilityHolder })
	if isTouch then
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end
	local nameLabel = label({ Size = UDim2.new(1, -8, 0.45, 0), Position = UDim2.fromScale(0, 0.12), AnchorPoint = Vector2.new(0, 0),
		Text = text, Parent = b })
	if not isTouch then
		label({ Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -20), Text = "[" .. key .. "]",
			Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, Parent = b })
	end
	local shade = make("Frame", { Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Parent = b },
		{ corner(isTouch and 46 or 8) })
	return b, shade, nameLabel
end
local attackButton, attackShade, attackName = abilityButton("Sword", "F", 3)
local whirlButton, whirlShade, whirlName = abilityButton("Whirl", "E", 2)
local leapButton, leapShade, leapName = abilityButton("Leap", "R", 1)
if not isTouch then
	-- on PC the order left to right is Sword, Whirl, Leap
	attackButton.LayoutOrder, whirlButton.LayoutOrder, leapButton.LayoutOrder = 1, 2, 3
end

-------------------------------------------------------------------------------
-- defender info panel (shows when you click one of your defenders)
-------------------------------------------------------------------------------
local infoPanel = make("Frame", {
	Size = UDim2.fromOffset(240, 176),
	Position = isTouch and UDim2.new(1, -124, 0.42, 0) or UDim2.new(1, -10, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = root,
}, { corner(12), stroke() })
local infoTitle = label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 8), Text = "", Parent = infoPanel })
local infoStats = label({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 36), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextWrapped = true, Parent = infoPanel })
local upgradeButton = button({ Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 82),
	BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Upgrade", Parent = infoPanel })
local sellButton = button({ Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 128),
	BackgroundColor3 = Color3.fromRGB(140, 50, 50), Text = "Sell", Parent = infoPanel })

-- phones: confirm where to build
local confirmBar = make("Frame", {
	Size = UDim2.fromOffset(330, 54),
	Position = UDim2.new(0.5, 0, 1, -130),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = root,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local confirmButton = button({ Size = UDim2.fromOffset(200, 54), BackgroundColor3 = Color3.fromRGB(60, 140, 60),
	Text = "Build here", LayoutOrder = 1, Parent = confirmBar })
local cancelButton = button({ Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromRGB(140, 50, 50),
	Text = "Cancel", LayoutOrder = 2, Parent = confirmBar })
local tapHint = label({ Size = UDim2.fromOffset(400, 26), Position = UDim2.new(0.5, 0, 1, -190), AnchorPoint = Vector2.new(0.5, 1),
	Text = "Tap the ground where it should go", TextStrokeTransparency = 0.3, Visible = false, Parent = root })

-------------------------------------------------------------------------------
-- in the hub: start a run and pick a map
-------------------------------------------------------------------------------
local lobbyBar = make("Frame", {
	Size = UDim2.fromOffset(520, 60),
	Position = UDim2.new(0.5, 0, 1, isTouch and -14 or -12),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = root,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local runButton = button({ Size = UDim2.fromOffset(240, 60), BackgroundColor3 = Color3.fromRGB(110, 60, 190),
	Text = "Start run", LayoutOrder = 1, Parent = lobbyBar })
local eventInfo = Config.WeeklyEvent()
local eventLabel = label({ Size = UDim2.fromOffset(760, 24), Position = UDim2.new(0.5, 0, 1, -80), AnchorPoint = Vector2.new(0.5, 1),
	Text = "This week: " .. eventInfo.Name .. " · " .. eventInfo.Text, Visible = false,
	TextColor3 = Color3.fromRGB(255, 200, 120), TextStrokeTransparency = 0.2, Parent = root })
local mapButton = button({ Size = UDim2.fromOffset(260, 60), BackgroundColor3 = Color3.fromRGB(120, 80, 40),
	Text = "Map and difficulty", LayoutOrder = 2, Parent = lobbyBar })

local mapPanel = make("Frame", {
	Size = UDim2.fromOffset(900, 56 + math.max(#Config.MapOrder * 92, 32 + #Config.Modes * 42) + 120),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 20,
	Parent = root,
}, { corner(18), stroke(Color3.fromRGB(255, 160, 80), 3) })
label({ Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(16, 10), Text = "Choose a map",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = mapPanel })
local mapClose = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 21, Parent = mapPanel })
for i, mapId in Config.MapOrder do
	local info = Config.Maps[mapId]
	local b = button({ Size = UDim2.fromOffset(420, 86), Position = UDim2.fromOffset(16, 56 + (i - 1) * 92), Text = "",
		BackgroundColor3 = Ui.PANEL, ZIndex = 21, Parent = mapPanel })
	make("Frame", { Size = UDim2.new(0, 8, 1, -20), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = info.Color,
		ZIndex = 22, Parent = b }, { corner(4) })
	label({ Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(28, 6), Text = info.Name, TextColor3 = info.Color,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	label({ Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(28, 36), Text = info.Description,
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(28, 60),
		Text = string.format("Goblin health x%.2f · gems x%.1f · better loot +%d", info.Health, info.Gems, info.ItemLevel),
		Font = Enum.Font.Gotham, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	b.Activated:Connect(function()
		Remotes.PickMap:FireServer(mapId)
		mapPanel.Visible = false
	end)
end
-- modes under the maps
local MODES_TOP = 52
label({ Size = UDim2.fromOffset(434, 28), Position = UDim2.fromOffset(450, MODES_TOP), Text = "Mode",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = mapPanel })
local modeButtons = {}
for i, mode in Config.Modes do
	local b = button({ Size = UDim2.fromOffset(434, 36), Position = UDim2.fromOffset(450, MODES_TOP + 32 + (i - 1) * 42), Text = "",
		BackgroundColor3 = Ui.PANEL, ZIndex = 21, Parent = mapPanel })
	label({ Size = UDim2.new(0.42, -10, 1, -10), Position = UDim2.fromOffset(10, 5), Text = mode.Name,
		TextColor3 = mode.Challenge and Color3.fromRGB(255, 160, 90) or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	label({ Size = UDim2.new(0.58, -10, 1, -12), Position = UDim2.new(0.42, 0, 0, 6), Text = mode.Text,
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	b.Activated:Connect(function()
		Remotes.PickMode:FireServer(mode.Id)
	end)
	modeButtons[mode.Id] = b
end
-- difficulty lives here too, so it never covers the game
diffPanel.Parent = mapPanel
diffPanel.AnchorPoint = Vector2.zero
diffPanel.Position = UDim2.fromOffset(16, 56 + math.max(#Config.MapOrder * 92, 32 + #Config.Modes * 42) + 6)
diffPanel.BackgroundTransparency = 1
diffPanel.Visible = true

local function refreshModes()
	local current = GameState:GetAttribute("Mode") or "Campaign"
	for id, b in modeButtons do
		local st = b:FindFirstChildOfClass("UIStroke")
		st.Color = id == current and Ui.GOLD or Color3.fromRGB(200, 160, 80)
		st.Thickness = id == current and 4 or 2
	end
end
GameState:GetAttributeChangedSignal("Mode"):Connect(refreshModes)
refreshModes()

mapButton.Activated:Connect(function()
	mapPanel.Visible = not mapPanel.Visible
end)
mapClose.Activated:Connect(function()
	mapPanel.Visible = false
end)
runButton.Activated:Connect(function()
	Remotes.StartRun:FireServer()
end)

-------------------------------------------------------------------------------
-- the next goal: always one clear thing to do next
-------------------------------------------------------------------------------
local goalLabel = label({ Size = UDim2.fromOffset(760, 22), Position = UDim2.new(0.5, 0, 1, -112), AnchorPoint = Vector2.new(0.5, 1),
	Text = "", TextColor3 = Color3.fromRGB(255, 235, 190), TextStrokeTransparency = 0.25, Parent = root })

local function nextGoal()
	local s = GameState:GetAttribute("State")
	local mapId = GameState:GetAttribute("Map") or "CursedForest"
	local mapInfo = Config.Maps[mapId] or Config.Maps.CursedForest
	if s == "Lobby" then
		local free = player:GetAttribute("StatPointsFree") or 0
		if free > 0 then
			return "Next: spend your " .. free .. " stat point" .. (free == 1 and "" or "s") .. " (Heroes)"
		end
		if (player:GetAttribute("Wins") or 0) == 0 then
			return "Next: win your first run (it unlocks the Machine Engineer)"
		end
		local cleared = {}
		pcall(function()
			cleared = HttpService:JSONDecode(player:GetAttribute("Cleared") or "{}")[mapId] or {}
		end)
		for _, d in Config.Difficulties do
			if d.Id ~= "Easy" and not cleared[d.Id] then
				local unlocks = nil
				for _, other in Config.Difficulties do
					if other.Unlock == d.Id then
						unlocks = other.Name
					end
				end
				return "Next: beat " .. mapInfo.Name .. " on " .. d.Name .. (unlocks and (" to unlock " .. unlocks) or "")
			end
		end
		return "Next: try another map, or see how far you get in Endless"
	elseif s == "Break" or s == "Wave" then
		local wave = GameState:GetAttribute("Wave") or 0
		local maxWave = GameState:GetAttribute("MaxWave") or 10
		if maxWave == 0 then
			return "Goal: beat your best Endless wave (" .. (player:GetAttribute("BestEndless") or 0) .. ")"
		end
		if wave >= maxWave then
			return "Goal: defeat the boss!"
		end
		return "Goal: survive " .. maxWave .. " waves, then defeat the boss"
	end
	return ""
end

-------------------------------------------------------------------------------
-- end screen
-------------------------------------------------------------------------------
local endPanel = make("Frame", {
	Size = UDim2.fromOffset(460, 270),
	Position = UDim2.fromScale(0.5, 0.48),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 10,
	Parent = root,
}, { corner(18), stroke(Ui.GOLD, 3) })
local endTitle = label({ Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 12), Text = "",
	Font = Enum.Font.GothamBlack, ZIndex = 11, Parent = endPanel })
local endMeme = label({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 84), Text = "",
	TextColor3 = Color3.fromRGB(255, 160, 230), ZIndex = 11, Parent = endPanel })
local endText = label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 118), Text = "",
	Font = Enum.Font.Gotham, ZIndex = 11, Parent = endPanel })
local endGems = label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 148), Text = "",
	TextColor3 = Ui.GEM, ZIndex = 11, Parent = endPanel })
local playAgainButton = button({ Size = UDim2.fromOffset(240, 54), Position = UDim2.new(0.5, 0, 1, -18),
	AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(100, 60, 170), Text = "Back to the Outpost", ZIndex = 11,
	Parent = endPanel })

-------------------------------------------------------------------------------
-- shop
-------------------------------------------------------------------------------
local shopPanel = make("Frame", {
	Size = UDim2.fromOffset(780, 480),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 20,
	Parent = root,
}, { corner(18), stroke(Ui.GEM, 3) })
label({ Size = UDim2.new(1, -120, 0, 36), Position = UDim2.fromOffset(16, 10), Text = "Shop",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = shopPanel })
local shopGems = label({ Size = UDim2.fromOffset(200, 30), Position = UDim2.new(1, -70, 0, 14), AnchorPoint = Vector2.new(1, 0),
	Text = "0 gems", TextColor3 = Ui.GEM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21, Parent = shopPanel })
local shopClose = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 21, Parent = shopPanel })
local tabBar = make("Frame", { Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 56),
	BackgroundTransparency = 1, ZIndex = 21, Parent = shopPanel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -32, 1, -116),
	Position = UDim2.fromOffset(16, 104),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 21,
	Parent = shopPanel,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local shopTab = "Towers"
local TABS = { { Id = "Towers", Name = "Defenders" }, { Id = "Swords", Name = "Swords" }, { Id = "Titles", Name = "Titles" },
	{ Id = "Skins", Name = "Skins" }, { Id = "Robux", Name = "Robux" }, { Id = "Codes", Name = "Codes" } }
local tabButtons = {}

local function shopItems(kind)
	local items = {}
	if kind == "Towers" then
		for _, towerType in Config.TowerOrder do
			local info = Config.Towers[towerType]
			if info.UnlockGems then
				table.insert(items, { Id = towerType, Name = info.DisplayName, Price = info.UnlockGems,
					Text = info.Description, Color = info.Color })
			end
		end
	elseif kind == "Swords" then
		for _, s in Config.Swords do
			table.insert(items, { Id = s.Id, Name = s.Name, Price = s.Price, Color = s.Color, RebirthOnly = s.RebirthOnly,
				Text = s.RebirthOnly and "Unlocked by your first Rebirth" or "A new look for your sword" })
		end
	else
		for _, t in Config.Titles do
			table.insert(items, { Id = t.Id, Name = t.Name, Price = t.Price, RebirthOnly = t.SeasonOnly,
				Text = t.SeasonOnly and "Season reward" or "Shows over your head",
				Color = Color3.fromRGB(255, 200, 90) })
		end
	end
	return items
end

local refreshShop -- defined below

local function rowFor(kind, item, order)
	local row = make("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = Ui.PANEL, LayoutOrder = order,
		ZIndex = 22, Parent = list }, { corner(10) })
	make("Frame", { Size = UDim2.fromOffset(10, 44), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = item.Color,
		ZIndex = 23, Parent = row }, { corner(4) })
	label({ Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(30, 8), Text = item.Name,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
	label({ Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(30, 38), Text = item.Text,
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })

	local isOwned = owned[kind] and owned[kind][item.Id] == true
	local equippedId = kind == "Swords" and player:GetAttribute("EquippedSword")
		or kind == "Titles" and player:GetAttribute("EquippedTitle") or nil
	local text, color
	if not isOwned and item.RebirthOnly then
		text, color = "Reward only", Color3.fromRGB(70, 70, 80)
	elseif not isOwned then
		text, color = "Buy " .. item.Price .. " gems", Color3.fromRGB(40, 120, 170)
	elseif kind == "Towers" then
		text, color = "Unlocked", Color3.fromRGB(60, 60, 70)
	elseif equippedId == item.Id then
		text, color = "Equipped", Color3.fromRGB(60, 60, 70)
	else
		text, color = "Equip", Color3.fromRGB(60, 130, 60)
	end
	local b = button({ Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		Text = text, BackgroundColor3 = color, ZIndex = 23, Parent = row })
	b.Activated:Connect(function()
		local ok, reason
		if not isOwned then
			ok, reason = Remotes.BuyItem:InvokeServer(kind, item.Id)
			if ok then
				showMessage("You got " .. item.Name .. "!", Ui.GEM)
				Ui.playSound("Coin")
			end
		elseif kind ~= "Towers" then
			ok, reason = Remotes.EquipItem:InvokeServer(kind, item.Id)
		end
		if ok == false then
			showMessage(reason or "Can't do that", Ui.BAD)
		end
		task.wait(0.15)
		refreshShop()
	end)
end

function refreshShop()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if shopTab == "Skins" then
		local ownedSkins, equippedSkins = {}, {}
		pcall(function()
			ownedSkins = HttpService:JSONDecode(player:GetAttribute("OwnedSkins") or "{}")
			equippedSkins = HttpService:JSONDecode(player:GetAttribute("EquippedSkins") or "{}")
		end)
		local featured = Store.Featured()
		for i, id in Store.SkinOrder do
			local skin = Store.Skins[id]
			local isOwned = ownedSkins[id] == true
			if not skin.NotForSale or isOwned then
				local row = make("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = Ui.PANEL, LayoutOrder = i, ZIndex = 22,
					Parent = list }, { corner(10) })
				make("Frame", { Size = UDim2.fromOffset(22, 44), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = skin.Primary,
					ZIndex = 23, Parent = row }, { corner(4) })
				make("Frame", { Size = UDim2.fromOffset(22, 44), Position = UDim2.fromOffset(36, 10),
					BackgroundColor3 = skin.Accent or skin.Primary, ZIndex = 23, Parent = row }, { corner(4) })
				local isFeatured = table.find(featured, id) ~= nil and not isOwned
				label({ Size = UDim2.new(1, -260, 0, 26), Position = UDim2.fromOffset(68, 8),
					Text = skin.Name .. (isFeatured and "  ·  TODAY -" .. math.floor(Store.FeaturedDiscount * 100) .. "%" or ""),
					TextColor3 = isFeatured and Ui.GOLD or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
				local targetName = skin.Target == "Cape" and "Hero cape" or (Config.Towers[skin.Target] and Config.Towers[skin.Target].DisplayName or skin.Target)
				label({ Size = UDim2.new(1, -260, 0, 18), Position = UDim2.fromOffset(68, 38), Text = skin.Tier .. " skin for: " .. targetName,
					Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
				local wearing = equippedSkins[skin.Target] == id
				local text, color
				if wearing then
					text, color = "Take off", Color3.fromRGB(110, 60, 60)
				elseif isOwned then
					text, color = "Wear", Color3.fromRGB(60, 130, 60)
				else
					text, color = "Buy " .. Store.PriceOf(id) .. " gems", Color3.fromRGB(40, 120, 170)
				end
				local b = button({ Size = UDim2.fromOffset(170, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
					Text = text, BackgroundColor3 = color, ZIndex = 23, Parent = row })
				b.Activated:Connect(function()
					local ok, reason
					if wearing then
						ok, reason = Remotes.EquipSkin:InvokeServer("None:" .. skin.Target)
					elseif isOwned then
						ok, reason = Remotes.EquipSkin:InvokeServer(id)
					else
						ok, reason = Remotes.BuySkin:InvokeServer(id)
						if ok then
							showMessage("You got the " .. skin.Name .. "!", Ui.GEM)
							Ui.playSound("Coin")
						end
					end
					if not ok then
						showMessage(reason or "Can't do that", Ui.BAD)
					end
					task.wait(0.15)
					refreshShop()
				end)
			end
		end
	elseif shopTab == "Robux" then
		local order = 0
		local function robuxRow(name, text, price, id, isPass, ownedAlready)
			order += 1
			local row = make("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = Ui.PANEL, LayoutOrder = order, ZIndex = 22,
				Parent = list }, { corner(10) })
			label({ Size = UDim2.new(1, -220, 0, 26), Position = UDim2.fromOffset(14, 8), Text = name,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			label({ Size = UDim2.new(1, -220, 0, 18), Position = UDim2.fromOffset(14, 38), Text = text or "",
				Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			local buttonText = ownedAlready and "Owned" or (id == 0 and "Coming soon" or ("R$ " .. price))
			local b = button({ Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
				Text = buttonText, ZIndex = 23, Parent = row,
				BackgroundColor3 = (ownedAlready or id == 0) and Color3.fromRGB(70, 70, 80) or Color3.fromRGB(40, 150, 80) })
			b.Activated:Connect(function()
				if ownedAlready or id == 0 then
					return
				end
				if isPass then
					MarketplaceService:PromptGamePassPurchase(player, id)
				else
					MarketplaceService:PromptProductPurchase(player, id)
				end
			end)
		end
		for _, key in Store.GamePassOrder do
			local pass = Store.GamePasses[key]
			robuxRow(pass.Name .. " (pass)", pass.Text, pass.Price, pass.Id, true, player:GetAttribute("Pass" .. key) == true)
		end
		for _, key in Store.ProductOrder do
			local product = Store.Products[key]
			if not (product.Once and player:GetAttribute("StarterBought")) then
				robuxRow(product.Name, product.Text, product.Price, product.Id, false, false)
			end
		end
	elseif shopTab == "Codes" then
		local row = make("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = Ui.PANEL, ZIndex = 22, Parent = list }, { corner(10) })
		local box = make("TextBox", { Size = UDim2.new(1, -190, 0, 44), Position = UDim2.fromOffset(10, 10), PlaceholderText = "Type a code",
			Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.fromRGB(30, 25, 40), ZIndex = 23, Parent = row }, { corner(8) })
		local go = button({ Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
			Text = "Redeem", BackgroundColor3 = Color3.fromRGB(60, 130, 60), ZIndex = 23, Parent = row })
		local hint = make("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 22, Parent = list })
		local hintText = label({ Size = UDim2.fromScale(1, 1), Text = "New codes come with every update!", Font = Enum.Font.Gotham,
			TextColor3 = Ui.TEXT_DIM, ZIndex = 23, Parent = hint })
		go.Activated:Connect(function()
			local ok, result = Remotes.RedeemCode:InvokeServer(box.Text)
			hintText.Text = ok and ("Code worked: " .. tostring(result)) or (result or "Didn't work")
			hintText.TextColor3 = ok and Ui.GEM or Ui.BAD
			if ok then
				Ui.playSound("Coin")
			end
		end)
	else
		for i, item in shopItems(shopTab) do
			rowFor(shopTab, item, i)
		end
	end
	for id, b in tabButtons do
		b.BackgroundColor3 = id == shopTab and Color3.fromRGB(90, 70, 150) or Ui.PANEL
	end
end

for i, tab in TABS do
	local b = button({ Size = UDim2.fromOffset(120, 40), Text = tab.Name, LayoutOrder = i, ZIndex = 22, Parent = tabBar })
	b.Activated:Connect(function()
		shopTab = tab.Id
		refreshShop()
	end)
	tabButtons[tab.Id] = b
end

local function openShop(tab)
	shopTab = tab or shopTab
	shopPanel.Visible = true
	refreshShop()
	Ui.pop(shopPanel, 0.85)
end
shopButton.Activated:Connect(function()
	if shopPanel.Visible then
		shopPanel.Visible = false
	else
		openShop()
	end
end)
shopClose.Activated:Connect(function()
	shopPanel.Visible = false
end)

-------------------------------------------------------------------------------
-- daily reward
-------------------------------------------------------------------------------
local dailyPanel = make("Frame", {
	Size = UDim2.fromOffset(560, 250),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 20,
	Parent = root,
}, { corner(18), stroke(Ui.GOLD, 3) })
label({ Size = UDim2.new(1, -80, 0, 36), Position = UDim2.fromOffset(16, 10), Text = "Daily reward",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = dailyPanel })
local dailyClose = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 21, Parent = dailyPanel })
local dayRow = make("Frame", { Size = UDim2.new(1, -32, 0, 90), Position = UDim2.fromOffset(16, 56),
	BackgroundTransparency = 1, ZIndex = 21, Parent = dailyPanel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local dayBoxes = {}
for day, reward in Config.DailyRewards do
	local box = make("Frame", { Size = UDim2.fromOffset(68, 90), BackgroundColor3 = Ui.PANEL, LayoutOrder = day,
		ZIndex = 22, Parent = dayRow }, { corner(10), stroke() })
	label({ Size = UDim2.new(1, -6, 0, 22), Position = UDim2.fromOffset(3, 6), Text = "Day " .. day, ZIndex = 23, Parent = box })
	label({ Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 32), Text = tostring(reward),
		TextColor3 = Ui.GEM, ZIndex = 23, Parent = box })
	label({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 64), Text = "gems",
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 23, Parent = box })
	dayBoxes[day] = box
end
local claimButton = button({ Size = UDim2.fromOffset(260, 54), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(60, 140, 60), Text = "Claim", ZIndex = 21, Parent = dailyPanel })

local function dailyReady()
	return os.time() >= (player:GetAttribute("DailyNextAt") or 0)
end

local function refreshDaily()
	local streak = player:GetAttribute("DailyStreak") or 0
	local ready = dailyReady()
	local today = ready and math.min(streak + 1, #Config.DailyRewards) or math.min(streak, #Config.DailyRewards)
	for day, box in dayBoxes do
		local s = box:FindFirstChildOfClass("UIStroke")
		if day == today then
			box.BackgroundColor3 = Color3.fromRGB(110, 80, 30)
			s.Color = Ui.GOLD
		elseif day < today then
			box.BackgroundColor3 = Color3.fromRGB(40, 70, 45)
			s.Color = Color3.fromRGB(90, 160, 90)
		else
			box.BackgroundColor3 = Ui.PANEL
			s.Color = Color3.fromRGB(200, 160, 80)
		end
	end
	if ready then
		claimButton.Text = "Claim!"
		claimButton.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
	else
		local left = math.max(0, (player:GetAttribute("DailyNextAt") or 0) - os.time())
		claimButton.Text = string.format("Come back in %dh %dm", left // 3600, (left % 3600) // 60)
		claimButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	end
	dailyDot.Visible = ready
end

dailyButton.Activated:Connect(function()
	dailyPanel.Visible = not dailyPanel.Visible
	refreshDaily()
end)
dailyClose.Activated:Connect(function()
	dailyPanel.Visible = false
end)
claimButton.Activated:Connect(function()
	local ok, result = Remotes.ClaimDaily:InvokeServer()
	if ok then
		showBanner("+" .. result .. " GEMS", "Daily reward claimed. Come back tomorrow!", Ui.GEM)
		Ui.playSound("Coin")
		dailyPanel.Visible = false
	else
		showMessage(result or "Not yet", Ui.BAD)
	end
	refreshDaily()
end)
task.spawn(function()
	-- show the daily reward by itself when it's ready
	task.wait(4)
	if dailyReady() and player:GetAttribute("DailyNextAt") then
		dailyPanel.Visible = true
		refreshDaily()
	end
	while true do
		task.wait(30)
		refreshDaily()
	end
end)

-------------------------------------------------------------------------------
-- keep the screen up to date
-------------------------------------------------------------------------------
local lastGold = GameState:GetAttribute("Gold") or 0
local lastPortal = GameState:GetAttribute("PortalHealth") or 100
local lastWave = GameState:GetAttribute("Wave") or 0
local lastBoss = GameState:GetAttribute("BossAlert") or 0
local lastKills = GameState:GetAttribute("Kills") or 0
local combo, lastKillTime, comboStep = 0, 0, 0

local function refreshTop()
	local gold = GameState:GetAttribute("Gold") or 0
	goldLabel.Text = math.floor(gold) .. " mana"
	local used, maxBuild = GameState:GetAttribute("BuildUsed") or 0, GameState:GetAttribute("BuildMax") or Config.BuildLimit
	buildLabel.Text = "Build Points " .. used .. "/" .. maxBuild
	buildLabel.TextColor3 = used >= maxBuild and Ui.BAD or Ui.TEXT_DIM
	if gold > lastGold then
		Ui.pop(goldLabel, 1.15)
	end
	lastGold = gold

	local wave = GameState:GetAttribute("Wave") or 0
	local maxWave = GameState:GetAttribute("MaxWave") or 10
	waveLabel.Text = maxWave == 0 and ("Wave " .. wave .. " (Endless)") or ("Wave " .. wave .. "/" .. maxWave)
	if wave > lastWave and wave > 0 then
		local maxWave = GameState:GetAttribute("MaxWave") or 10
		showBanner(wave == maxWave and "FINAL WAVE" or "WAVE " .. wave, GameState:GetAttribute("WaveTitle") or "",
			wave == maxWave and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 200, 90))
	end
	lastWave = wave

	local boss = GameState:GetAttribute("BossAlert") or 0
	if boss > lastBoss then
		task.delay(1.5, function()
			showBanner("BOSS INCOMING", "The boss has entered the chat", Color3.fromRGB(220, 120, 255))
			shake(0.6)
		end)
	end
	lastBoss = boss

	local hp = GameState:GetAttribute("PortalHealth") or 0
	local maxHp = GameState:GetAttribute("MaxPortalHealth") or 100
	portalFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	portalFill.BackgroundColor3 = hp / maxHp > 0.3 and Color3.fromRGB(150, 90, 255) or Color3.fromRGB(255, 70, 90)
	portalText.Text = hp .. " / " .. maxHp
	if hp < lastPortal then
		flash.BackgroundTransparency = 0.65
		TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		shake(0.35)
		Ui.pop(portalBack, 1.1)
		if math.random() < 0.25 then
			showMessage(Memes.Pick(Memes.Portal), Ui.BAD)
		end
	end
	lastPortal = hp

	-- combo: kills that happen close together
	local kills = GameState:GetAttribute("Kills") or 0
	if kills > lastKills then
		local now = os.clock()
		if now - lastKillTime < 1.6 then
			combo += kills - lastKills
		else
			combo = kills - lastKills
			comboStep = 0
		end
		lastKillTime = now
		if combo >= 3 then
			comboLabel.Text = "x" .. combo .. " COMBO"
			comboLabel.TextTransparency = 0
			comboLabel.TextStrokeTransparency = 0
			Ui.pop(comboLabel, 1.2)
		end
		local shout = Memes.Combo[comboStep + 1]
		if shout and combo >= shout.Count then
			comboStep += 1
			comboShout.Text = shout.Text
			comboShout.TextTransparency = 0
			comboShout.TextStrokeTransparency = 0.1
			Ui.pop(comboShout, 1.4)
		end
	end
	lastKills = kills

	local s = GameState:GetAttribute("State")
	local mapId = GameState:GetAttribute("Map") or "CursedForest"
	if mapId ~= Config.CurrentMap then
		Config.SetMap(mapId) -- so the build ghost knows the new path
	end
	local inLobby = s == "Lobby"
	lobbyBar.Visible = inLobby
	eventLabel.Visible = inLobby
	goalLabel.Text = nextGoal()
	goalLabel.Position = inLobby and UDim2.new(0.5, 0, 1, -108) or UDim2.new(0.5, 0, 1, -116)
	towerBar.Visible = not inLobby
	top.Visible = true
	portalBack.Visible = not inLobby
	startButton.Visible = s == "Break"
	speedButton.Visible = s == "Break" or s == "Wave"
	speedButton.Text = "Speed " .. (GameState:GetAttribute("Speed") or 1) .. "x"
	if inLobby then
		local mapInfo = Config.Maps[mapId] or Config.Maps.CursedForest
		waveLabel.Text = "The Outpost"
		local modeInfo = Config.FindById(Config.Modes, GameState:GetAttribute("Mode") or "Campaign")
		stateLabel.Text = mapInfo.Name .. " · " .. (GameState:GetAttribute("Difficulty") or "Normal")
			.. (modeInfo and modeInfo.Id ~= "Campaign" and (" · " .. modeInfo.Name) or "")

		mapButton.Text = "Map: " .. mapInfo.Name
	elseif s == "Break" then
		stateLabel.Text = "Next wave in " .. (GameState:GetAttribute("NextWaveIn") or 0) .. "s"
	elseif s == "Wave" then
		stateLabel.Text = "Goblins attacking!"
	else
		stateLabel.Text = ""
	end

	-- the difficulty can only be changed in the Outpost (Map button / Map Board)
	local currentDiff = GameState:GetAttribute("Difficulty")
	local cleared = {}
	pcall(function()
		cleared = HttpService:JSONDecode(player:GetAttribute("Cleared") or "{}")[GameState:GetAttribute("Map") or "CursedForest"] or {}
	end)
	for id, b in diffButtons do
		local d = Config.FindById(Config.Difficulties, id)
		local locked = d.Unlock and not cleared[d.Unlock]
		local sub = b:FindFirstChild("Sub")
		if sub then
			sub.Text = locked and ("Locked: beat " .. d.Unlock .. " here first") or (d.Subtitle .. " · gems x" .. d.Gems)
		end
		b.BackgroundColor3 = locked and Color3.fromRGB(45, 38, 34) or Ui.PANEL
		local st = b:FindFirstChildOfClass("UIStroke")
		st.Color = id == currentDiff and Ui.GOLD or Color3.fromRGB(200, 160, 80)
		st.Thickness = id == currentDiff and 4 or 2
	end

	local over = s == "Won" or s == "Lost"
	if over and not endPanel.Visible then
		Ui.pop(endPanel, 0.7)
	end
	endPanel.Visible = over
	endMeme.Text = GameState:GetAttribute("EndMeme") or ""
	if s == "Won" then
		endTitle.Text = "VICTORY!"
		endTitle.TextColor3 = Ui.GOLD
		endText.Text = "All waves beaten · " .. kills .. " goblins bonked"
	elseif s == "Lost" then
		endTitle.Text = "DEFEAT"
		endTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
		endText.Text = "You made it to wave " .. wave .. " · " .. kills .. " goblins bonked"
	end

	for towerType, t in towerButtons do
		local unlocked = isUnlocked(towerType)
		t.lock.Visible = not unlocked
		local affordable = gold >= Config.Towers[towerType].Cost
		t.button.BackgroundColor3 = (affordable and unlocked) and Ui.PANEL or Color3.fromRGB(45, 40, 45)
		t.cost.TextColor3 = affordable and Ui.MANA or Ui.BAD
	end
end
GameState.AttributeChanged:Connect(refreshTop)
refreshTop()

-- combo fades after a moment without kills
RunService.Heartbeat:Connect(function()
	if combo > 0 and os.clock() - lastKillTime > 1.6 then
		combo = 0
		comboStep = 0
		TweenService:Create(comboLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(comboShout, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end)

local lastGems = nil
local function refreshPlayer()
	local level = player:GetAttribute("HeroLevel") or 1
	local hero = Config.Heroes[player:GetAttribute("HeroId") or "Swordmaster"] or Config.Heroes.Swordmaster
	heroName.Text = hero.Name .. "  Lv " .. level
	attackName.Text, whirlName.Text, leapName.Text = hero.Abilities.F, hero.Abilities.E, hero.Abilities.R
	local needed = player:GetAttribute("HeroXpNeeded") or 1
	local xp = player:GetAttribute("HeroXp") or 0
	xpFill.Size = UDim2.fromScale(level >= Config.HeroMaxLevel and 1 or math.clamp(xp / needed, 0, 1), 1)

	local gems = player:GetAttribute("Gems") or 0
	gemsLabel.Text = gems .. " gems"
	shopGems.Text = gems .. " gems"
	if lastGems and gems > lastGems then
		Ui.pop(gemsLabel, 1.3)
	end
	lastGems = gems
	endGems.Text = "+" .. (player:GetAttribute("LastReward") or 0) .. " gems"

	local json = player:GetAttribute("Owned")
	if json then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(data) == "table" then
			owned = data
			owned.Towers = owned.Towers or {}
		end
	end
	refreshDaily()
	refreshTop()
end
player.AttributeChanged:Connect(refreshPlayer)
refreshPlayer()

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local function fill(shade, attr, cooldown)
		shade.Size = UDim2.fromScale(1, math.clamp(((player:GetAttribute(attr) or 0) - now) / cooldown, 0, 1))
	end
	fill(attackShade, "AttackReadyAt", player:GetAttribute("AttackCooldown") or Config.Hero.Attack.Cooldown)
	fill(whirlShade, "WhirlwindReadyAt", player:GetAttribute("CooldownE") or Config.Hero.Whirlwind.Cooldown)
	fill(leapShade, "LeapReadyAt", player:GetAttribute("CooldownR") or Config.Hero.Leap.Cooldown)
end)

-------------------------------------------------------------------------------
-- placing defenders
-------------------------------------------------------------------------------
local placing = nil -- the defender type we're placing, or nil
local ghost = nil
local ghostPos = nil -- phones: the spot that was tapped
local selected = nil -- the defender model whose info panel is open
local rangeCircle = nil

local function makeDisc(radius, color)
	return make("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.75,
	})
end

local function screenRay(screenPos, include)
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function mouseRay(include)
	return screenRay(UserInputService:GetMouseLocation(), include)
end

-- same rules as the server, so the ghost shows green or red
local function canPlaceHere(position)
	local half = Config.MapSize / 2
	if math.abs(position.X) > half.X - 4 or math.abs(position.Z) > half.Y - 4 then
		return false, "Too close to the edge"
	end
	if Config.DistanceToPath(position) < Config.PathWidth / 2 + 3 then
		return false, "Not on the path"
	end
	if (Vector3.new(position.X, 0, position.Z) - Config.Path[#Config.Path]).Magnitude < 14 then
		return false, "Too close to the portal"
	end
	for _, tower in workspace.Towers:GetChildren() do
		if tower.PrimaryPart then
			local p = tower.PrimaryPart.Position
			if (Vector3.new(p.X, 0, p.Z) - position).Magnitude < Config.TowerSpacing then
				return false, "Too close to another defender"
			end
		end
	end
	if (GameState:GetAttribute("BuildUsed") or 0) + (Config.BuildPoints[placing] or 0) > (GameState:GetAttribute("BuildMax") or Config.BuildLimit) then
		return false, "Build Points full"
	end
	return true, nil
end

local function stopPlacing()
	placing = nil
	ghostPos = nil
	confirmBar.Visible = false
	tapHint.Visible = false
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
end

local function closeInfo()
	selected = nil
	infoPanel.Visible = false
	if rangeCircle then
		rangeCircle:Destroy()
		rangeCircle = nil
	end
end

local function startPlacing(towerType)
	closeInfo()
	stopPlacing()
	local info = Config.Towers[towerType]
	if not isUnlocked(towerType) then
		showMessage("Unlock the " .. info.DisplayName .. " in the Shop (" .. info.UnlockGems .. " gems)", Ui.GEM)
		openShop("Towers")
		return
	end
	if (GameState:GetAttribute("Gold") or 0) < info.Cost then
		showMessage("Not enough mana for a " .. info.DisplayName, Ui.BAD)
		return
	end
	placing = towerType
	ghost = make("Model", { Name = "PlacementGhost" })
	local function ghostPart(props)
		local p = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = Enum.Material.Neon })
		for k, v in props do
			p[k] = v
		end
		p.Parent = ghost
		return p
	end
	-- the tower's shape (a simple stand-in) with a bright outline you see through anything
	local body = ghostPart({ Name = "Body", Size = Vector3.new(3, 7, 3), Color = info.Color, Transparency = 0.35,
		Material = Enum.Material.SmoothPlastic })
	ghostPart({ Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, Color = info.Color, Transparency = 0.35 })
	-- the exact spot it takes: a solid circle on the ground
	ghostPart({ Name = "Foot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, Config.TowerSpacing, Config.TowerSpacing),
		Color = Color3.fromRGB(120, 255, 120), Transparency = 0.25 })
	ghost.PrimaryPart = body
	make("Highlight", { FillTransparency = 0.7, OutlineTransparency = 0, OutlineColor = Color3.new(1, 1, 1),
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = ghost })
	-- the range: a faint disc with a bright edge
	local range = info.Levels[1].Range
	local disc = makeDisc(range, Color3.fromRGB(120, 255, 120))
	disc.Name = "Range"
	disc.Transparency = 0.85
	disc.Parent = ghost
	local edge = make("Folder", { Name = "Edge", Parent = ghost })
	for i = 1, 40 do
		local a = i / 40 * math.pi * 2
		make("Part", { Size = Vector3.new(0.35, 0.35, range * math.pi * 2 / 40 + 0.2), Anchored = true, CanCollide = false,
			CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 255, 120),
			Parent = edge }):SetAttribute("Angle", a)
	end
	local tagHolder = ghostPart({ Name = "TagHolder", Size = Vector3.one * 0.2, Transparency = 1 })
	local tag = make("BillboardGui", { Name = "Tag", Size = UDim2.fromOffset(260, 34), StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true, Parent = tagHolder })
	label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(255, 120, 120),
		TextStrokeTransparency = 0, Parent = tag })
	ghost.Parent = workspace
	if isTouch then
		tapHint.Visible = true
		-- start the ghost in front of the hero
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local p = r.Position + r.CFrame.LookVector * 10
			ghostPos = Vector3.new(p.X, 0, p.Z)
			confirmBar.Visible = true
		end
	end
end

local function groundUnder(screenPos)
	local hit = screenRay(screenPos, { workspace.Map.Ground, workspace.Map.Path })
	if not hit then
		return nil
	end
	return Vector3.new(hit.Position.X, 0, hit.Position.Z)
end

RunService.RenderStepped:Connect(function()
	if not placing or not ghost then
		return
	end
	local pos = isTouch and ghostPos or groundUnder(UserInputService:GetMouseLocation())
	if not pos then
		ghost.Parent = nil
		return
	end
	ghost.Parent = workspace
	pos = Vector3.new(math.floor(pos.X + 0.5), 0, math.floor(pos.Z + 0.5)) -- snap to whole studs
	ghost:SetAttribute("Spot", pos)
	local ok, reason = canPlaceHere(pos)
	local color = ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 80, 80)
	local bob = math.sin(os.clock() * 4) * 0.2
	ghost.Body.CFrame = CFrame.new(pos + Vector3.new(0, 3.5 + bob, 0))
	ghost.Top.CFrame = CFrame.new(pos + Vector3.new(0, 7.5 + bob, 0))
	ghost.Top.Color = ok and Config.Towers[placing].Color or color
	ghost.Body.Color = ok and Config.Towers[placing].Color or color
	ghost.Foot.CFrame = CFrame.new(pos + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ghost.Foot.Color = color
	ghost.Range.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ghost.Range.Color = color
	local range = Config.Towers[placing].Levels[1].Range
	for _, piece in ghost.Edge:GetChildren() do
		local a = piece:GetAttribute("Angle")
		local at = pos + Vector3.new(math.cos(a) * range, 0.3, math.sin(a) * range)
		piece.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
		piece.Color = color
	end
	ghost.TagHolder.CFrame = CFrame.new(pos)
	ghost.TagHolder.Tag.Text.Text = ok and "" or (reason or "")
	local highlight = ghost:FindFirstChildOfClass("Highlight")
	highlight.OutlineColor = ok and Color3.new(1, 1, 1) or color
	highlight.FillColor = color
end)

local function tryPlace(pos)
	if not pos or not placing then
		return
	end
	pos = Vector3.new(math.floor(pos.X + 0.5), 0, math.floor(pos.Z + 0.5)) -- same spot the preview shows
	local ok, reason = Remotes.PlaceTower:InvokeServer(placing, pos)
	if ok then
		-- keep placing the same defender while holding Shift (PC)
		if isTouch or not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			stopPlacing()
		end
	else
		showMessage(reason or "Can't place here", Ui.BAD)
	end
end

confirmButton.Activated:Connect(function()
	tryPlace(ghostPos)
end)
cancelButton.Activated:Connect(stopPlacing)

-------------------------------------------------------------------------------
-- clicking your defenders: upgrade and sell
-------------------------------------------------------------------------------
local function refreshInfo()
	if not selected or not selected.Parent then
		closeInfo()
		return
	end
	local towerType = selected:GetAttribute("TowerType")
	local info = Config.Towers[towerType]
	local level = selected:GetAttribute("Level")
	local stats = info.Levels[level]
	infoTitle.Text = info.DisplayName .. "  Lv " .. level
	infoStats.Text = "Damage " .. stats.Damage .. " · Range " .. stats.Range .. " · every " .. stats.Cooldown .. "s"
	local nextLevel = info.Levels[level + 1]
	if nextLevel then
		local gold = GameState:GetAttribute("Gold") or 0
		upgradeButton.Text = "Upgrade (" .. nextLevel.Cost .. " mana)"
		upgradeButton.BackgroundColor3 = gold >= nextLevel.Cost and Color3.fromRGB(60, 130, 60) or Color3.fromRGB(70, 70, 80)
	else
		upgradeButton.Text = "Max level"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	end
	sellButton.Text = "Sell (+" .. math.floor((selected:GetAttribute("Spent") or 0) * Config.SellRefund) .. " mana)"
	if rangeCircle then
		rangeCircle:Destroy()
	end
	local base = selected.PrimaryPart and selected.PrimaryPart.Position or Vector3.zero
	rangeCircle = makeDisc(stats.Range, Color3.fromRGB(150, 200, 255))
	rangeCircle.CFrame = CFrame.new(base.X, 0.2, base.Z) * CFrame.Angles(0, 0, math.pi / 2)
	rangeCircle.Parent = workspace
end

local function selectTower(model)
	stopPlacing()
	selected = model
	infoPanel.Visible = true
	Ui.pop(infoPanel, 0.9)
	refreshInfo()
end

upgradeButton.Activated:Connect(function()
	if not selected then
		return
	end
	local ok, reason = Remotes.UpgradeTower:InvokeServer(selected)
	if ok then
		Ui.playSound("Coin")
	else
		showMessage(reason or "Can't upgrade", Ui.BAD)
	end
	refreshInfo()
end)

sellButton.Activated:Connect(function()
	if not selected then
		return
	end
	Remotes.SellTower:InvokeServer(selected)
	closeInfo()
end)

-- a click or tap in the world: place, or pick a defender
local function worldClick(screenPos)
	if placing then
		if isTouch then
			local pos = groundUnder(screenPos)
			if pos then
				ghostPos = pos
				confirmBar.Visible = true
				tapHint.Visible = false
			end
		else
			tryPlace(groundUnder(screenPos))
		end
		return
	end
	local hit = screenRay(screenPos, { workspace.Towers })
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= workspace.Towers do
		model = model.Parent:FindFirstAncestorOfClass("Model")
	end
	if model then
		selectTower(model)
	else
		closeInfo()
	end
end

-------------------------------------------------------------------------------
-- hero abilities
-------------------------------------------------------------------------------
local function doLeap()
	if workspace:GetServerTimeNow() < (player:GetAttribute("LeapReadyAt") or 0) then
		return
	end
	-- only the Swordmaster jumps, other heroes' R happens on the server
	if (player:GetAttribute("HeroId") or "Swordmaster") ~= "Swordmaster" then
		Remotes.HeroLeap:FireServer()
		return
	end
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not r or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- our computer moves our own character, the server does the damage on landing
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local forward = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit
	r.AssemblyLinearVelocity = forward * (Config.Hero.Leap.Distance * 1.8) + Vector3.new(0, 55, 0)
	Remotes.HeroLeap:FireServer()
	task.delay(0.6, function()
		shake(0.5)
	end)
end

local function doWhirl()
	Remotes.HeroWhirlwind:FireServer()

end

-------------------------------------------------------------------------------
-- buttons and keys
-------------------------------------------------------------------------------
for towerType, t in towerButtons do
	t.button.Activated:Connect(function()
		if placing == towerType then
			stopPlacing()
		else
			startPlacing(towerType)
		end
	end)
end
startButton.Activated:Connect(function()
	Remotes.StartWave:FireServer()
end)
speedButton.Activated:Connect(function()
	local current = GameState:GetAttribute("Speed") or 1
	local speeds = table.clone(Config.Speeds)
	if player:GetAttribute("PassSpeed3x") then
		table.insert(speeds, 3)
	end
	local idx = table.find(speeds, current) or 1
	Remotes.SetSpeed:FireServer(speeds[idx % #speeds + 1])
end)
playAgainButton.Activated:Connect(function()
	Remotes.PlayAgain:FireServer()
end)
attackButton.Activated:Connect(function()
	Remotes.HeroAttack:FireServer()
end)
whirlButton.Activated:Connect(doWhirl)
leapButton.Activated:Connect(doLeap)

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		worldClick(UserInputService:GetMouseLocation())
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		stopPlacing()
	elseif input.KeyCode == Enum.KeyCode.Q then
		stopPlacing()
		closeInfo()
		shopPanel.Visible = false
		dailyPanel.Visible = false
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.HeroAttack:FireServer()
	elseif input.KeyCode == Enum.KeyCode.E then
		doWhirl()
	elseif input.KeyCode == Enum.KeyCode.R then
		doLeap()
	elseif input.KeyCode == Enum.KeyCode.B then
		if shopPanel.Visible then
			shopPanel.Visible = false
		else
			openShop()
		end
	elseif NUMBER_KEYS[input.KeyCode] then
		local towerType = Config.TowerOrder[NUMBER_KEYS[input.KeyCode]]
		if towerType then
			if placing == towerType then
				stopPlacing()
			else
				startPlacing(towerType)
			end
		end
	end
end)

-- taps on phones (not on buttons)
UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
	if processedByUI then
		return
	end
	-- TouchTapInWorld gives a position without the top bar inset, so add it back
	local inset = game:GetService("GuiService"):GetGuiInset()
	worldClick(Vector2.new(position.X, position.Y + inset.Y))
end)

-- keep the info panel right when gold changes
GameState:GetAttributeChangedSignal("Gold"):Connect(function()
	if selected then
		refreshInfo()
	end
end)

if not isTouch then
	label({ Size = UDim2.fromOffset(300, 40), Position = UDim2.new(1, -10, 1, -10), AnchorPoint = Vector2.new(1, 1),
		Text = "1-5 build · click a defender to upgrade · Shift builds more · B shop · Q cancel",
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextStrokeTransparency = 0.5, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = root })
end

-- stalls in the Outpost open these screens
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Shop" then
		openShop()
	elseif name == "Daily" then
		dailyPanel.Visible = true
		refreshDaily()
	elseif name == "Maps" then
		mapPanel.Visible = true
	end
end)

print("Welcome to Heroes Tower Defense!")
