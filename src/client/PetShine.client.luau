-- Rainbow pets: the soft colour wash over the painted pet (PetService, Config.PetTiers) turns slowly through
-- Config.RainbowHues on this device. Golden pets keep their still gold wash. 6A restraint: one slow turn every
-- Config.RainbowSeconds, a faint fill, no outline, nothing that flashes.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local hues = Config.RainbowHues
local washes = {} -- [Highlight] = a phase offset, so two rainbow pets side by side are not in step

local function hueAt(t)
	-- smooth (cosine-eased) steps from one hue to the next, round and round
	local x = (t / Config.RainbowSeconds % 1) * #hues
	local i = math.floor(x)
	local f = x - i
	f = 0.5 - 0.5 * math.cos(f * math.pi)
	return hues[i + 1]:Lerp(hues[(i + 1) % #hues + 1], f)
end

local function watch(model)
	if model:GetAttribute("PetTier") ~= 2 then
		return
	end
	local wash = model:WaitForChild("TierWash", 10)
	if wash and wash:IsA("Highlight") then
		washes[wash] = math.random() * Config.RainbowSeconds
		wash.Destroying:Connect(function()
			washes[wash] = nil
		end)
	end
end
CollectionService:GetInstanceAddedSignal("PetFollower"):Connect(function(model)
	task.spawn(watch, model)
end)
for _, model in CollectionService:GetTagged("PetFollower") do
	task.spawn(watch, model)
end

local since = 0
RunService.Heartbeat:Connect(function(dt)
	since += dt
	if since < 1 / 15 or next(washes) == nil then
		return -- (a slow colour turn needs no more than 15 updates a second)
	end
	since = 0
	local now = os.clock()
	for wash, offset in washes do
		if wash.Parent then
			wash.FillColor = hueAt(now + offset)
		end
	end
end)
