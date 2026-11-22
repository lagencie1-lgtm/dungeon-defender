local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local GroundLooks = require(ReplicatedStorage.Shared.GroundLooks)
local probe = ReplicatedStorage.MobileTest
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local function waitFor(predicate)
	local deadline = os.clock() + 15
	repeat
		local result = predicate()
		if result then
			return result
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("timed out waiting for " .. tostring(probe:GetAttribute("Check")))
end

local function fits(item, bounds)
	local min, max = item.AbsolutePosition, item.AbsolutePosition + item.AbsoluteSize
	local start, finish = bounds.AbsolutePosition, bounds.AbsolutePosition + bounds.AbsoluteSize
	assert(min.X >= start.X - 2 and min.Y >= start.Y - 2 and max.X <= finish.X + 2 and max.Y <= finish.Y + 2,
		item.Name .. " exceeds the safe area")
end

-- Touch rule: every main button is at least 44 pixels tall, here and on a small phone.
-- Studio's window is bigger than a phone, so the size is also worked out for a small phone in landscape
-- (800x360 safe area), with the same fit-to-screen rule as Ui.fitRoot (phone layout sizes, at most 1.3x).
local PHONE = Vector2.new(800, 360)
local PHONE_LAYOUT = { RealmGuardiansHud = Vector2.new(930, 480), SideMenu = Vector2.new(520, 330) }
local function phoneHeight(item)
	local screen = item:FindFirstAncestorOfClass("ScreenGui")
	local layout = PHONE_LAYOUT[screen.Name]
	local scale = screen.Root:FindFirstChildOfClass("UIScale").Scale
	local phoneScale = math.min(PHONE.X / layout.X, PHONE.Y / layout.Y, 1.3)
	return item.AbsoluteSize.Y / scale * phoneScale
end
local function bigEnough(item)
	assert(item.AbsoluteSize.Y >= 44, item.Name .. " under 44 pixels tall")
	local small = phoneHeight(item)
	assert(small >= 44, string.format("%s only %.0f pixels tall on a small phone", item.Name, small))
end

local function readableButton(item, bounds)
	fits(item, bounds)
	bigEnough(item)
	assert(item.BackgroundTransparency < 1, item.Name .. " hid its background")
	assert(#item.Text > 0 and item.TextTransparency == 0 and item.TextFits, item.Name .. " native label is missing or clipped")
	assert(not item:FindFirstChild("SkinText"), item.Name .. " moved text into a separate render layer")
end

local function assertGround(name)
	local isOutpost = name == "Outpost"
	local theme = isOutpost and name or Config.Maps[name].Theme
	local world = waitFor(function()
		local candidate = workspace:FindFirstChild(isOutpost and "Outpost" or "Map")
		return candidate and candidate:GetAttribute("GroundTheme") == theme and candidate
	end)
	local colors = GroundLooks.Themes[theme]
	waitFor(function()
		for material, texture in colors do
			if MaterialService:GetBaseMaterialOverride(material) ~= "HTD_" .. texture then
				return false
			end
			local tint = workspace.Terrain:GetMaterialColor(material)
			local expected = GroundLooks.Colors[texture]:Lerp(Color3.new(1, 1, 1), 0.15)
			if math.max(math.abs(tint.R - expected.R), math.abs(tint.G - expected.G), math.abs(tint.B - expected.B)) > 0.012 then
				return false
			end
		end
		return true
	end)
	assert(not world:FindFirstChild("MobileGroundPaint"), "rectangular paint layer returned")
	local scripts = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
	assert(not scripts:FindFirstChild("GroundPaint"), "a second ground renderer is present")
	print("[MOBILE]", name, "native painted materials and fallback tints")
end

-- How much of the screen our UI covers (0..1): every visible panel, button, picture and line of text, painted onto
-- a 96 x 54 grid so overlaps count once. Rule (Lemp 2026-11-22, "Mobile and Console first"): at least 70% of a
-- phone screen stays free for the game, in the hub and in a run.
local MAX_UI_COVER = 0.30
-- Roblox's own screens are not ours to move: the invisible thumbstick zone, prompts, chat
local NOT_OURS = { TouchGui = true, ProximityPrompts = true, BubbleChat = true, Chat = true, Freecam = true }
local function shown(obj)
	while obj and obj:IsA("GuiObject") do
		if not obj.Visible then
			return false
		end
		obj = obj.Parent
	end
	return obj == nil or not obj:IsA("ScreenGui") or obj.Enabled
end
local function uiCoverage()
	local viewport = workspace.CurrentCamera.ViewportSize
	local cols, rows = 96, 54
	local cells, count = {}, 0
	local function paint(x0, y0, x1, y1)
		local c0, c1 = math.max(0, math.floor(x0 / viewport.X * cols)), math.min(cols - 1, math.floor(x1 / viewport.X * cols))
		local r0, r1 = math.max(0, math.floor(y0 / viewport.Y * rows)), math.min(rows - 1, math.floor(y1 / viewport.Y * rows))
		for c = c0, c1 do
			for r = r0, r1 do
				local key = r * cols + c
				if not cells[key] then
					cells[key] = true
					count += 1
				end
			end
		end
	end
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and not NOT_OURS[screen.Name] then
			for _, obj in screen:GetDescendants() do
				if obj:IsA("GuiObject") and shown(obj) and obj.AbsoluteSize.X > 2 and obj.AbsoluteSize.Y > 2 then
					local p, s = obj.AbsolutePosition, obj.AbsoluteSize
					if obj.BackgroundTransparency < 0.95 or (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= ""
						and obj.ImageTransparency < 0.95 then
						paint(p.X, p.Y, p.X + s.X, p.Y + s.Y)
					elseif (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" and obj.TextTransparency < 0.95 then
						-- a line of text on no background covers only its letters
						local b = obj.TextBounds
						local cx = p.X + s.X * (obj.TextXAlignment == Enum.TextXAlignment.Left and 0 or obj.TextXAlignment == Enum.TextXAlignment.Right and 1 or 0.5)
						local x0 = obj.TextXAlignment == Enum.TextXAlignment.Left and cx or obj.TextXAlignment == Enum.TextXAlignment.Right and cx - b.X or cx - b.X / 2
						local cy = p.Y + s.Y / 2
						paint(x0, cy - b.Y / 2, x0 + b.X, cy + b.Y / 2)
					end
				end
			end
		end
	end
	return count / (cols * rows)
end

-- the biggest visible pieces of UI, to see what to shrink when the screen is too full
local function biggest()
	local list = {}
	local viewport = workspace.CurrentCamera.ViewportSize
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and not NOT_OURS[screen.Name] then
			for _, obj in screen:GetDescendants() do
				if obj:IsA("GuiObject") and shown(obj) and (obj.BackgroundTransparency < 0.95 or obj:IsA("TextLabel") and obj.Text ~= "") then
					local path = obj:GetFullName():gsub("^.-PlayerGui%.", "")
					if obj:IsA("TextLabel") then
						path ..= ' "' .. obj.Text:sub(1, 40) .. '"'
					end
					table.insert(list, { path, obj.AbsoluteSize.X * obj.AbsoluteSize.Y / (viewport.X * viewport.Y) })
				end
			end
		end
	end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	for i = 1, math.min(12, #list) do
		print(string.format("[MOBILE]   %4.1f%% %s", list[i][2] * 100, list[i][1]))
	end
end

local function check(name)
	if name == "Combat" then
		waitFor(function()
			return workspace:FindFirstChild("LocalCombatEffects") and #workspace.LocalCombatEffects:GetChildren() > 0
		end)
		waitFor(function() return #workspace.Effects:GetChildren() > 0 end)
		return
	end
	if name ~= "Outpost" then
		-- the steady run screen: after the start-of-run messages fade, before this check's own build messages
		task.wait(7)
		local cover = uiCoverage()
		print(string.format("[MOBILE] %s run screen covered by UI %.0f%% (max %.0f%%)", name, cover * 100, MAX_UI_COVER * 100))
		if cover > MAX_UI_COVER then
			biggest()
		end
		assert(cover <= MAX_UI_COVER, string.format("the run UI covers %.0f%% of the screen", cover * 100))
	end
	if name == "CursedForest" then
		local remotes = require(ReplicatedStorage.Shared.Remotes)
		local spawn = Config.Maps.CursedForest.SpawnPoint
		local built, reason = remotes.PlaceTower:InvokeServer("Ranger", spawn)
		assert(built, tostring(reason))
		local tower = waitFor(function() return workspace.Towers:FindFirstChild(Config.Towers.Ranger.DisplayName) end)
		local target = tower:WaitForChild("SelectionVolume", 5)
		assert(target and target.CanQuery and target.Size.X >= 6, "missing defender selection volume")
		assert(tower.PrimaryPart and tower.PrimaryPart.Transparency < 1, "missing visible defender base")
		assert(remotes.SellTower:InvokeServer(tower), "could not sell the defender")
	end
	assertGround(name)
	local hud = gui:WaitForChild("RealmGuardiansHud", 8)
	assert(hud and hud.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets, "HUD escaped safe insets")
	-- every screen of ours stays out of the notch and the home bar
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and (screen.Name:match("Hud$") or screen.Name == "SideMenu") then
			assert(screen.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets, screen.Name .. " escaped safe insets")
		end
	end
	local root = hud.Root
	if name == "Outpost" then
		assert(not workspace:FindFirstChild("Map"), "the first join already has a battlefield")
		local hub = workspace.Outpost
		-- the Watch Keep hub: a spawn, the first map pad (StartPad) and a walk-in ring per station
		local pad = hub:WaitForChild("StartPad", 10)
		assert(pad and hub:WaitForChild("OutpostSpawn", 5), "the Keep's spawn or start pad did not stream")
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local rootPart = character:WaitForChild("HumanoidRootPart")
		local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
		for _, station in HubLayout.Stations do
			local ring = hub:WaitForChild(station.Id .. "Ring", 5)
			assert(ring, station.Id .. "Ring missing")
			local offset = rootPart.Position - ring.Position
			assert(Vector3.new(offset.X, 0, offset.Z).Magnitude > HubLayout.RingRadius, station.Id .. " opens at spawn")
		end
		-- walk from the spawn to just in front of the pad (standing on it would start a run)
		local toPad = Vector3.new(pad.Position.X - rootPart.Position.X, 0, pad.Position.Z - rootPart.Position.Z)
		local approach = pad.Position - toPad.Unit * (HubLayout.PadRadius + 3)
		-- (MoveTo gives up after 8 s; the first walk after joining can start before the ground has streamed in)
		local reached = false
		for _ = 1, 3 do
			humanoid:MoveTo(approach)
			reached = humanoid.MoveToFinished:Wait()
			print("[MOBILE] walk", reached, "at", rootPart.Position - Config.OutpostCenter, "to", approach - Config.OutpostCenter,
				"speed", humanoid.WalkSpeed, "state", humanoid:GetState(), "anchored", rootPart.Anchored)
			if reached then
				break
			end
		end
		assert(reached, "walk from spawn to the start pad failed")
		assert((Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(approach.X, 0, approach.Z)).Magnitude < 4,
			"missed the portal approach")
		local dock = gui:WaitForChild("SideMenu").Root
		assert(not dock.Dock.Visible, "phone joined with an expanded menu")
		for _, item in { dock.OpenMenu, root:FindFirstChild("StartRun", true), root:FindFirstChild("PickMap", true) } do
			readableButton(item, item:IsDescendantOf(dock) and dock or root)
		end
		print("[MOBILE] viewport", workspace.CurrentCamera.ViewportSize, "touch", UserInputService.TouchEnabled,
			"root", root.AbsoluteSize)
		local cover = uiCoverage()
		print(string.format("[MOBILE] hub screen covered by UI %.0f%% (max %.0f%%)", cover * 100, MAX_UI_COVER * 100))
		if cover > MAX_UI_COVER then biggest() end
		assert(cover <= MAX_UI_COVER, string.format("the hub UI covers %.0f%% of the screen", cover * 100))
	else
		local menu = gui:WaitForChild("SideMenu").Root.OpenMenu
		local hero = root.HeroStatus
		assert(menu.AbsolutePosition.Y + menu.AbsoluteSize.Y <= hero.AbsolutePosition.Y + 1, "menu covers hero status")
		for _, id in { "StartWave", "WaveSpeed" } do
			readableButton(root:FindFirstChild(id, true), root)
		end
		for _, id in { "PrimaryAttack", "TowerBar" } do
			local item = root:FindFirstChild(id, true)
			assert(item, id .. " missing")
			fits(item, root)
			bigEnough(item)
		end
		-- the placing and defender buttons (hidden now, their size is what counts)
		for _, id in { "ConfirmBuild", "CancelBuild", "Upgrade", "Sell" } do
			local item = root:FindFirstChild(id, true)
			assert(item, id .. " missing")
			bigEnough(item)
		end
		print("[MOBILE] touch targets on a small phone: tower card", math.floor(phoneHeight(root.TowerBar)),
			"upgrade", math.floor(phoneHeight(root.TowerInfo.Upgrade)), "menu",
			math.floor(phoneHeight(gui.SideMenu.Root.OpenMenu)))
	end
end

local function run()
	local name = probe:GetAttribute("Check")
	if not name then
		return
	end
	local ok, failure = pcall(check, name)
	print("[MOBILE]", name, ok and "OK" or ("FAILED: " .. tostring(failure)))
	probe:FireServer(name, not ok and tostring(failure) or nil)
end

probe:GetAttributeChangedSignal("Check"):Connect(run)
run()
