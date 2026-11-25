-- A one-tap ping for playing together without voice (research report: a lane or target ping, an icon at the lane).
-- A player sends a spot on the ground; everyone sees a ring with that player's name there for a few seconds
-- (Ping.client.luau). At most one ping a second per player, only on the ground near the map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PingService = {}

local last = {} -- [player] = os.clock() of the last ping

function PingService.Start()
	Remotes.Ping.OnServerEvent:Connect(function(player, position)
		if typeof(position) ~= "Vector3" or position.Magnitude > 5000 or position.Y ~= position.Y then
			return
		end
		local now = os.clock()
		if now - (last[player] or 0) < 1 then
			return
		end
		last[player] = now
		Remotes.Ping:FireAllClients(player.UserId, player.DisplayName, position)
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return PingService
