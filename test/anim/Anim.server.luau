-- Animation test rig (test/anim.project.json only): starts a real run and does what the client asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local State = require(Server.State)
local cue = ReplicatedStorage.AnimCue

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end

cue.OnServerEvent:Connect(function(player, step, arg)
	mark(step)
	if step == "StartRun" then
		State.Set("Map", arg or "CursedForest")
		GameService.StartRun()
		cue:FireClient(player, "RunReady")
	elseif step == "Hit" then
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			h:TakeDamage(arg or 8)
		end
	elseif step == "Heal" then
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = h.MaxHealth
		end
	elseif step == "KO" then
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = 0
		end
	elseif step == "HitEnemy" then
		-- a sword blow on one enemy (as HeroService's hit does it), for the rigged goblin's hit and fall
		local EnemyService = require(Server.EnemyService)
		for _, e in EnemyService.GetActive() do
			if e.model == arg then
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				EnemyService.Damage(e, 12, player, true, false, r and r.Position)
				EnemyService.HitStop(e, 0.06)
				EnemyService.Knockback(e, 1.5)
			end
		end
	elseif step == "SpawnGoblin" then
		-- one goblin alone at the start of the path (as the dev panel's spawn does)
		require(Server.EnemyService).Spawn("Goblin", 1, arg or 0)
	elseif step == "KillEnemy" then
		local EnemyService = require(Server.EnemyService)
		for _, e in EnemyService.GetActive() do
			if e.model == arg then
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				EnemyService.Damage(e, 99999, player, true, false, r and r.Position)
			end
		end
	elseif step == "Done" then
		pcall(function()
			game:GetService("StudioTestService"):EndTest("anim done")
		end)
	end
end)
-- what the rigged goblin looks like once loaded (bones kept?)
task.spawn(function()
	local ArtService = require(Server.ArtService)
	local m = ArtService.WaitModel("enemy_goblin_rigged", 40)
	if not m then
		print("[ANIM] rigged goblin did not load")
		return
	end
	local bones, parts = 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("Bone") then
			bones += 1
		elseif d:IsA("BasePart") then
			parts += 1
			print("[ANIM] rigged part", d.Name, d.ClassName, d.Size, d:IsA("MeshPart") and d.TextureID or "")
		end
	end
	print("[ANIM] rigged goblin loaded:", parts, "parts,", bones, "bones")
	-- the raw asset, for comparison: where its bones sit
	local ok, raw = pcall(function()
		return game:GetService("InsertService"):LoadAsset(130565995983817)
	end)
	if ok and raw then
		local n = 0
		for _, d in raw:GetDescendants() do
			n += 1
			if n <= 30 then
				print("[ANIM] raw", d.ClassName, d:GetFullName())
			end
		end
		print("[ANIM] raw total", n)
		raw:Destroy()
	end
end)
mark("server ready")
