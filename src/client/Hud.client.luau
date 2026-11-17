-- The game screen on each player's computer: gold, waves, portal health,
-- defender buttons, placing/upgrading/selling, hero abilities and messages.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameState = ReplicatedStorage:WaitForChild("GameState")

workspace:WaitForChild("Map"):WaitForChild("Ground")
workspace:WaitForChild("Towers")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GOLD = Color3.fromRGB(255, 210, 70)
local DARK = Color3.fromRGB(25, 20, 35)
local PANEL = Color3.fromRGB(40, 32, 55)

-------------------------------------------------------------------------------
-- little helpers to make UI pieces
-------------------------------------------------------------------------------
local function make(className, props, children)
	local obj = Instance.new(className)
	for k, v in props do
		obj[k] = v
	end
	for _, child in children or {} do
		child.Parent = obj
	end
	return obj
end

local function corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness)
	return make("UIStroke", { Color = color or Color3.fromRGB(120, 90, 160), Thickness = thickness or 2 })
end

local function label(props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	})
	for k, v in props do
		l[k] = v
	end
	return l
end

local function button(props)
	local b = make("TextButton", {
		BackgroundColor3 = PANEL,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}, { corner(8), stroke() })
	for k, v in props do
		b[k] = v
	end
	return b
end

local gui = make("ScreenGui", {
	Name = "RealmGuardiansHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-------------------------------------------------------------------------------
-- top bar: wave, gold, portal health
-------------------------------------------------------------------------------
local top = make("Frame", {
	Size = UDim2.fromOffset(560, 64),
	Position = UDim2.new(0.5, 0, 0, 8),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { corner(12), stroke() })

local waveLabel = label({ Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(12, 6), Text = "Wave 0/10",
	TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local stateLabel = label({ Size = UDim2.fromOffset(170, 20), Position = UDim2.fromOffset(12, 38), Text = "",
	TextColor3 = Color3.fromRGB(200, 190, 230), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local goldLabel = label({ Size = UDim2.fromOffset(130, 34), Position = UDim2.fromOffset(190, 14), Text = "200",
	TextColor3 = GOLD, Parent = top })
label({ Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(345, 6), Text = "Portal",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 170, 255), Parent = top })
local portalBack = make("Frame", { Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(345, 26),
	BackgroundColor3 = Color3.fromRGB(50, 30, 40), Parent = top }, { corner(6) })
local portalFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 90, 255),
	Parent = portalBack }, { corner(6) })
local portalText = label({ Size = UDim2.fromScale(1, 1), Text = "100 / 100", ZIndex = 2, Parent = portalBack })

local startButton = button({
	Size = UDim2.fromOffset(200, 40),
	Position = UDim2.new(0.5, 0, 0, 80),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(150, 60, 40),
	Text = "Start wave now",
	Parent = gui,
})

-------------------------------------------------------------------------------
-- messages in the middle of the screen
-------------------------------------------------------------------------------
local messages = make("Frame", {
	Size = UDim2.fromOffset(600, 160),
	Position = UDim2.new(0.5, 0, 0, 130),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, { make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }) })

local function showMessage(text, color)
	local l = label({ Size = UDim2.fromOffset(600, 30), Text = text, TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2, Parent = messages })
	task.delay(3, function()
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.6)
		l:Destroy()
	end)
	local list = messages:GetChildren()
	if #list > 6 then
		for _, child in list do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end
Remotes.Notify.OnClientEvent:Connect(showMessage)

-------------------------------------------------------------------------------
-- defender buttons (bottom middle)
-------------------------------------------------------------------------------
local towerBar = make("Frame", {
	Size = UDim2.fromOffset(#Config.TowerOrder * 150 + 10, 96),
	Position = UDim2.new(0.5, 0, 1, -10),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Parent = gui,
}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

local towerButtons = {}
for i, towerType in Config.TowerOrder do
	local info = Config.Towers[towerType]
	local b = button({ Size = UDim2.fromOffset(140, 96), Text = "", LayoutOrder = i, Parent = towerBar })
	make("Frame", { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = info.Color,
		Parent = b }, { corner(3) })
	label({ Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 18), Text = info.DisplayName, Parent = b })
	label({ Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 42), Text = info.Cost .. " gold",
		TextColor3 = GOLD, Parent = b })
	label({ Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 66), Text = info.Description,
		Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 190, 220), TextWrapped = true, Parent = b })
	label({ Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -26, 0, -8), Text = tostring(i),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(90, 70, 130), Parent = b }, {})
	towerButtons[towerType] = b
end

-------------------------------------------------------------------------------
-- hero panel (bottom left)
-------------------------------------------------------------------------------
local heroPanel = make("Frame", {
	Size = UDim2.fromOffset(250, 120),
	Position = UDim2.new(0, 10, 1, -10),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { corner(12), stroke() })
local heroName = label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6),
	Text = Config.Hero.Name .. "  Lv 1", TextXAlignment = Enum.TextXAlignment.Left, Parent = heroPanel })
local xpBack = make("Frame", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 34),
	BackgroundColor3 = Color3.fromRGB(50, 45, 60), Parent = heroPanel }, { corner(4) })
local xpFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 200, 255),
	Parent = xpBack }, { corner(4) })

local function abilityButton(text, key, x)
	local b = button({ Size = UDim2.fromOffset(110, 58), Position = UDim2.fromOffset(x, 52), Text = "", Parent = heroPanel })
	label({ Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 6), Text = text, Parent = b })
	label({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 32), Text = "Key: " .. key,
		Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 190, 220), Parent = b })
	local shade = make("Frame", { Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Parent = b }, { corner(8) })
	return b, shade
end
local attackButton, attackShade = abilityButton("Sword", "F", 10)
local whirlButton, whirlShade = abilityButton("Whirlwind", "E", 130)

-------------------------------------------------------------------------------
-- defender info panel (shows when you click one of your defenders)
-------------------------------------------------------------------------------
local infoPanel = make("Frame", {
	Size = UDim2.fromOffset(220, 170),
	Position = UDim2.new(1, -10, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = gui,
}, { corner(12), stroke() })
local infoTitle = label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 8), Text = "", Parent = infoPanel })
local infoStats = label({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 36), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(210, 200, 230), TextWrapped = true, Parent = infoPanel })
local upgradeButton = button({ Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 82),
	BackgroundColor3 = Color3.fromRGB(60, 120, 60), Text = "Upgrade", Parent = infoPanel })
local sellButton = button({ Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 124),
	BackgroundColor3 = Color3.fromRGB(130, 50, 50), Text = "Sell", Parent = infoPanel })

-------------------------------------------------------------------------------
-- end screen
-------------------------------------------------------------------------------
local endPanel = make("Frame", {
	Size = UDim2.fromOffset(420, 220),
	Position = UDim2.fromScale(0.5, 0.45),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = DARK,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { corner(16), stroke(GOLD, 3) })
local endTitle = label({ Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 16), Text = "", ZIndex = 11, Parent = endPanel })
local endText = label({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 86), Text = "", ZIndex = 11,
	Font = Enum.Font.Gotham, Parent = endPanel })
local playAgainButton = button({ Size = UDim2.fromOffset(220, 50), Position = UDim2.new(0.5, 0, 1, -20),
	AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(90, 60, 150), Text = "Play again", ZIndex = 11,
	Parent = endPanel })

label({ Size = UDim2.fromOffset(330, 18), Position = UDim2.new(1, -10, 1, -10), AnchorPoint = Vector2.new(1, 1),
	Text = "1/2/3 build  ·  click defender to upgrade  ·  Q cancel", Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(200, 190, 220), TextStrokeTransparency = 0.5, Parent = gui })

-------------------------------------------------------------------------------
-- keep the screen up to date
-------------------------------------------------------------------------------
local function refreshTop()
	local gold = GameState:GetAttribute("Gold") or 0
	goldLabel.Text = gold .. " gold"
	waveLabel.Text = "Wave " .. (GameState:GetAttribute("Wave") or 0) .. "/" .. (GameState:GetAttribute("MaxWave") or 10)
	local hp = GameState:GetAttribute("PortalHealth") or 0
	local maxHp = GameState:GetAttribute("MaxPortalHealth") or 100
	portalFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	portalText.Text = hp .. " / " .. maxHp

	local s = GameState:GetAttribute("State")
	startButton.Visible = s == "Break"
	if s == "Break" then
		stateLabel.Text = "Next wave in " .. (GameState:GetAttribute("NextWaveIn") or 0) .. "s"
	elseif s == "Wave" then
		stateLabel.Text = "Goblins attacking!"
	else
		stateLabel.Text = ""
	end

	endPanel.Visible = s == "Won" or s == "Lost"
	if s == "Won" then
		endTitle.Text = "VICTORY!"
		endTitle.TextColor3 = GOLD
		endText.Text = "All waves beaten · " .. (GameState:GetAttribute("Kills") or 0) .. " goblins defeated"
	elseif s == "Lost" then
		endTitle.Text = "The portal has fallen"
		endTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
		endText.Text = "You reached wave " .. (GameState:GetAttribute("Wave") or 0)
	end

	for towerType, b in towerButtons do
		local affordable = gold >= Config.Towers[towerType].Cost
		b.BackgroundColor3 = affordable and PANEL or Color3.fromRGB(45, 40, 45)
	end
end
GameState.AttributeChanged:Connect(refreshTop)
refreshTop()

local function refreshHero()
	local level = player:GetAttribute("HeroLevel") or 1
	heroName.Text = Config.Hero.Name .. "  Lv " .. level
	local needed = player:GetAttribute("HeroXpNeeded") or 1
	local xp = player:GetAttribute("HeroXp") or 0
	xpFill.Size = UDim2.fromScale(level >= Config.Hero.MaxLevel and 1 or math.clamp(xp / needed, 0, 1), 1)
end
player.AttributeChanged:Connect(refreshHero)
refreshHero()

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local attackLeft = (player:GetAttribute("AttackReadyAt") or 0) - now
	attackShade.Size = UDim2.fromScale(1, math.clamp(attackLeft / Config.Hero.Attack.Cooldown, 0, 1))
	local whirlLeft = (player:GetAttribute("WhirlwindReadyAt") or 0) - now
	whirlShade.Size = UDim2.fromScale(1, math.clamp(whirlLeft / Config.Hero.Whirlwind.Cooldown, 0, 1))
end)

-------------------------------------------------------------------------------
-- placing defenders
-------------------------------------------------------------------------------
local placing = nil -- the defender type we're placing, or nil
local ghost = nil
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

local function mouseRay(include)
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

-- same rules as the server, so the ghost shows green or red
local function canPlaceHere(position)
	local half = Config.MapSize / 2
	if math.abs(position.X) > half.X - 4 or math.abs(position.Z) > half.Y - 4 then
		return false
	end
	if Config.DistanceToPath(position) < Config.PathWidth / 2 + 3 then
		return false
	end
	if (Vector3.new(position.X, 0, position.Z) - Config.Path[#Config.Path]).Magnitude < 14 then
		return false
	end
	for _, tower in workspace.Towers:GetChildren() do
		if tower.PrimaryPart then
			local p = tower.PrimaryPart.Position
			if (Vector3.new(p.X, 0, p.Z) - position).Magnitude < Config.TowerSpacing then
				return false
			end
		end
	end
	return true
end

local function stopPlacing()
	placing = nil
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
	if (GameState:GetAttribute("Gold") or 0) < info.Cost then
		showMessage("Not enough gold for a " .. info.DisplayName, Color3.fromRGB(255, 120, 120))
		return
	end
	placing = towerType
	ghost = make("Model", { Name = "PlacementGhost" })
	local body = make("Part", {
		Name = "Body",
		Size = Vector3.new(4, 6, 4),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 0.5,
		Material = Enum.Material.ForceField,
		Color = info.Color,
		Parent = ghost,
	})
	ghost.PrimaryPart = body
	local disc = makeDisc(info.Levels[1].Range, Color3.fromRGB(120, 255, 120))
	disc.Name = "Range"
	disc.Parent = ghost
	ghost.Parent = workspace
end

local function placeGhostPosition()
	local hit = mouseRay({ workspace.Map.Ground, workspace.Map.Path })
	if not hit then
		return nil
	end
	return Vector3.new(hit.Position.X, 0, hit.Position.Z)
end

RunService.RenderStepped:Connect(function()
	if not placing or not ghost then
		return
	end
	local pos = placeGhostPosition()
	if not pos then
		return
	end
	local ok = canPlaceHere(pos)
	ghost.Body.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	ghost.Range.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local color = ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 80, 80)
	ghost.Range.Color = color
	ghost.Body.Color = ok and Config.Towers[placing].Color or color
end)

local function tryPlace()
	local pos = placeGhostPosition()
	if not pos then
		return
	end
	local towerType = placing
	local ok, reason = Remotes.PlaceTower:InvokeServer(towerType, pos)
	if ok then
		-- keep placing the same defender while holding Shift
		if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			stopPlacing()
		end
	else
		showMessage(reason or "Can't place here", Color3.fromRGB(255, 120, 120))
	end
end

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
		upgradeButton.Text = "Upgrade (" .. nextLevel.Cost .. " gold)"
		upgradeButton.AutoButtonColor = true
	else
		upgradeButton.Text = "Max level"
		upgradeButton.AutoButtonColor = false
	end
	sellButton.Text = "Sell (+" .. math.floor(selected:GetAttribute("Spent") * Config.SellRefund) .. " gold)"
	if rangeCircle then
		rangeCircle:Destroy()
	end
	local base = selected.PrimaryPart.Position
	rangeCircle = makeDisc(stats.Range, Color3.fromRGB(150, 200, 255))
	rangeCircle.CFrame = CFrame.new(base.X, 0.2, base.Z) * CFrame.Angles(0, 0, math.pi / 2)
	rangeCircle.Parent = workspace
end

local function selectTower(model)
	stopPlacing()
	selected = model
	infoPanel.Visible = true
	refreshInfo()
end

upgradeButton.Activated:Connect(function()
	if not selected then
		return
	end
	local ok, reason = Remotes.UpgradeTower:InvokeServer(selected)
	if not ok then
		showMessage(reason or "Can't upgrade", Color3.fromRGB(255, 120, 120))
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

-------------------------------------------------------------------------------
-- buttons and keys
-------------------------------------------------------------------------------
for towerType, b in towerButtons do
	b.Activated:Connect(function()
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
playAgainButton.Activated:Connect(function()
	Remotes.PlayAgain:FireServer()
end)
attackButton.Activated:Connect(function()
	Remotes.HeroAttack:FireServer()
end)
whirlButton.Activated:Connect(function()
	Remotes.HeroWhirlwind:FireServer()
end)

local NUMBER_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if placing then
			tryPlace()
		else
			local hit = mouseRay({ workspace.Towers })
			local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model.Parent == workspace.Towers then
				selectTower(model)
			else
				closeInfo()
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		stopPlacing()
	elseif input.KeyCode == Enum.KeyCode.Q then
		stopPlacing()
		closeInfo()
	elseif input.KeyCode == Enum.KeyCode.F then
		Remotes.HeroAttack:FireServer()
	elseif input.KeyCode == Enum.KeyCode.E then
		Remotes.HeroWhirlwind:FireServer()
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

-- keep the info panel right when gold or the defender changes
GameState:GetAttributeChangedSignal("Gold"):Connect(function()
	if selected then
		refreshInfo()
	end
end)

print("Welcome to Realm Guardians!")
