-- Every hero move as plain numbers, so a move can be tuned without touching the code that plays it
-- (src/client/HeroAnim.client.luau). Change a number, press Play in Studio, look.
--
-- A move is a list of key poses. Each key has:
--   t      the time in seconds from the press
--   ease   how it gets there from the key before: "out" (fast, then slows: strikes), "inout" (smooth),
--          "back" (overshoots a little, then settles: recoveries), "in" (slow, then fast: falls)
--   hold   true = stay in the pose of the key before (the short freeze on impact, "hit-stop")
--   and the pose itself: each joint's turn in degrees { forward/back, twist, sideways }, plus
--   Drop   how far the body crouches, in studs (the legs bend so the feet stay on the ground)
--   Push   how far the body lunges forward, in studs
-- A joint that a key leaves out is back at rest in that key. The first key always starts from wherever the
-- hero was, so presses chain into each other instead of snapping.
--
-- Signs (R15): shoulder/hip forward-up = +x, arm out to the side = +z on the right arm and -z on the left,
-- elbow bend = +x, knee bend = -x, Waist/Root twist to the hero's left = +y, Root lean forward = -x.
-- Timing rules from 6A: strike contact within about 0.07 s of the press (the server hits at once),
-- hit-stop 0.055-0.12 s taken out of the recovery, recoveries overshoot and settle.

local HeroMoves = {}

-- which move each hero plays for its attack (F), second (E) and third (R) ability. A list = a combo:
-- presses within ComboWindow seconds of each other play the next one.
HeroMoves.Moves = {
	Swordmaster = { AttackReadyAt = { "slashRight", "slashLeft", "chop" }, WhirlwindReadyAt = "spin", LeapReadyAt = "leap" },
	RuneMage = { AttackReadyAt = { "cast", "castLeft" }, WhirlwindReadyAt = "raise", LeapReadyAt = "slam" },
	BeastHunter = { AttackReadyAt = { "shoot" }, WhirlwindReadyAt = "cast", LeapReadyAt = "raise" },
	Engineer = { AttackReadyAt = { "wrench", "wrenchBack" }, WhirlwindReadyAt = "raise", LeapReadyAt = "slam" },
}
HeroMoves.ComboWindow = 0.9

-- the ready stance a hero falls into after fighting (held CombatStance seconds after the last move), and how
-- strongly it shows while walking (0 = only when standing still)
HeroMoves.CombatStance = 3.5
HeroMoves.StanceWhileWalking = 0.35
HeroMoves.Stance = {
	Swordmaster = { Drop = 0.18, Root = { -4, 12, 0 }, Waist = { 0, -10, 0 }, Neck = { 0, -4, 0 },
		RShoulder = { 28, 0, 8 }, RElbow = { 35, 0, 0 }, LShoulder = { 12, 0, -14 }, LElbow = { 25, 0, 0 } },
	RuneMage = { Drop = 0.08, Waist = { 3, 0, 0 }, RShoulder = { 22, 0, 6 }, RElbow = { 20, 0, 0 },
		LShoulder = { 18, 0, -18 }, LElbow = { 45, 0, 0 } },
	BeastHunter = { Drop = 0.14, Root = { -3, 8, 0 }, RShoulder = { 10, 0, 6 }, LShoulder = { 20, 0, -8 },
		LElbow = { 20, 0, 0 } },
	Engineer = { Drop = 0.1, Waist = { 4, 0, 0 }, RShoulder = { 25, 0, 6 }, RElbow = { 40, 0, 0 },
		LShoulder = { 10, 0, -10 } },
}

-- life that is always on (all heroes)
HeroMoves.Life = {
	LeanPerSpeed = 0.32, -- degrees of forward lean per stud/s of running speed
	LeanMax = 9,
	LeanPerAccel = 0.05, -- extra lean while speeding up (back while braking), degrees per stud/s²
	BankPerTurn = 0.05, -- sideways bank into turns, degrees per degree/s of turning
	BankMax = 7,
	ShoulderCounter = 0.35, -- shoulders turn against the stride (share of the hips' swing), capped below
	ShoulderCounterMax = 6,
	BreathDeg = 1.6, -- chest rise when standing, degrees
	BreathHz = 0.32,
	LeanSpring = { Hz = 3.2, Damping = 0.7 }, -- how lean and bank follow speed
	-- the head and the free arm trail the body a little (overlap): a spring on what the move asks of them
	Follow = { Hz = 7, Damping = 0.48, Joints = { "Neck", "LShoulder", "LElbow" } },
}

-- the knock-out fall tips the body about a line this high above the ground (studs at scale 1): half the body's
-- depth, so the back rests on the ground instead of in it
HeroMoves.FallPivot = 0.6

-- the arm shakes for a moment on impact (6A: arm shudder at 34 Hz)
HeroMoves.ShudderHz = 34

HeroMoves.Clips = {
	-- Swordmaster combo 1: a forehand cut from the right shoulder down across the body
	slashRight = {
		Shudder = { From = 0.07, To = 0.13, Joint = "RShoulder", Deg = 4 },
		Keys = {
			{ t = 0.03, ease = "out", Drop = 0.12, Root = { -3, -8, 0 }, Waist = { 0, -28, 0 }, Neck = { 0, 12, 0 },
				RShoulder = { 125, 0, 35 }, RElbow = { 45, 0, 0 }, LShoulder = { 25, 0, -18 }, LElbow = { 30, 0, 0 } },
			{ t = 0.07, ease = "out", Drop = 0.28, Push = 0.45, Root = { -9, 12, 0 }, Waist = { -6, 38, 0 },
				Neck = { 0, -22, 0 }, RShoulder = { 55, 0, -42 }, RElbow = { 5, 0, 0 }, LShoulder = { -30, 0, -22 },
				LElbow = { 20, 0, 0 } },
			{ t = 0.13, hold = true },
			{ t = 0.27, ease = "out", Drop = 0.22, Push = 0.32, Root = { -6, 16, 0 }, Waist = { -4, 48, 0 },
				Neck = { 0, -26, 0 }, RShoulder = { 28, 0, -62 }, RElbow = { 10, 0, 0 }, LShoulder = { -22, 0, -18 } },
			{ t = 0.5, ease = "back" },
		},
	},
	-- combo 2: a backhand cut, left to right
	slashLeft = {
		Shudder = { From = 0.07, To = 0.13, Joint = "RShoulder", Deg = 4 },
		Keys = {
			{ t = 0.03, ease = "out", Drop = 0.14, Root = { -3, 10, 0 }, Waist = { 0, 32, 0 }, Neck = { 0, -14, 0 },
				RShoulder = { 95, 0, -62 }, RElbow = { 60, 0, 0 }, LShoulder = { -10, 0, -25 } },
			{ t = 0.07, ease = "out", Drop = 0.28, Push = 0.45, Root = { -9, -14, 0 }, Waist = { -6, -40, 0 },
				Neck = { 0, 24, 0 }, RShoulder = { 70, 0, 58 }, RElbow = { 4, 0, 0 }, LShoulder = { 30, 0, -12 },
				LElbow = { 35, 0, 0 } },
			{ t = 0.13, hold = true },
			{ t = 0.27, ease = "out", Drop = 0.22, Push = 0.3, Root = { -6, -18, 0 }, Waist = { -4, -48, 0 },
				Neck = { 0, 26, 0 }, RShoulder = { 40, 0, 75 }, RElbow = { 10, 0, 0 } },
			{ t = 0.52, ease = "back" },
		},
	},
	-- combo 3: the big one, an overhead chop with both hands, longer freeze
	chop = {
		Shudder = { From = 0.1, To = 0.19, Joint = "RShoulder", Deg = 5 },
		Keys = {
			{ t = 0.05, ease = "out", Drop = 0.05, Root = { 7, 0, 0 }, Waist = { 8, 0, 0 }, Neck = { 6, 0, 0 },
				RShoulder = { 172, 0, 8 }, RElbow = { 30, 0, 0 }, LShoulder = { 160, 0, -8 }, LElbow = { 35, 0, 0 } },
			{ t = 0.1, ease = "out", Drop = 0.45, Push = 0.65, Root = { -15, 0, 0 }, Waist = { -14, 0, 0 },
				Neck = { 12, 0, 0 }, RShoulder = { 42, 0, -4 }, RElbow = { 0, 0, 0 }, LShoulder = { 45, 0, 8 },
				LElbow = { 10, 0, 0 } },
			{ t = 0.19, hold = true },
			{ t = 0.36, ease = "out", Drop = 0.35, Push = 0.5, Root = { -11, 0, 0 }, Waist = { -10, 0, 0 },
				RShoulder = { 30, 0, -6 }, LShoulder = { 32, 0, 6 } },
			{ t = 0.66, ease = "back" },
		},
	},
	-- Whirlwind: wind up the other way, then one and a quarter turns with the sword held out, then settle
	spin = {
		Keys = {
			{ t = 0.07, ease = "out", Drop = 0.32, Root = { -6, 25, 0 }, Waist = { 0, 35, 0 }, Neck = { 0, -20, 0 },
				RShoulder = { 90, 0, -45 }, RElbow = { 70, 0, 0 }, LShoulder = { 30, 0, -30 } },
			{ t = 0.42, ease = "inout", Drop = 0.26, Root = { -8, -425, 0 }, Waist = { -4, -15, 0 },
				RShoulder = { 88, 0, 75 }, RElbow = { 5, 0, 0 }, LShoulder = { 70, 0, -70 } },
			{ t = 0.52, ease = "back", Drop = 0.22, Root = { -5, -360, 0 }, Waist = { 0, 6, 0 },
				RShoulder = { 55, 0, 40 }, LShoulder = { 30, 0, -40 } },
			{ t = 0.78, ease = "back", Root = { 0, -360, 0 } },
		},
	},
	-- Leap (the client throws the hero up; it lands about 0.6 s later): tuck, sword over the head, slam
	-- down on landing and stay down for a moment so the eye catches the contact
	leap = {
		Shudder = { From = 0.6, To = 0.7, Joint = "RShoulder", Deg = 5 },
		Keys = {
			{ t = 0.06, ease = "out", Drop = 0.3, Root = { -12, 0, 0 }, RShoulder = { -35, 0, 25 },
				LShoulder = { -35, 0, -25 } },
			{ t = 0.22, ease = "out", Root = { 10, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 8, 0, 0 },
				RShoulder = { 170, 0, 12 }, RElbow = { 25, 0, 0 }, LShoulder = { 160, 0, -12 }, LElbow = { 30, 0, 0 },
				RHip = { 65, 0, 0 }, RKnee = { -90, 0, 0 }, LHip = { 35, 0, 0 }, LKnee = { -60, 0, 0 } },
			{ t = 0.5, ease = "inout", Root = { 14, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { 6, 0, 0 },
				RShoulder = { 178, 0, 6 }, RElbow = { 35, 0, 0 }, LShoulder = { 170, 0, -6 }, LElbow = { 40, 0, 0 },
				RHip = { 40, 0, 0 }, RKnee = { -45, 0, 0 }, LHip = { 20, 0, 0 }, LKnee = { -35, 0, 0 } },
			{ t = 0.6, ease = "out", Drop = 0.75, Root = { -22, 0, 0 }, Waist = { -18, 0, 0 }, Neck = { 14, 0, 0 },
				RShoulder = { 28, 0, -8 }, LShoulder = { 30, 0, 8 }, RHip = { 25, 0, 0 } },
			{ t = 0.95, hold = true },
			{ t = 1.3, ease = "back" },
		},
	},

	-- Rune Mage: the staff thrusts forward, the other hand pushes the spell
	cast = {
		Keys = {
			{ t = 0.04, ease = "out", Drop = 0.08, Root = { 4, 6, 0 }, Waist = { 6, 15, 0 }, RShoulder = { 70, 0, 25 },
				RElbow = { 70, 0, 0 }, LShoulder = { 40, 0, -20 }, LElbow = { 80, 0, 0 } },
			{ t = 0.09, ease = "out", Drop = 0.2, Push = 0.3, Root = { -8, -6, 0 }, Waist = { -6, -12, 0 },
				Neck = { -6, 0, 0 }, RShoulder = { 95, 0, 5 }, RElbow = { 5, 0, 0 }, LShoulder = { 85, 0, -10 },
				LElbow = { 10, 0, 0 } },
			{ t = 0.15, hold = true },
			{ t = 0.45, ease = "back" },
		},
	},
	castLeft = {
		Keys = {
			{ t = 0.04, ease = "out", Drop = 0.08, Root = { 4, -6, 0 }, Waist = { 6, -15, 0 }, RShoulder = { 45, 0, 20 },
				RElbow = { 60, 0, 0 }, LShoulder = { 70, 0, -25 }, LElbow = { 70, 0, 0 } },
			{ t = 0.09, ease = "out", Drop = 0.2, Push = 0.3, Root = { -8, 6, 0 }, Waist = { -6, 12, 0 },
				RShoulder = { 60, 0, 10 }, RElbow = { 20, 0, 0 }, LShoulder = { 98, 0, -5 }, LElbow = { 5, 0, 0 } },
			{ t = 0.15, hold = true },
			{ t = 0.45, ease = "back" },
		},
	},
	-- both arms up and out, held for a moment (summons, buffs, big spells)
	raise = {
		Keys = {
			{ t = 0.1, ease = "out", Drop = 0.3, Root = { -8, 0, 0 }, RShoulder = { -20, 0, 20 }, LShoulder = { -20, 0, -20 } },
			{ t = 0.24, ease = "out", Drop = -0.05, Root = { 8, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 14, 0, 0 },
				RShoulder = { 150, 0, 40 }, LShoulder = { 150, 0, -40 } },
			{ t = 0.5, hold = true },
			{ t = 0.85, ease = "back" },
		},
	},
	-- both arms high, then down hard, bending at the waist
	slam = {
		Shudder = { From = 0.22, To = 0.32, Joint = "RShoulder", Deg = 4 },
		Keys = {
			{ t = 0.12, ease = "out", Drop = 0.05, Root = { 8, 0, 0 }, Waist = { 10, 0, 0 },
				RShoulder = { 172, 0, 10 }, LShoulder = { 172, 0, -10 } },
			{ t = 0.22, ease = "out", Drop = 0.55, Root = { -18, 0, 0 }, Waist = { -20, 0, 0 },
				RShoulder = { 30, 0, 0 }, LShoulder = { 30, 0, 0 } },
			{ t = 0.5, hold = true },
			{ t = 0.85, ease = "back" },
		},
	},
	-- Beast Hunter: bow arm out, string hand draws to the cheek and lets go with a kick
	shoot = {
		Keys = {
			{ t = 0.06, ease = "out", Drop = 0.12, Root = { 0, 30, 0 }, Waist = { 0, 20, 0 }, Neck = { 0, -40, 0 },
				LShoulder = { 90, 0, -10 }, LElbow = { 0, 0, 0 }, RShoulder = { 85, -30, -25 }, RElbow = { 110, 0, 0 } },
			{ t = 0.1, ease = "out", Drop = 0.14, Root = { 4, 32, 0 }, Waist = { 0, 22, 0 }, Neck = { 0, -40, 0 },
				LShoulder = { 92, 0, -8 }, RShoulder = { 70, -30, 15 }, RElbow = { 60, 0, 0 } },
			{ t = 0.22, hold = true },
			{ t = 0.5, ease = "back" },
		},
	},
	-- Engineer: a wrench swing and a back swing
	wrench = {
		Shudder = { From = 0.07, To = 0.13, Joint = "RShoulder", Deg = 4 },
		Keys = {
			{ t = 0.03, ease = "out", Drop = 0.1, Waist = { 4, -22, 0 }, RShoulder = { 140, 0, 30 }, RElbow = { 50, 0, 0 } },
			{ t = 0.07, ease = "out", Drop = 0.26, Push = 0.4, Root = { -8, 10, 0 }, Waist = { -8, 30, 0 },
				Neck = { 0, -16, 0 }, RShoulder = { 40, 0, -30 }, RElbow = { 10, 0, 0 }, LShoulder = { -20, 0, -15 } },
			{ t = 0.13, hold = true },
			{ t = 0.46, ease = "back" },
		},
	},
	wrenchBack = {
		Shudder = { From = 0.07, To = 0.13, Joint = "RShoulder", Deg = 4 },
		Keys = {
			{ t = 0.03, ease = "out", Drop = 0.1, Waist = { 0, 28, 0 }, RShoulder = { 90, 0, -55 }, RElbow = { 60, 0, 0 } },
			{ t = 0.07, ease = "out", Drop = 0.26, Push = 0.4, Root = { -8, -12, 0 }, Waist = { -6, -34, 0 },
				Neck = { 0, 18, 0 }, RShoulder = { 65, 0, 50 }, RElbow = { 8, 0, 0 }, LShoulder = { 25, 0, -10 } },
			{ t = 0.13, hold = true },
			{ t = 0.48, ease = "back" },
		},
	},

	-- getting hit (any hero): rock back, arms flinch out, then spring back. Plays on top of whatever else runs.
	hurt = {
		Keys = {
			{ t = 0.05, ease = "out", Drop = 0.1, Root = { 9, 0, 5 }, Waist = { 12, 0, 0 }, Neck = { 18, 0, 0 },
				RShoulder = { 25, 0, 25 }, LShoulder = { 25, 0, -25 } },
			{ t = 0.33, ease = "back" },
		},
	},
	-- knocked out: knees buckle, a wobble, then over backwards onto the back (the hero comes back a few seconds
	-- later). Fall = degrees the whole body tips back (about a line under the hips, FallPivot studs up).
	death = {
		Keys = {
			{ t = 0.18, ease = "out", Drop = 0.8, Root = { -14, 0, 0 }, Waist = { -18, 0, 0 }, Neck = { -20, 0, 0 },
				RShoulder = { -10, 0, 12 }, LShoulder = { -10, 0, -12 } },
			{ t = 0.42, ease = "inout", Drop = 0.85, Root = { -10, 10, 6 }, Waist = { -14, 0, 0 }, Neck = { -24, 0, 10 },
				RShoulder = { -5, 0, 16 }, LShoulder = { -5, 0, -16 } },
			{ t = 0.82, ease = "in", Fall = 90, Root = { 0, 10, 4 }, Neck = { -10, 0, 0 },
				RShoulder = { 60, 0, 60 }, LShoulder = { 60, 0, -60 }, RHip = { 25, 0, 0 }, LHip = { 10, 0, 0 },
				RKnee = { -30, 0, 0 }, LKnee = { -12, 0, 0 } },
			{ t = 0.95, ease = "back", Fall = 86, Root = { 0, 10, 4 }, Neck = { -8, 0, 0 },
				RShoulder = { 55, 0, 64 }, LShoulder = { 55, 0, -64 }, RHip = { 22, 0, 0 }, LHip = { 8, 0, 0 },
				RKnee = { -26, 0, 0 }, LKnee = { -10, 0, 0 } },
			{ t = 30, hold = true },
		},
	},
}

return HeroMoves
