-- Timing events for the research report's measurements (Creator Dashboard > Analytics > Custom events):
-- seconds from joining to the first valid defender, the first hero hit, the first rescue, the first gear equip;
-- the time from the end of a run to the next one; reward per minute of every run (win, loss or leaving early).
-- Each "First" event is sent once per visit. Nothing here changes the game.
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

local joined = {} -- [player] = os.clock() when they joined
local sent = {} -- [player] = { [name] = true }

local function log(player, name, value, fields)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value, fields)
	end)
end

-- the first time this visit that `name` happens: seconds since the player joined
function Telemetry.First(player, name)
	if not player or not joined[player] then
		return
	end
	sent[player] = sent[player] or {}
	if sent[player][name] then
		return
	end
	sent[player][name] = true
	log(player, name, math.floor(os.clock() - joined[player]))
end

-- any number, with up to three text fields (map, mode, result...)
function Telemetry.Value(player, name, value, a, b, c)
	local fields = {}
	if a then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(a)
	end
	if b then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(b)
	end
	if c then
		fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(c)
	end
	log(player, name, value, fields)
end

function Telemetry.Start()
	local function add(player)
		joined[player] = os.clock()
	end
	Players.PlayerAdded:Connect(add)
	for _, player in Players:GetPlayers() do
		add(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
		sent[player] = nil
	end)
end

return Telemetry
