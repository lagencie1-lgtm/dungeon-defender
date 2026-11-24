-- Strong gear makes the hero a little bigger (Config.MightRanks, Scale). The glow, sparks and rings are drawn on
-- every device by MightLook.client.luau; only the size has to come from the server so everyone sees the same hero.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MightService = {}

local SCALES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

local function apply(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local rank = Config.MightRanks[player:GetAttribute("MightRank") or 1] or Config.MightRanks[1]
	local scale = rank.Scale or 1
	for _, name in SCALES do
		local value = humanoid:FindFirstChild(name)
		if not value then
			value = Instance.new("NumberValue")
			value.Name = name
			value.Value = 1
			value.Parent = humanoid
		end
		-- remember the avatar's own size once, then grow from it
		local base = value:GetAttribute("MightBase")
		if not base then
			base = value.Value
			value:SetAttribute("MightBase", base)
		end
		if math.abs(value.Value - base * scale) > 0.001 then
			value.Value = base * scale
		end
	end
end

function MightService.Start()
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			task.wait(0.5) -- after the avatar has loaded its own scales
			apply(player)
		end)
		player:GetAttributeChangedSignal("MightRank"):Connect(function()
			apply(player)
		end)
		if player.Character then
			task.spawn(apply, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return MightService
