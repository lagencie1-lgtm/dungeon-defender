-- Small life in the Watch Keep, drawn on each player's own screen (smooth at any frame rate, nothing sent over the
-- network). Restraint: slow motions, no flashes.
--  * the Beacon Tower's crystal turns slowly and breathes up and down
--  * a slow violet swirl turns inside the portal, over the picture of the picked map
--  * a station's rune ring glows softly only while you stand near it
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local CRYSTAL = "c_150_90_255" -- the crystal, its own part in the keep_beacon model (bright violet: drawn as glowing Neon)
local crystal, home, swirl, t = nil, nil, nil, 0
local runes = {}

local function scan()
	local hub = workspace:FindFirstChild("Outpost")
	if not hub or hub:GetAttribute("HubVersion") ~= "Keep" then
		return
	end
	runes = {}
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and d.Name == CRYSTAL and not crystal then
			crystal, home = d, d.CFrame
		elseif d:IsA("BasePart") and d.Name == "Runes" then
			table.insert(runes, d)
		end
	end
	-- the swirl: two soft violet bands on a round frame inside the portal picture, turned by a gradient
	local view = hub:FindFirstChild("PortalView")
	local vista = view and view:FindFirstChildOfClass("SurfaceGui") and view:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("Vista")
	if vista and not swirl then
		local ring = Instance.new("Frame")
		ring.Name = "Swirl"
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundColor3 = Color3.fromRGB(170, 120, 255)
		ring.BackgroundTransparency = 0
		ring.Parent = vista
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring
		swirl = Instance.new("UIGradient")
		swirl.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.25, 0.95), NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(0.75, 0.95), NumberSequenceKeypoint.new(1, 0.55) })
		swirl.Parent = ring
	end
end

local searchIn = 0
RunService.RenderStepped:Connect(function(dt)
	searchIn -= dt
	if searchIn <= 0 then
		searchIn = 3
		if not (crystal and crystal.Parent) then
			crystal, home = nil, nil
		end
		if swirl and not swirl.Parent then
			swirl = nil
		end
		scan()
	end
	t += dt
	if crystal and crystal.Parent and home then
		-- one turn every 14 s, rising and falling 0.35 studs every 5 s
		crystal.CFrame = CFrame.new(home.Position + Vector3.new(0, math.sin(t * math.pi * 2 / 5) * 0.35, 0))
			* (home - home.Position) * CFrame.Angles(0, t * math.pi * 2 / 14, 0)
	end
	if swirl then
		swirl.Rotation = (t * 24) % 360 -- one turn every 15 s
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, r in runes do
		if r.Parent then
			local near = root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude < 9
			-- glow eases towards its target (1 - exp(-k dt)), with a slow breath while you stand in the ring
			local target = near and (0.05 + 0.15 * (1 + math.sin(t * 2.5)) / 2) or 0.55
			r.Transparency += (target - r.Transparency) * (1 - math.exp(-6 * dt))
		end
	end
end)
