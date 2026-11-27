-- Hero animation, all in code (no animation assets), played on every player's computer for every hero.
-- On top of Roblox's own walk and idle it adds:
--   * moves: each ability press (the "...ReadyAt" attributes every computer can see) plays a full-body move from
--     src/shared/HeroMoves.luau: wind-up, lunge, contact, a short freeze on impact (hit-stop) with an arm shudder,
--     follow-through and a recovery that overshoots and settles. Sword presses chain into a three-hit combo.
--   * a ready stance after fighting, a flinch when hurt, and a knock-out fall when the hero dies
--   * life that is always on: lean into running and turns (springs), shoulders turning against the stride,
--     breathing, and the head and free arm trailing the body a little (overlap)
-- The legs bend whenever the body crouches or lunges, so the feet stay on the ground.
-- Every number lives in HeroMoves; this file only plays them. Nothing here changes the game, only the look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HeroMoves = require(ReplicatedStorage.Shared.HeroMoves)
local Life = HeroMoves.Life

local JOINTS = {
	-- our name = { part, joint }
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RHip = { "RightUpperLeg", "RightHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
}
local POSE_JOINTS = { "Root", "Waist", "Neck", "RShoulder", "RElbow", "LShoulder", "LElbow", "RHip", "RKnee", "LHip", "LKnee" }
local ZERO = Vector3.zero
local RAD = math.pi / 180

-------------------------------------------------------------------------------
-- poses: { [joint] = Vector3 degrees, Drop = studs, Push = studs }
-------------------------------------------------------------------------------
local function emptyPose()
	local p = { Drop = 0, Push = 0, Fall = 0 }
	for _, name in POSE_JOINTS do
		p[name] = ZERO
	end
	return p
end

local function poseFromKey(key)
	local p = emptyPose()
	p.Drop = key.Drop or 0
	p.Push = key.Push or 0
	p.Fall = key.Fall or 0
	for _, name in POSE_JOINTS do
		local v = key[name]
		if v then
			p[name] = Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0)
		end
	end
	return p
end

local function lerpPose(a, b, w)
	local p = { Drop = a.Drop + (b.Drop - a.Drop) * w, Push = a.Push + (b.Push - a.Push) * w,
		Fall = a.Fall + (b.Fall - a.Fall) * w }
	for _, name in POSE_JOINTS do
		p[name] = a[name]:Lerp(b[name], w)
	end
	return p
end

-- out += p * w
local function addPose(out, p, w)
	out.Drop += p.Drop * w
	out.Push += p.Push * w
	out.Fall += p.Fall * w
	for _, name in POSE_JOINTS do
		out[name] += p[name] * w
	end
end

local EASE = {
	out = function(k)
		return 1 - (1 - k) ^ 3
	end,
	inout = function(k)
		return k * k * (3 - 2 * k)
	end,
	["in"] = function(k)
		return k * k * k
	end,
	back = function(k)
		local c = 1.7
		return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
	end,
}

-- each clip's keys turned into full poses once ("hold" copies the pose before it)
local clips = {}
for name, clip in HeroMoves.Clips do
	local keys = {}
	local last = emptyPose()
	for _, key in clip.Keys do
		local pose = key.hold and last or poseFromKey(key)
		table.insert(keys, { t = key.t, ease = EASE[key.ease or "inout"] or EASE.inout, pose = pose })
		last = pose
	end
	clips[name] = { keys = keys, length = keys[#keys].t, shudder = clip.Shudder }
end

-- the pose of a clip `t` seconds after it started from pose `from`; second value true once it has ended
local function sample(clip, from, t)
	local prevT, prevPose = 0, from
	for _, key in clip.keys do
		if t < key.t then
			local w = (t - prevT) / math.max(1e-3, key.t - prevT)
			return lerpPose(prevPose, key.pose, key.ease(math.clamp(w, 0, 1))), false
		end
		prevT, prevPose = key.t, key.pose
	end
	return prevPose, true
end

-- a pose to start a new clip from: a turn already made (a spin ends at -360) counts as no turn
local function wrapped(pose)
	local p = table.clone(pose)
	local r = p.Root
	p.Root = Vector3.new(r.X, (r.Y + 180) % 360 - 180, r.Z)
	return p
end

-------------------------------------------------------------------------------
-- springs, stepped in small slices so 30 fps moves like 240 fps
-------------------------------------------------------------------------------
local function springStep(x, v, goal, hz, damping, dt)
	local w = 2 * math.pi * hz
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	for _ = 1, steps do
		v += ((goal - x) * w * w - v * 2 * damping * w) * h
		x += v * h
	end
	return x, v
end

-------------------------------------------------------------------------------
-- per-character state
-------------------------------------------------------------------------------
local states = {} -- [character] = state
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function findJoints(character)
	local found = {}
	for name, spec in JOINTS do
		local part = character:FindFirstChild(spec[1])
		local joint = part and part:FindFirstChild(spec[2])
		-- Motor6D on classic bodies, AnimationConstraint on bodies with Roblox's upgraded joints (new places use
		-- them by default: with Motor6D only, the hero did not move at all, 2026-11-25). Both have a Transform.
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			found[name] = joint
		end
	end
	return found
end

-- where a joint sits on its parent part (C0) and on its own part (C1): Motor6D has them, an AnimationConstraint
-- has them as its two attachments
local function c0(joint)
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	return joint.Attachment0 and joint.Attachment0.CFrame or CFrame.identity
end
local function c1(joint)
	if joint:IsA("Motor6D") then
		return joint.C1
	end
	return joint.Attachment1 and joint.Attachment1.CFrame or CFrame.identity
end

-- leg lengths from the joints themselves: thigh (hip to knee) and shin (knee to ankle)
local function legLength(j, hip, knee, ankle)
	local h, k, a = j[hip], j[knee], j[ankle]
	if not (h and k and a) then
		return { 1, 1 }
	end
	return { (c0(k).Position - c1(h).Position).Magnitude, (c0(a).Position - c1(k).Position).Magnitude }
end

local function stateOf(character)
	local st = states[character]
	if st then
		return st
	end
	st = {
		character = character,
		joints = {},
		nextLook = 0,
		written = {}, -- [joint] = { value, delta }: what we wrote last frame, to undo it if nothing reset it
		action = nil, -- { clip, start, from, name }
		actionPose = emptyPose(),
		react = nil,
		reactPose = emptyPose(),
		stance = 0,
		stanceVel = 0,
		lastMove = -100,
		combo = 0,
		lean = 0, leanVel = 0,
		bank = 0, bankVel = 0,
		speed = 0,
		yaw = nil,
		follow = {}, -- [joint] = { x, v }
		dead = false,
		phase = math.random() * 10,
	}
	states[character] = st
	return st
end

local function play(st, name, layer)
	local clip = clips[name]
	if not clip then
		return
	end
	if layer == "react" then
		st.react = { clip = clip, start = os.clock(), from = wrapped(st.reactPose), name = name }
	else
		st.action = { clip = clip, start = os.clock(), from = wrapped(st.actionPose), name = name }
		st.lastMove = os.clock()
	end
end

local function watchCharacter(player, character)
	local st = stateOf(character)
	st.player = player
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or states[character] ~= st then
		return
	end
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(new)
		if new < health - 0.5 and new > 0 and not st.dead then
			play(st, "hurt", "react")
		end
		health = new
	end)
	humanoid.Died:Connect(function()
		st.dead = true
		st.react = nil
		-- pin the body where it stands at once (the server does too, but its pin arrives a moment later: in between
		-- the dead body tipped over as one piece and sank into the ground, 2026-11-25)
		local r = character:FindFirstChild("HumanoidRootPart")
		if r then
			r.Anchored = true
		end
		-- upgraded joints go limp on death: keep them driven so the fall below plays (the server does the same)
		for _, joint in character:GetDescendants() do
			if joint:IsA("AnimationConstraint") then
				joint.IsKinematic = true
				joint.Enabled = true
			end
		end
		play(st, "death", "action")
	end)
end

local function watch(player)
	for _, attr in { "AttackReadyAt", "WhirlwindReadyAt", "LeapReadyAt" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			local ready = player:GetAttribute(attr) or 0
			if ready <= workspace:GetServerTimeNow() then
				return -- a reset, not a new move
			end
			local character = player.Character
			if not character then
				return
			end
			local st = stateOf(character)
			if st.dead then
				return
			end
			local moves = HeroMoves.Moves[player:GetAttribute("HeroId") or "Swordmaster"] or HeroMoves.Moves.Swordmaster
			local move = moves[attr]
			if type(move) == "table" then
				-- a combo: the next one if pressed soon after the last, otherwise the first again
				local now = os.clock()
				if st.lastCombo and now - st.lastCombo < HeroMoves.ComboWindow then
					st.combo = st.combo % #move + 1
				else
					st.combo = 1
				end
				st.lastCombo = now
				move = move[st.combo]
			end
			play(st, move, "action")
		end)
	end
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
end
for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)

-------------------------------------------------------------------------------
-- writing to the joints, on top of whatever Roblox's animator put there this frame
-------------------------------------------------------------------------------
-- the joint's pose before our own change: if nothing reset it since last frame, take our change back out first
local function baseOf(st, joint)
	local rec = st.written[joint]
	local t = joint.Transform
	if rec and t:FuzzyEq(rec.value, 1e-5) then
		return t * rec.delta:Inverse()
	end
	return t
end

local function write(st, joint, delta)
	local base = baseOf(st, joint)
	local value = base * delta
	joint.Transform = value
	local rec = st.written[joint]
	if rec then
		rec.value, rec.delta = value, delta
	else
		st.written[joint] = { value = value, delta = delta }
	end
end

local function turn(v) -- degrees → rotation
	return CFrame.fromEulerAnglesYXZ(v.X * RAD, v.Y * RAD, v.Z * RAD)
end

local function animate(st, dt, now)
	local character = st.character
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if now >= st.nextLook then
		st.nextLook = now + 1
		st.joints = findJoints(character)
		st.legR = legLength(st.joints, "RHip", "RKnee", "RAnkle")
		st.legL = legLength(st.joints, "LHip", "LKnee", "LAnkle")
	end
	local j = st.joints
	if not j.Root then
		return
	end
	local scale = character:GetScale()

	-- the move and the flinch
	if st.action then
		local pose, done = sample(st.action.clip, st.action.from, now - st.action.start)
		st.actionPose = pose
		if done and not st.dead then
			st.action = nil
		end
	else
		st.actionPose = emptyPose()
	end
	if st.react then
		local pose, done = sample(st.react.clip, st.react.from, now - st.react.start)
		st.reactPose = pose
		if done then
			st.react = nil
		end
	else
		st.reactPose = emptyPose()
	end
	local pose = emptyPose()
	addPose(pose, st.actionPose, 1)
	addPose(pose, st.reactPose, 1)

	-- running: speed, lean and bank (springs), the ready stance after a fight
	local v = root.AssemblyLinearVelocity
	local look = root.CFrame.LookVector
	local flat = Vector3.new(v.X, 0, v.Z)
	local forward = flat:Dot(Vector3.new(look.X, 0, look.Z).Unit)
	local accel = (forward - st.speed) / math.max(dt, 1 / 240)
	st.speed = forward
	local yaw = math.atan2(-look.X, -look.Z)
	local yawRate = 0
	if st.yaw then
		yawRate = ((yaw - st.yaw + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1 / 240)
	end
	st.yaw = yaw
	local leanGoal = -math.clamp(forward * Life.LeanPerSpeed + math.clamp(accel, -60, 60) * Life.LeanPerAccel,
		-Life.LeanMax * 0.5, Life.LeanMax)
	local bankGoal = math.clamp(yawRate / RAD * Life.BankPerTurn, -Life.BankMax, Life.BankMax) * math.clamp(flat.Magnitude / 12, 0, 1)
	if st.dead then
		leanGoal, bankGoal = 0, 0
	end
	st.lean, st.leanVel = springStep(st.lean, st.leanVel, leanGoal, Life.LeanSpring.Hz, Life.LeanSpring.Damping, dt)
	st.bank, st.bankVel = springStep(st.bank, st.bankVel, bankGoal, Life.LeanSpring.Hz, Life.LeanSpring.Damping, dt)
	pose.Root += Vector3.new(st.lean, 0, st.bank)

	local heroId = st.player and st.player:GetAttribute("HeroId") or "Swordmaster"
	local stance = HeroMoves.Stance[heroId]
	local moving = flat.Magnitude > 2
	local fighting = now - st.lastMove < HeroMoves.CombatStance
	local stanceGoal = (fighting and not st.action and not st.dead) and (moving and HeroMoves.StanceWhileWalking or 1) or 0
	st.stance, st.stanceVel = springStep(st.stance, st.stanceVel, stanceGoal, 4, 0.8, dt)
	if stance and math.abs(st.stance) > 1e-3 then
		addPose(pose, poseFromKey(stance), st.stance)
	end

	-- shoulders against the stride (read from the walk's own hip swing), breathing when standing
	if j.RHip and not st.dead then
		local hipX = baseOf(st, j.RHip):ToEulerAnglesXYZ()
		local counter = math.clamp(-hipX / RAD * Life.ShoulderCounter, -Life.ShoulderCounterMax, Life.ShoulderCounterMax)
		pose.Waist += Vector3.new(0, counter, 0)
	end
	if not moving and not st.dead then
		local breath = math.sin(now * 2 * math.pi * Life.BreathHz + st.phase) * Life.BreathDeg
		pose.Waist += Vector3.new(breath, 0, 0)
		pose.Neck += Vector3.new(-breath * 0.5, 0, 0)
	end

	-- the shudder on impact
	local action = st.action
	local shudder = action and action.clip.shudder
	if shudder then
		local t = now - action.start
		if t >= shudder.From and t <= shudder.To then
			local s = math.sin(t * HeroMoves.ShudderHz * 2 * math.pi) * shudder.Deg
			pose[shudder.Joint] += Vector3.new(s, 0, s * 0.5)
		end
	end

	-- overlap: the head and free arm follow what is asked of them on a loose spring
	for _, name in Life.Follow.Joints do
		local f = st.follow[name]
		if not f then
			f = { x = pose[name], v = ZERO }
			st.follow[name] = f
		end
		f.x, f.v = springStep(f.x, f.v, pose[name], Life.Follow.Hz, Life.Follow.Damping, dt)
		pose[name] = f.x
	end

	-- the body: crouch and lunge move the hips; the legs bend so the feet stay where they were
	local drop = pose.Drop * scale
	local push = pose.Push * scale

	-- the knock-out fall: the whole body tips over backwards on the (anchored) root part, about a line under the
	-- hips at the height of half the body's depth, so it lies on its back on the ground. Turning the Root joint
	-- instead did not tip the body once the hero was dead (upgraded joints, 2026-11-25). Only this computer's view.
	if st.dead and root.Anchored then
		if not st.fallBase then
			params.FilterDescendantsInstances = { character }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
			st.fallBase = root.CFrame
			st.fallGround = hit and hit.Position.Y or (root.Position.Y - 3 * scale)
			-- the ground behind can rise (a bank, a step) or drop: tip over only as far as it allows, so the head
			-- and back rest on it instead of in it (a fall into a grass bank buried the head, 2026-11-25)
			local back = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			local slope = -math.huge
			for d = 1, 5 do
				local at = root.Position + back * d * scale
				local g = workspace:Raycast(at + Vector3.new(0, 4 * scale, 0), Vector3.new(0, -14 * scale, 0), params)
				if g then
					slope = math.max(slope, math.atan2(g.Position.Y - st.fallGround, d * scale))
				end
			end
			st.fallScale = slope > -math.huge and math.clamp((90 - math.deg(slope)) / 90, 0.5, 1.15) or 1
		end
		local base = st.fallBase
		local pivot = Vector3.new(base.Position.X, st.fallGround + HeroMoves.FallPivot * scale, base.Position.Z)
		root.CFrame = CFrame.new(pivot) * CFrame.fromAxisAngle(base.RightVector, pose.Fall * st.fallScale * RAD)
			* CFrame.new(-pivot) * base
	end
	write(st, j.Root, CFrame.new(0, -drop, -push) * turn(pose.Root))
	for _, name in { "Waist", "Neck", "RShoulder", "RElbow", "LShoulder", "LElbow" } do
		if j[name] then
			write(st, j[name], turn(pose[name]))
		end
	end
	for _, side in { "R", "L" } do
		local hip, knee, ankle = j[side .. "Hip"], j[side .. "Knee"], j[side .. "Ankle"]
		if hip and knee then
			local leg = side == "R" and st.legR or st.legL
			local l1, l2 = leg[1] * scale, leg[2] * scale
			local len = l1 + l2
			local hipTurn = pose[side .. "Hip"] * RAD
			local kneeTurn = pose[side .. "Knee"] * RAD
			-- the legs lean back against the body's lean and lunge, so the feet do not swing forward with it
			local lunge = math.atan2(push, len)
			local back = -pose.Root.X * RAD - lunge
			-- a crouch of `drop`: thigh forward by a, shin back by 2a, foot level again. a is solved on the leg as
			-- the walk and idle already bent it (about 30 degrees at the knee): assuming a straight leg lifted the
			-- feet off the ground in the ready stance, 2026-11-25
			local thigh0 = baseOf(st, hip):ToEulerAnglesYXZ() + hipTurn.X
			local bend0 = baseOf(st, knee):ToEulerAnglesYXZ() + kneeTurn.X
			local function reach(add)
				local th = thigh0 + add - lunge
				return l1 * math.cos(th) + l2 * math.cos(th + bend0 - 2 * add)
			end
			local goal = l1 * math.cos(thigh0) + l2 * math.cos(thigh0 + bend0) - math.max(drop, 0)
			local lo, hi = 0, 1.4
			for _ = 1, 16 do
				local mid = (lo + hi) / 2
				if reach(mid) > goal then
					lo = mid
				else
					hi = mid
				end
			end
			local a = (lo + hi) / 2
			write(st, hip, CFrame.fromEulerAnglesYXZ(hipTurn.X + a + back, hipTurn.Y, hipTurn.Z - pose.Root.Z * RAD))
			write(st, knee, CFrame.fromEulerAnglesYXZ(kneeTurn.X - 2 * a, kneeTurn.Y, kneeTurn.Z))
			if ankle then
				write(st, ankle, CFrame.Angles(a + lunge, 0, 0))
			end
		end
	end
end

-- after Roblox's animator has posed the body each frame, add ours on top
local FAR = 180 -- beyond this a hero is not animated (too small to see on a phone)
RunService.Stepped:Connect(function(_, dt)
	dt = math.clamp(dt, 1 / 240, 1 / 15)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for character, st in states do
		if not character.Parent then
			states[character] = nil
			continue
		end
		local root = character.PrimaryPart
		if eye and root and (root.Position - eye).Magnitude > FAR then
			continue
		end
		animate(st, dt, now)
	end
end)
