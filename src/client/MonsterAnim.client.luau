-- Rigged monsters, animated in code on every player's computer (no animation assets): the bones of an enemy whose
-- Look holds a skinned mesh with the rig's bones (art/blender/rig_monster.py) are driven every frame:
--   * a walk from the distance the monster really travelled (stride per stud, so the feet do not slide):
--     legs swing and the knees lift, arms counter-swing, shoulders turn against the hips, the body sinks as a
--     leg reaches out (straight-leg geometry, so the planted foot stays on the ground), the head lags on a spring
--   * breathing while standing
--   * the attack while the server says it is bashing ("Bashing" attribute), each monster on its own beat
--   * a hit reaction when the server says it was hit ("HitAt" attribute): rocks back from the nearest hero
--   * a fall when it dies ("Dead" attribute; the server removes the body a moment later)
-- Every number lives in src/shared/MonsterMoves.luau. Nothing here changes the game, only the look.
-- The server moves the whole model along the path and leaves the waddle and lean to this script for these models.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Moves = require(ReplicatedStorage.Shared.MonsterMoves)
-- test rigs set this on workspace (on their own computer) to read which foot is down
local DEBUG = false
workspace:GetAttributeChangedSignal("MonsterAnimDebug"):Connect(function()
	DEBUG = workspace:GetAttribute("MonsterAnimDebug") == true
end)

local RAD = math.pi / 180
local ZERO = Vector3.zero
-- the rig's bones, by the name used in MonsterMoves (the bone's own name without dots or underscores)
local JOINTS = { "Root", "Hips", "Spine", "Chest", "Neck", "Head", "UpperArmL", "LowerArmL", "HandL", "UpperArmR",
	"LowerArmR", "HandR", "UpperLegL", "LowerLegL", "FootL", "UpperLegR", "LowerLegR", "FootR",
	-- optional (rig_monster.py adds them when the model has them): a tail of three and a pair of wings
	"Tail1", "Tail2", "Tail3", "WingL", "WingR" }
local NEEDED = { "Root", "Hips", "Chest", "Head", "UpperLegL", "LowerLegL", "FootL", "UpperLegR", "LowerLegR", "FootR" }

-------------------------------------------------------------------------------
-- poses: { [joint] = Vector3 degrees, Drop / Push / Lift = share of height }
-------------------------------------------------------------------------------
local function emptyPose()
	local p = { Drop = 0, Push = 0, Lift = 0 }
	for _, n in JOINTS do
		p[n] = ZERO
	end
	return p
end

local function poseFromKey(key)
	local p = emptyPose()
	p.Drop, p.Push, p.Lift = key.Drop or 0, key.Push or 0, key.Lift or 0
	for _, n in JOINTS do
		local v = key[n]
		if v then
			p[n] = Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0)
		end
	end
	return p
end

local function lerpPose(a, b, w)
	local p = { Drop = a.Drop + (b.Drop - a.Drop) * w, Push = a.Push + (b.Push - a.Push) * w,
		Lift = a.Lift + (b.Lift - a.Lift) * w }
	for _, n in JOINTS do
		p[n] = a[n]:Lerp(b[n], w)
	end
	return p
end

local function addPose(out, p, w)
	out.Drop += p.Drop * w
	out.Push += p.Push * w
	out.Lift += p.Lift * w
	for _, n in JOINTS do
		out[n] += p[n] * w
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

local function clipOf(spec)
	local keys, last = {}, emptyPose()
	for _, key in spec.Keys do
		local pose = key.hold and last or poseFromKey(key)
		table.insert(keys, { t = key.t, ease = EASE[key.ease or "inout"] or EASE.inout, pose = pose })
		last = pose
	end
	return keys
end
local ATTACK = clipOf(Moves.Attack)
local DEATH = clipOf(Moves.Death)
local REST = emptyPose()

local function sample(keys, t)
	local prevT, prevPose = 0, REST
	for _, key in keys do
		if t < key.t then
			local w = (t - prevT) / math.max(1e-3, key.t - prevT)
			return lerpPose(prevPose, key.pose, key.ease(math.clamp(w, 0, 1)))
		end
		prevT, prevPose = key.t, key.pose
	end
	return prevPose
end

-- springs, stepped in small slices so 30 fps moves like 240 fps
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
-- finding rigged monsters
-------------------------------------------------------------------------------
local states = {} -- [model] = state, or false for a model without a rig

local function rigOf(model)
	local look = model:FindFirstChild("Look")
	if not look then
		return nil
	end
	local bones = {}
	for _, d in look:GetDescendants() do
		if d:IsA("Bone") then
			bones[(string.gsub(d.Name, "[^%w]", ""))] = d
		end
	end
	for _, n in NEEDED do
		if not bones[n] then
			return nil
		end
	end
	return bones
end

local function newState(model, bones)
	local _, size = model:FindFirstChild("Look"):GetBoundingBox()
	for _, bone in bones do
		bone.Transform = CFrame.identity
	end
	-- the rig's own frame, from its bones: left is where the left foot is, forward is left x up (the rig was
	-- built facing its front, left +X in Blender); every turn below is given in this frame, whichever way the
	-- model file happens to face inside the enemy model
	local pivot = model:GetPivot()
	local left = pivot:PointToObjectSpace(bones.FootL.WorldPosition) - pivot:PointToObjectSpace(bones.FootR.WorldPosition)
	left = Vector3.new(left.X, 0, left.Z)
	local frame = CFrame.identity
	if left.Magnitude > 1e-3 then
		frame = CFrame.fromMatrix(Vector3.zero, -left.Unit, Vector3.yAxis)
	end
	pivot = pivot * frame
	local st = {
		model = model,
		joints = {},
		height = size.Y,
		lastPos = pivot.Position,
		phase = 0,
		walk = 0,
		walkVel = 0,
		headX = 0,
		headV = 0,
		hit = 0,
		hitVel = 0,
		hitAxis = Vector3.xAxis,
		lastHitAt = model:GetAttribute("HitAt"),
		frame = frame,
		beat = math.random() * Moves.Attack.Every,
		breath = math.random() * 10,
	}
	for name, bone in bones do
		-- the bone's resting frame in the monster's frame (its Transform is still empty here): turns given in the
		-- monster's frame are carried into the bone's own frame through it
		local rel = pivot:ToObjectSpace(bone.WorldCFrame)
		local rot = rel.Rotation
		-- sideways turns swing a limb OUT: the bone's side decides the sign
		local out = (string.sub(name, -1) == "L" or string.sub(name, -1) == "R") and (rel.Position.X >= 0 and 1 or -1) or 1
		st.joints[name] = { bone = bone, rot = rot, inv = rot:Inverse(), out = out, pos = rel.Position }
	end
	-- leg length: hip to foot, from the bones themselves
	local hip, foot = st.joints.UpperLegL, st.joints.FootL or st.joints.LowerLegL
	st.leg = (hip and foot) and math.max(0.2, (hip.pos - foot.pos).Magnitude) or size.Y * 0.3
	return st
end

local function scan()
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		if states[model] == nil and model:IsA("Model") and model:FindFirstChild("Look") then
			local bones = rigOf(model)
			states[model] = bones and newState(model, bones) or false
		end
	end
end

-- the nearest hero to a point (for the direction a hit came from)
local function nearestHero(pos)
	local best, bestD = nil, 30
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestD then
				best, bestD = root.Position, d
			end
		end
	end
	return best
end

-------------------------------------------------------------------------------
-- one monster, one frame
-------------------------------------------------------------------------------
local function animate(st, dt, now)
	local model = st.model
	local pivot = model:GetPivot() * st.frame
	local h = st.height
	local W = Moves.Walk
	local pose = emptyPose()

	-- how far it really moved since last frame (along the ground)
	local delta = pivot.Position - st.lastPos
	st.lastPos = pivot.Position
	local moved = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if moved > h * 3 then
		moved = 0 -- a jump (a blink, a teleport): no stride for it
	end
	local dead = model:GetAttribute("Dead")
	local speed = moved / math.max(dt, 1e-3)
	st.walk, st.walkVel = springStep(st.walk, st.walkVel, (speed > 0.3 and not dead) and 1 or 0, W.Settle.Hz, W.Settle.Damping, dt)
	local w = math.clamp(st.walk, 0, 1.2)

	local gait = Moves.Gaits[model.Name] or Moves.Gaits.Default
	st.down = nil
	if gait == "run" then
		-- the bouncy run: fewer, longer steps with a short hop between them. Each step is a contact (one foot planted,
		-- its leg solved so the foot stays put; the knee gives on landing and straightens to push off) and then a
		-- flight (both feet up, the body on a little arc). The step rate is set in MonsterMoves; the step length
		-- follows the monster's real speed.
		local R = Moves.Run
		st.speedAvg = (st.speedAvg or speed) + (speed - (st.speedAvg or speed)) * math.min(1, dt * 4)
		local stepLen = math.clamp(st.speedAvg / R.StepRate, st.leg * 0.4, st.leg * R.MaxStep)
		st.step = ((st.step or 0) + moved / stepLen) % 2 -- two steps = one cycle of both legs
		local half = R.Contact * 0.5 * stepLen -- the planted foot goes from this far in front of the hip to this far behind
		local function legOf(p) -- p: this leg's place in the cycle, 0..2 steps
			if p < R.Contact then
				-- planted: the hip passes over the foot; the knee gives on landing (squash) and straightens to push off
				local u = p / R.Contact
				local k = R.Squash * math.sin(u * math.pi) * RAD
				local x = half * (1 - 2 * u)
				local reachable = st.leg * math.cos(k / 2)
				local a = math.asin(math.clamp(x / reachable, -1, 1))
				return a, k, true, st.leg * (1 - math.cos(k / 2) * math.cos(a)), u
			end
			-- swung: from behind the hip round to in front of it, knee folded up
			local v = (p - R.Contact) / (2 - R.Contact)
			local back = math.asin(math.clamp(-half / st.leg, -1, 1))
			local front = math.asin(math.clamp(half / st.leg, -1, 1))
			local a = back + (front - back) * (v * v * (3 - 2 * v))
			return a, R.Knee * math.sin(v * math.pi) * RAD, false, nil, v
		end
		local aL, kL, onL, dropL = legOf(st.step)
		local aR, kR, onR, dropR = legOf((st.step + 1) % 2)
		st.down = (w > 0.9 and not dead) and (onL and "L" or onR and "R") or nil
		st.downA = onL and aL or aR
		if DEBUG then
			model:SetAttribute("FootDown", st.down or "") -- (test rigs measure the slide)
		end
		-- thigh = angle + half the knee, shin back by the knee, sole kept level
		pose.UpperLegL = Vector3.new((aL + kL / 2) / RAD * w, 0, 0)
		pose.LowerLegL = Vector3.new(-kL / RAD * w, 0, 0)
		pose.FootL = Vector3.new((kL / 2 - aL) / RAD * w, 0, 0)
		pose.UpperLegR = Vector3.new((aR + kR / 2) / RAD * w, 0, 0)
		pose.LowerLegR = Vector3.new(-kR / RAD * w, 0, 0)
		pose.FootR = Vector3.new((kR / 2 - aR) / RAD * w, 0, 0)
		-- the body: on the planted leg it sits as low as that leg puts it; in the air it follows a little arc
		local within = st.step % 1
		if onL or onR then
			pose.Drop = (onL and dropL or dropR) / h * w
		else
			-- (from the height the leg left the ground at to the height the other lands at: the same, by symmetry)
			local v = (within - R.Contact) / (1 - R.Contact)
			local edge = st.leg * (1 - math.cos(math.asin(math.clamp(half / st.leg, -1, 1)))) / h
			pose.Lift = (R.Hop * 4 * v * (1 - v) - edge) * w
		end
		-- arms pump against the legs, elbows bent; a forward lean
		local s = math.sin(st.step * math.pi)
		local out = W.ArmOut * w + Moves.Idle.ArmOut * (1 - math.min(w, 1))
		pose.UpperArmL = Vector3.new(-R.ArmPump * s * w, 0, out)
		pose.UpperArmR = Vector3.new(R.ArmPump * s * w, 0, out)
		pose.LowerArmL = Vector3.new(R.Elbow * w, 0, 0)
		pose.LowerArmR = Vector3.new(R.Elbow * w, 0, 0)
		pose.Chest = Vector3.new(0, W.ChestTwist * s * w, 0)
		pose.Root = Vector3.new(R.Lean * w, 0, 0)
		-- (the head trails the bob on its spring below)
		local lift = (pose.Lift - pose.Drop) * h
		st.headBob = (lift - (st.lastLift or lift)) / math.max(dt, 1e-3)
		st.lastLift = lift
	else
		-- the walk, from the distance really travelled. Each foot is planted for half the cycle and swung for the other
		-- half. While planted, its leg angle is solved from where the foot must stay (asin of its offset from the hip),
		-- so the foot does not slide; the hips sink by the straight-leg geometry of the planted leg. One cycle = two
		-- steps of 2 x leg x sin(Swing).
		local stride = 2 * st.leg * math.sin(W.Swing * RAD)
		st.phase = (st.phase + moved / math.max(2 * stride, 0.05)) % 1
		local function leg(p)
			local x, knee, planted
			if p < 0.5 then
				x = stride * (0.5 - p / 0.5) -- planted: from in front of the hip to behind it
				knee, planted = 0, true
			else
				local v = (p - 0.5) / 0.5
				x = stride * (-0.5 + v * v * (3 - 2 * v)) -- swung forward again, lifting the knee
				knee, planted = math.sin(v * math.pi), false
			end
			return math.asin(math.clamp(x / st.leg, -1, 1)), knee, planted
		end
		local aL, kL, pL = leg(st.phase)
		local aR, kR = leg((st.phase + 0.5) % 1)
		local s = math.sin(st.phase * 2 * math.pi)
		pose.UpperLegL = Vector3.new(aL / RAD * w, 0, 0)
		pose.UpperLegR = Vector3.new(aR / RAD * w, 0, 0)
		pose.LowerLegL = Vector3.new(-W.Knee * kL * w, 0, 0)
		pose.LowerLegR = Vector3.new(-W.Knee * kR * w, 0, 0)
		pose.FootL = Vector3.new(-aL / RAD * w, 0, 0) -- (the sole stays flat)
		pose.FootR = Vector3.new(-aR / RAD * w, 0, 0)
		local out = W.ArmOut * w + Moves.Idle.ArmOut * (1 - math.min(w, 1))
		pose.UpperArmL = Vector3.new(-W.ArmSwing * s * w, 0, out)
		pose.UpperArmR = Vector3.new(W.ArmSwing * s * w, 0, out)
		pose.Chest = Vector3.new(0, W.ChestTwist * s * w, 0)
		pose.Root = Vector3.new(W.Lean * w, 0, 0)
		-- the planted leg leaning out lowers the hips: sink by exactly that so the planted foot stays on the ground
		local planted = (pL and aL or aR) * w
		pose.Drop = st.leg * (1 - math.cos(planted)) / h

	end

	-- breathing when standing
	local still = 1 - math.min(w, 1)
	local breath = math.sin(now * 2 * math.pi * Moves.Idle.BreathHz + st.breath) * Moves.Idle.BreathDeg * still
	pose.Chest += Vector3.new(breath, 0, 0)

	-- a tail swishes from side to side, each bone a little later than the one before; wings beat (only on rigs
	-- that have them)
	if st.joints.Tail1 then
		local T = Moves.Tail
		for n = 1, 3 do
			local a = math.sin(now * 2 * math.pi * T.Hz + st.breath - n * T.Lag) * T.Sway * (1 + 0.6 * math.min(w, 1))
			pose["Tail" .. n] = Vector3.new(T.Lift * (n == 1 and 1 or 0), a, 0)
		end
	end
	if st.joints.WingL then
		local F = Moves.Wings
		local beat = math.sin(now * 2 * math.pi * F.Hz + st.breath) * F.Flap
		pose.WingL = Vector3.new(0, 0, F.Open + beat)
		pose.WingR = Vector3.new(0, 0, F.Open + beat)
	end

	-- the attack while bashing, on this monster's own beat
	if model:GetAttribute("Bashing") and not dead then
		local t = (now + st.beat) % Moves.Attack.Every
		addPose(pose, sample(ATTACK, t), 1)
	end

	-- the fall
	if dead then
		st.deadAt = st.deadAt or now
		pose = sample(DEATH, now - st.deadAt)
	end

	-- the legs hang from the leaning body: lean them back by the same amount, so a lean does not swing the feet
	-- (a 10 degree run lean made the planted foot slide)
	if not dead then
		local back = Vector3.new(-pose.Root.X, 0, 0)
		pose.UpperLegL += back
		pose.UpperLegR += back
	end

	-- the head trails the body on a loose spring (keeps it level against lean and bob)
	local headGoal = -(pose.Root.X + pose.Chest.X) * Moves.HeadLag.Pitch + (st.headBob or 0) * Moves.HeadLag.PerBob
	st.headX, st.headV = springStep(st.headX, st.headV, headGoal, Moves.HeadLag.Hz, Moves.HeadLag.Damping, dt)
	if not dead then
		pose.Neck += Vector3.new(st.headX, 0, 0)
	end

	-- the hit reaction: a kick away from the hitter, springing back
	local hitAt = model:GetAttribute("HitAt")
	if hitAt ~= st.lastHitAt then
		st.lastHitAt = hitAt
		if hitAt and not dead then
			-- away from where the blow came from (the server says: hero, tower, blast), else from the nearest hero
			local fx, fz = model:GetAttribute("HitFromX"), model:GetAttribute("HitFromZ")
			local from = (fx and fz) and Vector3.new(fx, pivot.Position.Y, fz) or nearestHero(pivot.Position)
			local away = from and (pivot.Position - from) or -pivot.LookVector
			away = pivot:VectorToObjectSpace(Vector3.new(away.X, 0, away.Z))
			if away.Magnitude < 1e-3 then
				away = Vector3.zAxis
			end
			st.hitAxis = Vector3.yAxis:Cross(away.Unit) -- turning about this tips the top away from the hitter
			st.hit, st.hitVel = Moves.Hit.Deg, 0
		end
	end
	st.hit, st.hitVel = springStep(st.hit, st.hitVel, 0, Moves.Hit.Hz, Moves.Hit.Damping, dt)

	-- write the bones
	local function write(name, j, v)
		local r = CFrame.fromEulerAnglesYXZ(v.X * RAD, v.Y * RAD * j.out, v.Z * RAD * j.out)
		if name == "Root" then
			if math.abs(st.hit) > 0.01 then
				r = CFrame.fromAxisAngle(st.hitAxis, st.hit * RAD) * r
			end
			local move = Vector3.new(0, (pose.Lift - pose.Drop) * h, -pose.Push * h)
			j.bone.Transform = CFrame.new(j.inv * move) * (j.inv * r * j.rot)
		else
			j.bone.Transform = j.inv * r * j.rot
		end
	end
	for name, j in st.joints do
		local v = pose[name]
		if v then
			write(name, j, v)
		end
	end

	-- the planted foot, where it really ended up: the leg solve assumes an ideal leg, the real one is a little
	-- slanted and uneven, which let the foot creep (0.09 studs a contact). Turn the planted leg by what is left so
	-- the foot sits on the spot it landed on (one correction step, in the same frame).
	if st.down then
		local side = st.down
		local foot = st.joints["Foot" .. side]
		local p = foot.bone.TransformedWorldCFrame.Position
		if side ~= st.plantSide or not st.plantPos then
			st.plantSide, st.plantPos = side, p
		else
			local fwd = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
			local right = Vector3.new(pivot.RightVector.X, 0, pivot.RightVector.Z)
			if fwd.Magnitude > 1e-3 and right.Magnitude > 1e-3 then
				-- along the walk: swing the thigh; across it (the body turning at a corner): swing the leg out or in
				local err = (p - st.plantPos):Dot(fwd.Unit)
				local fix = math.clamp(-err / (st.leg * math.max(0.4, math.cos(st.downA or 0))) / RAD, -12, 12)
				local thigh = "UpperLeg" .. side
				local errSide = (p - st.plantPos):Dot(right.Unit)
				local fixSide = math.clamp(-errSide / st.leg / RAD * st.joints[thigh].out, -15, 15)
				write(thigh, st.joints[thigh], pose[thigh] + Vector3.new(fix, 0, fixSide))
				write("Foot" .. side, foot, pose["Foot" .. side] - Vector3.new(fix, 0, fixSide))
			end
		end
	else
		st.plantSide, st.plantPos = nil, nil
	end

	-- (test rigs: how far the planted foot moved over the ground this frame, read right after posing it)
	if DEBUG then
		local down = model:GetAttribute("FootDown")
		local foot = (down == "L" and st.joints.FootL) or (down == "R" and st.joints.FootR)
		local p = foot and foot.bone.TransformedWorldCFrame.Position
		if p and down == st.lastDown and st.lastFoot then
			local d = Vector3.new(p.X - st.lastFoot.X, 0, p.Z - st.lastFoot.Z).Magnitude
			st.contactSlide = (st.contactSlide or 0) + d
		elseif down ~= st.lastDown and st.lastDown and st.lastDown ~= "" then
			model:SetAttribute("SlideContacts", (model:GetAttribute("SlideContacts") or 0) + 1)
			model:SetAttribute("SlideTotal", (model:GetAttribute("SlideTotal") or 0) + (st.contactSlide or 0))
			model:SetAttribute("SlideWorst", math.max(model:GetAttribute("SlideWorst") or 0, st.contactSlide or 0))
			st.contactSlide = 0
		end
		st.lastDown, st.lastFoot = down, p
	end
end

-------------------------------------------------------------------------------
local nextScan = 0
RunService.RenderStepped:Connect(function(dt)
	dt = math.clamp(dt, 1 / 240, 1 / 15)
	local now = os.clock()
	if now >= nextScan then
		nextScan = now + 0.4
		scan()
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for model, st in states do
		if not model.Parent then
			states[model] = nil
		elseif st then
			if eye and (model:GetPivot().Position - eye).Magnitude > Moves.Far then
				st.lastPos = model:GetPivot().Position -- (no stride for the distance walked out of sight)
			else
				animate(st, dt, now)
			end
		end
	end
end)
