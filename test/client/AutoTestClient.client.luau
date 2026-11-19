-- Only in the test build: uses hero abilities, switches heroes, spends stat
-- points and works the backpack, printing [AUTOTEST-CLIENT] lines.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameState = ReplicatedStorage:WaitForChild("GameState")

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

task.spawn(function()
	while true do
		task.wait(6)
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
log("buy cape", Remotes.BuySkin:InvokeServer("CapeRed"))
log("buy VIP cape (should fail)", Remotes.BuySkin:InvokeServer("CapeVIP"))
log("take cape off", Remotes.EquipSkin:InvokeServer("None:Cape"))
log("wear cape", Remotes.EquipSkin:InvokeServer("CapeRed"))
log("buy rebirth sword (should fail)", Remotes.BuyItem:InvokeServer("Swords", "Starforged"))
for _ = 1, 3 do
	local ok, pet = Remotes.HatchEgg:InvokeServer("ForestEgg")
	log("hatch", ok, ok and pet.kind or pet)
	if ok then
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

-- a short map tour for the look check: overview, the enemy gate, the portal (test build only)
task.spawn(function()
	repeat
		task.wait(0.5)
	until GameState:GetAttribute("Map") == "MagmaFortress" and workspace:FindFirstChild("Map")
	task.wait(5) -- let the models load in
	-- positions from the built map itself (the client's Config doesn't know which map is on)
	local map = workspace.Map
	local gate = map:WaitForChild("GateGlow", 10).Position
	local portal = map:WaitForChild("Portal", 10).Position
	local flat = Vector3.new(1, 0, 1)
	local toPortal = ((portal - gate) * flat).Unit
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
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
	}
	local towers = workspace:FindFirstChild("Towers")
	for _, kind in { "Ranger", "Flame Cannon", "Frost Crystal", "Storm Obelisk", "Ballista" } do
		local tower = towers and towers:FindFirstChild(kind)
		if tower and tower.PrimaryPart then
			local p = tower.PrimaryPart.Position
			local size = kind == "Ranger" and 16 or kind == "Storm Obelisk" and 15 or 10
			table.insert(shots, { string.lower((kind:gsub(" ", ""))), CFrame.lookAt(p + Vector3.new(size, size * 0.7, -size), p + Vector3.new(0, size * 0.35, 0)) })
		end
	end
	for _, shot in shots do
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = shot[2]
		log("camera-tour " .. shot[1], tostring(shot[2].Position))
		task.wait(5)
	end
	for _, g in hidden do
		g.Enabled = true
	end
	cam.CameraType = Enum.CameraType.Custom
end)

-- and at a goblin-type enemy, for the model look check
task.spawn(function()
	task.wait(80) -- after the Ranger shot and the map tour
	for _ = 1, 400 do
		task.wait(0.5)
		local enemies = workspace:FindFirstChild("Enemies")
		local gob = nil
		for _, e in enemies and enemies:GetChildren() or {} do
			if e:GetAttribute("Mesh") and e.PrimaryPart then
				gob = e
				break
			end
		end
		if gob then
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			local hidden = {}
			for _, g in game:GetService("Players").LocalPlayer.PlayerGui:GetChildren() do
				if g:IsA("ScreenGui") and g.Enabled then
					g.Enabled = false
					table.insert(hidden, g)
				end
			end
			log("camera on a goblin")
			for _ = 1, 500 do
				if gob.PrimaryPart then
					local p = gob.PrimaryPart.Position
					cam.CFrame = CFrame.lookAt(p + Vector3.new(8, 5, 8), p)
				end
				task.wait(0.05)
			end
			for _, g in hidden do
				g.Enabled = true
			end
			cam.CameraType = Enum.CameraType.Custom
			return
		end
	end
end)
