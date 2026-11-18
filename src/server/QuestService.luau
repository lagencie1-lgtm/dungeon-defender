-- Daily quests: 3 new quests every day. Progress comes from playing,
-- rewards (gold and gems) are claimed on the quest board or the Quests screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local function today()
	return os.time() // 86400
end

-- makes sure the player has today's quests
local function questsOf(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local q = profile.Quests
	if type(q) ~= "table" or q.Day ~= today() then
		-- pick 3 different quests, the same 3 for everyone on the same day (good for playing together)
		local rng = Random.new(today() * 7919)
		local pool = table.clone(Config.Quests)
		local list = {}
		for _ = 1, Config.QuestsPerDay do
			local info = table.remove(pool, rng:NextInteger(1, #pool))
			table.insert(list, { Id = info.Id, Progress = 0, Claimed = false })
		end
		q = { Day = today(), List = list }
		profile.Quests = q
	end
	return q
end

local function publish(player)
	local q = questsOf(player)
	if q then
		Remotes.Quests:FireClient(player, q.List)
		local ready = 0
		for _, quest in q.List do
			local info = Config.FindById(Config.Quests, quest.Id)
			if info and not quest.Claimed and quest.Progress >= info.Goal then
				ready += 1
			end
		end
		player:SetAttribute("QuestsReady", ready)
	end
end

-- adds progress for one player. kind is a quest Id like "Kills"
function QuestService.Add(player, kind, amount)
	local q = questsOf(player)
	if not q then
		return
	end
	local changed = false
	for _, quest in q.List do
		if quest.Id == kind and not quest.Claimed then
			local info = Config.FindById(Config.Quests, quest.Id)
			if info and quest.Progress < info.Goal then
				quest.Progress = math.min(info.Goal, quest.Progress + (amount or 1))
				changed = true
				if quest.Progress >= info.Goal then
					Remotes.Notify:FireClient(player, "Quest done: " .. string.format(info.Text, info.Goal) .. "! Claim it",
						Color3.fromRGB(255, 220, 90))
				end
			end
		end
	end
	if changed then
		publish(player)
	end
end

function QuestService.AddAll(kind, amount)
	for _, player in Players:GetPlayers() do
		QuestService.Add(player, kind, amount)
	end
end

local function claim(player, index)
	local q = questsOf(player)
	local quest = q and q.List[index]
	if not quest then
		return false, "No such quest"
	end
	local info = Config.FindById(Config.Quests, quest.Id)
	if quest.Claimed then
		return false, "Already claimed"
	end
	if quest.Progress < info.Goal then
		return false, "Not done yet"
	end
	quest.Claimed = true
	DataService.AddGold(player, info.Gold)
	DataService.AddGems(player, info.Gems)
	publish(player)
	return true, info.Gold, info.Gems
end

function QuestService.Start()
	Remotes.ClaimQuest.OnServerInvoke = claim
	Remotes.GetQuests.OnServerInvoke = function(player)
		local q = questsOf(player)
		return q and q.List or {}
	end
	table.insert(DataService.OnLoaded, function(player)
		publish(player)
	end)
end

return QuestService
