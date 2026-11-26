-- Every sound of the game, loaded on this device before it is needed, and checked.
--
-- Why: some devices (older iPads above all) quietly drop sounds when a game asks for many at once, and a sound the
-- game is not allowed to use (an audio file without permission for this experience) never plays anywhere. Both look
-- the same to a player: silence. So the sounds load in small batches, each one's result is read, failures are tried
-- again a few times, and whatever still fails is reported (output, the DevPanel and Creator Hub analytics).
--
-- Rules (checked by the autotest, see test/client/AutoTestClient.client.luau):
--   batches of BATCH sounds, up to RETRIES more tries for a failed sound, waiting RETRY_WAIT[n] seconds first
--   every sound in Config.Sounds must end "loaded"
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage.Shared.Config)

local SoundBank = {}

local BATCH = 4
local RETRIES = 3
local RETRY_WAIT = { 1, 3, 6 }
local LOAD_WAIT = 8 -- seconds a preloaded sound may take to report it is ready to play

local folder = SoundService:FindFirstChild("HTD_SoundBank") or Instance.new("Folder")
folder.Name = "HTD_SoundBank"
folder.Parent = SoundService

local cache = {} -- name -> Sound (in SoundService, used for the 2D sounds: clicks, coins)

-- the one Sound kept for `name` (made the first time it is asked for)
function SoundBank.Get(name)
	local info = Config.Sounds[name]
	if not info then
		return nil
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = info.Id
		s.Volume = info.Volume or 0.5
		s.Parent = folder
		cache[name] = s
	end
	return s
end

-- the result of the last check: { done, loaded, failed = { {name, id, status} }, retried, seconds }
SoundBank.Result = nil
local finished = Instance.new("BindableEvent")
SoundBank.Finished = finished.Event

local function loadOne(s)
	-- PreloadAsync fetched the file; IsLoaded says the device decoded it and can play it
	if s.IsLoaded then
		return true
	end
	local deadline = os.clock() + LOAD_WAIT
	while not s.IsLoaded and os.clock() < deadline do
		task.wait(0.1)
	end
	return s.IsLoaded
end

-- loads `sounds` (a list of Sound) in batches; returns the ones that failed with their fetch status
local function loadAll(sounds)
	local failed = {}
	for start = 1, #sounds, BATCH do
		local batch = {}
		for i = start, math.min(start + BATCH - 1, #sounds) do
			table.insert(batch, sounds[i])
		end
		local status = {}
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(batch, function(contentId, fetchStatus)
				status[contentId] = fetchStatus
			end)
		end)
		for _, s in batch do
			local fetch = status[s.SoundId]
			local good = ok and (fetch == nil or fetch == Enum.AssetFetchStatus.Success) and loadOne(s)
			if not good then
				table.insert(failed, { sound = s, status = not ok and ("error " .. tostring(err))
					or (fetch and fetch.Name) or "not loaded" })
			end
		end
	end
	return failed
end

-- loads and checks every sound in Config.Sounds (once per visit; later calls wait for the first one)
local running = false
function SoundBank.CheckAll()
	if SoundBank.Result then
		return SoundBank.Result
	end
	if running then
		finished.Event:Wait()
		return SoundBank.Result
	end
	running = true
	local started = os.clock()
	-- the same file is often used by several sounds (Click and Coin): load each file once
	local byId, list, names = {}, {}, {}
	local nameList = {}
	for name in Config.Sounds do
		table.insert(nameList, name)
	end
	table.sort(nameList)
	for _, name in nameList do
		local s = SoundBank.Get(name)
		names[s.SoundId] = names[s.SoundId] or {}
		table.insert(names[s.SoundId], name)
		if not byId[s.SoundId] then
			byId[s.SoundId] = s
			table.insert(list, s)
		end
	end
	local failed = loadAll(list)
	local retried = #failed
	for round = 1, RETRIES do
		if #failed == 0 then
			break
		end
		task.wait(RETRY_WAIT[round])
		local again = {}
		for _, f in failed do
			table.insert(again, f.sound)
		end
		failed = loadAll(again)
	end
	local report = { done = true, files = #list, loaded = #list - #failed, retried = retried, failed = {},
		seconds = os.clock() - started }
	for _, f in failed do
		table.insert(report.failed, { names = table.concat(names[f.sound.SoundId], "/"), id = f.sound.SoundId, status = f.status })
	end
	SoundBank.Result = report
	running = false
	finished:Fire(report)
	return report
end

-- one line for the output and the DevPanel
function SoundBank.Summary(report)
	report = report or SoundBank.Result
	if not report then
		return "sounds: still loading"
	end
	local line = string.format("%d of %d sound files loaded in %.1f s (%d needed another try)", report.loaded, report.files,
		report.seconds, report.retried)
	for _, f in report.failed do
		line ..= string.format("; FAILED %s %s (%s)", f.names, f.id, f.status)
	end
	return line
end

return SoundBank
