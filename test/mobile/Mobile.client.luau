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

local function readableButton(item, bounds)
	fits(item, bounds)
	assert(item.AbsoluteSize.Y >= 40, item.Name .. " under 40 pixels tall")
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

local function check(name)
	if name == "Combat" then
		waitFor(function()
			return workspace:FindFirstChild("LocalCombatEffects") and #workspace.LocalCombatEffects:GetChildren() > 0
		end)
		waitFor(function() return #workspace.Effects:GetChildren() > 0 end)
		return
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
	local root = hud.Root
	if name == "Outpost" then
		assert(not workspace:FindFirstChild("Map"), "the first join already has a battlefield")
		local hub = workspace.Outpost
		local gate = hub:WaitForChild("RangerGatehouse", 10)
		assert(gate and gate:WaitForChild("WallWalk", 5), "gatehouse did not stream")
		waitFor(function() return gate:GetAttribute("ArrowOrigin") end)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")
		local rootPart = character:WaitForChild("HumanoidRootPart")
		local chest = hub:WaitForChild("outpost_chest"):FindFirstChildOfClass("ProximityPrompt")
		assert((rootPart.Position - chest.Parent.Position).Magnitude > chest.MaxActivationDistance, "chest prompt at spawn")
		humanoid:MoveTo(Config.OutpostCenter + Vector3.new(0, 1, -20))
		assert(humanoid.MoveToFinished:Wait(), "walk from spawn under the gate failed")
		assert((rootPart.Position - hub.StartPad.Position).Magnitude < 6, "missed the portal approach")
		local dock = gui:WaitForChild("SideMenu").Root
		assert(not dock.Dock.Visible, "phone joined with an expanded menu")
		for _, item in { dock.OpenMenu, root:FindFirstChild("StartRun", true), root:FindFirstChild("PickMap", true) } do
			readableButton(item, item:IsDescendantOf(dock) and dock or root)
		end
		print("[MOBILE] viewport", workspace.CurrentCamera.ViewportSize, "touch", UserInputService.TouchEnabled,
			"root", root.AbsoluteSize)
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
			assert(item.AbsoluteSize.Y >= 40, item.Name .. " under 40 pixels tall")
		end
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
