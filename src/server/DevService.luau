-- Developer cheats for testing (Lemp 2026-11-23: "yes build it"). Only the game's owner gets them:
-- the server checks the account on every single press, so nobody else can use them even with a hacked
-- client. Everyone else is turned down by the server and never sees the panel (it only appears for players
-- the server marked with the "Developer" attribute).
--
-- Who counts as the owner: the account that owns the experience (or the owner of the group, if the game
-- ever moves to a group), the ids in DEVELOPER_IDS, and anyone playing inside Roblox Studio.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Store = require(ReplicatedStorage.Shared.Store)
local DataService = require(script.Parent.DataService)
local HeroService = require(script.Parent.HeroService)
local PetService = require(script.Parent.PetService)
local SeasonService = require(script.Parent.SeasonService)
local State = require(script.Parent.State)

local DevService = {}

-- Lemp's Roblox account (the account signed in to Studio on Lemp's PC)
local DEVELOPER_IDS = { [11766403666] = true }

local groupOwnerId = nil
if game.CreatorType == Enum.CreatorType.Group then
	pcall(function()
		local info = GroupService:GetGroupInfoAsync(game.CreatorId)
		groupOwnerId = info and info.Owner and info.Owner.Id
	end)
end

local function isDeveloper(player)
	if RunService:IsStudio() then
		return true
	end
	if DEVELOPER_IDS[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		return true
	end
	return groupOwnerId ~= nil and groupOwnerId == player.UserId
end

-- what each button gives. The panel shows them in this order.
DevService.Grants = {
	{ Id = "Gems", Text = "+1000 Gems" },
	{ Id = "Gold", Text = "+5000 Gold" },
	{ Id = "Scrap", Text = "+500 Scrap" },
	{ Id = "Mana", Text = "+1000 Mana (in a run)" },
	{ Id = "HeroLevel", Text = "Hero +1 level" },
	{ Id = "SeasonLevel", Text = "Season pass +1 level" },
	{ Id = "ResetSave", Text = "Reset my save (press twice)" }, -- "ResetSaveConfirm" is the second press
	{ Id = "PetDust", Text = "+500 Pet Dust" },
	{ Id = "FivePets", Text = "+5 Slimey (to test fusing)" },
}

local function grant(player, id)
	if not isDeveloper(player) then
		return false, "Not allowed"
	end
	local profile = DataService.Get(player)
	if not profile then
		return false, "Still loading"
	end
	if id == "ResetSave" or id == "ResetSaveConfirm" then
		-- deletes the whole save and sends the player out, so the next join is a brand-new player
		return DataService.ResetSave(player, id == "ResetSaveConfirm")
	end
	if id == "Gems" then
		DataService.AddGems(player, 1000)
	elseif id == "Gold" then
		DataService.AddGold(player, 5000)
	elseif id == "Scrap" then
		profile.Scrap = (profile.Scrap or 0) + 500
		DataService.Publish(player)
	elseif id == "Mana" then
		local state = State.Get("State")
		if state ~= "Wave" and state ~= "Break" then
			return false, "Mana only works during a run"
		end
		State.AddGold(1000)
	elseif id == "HeroLevel" then
		local level = player:GetAttribute("HeroLevel") or 1
		if level >= Config.HeroMaxLevel then
			return false, "Hero is at the top level"
		end
		HeroService.AddXp(player, Config.XpForLevel(level))
	elseif id == "SeasonLevel" then
		SeasonService.AddXp(player, Store.Season.XpPerLevel)
	elseif id == "PetDust" then
		PetService.AddDust(player, 500)
	elseif id == "FivePets" then
		local ok, why = PetService.Give(player, "Slimey", Config.PetFuseCount)
		if not ok then
			return false, why
		end
	else
		return false, "Unknown"
	end
	print(("[DEV] %s used %s"):format(player.Name, id))
	task.spawn(DataService.Save, player)
	return true
end

function DevService.Start()
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "DevGrant"
	remote.OnServerInvoke = grant
	remote.Parent = folder

	local function onPlayer(player)
		if isDeveloper(player) then
			player:SetAttribute("Developer", true)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return DevService
