-- Loot on your screen: your own drops (with beams for rare ones), picking
-- them up by walking over them, the backpack (equip, compare, upgrade,
-- salvage) and the Victory Chest reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Ground = require(ReplicatedStorage.Shared.Ground)
local Art = require(ReplicatedStorage.Shared.Art)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

local player = Players.LocalPlayer
local isTouch = Ui.isTouch
local PICKUP_RANGE = 6 -- walk right up to it

-------------------------------------------------------------------------------
-- screen (same scaling as the main game screen)
-------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "LootHud",
	ResetOnSpawn = false,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
Ui.fitRoot(gui, root, 848, 524)

local function rarityOf(item)
	return Items.Rarities[item.rarity] or Items.Rarities[1]
end

-- the painted picture of an item kind (art/icons/item_*.png), or nil while it has not loaded
local function itemImage(item)
	local base = item and item.base
	return base and Art.Image("item_" .. string.lower((string.gsub(base, "%s", "")))) or nil
end
-- an ImageLabel showing an item's picture inside `parent` (hidden when there is no picture)
local function itemPicture(parent, item, props)
	local defaults = { Name = "Picture", BackgroundTransparency = 1, Image = itemImage(item) or "",
		ScaleType = Enum.ScaleType.Fit, Parent = parent }
	for k, v in props do
		defaults[k] = v
	end
	local picture = make("ImageLabel", defaults)
	picture.Visible = picture.Image ~= ""
	return picture
end

-------------------------------------------------------------------------------
-- toasts: "Picked up Rare Runed Longsword"
-------------------------------------------------------------------------------
local toasts = make("Frame", {
	Size = UDim2.fromOffset(420, 200),
	Position = UDim2.new(1, -16, 1, isTouch and -235 or -170),
	AnchorPoint = Vector2.new(1, 1),
	BackgroundTransparency = 1,
	Parent = root,
}, { make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }) })

local function toast(text, color, item)
	local image = item and itemImage(item)
	local box = make("Frame", { Size = UDim2.fromOffset(400, image and 52 or 34), BackgroundColor3 = Ui.DARK,
		BackgroundTransparency = 0.15, Parent = toasts }, { corner(8), stroke(color, 2) })
	if image then
		-- the item itself, in a little slot in its rarity colour
		local slot = make("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.65), Parent = box }, { corner(8), stroke(color, 2) })
		itemPicture(slot, item, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3) })
		Ui.pop(slot, 1.5)
	end
	local l = label({ Size = UDim2.new(1, image and -64 or -16, 1, -8), Position = UDim2.fromOffset(image and 56 or 8, 4),
		Text = text, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
	Ui.pop(box, 1.15)
	task.delay(4, function()
		TweenService:Create(box, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.5)
		box:Destroy()
	end)
end

-------------------------------------------------------------------------------
-- drops in the world: they pop out of the goblin, land, and glow more the
-- rarer they are. Walk over them to pick them up (they don't come by themselves).
-------------------------------------------------------------------------------
local drops = {} -- [dropId] = { model, base, rarity, asked, landed }
local dropFolder = make("Folder", { Name = "MyLoot", Parent = workspace })
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- how loud each rarity is: light range, beam height and width, sparkles per second
local LOUDNESS = {
	{ light = 6, beam = 0, width = 0, sparkles = 0, ring = 2.5 },
	{ light = 9, beam = 0, width = 0, sparkles = 4, ring = 3 },
	{ light = 12, beam = 28, width = 0.8, sparkles = 10, ring = 3.5 },
	{ light = 16, beam = 50, width = 1.3, sparkles = 18, ring = 4.5 },
	{ light = 22, beam = 80, width = 2, sparkles = 30, ring = 6 },
	{ light = 30, beam = 120, width = 3, sparkles = 50, ring = 8 },
}

local function lootPart(model, props)
	local p = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- a little object that looks like the kind of item it is
local function itemShape(model, slot, color, material)
	local parts = {}
	local function add(props, offset)
		local p = lootPart(model, props)
		table.insert(parts, { part = p, offset = offset })
	end
	if slot == "Weapon" then
		add({ Size = Vector3.new(0.35, 0.15, 3), Material = material, Color = color }, CFrame.new(0, 0, -0.6))
		add({ Size = Vector3.new(1.2, 0.25, 0.25), Color = Color3.fromRGB(120, 80, 40) }, CFrame.new(0, 0, 0.95))
		add({ Size = Vector3.new(0.25, 0.25, 0.8), Color = Color3.fromRGB(90, 60, 30) }, CFrame.new(0, 0, 1.45))
	elseif slot == "Helmet" then
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Material = material, Color = color }, CFrame.new())
		add({ Size = Vector3.new(1.8, 0.3, 1.8), Material = material, Color = color }, CFrame.new(0, -0.5, 0))
	elseif slot == "Armor" then
		add({ Size = Vector3.new(1.6, 1.8, 0.8), Material = material, Color = color }, CFrame.new())
		add({ Size = Vector3.new(2.4, 0.5, 0.9), Material = material, Color = color }, CFrame.new(0, 0.75, 0))
	elseif slot == "Boots" then
		for _, x in { -0.45, 0.45 } do
			add({ Size = Vector3.new(0.6, 1, 0.6), Material = material, Color = color }, CFrame.new(x, 0.2, 0))
			add({ Size = Vector3.new(0.6, 0.4, 1.1), Material = material, Color = color }, CFrame.new(x, -0.3, -0.25))
		end
	else -- Trinket: a ring with a gem
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.4, 1.4), Material = material, Color = color },
			CFrame.Angles(0, math.pi / 2, 0))
		add({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) },
			CFrame.new(0, 0.7, 0))
	end
	return parts
end

Remotes.LootDrop.OnClientEvent:Connect(function(dropId, position, rarityIndex, name, slot)
	local r = Items.Rarities[rarityIndex] or Items.Rarities[1]
	local loud = LOUDNESS[rarityIndex] or LOUDNESS[1]
	local model = make("Model", { Name = "Loot" })
	-- on the ground where it falls: the higher of the monster's own footing (a lane, a bridge) and the terrain
	-- there (a raised floor beside the lane). The ground is not flat any more: never a fixed height.
	local floor = math.max(position.Y, (Ground.At(position.X, position.Z)))
	local base = Vector3.new(position.X, floor + 1.6, position.Z)
	local material = rarityIndex >= 3 and Enum.Material.Neon or Enum.Material.Metal
	local parts = itemShape(model, slot, r.Color, material)
	local core = parts[1].part
	make("PointLight", { Color = r.Color, Range = loud.light, Brightness = 1 + rarityIndex * 0.5, Parent = core })

	-- glowing circle on the ground
	local ring = lootPart(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, loud.ring, loud.ring),
		CFrame = CFrame.new(base.X, floor + 0.12, base.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = r.Color,
		Material = Enum.Material.Neon, Transparency = 0.5 })
	-- sparkles
	if loud.sparkles > 0 then
		make("ParticleEmitter", { Texture = SPARKLE, Color = ColorSequence.new(r.Color), LightEmission = 1, Rate = loud.sparkles,
			Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.5 + rarityIndex * 0.15, 0), Parent = core })
	end
	-- a light beam you see from far away (Rare and up)
	local beam = nil
	if loud.beam > 0 then
		beam = lootPart(model, { Name = "Beam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(loud.beam, loud.width, loud.width),
			CFrame = CFrame.new(base.X, floor + loud.beam / 2, base.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = r.Color,
			Material = Enum.Material.Neon, Transparency = 0.4 })
	end
	local tag = make("BillboardGui", { Size = UDim2.fromOffset(240, 40), StudsOffset = Vector3.new(0, 2.6, 0),
		AlwaysOnTop = true, MaxDistance = 60 + rarityIndex * 25, Parent = core })
	label({ Size = UDim2.new(1, 0, 0.45, 0), Text = r.Name, Font = Enum.Font.GothamBlack, TextColor3 = r.Color,
		TextStrokeTransparency = 0.1, Parent = tag })
	label({ Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.45), Text = name, TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = r.Color, TextStrokeTransparency = 0.2, Parent = tag })
	model.Parent = dropFolder

	-- it pops out of the goblin and lands
	drops[dropId] = { model = model, parts = parts, ring = ring, beam = beam, base = base, rarity = rarityIndex,
		asked = 0, born = os.clock(), from = base + Vector3.new(0, 4, 0) }
	if rarityIndex >= 3 then
		toast(r.Name .. " drop! " .. name, r.Color)
		Ui.playSound("Coin")
	end
	if rarityIndex >= 5 then
		-- Legendary and Mythic: a big moment
		local big = label({ Size = UDim2.fromOffset(700, 60), Position = UDim2.fromScale(0.5, 0.28), AnchorPoint = Vector2.new(0.5, 0.5),
			Text = string.upper(r.Name) .. " DROP!", Font = Enum.Font.GothamBlack, TextColor3 = r.Color, TextStrokeTransparency = 0,
			Parent = root })
		Ui.pop(big, 1.8)
		task.delay(2.5, function()
			big:Destroy()
		end)
	end
end)

Remotes.LootPicked.OnClientEvent:Connect(function(dropId, item)
	local d = drops[dropId]
	if d then
		d.model:Destroy()
		drops[dropId] = nil
	end
	if item then
		local r = rarityOf(item)
		toast(r.Name .. " " .. Items.DisplayName(item), r.Color, item)
		Ui.playSound("Coin")
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for dropId, d in drops do
		-- pop out in an arc for the first half second, then float and spin
		local t = math.min(1, (now - d.born) / 0.5)
		local pos
		if t < 1 then
			local flat = d.from:Lerp(d.base, t)
			pos = flat + Vector3.new(0, math.sin(t * math.pi) * 4, 0)
		else
			pos = d.base + Vector3.new(0, math.sin(now * 3) * 0.3, 0)
		end
		local cf = CFrame.new(pos) * CFrame.Angles(math.rad(20), now * 1.5, 0)
		for _, item in d.parts do
			item.part.CFrame = cf * item.offset
		end
		if d.beam and d.rarity >= 5 then
			-- Legendary and Mythic beams pulse (Mythic in rainbow colours)
			d.beam.Transparency = 0.3 + math.sin(now * 4) * 0.15
			if d.rarity >= 6 then
				local c = Color3.fromHSV((now * 0.3) % 1, 0.8, 1)
				d.beam.Color = c
				d.ring.Color = c
			end
		end
		if rootPart and now - d.asked > 0.5 then
			local flat = Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			if (flat - Vector3.new(d.base.X, 0, d.base.Z)).Magnitude <= PICKUP_RANGE then
				d.asked = now
				Remotes.PickupLoot:FireServer(dropId)
			end
		end
	end
end)

-- remind players to grab their loot before leaving the battlefield
local GameState = ReplicatedStorage:WaitForChild("GameState")
GameState:GetAttributeChangedSignal("State"):Connect(function()
	local s = GameState:GetAttribute("State")
	if (s == "Won" or s == "Lost") and next(drops) then
		toast("Grab your loot before going back to the Outpost!", Ui.GOLD)
	end
end)

-------------------------------------------------------------------------------
-- backpack screen
-------------------------------------------------------------------------------
local inventory, gear = {}, {}

local bagButton, newDot = require(script.Parent.Menu).Add("Backpack", "Backpack", 3)

local panel = make("Frame", {
	Size = UDim2.fromOffset(820, 500),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 30,
	Parent = root,
}, { corner(18), stroke(Color3.fromRGB(200, 150, 80), 3) })
label({ Size = UDim2.fromOffset(200, 36), Position = UDim2.fromOffset(16, 10), Text = "Backpack",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local countLabel = label({ Size = UDim2.fromOffset(90, 26), Position = UDim2.fromOffset(176, 16), Text = "0/60",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 31, Parent = panel })
local goldLabel = label({ Size = UDim2.fromOffset(180, 28), Position = UDim2.fromOffset(300, 14), Text = "0 gold",
	TextColor3 = Ui.GOLD, ZIndex = 31, Parent = panel })
local scrapLabel = label({ Size = UDim2.fromOffset(160, 28), Position = UDim2.fromOffset(480, 14), Text = "0 scrap",
	TextColor3 = Ui.SCRAP, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })

-- equipped slots row
local slotRow = make("Frame", { Size = UDim2.fromOffset(440, 74), Position = UDim2.fromOffset(16, 56),
	BackgroundTransparency = 1, ZIndex = 31, Parent = panel },
	{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
local slotBoxes = {}
for i, slot in Items.Slots do
	local b = make("TextButton", { Size = UDim2.fromOffset(80, 74), BackgroundColor3 = Ui.PANEL, Text = "",
		AutoButtonColor = true, LayoutOrder = i, ZIndex = 32, Parent = slotRow }, { corner(10), stroke() })
	label({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 4), Text = slot, Font = Enum.Font.Gotham,
		TextColor3 = Ui.TEXT_DIM, ZIndex = 33, Parent = b })
	local name = label({ Size = UDim2.new(1, -6, 0, 46), Position = UDim2.fromOffset(3, 22), Text = "empty",
		TextWrapped = true, ZIndex = 33, Parent = b })
	local picture = make("ImageLabel", { Name = "Picture", BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(0.5, 0, 0, 21), AnchorPoint = Vector2.new(0.5, 0), ScaleType = Enum.ScaleType.Fit, Visible = false,
		ZIndex = 33, Parent = b })
	slotBoxes[slot] = { button = b, name = name, picture = picture }
end
local totalsLabel = label({ Size = UDim2.fromOffset(440, 40), Position = UDim2.fromOffset(16, 134), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 230, 200), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })

-- the grid of items
local grid = make("ScrollingFrame", {
	Size = UDim2.fromOffset(440, 306),
	Position = UDim2.fromOffset(16, 180),
	BackgroundColor3 = Color3.fromRGB(35, 28, 48),
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 31,
	Parent = panel,
}, {
	corner(10),
	make("UIGridLayout", { CellSize = UDim2.fromOffset(80, 80), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
})

-- details on the right
local detail = make("Frame", { Size = UDim2.fromOffset(330, 420), Position = UDim2.new(1, -16, 0, 66), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Ui.PANEL, ZIndex = 31, Parent = panel }, { corner(12) })
local dSlot = make("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Ui.DARK,
	Visible = false, ZIndex = 32, Parent = detail }, { corner(10), stroke(Ui.GOLD, 3) })
local dPicture = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5),
	ScaleType = Enum.ScaleType.Fit, ZIndex = 33, Parent = dSlot })
local dName = label({ Size = UDim2.new(1, -114, 0, 52), Position = UDim2.fromOffset(104, 10), Text = "Pick an item",
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = detail })
local dRarity = label({ Size = UDim2.new(1, -114, 0, 20), Position = UDim2.fromOffset(104, 66), Text = "",
	Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = detail })
local dStats = label({ Size = UDim2.new(1, -20, 0, 140), Position = UDim2.fromOffset(10, 104), Text = "",
	Font = Enum.Font.Gotham, TextScaled = false, TextSize = 17, RichText = true, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32, Parent = detail })
local equipButton = button({ Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 252),
	BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Equip", ZIndex = 32, Parent = detail })
local upgradeButton = button({ Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 302),
	BackgroundColor3 = Color3.fromRGB(150, 110, 40), Text = "Upgrade", ZIndex = 32, Parent = detail })
local salvageButton = button({ Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 352),
	BackgroundColor3 = Color3.fromRGB(110, 60, 60), Text = "Salvage", ZIndex = 32, Parent = detail })

local selectedId = nil
local salvageArmed = nil -- press Salvage twice on good items

local function findItem(id)
	for _, item in inventory do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function equippedIn(slot)
	return gear[slot] and findItem(gear[slot]) or nil
end

local refresh -- defined below

local function showDetail()
	local item = selectedId and findItem(selectedId)
	salvageArmed = nil
	equipButton.Visible, upgradeButton.Visible, salvageButton.Visible = item ~= nil, item ~= nil, item ~= nil
	if not item then
		dSlot.Visible = false
		dName.Text = "Pick an item"
		dName.TextColor3 = Color3.new(1, 1, 1)
		dRarity.Text = ""
		dStats.Text = "Click an item to see it.\nWeapons drop from goblins, and the Goblin King always drops a Victory Chest."
		return
	end
	local r = rarityOf(item)
	local image = itemImage(item)
	dSlot.Visible = image ~= nil
	dPicture.Image = image or ""
	dSlot.BackgroundColor3 = r.Color:Lerp(Color3.fromRGB(30, 24, 36), 0.75)
	dSlot:FindFirstChildOfClass("UIStroke").Color = r.Color
	dName.Text = Items.DisplayName(item)
	dName.TextColor3 = r.Color
	dRarity.Text = r.Name .. " " .. item.slot .. " · item level " .. item.ilvl
	dRarity.TextColor3 = r.Color

	-- each stat, compared with what you wear in that slot now
	local current = equippedIn(item.slot)
	local isOn = current and current.id == item.id
	local lines = {}
	if item.slot == "Weapon" then
		local w = Items.WeaponTypes[item.base]
		if w then
			table.insert(lines, "<b>" .. w.Name .. "</b>: " .. w.Text)
		end
	end
	for _, stat in Items.StatOrder do
		local v = Items.StatValue(item, stat)
		local old = current and not isOn and Items.StatValue(current, stat) or v
		if v > 0 or old > 0 then
			local diff = v - old
			local diffText = ""
			if not isOn and math.abs(diff) >= 0.05 then
				diffText = string.format(diff > 0 and '  <font color="#66ff77">(+%.1f)</font>' or '  <font color="#ff7777">(%.1f)</font>', diff)
			end
			table.insert(lines, string.format("+%.1f%% %s <font color=\"#b8b0d0\">%s</font>%s", v, Items.Stats[stat].Name,
				Items.Stats[stat].Text, diffText))
		end
	end
	if current and not isOn then
		table.insert(lines, '<font color="#b8b0d0">Compared with: ' .. Items.DisplayName(current) .. "</font>")
	end
	dStats.Text = table.concat(lines, "\n")

	equipButton.Text = isOn and "Equipped" or "Equip"
	equipButton.BackgroundColor3 = isOn and Color3.fromRGB(70, 70, 80) or Color3.fromRGB(60, 130, 60)
	local gold, scrap = Items.UpgradeCost(item)
	if gold then
		upgradeButton.Text = "Upgrade to +" .. (item.plus + 1) .. ": " .. gold .. " gold" .. (scrap > 0 and (", " .. scrap .. " scrap") or "")
		local canPay = (player:GetAttribute("Gold") or 0) >= gold and (player:GetAttribute("Scrap") or 0) >= scrap
		upgradeButton.BackgroundColor3 = canPay and Color3.fromRGB(150, 110, 40) or Color3.fromRGB(70, 70, 80)
	else
		upgradeButton.Text = "Max +" .. Items.MaxPlus
		upgradeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	end
	salvageButton.Text = isOn and "Wearing it (can't salvage)" or ("Salvage: +" .. Items.SalvageValue(item) .. " scrap")
	salvageButton.BackgroundColor3 = isOn and Color3.fromRGB(70, 70, 80) or Color3.fromRGB(110, 60, 60)
end

local function card(item, order)
	local r = rarityOf(item)
	local isOn = gear[item.slot] == item.id
	local b = make("TextButton", { Text = "", BackgroundColor3 = Color3.fromRGB(45, 38, 60), AutoButtonColor = true,
		LayoutOrder = order, ZIndex = 32, Parent = grid }, { corner(8), stroke(r.Color, item.id == selectedId and 4 or 2) })
	make("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = r.Color, ZIndex = 33, Parent = b }, { corner(3) })
	b.BackgroundColor3 = r.Color:Lerp(Color3.fromRGB(30, 24, 36), 0.78) -- a hint of its rarity behind the picture
	local picture = itemPicture(b, item, { Size = UDim2.new(1, -16, 1, -28), Position = UDim2.fromOffset(8, 8), ZIndex = 33 })
	if not picture.Visible then
		-- (no picture loaded yet: the old text card)
		label({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 9), Text = item.slot, Font = Enum.Font.Gotham,
			TextColor3 = Ui.TEXT_DIM, ZIndex = 33, Parent = b })
		label({ Size = UDim2.new(1, -6, 0, 34), Position = UDim2.fromOffset(3, 26), Text = item.slot == "Weapon"
			and (Items.WeaponTypes[item.base] and Items.WeaponTypes[item.base].Name or item.base) or item.base,
			TextColor3 = r.Color, TextWrapped = true, ZIndex = 33, Parent = b })
	end
	label({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 1, -18),
		Text = (isOn and "ON  " or "") .. ((item.plus or 0) > 0 and ("+" .. item.plus) or ("lv " .. item.ilvl)),
		TextColor3 = isOn and Color3.fromRGB(120, 255, 120) or Color3.new(1, 1, 1), ZIndex = 33, Parent = b })
	if item.new then
		make("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -14, 0, 10), BackgroundColor3 = Color3.fromRGB(255, 60, 60),
			ZIndex = 34, Parent = b }, { corner(6) })
	end
	b.Activated:Connect(function()
		Ui.playSound("Click")
		selectedId = item.id
		refresh()
	end)
end

function refresh()
	for _, child in grid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local sorted = table.clone(inventory)
	table.sort(sorted, function(a, b)
		local aOn, bOn = gear[a.slot] == a.id, gear[b.slot] == b.id
		if aOn ~= bOn then
			return aOn
		end
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return a.ilvl > b.ilvl
	end)
	local anyNew = false
	for i, item in sorted do
		card(item, i)
		anyNew = anyNew or item.new == true
	end
	newDot.Visible = anyNew and not panel.Visible
	countLabel.Text = #inventory .. "/" .. (player:GetAttribute("BackpackSize") or Items.BackpackSize)

	for slot, box in slotBoxes do
		local item = equippedIn(slot)
		if item then
			local r = rarityOf(item)
			local image = itemImage(item)
			box.picture.Image = image or ""
			box.picture.Visible = image ~= nil
			box.name.Text = image and "" or Items.DisplayName(item)
			box.name.TextColor3 = r.Color
			box.button:FindFirstChildOfClass("UIStroke").Color = r.Color
		else
			box.picture.Visible = false
			box.name.Text = "empty"
			box.name.TextColor3 = Ui.TEXT_DIM
			box.button:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(200, 160, 80)
		end
	end
	local equippedList = {}
	for slot in gear do
		local item = equippedIn(slot)
		if item then
			equippedList[slot] = item
		end
	end
	local totals = Items.Totals(equippedList)
	local parts = {}
	for _, stat in Items.StatOrder do
		if totals[stat] > 0 then
			table.insert(parts, Items.FormatStat(stat, totals[stat]))
		end
	end
	totalsLabel.Text = #parts > 0 and ("Your gear: " .. table.concat(parts, "  ·  ")) or "Your gear gives no bonus yet"
	showDetail()
end

for slot, box in slotBoxes do
	box.button.Activated:Connect(function()
		local item = equippedIn(slot)
		if item then
			selectedId = item.id
			refresh()
		end
	end)
end

local function refreshMoney()
	goldLabel.Text = (player:GetAttribute("Gold") or 0) .. " gold"
	scrapLabel.Text = (player:GetAttribute("Scrap") or 0) .. " scrap"
	if panel.Visible then
		showDetail()
	end
end
player:GetAttributeChangedSignal("Gold"):Connect(refreshMoney)
player:GetAttributeChangedSignal("Scrap"):Connect(refreshMoney)
refreshMoney()

Remotes.Inventory.OnClientEvent:Connect(function(items, equipped)
	inventory, gear = items or {}, equipped or {}
	refresh()
end)
task.spawn(function()
	local items, equipped = Remotes.GetInventory:InvokeServer()
	if items then
		inventory, gear = items, equipped or {}
		refresh()
	end
end)

local function openBag()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Ui.pop(panel, 0.85)
		refresh()
	else
		Remotes.SeenGear:FireServer()
		for _, item in inventory do
			item.new = nil
		end
		refresh()
	end
end
bagButton.Activated:Connect(openBag)
bagButton.Press.Event:Connect(openBag)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Backpack" and not panel.Visible then
		openBag()
	end
end)
closeButton.Activated:Connect(function()
	if panel.Visible then
		openBag()
	end
end)

local function act(remote, okText)
	if not selectedId then
		return
	end
	local ok, result = remote:InvokeServer(selectedId)
	if ok then
		if okText then
			toast(okText(result), Ui.GOLD)
		end
		Ui.playSound("Coin")
	else
		toast(result or "Can't do that", Ui.BAD)
	end
end

equipButton.Activated:Connect(function()
	act(Remotes.EquipGear)
end)
upgradeButton.Activated:Connect(function()
	act(Remotes.UpgradeGear, function(plus)
		return "Upgraded to +" .. tostring(plus) .. "!"
	end)
end)
salvageButton.Activated:Connect(function()
	local item = selectedId and findItem(selectedId)
	if not item then
		return
	end
	-- Epic and better: press twice so nobody salvages by accident
	if item.rarity >= 4 and salvageArmed ~= item.id then
		salvageArmed = item.id
		salvageButton.Text = "Sure? Press again"
		return
	end
	act(Remotes.SalvageGear, function(scrap)
		return "+" .. tostring(scrap) .. " scrap"
	end)
	selectedId = nil
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		openBag()
	elseif input.KeyCode == Enum.KeyCode.Q and panel.Visible then
		openBag()
	end
end)

-------------------------------------------------------------------------------
-- Victory Chest reveal
-------------------------------------------------------------------------------
local chestPanel = make("Frame", {
	Size = UDim2.fromOffset(440, 420),
	Position = UDim2.fromScale(0.5, 0.47),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Ui.DARK,
	Visible = false,
	ZIndex = 40,
	Parent = root,
}, { corner(18), stroke(Ui.GOLD, 4) })
label({ Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 18), Text = "VICTORY CHEST",
	Font = Enum.Font.GothamBlack, TextColor3 = Ui.GOLD, ZIndex = 42, Parent = chestPanel })
-- the item you got, big, in a slot in its rarity colour
local chestSlot = make("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, 0, 0, 142),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.PANEL, ZIndex = 42, Parent = chestPanel },
	{ corner(18), stroke(Ui.GOLD, 4) })
local chestPicture = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -18, 1, -18),
	Position = UDim2.fromOffset(9, 9), ScaleType = Enum.ScaleType.Fit, ZIndex = 43, Parent = chestSlot })
local chestRarity = label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 226), Text = "",
	ZIndex = 42, Parent = chestPanel })
local chestName = label({ Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, 250), Text = "",
	Font = Enum.Font.GothamBlack, ZIndex = 42, Parent = chestPanel })
local chestStats = label({ Size = UDim2.new(1, -48, 0, 46), Position = UDim2.fromOffset(24, 290), Text = "",
	Font = Enum.Font.Gotham, TextWrapped = true, ZIndex = 42, Parent = chestPanel })
local chestOk = button({ Size = UDim2.fromOffset(200, 48), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(100, 60, 170), Text = "Nice!", ZIndex = 42, Parent = chestPanel })
chestOk.Activated:Connect(function()
	chestPanel.Visible = false
end)

Remotes.VictoryChest.OnClientEvent:Connect(function(item, kept)
	local r = rarityOf(item)
	chestPanel.Visible = true
	chestRarity.Text = "..."
	chestName.Text = ""
	chestStats.Text = ""
	-- first the open chest, then the item pops out of it
	chestPicture.Image = Art.Image("chest_open") or ""
	chestSlot.BackgroundColor3 = Ui.PANEL
	chestSlot:FindFirstChildOfClass("UIStroke").Color = Ui.GOLD
	chestPanel:FindFirstChildOfClass("UIStroke").Color = Ui.GOLD
	Ui.pop(chestPanel, 0.6)
	task.wait(1.2) -- a little suspense
	chestRarity.Text = r.Name .. " " .. item.slot
	chestRarity.TextColor3 = r.Color
	chestName.Text = Items.DisplayName(item)
	chestName.TextColor3 = r.Color
	chestPanel:FindFirstChildOfClass("UIStroke").Color = r.Color
	chestPicture.Image = itemImage(item) or chestPicture.Image
	chestSlot.BackgroundColor3 = r.Color:Lerp(Color3.fromRGB(30, 24, 36), 0.7)
	chestSlot:FindFirstChildOfClass("UIStroke").Color = r.Color
	Ui.pop(chestSlot, 1.6)
	local parts = {}
	for _, stat in Items.StatOrder do
		local v = Items.StatValue(item, stat)
		if v > 0 then
			table.insert(parts, Items.FormatStat(stat, v))
		end
	end
	chestStats.Text = table.concat(parts, "  ·  ") .. (kept and "" or "\n(backpack full: turned into scrap)")
	Ui.pop(chestName, 1.5)
	Ui.playSound("Coin")
	-- closes by itself if nobody taps it
	local shown = chestName.Text
	task.delay(7, function()
		if chestPanel.Visible and chestName.Text == shown then
			chestPanel.Visible = false
		end
	end)
end)

-- gold earned at the end of a run
player:GetAttributeChangedSignal("LastGold"):Connect(function()
	local g = player:GetAttribute("LastGold") or 0
	if g > 0 then
		toast("+" .. g .. " gold for the blacksmith (open your Backpack)", Ui.GOLD)
	end
end)

-- controllers: the highlight jumps into the panel when it opens, B closes it
Ui.Gamepad.Panel(panel, { closeButton = closeButton, close = function()
	if panel.Visible then
		openBag() -- (closing through here also marks new gear as seen)
	end
end })
Ui.Gamepad.Panel(chestPanel, { default = chestOk })
