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

local RAD = math.pi / 180
local ZERO = Vector3.zero
-- the rig's bones, by the name used in MonsterMoves (the bone's own name without dots or underscores)
local JOINTS = { "Root", "Hips", "Spine", "Chest", "Neck", "Head", "UpperArmL", "LowerArmL", "HandL", "UpperArmR",
	"LowerArmR", "HandR", "UpperLegL", "LowerLegL", "FootL", "UpperLegR", "LowerLegR", "FootR" }
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

	-- breathing when standing
	local still = 1 - math.min(w, 1)
	local breath = math.sin(now * 2 * math.pi * Moves.Idle.BreathHz + st.breath) * Moves.Idle.BreathDeg * still
	pose.Chest += Vector3.new(breath, 0, 0)

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

	-- the head trails the body on a loose spring (keeps it level against lean and bob)
	local headGoal = -(pose.Root.X + pose.Chest.X) * Moves.HeadLag.Pitch
	st.headX, st.headV = springStep(st.headX, st.headV, headGoal, Moves.HeadLag.Hz, Moves.HeadLag.Damping, dt)
	if not dead then
		pose.Neck += Vector3.new(st.headX, 0, 0)
	end

	-- the hit reaction: a kick away from the hitter, springing back
	local hitAt = model:GetAttribute("HitAt")
	if hitAt ~= st.lastHitAt then
		st.lastHitAt = hitAt
		if hitAt and not dead then
			local from = nearestHero(pivot.Position)
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
	for name, j in st.joints do
		local v = pose[name]
		if v then
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
