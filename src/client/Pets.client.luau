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

local gui = make("ScreenGui", { Name = "PetHud", ResetOnSpawn = false, DisplayOrder = 3,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
Ui.fitRoot(gui, root, 964, 564)

local Art = require(ReplicatedStorage.Shared.Art)
local TweenService = game:GetService("TweenService")

local petButton = require(script.Parent.Menu).Add("Pets", "Pets", 6)

local function rarityColor(kind)
	return Items.Rarities[Config.Pets[kind].Rarity].Color
end
local function petImage(kind)
	return Art.Image("pet_" .. string.lower(kind))
end
local function eggImage(egg)
	return Art.Image("egg_" .. string.lower((string.gsub(egg.Id, "Egg$", ""))))
end

-- a square tile with a pet's picture on a plate in its rarity colour (its name when the picture isn't loaded)
local function petTile(parent, kind, size, zIndex, props)
	local color = rarityColor(kind)
	local defaults = { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color:Lerp(Color3.fromRGB(30, 24, 36), 0.72),
		ZIndex = zIndex, Parent = parent }
	for k, v in props or {} do
		defaults[k] = v
	end
	local tile = make("Frame", defaults, { corner(math.floor(size / 6)), stroke(color, 2) })
	local image = petImage(kind)
	if image then
		make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
			Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = zIndex + 1, Parent = tile })
	else
		label({ Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), Text = Config.Pets[kind].Name, TextWrapped = true,
			TextColor3 = color, ZIndex = zIndex + 1, Parent = tile })
	end
	return tile
end

local panel = make("Frame", { Size = UDim2.fromOffset(940, 540), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 30, Parent = root },
	{ corner(18), stroke(Color3.fromRGB(140, 255, 160), 3) })
label({ Size = UDim2.fromOffset(120, 36), Position = UDim2.fromOffset(24, 16), Text = "Pets",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local goldLabel = label({ Size = UDim2.fromOffset(200, 28), Position = UDim2.fromOffset(130, 20), Text = "",
	TextColor3 = Ui.GOLD, ZIndex = 31, Parent = panel })
local message = label({ Size = UDim2.fromOffset(440, 24), Position = UDim2.fromOffset(350, 22), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -18, 0, 14), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })

-------------------------------------------------------------------------------
-- the hatch reveal: the egg shakes, then the pet pops out
-------------------------------------------------------------------------------
local reveal = make("Frame", { Size = UDim2.fromOffset(380, 400), Position = UDim2.fromScale(0.5, 0.48),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 50, Parent = root },
	{ corner(18), stroke(Ui.GOLD, 4) })
local revealTitle = label({ Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 18), Text = "", Font = Enum.Font.GothamBlack,
	TextColor3 = Ui.GOLD, ZIndex = 52, Parent = reveal })
local revealSlot = make("Frame", { Size = UDim2.fromOffset(180, 180), Position = UDim2.new(0.5, 0, 0, 150),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.PANEL, ZIndex = 52, Parent = reveal }, { corner(22), stroke(Ui.GOLD, 4) })
local revealPicture = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
	ScaleType = Enum.ScaleType.Fit, ZIndex = 53, Parent = revealSlot })
local revealName = label({ Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, 250), Text = "", Font = Enum.Font.GothamBlack,
	ZIndex = 52, Parent = reveal })
local revealInfo = label({ Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 290), Text = "", Font = Enum.Font.Gotham,
	TextColor3 = Ui.TEXT_DIM, ZIndex = 52, Parent = reveal })
local revealOk = button({ Size = UDim2.fromOffset(180, 46), Position = UDim2.new(0.5, 0, 1, -22), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Nice!", ZIndex = 52, Parent = reveal })
revealOk.Activated:Connect(function()
	reveal.Visible = false
end)
local revealToken = 0
local function showReveal(egg, pet, chance)
	revealToken += 1
	local my = revealToken
	local info = Config.Pets[pet.kind]
	local color = rarityColor(pet.kind)
	reveal.Visible = true
	revealTitle.Text = egg.Name
	revealName.Text = ""
	revealInfo.Text = "..."
	revealPicture.Image = eggImage(egg) or ""
	revealSlot.BackgroundColor3 = Ui.PANEL
	revealSlot:FindFirstChildOfClass("UIStroke").Color = Ui.GOLD
	reveal:FindFirstChildOfClass("UIStroke").Color = Ui.GOLD
	Ui.pop(reveal, 0.7)
	-- the egg wobbles, faster and faster
	for i = 1, 6 do
		if my ~= revealToken then
			return
		end
		TweenService:Create(revealPicture, TweenInfo.new(0.09), { Rotation = (i % 2 == 0 and 1 or -1) * (6 + i * 2) }):Play()
		task.wait(0.19 - i * 0.015)
	end
	if my ~= revealToken then
		return
	end
	revealPicture.Rotation = 0
	revealPicture.Image = petImage(pet.kind) or ""
	revealSlot.BackgroundColor3 = color:Lerp(Color3.fromRGB(30, 24, 36), 0.65)
	revealSlot:FindFirstChildOfClass("UIStroke").Color = color
	reveal:FindFirstChildOfClass("UIStroke").Color = color
	revealName.Text = info.Name
	revealName.TextColor3 = color
	revealInfo.Text = string.format("%s  ·  %s chance", Items.Rarities[info.Rarity].Name,
		chance >= 1 and string.format("%.0f%%", chance) or string.format("%.2f%%", chance))
	Ui.pop(revealSlot, info.Rarity >= 5 and 2 or 1.5)
	Ui.pop(revealName, 1.4)
	Ui.playSound("Coin")
end

-------------------------------------------------------------------------------
-- eggs on the left: the egg, its price, and a picture of every pet inside with its chance
-------------------------------------------------------------------------------
local eggColumn = make("ScrollingFrame", { Size = UDim2.fromOffset(440, 450), Position = UDim2.fromOffset(24, 66),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ZIndex = 31, Parent = panel }, { make("UIListLayout", { Padding = UDim.new(0, 10) }) })
-- (built each time the screen opens: the pictures load a moment after the game starts)
local function buildEggs()
	for _, child in eggColumn:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, egg in Config.Eggs do
		local total = 0
		for _, c in egg.Chances do
			total += c[2]
		end
		local rows = math.ceil(#egg.Chances / 4)
		local card = make("Frame", { Size = UDim2.fromOffset(428, 110 + rows * 92), BackgroundColor3 = Ui.PANEL, LayoutOrder = i,
			ZIndex = 32, Parent = eggColumn }, { corner(12), stroke(egg.Color, 2) })
		local eggSlot = make("Frame", { Size = UDim2.fromOffset(88, 88), Position = UDim2.fromOffset(10, 10),
			BackgroundColor3 = egg.Color:Lerp(Color3.fromRGB(30, 24, 36), 0.7), ZIndex = 33, Parent = card }, { corner(14), stroke(egg.Color, 2) })
		make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
			Image = eggImage(egg) or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 34, Parent = eggSlot })
		label({ Size = UDim2.fromOffset(300, 30), Position = UDim2.fromOffset(110, 10), Text = egg.Name, TextColor3 = egg.Color,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = card })
		local hatch = button({ Size = UDim2.fromOffset(212, 44), Position = UDim2.fromOffset(110, 50),
			BackgroundColor3 = Color3.fromRGB(60, 130, 60), Text = "Hatch: " .. egg.Price .. " gold", ZIndex = 33, Parent = card })
		-- three at once: the same price each and the same odds (gold only)
		local hatch3 = button({ Size = UDim2.fromOffset(80, 44), Position = UDim2.fromOffset(330, 50),
			BackgroundColor3 = Color3.fromRGB(50, 105, 50), Text = "x3", ZIndex = 33, Parent = card })
		-- what can come out
		local inside = make("Frame", { Size = UDim2.new(1, -20, 0, rows * 92), Position = UDim2.fromOffset(10, 106),
			BackgroundTransparency = 1, ZIndex = 33, Parent = card },
			{ make("UIGridLayout", { CellSize = UDim2.fromOffset(96, 86), CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder }) })
		for n, c in egg.Chances do
			local percent = c[2] / total * 100
			local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = n, ZIndex = 33, Parent = inside })
			petTile(cell, c[1], 62, 34, { Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0) })
			label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 64),
				Text = percent >= 1 and string.format("%.0f%%", percent) or string.format("%.2f%%", percent),
				TextColor3 = rarityColor(c[1]), ZIndex = 34, Parent = cell })
		end
		hatch3.Activated:Connect(function()
			local ok, result = Remotes.HatchEgg:InvokeServer(egg.Id, 3)
			if ok and type(result) == "table" and result[1] then
				-- the rarest of the three gets the reveal, the line names all three
				local names = {}
				local indexGold = 0
				for _, pet in result do
					table.insert(names, Config.Pets[pet.kind].Name)
					indexGold += pet.indexGold or 0
				end
				local best = result[1]
				local chance = 0
				for _, ch in egg.Chances do
					if ch[1] == best.kind then
						chance = ch[2] / total * 100
					end
				end
				message.Text = "Hatched: " .. table.concat(names, ", ") .. (indexGold > 0 and (" · Pet Index +" .. indexGold .. " gold") or "")
				message.TextColor3 = Ui.GOLD
				task.spawn(showReveal, egg, best, chance)
			else
				message.Text = (type(result) == "string" and result) or "Can't hatch"
				message.TextColor3 = Ui.BAD
			end
		end)
		hatch.Activated:Connect(function()
			local ok, result = Remotes.HatchEgg:InvokeServer(egg.Id)
			if ok then
				local chance = 0
				for _, c in egg.Chances do
					if c[1] == result.kind then
						chance = c[2] / total * 100
					end
				end
				message.Text = ""
				if (result.indexGold or 0) > 0 then
					-- a new kind: what the Pet Index paid for it
					message.Text = string.format("New for your Pet Index: +%d gold, +%d gems", result.indexGold, result.indexGems or 0)
					message.TextColor3 = Ui.GOLD
				end
				task.spawn(showReveal, egg, result, chance)
			else
				message.Text = result or "Can't hatch"
				message.TextColor3 = Ui.BAD
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- your pets on the right
-------------------------------------------------------------------------------
local list = make("ScrollingFrame", { Size = UDim2.fromOffset(430, 450), Position = UDim2.new(1, -24, 0, 66), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = Color3.fromRGB(35, 28, 48), BorderSizePixel = 0, ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 31, Parent = panel },
	{ corner(10), make("UIListLayout", { Padding = UDim.new(0, 6) }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })

local pets, equippedId = {}, nil
local team, index, slots = {}, {}, 1 -- the ids walking with you (lead first), the kinds ever hatched, open team slots

local function take(list2, equipped, team2, index2, slots2)
	pets, equippedId = list2 or {}, equipped
	team, index, slots = team2 or (equipped and { equipped } or {}), index2 or {}, slots2 or 1
end

-- helper = a team pet that is not the lead: it gives a part of its bonus
local function bonusText(pet, helper)
	local info = Config.Pets[pet.kind]
	local value = info.Bonus * (1 + 0.1 * ((pet.level or 1) - 1)) * (pet.evolved and 2 or 1) * (helper and Config.PetHelperBonus or 1)
	return string.format("+%.1f%% %s", value, Items.Stats[info.Stat] and Items.Stats[info.Stat].Name or info.Stat)
end

-- the Pet Index on top of the eggs: every kind of pet, the ones you have hatched in colour
local function buildIndex()
	local old = eggColumn:FindFirstChild("IndexCard")
	if old then
		old:Destroy()
	end
	-- (lists sort by name unless told otherwise: the Index is card 0, above the eggs)
	eggColumn:FindFirstChildOfClass("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	local kinds = {}
	for kind in Config.Pets do
		table.insert(kinds, kind)
	end
	table.sort(kinds, function(a, b)
		local ra, rb = Config.Pets[a].Rarity, Config.Pets[b].Rarity
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	local found = 0
	for _, kind in kinds do
		if index[kind] then
			found += 1
		end
	end
	local nextAt = nil
	for _, m in Config.PetIndexMilestones do
		if found < m.At then
			nextAt = m
			break
		end
	end
	local rows = math.ceil(#kinds / 6)
	local card = make("Frame", { Name = "IndexCard", Size = UDim2.fromOffset(428, 62 + rows * 68), BackgroundColor3 = Ui.PANEL,
		LayoutOrder = 0, ZIndex = 32, Parent = eggColumn }, { corner(12), stroke(Ui.GOLD, 2) })
	label({ Size = UDim2.fromOffset(200, 26), Position = UDim2.fromOffset(12, 6), Text = string.format("Pet Index %d/%d", found, #kinds),
		TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = card })
	label({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 34),
		Text = nextAt and string.format("Every new pet pays gold and gems · bonus at %d pets: %d gold", nextAt.At, nextAt.Gold)
			or "Complete! You found every pet",
		Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = card })
	local grid = make("Frame", { Size = UDim2.new(1, -20, 0, rows * 68), Position = UDim2.fromOffset(10, 58),
		BackgroundTransparency = 1, ZIndex = 33, Parent = card },
		{ make("UIGridLayout", { CellSize = UDim2.fromOffset(62, 62), CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder }) })
	for n, kind in kinds do
		local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = n, ZIndex = 33, Parent = grid })
		petTile(cell, kind, 62, 34)
		if not index[kind] then
			-- not found yet: in the dark, with the reward it will pay
			local rarity = Config.Pets[kind].Rarity
			local shade = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 16, 24),
				BackgroundTransparency = 0.18, ZIndex = 36, Parent = cell }, { corner(10) })
			label({ Size = UDim2.new(1, -4, 0, 30), Position = UDim2.fromOffset(2, 6), Text = "?", TextColor3 = rarityColor(kind),
				ZIndex = 37, Parent = shade })
			label({ Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 1, -20),
				Text = "+" .. (Config.PetIndexGold[rarity] or 0), TextColor3 = Ui.GOLD, ZIndex = 37, Parent = shade })
		end
	end
end

local function refresh()
	goldLabel.Text = (player:GetAttribute("Gold") or 0) .. " gold"
	buildIndex()
	list:FindFirstChildOfClass("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	do
		-- the team line: how many walk with you, and when the next slot opens
		local nextLevel = Config.PetTeamLevels[slots + 1]
		local line = make("Frame", { Size = UDim2.new(1, -12, 0, 24), BackgroundTransparency = 1, LayoutOrder = -1, ZIndex = 32, Parent = list })
		label({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 33, Parent = line,
			Text = string.format("Team %d/%d · the lead fights, all fetch loot", #team, slots)
				.. (nextLevel and (" · next slot: hero level " .. nextLevel) or "") })
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
		local ta, tb = table.find(team, a.id), table.find(team, b.id)
		if ta ~= tb then
			return (ta or 99) < (tb or 99) -- the team first, the lead on top
		end
		if ra ~= rb then
			return ra > rb
		end
		return (a.level or 1) > (b.level or 1)
	end)
	for i, pet in sorted do
		local info = Config.Pets[pet.kind]
		local color = Items.Rarities[info.Rarity].Color
		local row = make("Frame", { Size = UDim2.new(1, -12, 0, 118), BackgroundColor3 = Ui.PANEL, LayoutOrder = i, ZIndex = 32,
			Parent = list }, { corner(8), stroke(color, table.find(team, pet.id) and 3 or 1) })
		local place = table.find(team, pet.id) -- 1 = lead, 2 or 3 = helper, nil = not in the team
		petTile(row, pet.kind, 60, 33, { Position = UDim2.fromOffset(6, 6) })
		label({ Size = UDim2.fromOffset(170, 26), Position = UDim2.fromOffset(76, 8),
			Text = info.Name .. (pet.evolved and " (evolved)" or "") .. (place == 1 and " · Lead" or place and " · Helper" or ""),
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33, Parent = row })
		label({ Size = UDim2.fromOffset(170, 22), Position = UDim2.fromOffset(76, 38),
			Text = "Lv " .. (pet.level or 1) .. " · " .. bonusText(pet, place ~= nil and place > 1), Font = Enum.Font.Gotham,
			TextColor3 = Ui.TEXT_DIM,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = row })
		local move = Config.PetMoves[info.Stat]
		if move then
			-- what it does in a fight, under its bonus
			label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 72),
				Text = (place == 1 and "In a fight · " or "As lead · ") .. move.Name .. ": " .. move.Text, Font = Enum.Font.Gotham,
				TextColor3 = place == 1 and Ui.GOLD or Ui.TEXT_DIM,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = row })
		end
		local carry = Config.PetCarryOf(pet.kind, pet.evolved, player:GetAttribute("PassAutoCollect") == true)
		if carry then
			-- what it fetches from the ground (Config.PetCarry)
			local best = carry.MaxItemRarity >= #Items.Rarities and "all gear" or ("gear up to " .. Items.Rarities[carry.MaxItemRarity].Name)
			label({ Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 94),
				Text = string.format("Fetches %s%s · %d per trip%s", carry.Gems and "gems and " or "", best, carry.Carry,
					carry.Pass and " · 2x speed, whole map" or ""),
				Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = row })
		end
		local equip = button({ Size = UDim2.fromOffset(70, 44), Position = UDim2.new(1, -164, 0, 36), AnchorPoint = Vector2.new(0, 0.5),
			Text = place == 1 and "Lead" or place and "Lead it" or "Equip",
			BackgroundColor3 = place == 1 and Color3.fromRGB(60, 60, 70) or place and Color3.fromRGB(150, 110, 40)
				or Color3.fromRGB(60, 130, 60), ZIndex = 33, Parent = row })
		equip.Activated:Connect(function()
			if place ~= 1 then
				-- not in the team: it joins. A helper: it becomes the lead
				Remotes.EquipPet:InvokeServer(pet.id, place and "Lead" or nil)
			end
		end)
		local maxed = (pet.level or 1) >= Config.PetMaxLevel and not pet.evolved
		local other = button({ Size = UDim2.fromOffset(84, 44), Position = UDim2.new(1, -8, 0, 36), AnchorPoint = Vector2.new(1, 0.5),
			Text = maxed and "Evolve" or place and "Rest" or "Release", ZIndex = 33,
			BackgroundColor3 = maxed and Color3.fromRGB(150, 110, 40) or place and Color3.fromRGB(60, 60, 70)
				or Color3.fromRGB(110, 60, 60), Parent = row })
		other.Activated:Connect(function()
			local ok, result
			if place and not maxed then
				-- a team pet takes a rest (leaves the team)
				Remotes.EquipPet:InvokeServer(pet.id, "Off")
				return
			end
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

Remotes.Pets.OnClientEvent:Connect(function(list2, equipped, team2, index2, slots2)
	take(list2, equipped, team2, index2, slots2)
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
		buildEggs() -- (before asking the server, so the screen is never empty while it answers)
		take(Remotes.GetPets:InvokeServer())
		message.Text = "Eggs cost gold. Gold is earned by playing"
		message.TextColor3 = Ui.TEXT_DIM
		Ui.pop(panel, 0.85)
		refresh()
	else
		reveal.Visible = false
	end
end
petButton.Activated:Connect(toggle)
petButton.Press.Event:Connect(toggle)
closeButton.Activated:Connect(function()
	panel.Visible = false
	reveal.Visible = false
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
		reveal.Visible = false
	end
end)

-- controllers: the highlight jumps into the panel when it opens, B closes it (the hatch reveal first)
Ui.Gamepad.Panel(panel, { closeButton = closeButton, close = function()
	panel.Visible = false
	reveal.Visible = false
end })
Ui.Gamepad.Panel(reveal, { default = revealOk })
