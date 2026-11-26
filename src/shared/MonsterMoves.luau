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

-- a slime hops (rig_monster.py "slime"): Length = one hop, in its heights; Ground = share of the hop on the ground;
-- Squash / Stretch = how far the column sinks or rises (share of height); Bulge = how far the sides push out per
-- unit of squash; Height = the arc (share of height). No scale anywhere: bones only.
MonsterMoves.Hop = { Length = 1.4, Ground = 0.45, Squash = 0.2, Stretch = 0.12, Bulge = 0.45, Height = 0.35,
	Breathe = 0.04, Wobble = 5, WobbleHz = 1.6, Lean = -6, Spring = { Hz = 6, Damping = 0.45 } }

-- rigs without legs (ghosts, robes): a float. Bob = rise and fall (share of height), Trail = how far the hem swings
-- back while gliding (degrees), Sway = the hem's side to side
MonsterMoves.Float = { Bob = 0.035, BobHz = 0.8, Lean = -8, Roll = 3, Trail = 22, Sway = 7, SwayHz = 1.1,
	ArmForward = 20, ArmDrift = 6 }

-- which gait each enemy uses (by its name in Config.Enemies): "walk", "run" or "fly"
MonsterMoves.Gaits = {
	Default = "walk",
	Goblin = "run", -- Lemp 2026-11-25: the bouncy run
	-- (2026-11-26: the imp's stubby legs rest slanted 47 degrees and it is the fastest enemy, 15 studs/s: a walk
	-- either slid or sank its feet, so it flies low on its wings and lands to fight)
	EmberImp = "fly",
}

-- the low flight (a winged monster with short legs): it lifts off as it moves, bobs with each wing beat, leans into
-- the flight with its legs trailing, and lands when it stops (to bash, to be hit)
MonsterMoves.Fly = {
	Hover = 0.12, -- how high the feet are off the ground in flight (share of height)
	Bob = 0.03, -- the bob with each wing beat (share of height)
	Lean = -14,
	LegsBack = 28, -- the legs trail back (degrees)
	Knee = 35,
	Kick = 8, -- the legs paddle a little, one after the other
	Flap = 36, -- the wing beat in flight (degrees; Wings.Flap when standing)
	Hz = 4.2, -- wing beats a second in flight (Wings.Hz when standing)
	ArmForward = 18,
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

-- a tail (Tail1-3): swishes side to side, each bone Lag radians behind the one before, wider while moving
MonsterMoves.Tail = { Sway = 12, Hz = 0.9, Lag = 0.7, Lift = 6 }
-- wings (Wing L/R): held a little open, beating
MonsterMoves.Wings = { Open = 8, Flap = 16, Hz = 2.2 }

-- the head trails the body's bob and turns on a loose spring (overlap)
MonsterMoves.HeadLag = { Hz = 4.5, Damping = 0.45, Pitch = 0.6, PerBob = -1.2 } -- PerBob: degrees per stud/s of bob

-- the attack, played over and over while the server says the monster is bashing (attribute "Bashing"),
-- each monster on its own beat
MonsterMoves.Attack = {
	Every = 1.1, -- seconds from one blow to the next
	-- (round 3: a longer wind-up that rises and holds a beat, a faster strike, and a held contact frame)
	Keys = {
		-- wind-up: rise a little, lean back, right arm high, the off arm out for balance
		{ t = 0.3, ease = "out", Lift = 0.012, Chest = { 16, -14, 0 }, Spine = { 8, 0, 0 }, Neck = { -8, 0, 0 },
			UpperArmR = { 165, 0, 18 }, LowerArmR = { 40, 0, 0 }, UpperArmL = { 30, 0, 14 } },
		-- the beat at the top before the blow
		{ t = 0.4, hold = true },
		-- strike: down hard and fast with a lunge
		{ t = 0.46, ease = "in", Push = 0.07, Drop = 0.03, Chest = { -22, 14, 0 }, Spine = { -10, 0, 0 },
			Neck = { 12, 0, 0 }, UpperArmR = { 30, 0, 6 }, LowerArmR = { 8, 0, 0 }, UpperArmL = { -20, 0, 14 } },
		-- contact: held so the hit reads
		{ t = 0.58, hold = true },
		-- recover with a little overshoot
		{ t = 0.9, ease = "back" },
	},
	-- a slime (no arms) lunges with its top: back and up in the wind-up, forward and down at the strike (shares of
	-- height, rig frame: -Z is forward)
	SlimeWind = { 0, 0.05, 0.06 },
	SlimeStrike = { 0, -0.07, -0.12 },
}

-- the pile-up at a wall (Lemp 2026-11-26: "they should pile up before the barricade and smash onto it"): everyone
-- standing in the pile swings at it on their own beat. The rows behind lean on the ones in front, reach over them with
-- higher overhead swings (some hop up to swing) and the whole pile surges forward a little on each blow.
MonsterMoves.Pile = {
	Near = 2.5, -- in the pile: standing within this many heights of one that is hitting the wall
	Lean = -12, -- a back row leans on the one in front (degrees)
	Reach = 25, -- extra overhead on the wind-up (degrees, the striking arm)
	Hop = 0.07, -- the hoppers jump this high on the wind-up (share of height); about half of the back rows hop
	Surge = 0.035, -- the push forward on each blow, on top of the strike's own lunge (share of height)
}
-- the wall breaks (Bashing goes off for the whole pile): a beat, then they burst forward as a running blob
MonsterMoves.Burst = {
	Beat = 0.15, -- the beat before the burst (seconds); each one's start is staggered by up to Stagger more
	Stagger = 0.1,
	Lean = -14, -- extra forward lean in the burst, easing off over Fade seconds
	Fade = 0.9,
}

-- a broken wall leaves a stump on the path (the barricade branch: attribute Broken on the tower model): monsters
-- crossing it hop over, knees tucked, so no foot goes into it
MonsterMoves.StepOver = {
	Clear = 0.35, -- studs over the stump's top at the top of the hop
	Reach = 0.55, -- the hop starts this many heights before the stump's face (and ends as far behind it)
	Tuck = 45, -- knee tuck at the top of the hop (degrees)
}

-- a standing crowd keeps a little room between its members (a lane each, so two never sit in one spot); round 3 spread
-- them wider, which Lemp didn't want at a wall (the pile-up). Client only: the bodies move inside their models.
MonsterMoves.Crowd = { Radius = 0.55, Spread = 0.08, Max = 0.25, Lane = 0.1, Hz = 1.1 } -- shares of height

-- boss tells (6A: a boss never goes quiet). Round 2: they must read at phone distance, so the whole body moves
-- (rear back, rise, crouch, head up) and each pose holds 0.4-0.6 s; the arms stay within what each rig was tested at
-- (the Goblin King: arms 35; the Shadow Queen keeps hers near the body). Drop/Lift/Push are shares of height; the
-- legs bend under them (MonsterAnim), so the feet stay put.
-- slam: the server shows the red ring 0.9 s before the blow. Rear back and up (0.3 s), hold, smash down at 0.9 s
-- into a deep crouch, hold it, rise again.
MonsterMoves.Slam = {
	Length = 1.6,
	Keys = {
		{ t = 0.3, ease = "out", Lift = 0.03, Root = { 22, 0, 0 }, Spine = { 14, 0, 0 }, Chest = { 8, 0, 0 },
			Neck = { -18, 0, 0 }, UpperArmL = { 35, 0, 16 }, UpperArmR = { 35, 0, 16 }, LowerArmL = { 75, 0, 0 },
			LowerArmR = { 75, 0, 0 }, HandL = { 35, 0, 0 }, HandR = { 35, 0, 0 } },
		{ t = 0.76, hold = true }, -- (held 0.46 s)
		-- (round 2 first try: Drop 0.15 and 56 degrees of bend read as the golem falling over; this is a crouch)
		{ t = 0.9, ease = "in", Drop = 0.1, Push = 0.03, Root = { -20, 0, 0 }, Spine = { -12, 0, 0 }, Chest = { -6, 0, 0 },
			Neck = { 20, 0, 0 }, UpperArmL = { -15, 0, 18 }, UpperArmR = { -15, 0, 18 }, LowerArmL = { 10, 0, 0 },
			LowerArmR = { 10, 0, 0 } },
		{ t = 1.3, hold = true }, -- (held 0.4 s; the server keeps the boss still until the rise is done)
		{ t = 1.6, ease = "back" },
	},
}
-- charge: the wind-up lasts seconds. Rear up and roar (head back) for half a second, then drop low into a crouch,
-- leaning in with the head up at the target, held for the rest of the wind-up while one foot paws the ground.
MonsterMoves.Charge = {
	Keys = {
		{ t = 0.3, ease = "out", Lift = 0.02, Root = { 20, 0, 0 }, Spine = { 12, 0, 0 }, Neck = { -24, 0, 0 },
			UpperArmL = { 30, 0, 25 }, UpperArmR = { 30, 0, 25 }, LowerArmL = { 50, 0, 0 }, LowerArmR = { 50, 0, 0 } },
		{ t = 0.8, hold = true }, -- (held 0.5 s)
		{ t = 1.15, ease = "out", Drop = 0.11, Root = { -24, 0, 0 }, Spine = { -10, 0, 0 }, Neck = { 30, 0, 0 },
			UpperArmL = { -30, 0, 14 }, UpperArmR = { -30, 0, 14 }, LowerArmL = { 30, 0, 0 }, LowerArmR = { 30, 0, 0 } },
	},
	Paw = 12, -- a foot paws the ground (degrees), PawHz times a second, once crouched
	PawHz = 2.2,
}
-- summon: rise up (a floating queen levitates), lean back with the head up and the arms open, hold, sink back
MonsterMoves.Summon = {
	Length = 1.5,
	Keys = {
		{ t = 0.4, ease = "out", Lift = 0.16, Root = { 16, 0, 0 }, Spine = { 10, 0, 0 }, Neck = { -22, 0, 0 },
			UpperArmL = { 15, 0, 30 }, UpperArmR = { 15, 0, 30 }, LowerArmL = { 40, 0, 0 }, LowerArmR = { 40, 0, 0 } },
		{ t = 0.95, hold = true }, -- (held 0.55 s)
		{ t = 1.5, ease = "back" },
	},
}

-- getting hit: rock back from the hit, then spring back (0.28 s)
MonsterMoves.Hit = { Deg = 8, Hz = 2.6, Damping = 0.55 }
-- with the rock, the body recoils: knocked back and down a little, head snapped back, arms flung, eased back in 0.28 s
MonsterMoves.HitRecoil = {
	Length = 0.3,
	Keys = {
		{ t = 0.06, ease = "out", Push = -0.05, Drop = 0.025, Neck = { -18, 0, 0 }, Chest = { 12, 0, 0 },
			UpperArmL = { -25, 0, 30 }, UpperArmR = { -25, 0, 30 }, LowerArmL = { 30, 0, 0 }, LowerArmR = { 30, 0, 0 } },
		{ t = 0.3, ease = "back" },
	},
}

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
