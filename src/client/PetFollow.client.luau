-- Moves every pet that follows a hero, on this device (the server only creates the pet: PetService).
-- 6A: springs solved exactly so 30 fps looks like 120 fps, no linear tweens, nothing floats without a reason.
-- Walking pets hop after their hero and land with a little nod; winged pets hover with a slow wing-beat bob.
-- Standing still, a pet breathes and turns to look where its hero looks.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FLYERS = { Glowbug = true, CrystalOwl = true, Phoenix = true }
local SIDE, BACK = 3.2, 2.4 -- where the pet stands: to the hero's right and a little behind
local FOLLOW_HZ = 1.9 -- how eagerly it catches up (critically damped)
local TURN_HZ = 2.6
local HOP_TIME, HOP_HEIGHT = 0.36, 0.85
local FAR = 220 -- beyond this the pet is only placed, not animated

local pets = {} -- [model] = state

-- critically damped spring, exact for any frame time
local function spring(x, v, target, hz, dt)
	local w = 2 * math.pi * hz
	local d = x - target
	local e = math.exp(-w * dt)
	local c = v + w * d
	return target + (d + c * dt) * e, (v - c * w * dt) * e
end

local function groundUnder(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position.Y
end

local function add(model)
	local body = model.PrimaryPart or model:WaitForChild("Body", 5)
	if not body then
		return
	end
	local scale = model:GetAttribute("PetScale") or 1
	pets[model] = {
		body = body,
		half = 1.15 * scale, -- the pet is 2.3 studs tall, its body part sits at its middle
		flyer = FLYERS[model:GetAttribute("PetKind")] == true,
		pos = nil, vel = Vector3.zero,
		yaw = 0, yawVel = 0,
		hop = 0, hopping = false,
		nod = 0, nodVel = 0,
		ground = nil, groundClock = 0,
		clock = math.random() * 10,
	}
end

for _, model in CollectionService:GetTagged("PetFollower") do
	task.spawn(add, model)
end
CollectionService:GetInstanceAddedSignal("PetFollower"):Connect(add)
CollectionService:GetInstanceRemovedSignal("PetFollower"):Connect(function(model)
	pets[model] = nil
end)

local function angleDelta(a, b)
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local camera = workspace.CurrentCamera
	for model, s in pets do
		local owner = Players:GetPlayerByUserId(model:GetAttribute("PetOwner") or 0)
		local character = owner and owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not s.body.Parent then
			continue
		end
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.zAxis
		local right = Vector3.new(-flat.Z, 0, flat.X)
		local target = root.Position + right * SIDE - flat * BACK
		if not s.pos or (s.pos - target).Magnitude > 40 then
			s.pos, s.vel = target, Vector3.zero -- first frame or a teleport: appear in place
		end
		if camera and (camera.CFrame.Position - target).Magnitude > FAR then
			s.pos = target
			s.body.CFrame = CFrame.new(target)
			continue
		end
		s.clock += dt
		-- across the ground
		local x, vx = spring(s.pos.X, s.vel.X, target.X, FOLLOW_HZ, dt)
		local z, vz = spring(s.pos.Z, s.vel.Z, target.Z, FOLLOW_HZ, dt)
		s.vel = Vector3.new(vx, 0, vz)
		local speed = s.vel.Magnitude
		-- the ground under the pet, looked up a few times a second
		s.groundClock -= dt
		if s.groundClock <= 0 or not s.ground then
			s.groundClock = 0.15
			s.ground = groundUnder(Vector3.new(x, root.Position.Y, z), { model, character }) or (root.Position.Y - 3)
		end
		local lift, tilt
		if s.flyer then
			-- hovering: a slow double bob like wing beats, leaning into the flight
			lift = 2.1 + math.sin(s.clock * 2.4) * 0.22 + math.sin(s.clock * 4.8) * 0.05
			tilt = -math.clamp(speed / 16, 0, 1) * math.rad(14)
		else
			if not s.hopping and speed > 1.6 then
				s.hopping, s.hop = true, 0
			end
			lift = 0
			if s.hopping then
				s.hop += dt / HOP_TIME
				if s.hop >= 1 then
					s.hopping = speed > 1.6
					s.hop = 0
					s.nodVel -= 2.4 -- landing: a quick nod that springs back
				else
					lift = 4 * HOP_HEIGHT * s.hop * (1 - s.hop) * math.clamp(speed / 8, 0.45, 1)
				end
			end
			lift += (1 + math.sin(s.clock * 1.7)) * 0.03 -- breathing
			tilt = -math.clamp(speed / 16, 0, 1) * math.rad(9)
		end
		s.nod, s.nodVel = spring(s.nod, s.nodVel, 0, 3.2, dt)
		-- face where it is going; standing still, where the hero looks
		local wantYaw = speed > 1.2 and math.atan2(-s.vel.X, -s.vel.Z) or math.atan2(-flat.X, -flat.Z)
		local goal = s.yaw + angleDelta(s.yaw, wantYaw)
		s.yaw, s.yawVel = spring(s.yaw, s.yawVel, goal, TURN_HZ, dt)
		s.pos = Vector3.new(x, s.ground + s.half + lift, z)
		s.body.CFrame = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(tilt + s.nod * 0.12, 0, 0)
	end
end)
