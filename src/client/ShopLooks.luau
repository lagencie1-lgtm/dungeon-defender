local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local GearLooks = require(ReplicatedStorage.Shared.GearLooks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Store = require(ReplicatedStorage.Shared.Store)
local Ui = require(script.Parent.Ui)

local ShopLooks = {}
local player = Players.LocalPlayer
local make, label, button = Ui.make, Ui.label, Ui.button
local selectedColor = Color3.fromRGB(104, 76, 48)
local buyColor = Color3.fromRGB(40, 120, 150)
local wearColor = Color3.fromRGB(59, 113, 71)
local inactiveColor = Color3.fromRGB(69, 64, 65)

local function attributeTable(name)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(name) or "{}")
	return ok and type(data) == "table" and data or {}
end

local function catalog(kind, category)
	local entries = {}
	if kind == "Skins" then
		local owned = attributeTable("OwnedSkins")
		local equipped = attributeTable("EquippedSkins")
		for _, id in Store.SkinOrder do
			local skin = Store.Skins[id]
			local group = Config.Towers[skin.Target] and "Defenders" or skin.Target
			local isOwned = owned[id] == true
			if group ~= category or (skin.NotForSale and not isOwned) then
				continue
			end
			local wearing = skin.Outfit and GearLooks.IsOutfitWorn(player, skin.Outfit) or equipped[skin.Target] == id
			local detail = skin.Description or (Config.Towers[skin.Target] and Config.Towers[skin.Target].DisplayName)
			if skin.Outfit and skin.Outfit ~= "Original" then
				detail = detail .. " · 5-piece outfit"
			end
			table.insert(entries, { Id = id, Name = skin.Name, Color = skin.Primary, Detail = detail,
				Price = Store.PriceOf(id), Owned = isOwned, Wearing = wearing, Outfit = skin.Outfit, Target = skin.Target })
		end
	else
		local slot = GearLooks.BySlot[kind]
		local owned = attributeTable("Owned")[kind] or {}
		local equipped = player:GetAttribute("Equipped" .. slot.Field)
		for _, item in GearLooks.Items[kind] do
			local detail = item.Finish
			if item.RebirthOnly then
				detail = "Unlocked by your first Rebirth"
			elseif item.Id == slot.Default then
				detail = "Use your regular gear appearance"
			elseif item.Baguette then
				detail = "A baguette for the Swordmaster"
			end
			table.insert(entries, { Id = item.Id, Name = item.Name, Color = item.PaintTint or item.Color, Detail = detail,
				Price = item.Price, Owned = owned[item.Id] == true, Wearing = equipped == item.Id, Reward = item.RebirthOnly })
		end
	end
	return entries
end

local function actionText(entry)
	if entry.Wearing then
		return entry.Target and not entry.Outfit and "Take off" or "Equipped"
	elseif entry.Owned then
		return entry.Outfit and "Equip outfit" or "Equip"
	elseif entry.Reward then
		return "Reward only"
	end
	return entry.Price == 0 and "Claim free" or "Buy " .. entry.Price .. " gems"
end

function ShopLooks.new(shop, list, notify)
	local panel = make("Frame", { Name = "LookDisplay", Size = UDim2.new(0.42, -8, 1, -168),
		Position = UDim2.new(1, -16, 0, 156), AnchorPoint = Vector2.new(1, 0), ZIndex = 22, Parent = shop,
		BackgroundColor3 = Color3.fromRGB(47, 33, 27), Visible = false },
		{ Ui.corner(12), Ui.stroke(Color3.fromRGB(144, 105, 56), 2) })
	local viewport = make("ViewportFrame", { Name = "SkinPreview", Size = UDim2.new(1, -20, 1, -110),
		Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(39, 34, 35), ZIndex = 23,
		Ambient = Color3.fromRGB(185, 171, 163), LightColor = Color3.fromRGB(255, 237, 204),
		LightDirection = Vector3.new(-1, -2, -2), Parent = panel }, { Ui.corner(7) })
	local camera = make("Camera", { FieldOfView = 36, Parent = viewport })
	viewport.CurrentCamera = camera
	local status = label({ Size = UDim2.new(1, -30, 0, 34), Position = UDim2.new(0.5, 0, 0.5, -45),
		AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Ui.TEXT_DIM, Text = "", ZIndex = 24, Parent = panel })
	local turn = button({ Size = UDim2.fromOffset(48, 42), Position = UDim2.new(1, -17, 1, -105),
		AnchorPoint = Vector2.new(1, 1), Text = "Turn", ZIndex = 24, Visible = false, Parent = panel })
	local name = label({ Size = UDim2.new(1, -20, 0, 23), Position = UDim2.new(0, 10, 1, -95),
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 24, Parent = panel })
	local detail = label({ Size = UDim2.new(1, -20, 0, 19), Position = UDim2.new(0, 10, 1, -71),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Ui.TEXT_DIM, Text = "", ZIndex = 24, Parent = panel })
	local action = button({ Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -50),
		Text = "", ZIndex = 24, Parent = panel })
	local filters = make("Frame", { Name = "SkinCategories", Size = UDim2.new(1, -32, 0, 44),
		Position = UDim2.fromOffset(16, 104), BackgroundTransparency = 1, Visible = false, ZIndex = 21, Parent = shop },
		{ make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder }) })

	local kind, category = nil, "Outfit"
	local entries, rows, selectedByGroup = {}, {}, {}
	local selected, model, request = nil, nil, 0
	local ready, busy, angle = false, false, 0
	local filterButtons = {}
	local rebuild

	local function frameModel()
		if not model or viewport.AbsoluteSize.Y == 0 then
			return
		end
		local box, size = model:GetBoundingBox()
		local direction = Vector3.new(math.sin(angle), 0.16, -math.cos(angle)).Unit
		local view = CFrame.lookAt(box.Position + direction, box.Position)
		local function extent(axis)
			return (math.abs(axis:Dot(box.RightVector)) * size.X + math.abs(axis:Dot(box.UpVector)) * size.Y
				+ math.abs(axis:Dot(box.LookVector)) * size.Z) / 2
		end
		local aspect = math.max(0.1, viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y)
		local slope = math.tan(math.rad(camera.FieldOfView / 2))
		local distance = math.max(extent(view.RightVector) / aspect, extent(view.UpVector)) / slope * 1.12
			+ extent(direction)
		camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	end

	turn.Activated:Connect(function()
		angle += math.pi / 3
		frameModel()
	end)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameModel)

	local function updateAction()
		action.Text = selected and actionText(selected) or ""
		local equipped = action.Text == "Equipped" or action.Text == "Reward only"
		action.Interactable = selected ~= nil and not busy and not equipped and (ready or selected.Owned)
		action.BackgroundColor3 = action.Interactable and (selected.Owned and wearColor or buyColor) or inactiveColor
	end

	local function selectEntry(entry)
		selected = entry
		request += 1
		ready = false
		if model then
			model:Destroy()
			model = nil
		end
		turn.Visible = false
		name.Text = entry and entry.Name or ""
		detail.Text = entry and entry.Detail or ""
		status.Text = entry and "Loading preview…" or "No skins here yet"
		updateAction()
		if not entry then
			return
		end
		for id, row in rows do
			row.BackgroundColor3 = id == entry.Id and selectedColor or Ui.PANEL
		end
		local group = kind == "Skins" and category or kind
		selectedByGroup[group] = entry.Id
		local token, previewKind = request, kind
		task.delay(0.18, function()
			for attempt = 1, 3 do
				if token ~= request or not shop.Visible then
					return
				end
				local ok, key, message, original = pcall(Remotes.GetLookPreview.InvokeServer, Remotes.GetLookPreview, previewKind, entry.Id)
				if token ~= request or not shop.Visible then
					return
				end
				if ok and key then
					local transport = player.PlayerGui:WaitForChild("ShopPreviewModels", 4)
					local source = transport and transport:WaitForChild(key, 4)
					if token ~= request or not shop.Visible then
						return
					end
					if source then
						model = source:Clone()
						model.Parent = viewport
						angle = model:GetAttribute("RearView") and math.pi - 0.28 or 0.34
						frameModel()
						status.Text = ""
						turn.Visible = true
						ready = true
						updateAction()
						return
					end
				elseif original then
					status.Text = message
					ready = true
					updateAction()
					return
				end
				if attempt < 3 then
					task.wait(0.7)
				end
			end
			if token == request then
				status.Text = "Select the skin again to reload"
			end
		end)
	end

	action.Activated:Connect(function()
		local entry, actionKind = selected, kind
		if not entry or busy or not action.Interactable then
			return
		end
		busy = true
		updateAction()
		local ok, reason
		if actionKind == "Skins" then
			if not entry.Owned then
				ok, reason = Remotes.BuySkin:InvokeServer(entry.Id)
			else
				ok, reason = Remotes.EquipSkin:InvokeServer(entry.Wearing and "None:" .. entry.Target or entry.Id)
			end
		elseif entry.Owned then
			ok, reason = Remotes.EquipItem:InvokeServer(actionKind, entry.Id)
		else
			ok, reason = Remotes.BuyItem:InvokeServer(actionKind, entry.Id)
		end
		if not ok then
			notify(reason or "Can't do that", Ui.BAD)
		elseif not entry.Owned then
			notify("You got " .. entry.Name .. "!", Ui.GEM)
			Ui.playSound("Coin")
		end
		task.wait(0.15)
		busy = false
		if panel.Visible and shop.Visible and kind == actionKind then
			rebuild(true)
		else
			updateAction()
		end
	end)

	function rebuild(keepPreview)
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		entries = catalog(kind, category)
		local pick
		local group = kind == "Skins" and category or kind
		for i, entry in entries do
			local row = make("TextButton", { Name = entry.Id, Size = UDim2.new(1, -10, 0, 54), LayoutOrder = i,
				Text = "", BackgroundColor3 = Ui.PANEL, ZIndex = 22, Parent = list }, { Ui.corner(8) })
			make("Frame", { Size = UDim2.fromOffset(7, 34), Position = UDim2.fromOffset(9, 10), BackgroundColor3 = entry.Color,
				ZIndex = 23, Parent = row }, { Ui.corner(3) })
			label({ Size = UDim2.new(1, -135, 0, 30), Position = UDim2.fromOffset(26, 12), Text = entry.Name,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			label({ Size = UDim2.fromOffset(96, 24), Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5), Text = entry.Wearing and "Equipped" or
					(entry.Owned and "Owned" or (entry.Reward and "Reward" or entry.Price == 0 and "Free" or entry.Price .. " gems")),
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Ui.TEXT_DIM, ZIndex = 23, Parent = row })
			row.Activated:Connect(function()
				selectEntry(entry)
			end)
			rows[entry.Id] = row
			if entry.Id == selectedByGroup[group] then
				pick = entry
			end
		end
		pick = pick or (kind ~= "Skins" and entries[2]) or entries[1]
		if keepPreview and pick and selected and pick.Id == selected.Id then
			selected = pick
			rows[pick.Id].BackgroundColor3 = selectedColor
			updateAction()
		else
			selectEntry(pick)
		end
	end

	for i, info in { { "Outfit", "Outfits" }, { "Defenders", "Defenders" }, { "Pet", "Pets" }, { "Cape", "Capes" },
		{ "Aura", "Glows" } } do
		local filter = button({ Size = UDim2.new(0.2, -7, 1, 0), Text = info[2], LayoutOrder = i, ZIndex = 22, Parent = filters })
		filterButtons[info[1]] = filter
		filter.Activated:Connect(function()
			category = info[1]
			list.CanvasPosition = Vector2.zero
			for id, item in filterButtons do
				item.BackgroundColor3 = id == category and selectedColor or Ui.PANEL
			end
			rebuild()
		end)
	end
	filterButtons.Outfit.BackgroundColor3 = selectedColor

	return {
		Show = function(nextKind)
			kind = nextKind
			panel.Visible = true
			filters.Visible = kind == "Skins"
			list.Size = UDim2.new(0.58, -32, 1, -168)
			list.Position = UDim2.fromOffset(16, 156)
			rebuild()
		end,
		Hide = function()
			request += 1
			panel.Visible = false
			filters.Visible = false
			if model then
				model:Destroy()
				model = nil
			end
			for _, row in rows do
				row:Destroy()
			end
			table.clear(rows)
		end,
	}
end

return ShopLooks
