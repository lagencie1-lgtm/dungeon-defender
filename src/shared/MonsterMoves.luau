-- Every number for the rigged monsters' movement (src/client/MonsterAnim.client.luau plays them), so a move can be
-- tuned without touching the code. Change a number, press Play in Studio, look.
--
-- A rigged monster is an enemy whose Look holds a skinned MeshPart with bones named like the rig that
-- art/blender/rig_monster.py builds: Root, Hips, Spine, Chest, Neck, Head, UpperArm/LowerArm/Hand L+R,
-- UpperLeg/LowerLeg/Foot L+R. Everything here is in the monster's own frame:
--   joint turns in degrees { forward/back, twist, sideways }:
--     forward/back: + swings a hanging limb forward and up, + leans the body BACK (- leans it forward)
--     twist: + turns to the monster's left
--     sideways: + swings a limb OUT from the body (the code mirrors it for the left and right side)
--   Drop, Push, Lift: how far the body sinks, moves forward, rises, as a share of the monster's height
-- Keys work like HeroMoves: t = seconds, ease = "out" / "inout" / "back" / "in", hold = keep the last pose.

local MonsterMoves = {}

-- monsters farther than this from the camera are not animated (too small to see on a phone)
MonsterMoves.Far = 180

-- the walk: each foot is planted for half the cycle, its leg angle solved so the foot stays where it was put
-- (no sliding); a step is 2 x leg length x sin(Swing); the body sinks as the planted leg leans (straight-leg
-- geometry), so the bob comes by itself
MonsterMoves.Walk = {
	Swing = 32, -- legs swing this far forward and back (bigger = longer, slower steps)
	Knee = 45, -- the swinging leg's knee lifts by this much at mid-swing
	ArmSwing = 22, -- arms swing against the legs
	ArmOut = 12, -- arms held a little away from the body
	ChestTwist = 7, -- shoulders turn against the hips
	Lean = -6, -- a little forward lean while walking
	Settle = { Hz = 3, Damping = 0.8 }, -- how fast the walk fades in and out when the monster starts or stops
}

-- which gait each enemy uses (by its name in Config.Enemies): "walk" or "run"
MonsterMoves.Gaits = {
	Default = "walk",
	Goblin = "run", -- Lemp 2026-11-25: the bouncy run
}

-- the bouncy run: fewer, longer steps with a short hop between them (both feet up), the body rising on the
-- push-off and giving a little on landing, arms pumping
MonsterMoves.Run = {
	StepRate = 2.75, -- steps per second; the step length follows the monster's speed
	MaxStep = 3, -- longest step, in leg lengths (a faster monster then takes more steps)
	Contact = 0.55, -- share of each step with a foot on the ground (the rest is the hop)
	Hop = 0.045, -- how high the body rises in the hop (share of height)
	Squash = 34, -- how far the planted knee gives on landing (degrees, at mid-contact)
	Knee = 95, -- how far the swinging knee folds up
	ArmPump = 34,
	Elbow = 55,
	Lean = -10,
}

-- standing still: breathing
MonsterMoves.Idle = {
	BreathDeg = 2.2,
	BreathHz = 0.45,
	ArmOut = 8,
}

-- the head trails the body's bob and turns on a loose spring (overlap)
MonsterMoves.HeadLag = { Hz = 4.5, Damping = 0.45, Pitch = 0.6, PerBob = -1.2 } -- PerBob: degrees per stud/s of bob

-- the attack, played over and over while the server says the monster is bashing (attribute "Bashing"),
-- each monster on its own beat
MonsterMoves.Attack = {
	Every = 1.0, -- seconds from one blow to the next
	Keys = {
		-- wind-up: right arm high, leaning back
		{ t = 0.25, ease = "out", Chest = { 12, -10, 0 }, Spine = { 6, 0, 0 }, Neck = { -6, 0, 0 },
			UpperArmR = { 165, 0, 18 }, LowerArmR = { 35, 0, 0 }, UpperArmL = { 25, 0, 10 } },
		-- strike: down hard with a lunge
		{ t = 0.32, ease = "out", Push = 0.06, Drop = 0.025, Chest = { -18, 12, 0 }, Spine = { -8, 0, 0 },
			Neck = { 10, 0, 0 }, UpperArmR = { 35, 0, 6 }, LowerArmR = { 10, 0, 0 }, UpperArmL = { -15, 0, 14 } },
		-- contact: hold
		{ t = 0.40, hold = true },
		-- recover with a little overshoot
		{ t = 0.70, ease = "back" },
	},
}

-- getting hit: rock back from the hit, then spring back (0.28 s)
MonsterMoves.Hit = { Deg = 9, Hz = 2.6, Damping = 0.55 }

-- knocked out: knees give, then forward onto the face; the server removes the body 0.7 s after it fell
MonsterMoves.Death = {
	Keys = {
		{ t = 0.18, ease = "out", Drop = 0.08, Root = { -8, 0, 0 }, Spine = { -10, 0, 0 }, Neck = { 12, 0, 0 },
			UpperLegL = { 35, 0, 0 }, LowerLegL = { -55, 0, 0 }, UpperLegR = { 30, 0, 0 }, LowerLegR = { -50, 0, 0 },
			UpperArmL = { 20, 0, 20 }, UpperArmR = { 20, 0, 20 } },
		{ t = 0.6, ease = "in", Lift = 0.12, Root = { -86, 0, 4 }, Spine = { -4, 0, 0 }, Neck = { 20, 0, 0 },
			UpperLegL = { 10, 0, 0 }, LowerLegL = { -20, 0, 0 }, UpperLegR = { 6, 0, 0 }, LowerLegR = { -14, 0, 0 },
			UpperArmL = { 120, 0, 30 }, UpperArmR = { 110, 0, 34 } },
		{ t = 30, hold = true },
	},
}

return MonsterMoves
