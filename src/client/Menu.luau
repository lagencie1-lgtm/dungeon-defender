-- The side menu: one wooden dock with square icon buttons, shared by all
-- the screens (shop, backpack, heroes...). Each screen adds its own button.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Ui = require(script.Parent.Ui)
local make, corner, label = Ui.make, Ui.corner, Ui.label

local Menu = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SIZE = 54

local WOOD = Color3.fromRGB(70, 46, 30)
local WOOD_DARK = Color3.fromRGB(40, 26, 18)
local BRASS = Color3.fromRGB(214, 170, 80)

local gui = make("ScreenGui", { Name = "SideMenu", ResetOnSpawn = false, DisplayOrder = 1,
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

-- the dock: a dark wooden board with a brass frame
local dock = make("Frame", {
	Name = "Dock",
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(SIZE + 16, 0),
	Position = UDim2.fromOffset(8, isTouch and 108 or 96),
	BackgroundColor3 = WOOD,
	Parent = root,
}, {
	corner(14),
	make("UIStroke", { Color = BRASS, Thickness = 3 }),
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 130, 120)), Rotation = 90 }),
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }),
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- adds a button. Returns the button and a red dot to show "something new"
function Menu.Add(name, icon, order, color)
	local b = make("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = WOOD_DARK,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = order,
		Parent = dock,
	}, {
		corner(12),
		make("UIStroke", { Color = color or BRASS, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 150)), Rotation = 90 }),
	})
	label({ Name = "Icon", Size = UDim2.new(1, 0, 0, SIZE - 20), Position = UDim2.fromOffset(0, 3), Text = icon,
		Font = Enum.Font.GothamBold, Parent = b })
	label({ Name = "Caption", Size = UDim2.new(1, -4, 0, 13), Position = UDim2.new(0, 2, 1, -15), Text = name,
		Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 180), TextStrokeTransparency = 0.4, Parent = b })
	local dot = make("Frame", { Name = "Dot", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -10, 0, -6),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60), Visible = false, ZIndex = 3, Parent = b },
		{ corner(8), make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }) })
	local scale = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		scale.Scale = 1.08
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	b.Activated:Connect(function()
		Ui.playSound("Click")
		Ui.pop(b, 0.9)
	end)
	return b, dot
end

-- the wallet in the top-left corner: gems and gold
local wallet = make("Frame", {
	Name = "Wallet",
	Size = UDim2.fromOffset(250, 34),
	Position = UDim2.fromOffset(8, isTouch and 64 or 52),
	BackgroundColor3 = WOOD,
	Parent = root,
}, { corner(10), make("UIStroke", { Color = BRASS, Thickness = 2 }) })
local gemsText = label({ Size = UDim2.new(0.5, -8, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "0",
	TextColor3 = Ui.GEM, TextXAlignment = Enum.TextXAlignment.Left, Parent = wallet })
local goldText = label({ Size = UDim2.new(0.5, -8, 1, -8), Position = UDim2.new(0.5, 0, 0, 4), Text = "0",
	TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = wallet })
local function refreshWallet()
	gemsText.Text = "💎 " .. (player:GetAttribute("Gems") or 0)
	goldText.Text = "💰 " .. (player:GetAttribute("Gold") or 0)
end
player:GetAttributeChangedSignal("Gems"):Connect(function()
	refreshWallet()
	Ui.pop(gemsText, 1.2)
end)
player:GetAttributeChangedSignal("Gold"):Connect(refreshWallet)
refreshWallet()

return Menu
