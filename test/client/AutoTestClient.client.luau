-- Only in the test build: uses hero abilities, switches heroes, spends stat
-- points and works the backpack, printing [AUTOTEST-CLIENT] lines.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameState = ReplicatedStorage:WaitForChild("GameState")

local UI_TOUR = false -- true: shoot the HUD and panels; false: the map look tours
local player = game:GetService("Players").LocalPlayer

local function log(...)
	print("[AUTOTEST-CLIENT]", ...)
end

task.wait(8)
log("client started, state", GameState:GetAttribute("State"))

local heroes = { "Swordmaster", "RuneMage", "Engineer", "BeastHunter" }
local i = 0
task.spawn(function()
	while true do
		task.wait(0.4)
		Remotes.HeroAttack:FireServer()
		Remotes.HeroWhirlwind:FireServer()
		Remotes.HeroLeap:FireServer()
	end
end)

local heroShots = false
task.spawn(function()
	while true do
		task.wait(6)
		if heroShots then
			continue
		end
		i += 1
		local ok, reason = Remotes.SelectHero:InvokeServer(heroes[i % #heroes + 1])
		log("select hero", heroes[i % #heroes + 1], ok, reason)
		log("spend point", Remotes.SpendPoint:InvokeServer("Power"))
	end
end)

task.wait(10)
local items, gear = Remotes.GetInventory:InvokeServer()
log("inventory", items and #items or "nil")
if items and #items > 0 then
	for n = 1, math.min(5, #items) do
		local item = items[n]
		log("equip", item.name, Remotes.EquipGear:InvokeServer(item.id))
		log("upgrade", item.name, Remotes.UpgradeGear:InvokeServer(item.id))
	end
	local last = items[#items]
	log("salvage", last.name, Remotes.SalvageGear:InvokeServer(last.id))
end
log("buy", Remotes.BuyItem:InvokeServer("Swords", "Baguette"))
log("buy skin", Remotes.BuySkin:InvokeServer("RangerRoyal"))
log("skin off for the look check", Remotes.EquipSkin:InvokeServer("None:Ranger"))
log("buy cape", Remotes.BuySkin:InvokeServer("CapeRed"))
log("buy VIP cape (should fail)", Remotes.BuySkin:InvokeServer("CapeVIP"))
log("take cape off", Remotes.EquipSkin:InvokeServer("None:Cape"))
log("wear cape", Remotes.EquipSkin:InvokeServer("CapeRed"))
log("buy rebirth sword (should fail)", Remotes.BuyItem:InvokeServer("Swords", "Starforged"))
for _ = 1, 3 do
	local ok, pet = Remotes.HatchEgg:InvokeServer("ForestEgg")
	log("hatch", ok, ok and pet.kind or pet)
	if ok and not player:GetAttribute("TestPetLocked") then
		log("equip pet", Remotes.EquipPet:InvokeServer(pet.id))
	end
end
log("quests", #Remotes.GetQuests:InvokeServer())
log("claim quest 1", Remotes.ClaimQuest:InvokeServer(1))
task.delay(150, function()
	local season = Remotes.GetSeason:InvokeServer()
	log("season level", season and season.Level, "xp", season and season.Xp)
	log("claim season free 1", Remotes.ClaimSeason:InvokeServer(1, "Free"))
	log("claim season paid 1 (should fail)", Remotes.ClaimSeason:InvokeServer(1, "Paid"))
end)
task.delay(200, function()
	log("spend ascension", Remotes.SpendAscension:InvokeServer("Power"))
	log("rebirth", Remotes.Rebirth:InvokeServer())
end)
log("daily", Remotes.ClaimDaily:InvokeServer())
log("code", Remotes.RedeemCode:InvokeServer("goblinmode"))
log("code again", Remotes.RedeemCode:InvokeServer("GOBLINMODE"))
log("bad code", Remotes.RedeemCode:InvokeServer("nope"))

-- look at a Ranger for a screenshot check (test build only; off while the map tour runs)
task.delay(25, function()
	if true then
		return
	end
	local towers = workspace:FindFirstChild("Towers")
	local ranger = towers and towers:FindFirstChild("Ranger")
	if ranger and ranger.PrimaryPart then
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local p = ranger.PrimaryPart.Position
		cam.CFrame = CFrame.lookAt(p + Vector3.new(40, 34, 40), p + Vector3.new(0, 2, 0))
		local hidden = {}
		for _, g in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		log("camera on a Ranger")
		task.wait(20)
		for _, g in hidden do
			g.Enabled = true
		end
		cam.CameraType = Enum.CameraType.Custom
	end
end)

-- a short map tour for the look check on each rebuilt map: overview, the enemy gate, the portal,
-- and (on Magma) each defender up close (test build only)
local function tour(mapId, prefix, withTowers)
	log("tour waiting for", mapId)
	local n = 0
	repeat
		task.wait(0.5)
		n += 1
		if n % 20 == 0 then
			log("tour sees", GameState:GetAttribute("Map"), GameState:GetAttribute("State"), workspace:FindFirstChild("Map") ~= nil)
		end
	until GameState:GetAttribute("Map") == mapId and GameState:GetAttribute("State") ~= "Lobby" and workspace:FindFirstChild("Map")
	task.wait(3) -- let the models load in
	-- positions from the built map itself (the client's Config doesn't know which map is on)
	local map = workspace.Map
	local gateMark = map:WaitForChild("GateGlow", 5) or map:FindFirstChild("CampHut") or map:FindFirstChild("CampFire")
	local gate = gateMark and gateMark.Position or Vector3.new(-80, 0, 0)
	local portal = map:WaitForChild("Portal", 10).Position
	local flat = Vector3.new(1, 0, 1)
	local toPortal = ((portal - gate) * flat).Unit
	local cam = workspace.CurrentCamera
	local hidden = {}
	for _, g in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local shots = {
		{ "overview", CFrame.lookAt(Vector3.new(0, 120, 110), Vector3.new(0, 0, 0)) },
		{ "gate", CFrame.lookAt(Vector3.new(gate.X, 18, gate.Z) + toPortal * 34, Vector3.new(gate.X, 8, gate.Z)) },
		{ "portal", CFrame.lookAt(Vector3.new(portal.X, 16, portal.Z) - toPortal * 34, portal) },
		{ "low", CFrame.lookAt(Vector3.new(0, 14, 60), Vector3.new(0, 4, 0)) },
	}
	local names = {}
	for _, c in map:GetChildren() do
		names[c.Name] = (names[c.Name] or 0) + 1
	end
	local list = {}
	for k, v in names do
		table.insert(list, k .. "=" .. v)
	end
	log("map children", table.concat(list, " "))
	local trees = map:FindFirstChild("Trees")
	local tree = trees and trees:GetChildren()[3]
	if tree then
		local cf, size = tree:GetBoundingBox()
		log("tree", tree.Name, tostring(cf.Position), tostring(size))
		for _, part in tree:GetDescendants() do
			if part:IsA("BasePart") then
				log("tree part", part.Name, part.ClassName, part.Transparency, tostring(part.Size), part:IsA("MeshPart") and part.TextureID or "")
			end
		end
		table.insert(shots, 1, { "tree", CFrame.lookAt(cf.Position + Vector3.new(size.Y, size.Y * 0.3, size.Y), cf.Position) })
	end
	local towers = workspace:FindFirstChild("Towers")
	for _, kind in withTowers and { "Ranger", "Flame Cannon", "Frost Crystal", "Storm Obelisk", "Ballista" } or {} do
		local tower = towers and towers:FindFirstChild(kind)
		if tower and tower.PrimaryPart then
			local p = tower.PrimaryPart.Position
			local size = kind == "Ranger" and 16 or kind == "Storm Obelisk" and 15 or 10
			table.insert(shots, { string.lower((kind:gsub(" ", ""))), CFrame.lookAt(p + Vector3.new(size, size * 0.7, -size), p + Vector3.new(0, size * 0.35, 0)) })
		end
	end
	for _, shot in shots do
		-- (popups that opened since keep hidden too)
		for _, g in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = shot[2]
		log("camera-tour " .. prefix .. "_" .. shot[1], tostring(shot[2].Position))
		task.wait(6)
	end
	for _, g in hidden do
		g.Enabled = true
	end
	cam.CameraType = Enum.CameraType.Custom
end
-- the Outpost as a player sees it on joining (HUD on), then from above
local function outpostTour()
	repeat
		task.wait(0.5)
	until workspace:FindFirstChild("Outpost") and GameState:GetAttribute("State") == "Lobby"
	task.wait(4)
	log("camera-tour outpost_join")
	task.wait(6)
	local c = workspace.Outpost:FindFirstChild("OutpostSpawn")
	local center = c and c.Position or Vector3.zero
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local hidden = {}
	for _, g in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local lineup = workspace:WaitForChild("LineUp", 20)
	task.wait(1)
	local lineShots = {}
	if lineup then
		for i = -2, 2 do
			table.insert(lineShots, { "lineup" .. (i + 3), CFrame.lookAt(center + Vector3.new(i * 27, 7, -8), center + Vector3.new(i * 27, 3, -30)) })
		end
	end
	for _, shot in lineShots do
		cam.CFrame = shot[2]
		log("camera-tour " .. shot[1])
		task.wait(5)
	end
	-- the row of every pet model
	if workspace:WaitForChild("PetRow", 30) then
		task.wait(1)
		for i = -1, 1 do
			cam.CFrame = CFrame.lookAt(center + Vector3.new(i * 16.8, 7, 2), center + Vector3.new(i * 16.8, 3, -11))
			log("camera-tour petrow" .. (i + 2))
			task.wait(4)
		end
	end
	-- the pet that follows the player, up close from the front and from the side
	if player:GetAttribute("TestPetLocked") then
		log("equip dragon", Remotes.EquipPet:InvokeServer("testdragon"))
		task.wait(2.5)
	end
	local pet = workspace:FindFirstChild("Pet")
	if pet and pet.PrimaryPart then
		for i, offset in { Vector3.new(1.5, 1.2, -5.5), Vector3.new(5, 1.5, -2.5), Vector3.new(-3, 2.5, 5) } do
			local p = pet.PrimaryPart.CFrame
			cam.CFrame = CFrame.lookAt((p * CFrame.new(offset)).Position, p.Position)
			log("camera-tour pet" .. i)
			task.wait(4)
		end
	end
	-- each hero up close, from the front (weapon, hat, worn armor)
	heroShots = true
	for _, heroId in heroes do
		Remotes.SelectHero:InvokeServer(heroId)
		task.wait(2.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			cam.CFrame = CFrame.lookAt((root.CFrame * CFrame.new(3.5, 2, -8.5)).Position, root.Position + Vector3.new(0, 1.2, 0))
			log("camera-tour hero_" .. string.lower(heroId))
			task.wait(4)
		end
	end
	heroShots = false
	for _, shot in {
		{ "outpost_overview", CFrame.lookAt(center + Vector3.new(0, 60, 50), center + Vector3.new(0, 0, -26)) },
		{ "outpost_low", CFrame.lookAt(center + Vector3.new(0, 8, 14), center + Vector3.new(0, 4, -30)) },
	} do
		cam.CFrame = shot[2]
		log("camera-tour " .. shot[1])
		task.wait(6)
	end
	for _, g in hidden do
		g.Enabled = true
	end
	cam.CameraType = Enum.CameraType.Custom
end

-- the screens as a player sees them during a run (HUD on): the battle, every menu panel, the boss
local function uiTour(mapId)
	repeat
		task.wait(0.5)
	until GameState:GetAttribute("Map") == mapId and (GameState:GetAttribute("Wave") or 0) >= 2
	log("camera-tour ui_battle")
	task.wait(5)
	-- close-ups of up to three different enemies
	local seen, shots = {}, 0
	local cam = workspace.CurrentCamera
	for _ = 1, 40 do
		for _, e in workspace.Enemies:GetChildren() do
			if not seen[e.Name] and e.PrimaryPart and shots < 3 then
				seen[e.Name] = true
				shots += 1
				cam.CameraType = Enum.CameraType.Scriptable
				log("camera-tour ui_enemy" .. shots, e.Name)
				for _ = 1, 60 do
					if e.PrimaryPart then
						local p = e.PrimaryPart.Position
						cam.CFrame = CFrame.lookAt(p + Vector3.new(6, 4, 6), p)
					end
					task.wait(0.05)
				end
			end
		end
		if shots >= 3 then
			break
		end
		task.wait(0.5)
	end
	cam.CameraType = Enum.CameraType.Custom
	local dock = nil
	for _, d in player.PlayerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Name == "Backpack" and d:FindFirstChild("Press") then
			dock = d.Parent
		end
	end
	for _, name in { "Backpack", "Heroes", "Quests", "Pets", "Season", "Daily", "Shop" } do
		local button = dock and dock:FindFirstChild(name)
		if button then
			button.Press:Fire()
			log("camera-tour ui_" .. string.lower(name))
			task.wait(5)
			if name ~= "Daily" and name ~= "Shop" then
				button.Press:Fire() -- toggles it shut
			end
			task.wait(0.5)
		end
	end
	repeat
		task.wait(0.5)
	until (GameState:GetAttribute("Wave") or 0) >= (GameState:GetAttribute("MaxWave") or 10) or GameState:GetAttribute("Map") ~= mapId
	task.wait(2)
	log("camera-tour ui_boss")
end

task.spawn(function()
	outpostTour()
	if UI_TOUR then
		uiTour("MagmaFortress")
		return
	end
	tour("MagmaFortress", "magma", true)
	tour("CrystalCaves", "crystal", false)
	tour("CursedForest", "forest", false)
end)
