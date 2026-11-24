-- Moves every pet that follows a hero, on this device (the server only creates the pet: PetService).
-- 6A: springs solved exactly so 30 fps looks like 120 fps, no linear tweens, nothing floats without a reason.
-- Walking pets hop after their hero and land with a little nod; winged pets hover with a slow wing-beat bob.
-- Standing still, a pet breathes and turns to look where its hero looks.
-- Every kind has its own GAIT (research report 2026-11-24: "give each pet species a job and a movement signature you
-- can recognize before adding more species"): Slimey wobbles in low quick bounces, the Golem stomps, the Fox trots,
-- the Unicorn prances, the Owl glides and banks, the Glowbug buzzes. Motion only: no new effects.
-- In a fight the server picks a move (PetMoves.luau) and sets "PetAct" on the model: the pet lunges at the
-- target on a spring and springs back, with one small shot or glow (6A: small, rare, readable on a phone).
-- Fetching loot ("FetchPhase" go/back): the spot the pet springs after trots to the loot at the pet's speed and
-- back to the hero; on the way back the pet carries a small glowing bead in the loot's colour.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local CombatLooks = require(script.Parent.CombatLooks)

local FLYERS = { Glowbug = true, CrystalOwl = true, Phoenix = true }
-- walkers: hop = seconds per hop, height = studs, sway = side-to-side roll while moving (degrees), lean = forward tilt
-- at full speed (degrees), land = landing nod kick, breathe = idle rise (studs)
-- flyers: lift = hover height, bob / bobHz = up-down, buzz = quick sideways jitter (studs), bank = roll into turns
local GAITS = {
	Slimey = { hop = 0.26, height = 0.35, sway = 7, lean = 4, land = 3.2, breathe = 0.07 }, -- jelly wobble
	Leafling = { hop = 0.22, height = 0.18, sway = 11, lean = 5, land = 1.4, breathe = 0.04 }, -- waddle
	Stonepup = { hop = 0.34, height = 0.9, sway = 3, lean = 10, land = 2.6, breathe = 0.03 }, -- bouncy puppy
	MossKitten = { hop = 0.3, height = 0.6, sway = 2, lean = 8, land = 1.8, breathe = 0.03 }, -- light prance
	EmberFox = { hop = 0.22, height = 0.42, sway = 1, lean = 14, land = 1.6, breathe = 0.03 }, -- low quick trot
	MiniGolem = { hop = 0.5, height = 0.14, sway = 6, lean = 3, land = 4.5, breathe = 0.015 }, -- heavy stomp
	BabyDragon = { hop = 0.38, height = 0.65, sway = 5, lean = 8, land = 2.4, breathe = 0.04 }, -- waddle-hop
	StarUnicorn = { hop = 0.42, height = 1.15, sway = 2, lean = 6, land = 2, breathe = 0.03 }, -- high prance
	VoidDrake = { hop = 0.5, height = 0.8, sway = 3, lean = 12, land = 3, breathe = 0.03 }, -- long low leaps
	Glowbug = { lift = 2.0, bob = 0.12, bobHz = 1.2, buzz = 0.07, bank = 6 }, -- quick little buzz
	CrystalOwl = { lift = 2.3, bob = 0.3, bobHz = 0.32, buzz = 0, bank = 22 }, -- slow glide, banks into turns
	Phoenix = { lift = 2.6, bob = 0.26, bobHz = 0.45, buzz = 0, bank = 16 }, -- soaring swoop
}
local WALK = { hop = 0.36, height = 0.85, sway = 0, lean = 9, land = 2.4, breathe = 0.03 }
local FLY = { lift = 2.1, bob = 0.22, bobHz = 0.38, buzz = 0, bank = 8 }
local SIDE, BACK = 3.2, 2.4 -- where the lead pet stands: to the hero's right and a little behind
-- the team (PetSlot 1 to 3): the lead on the right, the second on the left, the third behind the hero
local SLOTS = { { SIDE, BACK }, { -SIDE, BACK }, { 0, BACK + 2.6 } }
local FOLLOW_HZ = 1.9 -- how eagerly it catches up (critically damped)
local TURN_HZ = 2.6
local FAR = 220 -- beyond this the pet is only placed, not animated
local LUNGE_HZ = 1.7 -- the lunge: a kick of speed on a spring that brings it back (peaks after about 0.09 s)
local LUNGE_MAX = 5 -- studs at most
local HIT_TIME = 0.22 -- the same as the server's HIT_DELAY
local MANA_COLOR = Color3.fromRGB(170, 150, 255) -- Ui.MANA

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
		gait = GAITS[model:GetAttribute("PetKind") or ""] or (FLYERS[model:GetAttribute("PetKind")] and FLY or WALK),
		pos = nil, vel = Vector3.zero,
		yaw = 0, yawVel = 0,
		hop = 0, hopping = false,
		nod = 0, nodVel = 0,
		ground = nil, groundClock = 0,
		clock = math.random() * 10,
		lunge = Vector3.zero, lungeVel = Vector3.zero,
		goal = nil, away = false, orb = nil,
	}
	model:GetAttributeChangedSignal("PetAct"):Connect(function()
		local s = pets[model]
		if s then
			s.act = true -- played on the next frame, from where the pet is drawn then
		end
	end)
end

-- the move's own short sound, from the pet (3D: only players nearby hear it, louder the closer they are)
local function moveSound(s, name)
	local info = Config.Sounds["Pet" .. name]
	if not info then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = info.Id
	sound.Volume = info.Volume or 0.3
	sound.PlaybackSpeed = info.Pitch and (info.Pitch[1] + math.random() * (info.Pitch[2] - info.Pitch[1])) or 1
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 12, 70
	sound.Parent = s.body
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- one move, seen from this device
local function playMove(model, s)
	local move = model:GetAttribute("PetActMove")
	local at = model:GetAttribute("PetActAt")
	if typeof(at) ~= "Vector3" or not s.pos then
		return
	end
	local info = Config.Pets[model:GetAttribute("PetKind") or ""]
	local color = info and info.Color or Color3.new(1, 1, 1)
	local from = s.pos
	local offset = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	local dir = offset.Magnitude > 0.1 and offset.Unit or Vector3.zero
	local reach = math.min(offset.Magnitude * 0.35, LUNGE_MAX)
	if typeof(move) == "string" then
		moveSound(s, move)
	end
	if move == "Dig" then
		-- a little dig in place: a nod down and a puff of mana
		s.nodVel += 4
		CombatLooks.Particles(Vector3.new(from.X, s.ground or from.Y, from.Z), { Color = MANA_COLOR, Count = 8, Size = 0.5,
			Speed = 7, Life = 0.45, Gravity = -20, Spread = 40 })
		return
	end
	-- spring kick: a critically damped spring started with speed v peaks at v / (w * e)
	local w = 2 * math.pi * LUNGE_HZ
	s.lungeVel += dir * reach * w * math.exp(1)
	s.nodVel -= 1.6
	if not s.flyer then
		s.hopping, s.hop = true, 0
	end
	if move == "Pounce" or move == "Mark" then
		local shotColor = move == "Mark" and Color3.fromRGB(255, 225, 90) or color
		CombatLooks.Projectile(from + dir * 0.8, at + Vector3.new(0, 1.5, 0), shotColor, move == "Mark" and 0.45 or 0.6, HIT_TIME)
	elseif move == "Rally" or move == "Spark" then
		local glow = move == "Spark" and Color3.fromRGB(255, 170, 60) or color
		CombatLooks.Bolt(from + Vector3.new(0, 0.6, 0), at, glow, 0.3, HIT_TIME)
		task.delay(HIT_TIME, function()
			CombatLooks.Burst(at, 1.6, glow, 0.35)
		end)
	end
end

for _, model in CollectionService:GetTagged("PetFollower") do
	task.spawn(add, model)
end
CollectionService:GetInstanceAddedSignal("PetFollower"):Connect(add)
CollectionService:GetInstanceRemovedSignal("PetFollower"):Connect(function(model)
	local s = pets[model]
	if s and s.orb then
		s.orb:Destroy()
	end
	pets[model] = nil
end)

-- the bead a pet carries back from a fetch (only on this device)
local function carryBead(s, color, dt)
	if not color then
		if s.orb then
			s.orb:Destroy()
			s.orb = nil
		end
		return
	end
	if not s.orb then
		local orb = Instance.new("Part")
		orb.Name = "PetCarry"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.one * 0.55
		orb.Material = Enum.Material.Neon
		orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch = true, false, false, false
		orb.CastShadow = false
		orb.Parent = workspace:FindFirstChild("LocalCombatEffects") or workspace
		s.orb = orb
	end
	s.orb.Color = color
	s.orb.Position = s.pos + Vector3.new(0, s.half + 0.5 + math.sin(s.clock * 5) * 0.08, 0)
end

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
		local place = SLOTS[model:GetAttribute("PetSlot") or 1] or SLOTS[1]
		local follow = root.Position + right * place[1] - flat * place[2]
		-- fetching: the spot the pet follows walks to the loot and back at the pet's own speed
		local phase = model:GetAttribute("FetchPhase") or ""
		local fetchAt = model:GetAttribute("FetchAt")
		if phase == "go" and typeof(fetchAt) == "Vector3" then
			s.away = true
		end
		if s.away and s.goal then
			local dest = (phase == "go" and typeof(fetchAt) == "Vector3") and fetchAt or follow
			local speed = (model:GetAttribute("FetchSpeed") or 10) * (phase == "go" and 1 or 1.15)
			local step = Vector3.new(dest.X - s.goal.X, 0, dest.Z - s.goal.Z)
			if step.Magnitude <= speed * dt then
				s.goal = Vector3.new(dest.X, follow.Y, dest.Z)
				if phase ~= "go" then
					s.away = false -- home again
				end
			else
				s.goal += step.Unit * speed * dt
			end
		else
			s.goal = follow
		end
		local target = s.goal
		if not s.pos or (s.pos - follow).Magnitude > 60 then
			target, s.goal, s.away = follow, follow, false
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
		local lift, tilt, roll
		local g = s.gait
		local side = Vector3.zero
		if s.flyer then
			-- hovering: a double bob like wing beats, leaning into the flight and banking into turns
			local w = 2 * math.pi * g.bobHz
			lift = g.lift + math.sin(s.clock * w) * g.bob + math.sin(s.clock * w * 2) * g.bob * 0.25
			tilt = -math.clamp(speed / 16, 0, 1) * math.rad(14)
			roll = math.clamp(-s.yawVel * 0.12, -1, 1) * math.rad(g.bank)
			if g.buzz > 0 then -- a bug's quick little sideways jitter
				side = right * (math.sin(s.clock * 17) * 0.6 + math.sin(s.clock * 29) * 0.4) * g.buzz
			end
		else
			if not s.hopping and speed > 1.6 then
				s.hopping, s.hop = true, 0
			end
			lift = 0
			roll = 0
			if s.hopping then
				s.hop += dt / g.hop
				if s.hop >= 1 then
					s.hopping = speed > 1.6
					s.hop = 0
					s.nodVel -= g.land -- landing: a quick nod that springs back
					s.step = -(s.step or 1) -- the sway swings to the other side with every hop
				else
					local pace = math.clamp(speed / 8, 0.45, 1)
					lift = 4 * g.height * s.hop * (1 - s.hop) * pace
					roll = math.sin(s.hop * math.pi) * (s.step or 1) * math.rad(g.sway) * pace
				end
			end
			lift += (1 + math.sin(s.clock * 1.7)) * g.breathe -- breathing
			tilt = -math.clamp(speed / 16, 0, 1) * math.rad(g.lean)
		end
		s.nod, s.nodVel = spring(s.nod, s.nodVel, 0, 3.2, dt)
		if s.act then
			s.act = false
			playMove(model, s)
		end
		local lx, lvx = spring(s.lunge.X, s.lungeVel.X, 0, LUNGE_HZ, dt)
		local lz, lvz = spring(s.lunge.Z, s.lungeVel.Z, 0, LUNGE_HZ, dt)
		s.lunge, s.lungeVel = Vector3.new(lx, 0, lz), Vector3.new(lvx, 0, lvz)
		-- face where it is going; standing still, where the hero looks
		local wantYaw = speed > 1.2 and math.atan2(-s.vel.X, -s.vel.Z) or math.atan2(-flat.X, -flat.Z)
		local goal = s.yaw + angleDelta(s.yaw, wantYaw)
		s.yaw, s.yawVel = spring(s.yaw, s.yawVel, goal, TURN_HZ, dt)
		s.pos = Vector3.new(x, s.ground + s.half + lift, z)
		carryBead(s, phase == "back" and model:GetAttribute("CarryColor") or nil, dt)
		s.body.CFrame = CFrame.new(s.pos + s.lunge + side) * CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(tilt + s.nod * 0.12, 0, roll)
	end
end)
