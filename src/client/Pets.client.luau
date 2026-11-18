-- The Pets screen: hatch eggs with gold (chances shown before you buy),
-- pick the pet that follows you, evolve or release pets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local gui = make("ScreenGui", { Name = "PetHud", ResetOnSpawn = false, DisplayOrder = 3,
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

local petButton = require(script.Parent.Menu).Add("Pets", "🐾", 6)

local panel = make("Frame", { Size = UDim2.fromOffset(820, 500), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 30, Parent = root },
	{ corner(18), stroke(Color3.fromRGB(140, 255, 160), 3) })
label({ Size = UDim2.fromOffset(200, 36), Position = UDim2.fromOffset(16, 10), Text = "Pets",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local goldLabel = label({ Size = UDim2.fromOffset(200, 28), Position = UDim2.fromOffset(120, 14), Text = "",
	TextColor3 = Ui.GOLD, ZIndex = 31, Parent = panel })
local message = label({ Size = UDim2.fromOffset(360, 24), Position = UDim2.fromOffset(330, 16), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })

-- eggs on the left, with their chances
local eggColumn = make("Frame", { Size = UDim2.fromOffset(300, 430), Position = UDim2.fromOffset(16, 56), BackgroundTransparency = 1,
	ZIndex = 31, Parent = panel }, { make("UIListLayout", { Padding = UDim.new(0, 10) }) })
for i, egg in Config.Eggs do
	local card = make("Frame", { Size = UDim2.fromOffset(300, 206), BackgroundColor3 = Ui.PANEL, LayoutOrder = i, ZIndex = 32,
		Parent = eggColumn }, { corner(12), stroke(egg.Color, 2) })
	label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), Text = egg.Name, TextColor3 = egg.Color,
		ZIndex = 33, Parent = card })
	local total = 0
	for _, c in egg.Chances do
		total += c[2]
	end
	local lines = {}
	for _, c in egg.Chances do
		local pet = Config.Pets[c[1]]
		table.insert(lines, string.format("%s  %.1f%%  (+%d%% %s)", pet.Name, c[2] / total * 100, pet.Bonus,
			Items.Stats[pet.Stat] and Items.Stats[pet.Stat].Name or pet.Stat))
	end
	label({ Size = UDim2.new(1, -20, 0, 110), Position = UDim2.fromOffset(10, 36), Text = table.concat(lines, "\n"),
		Font = Enum.Font.Gotham, TextScaled = false, TextSize = 15, TextColor3 = Ui.TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, Parent = card })
	local hatch = button({ Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -50),
		BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Hatch: " .. egg.Price .. " gold", ZIndex = 33, Parent = card })
	hatch.Activated:Connect(function()
		local ok, result = Remotes.HatchEgg:InvokeServer(egg.Id)
		if ok then
			local info = Config.Pets[result.kind]
			message.Text = "You hatched " .. info.Name .. "!"
			message.TextColor3 = Items.Rarities[info.Rarity].Color
			Ui.pop(message, 1.6)
			Ui.playSound("Coin")
		else
			message.Text = result or "Can't hatch"
			message.TextColor3 = Ui.BAD
		end
	end)
end

-- your pets on the right
local list = make("ScrollingFrame", { Size = UDim2.fromOffset(476, 430), Position = UDim2.new(1, -16, 0, 56), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(35, 28, 48), BorderSizePixel = 0, ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 31, Parent = panel },
	{ corner(10), make("UIListLayout", { Padding = UDim.new(0, 6) }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })

local pets, equippedId = {}, nil

local function bonusText(pet)
	local info = Config.Pets[pet.kind]
	local value = info.Bonus * (1 + 0.1 * ((pet.level or 1) - 1)) * (pet.evolved and 2 or 1)
	return string.format("+%.1f%% %s", value, Items.Stats[info.Stat] and Items.Stats[info.Stat].Name or info.Stat)
end

local function refresh()
	goldLabel.Text = (player:GetAttribute("Gold") or 0) .. " gold"
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if #pets == 0 then
		local empty = make("Frame", { Size = UDim2.new(1, -12, 0, 60), BackgroundTransparency = 1, ZIndex = 32, Parent = list })
		label({ Size = UDim2.fromScale(1, 1), Text = "No pets yet. Hatch an egg with gold!", Font = Enum.Font.Gotham,
			TextColor3 = Ui.TEXT_DIM, ZIndex = 33, Parent = empty })
		return
	end
	local sorted = table.clone(pets)
	table.sort(sorted, function(a, b)
		local ra, rb = Config.Pets[a.kind].Rarity, Config.Pets[b.kind].Rarity
		if (a.id == equippedId) ~= (b.id == equippedId) then
			return a.id == equippedId
		end
		if ra ~= rb then
			return ra > rb
		end
		return (a.level or 1) > (b.level or 1)
	end)
	for i, pet in sorted do
		local info = Config.Pets[pet.kind]
		local color = Items.Rarities[info.Rarity].Color
		local row = make("Frame", { Size = UDim2.new(1, -12, 0, 62), BackgroundColor3 = Ui.PANEL, LayoutOrder = i, ZIndex = 32,
			Parent = list }, { corner(8), stroke(color, pet.id == equippedId and 3 or 1) })
		label({ Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(10, 6),
			Text = info.Name .. (pet.evolved and " (evolved)" or ""), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33, Parent = row })
		label({ Size = UDim2.fromOffset(220, 20), Position = UDim2.fromOffset(10, 34),
			Text = "Lv " .. (pet.level or 1) .. " · " .. bonusText(pet), Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = row })
		local equip = button({ Size = UDim2.fromOffset(74, 40), Position = UDim2.new(1, -170, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Text = pet.id == equippedId and "On" or "Equip",
			BackgroundColor3 = pet.id == equippedId and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(60, 130, 60), ZIndex = 33, Parent = row })
		equip.Activated:Connect(function()
			Remotes.EquipPet:InvokeServer(pet.id)
		end)
		local maxed = (pet.level or 1) >= Config.PetMaxLevel and not pet.evolved
		local other = button({ Size = UDim2.fromOffset(84, 40), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
			Text = maxed and "Evolve" or "Release", ZIndex = 33,
			BackgroundColor3 = maxed and Color3.fromRGB(150, 110, 40) or Color3.fromRGB(110, 60, 60), Parent = row })
		other.Activated:Connect(function()
			local ok, result
			if maxed then
				ok, result = Remotes.EvolvePet:InvokeServer(pet.id)
				message.Text = ok and (info.Name .. " evolved!") or (result or "Can't evolve")
			else
				ok, result = Remotes.ReleasePet:InvokeServer(pet.id)
				message.Text = ok and ("Released for " .. tostring(result) .. " gold") or (result or "Can't release")
			end
			message.TextColor3 = ok and Ui.GOLD or Ui.BAD
		end)
	end
end

Remotes.Pets.OnClientEvent:Connect(function(list2, equipped)
	pets, equippedId = list2 or {}, equipped
	if panel.Visible then
		refresh()
	end
end)
player:GetAttributeChangedSignal("Gold"):Connect(function()
	if panel.Visible then
		goldLabel.Text = (player:GetAttribute("Gold") or 0) .. " gold"
	end
end)

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		local p, e = Remotes.GetPets:InvokeServer()
		pets, equippedId = p or {}, e
		message.Text = "Eggs cost gold. Gold is earned by playing"
		message.TextColor3 = Ui.TEXT_DIM
		Ui.pop(panel, 0.85)
		refresh()
	end
end
petButton.Activated:Connect(toggle)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Pets" and not panel.Visible then
		toggle()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Q then
		panel.Visible = false
	end
end)
