-- Small life in the Watch Keep, drawn on each player's own screen (smooth at any frame rate, nothing sent over the
-- network): the Beacon Tower's crystal turns slowly and breathes up and down. Restraint: one slow motion, no flashes.
local RunService = game:GetService("RunService")

local CRYSTAL = "c_150_90_255" -- the crystal, its own part in the keep_beacon model (bright violet: drawn as glowing Neon)
local crystal, home, t = nil, nil, 0

local function find()
	local hub = workspace:FindFirstChild("Outpost")
	if not hub or hub:GetAttribute("HubVersion") ~= "Keep" then
		return nil
	end
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and d.Name == CRYSTAL then
			return d
		end
	end
	return nil
end

local searchIn = 0
RunService.RenderStepped:Connect(function(dt)
	if not crystal or not crystal.Parent then
		crystal, home = nil, nil
		searchIn -= dt
		if searchIn <= 0 then
			searchIn = 2
			crystal = find()
			home = crystal and crystal.CFrame
		end
		return
	end
	t += dt
	-- one turn every 14 s, rising and falling 0.35 studs every 5 s (a sine is a smooth periodic motion, not a tween)
	crystal.CFrame = CFrame.new(home.Position + Vector3.new(0, math.sin(t * math.pi * 2 / 5) * 0.35, 0))
		* (home - home.Position) * CFrame.Angles(0, t * math.pi * 2 / 14, 0)
end)
