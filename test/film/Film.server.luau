-- Film rig (test/film.project.json only): drives one fixed route so every take films the same shots.
-- The client asks for each step with FilmCue; marks are printed as "[FILM] <unix ms> <name>" to cut the clip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameService = require(Server.GameService)
local TowerService = require(Server.TowerService)
local DataService = require(Server.DataService)
local State = require(Server.State)
local Config = require(ReplicatedStorage.Shared.Config)
local cue = ReplicatedStorage.FilmCue

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local function profile()
	local deadline = os.clock() + 20
	while not DataService.Get(player) and os.clock() < deadline do
		task.wait(0.2)
	end
	local p = DataService.Get(player)
	-- a newcomer's save: the film shows what a first-time player sees
	return p
end
profile()

cue.OnServerEvent:Connect(function(sender, step, arg)
	if sender ~= player then
		return
	end
	mark(step)
	if step == "StartRun" then
		State.Set("Map", arg or "CursedForest")
		GameService.StartRun()
		cue:FireClient(player, "RunReady")
	elseif step == "Mana" then
		State.AddGold(2000)
	elseif step == "Own" then
		-- the film shows every defender's levels: unlock them for this test save only
		local p = DataService.Get(player)
		if p then
			p.Owned.Towers = p.Owned.Towers or {}
			for _, kind in Config.TowerOrder do
				p.Owned.Towers[kind] = true
			end
		end
	elseif step == "Defenders" then
		-- a few defenders along the path, near the hero, for the wave shot
		local pts = Config.Path
		local placed = 0
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local dir = (b - a).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			for _, k in { -10, 10 } do
				if placed < 6 then
					local kind = Config.TowerOrder[placed % #Config.TowerOrder + 1]
					if TowerService.Place(player, kind, a:Lerp(b, 0.5) + side * k) then
						placed += 1
					end
				end
			end
		end
		cue:FireClient(player, "DefendersReady")
	elseif step == "OpenArcher" then
		-- one archer standing on open ground in plain daylight (2026-11-23: his colours are checked against the painting
		-- in open light, not under a tower roof)
		local art = game:GetService("ServerStorage"):FindFirstChild("ArtModels")
		local src = art and art:FindFirstChild("ranger_archer")
		if src then
			local m = src:Clone()
			m.Name = "OpenArcher"
			local _, size = m:GetBoundingBox()
			m:ScaleTo(m:GetScale() * 3.2 / size.Y)
			local hit = workspace:Raycast(arg + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0))
			local ground = hit and hit.Position.Y or arg.Y
			local _, s2 = m:GetBoundingBox()
			m:PivotTo(CFrame.new(arg.X, ground, arg.Z))
			local cf, s3 = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + Vector3.new(0, ground - (cf.Position.Y - s3.Y / 2), 0))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			m.Parent = workspace
		end
		cue:FireClient(player, "OpenArcherReady")
	elseif step == "Done" then
		pcall(function()
			game:GetService("StudioTestService"):EndTest("film done")
		end)
	end
end)
mark("server ready")
