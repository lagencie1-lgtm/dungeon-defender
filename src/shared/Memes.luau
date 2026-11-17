-- All the funny lines in one place. Add your own!
local Memes = {}

-- goblins sometimes say this when they appear
Memes.Spawn = {
	"we ride at dawn",
	"bro thinks he can stop us",
	"portal? i hardly know her",
	"no cap, we winning this",
	"goblin mode: ON",
	"is this the line for free robux?",
	"mom said it's my turn on the portal",
	"just here so i don't get fined",
	"i'm built different",
	"left my oven on brb",
	"one of us is the impostor",
	"brb, speedrunning",
	"skill issue incoming",
	"the grind never stops",
	"i'm not lost, i'm exploring",
	"this path has zero reviews",
}

-- when they get hit hard
Memes.Hurt = {
	"bruh",
	"that one hurt my feelings",
	"that's not very cash money of you",
	"ow my rizz",
	"i'm telling my mom",
	"ratio",
	"lag!!",
	"nerf that tower",
	"i paid for this skin",
	"ok that was rude",
	"reported",
}

-- when one gets through the portal
Memes.Leak = {
	"W",
	"ez",
	"too easy",
	"see ya nerds",
	"portal go brrr",
	"gg no re",
}

-- the Goblin King every few seconds
Memes.Boss = {
	"BOW BEFORE YOUR KING",
	"I am the final boss of your homework",
	"Your towers are mid",
	"I've been doing goblin mode since before it was cool",
	"I'm not even trying right now",
	"Who turned off my aura?",
}

-- the Loot Goblin
Memes.Loot = {
	"you'll never catch me!",
	"my precious gems!",
	"catch me if you can",
	"zoom zoom",
	"these gems are NOT for you",
}

-- combo shout-outs (kills in a row, close together)
Memes.Combo = {
	{ Count = 5, Text = "NICE" },
	{ Count = 10, Text = "SHEESH" },
	{ Count = 20, Text = "ABSOLUTELY COOKED" },
	{ Count = 35, Text = "GOBLIN EXTINCTION EVENT" },
	{ Count = 50, Text = "SOMEBODY CALL THE GOBLIN UNION" },
	{ Count = 80, Text = "TOUCH GRASS, GOBLINS" },
}

Memes.Win = { "GG EZ", "W", "Built different", "Main character moment" }
Memes.Lose = { "Skill issue?", "L + ratio by goblins", "Have you tried turning it off and on again?", "It's fine. Everything is fine." }
Memes.Portal = { "The portal felt that", "Portal integrity: questionable", "Ouch, my portal!" }

function Memes.Pick(list)
	return list[math.random(1, #list)]
end

return Memes
