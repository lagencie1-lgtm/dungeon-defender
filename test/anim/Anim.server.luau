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
	elseif step == "Done" then
		pcall(function()
			game:GetService("StudioTestService"):EndTest("anim done")
		end)
	end
end)
mark("server ready")
