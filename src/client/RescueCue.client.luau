-- The first-wave rescue on this device: a thin ring on the ground where this hero can still catch the Goblin Sneak
-- (player attribute "RescueAt", worked out by RescueService). It grows in on a spring and fades when the Sneak is
-- caught or gone. 6A: one quiet shape, no arrows or flashing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Ground = require(ReplicatedStorage.Shared.Ground)

local player = Players.LocalPlayer
local COLOR = Color3.fromRGB(255, 170, 50) -- the Sneak's own mark colour
local RADIUS = 4.5
local BEADS = 18

local folder = Instance.new("Folder")
folder.Name = "RescueCue"
folder.Parent = workspace

local beads = {}
for i = 1, BEADS do
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 0.45
	p.Material = Enum.Material.Neon
	p.Color = COLOR
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	beads[i] = p
end

-- critically damped spring, exact for any frame time
local function spring(x, v, target, hz, dt)
	local w = 2 * math.pi * hz
	local d = x - target
	local e = math.exp(-w * dt)
	local c = v + w * d
	return target + (d + c * dt) * e, (v - c * w * dt) * e
end

local shown, showVel = 0, 0 -- 0 = gone, 1 = full size
local at = nil -- where the ring stands (it glides to a new spot instead of jumping)
local atVel = Vector3.zero
local clock = 0

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	clock += dt
	local target = player:GetAttribute("RescueAt")
	local want = typeof(target) == "Vector3" and 1 or 0
	shown, showVel = spring(shown, showVel, want, 2.4, dt)
	if want == 1 then
		local ground = math.max(target.Y, (Ground.At(target.X, target.Z))) + 0.25
		local goal = Vector3.new(target.X, ground, target.Z)
		if not at or (at - goal).Magnitude > 40 then
			at, atVel = goal, Vector3.zero
		else
			local x, vx = spring(at.X, atVel.X, goal.X, 1.6, dt)
			local y, vy = spring(at.Y, atVel.Y, goal.Y, 1.6, dt)
			local z, vz = spring(at.Z, atVel.Z, goal.Z, 1.6, dt)
			at, atVel = Vector3.new(x, y, z), Vector3.new(vx, vy, vz)
		end
	end
	local visible = shown > 0.02 and at ~= nil
	for i, p in beads do
		if visible then
			local a = clock * 0.5 + i / BEADS * math.pi * 2
			local r = RADIUS * math.clamp(shown, 0, 1.2)
			p.Position = at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			p.Transparency = 1 - 0.75 * math.clamp(shown, 0, 1)
		elseif p.Transparency < 1 then
			p.Transparency = 1
		end
	end
end)
