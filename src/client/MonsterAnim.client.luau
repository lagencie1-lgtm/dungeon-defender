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
	"Tail1", "Tail2", "Tail3", "WingL", "WingR", "HemF", "HemB", "HemL", "HemR",
	-- a slime (rig_monster.py "slime"): a column of body bones and four bulges
	"Body1", "Body2", "Body3", "Top", "BulgeF", "BulgeB", "BulgeL", "BulgeR" }
local NEEDED = { "Root", "Hips", "Chest", "Head" } -- (legs are optional: a robe or a ghost floats on hem bones)

-------------------------------------------------------------------------------
-- poses: { [joint] = Vector3 degrees, Drop / Push / Lift = share of height }
-------------------------------------------------------------------------------
local function emptyPose()
	local p = { Drop = 0, Push = 0, Lift = 0, Moves = {} }
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
		Lift = a.Lift + (b.Lift - a.Lift) * w, Moves = {} }
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
local HITRECOIL = clipOf(Moves.HitRecoil)
local SLAM = clipOf(Moves.Slam)
local SUMMON = clipOf(Moves.Summon)
local CHARGE = clipOf(Moves.Charge)
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
	if bones.Root and bones.Body1 and bones.Top then
		return bones -- a slime
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
	local l = bones.FootL or bones.UpperArmL or bones.HemL or bones.BulgeL
	local r = bones.FootR or bones.UpperArmR or bones.HemR or bones.BulgeR
	local left = (l and r) and (pivot:PointToObjectSpace(l.WorldPosition) - pivot:PointToObjectSpace(r.WorldPosition))
		or Vector3.xAxis
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
	-- how far the foot rests in front of (+) or behind (-) the hip, as an angle seen from the side: the walk swings
	-- the leg about that rest angle (an imp's legs rest slanted; solving them as if straight down sank its feet)
	st.legB = 0
	st.legS = st.leg
	if hip and foot then
		local d = foot.pos - hip.pos
		st.legB = math.atan2(-d.Z, math.max(1e-3, -d.Y))
		st.legS = math.max(0.2, Vector3.new(0, d.Y, d.Z).Magnitude)
	end
	-- half the stance (hip to hip across): a turn on the spot moves each foot by about this times the angle
	local fl, fr = st.joints.FootL, st.joints.FootR
	st.stance = (fl and fr) and math.abs(fl.pos.X - fr.pos.X) * 0.5 or 0
	if DEBUG then
		model:SetAttribute("LegRest", string.format("%.1f deg, %.2f studs", math.deg(st.legB), st.legS))
	end
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
	-- moving backwards (a knockback): the legs step backwards, instead of a planted foot sliding back with the body
	local flat = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	local stepped = (flat.Magnitude > 1e-3 and delta:Dot(flat.Unit) < -0.5 * moved) and -moved or moved
	-- turning on the spot (to face a hero it bashes, a corner) swings the planted foot round with the body: count the
	-- turn as steps so the legs step round instead of the feet sliding
	if flat.Magnitude > 1e-3 then
		local last = st.lastFlat or flat.Unit
		local turn = math.acos(math.clamp(last:Dot(flat.Unit), -1, 1)) * (st.stance or 0)
		st.lastFlat = flat.Unit
		st.lastTurn = turn
		if turn < h then
			-- (counted 4 times over for the stride: a big boss rounding a corner must take quicker steps, or the planted
			-- foot is swung round further than its leg can reach, 1.6-2.6 studs in round 3)
			stepped += turn * 4
			moved += turn
		end
	end
	local speed = moved / math.max(dt, 1e-3)
	-- a boss winding up a tell stands: the legs leave the stride quickly, so the crouch bends straight legs (a stride
	-- under the crouch pushed the feet into the ground)
	local telling = (st.slamStart and now - st.slamStart < Moves.Slam.Length) or model:GetAttribute("Tell") == "charge"
	if telling then
		st.walk *= math.exp(-dt * 12)
		st.walkVel = 0
		speed = 0
	end
	-- (the server's moves reach this computer at its network rate, so at 60 fps every other frame moves 0: the walk
	-- decides on the speed over the last ~0.15 s, else it sat at half a stride and the feet never planted)
	st.speedAvg2 = (st.speedAvg2 or speed) + (speed - (st.speedAvg2 or speed)) * math.min(1, dt * 7)
	if telling then
		st.speedAvg2 = 0
	end
	st.walk, st.walkVel = springStep(st.walk, st.walkVel, (st.speedAvg2 > 0.3 and not dead) and 1 or 0, W.Settle.Hz, W.Settle.Damping, dt)
	local w = math.clamp(st.walk, 0, 1.2)

	local gait = st.joints.Body1 and "hop" or st.joints.UpperLegL and (Moves.Gaits[model.Name] or Moves.Gaits.Default)
		or "float"
	st.down = nil
	if gait == "hop" then
		-- a slime moves in hops, from the distance it really travelled: it squashes (the column sinks, the sides
		-- bulge out), springs up tall and thin, flies a little arc, and squashes again on landing. A wobble on top.
		local S = Moves.Hop
		local hopLen = math.max(0.5, h * S.Length)
		st.hop = ((st.hop or 0) + moved / hopLen) % 1
		local p = st.hop
		local squash -- + = squashed, - = stretched
		if w < 0.2 then
			squash = math.sin(now * 2 * math.pi * Moves.Idle.BreathHz + st.breath) * S.Breathe -- standing: it breathes
		elseif p < S.Ground then
			-- on the ground: land squashed, then push off
			local u = p / S.Ground
			squash = math.cos(u * math.pi * 0.5) * S.Squash * w
			if u > 0.65 then
				squash = -S.Stretch * (u - 0.65) / 0.35 * w
			end
		else
			local v = (p - S.Ground) / (1 - S.Ground)
			pose.Lift = S.Height * 4 * v * (1 - v) * w
			squash = -S.Stretch * (1 - v) * w + S.Squash * math.max(0, v - 0.85) / 0.15 * w * 0.5
		end
		st.squash, st.squashVel = springStep(st.squash or 0, st.squashVel or 0, squash, S.Spring.Hz, S.Spring.Damping, dt)
		local q = st.squash
		pose.Moves.Body2 = Vector3.new(0, -q * 0.35, 0)
		pose.Moves.Body3 = Vector3.new(0, -q * 0.3, 0)
		pose.Moves.Top = Vector3.new(0, -q * 0.35, 0)
		local out = q * S.Bulge
		pose.Moves.BulgeF = Vector3.new(0, 0, -out)
		pose.Moves.BulgeB = Vector3.new(0, 0, out)
		pose.Moves.BulgeL = Vector3.new(-out, 0, 0)
		pose.Moves.BulgeR = Vector3.new(out, 0, 0)
		local wob = math.sin(now * 2 * math.pi * S.WobbleHz + st.breath) * S.Wobble
		pose.Body3 = Vector3.new(S.Lean * w, wob, 0)
		pose.Top = Vector3.new(S.Lean * w * 0.5, wob, 0)
	elseif gait == "float" then
		-- no legs (a ghost, a robe): it bobs as it glides, leans into the glide, and the hem trails behind and sways
		local F = Moves.Float
		local bob = math.sin(now * 2 * math.pi * F.BobHz + st.breath)
		pose.Lift = F.Bob * (bob + 1) * 0.5
		pose.Root = Vector3.new(F.Lean * w, 0, F.Roll * math.sin(now * 2 * math.pi * F.BobHz * 0.5 + st.breath))
		local trail = F.Trail * w
		local sway = math.sin(now * 2 * math.pi * F.SwayHz + st.breath) * F.Sway
		pose.HemF = Vector3.new(trail + sway * 0.5, 0, 0)
		pose.HemB = Vector3.new(trail + sway * 0.5, 0, 0)
		pose.HemL = Vector3.new(0, sway, 0)
		pose.HemR = Vector3.new(0, sway, 0)
		local out = Moves.Idle.ArmOut + F.ArmDrift * bob
		pose.UpperArmL = Vector3.new(F.ArmForward * w, 0, out)
		pose.UpperArmR = Vector3.new(F.ArmForward * w, 0, out)
	elseif gait == "fly" then
		-- the low flight (MonsterMoves.Fly): up off the ground while moving, a bob on each wing beat, legs trailing
		local Fy = Moves.Fly
		local k = math.min(w, 1)
		local bob = math.sin((st.wingPh or 0) - math.pi / 2)
		pose.Lift = (Fy.Hover + Fy.Bob * (bob + 1) * 0.5) * k
		pose.Root = Vector3.new(Fy.Lean * k, 0, 0)
		local kick = math.sin(now * 2 * math.pi * Fy.Hz * 0.5) * Fy.Kick
		pose.UpperLegL = Vector3.new((-Fy.LegsBack + kick) * k, 0, 0)
		pose.UpperLegR = Vector3.new((-Fy.LegsBack - kick) * k, 0, 0)
		pose.LowerLegL = Vector3.new(-Fy.Knee * k, 0, 0)
		pose.LowerLegR = Vector3.new(-Fy.Knee * k, 0, 0)
		pose.UpperArmL = Vector3.new(Fy.ArmForward * k, 0, Moves.Idle.ArmOut)
		pose.UpperArmR = Vector3.new(Fy.ArmForward * k, 0, Moves.Idle.ArmOut)
	elseif gait == "run" then
		-- the bouncy run: fewer, longer steps with a short hop between them. Each step is a contact (one foot planted,
		-- its leg solved so the foot stays put; the knee gives on landing and straightens to push off) and then a
		-- flight (both feet up, the body on a little arc). The step rate is set in MonsterMoves; the step length
		-- follows the monster's real speed.
		local R = Moves.Run
		st.speedAvg = (st.speedAvg or speed) + (speed - (st.speedAvg or speed)) * math.min(1, dt * 4)
		local stepLen = math.clamp(st.speedAvg / R.StepRate, st.leg * 0.4, st.leg * R.MaxStep)
		st.step = ((st.step or 0) + stepped / stepLen) % 2 -- two steps = one cycle of both legs
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
		-- (angles below are turns from the leg's rest angle B; the foot's place is measured from where it rests)
		local L, B = st.legS, st.legB
		local stride = 2 * L * math.sin(W.Swing * RAD)
		st.phase = (st.phase + stepped / math.max(2 * stride, 0.05)) % 1
		local rest = L * math.sin(B)
		local function leg(p)
			local x, knee, planted
			if p < 0.5 then
				x = stride * (0.5 - p / 0.5) -- planted: from in front of its rest spot to behind it
				knee, planted = 0, true
			else
				local v = (p - 0.5) / 0.5
				x = stride * (-0.5 + v * v * (3 - 2 * v)) -- swung forward again, lifting the knee
				knee, planted = math.sin(v * math.pi), false
			end
			return math.asin(math.clamp((rest + x) / L, -1, 1)) - B, knee, planted
		end
		local aL, kL, pL = leg(st.phase)
		local aR, kR = leg((st.phase + 0.5) % 1)
		-- (the planted foot, for the correction after posing, as in the run)
		st.down = (w > 0.9 and not dead) and (pL and "L" or "R") or nil
		st.downA = pL and aL or aR
		if DEBUG then
			model:SetAttribute("FootDown", st.down or "")
		end
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
		pose.Drop = L * (math.cos(B) - math.cos(B + planted)) / h

	end

	local gaitDrop, gaitPush = pose.Drop, pose.Push

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
		-- (a flyer beats harder and faster in flight; the beat runs on its own phase so the speed-up stays smooth)
		local fk = gait == "fly" and math.min(w, 1) or 0
		st.wingPh = ((st.wingPh or st.breath) + dt * 2 * math.pi * (F.Hz + (Moves.Fly.Hz - F.Hz) * fk)) % (2 * math.pi)
		local beat = math.sin(st.wingPh) * (F.Flap + (Moves.Fly.Flap - F.Flap) * fk)
		pose.WingL = Vector3.new(0, 0, F.Open + beat)
		pose.WingR = Vector3.new(0, 0, F.Open + beat)
	end

	-- the attack while bashing, on this monster's own beat
	if model:GetAttribute("Bashing") and not dead then
		local t = (now + st.beat) % Moves.Attack.Every
		if st.joints.Top then
			-- (a slime: the lunge with its top)
			local A = Moves.Attack
			local wind, strike = Vector3.new(table.unpack(A.SlimeWind)), Vector3.new(table.unpack(A.SlimeStrike))
			local v
			if t < 0.4 then
				local k = math.min(1, t / 0.3)
				v = wind * (1 - (1 - k) ^ 3)
			elseif t < 0.46 then
				local k = (t - 0.4) / 0.06
				v = wind:Lerp(strike, k * k)
			elseif t < 0.58 then
				v = strike
			else
				local k = math.min(1, (t - 0.58) / 0.32)
				v = strike * (1 - k * k * (3 - 2 * k))
			end
			pose.Moves.Top = (pose.Moves.Top or ZERO) + v
		else
			addPose(pose, sample(ATTACK, t), 1)
		end
	elseif not dead and st.jeer then
		-- a back row: jeers at the front (arms pumping, little hops), on its own beat
		local J = Moves.Jeer
		local ph = now * 2 * math.pi * J.Hz + st.breath
		local k = st.jeer
		pose.UpperArmL += Vector3.new((J.ArmUp + J.Pump * math.sin(ph)) * k, 0, 20 * k)
		pose.UpperArmR += Vector3.new((J.ArmUp + J.Pump * math.sin(ph + math.pi)) * k, 0, 20 * k)
		pose.LowerArmL += Vector3.new(40 * k, 0, 0)
		pose.LowerArmR += Vector3.new(40 * k, 0, 0)
		pose.Neck += Vector3.new(-10 * k, 12 * math.sin(ph * 0.5) * k, 0)
		pose.Lift += J.Hop * math.max(0, math.sin(ph * 2)) * k
	end

	-- boss tells: the slam (its whole clip from the moment the server starts it, the smash on the server's beat), the
	-- charge (rear up, then crouched until it ends), the summon
	local tell = model:GetAttribute("Tell") or ""
	if tell ~= (st.tell or "") then
		st.tell = tell
		st.tellAt = now
		if tell == "slam" then
			st.slamStart = now
		end
	end
	if not dead then
		if st.slamStart and now - st.slamStart < Moves.Slam.Length then
			addPose(pose, sample(SLAM, now - st.slamStart), 1)
		end
		if tell == "charge" then
			local t = now - st.tellAt
			addPose(pose, sample(CHARGE, t), 1)
			if t > 1.15 then
				local paw = math.sin(now * 2 * math.pi * Moves.Charge.PawHz) * Moves.Charge.Paw
				pose.UpperLegR += Vector3.new(math.max(0, paw), 0, 0)
			end
			st.chargeEnd = now
		elseif st.chargeEnd and now - st.chargeEnd < 0.35 then
			-- (out of the crouch on a spring-like ease when the charge ends)
			local k = 1 - (now - st.chargeEnd) / 0.35
			addPose(pose, sample(CHARGE, 99), k * k * (3 - 2 * k))
		end
		local summonAt = model:GetAttribute("SummonAt")
		if summonAt ~= st.lastSummon then
			st.lastSummon = summonAt
			st.summonStart = summonAt and now or nil
		end
		if st.summonStart and now - st.summonStart < Moves.Summon.Length then
			addPose(pose, sample(SUMMON, now - st.summonStart), 1)
		end
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

	-- a clip that sinks or pushes the body (attack, hit, slam, charge, summon) bends the knees under it, so the feet
	-- stay where they stand instead of sinking into the ground or sliding (a two-bone bend on the leg's length)
	if not dead and st.joints.UpperLegL and st.joints.LowerLegL then
		-- (on the move it does not lunge: a push would drag the planted foot along)
		pose.Push -= (pose.Push - gaitPush) * math.clamp(w, 0, 1)
		pose.Drop -= (pose.Drop - gaitDrop) * math.clamp(w, 0, 1) -- (nor crouch: the bend moved the planted foot)
		local exD, exP = (pose.Drop - gaitDrop) * h, (pose.Push - gaitPush) * h
		local still = 1
		if math.abs(exD) > 1e-3 or math.abs(exP) > 1e-3 then
			local L = st.leg
			local x, y = -exP, math.max(L * 0.3, L - exD)
			local bend = math.acos(math.min(1, math.sqrt(x * x + y * y) / L))
			local lean = math.atan2(x, y)
			for _, s in { "L", "R" } do
				pose["UpperLeg" .. s] += Vector3.new((lean + bend) / RAD * still, 0, 0)
				pose["LowerLeg" .. s] += Vector3.new(-2 * bend / RAD * still, 0, 0)
				pose["Foot" .. s] += Vector3.new((bend - lean) / RAD * still, 0, 0)
			end
		end
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
			st.hitAway = away.Z >= 0 and 1 or -1 -- (+Z is the rig's back: a blow from the front)
			st.hitAxis = Vector3.yAxis:Cross(away.Unit) -- turning about this tips the top away from the hitter
			st.hit, st.hitVel = Moves.Hit.Deg, 0
			st.hitClipAt = now
		end
	end
	st.hit, st.hitVel = springStep(st.hit, st.hitVel, 0, Moves.Hit.Hz, Moves.Hit.Damping, dt)
	if st.hitClipAt and now - st.hitClipAt < Moves.HitRecoil.Length and not dead then
		local rc = sample(HITRECOIL, now - st.hitClipAt)
		-- (the recoil goes away from the hitter: backwards for a blow from the front, forwards for one from behind)
		local away = st.hitAway or 1
		pose.Push += rc.Push * away
		pose.Drop += rc.Drop
		for _, n in { "Neck", "Chest", "UpperArmL", "UpperArmR", "LowerArmL", "LowerArmR" } do
			pose[n] += rc[n]
		end
	end
	-- the hit tips the body at the hips: turn the legs back by the same, so the feet stay on their spot (the tip
	-- swung a golem's planted foot 0.5 studs and more)
	if not dead and math.abs(st.hit) > 0.01 and st.joints.UpperLegL then
		for _, s in { "L", "R" } do
			local j = st.joints["UpperLeg" .. s]
			if j then
				pose["UpperLeg" .. s] += Vector3.new(-st.hit * st.hitAxis.X, 0, -st.hit * st.hitAxis.Z * j.out)
			end
		end
	end

	-- write the bones
	local function write(name, j, v)
		local r = CFrame.fromEulerAnglesYXZ(v.X * RAD, v.Y * RAD * j.out, v.Z * RAD * j.out)
		if name == "Root" then
			if math.abs(st.hit) > 0.01 then
				r = CFrame.fromAxisAngle(st.hitAxis, st.hit * RAD) * r
			end
			local move = Vector3.new(st.crowdX or 0, (pose.Lift - pose.Drop) * h, -pose.Push * h)
			j.bone.Transform = CFrame.new(j.inv * move) * (j.inv * r * j.rot)
		elseif pose.Moves[name] then
			j.bone.Transform = CFrame.new(j.inv * (pose.Moves[name] * h)) * (j.inv * r * j.rot)
		else
			j.bone.Transform = j.inv * r * j.rot
		end
	end
	for name, j in st.joints do
		local v = pose[name] or (pose.Moves[name] and ZERO)
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
				local fix = math.clamp(-err / (st.leg * math.max(0.4, math.cos(st.downA or 0))) / RAD, -25, 25)
				local thigh = "UpperLeg" .. side
				local errSide = (p - st.plantPos):Dot(right.Unit)
				-- (a big boss turning at a corner moves its hips across by stance x angle: up to 30 degrees)
				local fixSide = math.clamp(-errSide / st.leg / RAD * st.joints[thigh].out, -30, 30)
				write(thigh, st.joints[thigh], pose[thigh] + Vector3.new(fix, 0, fixSide))
				write("Foot" .. side, foot, pose["Foot" .. side] - Vector3.new(fix, 0, fixSide))
				-- the walk sank the hips for the solved leg angle; the corrected leg is steeper or flatter, so sink
				-- the hips for that angle instead (else the planted foot dips under the ground: the imp, 0.4 studs)
				if gait == "walk" then
					local a0 = (st.downA or 0) + st.legB
					local a1 = a0 + fix * RAD
					pose.Drop += st.legS * (math.cos(a0) - math.cos(a1)) * math.min(w, 1) / h
					write("Root", st.joints.Root, pose.Root)
				end
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
			if (st.contactSlide or 0) > 0.1 then
				-- (test rigs: what was going on during a contact that slid)
				print(string.format("[MONSTERANIM] %s slid %.2f: w %.2f, back %s, hit %.1f, bashing %s, tell %s, turn %.2f",
					model.Name, st.contactSlide, w, tostring(stepped < 0), st.hit, tostring(model:GetAttribute("Bashing")),
					tostring(model:GetAttribute("Tell")), st.lastTurn or 0))
			end
			st.contactSlide = 0
		end
		st.lastDown, st.lastFoot = down, p
	end
end

-------------------------------------------------------------------------------
-- the crowd: monsters standing close spread to the sides (inside their models: the server's places are unchanged), and
-- the ones standing near a monster that is hitting something jeer (MonsterMoves.Crowd, MonsterMoves.Jeer)
local function crowdPass(dt)
	local C, J = Moves.Crowd, Moves.Jeer
	local list = {}
	for model, st in states do
		if st and model.Parent then
			local pv = model:GetPivot() * st.frame
			table.insert(list, { st = st, pos = Vector3.new(pv.Position.X, 0, pv.Position.Z),
				right = Vector3.new(pv.RightVector.X, 0, pv.RightVector.Z), bash = model:GetAttribute("Bashing") == true,
				h = st.height })
		end
	end
	for _, a in list do
		local st = a.st
		st.lane = st.lane or (math.random() * 2 - 1) * C.Lane
		local side, crowded, nearBash = 0, false, false
		for _, b in list do
			if b ~= a then
				local d = a.pos - b.pos
				local r = (a.h + b.h) * C.Radius
				local dist = d.Magnitude
				if dist < r then
					crowded = true
					local s = d:Dot(a.right)
					if math.abs(s) < 1e-3 then
						s = st.lane -- (exactly in line: each takes its own side)
					end
					side += (s >= 0 and 1 or -1) * (1 - dist / r)
				end
				if b.bash and dist < (a.h + b.h) * 0.5 * J.Near then
					nearBash = true
				end
			end
		end
		local standing = (st.walk or 0) < 0.5
		if standing then
			-- (only a standing crowd spreads: on the move the offset is held, so no planted foot is dragged)
			st.crowdGoal = crowded and math.clamp((side * C.Spread + st.lane) * a.h, -C.Max * a.h, C.Max * a.h) or 0
		end
		st.crowdX, st.crowdV = springStep(st.crowdX or 0, st.crowdV or 0, st.crowdGoal or 0, C.Hz, 0.9, dt)
		local jeerGoal = (standing and nearBash and not a.bash) and 1 or 0
		st.jeer = (st.jeer or 0) + (jeerGoal - (st.jeer or 0)) * math.min(1, dt * 5)
		if st.jeer < 0.01 then
			st.jeer = nil
		end
	end
end

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
	crowdPass(dt)
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
