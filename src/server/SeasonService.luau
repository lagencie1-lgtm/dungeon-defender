-- The season (battle pass): pass XP from waves, wins and quests fills levels.
-- Every level has a free reward and a paid reward (paid needs the Season Pass).
-- Also: tracking where new players stop (Creator Dashboard > Analytics > Funnels).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Store = require(ReplicatedStorage.Shared.Store)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local SeasonService = {}
local S = Store.Season

local function seasonOf(profile)
	local s = profile.Season
	if type(s) ~= "table" or s.Id ~= S.Id then
		s = { Id = S.Id, Xp = 0, Level = 0, Paid = false, Free = {}, PaidClaimed = {} }
		profile.Season = s
	end
	s.Free = s.Free or {}
	s.PaidClaimed = s.PaidClaimed or {}
	return s
end

local function publish(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local s = seasonOf(profile)
	Remotes.Season:FireClient(player, s)
	-- a red dot when something can be claimed
	local ready = 0
	for level = 1, s.Level do
		if not s.Free[tostring(level)] then
			ready += 1
		end
		if s.Paid and not s.PaidClaimed[tostring(level)] then
			ready += 1
		end
	end
	player:SetAttribute("SeasonReady", ready)
	player:SetAttribute("SeasonLevel", s.Level)
end

function SeasonService.AddXp(player, amount)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local s = seasonOf(profile)
	if s.Level >= S.Levels then
		return
	end
	s.Xp += amount
	local before = s.Level
	while s.Xp >= S.XpPerLevel and s.Level < S.Levels do
		s.Xp -= S.XpPerLevel
		s.Level += 1
	end
	if s.Level > before then
		Remotes.Notify:FireClient(player, "Season level " .. s.Level .. "! Claim your reward (Season button)", Color3.fromRGB(120, 255, 160))
	end
	publish(player)
end

function SeasonService.AddXpAll(amount)
	for _, player in Players:GetPlayers() do
		SeasonService.AddXp(player, amount)
	end
end

function SeasonService.UnlockPaid(profile)
	seasonOf(profile).Paid = true
end

local function give(player, profile, reward)
	if reward.Kind == "Gems" then
		profile.Gems += reward.Amount
	elseif reward.Kind == "Gold" then
		profile.Gold += reward.Amount
	elseif reward.Kind == "Skin" then
		profile.Owned.Skins = profile.Owned.Skins or {}
		profile.Owned.Skins[reward.Id] = true
	elseif reward.Kind == "Title" then
		profile.Owned.Titles[reward.Id] = true
	end
	DataService.Publish(player)
end

local function claim(player, level, track)
	local profile = DataService.Get(player)
	if not profile or type(level) ~= "number" then
		return false, "Still loading"
	end
	local s = seasonOf(profile)
	level = math.floor(level)
	if level < 1 or level > s.Level then
		return false, "Reach season level " .. level .. " first"
	end
	local free, paid = Store.SeasonReward(level)
	local key = tostring(level)
	if track == "Paid" then
		if not s.Paid then
			return false, "Needs the Season Pass"
		end
		if s.PaidClaimed[key] then
			return false, "Already claimed"
		end
		s.PaidClaimed[key] = true
		give(player, profile, paid)
	else
		if s.Free[key] then
			return false, "Already claimed"
		end
		s.Free[key] = true
		give(player, profile, free)
	end
	publish(player)
	task.spawn(DataService.Save, player)
	return true
end

-------------------------------------------------------------------------------
-- where new players stop: steps 1..6 show up as a funnel in the dashboard
-------------------------------------------------------------------------------
local FUNNEL = { "Joined", "Started a run", "Built a defender", "Cleared wave 1", "Cleared wave 5", "Won a run" }
function SeasonService.Funnel(player, step)
	local profile = DataService.Get(player)
	if not profile or (profile.FunnelStep or 0) >= step then
		return
	end
	profile.FunnelStep = step
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, FUNNEL[step])
	end)
end

function SeasonService.FunnelAll(step)
	for _, player in Players:GetPlayers() do
		SeasonService.Funnel(player, step)
	end
end

function SeasonService.LogRunEnded(player, mapId, mode, wave, won)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, won and "RunWon" or "RunLost", wave, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = mapId,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = mode,
		})
	end)
end

function SeasonService.Start()
	Remotes.ClaimSeason.OnServerInvoke = claim
	Remotes.GetSeason.OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		return profile and seasonOf(profile) or nil
	end
	table.insert(DataService.OnLoaded, function(player)
		publish(player)
		SeasonService.Funnel(player, 1)
	end)
end

return SeasonService
