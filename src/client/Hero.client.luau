-- The Heroes screen: pick your hero and spend stat points.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local gui = make("ScreenGui", { Name = "HeroHud", ResetOnSpawn = false, DisplayOrder = 3,
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

local heroButton = button({ Size = UDim2.fromOffset(150, 46), Position = UDim2.fromOffset(10, isTouch and 306 or 296),
	BackgroundColor3 = Color3.fromRGB(70, 110, 70), Text = "Heroes", Parent = root })
local pointDot = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -8, 0, -6),
	BackgroundColor3 = Color3.fromRGB(255, 60, 60), Visible = false, ZIndex = 3, Parent = heroButton }, { corner(8) })

local panel = make("Frame", { Size = UDim2.fromOffset(760, 600), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 30, Parent = root },
	{ corner(18), stroke(Color3.fromRGB(120, 200, 120), 3) })
label({ Size = UDim2.fromOffset(300, 36), Position = UDim2.fromOffset(16, 10), Text = "Heroes",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })

-- hero cards
local cardRow = make("Frame", { Size = UDim2.new(1, -32, 0, 150), Position = UDim2.fromOffset(16, 56), BackgroundTransparency = 1,
	ZIndex = 31, Parent = panel }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12) }) })
local cards = {}
for i, heroId in Config.HeroOrder do
	local hero = Config.Heroes[heroId]
	local b = make("TextButton", { Size = UDim2.fromOffset(173, 150), Text = "", BackgroundColor3 = Ui.PANEL, AutoButtonColor = true,
		LayoutOrder = i, ZIndex = 32, Parent = cardRow }, { corner(12), stroke(hero.Color, 2) })
	make("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = hero.Color, ZIndex = 33, Parent = b },
		{ corner(3) })
	label({ Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 22), Text = hero.Name, TextColor3 = hero.Color,
		ZIndex = 33, Parent = b })
	label({ Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 54), Text = hero.Role, Font = Enum.Font.Gotham,
		TextColor3 = Ui.TEXT_DIM, TextWrapped = true, ZIndex = 33, Parent = b })
	label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 98),
		Text = hero.Abilities.F .. " · " .. hero.Abilities.E .. " · " .. hero.Abilities.R, Font = Enum.Font.Gotham,
		TextColor3 = Color3.new(1, 1, 1), ZIndex = 33, Parent = b })
	local state = label({ Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 122), Text = "Pick",
		TextColor3 = Ui.GOLD, ZIndex = 33, Parent = b })
	b.Activated:Connect(function()
		Ui.playSound("Click")
		local ok, reason = Remotes.SelectHero:InvokeServer(heroId)
		if not ok then
			state.Text = reason or "Not now"
		end
	end)
	cards[heroId] = { button = b, state = state }
end

local helpLabel = label({ Size = UDim2.new(1, -32, 0, 22), Position = UDim2.fromOffset(16, 212), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextWrapped = true, ZIndex = 31, Parent = panel })

-- stat points
local levelLabel = label({ Size = UDim2.fromOffset(400, 28), Position = UDim2.fromOffset(16, 244), Text = "",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local freeLabel = label({ Size = UDim2.fromOffset(300, 28), Position = UDim2.new(1, -16, 0, 244), AnchorPoint = Vector2.new(1, 0),
	Text = "", TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 31, Parent = panel })
local rows = {}
for i, s in Config.StatPoints do
	local row = make("Frame", { Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 278 + (i - 1) * 40),
		BackgroundColor3 = Ui.PANEL, ZIndex = 31, Parent = panel }, { corner(8) })
	label({ Size = UDim2.fromOffset(140, 26), Position = UDim2.fromOffset(10, 4), Text = s.Name,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = row })
	local value = label({ Size = UDim2.fromOffset(420, 22), Position = UDim2.fromOffset(160, 6), Text = "",
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = row })
	local plus = button({ Size = UDim2.fromOffset(60, 28), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		Text = "+1", BackgroundColor3 = Color3.fromRGB(60, 130, 60), ZIndex = 32, Parent = row })
	plus.Activated:Connect(function()
		local ok, reason = Remotes.SpendPoint:InvokeServer(s.Id)
		if not ok then
			freeLabel.Text = reason or "Can't"
		end
	end)
	rows[s.Id] = { value = value, plus = plus }
end
-- Rebirth and Ascension (for heroes at the level cap)
local rebirthLabel = label({ Size = UDim2.fromOffset(440, 24), Position = UDim2.fromOffset(16, 446), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(255, 240, 170), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local rebirthButton = button({ Size = UDim2.fromOffset(220, 32), Position = UDim2.new(1, -16, 0, 442), AnchorPoint = Vector2.new(1, 0),
	Text = "Rebirth", BackgroundColor3 = Color3.fromRGB(150, 120, 40), ZIndex = 31, Parent = panel })
rebirthButton.Activated:Connect(function()
	local ok, result = Remotes.Rebirth:InvokeServer()
	freeLabel.Text = ok and ("Reborn! Rebirth " .. tostring(result)) or (result or "Can't")
end)
local ascLabel = label({ Size = UDim2.new(1, -32, 0, 22), Position = UDim2.fromOffset(16, 482), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local ascRow = make("Frame", { Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 508), BackgroundTransparency = 1,
	ZIndex = 31, Parent = panel }, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
local ascButtons = {}
for i, perk in Config.AscensionPerks do
	local b = button({ Size = UDim2.fromOffset(176, 34), Text = "", BackgroundColor3 = Color3.fromRGB(60, 70, 120), LayoutOrder = i,
		ZIndex = 32, Parent = ascRow })
	b.Activated:Connect(function()
		local ok, reason = Remotes.SpendAscension:InvokeServer(perk.Id)
		if not ok then
			freeLabel.Text = reason or "Can't"
		end
	end)
	ascButtons[perk.Id] = b
end

local resetButton = button({ Size = UDim2.fromOffset(260, 32), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1),
	Text = "Reset points", BackgroundColor3 = Color3.fromRGB(110, 60, 60), ZIndex = 31, Parent = panel })
resetButton.Activated:Connect(function()
	local ok, result = Remotes.ResetPoints:InvokeServer()
	freeLabel.Text = ok and ("Reset done (-" .. tostring(result) .. " gold)") or (result or "Can't")
end)

local function refresh()
	local heroId = player:GetAttribute("HeroId") or "Swordmaster"
	local hero = Config.Heroes[heroId] or Config.Heroes.Swordmaster
	for id, c in cards do
		local picked = id == heroId
		local info = Config.Heroes[id]
		local locked = info.UnlockWins and (player:GetAttribute("Wins") or 0) < info.UnlockWins
		c.state.Text = picked and "PLAYING" or (locked and ("Locked: " .. (info.UnlockText or "")) or "Pick")
		c.state.TextColor3 = picked and Color3.fromRGB(120, 255, 120) or (locked and Ui.TEXT_DIM or Ui.GOLD)
		c.button:FindFirstChildOfClass("UIStroke").Thickness = picked and 5 or 2
	end
	helpLabel.Text = hero.Help
	local level = player:GetAttribute("HeroLevel") or 1
	levelLabel.Text = hero.Name .. " level " .. level .. " · " .. (player:GetAttribute("HeroMaxHealth") or 100) .. " health"
	local free = player:GetAttribute("StatPointsFree") or 0
	freeLabel.Text = free .. " free point" .. (free == 1 and "" or "s")
	pointDot.Visible = free > 0
	for _, s in Config.StatPoints do
		local n = player:GetAttribute("Stat" .. s.Id) or 0
		rows[s.Id].value.Text = n .. " points = +" .. (n * s.Per) .. s.Text
		rows[s.Id].plus.BackgroundColor3 = free > 0 and Color3.fromRGB(60, 130, 60) or Color3.fromRGB(70, 70, 80)
	end
	resetButton.Text = "Reset points (" .. level * Config.StatResetGoldPerLevel .. " gold)"
	local rebirths = player:GetAttribute("Rebirths") or 0
	rebirthLabel.Text = "Rebirths: " .. rebirths .. " (+" .. rebirths * Config.RebirthBonus .. "% xp and gold forever)"
	local canRebirth = level >= Config.HeroMaxLevel
	rebirthButton.Text = canRebirth and "Rebirth now!" or ("Rebirth at level " .. Config.HeroMaxLevel)
	rebirthButton.BackgroundColor3 = canRebirth and Color3.fromRGB(150, 120, 40) or Color3.fromRGB(70, 70, 80)
	local ascPoints = player:GetAttribute("AscensionPoints") or 0
	ascLabel.Text = "Ascension: " .. ascPoints .. " point(s) to spend"
		.. (canRebirth and string.format(" · next point %d/%d xp", player:GetAttribute("AscensionXp") or 0, Config.AscensionXp)
			or " · earned with xp after level " .. Config.HeroMaxLevel)
	for _, perk in Config.AscensionPerks do
		local n = player:GetAttribute("Asc" .. perk.Id) or 0
		ascButtons[perk.Id].Text = perk.Name .. " +" .. (n * perk.Per) .. "%"
	end
end
player.AttributeChanged:Connect(function(attr)
	local prefix = attr:sub(1, 3)
	if prefix == "Her" or prefix == "Sta" or prefix == "Reb" or prefix == "Asc" then
		refresh()
	end
end)
refresh()

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Ui.pop(panel, 0.85)
		refresh()
	end
end
heroButton.Activated:Connect(toggle)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Heroes" and not panel.Visible then
		toggle()
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.H then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Q then
		panel.Visible = false
	end
end)
