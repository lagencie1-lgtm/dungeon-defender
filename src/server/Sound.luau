-- Plays sounds at a spot in the world (or for everybody if no spot is given).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Sound = {}
local lastPlayed = {}

function Sound.Play(name, position)
	local info = Config.Sounds[name]
	if not info then
		return
	end
	-- don't play the same sound more than ~15 times a second
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.07 then
		return
	end
	lastPlayed[name] = now

	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = info.Volume or 0.5
	if info.Pitch then
		s.PlaybackSpeed = info.Pitch[1] + math.random() * (info.Pitch[2] - info.Pitch[1])
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.1
		holder.Position = position
		holder.Parent = workspace:FindFirstChild("Effects") or workspace
		s.RollOffMinDistance = 30
		s.RollOffMaxDistance = 250
		s.Parent = holder
		s:Play()
		Debris:AddItem(holder, 4)
	else
		s.Parent = workspace
		s:Play()
		Debris:AddItem(s, 4)
	end
end

return Sound
