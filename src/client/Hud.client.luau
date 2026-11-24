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
local Ground = require(ReplicatedStorage.Shared.Ground)
local MapOutline = require(ReplicatedStorage.Shared.MapOutline)
local GearLooks = require(ReplicatedStorage.Shared.GearLooks)
local Memes = require(ReplicatedStorage.Shared.Memes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local ShopLooks = require(script.Parent.ShopLooks)
local Store = require(ReplicatedStorage.Shared.Store)
local Items = require(ReplicatedStorage.Shared.Items)
local MarketplaceService = game:GetService("MarketplaceService")
local GameState = ReplicatedStorage:WaitForChild("GameState")

workspace:WaitForChild("Towers")

local player = Players.LocalPlayer
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

-- phones and tablets get bigger buttons in different places
local isTouch = Ui.isTouch

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
Ui.fitRoot(gui, root, 930, 480)

-- red flash over the whole screen when the portal is hit
local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	BackgroundTransparency = 1, ZIndex = 50, Active = false, Parent = gui })

-------------------------------------------------------------------------------
-- top bar: wave, gold, portal health
-------------------------------------------------------------------------------
local top = make("Frame", {
	Name = "RunStatus",
	Size = UDim2.fromOffset(600, 64),
	Position = UDim2.new(0.5, 0, 0, 8),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.15,
	Parent = root,
}, { corner(14), stroke() })
if isTouch then
	-- phones: the run bar at 80% size (the mobile test keeps 70% of the screen free for the game)
	make("UIScale", { Scale = 0.8, Parent = top })
	top.Position = UDim2.new(0.5, 0, 0, 4)
end

local waveLabel = label({ Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(14, 6), Text = "Wave 0/10",
	TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local stateLabel = label({ Size = UDim2.fromOffset(180, 20), Position = UDim2.fromOffset(14, 38), Text = "",
	TextColor3 = Ui.TEXT_DIM, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local goldLabel = label({ Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(200, 6), Text = "200 mana",
	TextColor3 = Ui.MANA, Parent = top })
local buildLabel = label({ Size = UDim2.fromOffset(150, 18), Position = UDim2.fromOffset(200, 40), Text = "Build 0/30",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, Parent = top })
local portalLabel = label({ Size = UDim2.fromOffset(220, 16), Position = UDim2.fromOffset(366, 6), Text = "Portal",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 170, 255), Parent = top })
local portalBack = make("Frame", { Size = UDim2.fromOffset(220, 24), Position = UDim2.fromOffset(366, 26),
	BackgroundColor3 = Color3.fromRGB(50, 30, 40), Parent = top }, { corner(6) })
local portalFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 90, 255),
	Parent = portalBack }, { corner(6) })
local portalText = label({ Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.08), Text = "100 / 100",
	ZIndex = 2, Parent = portalBack })

-- start wave + speed buttons under the bar
-- phones: a compact stack in the top-right corner, off the lane (it sat over the middle of the map before)
local controls = make("Frame", {
	Name = "WaveControls",
	Size = isTouch and UDim2.fromOffset(160, 136) or UDim2.fromOffset(420, 44),
	-- (left of the ability column, which reaches up the right edge)
	Position = isTouch and UDim2.new(1, -118, 0, 8) or UDim2.new(0.5, 0, 0, 80),
	AnchorPoint = isTouch and Vector2.new(1, 0) or Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { FillDirection = isTouch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, isTouch and 6 or 10),
	HorizontalAlignment = isTouch and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center }) })
local startButton = button({ Name = "StartWave", Size = UDim2.fromOffset(isTouch and 140 or 210, isTouch and 66 or 44), BackgroundColor3 = Color3.fromRGB(160, 60, 40),
	Text = isTouch and "Start wave" or "Start wave now", LayoutOrder = 1, Parent = controls })
local speedButton = button({ Name = "WaveSpeed", Size = UDim2.fromOffset(isTouch and 88 or 110, isTouch and 64 or 44), BackgroundColor3 = Color3.fromRGB(50, 90, 140),
	Text = "Speed 1x", LayoutOrder = 2, Parent = controls })

-- the difficulty's name, with the Mythic tier ("Mythic 3")
local function difficultyName()
	local id = GameState:GetAttribute("Difficulty") or "Normal"
	return Config.DifficultyFor(id, GameState:GetAttribute("Tier")).Name
end

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
-- (6A: one or two short lines just under the wave panel, never a stack over the middle of the fight)
local messages = make("Frame", {
	Size = UDim2.fromOffset(560, 56),
	Position = UDim2.new(0.5, 0, 0, 160),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }) })

local function showMessage(text, color)
	local l = label({ Size = UDim2.fromOffset(560, 24), Text = text, TextColor3 = color or Color3.new(1, 1, 1),
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
	if count > (isTouch and 1 or 2) then
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
	Size = UDim2.fromOffset(200, 32),
	Position = isTouch and UDim2.new(1, -130, 0, 150) or UDim2.new(1, -16, 0, 160), -- phones: left of the ability column
	AnchorPoint = Vector2.new(1, 0),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	TextStrokeTransparency = 0,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = root,
})
local comboShout = label({
	Size = UDim2.fromOffset(300, 20),
	Position = UDim2.new(1, -16, 0, isTouch and 184 or 194),
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
local lastShaken
local function shake(amount)
	shakeAmount = math.max(shakeAmount, amount)
end
RunService.RenderStepped:Connect(function(dt)
	if shakeAmount <= 0.01 then
		if lastShaken then
			lastShaken.CameraOffset = Vector3.zero
			lastShaken = nil
		end
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		shakeAmount = 0
		return
	end
	if lastShaken and lastShaken ~= humanoid then
		lastShaken.CameraOffset = Vector3.zero
	end
	lastShaken = humanoid
	local strength = shakeAmount * (isTouch and 0.22 or 0.35)
	humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * strength
	shakeAmount = math.max(0, shakeAmount - dt * 3)
end)

-------------------------------------------------------------------------------
-- defender buttons (bottom middle)
-------------------------------------------------------------------------------
local BUTTON_W = isTouch and 98 or 112
local towerBar = make("Frame", {
	Name = "TowerBar",
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
	Icons.Draw(b, Config.TowerIcons[towerType], info.Color, { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0.5, -26, 0, 4) })
	label({ Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 58), Text = info.DisplayName, Parent = b })
	local cost = label({ Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 78),
		Text = info.Cost .. " mana · " .. (Config.BuildPoints[towerType] or 0) .. " bp",
		TextColor3 = Ui.MANA, Parent = b })
	if not isTouch then
		label({ Name = "KeyHint", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -18, 0, -8), Text = tostring(i),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(90, 70, 130), ZIndex = 3, Parent = b }, {})
	end
	local lock = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6, Visible = false, ZIndex = 4, Parent = b }, { corner(10) })
	-- locked: the tower and its name stay visible under a light shade, a small lock in the corner, the price below
	Icons.Draw(lock, "Lock", Color3.fromRGB(230, 200, 140), { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -28, 0, 4), ZIndex = 5 })
	label({ Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 78),
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
	Name = "HeroStatus",
	Size = UDim2.fromOffset(230, 52),
	Position = isTouch and UDim2.fromOffset(10, 168) or UDim2.new(0, 10, 1, -132), -- (below the square Menu button)
	AnchorPoint = Vector2.new(0, 0),
	BackgroundColor3 = Ui.DARK,
	BackgroundTransparency = 0.15,
	Parent = root,
}, { corner(12), stroke() })
if isTouch then
	make("UIScale", { Scale = 0.8, Parent = heroPanel })
	-- the Menu button lives on its own screen with its own scale; on a narrow, tall screen (a 4:3 tablet, a Studio
	-- window of 750x635) it reached down past this panel's top (test/mobile: "menu covers hero status").
	-- Keep the panel just below it, wherever the two scales put them.
	local hudScale = root:FindFirstChildOfClass("UIScale")
	local function keepBelowMenu()
		local menuGui = player.PlayerGui:FindFirstChild("SideMenu")
		local open = menuGui and menuGui:FindFirstChild("OpenMenu", true)
		if not open or not hudScale or hudScale.Scale <= 0 then
			return
		end
		local bottom = open.AbsolutePosition.Y + open.AbsoluteSize.Y
		local y = (bottom - root.AbsolutePosition.Y) / hudScale.Scale + 6
		heroPanel.Position = UDim2.fromOffset(10, math.max(168, math.ceil(y)))
	end
	task.spawn(function()
		local menuGui = player.PlayerGui:WaitForChild("SideMenu", 30)
		local open = menuGui and menuGui:FindFirstChild("OpenMenu", true)
		if open then
			open:GetPropertyChangedSignal("AbsolutePosition"):Connect(keepBelowMenu)
			open:GetPropertyChangedSignal("AbsoluteSize"):Connect(keepBelowMenu)
		end
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(keepBelowMenu)
		root:GetPropertyChangedSignal("AbsolutePosition"):Connect(keepBelowMenu)
		keepBelowMenu()
	end)
end
local heroPortrait = Icons.Draw(heroPanel, Config.HeroIcons.Swordmaster, nil,
	{ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(4, 3) })
local heroName = label({ Size = UDim2.new(1, -66, 0, 24), Position = UDim2.fromOffset(56, 4),
	Text = Config.Hero.Name .. "  Lv 1", TextXAlignment = Enum.TextXAlignment.Left, Parent = heroPanel })
local xpBack = make("Frame", { Size = UDim2.new(1, -66, 0, 10), Position = UDim2.fromOffset(56, 34),
	BackgroundColor3 = Color3.fromRGB(50, 45, 60), Parent = heroPanel }, { corner(4) })
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 200, 255),
	Parent = xpBack }, { corner(4) })

local abilityHolder
if isTouch then
	-- a column on the right, above the jump button
	abilityHolder = make("Frame", {
		Size = UDim2.fromOffset(96, 286),
		Position = UDim2.new(1, -12, 1, -168),
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
	local size = isTouch and UDim2.fromOffset(72, 72) or UDim2.fromOffset(71, 58) -- 72 x 0.69 = 50 px on an iPhone 13
	local b = button({ Size = size, Text = "", LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(70, 50, 100),
		Parent = abilityHolder })
	if isTouch then
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end
	local nameLabel = label({ Size = UDim2.new(1, -8, 0.45, 0), Position = UDim2.fromScale(0, 0.12), AnchorPoint = Vector2.new(0, 0),
		Text = text, Parent = b })
	-- the painted ability icon (art/make_ability_icons.py); once it has loaded the word shrinks to a small caption
	local icon = make("ImageLabel", { Name = "AbilityIcon", BackgroundTransparency = 1, Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Visible = false, Parent = b })
	local images = ReplicatedStorage:WaitForChild("ArtImages")
	local function showIcon()
		local image = images:GetAttribute("ab_" .. string.lower(nameLabel.Text))
		icon.Image = image or ""
		icon.Visible = image ~= nil
		if image then
			nameLabel.Size = UDim2.new(1, -8, 0, 14)
			nameLabel.Position = UDim2.new(0, 4, 1, isTouch and -20 or -34)
		else
			nameLabel.Size = UDim2.new(1, -8, 0.45, 0)
			nameLabel.Position = UDim2.fromScale(0, 0.12)
		end
	end
	nameLabel:GetPropertyChangedSignal("Text"):Connect(showIcon)
	images.AttributeChanged:Connect(showIcon)
	showIcon()
	if not isTouch then
		label({ Name = "KeyHint", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -20), Text = "[" .. key .. "]",
			Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, Parent = b })
	end
	local shade = make("Frame", { Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Parent = b },
		{ corner(isTouch and 46 or 8) })
	return b, shade, nameLabel
end
local attackButton, attackShade, attackName = abilityButton("Sword", "F", 3)
attackButton.Name = "PrimaryAttack"
local whirlButton, whirlShade, whirlName = abilityButton("Whirl", "E", 2)
local leapButton, leapShade, leapName = abilityButton("Leap", "R", 1)
if not isTouch then
	-- on PC the order left to right is Sword, Whirl, Leap
	attackButton.LayoutOrder, whirlButton.LayoutOrder, leapButton.LayoutOrder = 1, 2, 3
end

-------------------------------------------------------------------------------
-- defender info panel (shows when you click one of your defenders)
-------------------------------------------------------------------------------
-- (phones: 60-tall buttons, so upgrade and sell are at least 44 pixels on a small phone)
local INFO_BUTTON = isTouch and 66 or 38 -- 66 x the phone scale (0.69 on an iPhone 13) = 45 px
local infoPanel = make("Frame", {
	Name = "TowerInfo",
	Size = UDim2.fromOffset(240, 100 + INFO_BUTTON * 2),
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
local upgradeButton = button({ Name = "Upgrade", Size = UDim2.new(1, -20, 0, INFO_BUTTON), Position = UDim2.fromOffset(10, 82),
	BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Upgrade", Parent = infoPanel })
local sellButton = button({ Name = "Sell", Size = UDim2.new(1, -20, 0, INFO_BUTTON), Position = UDim2.fromOffset(10, 90 + INFO_BUTTON),
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
local confirmButton = button({ Name = "ConfirmBuild", Size = UDim2.fromOffset(200, isTouch and 74 or 54), BackgroundColor3 = Color3.fromRGB(60, 140, 60),
	Text = "Build here", LayoutOrder = 1, Parent = confirmBar })
local cancelButton = button({ Name = "CancelBuild", Size = UDim2.fromOffset(120, isTouch and 74 or 54), BackgroundColor3 = Color3.fromRGB(140, 50, 50),
	Text = "Cancel", LayoutOrder = 2, Parent = confirmBar })
local tapHint = label({ Size = UDim2.fromOffset(400, 26), Position = UDim2.new(0.5, 0, 1, isTouch and -209 or -190), AnchorPoint = Vector2.new(0.5, 1),
	Text = "Tap the ground where it should go", TextStrokeTransparency = 0.3, Visible = false, Parent = root })

-------------------------------------------------------------------------------
-- in the hub: start a run and pick a map
-------------------------------------------------------------------------------
local lobbyBar = make("Frame", {
	Size = UDim2.fromOffset(520, isTouch and 76 or 60),
	Position = UDim2.new(0.5, 0, 1, isTouch and -14 or -12),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = root,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local runButton = button({ Name = "StartRun", Size = UDim2.fromOffset(240, isTouch and 76 or 60), BackgroundColor3 = Color3.fromRGB(110, 60, 190),
	Text = "Start run", LayoutOrder = 1, Parent = lobbyBar })
local eventInfo = Config.WeeklyEvent()
local eventLabel = label({ Size = UDim2.fromOffset(760, 24), Position = UDim2.new(0.5, 0, 1, isTouch and -96 or -80), AnchorPoint = Vector2.new(0.5, 1),
	Text = "This week: " .. eventInfo.Name .. " · " .. eventInfo.Text, Visible = false,
	TextColor3 = Color3.fromRGB(255, 200, 120), TextStrokeTransparency = 0.2, Parent = root })
local mapButton = button({ Name = "PickMap", Size = UDim2.fromOffset(260, isTouch and 76 or 60), BackgroundColor3 = Color3.fromRGB(120, 80, 40),
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
	local statsLine = label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(28, 60),
		Text = string.format("Goblin health x%.2f · gems x%.1f · better loot +%d", info.Health, info.Gems, info.ItemLevel),
		Font = Enum.Font.Gotham, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = b })
	-- the boss's own reward instead, when it has one (Config.BossRewards): what it is, what it does, your meter
	local bossName = nil
	for _, wave in info.Waves do
		for _, group in ipairs(wave) do
			if Config.BossRewards[group.Enemy] then
				bossName = group.Enemy
			end
		end
	end
	if bossName then
		local reward = Config.BossRewards[bossName]
		local weapon = Items.WeaponTypes[reward.Item]
		local function showReward()
			local first = not player:GetAttribute("BossFirst_" .. bossName)
			statsLine.Text = string.format("Boss reward: %s (cracks armor) · %s", weapon.Name,
				first and "first win takes it" or string.format("meter %d/%d", player:GetAttribute("BossMeter_" .. bossName) or 0,
					reward.Meter))
			statsLine.TextColor3 = Items.Rarities[reward.Rarity].Color
		end
		showReward()
		player:GetAttributeChangedSignal("BossMeter_" .. bossName):Connect(showReward)
		player:GetAttributeChangedSignal("BossFirst_" .. bossName):Connect(showReward)
	end
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
-- one short line at the top edge (in a run just under the wave bar), never a sentence over the hero
local goalLabel = label({ Name = "NextGoal", Size = UDim2.fromOffset(440, 18), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0),
	Text = "", TextColor3 = Color3.fromRGB(255, 235, 190), TextStrokeTransparency = 0.25, Parent = root })
-- a small dark-wood chip behind it, so the line reads over bright signs and sky
goalLabel.TextScaled = false
goalLabel.TextSize = 15
goalLabel.AutomaticSize = Enum.AutomaticSize.X
goalLabel.Size = UDim2.fromOffset(0, 22)
goalLabel.BackgroundColor3 = Color3.fromRGB(58, 38, 24)
goalLabel.BackgroundTransparency = 0.12
make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = goalLabel })
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = goalLabel })
make("UIStroke", { Color = Color3.fromRGB(214, 170, 80), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Parent = goalLabel })

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
			return "Next: win a run to unlock the Engineer"
		end
		if player:GetAttribute("FirstWinReady") then
			local rift = Config.Maps[Config.RiftMap()]
			return "Next: first win today gives double gold and a bonus chest" .. (rift and (" · Rift map: " .. rift.Name) or "")
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
		return "Survive " .. maxWave .. " waves, then beat the boss"
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
	Name = "Shop",
	Size = UDim2.new(1, -28, 1, -32),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 20,
	Parent = root,
}, { corner(18), stroke(Ui.GEM, 3), make("UISizeConstraint", { MaxSize = Vector2.new(780, 480) }) })
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
local TABS = { { Id = "Towers", Name = "Defenders" }, { Id = "GearLooks", Name = "Gear Looks" }, { Id = "Titles", Name = "Titles" },
	{ Id = "Skins", Name = "Skins" }, { Id = "Robux", Name = "Robux" }, { Id = "Codes", Name = "Codes" } }
local tabButtons = {}
local gearSlot = GearLooks.Slots[1]
local gearTabs = make("Frame", { Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 104),
	BackgroundTransparency = 1, ZIndex = 21, Visible = false, Parent = shopPanel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder }) })
local gearButtons = {}
local shopLooks = ShopLooks.new(shopPanel, list, showMessage)

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

local function rowFor(kind, item, order, equippedId)
	local row = make("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = Ui.PANEL, LayoutOrder = order,
		ZIndex = 22, Parent = list }, { corner(10) })
	make("Frame", { Size = UDim2.fromOffset(10, 44), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = item.Color,
		ZIndex = 23, Parent = row }, { corner(4) })
	label({ Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(30, 8), Text = item.Name,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
	label({ Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(30, 38), Text = item.Text,
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })

	local isOwned = owned[kind] and owned[kind][item.Id] == true
	local text, color
	if not isOwned and item.RebirthOnly then
		text, color = "Reward only", Color3.fromRGB(70, 70, 80)
	elseif not isOwned then
		text, color = item.Price == 0 and "Claim free" or ("Buy " .. item.Price .. " gems"), Color3.fromRGB(40, 120, 170)
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
		if (not isOwned and item.RebirthOnly) or (isOwned and (kind == "Towers" or equippedId == item.Id)) then
			return
		end
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
	local showGear = shopTab == "GearLooks"
	gearTabs.Visible = showGear
	for id, b in tabButtons do
		b.BackgroundColor3 = id == shopTab and Color3.fromRGB(90, 70, 150) or Ui.PANEL
	end
	for id, b in gearButtons do
		b.BackgroundColor3 = id == gearSlot.Id and Color3.fromRGB(90, 70, 150) or Ui.PANEL
	end
	if showGear or shopTab == "Skins" then
		shopLooks.Show(showGear and gearSlot.Id or shopTab)
		return
	end
	shopLooks.Hide()
	list.Position = UDim2.fromOffset(16, 104)
	list.Size = UDim2.new(1, -32, 1, -116)
	if shopTab == "Robux" then
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
		local equipped = shopTab == "Titles" and player:GetAttribute("EquippedTitle")
		for i, item in shopItems(shopTab) do
			rowFor(shopTab, item, i, equipped)
		end
	end
end

for i, slot in GearLooks.Slots do
	local b = button({ Size = UDim2.new(0.2, -7, 1, 0), Text = slot.Name, LayoutOrder = i, ZIndex = 22, Parent = gearTabs })
	b.Activated:Connect(function()
		gearSlot = slot
		list.CanvasPosition = Vector2.zero
		refreshShop()
	end)
	gearButtons[slot.Id] = b
end

for i, tab in TABS do
	local b = button({ Size = UDim2.new(1 / #TABS, -7, 1, 0), Name = tab.Id, Text = tab.Name, LayoutOrder = i, ZIndex = 22, Parent = tabBar })
	local function selectTab()
		shopTab = tab.Id
		list.CanvasPosition = Vector2.zero
		refreshShop()
	end
	b.Activated:Connect(selectTab)
	make("BindableEvent", { Name = "Press", Parent = b }).Event:Connect(selectTab)
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
shopPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not shopPanel.Visible then
		shopLooks.Hide()
	end
end)

-------------------------------------------------------------------------------
-- daily reward
-------------------------------------------------------------------------------
local dailyPanel = make("Frame", {
	Size = UDim2.fromOffset(640, 290),
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
local dayRow = make("Frame", { Size = UDim2.new(1, -32, 0, 118), Position = UDim2.fromOffset(16, 56),
	BackgroundTransparency = 1, ZIndex = 21, Parent = dailyPanel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local dayBoxes = {}
for day, reward in Config.DailyRewards do
	local box = make("Frame", { Size = UDim2.fromOffset(78, 118), BackgroundColor3 = Ui.PANEL, LayoutOrder = day,
		ZIndex = 22, Parent = dayRow }, { corner(10), stroke() })
	label({ Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 5), Text = "Day " .. day, ZIndex = 23, Parent = box })
	-- a gem pile that grows with the reward
	local pictureSlot = make("Frame", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, 0, 0, 26),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 23, Parent = box })
	Ui.rewardPicture(pictureSlot, { Kind = "Gems", Amount = reward }, nil, 23)
	label({ Size = UDim2.new(1, -6, 0, Config.DailyGold[day] and 16 or 24), Position = UDim2.fromOffset(3, Config.DailyGold[day] and 84 or 88),
		Text = "x" .. tostring(reward), TextColor3 = Ui.GEM, ZIndex = 24, Parent = box })
	if Config.DailyGold[day] then
		label({ Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 101), Text = "+" .. Config.DailyGold[day] .. " gold",
			TextColor3 = Ui.GOLD, ZIndex = 24, Parent = box })
	end
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

dailyButton.Press.Event:Connect(function()
	dailyPanel.Visible = true
	refreshDaily()
end)
shopButton.Press.Event:Connect(function()
	openShop()
end)
dailyButton.Activated:Connect(function()
	dailyPanel.Visible = not dailyPanel.Visible
	refreshDaily()
end)
dailyClose.Activated:Connect(function()
	dailyPanel.Visible = false
end)
claimButton.Activated:Connect(function()
	local ok, result, gold = Remotes.ClaimDaily:InvokeServer()
	if ok then
		showBanner("+" .. result .. " GEMS" .. ((gold or 0) > 0 and (" and " .. gold .. " GOLD") or ""),
			"Daily reward claimed. Come back tomorrow!", Ui.GEM)
		Ui.playSound("Coin")
		dailyPanel.Visible = false
	else
		showMessage(result or "Not yet", Ui.BAD)
	end
	refreshDaily()
end)
task.spawn(function()
	refreshDaily()
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

local clearedJson, clearedMaps
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
	local loading = GameState:GetAttribute("LoadingRun") == true
	lobbyBar.Visible = inLobby
	runButton.Text = loading and "Preparing battlefield…" or "Start run"
	runButton.Interactable = not loading
	mapButton.Interactable = not loading
	if isTouch then
		top.Size = UDim2.fromOffset(inLobby and 322 or 600, 64)
		stateLabel.Size = UDim2.fromOffset(inLobby and 290 or 180, 20)
		goldLabel.Visible = not inLobby
		buildLabel.Visible = not inLobby
		portalLabel.Visible = not inLobby
		abilityHolder.Visible = not inLobby
	end
	-- the weekly twist is announced when a run starts; on a phone its line only covered the hub
	eventLabel.Visible = inLobby and not isTouch
	goalLabel.Text = nextGoal()
	goalLabel.Visible = goalLabel.Text ~= ""
	goalLabel.Position = inLobby and UDim2.new(0.5, 0, 0, 8) or UDim2.new(0.5, 0, 0, isTouch and 60 or 76)
	towerBar.Visible = not inLobby
	top.Visible = not inLobby
	portalBack.Visible = not inLobby
	startButton.Visible = s == "Break"
	speedButton.Visible = s == "Break" or s == "Wave"
	local speed = GameState:GetAttribute("Speed") or 1
	speedButton.Text = isTouch and (speed .. "x speed") or ("Speed " .. speed .. "x")
	if inLobby then
		local mapInfo = Config.Maps[mapId] or Config.Maps.CursedForest
		waveLabel.Text = "The Outpost"
		local modeInfo = Config.FindById(Config.Modes, GameState:GetAttribute("Mode") or "Campaign")
		stateLabel.Text = mapInfo.Name .. " · " .. difficultyName()
			.. (modeInfo and modeInfo.Id ~= "Campaign" and (" · " .. modeInfo.Name) or "")
			.. (mapId == Config.RiftMap() and " · Rift map: double drops" or "")

		mapButton.Text = mapInfo.Name .. " · " .. difficultyName()
	elseif s == "Break" then
		stateLabel.Text = "Next wave in " .. (GameState:GetAttribute("NextWaveIn") or 0) .. "s"
	elseif s == "Wave" then
		stateLabel.Text = "Goblins attacking!"
	else
		stateLabel.Text = ""
	end

	-- the difficulty can only be changed in the Outpost (Map button / Map Board)
	local currentDiff = GameState:GetAttribute("Difficulty")
	local rawClears = player:GetAttribute("Cleared") or "{}"
	if rawClears ~= clearedJson then
		clearedJson = rawClears
		local ok, data = pcall(HttpService.JSONDecode, HttpService, rawClears)
		clearedMaps = ok and data or {}
	end
	local cleared = clearedMaps[mapId] or {}
	for id, b in diffButtons do
		local d = Config.FindById(Config.Difficulties, id)
		local locked = d.Unlock and not cleared[d.Unlock]
		local sub = b:FindFirstChild("Sub")
		if sub then
			if locked then
				sub.Text = "Locked: beat " .. d.Unlock .. " here first"
			elseif d.Tiers then
				local top = (player:GetAttribute("MythicBest") or 0) + 1
				sub.Text = id == currentDiff and string.format("Tier %d of %d · tap for the next", GameState:GetAttribute("Tier") or 1, top)
					or string.format("Endless tiers · %d open", top)
			else
				sub.Text = d.Subtitle .. " · gems x" .. d.Gems
			end
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
local refreshQueued = false
local function queueTop()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refreshTop()
	end)
end
GameState.AttributeChanged:Connect(queueTop)
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
	local heroId = player:GetAttribute("HeroId") or "Swordmaster"
	if heroPortrait:GetAttribute("Hero") ~= heroId then
		heroPortrait:Destroy()
		heroPortrait = Icons.Draw(heroPanel, Config.HeroIcons[heroId], nil,
			{ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(4, 3) })
		heroPortrait:SetAttribute("Hero", heroId)
	end
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
	queueTop()
end
player.AttributeChanged:Connect(refreshPlayer)
refreshPlayer()

task.spawn(function()
	local cooldowns = {
		{ attackShade, "AttackReadyAt", "AttackCooldown", Config.Hero.Attack.Cooldown },
		{ whirlShade, "WhirlwindReadyAt", "CooldownE", Config.Hero.Whirlwind.Cooldown },
		{ leapShade, "LeapReadyAt", "CooldownR", Config.Hero.Leap.Cooldown },
	}
	while true do
		local now = workspace:GetServerTimeNow()
		for _, cooldown in cooldowns do
			local shade, ready, duration, fallback = table.unpack(cooldown)
			local left = (player:GetAttribute(ready) or 0) - now
			local fill = left > 0 and math.clamp(left / (player:GetAttribute(duration) or fallback), 0, 1) or 0
			if shade.Size.Y.Scale ~= fill then
				shade.Size = UDim2.fromScale(1, fill)
			end
		end
		task.wait(isTouch and 0.05 or 0.025)
	end
end)

-------------------------------------------------------------------------------
-- placing defenders
-------------------------------------------------------------------------------
local placing = nil -- the defender type we're placing, or nil
local placingWithPad = false -- true: a controller is placing, the ghost stands in front of the hero
local ghost = nil
local ghostPos = nil -- phones: the spot that was tapped
local displayedPos, displayedReason
local placementPending = false
local placementRay = RaycastParams.new()
placementRay.FilterType = Enum.RaycastFilterType.Include
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
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	-- GetMouseLocation and TouchTapInWorld both report viewport coordinates.
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	placementRay.FilterDescendantsInstances = include
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, placementRay)
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
	-- the map's real outline (same rule as the server)
	local map = Config.Maps[Config.CurrentMap]
	if map and MapOutline.OutsideOf(map.Theme, position.X, position.Z) > -MapOutline.BuildStop then
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
	-- rocks, bushes, the ruin (same rule as the server)
	local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	if decor then
		for _, d in decor:GetChildren() do
			local r = d:GetAttribute("BlockRadius")
			local p = r and d:GetPivot().Position
			if r and (Vector3.new(p.X, 0, p.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < r + 2.5 then
				return false, d:GetAttribute("BlockWhy") or "Something is in the way"
			end
		end
	end
	-- the ground itself (same rule as the server): no water, no boulders
	local height, why = Ground.Pad(position, Ground.Foot[placing] or 2.5)
	if not height then
		return false, why
	end
	return true, nil
end

local function stopPlacing()
	placing = nil
	placingWithPad = false
	ghostPos, displayedPos, displayedReason = nil, nil, nil
	confirmBar.Visible = false
	tapHint.Visible = false
	tapHint.Text = "Tap the ground where it should go"
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

local function groundUnder(screenPos)
	local map = workspace:FindFirstChild("Map")
	local ground = map and map:FindFirstChild("Ground")
	if not ground then
		return nil
	end
	local path = map:FindFirstChild("Path")
	-- the real ground first (raised floors: the flat click plane lies behind them from the camera), then the plane
	local hit = screenRay(screenPos, { workspace.Terrain }) or screenRay(screenPos, { ground, path })
	if hit then
		return Vector3.new(hit.Position.X, 0, hit.Position.Z)
	end
end

local function snapPlacement(pos)
	return Vector3.new(math.floor(pos.X + 0.5), 0, math.floor(pos.Z + 0.5))
end

-- A tap (or a controller's ghost) that lands a little off a free spot takes the nearest free one within 4.5 studs
-- (research briefs, 2026-11-24: a fresh phone player should get a defender down within 90 seconds, and a thumb is
-- not a mouse). Rings of 8 spots at 1.5, 3 and 4.5 studs; nil when none is free. The mouse stays exact.
local function nearestFree(pos)
	pos = snapPlacement(pos)
	if canPlaceHere(pos) then
		return pos
	end
	for _, r in { 1.5, 3, 4.5 } do
		for i = 0, 7 do
			local a = i * math.pi / 4
			local spot = snapPlacement(pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			if canPlaceHere(spot) then
				return spot
			end
		end
	end
	return nil
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
	-- The translucent floor disc shows the full range without an outline pass or 40 edge parts.
	local range = info.Levels[1].Range
	local disc = makeDisc(range, Color3.fromRGB(120, 255, 120))
	disc.Name = "Range"
	disc.Transparency = 0.85
	disc.Parent = ghost
	local tagHolder = ghostPart({ Name = "TagHolder", Size = Vector3.one * 0.2, Transparency = 1 })
	local tag = make("BillboardGui", { Name = "Tag", Size = UDim2.fromOffset(260, 34), StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true, Parent = tagHolder })
	label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(255, 120, 120),
		TextStrokeTransparency = 0, Parent = tag })
	if isTouch then
		-- Show a legal preview as soon as a card is chosen. Players can move it before confirming.
		local camera = workspace.CurrentCamera
		-- the map's designed first spot (MapOutline.Start, the one the tutorial points at) when it is near and free
		local map = Config.Maps[Config.CurrentMap]
		local start = map and MapOutline.Start[map.Theme]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if start and start.FirstSpot and root and (root.Position * Vector3.new(1, 0, 1) - start.FirstSpot).Magnitude < 24
			and canPlaceHere(start.FirstSpot) then
			ghostPos = start.FirstSpot
			confirmBar.Visible = true
		elseif camera then
			for _, x in { 0.5, 0.38, 0.62 } do
				local viewport = camera.ViewportSize
				local spot = groundUnder(Vector2.new(viewport.X * x, viewport.Y * 0.6))
				spot = spot and nearestFree(spot)
				if spot then
					ghostPos = spot
					confirmBar.Visible = true
					break
				end
			end
		end
		tapHint.Visible = ghostPos == nil
	end
end

local function visualGround(pos)
	-- exactly where the defender will stand: the highest ground under its footprint (Ground.Pad on the server)
	local top = Ground.Footprint(pos, Ground.Foot[placing] or 2.5)
	return Vector3.new(pos.X, top, pos.Z)
end

local function refreshPlacement(pos)
	if not pos then
		ghost.Parent = nil
		displayedPos = nil
		return
	end
	pos = snapPlacement(pos)
	local ok, reason = canPlaceHere(pos)
	if pos == displayedPos and reason == displayedReason then
		return
	end
	displayedPos, displayedReason = pos, reason
	pos = visualGround(pos)
	local color = ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 80, 80)
	ghost.Body.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
	ghost.Top.CFrame = CFrame.new(pos + Vector3.new(0, 7.5, 0))
	ghost.Top.Color = ok and Config.Towers[placing].Color or color
	ghost.Body.Color = ghost.Top.Color
	ghost.Foot.CFrame = CFrame.new(pos + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ghost.Foot.Color = color
	ghost.Range.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ghost.Range.Color = color
	ghost.TagHolder.CFrame = CFrame.new(pos)
	ghost.TagHolder.Tag.Text.Text = reason or ""
	confirmButton.BackgroundColor3 = ok and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(84, 72, 69)
	ghost.Parent = workspace
end

-- controllers: the spot a few studs in front of the hero (walk to move the ghost)
local PAD_REACH = 7
local function padSpot()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	local look = rootPart.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
	local spot = rootPart.Position + forward * PAD_REACH
	return Vector3.new(spot.X, 0, spot.Z)
end

local placementElapsed = 0
local padAsked, padFound = nil, nil -- the controller's last spot and the free one found for it
RunService.Heartbeat:Connect(function(dt)
	if not placing or not ghost then
		return
	end
	placementElapsed += dt
	if placementElapsed >= (isTouch and 0.12 or 0.03) then
		placementElapsed = 0
		if placingWithPad then
			local spot = padSpot()
			if spot and (not padAsked or (spot - padAsked).Magnitude > 0.75) then
				padAsked, padFound = spot, nearestFree(spot)
			end
			ghostPos = padFound or spot
			refreshPlacement(ghostPos)
		elseif isTouch then
			refreshPlacement(ghostPos)
		else
			refreshPlacement(groundUnder(UserInputService:GetMouseLocation()))
		end
	end
end)

local function tryPlace(pos)
	if not pos or not placing or placementPending then
		return
	end
	pos = snapPlacement(pos)
	local valid, problem = canPlaceHere(pos)
	if not valid then
		showMessage(problem, Ui.BAD)
		return
	end
	local requestGhost = ghost
	placementPending = true
	local replied, ok, reason = pcall(Remotes.PlaceTower.InvokeServer, Remotes.PlaceTower, placing, pos)
	placementPending = false
	if requestGhost ~= ghost then
		return
	end
	if not replied then
		showMessage("Build request failed. Try again.", Ui.BAD)
	elseif ok then
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
	-- the next level's painted picture beside the panel (docs/tower-pipeline.md), when that tower has one
	local preview = infoPanel:FindFirstChild("NextLook")
	if not preview then
		preview = make("ImageLabel", { Name = "NextLook", BackgroundColor3 = Ui.DARK, BackgroundTransparency = 0.1,
			Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0, -104, 0, 0), Parent = infoPanel }, { corner(12), stroke() })
		label({ Name = "Caption", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -18), Text = "Next",
			TextColor3 = Ui.GOLD, Parent = preview })
	end
	local nextImage = nextLevel and ReplicatedStorage.ArtImages:GetAttribute(Config.TowerIcons[towerType] .. "_l" .. (level + 1))
	preview.Image = nextImage or ""
	preview.Visible = nextImage ~= nil
	if nextLevel then
		local gold = GameState:GetAttribute("Gold") or 0
		upgradeButton.Text = "Upgrade (" .. nextLevel.Cost .. " mana)"
		upgradeButton.BackgroundColor3 = gold >= nextLevel.Cost and Color3.fromRGB(60, 130, 60) or Color3.fromRGB(70, 70, 80)
	else
		upgradeButton.Text = "Max level"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	end
	local full = (GameState:GetAttribute("Wave") or 0) == 0
		or workspace:GetServerTimeNow() < (selected:GetAttribute("FullRefundUntil") or 0)
	sellButton.Text = "Sell (+" .. math.floor((selected:GetAttribute("Spent") or 0) * (full and 1 or Config.SellRefund)) .. " mana)"
	local base = selected.PrimaryPart and selected.PrimaryPart.Position or Vector3.zero
	if not rangeCircle then
		rangeCircle = makeDisc(stats.Range, Color3.fromRGB(150, 200, 255))
	end
	rangeCircle.Size = Vector3.new(0.15, stats.Range * 2, stats.Range * 2)
	rangeCircle.CFrame = CFrame.new(base.X, base.Y + 0.2, base.Z) * CFrame.Angles(0, 0, math.pi / 2)
	rangeCircle.Parent = workspace
end

local function selectTower(model)
	stopPlacing()
	selected = model
	infoPanel.Visible = true
	Ui.pop(infoPanel, 0.9)
	refreshInfo()
end

local function upgradeSelected()
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
end
upgradeButton.Activated:Connect(upgradeSelected)
-- the test build presses this button through here (scripts can't press A on a real controller)
make("BindableEvent", { Name = "Press", Parent = upgradeButton }).Event:Connect(upgradeSelected)

sellButton.Activated:Connect(function()
	if not selected then
		return
	end
	Remotes.SellTower:InvokeServer(selected)
	closeInfo()
end)

-- a click or tap in the world: place, or pick a defender
local function worldClick(screenPos)
	if shopPanel.Visible or dailyPanel.Visible or mapPanel.Visible or endPanel.Visible
		or GameState:GetAttribute("State") == "Lobby" then
		return
	end
	if placing then
		if isTouch then
			local pos = groundUnder(screenPos)
			if pos then
				-- (a little off a free spot: the nearest free one; nowhere free near: where the thumb was, red, with why)
				ghostPos = nearestFree(pos) or pos
				refreshPlacement(ghostPos)
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
local function nextSpeed()
	local current = GameState:GetAttribute("Speed") or 1
	local speeds = table.clone(Config.Speeds)
	if player:GetAttribute("PassSpeed3x") then
		table.insert(speeds, 3)
	end
	local idx = table.find(speeds, current) or 1
	Remotes.SetSpeed:FireServer(speeds[idx % #speeds + 1])
end
speedButton.Activated:Connect(nextSpeed)
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
	worldClick(position)
end)

GameState:GetAttributeChangedSignal("State"):Connect(function()
	local state = GameState:GetAttribute("State")
	if state ~= "Break" and state ~= "Wave" then
		stopPlacing()
		closeInfo()
	end
end)

-- keep the info panel right when gold changes
GameState:GetAttributeChangedSignal("Gold"):Connect(function()
	if selected then
		refreshInfo()
	end
end)

local shortcuts
if not isTouch then
	shortcuts = label({ BackgroundColor3 = Color3.fromRGB(37, 29, 25), BackgroundTransparency = 0.12, Size = UDim2.fromOffset(300, 40), Position = UDim2.new(1, -10, 1, -10), AnchorPoint = Vector2.new(1, 1),
		Text = "1-5 build · click a defender to upgrade · Shift builds more · B shop · Q cancel",
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextStrokeTransparency = 0.5, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = root })
	local function showShortcuts()
		shortcuts.Visible = GameState:GetAttribute("State") ~= "Lobby"
	end
	GameState:GetAttributeChangedSignal("State"):Connect(showShortcuts)
	showShortcuts()
end

-------------------------------------------------------------------------------
-- controllers (the full button table is at the top of Gamepad.luau)
-------------------------------------------------------------------------------
local GuiService = game:GetService("GuiService")
local Gamepad = Ui.Gamepad

-- panels: the highlight jumps in when they open, B closes them
Gamepad.Panel(shopPanel, { closeButton = shopClose, default = function()
	return tabButtons[shopTab] -- the tab that is showing
end })
Gamepad.Panel(dailyPanel, { default = claimButton, closeButton = dailyClose })
Gamepad.Panel(mapPanel, { closeButton = mapClose })
Gamepad.Panel(endPanel, { default = playAgainButton, closable = false })
Gamepad.Panel(infoPanel, { default = upgradeButton, close = closeInfo })
Gamepad.Hint(infoPanel, Enum.KeyCode.ButtonB, UDim2.new(1, -6, 0, 6))

local function panelOpen()
	return shopPanel.Visible or dailyPanel.Visible or mapPanel.Visible or endPanel.Visible
end

-- the defender cards: d-pad left/right moves a gold frame, X builds the framed one
local padIndex = 1
local padCards = {}
for i, towerType in Config.TowerOrder do
	local b = towerButtons[towerType].button
	local focus = make("Frame", { Name = "PadFocus", Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = b },
		{ corner(12), make("UIStroke", { Color = Ui.GOLD, Thickness = 3 }) })
	padCards[i] = { focus = focus, badge = Gamepad.Hint(b, Enum.KeyCode.ButtonX), keyHint = b:FindFirstChild("KeyHint") }
end
local function showPadCards()
	for i, card in padCards do
		card.focus.Visible = Gamepad.active and i == padIndex
		Gamepad.ShowHint(card.badge, i == padIndex)
		if card.keyHint then
			card.keyHint.Visible = not Gamepad.active
		end
	end
end

-- placing with a controller: the ghost stands in front of the hero, A builds, B cancels
local function padStartPlacing(towerType)
	startPlacing(towerType)
	if placing then
		placingWithPad = true
		GuiService.SelectedObject = nil
		ghostPos = padSpot()
		confirmBar.Visible = true
		tapHint.Text = "Walk to move it"
		tapHint.Visible = true
	end
end

-- the nearest of your own defenders, at most 14 studs away
local PICK_RANGE = 14
local function nearestDefender()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	local best, bestDistance = nil, PICK_RANGE
	for _, tower in workspace.Towers:GetChildren() do
		if tower:GetAttribute("Owner") == player.UserId and tower.PrimaryPart then
			local offset = tower.PrimaryPart.Position - rootPart.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = tower, distance
			end
		end
	end
	return best
end

Gamepad.Bind("TowerStep", { Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight }, function(keyCode)
	if not towerBar.Visible or panelOpen() then
		return false
	end
	local step = keyCode == Enum.KeyCode.DPadRight and 1 or -1
	padIndex = (padIndex - 1 + step) % #Config.TowerOrder + 1
	showPadCards()
	local towerType = Config.TowerOrder[padIndex]
	Ui.pop(towerButtons[towerType].button, 1.06)
	if placingWithPad then
		padStartPlacing(towerType) -- swap the ghost for the new card
	end
	return true
end)
Gamepad.Bind("Build", { Enum.KeyCode.ButtonX }, function()
	if not towerBar.Visible or panelOpen() then
		return false -- (in the Outpost X belongs to the station prompts)
	end
	local towerType = Config.TowerOrder[padIndex]
	if placing == towerType then
		stopPlacing()
	else
		padStartPlacing(towerType)
	end
	return true
end)
Gamepad.Bind("Confirm", { Enum.KeyCode.ButtonA }, function()
	if not placingWithPad or not placing then
		return false -- A jumps
	end
	task.spawn(tryPlace, ghostPos)
	return true
end)
Gamepad.Bind("PickDefender", { Enum.KeyCode.ButtonY }, function()
	if not towerBar.Visible or panelOpen() then
		return false
	end
	local tower = nearestDefender()
	if tower then
		selectTower(tower) -- the info panel opens with Upgrade highlighted
	else
		showMessage("Walk up to one of your defenders first", Ui.TEXT_DIM)
	end
	return true
end)
Gamepad.Bind("Attack", { Enum.KeyCode.ButtonR2 }, function()
	Remotes.HeroAttack:FireServer()
	return true
end)
Gamepad.Bind("Whirl", { Enum.KeyCode.ButtonR1 }, function()
	doWhirl()
	return true
end)
Gamepad.Bind("Leap", { Enum.KeyCode.ButtonL1 }, function()
	doLeap()
	return true
end)
Gamepad.Bind("StartWave", { Enum.KeyCode.ButtonL2 }, function()
	if not startButton.Visible or panelOpen() then
		return false
	end
	Remotes.StartWave:FireServer()
	return true
end)
Gamepad.Bind("Down", { Enum.KeyCode.DPadDown }, function()
	if lobbyBar.Visible and not panelOpen() then
		GuiService.SelectedObject = runButton -- the Outpost: highlight Start run (A starts, B leaves)
		return true
	elseif speedButton.Visible and not panelOpen() then
		nextSpeed()
		return true
	end
	return false
end)
lobbyBar.SelectionGroup = true
Gamepad.OnBack(function()
	if placing then
		stopPlacing()
		return true
	end
	return false
end)

-- the badges next to the action buttons (they show only while a controller is in use)
Gamepad.Hint(confirmButton, Enum.KeyCode.ButtonA)
Gamepad.Hint(cancelButton, Enum.KeyCode.ButtonB)
Gamepad.Hint(startButton, Enum.KeyCode.ButtonL2)
Gamepad.Hint(speedButton, Enum.KeyCode.DPadDown)
Gamepad.Hint(runButton, Enum.KeyCode.DPadDown)
Gamepad.Hint(attackButton, Enum.KeyCode.ButtonR2)
Gamepad.Hint(whirlButton, Enum.KeyCode.ButtonR1)
Gamepad.Hint(leapButton, Enum.KeyCode.ButtonL1)

Gamepad.OnChanged(function(active)
	showPadCards()
	for _, b in { attackButton, whirlButton, leapButton } do
		local keyHint = b:FindFirstChild("KeyHint")
		if keyHint then
			keyHint.Visible = not active
		end
	end
	if shortcuts then
		shortcuts.Text = active
			and ("Left/Right pick · " .. Gamepad.Name(Enum.KeyCode.ButtonX) .. " build · " .. Gamepad.Name(Enum.KeyCode.ButtonY)
				.. " your defender · " .. Gamepad.Name(Enum.KeyCode.ButtonL2) .. " start wave · Up menu")
			or "1-5 build · click a defender to upgrade · Shift builds more · B shop · Q cancel"
	end
	-- picked up the controller in the middle of placing: the ghost follows the hero from now on
	if active and placing and not placingWithPad then
		padStartPlacing(placing)
	end
end)


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
