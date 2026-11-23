-- Film rig for pets and Might (test/petfilm.project.json only, scripts/film_route.ps1): one fixed route that shows
-- the pet team following, the lead pet's move in a wave, pets fetching loot, the Might look of a strong hero,
-- a Might style from the shop, and the pets screen. Marks are printed as "[FILM] <unix ms> <name>".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local DataService = require(Server.DataService)
local PetService = require(Server.PetService)
local LootService = require(Server.LootService)
local ItemService = require(Server.ItemService)
local State = require(Server.State)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local cue = ReplicatedStorage.FilmCue

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local deadline = os.clock() + 20
while not DataService.Get(player) and os.clock() < deadline do
	task.wait(0.2)
end

local function rootOf()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

cue.OnServerEvent:Connect(function(sender, step, arg)
	if sender ~= player then
		return
	end
	mark(step)
	local profile = DataService.Get(player)
	if step == "Setup" then
		-- three pets walk along (slots opened for the film), the owner's Auto Collect pass is off so pets fetch
		Config.PetTeamLevels = { 1, 1, 1 }
		player:SetAttribute("PassAutoCollect", false)
		profile.Pets = profile.Pets or {}
		for _, pet in { { "filmdragon", "BabyDragon" }, { "filmslime", "Slimey" }, { "filmowl", "CrystalOwl" } } do
			table.insert(profile.Pets, { id = pet[1], kind = pet[2], level = 1, xp = 0, evolved = false })
		end
		PetService.Equip(player, "filmdragon", "Lead")
		PetService.Equip(player, "filmslime")
		PetService.Equip(player, "filmowl")
		profile.Owned.Towers = profile.Owned.Towers or {}
		for _, kind in Config.TowerOrder do
			profile.Owned.Towers[kind] = true
		end
		cue:FireClient(player, "SetupReady")
	elseif step == "StartRun" then
		State.Set("Map", arg or "CursedForest")
		GameService.StartRun()
		cue:FireClient(player, "RunReady")
	elseif step == "Stand" then
		-- next to the middle of the path, where the fight passes by
		local pts = Config.Path
		local i = math.max(1, math.floor(#pts / 2))
		local a, b = pts[i], pts[i + 1]
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local spot = a:Lerp(b, 0.5) + side * 9
		player.Character:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 5, 0), a:Lerp(b, 0.5) + Vector3.new(0, 5, 0)))
		State.AddGold(3000)
		local placed = 0
		for j = 1, #pts - 1 do
			local p, q = pts[j], pts[j + 1]
			local d = (q - p).Unit
			local s = Vector3.new(-d.Z, 0, d.X)
			for _, k in { -12, 12 } do
				if placed < 4 and (p:Lerp(q, 0.5) + s * k - spot).Magnitude > 8 then
					if TowerService.Place(player, "Ranger", p:Lerp(q, 0.5) + s * k) then
						placed += 1
					end
				end
			end
		end
		cue:FireClient(player, "StandReady")
	elseif step == "Bosses" then
		-- the two crowned bosses in front of the hero, as the Outpost line-up of the autotest shows them
		-- (2026-11-23: yellow crown bars sat across their eyes)
		local EnemyService = require(Server.EnemyService)
		local ArtService = require(Server.ArtService)
		local root = rootOf()
		local folder = Instance.new("Folder")
		folder.Name = "FilmBosses"
		folder.Parent = workspace
		for i, name in { "GoblinKing", "ShadowQueen" } do
			ArtService.WaitModel(Config.Enemies[name].Model, 30)
			local e = EnemyService.Spawn(name, 1, 0)
			if e and e.model then
				local copy = e.model:Clone()
				local at = (root.CFrame * CFrame.new((i - 1.5) * 14, 0, -20)).Position
				at = Vector3.new(at.X, root.Position.Y - 3 + Config.Enemies[name].Size, at.Z)
				copy:PivotTo(CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
				copy.Parent = folder
				local crowns = 0
				for _, d in copy:GetChildren() do
					if d.Name == "Crown" then
						crowns += 1
					end
				end
				print("[FILM]", DateTime.now().UnixTimestampMillis, "boss " .. name .. " crown bars " .. crowns)
			end
		end
		EnemyService.Clear()
		cue:FireClient(player, "BossesReady")
	elseif step == "BossesGone" then
		local folder = workspace:FindFirstChild("FilmBosses")
		if folder then
			folder:Destroy()
		end
	elseif step == "Might" then
		-- a Mythic-rank hero (the look only: rank and number, as strong gear would set them)
		player:SetAttribute("Might", 2400)
		player:SetAttribute("MightRank", arg or 6)
	elseif step == "Loot" then
		-- gems and gear on the ground around the hero, out of the hero's own reach
		local root = rootOf()
		if root then
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				local spot = root.Position + Vector3.new(math.cos(a) * 15, 0, math.sin(a) * 15)
				LootService.DropGems(spot, i == 1 and 12 or 2)
				if i % 2 == 0 then
					ItemService.OnEnemyKilled({ name = "Film", stats = { DropChance = 50 }, position = spot + Vector3.new(2, 0, 2) },
						State.Get("Difficulty"), 5)
				end
			end
		end
	elseif step == "Style" then
		profile.Owned.Skins[arg] = true
		profile.Equipped.Skins.Aura = arg
		player:SetAttribute("EquippedAura", arg)
	elseif step == "Panel" then
		Remotes.OpenPanel:FireClient(player, arg or "Pets")
	elseif step == "Done" then
		pcall(function()
			game:GetService("StudioTestService"):EndTest("film done")
		end)
	end
end)
mark("server ready")
