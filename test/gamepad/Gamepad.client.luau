-- Only in the gamepad test build: plays like a controller player. Studio has no real controller, so the
-- ReplicatedStorage.GamepadTest object makes Gamepad.luau act as if one is the last input, and this script
-- presses buttons through Gamepad.Press (the same handlers the real buttons call).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local probe = ReplicatedStorage.GamepadTest
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local Gamepad = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Gamepad"))
local Key = Enum.KeyCode

local function waitFor(predicate, what, limit)
	local deadline = os.clock() + (limit or 10)
	repeat
		local result = predicate()
		if result then
			return result
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("timed out waiting for " .. what)
end

local function inside(obj, frame)
	return obj ~= nil and (obj == frame or obj:IsDescendantOf(frame))
end

local function shown(obj)
	local node = obj
	while node and not node:IsA("ScreenGui") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node.Enabled
end

local function myTowers()
	local list = {}
	for _, tower in workspace.Towers:GetChildren() do
		if tower:GetAttribute("Owner") == player.UserId then
			table.insert(list, tower)
		end
	end
	return list
end

local hud = gui:WaitForChild("RealmGuardiansHud")

local function check(name)
	assert(Gamepad.active, "the test build did not switch the game to controller mode")
	if name:sub(1, 6) == "Panel " then
		local frame = waitFor(function()
			local top = Gamepad.TopPanel()
			return top and top.Visible and inside(GuiService.SelectedObject, top) and top
		end, name .. " with a highlighted button")
		local picked = GuiService.SelectedObject
		assert(picked:IsA("GuiButton") and picked.Selectable and shown(picked), "highlighted something that can't be pressed")
		print("[GAMEPAD]", name, "opened, highlight on", picked:GetFullName():match("[^%.]+%.[^%.]+$"))
		assert(Gamepad.Press(Key.ButtonB), "B did nothing")
		waitFor(function() return not frame.Visible end, "B to close " .. name, 3)
		assert(not inside(GuiService.SelectedObject, frame), "the highlight stayed in a closed panel")
		assert(Gamepad.TopPanel() == nil, "another panel is still open")
	elseif name == "Menu" then
		local dock = gui:WaitForChild("SideMenu").Root.Dock
		assert(Gamepad.Press(Key.DPadUp), "d-pad up did nothing")
		assert(inside(GuiService.SelectedObject, dock), "d-pad up did not highlight the side menu")
		print("[GAMEPAD] Menu d-pad up highlights", GuiService.SelectedObject.Name)
		assert(Gamepad.Press(Key.ButtonB), "B did nothing in the menu")
		assert(GuiService.SelectedObject == nil, "B left the highlight in the menu")
	elseif name == "Build" then
		local root = hud.Root
		local bar = root.TowerBar
		waitFor(function() return bar.Visible end, "the tower bar")
		-- stand 7 studs west of a spot that is fine to build on, looking at it
		local spot = Config.Maps.CursedForest.SpawnPoint
		local rootPart = player.Character:WaitForChild("HumanoidRootPart")
		local y = rootPart.Position.Y
		rootPart.CFrame = CFrame.lookAt(Vector3.new(spot.X - 7, y, spot.Z), Vector3.new(spot.X, y, spot.Z))
		rootPart.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.5)
		-- step right and back: the gold frame must end on the first card (Ranger)
		assert(Gamepad.Press(Key.DPadRight) and Gamepad.Press(Key.DPadLeft), "d-pad left/right did nothing on the tower bar")
		local cards = {}
		for _, b in bar:GetChildren() do
			if b:IsA("GuiButton") then
				table.insert(cards, b)
			end
		end
		table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		assert(cards[1].PadFocus.Visible and not cards[2].PadFocus.Visible, "the highlight frame is not on the first card")
		assert(cards[1].PadHint.Visible and not cards[2].PadHint.Visible, "the X badge is not on the highlighted card only")
		local before = #myTowers()
		assert(Gamepad.Press(Key.ButtonX), "X did not start placing")
		local ghost = waitFor(function() return workspace:FindFirstChild("PlacementGhost") end, "the placement ghost")
		local confirm = root:FindFirstChild("ConfirmBuild", true)
		assert(shown(confirm) and confirm.PadHint.Visible, "the confirm bar or its A badge is missing")
		task.wait(0.4)
		local foot = ghost:WaitForChild("Foot")
		local offset = foot.Position - rootPart.Position
		print("[GAMEPAD] Build ghost", math.floor(Vector3.new(offset.X, 0, offset.Z).Magnitude + 0.5), "studs in front of the hero")
		assert(Gamepad.Press(Key.ButtonA), "A did not confirm")
		waitFor(function() return #myTowers() > before end, "Remotes.PlaceTower to build the Ranger")
		waitFor(function() return workspace:FindFirstChild("PlacementGhost") == nil end, "the ghost to go after building")
		print("[GAMEPAD] Build placed", myTowers()[1].Name, "in workspace.Towers")
	elseif name == "Upgrade" then
		local tower = myTowers()[1]
		assert(tower, "no defender to upgrade")
		local level = tower:GetAttribute("Level")
		assert(Gamepad.Press(Key.ButtonY), "Y did nothing")
		local info = hud.Root.TowerInfo
		waitFor(function() return info.Visible and GuiService.SelectedObject ~= nil end, "the info panel with a highlight")
		local picked = GuiService.SelectedObject
		assert(picked.Name == "Upgrade" and inside(picked, info), "Upgrade is not highlighted: " .. picked.Name)
		-- A on the highlighted button (scripts can't press it, the button's Press event runs the same code)
		picked.Press:Fire()
		waitFor(function() return tower:GetAttribute("Level") == level + 1 end, "the upgrade")
		print("[GAMEPAD] Upgrade level", level, "->", tower:GetAttribute("Level"))
		-- the d-pad can reach Sell below Upgrade
		local sell = info.Sell
		assert(sell.Selectable and sell.AbsolutePosition.Y > picked.AbsolutePosition.Y, "Sell is not below Upgrade")
		assert(Gamepad.Press(Key.ButtonB), "B did nothing on the info panel")
		assert(not info.Visible and GuiService.SelectedObject == nil, "B did not close the info panel")
	elseif name == "Readable" then
		-- 10-foot rule: no visible HUD text under about 18 pixels at 1080p
		local viewport = workspace.CurrentCamera.ViewportSize
		local least = 18 * viewport.Y / 1080
		local small = {}
		local count = 0
		for _, screen in { hud, gui:FindFirstChild("SideMenu"), gui:FindFirstChild("HeroHud") } do
			for _, obj in screen:GetDescendants() do
				if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" and obj.TextTransparency < 1 and shown(obj) then
					count += 1
					if obj.AbsoluteSize.Y < least - 0.5 then
						table.insert(small, obj.Name .. " '" .. obj.Text:sub(1, 20) .. "' " .. math.floor(obj.AbsoluteSize.Y))
					end
				end
			end
		end
		local scale = hud.Root:FindFirstChildOfClass("UIScale").Scale
		print("[GAMEPAD] Readable viewport", viewport, "HUD scale", string.format("%.2f", scale), count, "texts, need",
			string.format("%.1f", least), "px")
		assert(#small == 0, #small .. " texts too small: " .. table.concat(small, ", "))
	end
end

local function run()
	local name = probe:GetAttribute("Check")
	if not name then
		return
	end
	local ok, failure = pcall(check, name)
	print("[GAMEPAD]", name, ok and "OK" or ("FAILED: " .. tostring(failure)))
	probe:FireServer(name, not ok and tostring(failure) or nil)
end

probe:GetAttributeChangedSignal("Check"):Connect(run)
run()
