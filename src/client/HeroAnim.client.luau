-- Attack animations for every hero in the game, made in code (no animation assets): when a hero's ability goes on
-- cooldown (the "...ReadyAt" attributes every player's computer can see), their arms and body play a swing, a cast,
-- a bow shot, a slam or a spin on top of the normal walking animation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local playing = {} -- [player] = { kind, start, duration }

-- which move each hero plays for the attack (F), the second ability (E) and the third (R)
local MOVES = {
	Swordmaster = { AttackReadyAt = "swing", WhirlwindReadyAt = "spin", LeapReadyAt = "slam" },
	RuneMage = { AttackReadyAt = "cast", WhirlwindReadyAt = "raise", LeapReadyAt = "slam" },
	BeastHunter = { AttackReadyAt = "shoot", WhirlwindReadyAt = "cast", LeapReadyAt = "raise" },
	Engineer = { AttackReadyAt = "swing", WhirlwindReadyAt = "raise", LeapReadyAt = "slam" },
}
local DURATION = { swing = 0.34, cast = 0.4, shoot = 0.36, slam = 0.55, spin = 0.5, raise = 0.6 }

-- a value that goes a → b → 0 over the move: wind up, strike, recover
local function strike(t, windup, a, b)
	if t < windup then
		return a * math.sin(t / windup * math.pi / 2)
	end
	local u = (t - windup) / (1 - windup)
	if u < 0.45 then
		local k = u / 0.45
		return a + (b - a) * (1 - (1 - k) ^ 3) -- fast into the hit
	end
	return b * (1 - (u - 0.45) / 0.55) ^ 2 -- ease back
end

local function joints(character)
	local function find(partName, jointName)
		local part = character:FindFirstChild(partName)
		return part and part:FindFirstChild(jointName)
	end
	return find("RightUpperArm", "RightShoulder"), find("LeftUpperArm", "LeftShoulder"), find("UpperTorso", "Waist"),
		find("LowerTorso", "Root")
end

local function apply(character, kind, t)
	local right, left, waist, root = joints(character)
	if not right or not left then
		return
	end
	local A = CFrame.Angles
	if kind == "swing" then
		-- arm up and back, then a fast slash down across the body, the torso twisting with it
		right.Transform *= A(strike(t, 0.3, 2.6, -0.5), 0, strike(t, 0.3, 0.5, -0.6))
		if waist then
			waist.Transform *= A(strike(t, 0.3, -0.15, 0.3), strike(t, 0.3, -0.6, 0.7), 0)
		end
	elseif kind == "cast" then
		-- the staff arm thrusts forward, the other hand supports it
		right.Transform *= A(strike(t, 0.35, 0.6, 1.7), 0, 0)
		left.Transform *= A(strike(t, 0.35, 0.2, 0.9), 0, 0)
		if waist then
			waist.Transform *= A(strike(t, 0.35, -0.2, 0.25), 0, 0)
		end
	elseif kind == "shoot" then
		-- bow arm straight out, the other draws back and lets go
		right.Transform *= A(1.5 * math.sin(math.min(1, t * 3) * math.pi / 2) * (t < 0.8 and 1 or (1 - t) * 5), 0, 0)
		left.Transform *= A(strike(t, 0.5, 1.3, 0.4), 0, strike(t, 0.5, -0.9, 0))
		if waist then
			waist.Transform *= A(0, strike(t, 0.5, 0.5, -0.1), 0)
		end
	elseif kind == "slam" then
		-- both arms high, then down hard, bending at the waist
		local arms = strike(t, 0.45, 3.0, 0.4)
		right.Transform *= A(arms, 0, 0)
		left.Transform *= A(arms, 0, 0)
		if waist then
			waist.Transform *= A(strike(t, 0.45, -0.35, 0.6), 0, 0)
		end
	elseif kind == "raise" then
		-- both arms up and out, held for a moment (summons, buffs, big spells)
		local up = math.sin(math.min(1, t * 2.5) * math.pi / 2) * (t < 0.7 and 1 or (1 - t) / 0.3)
		right.Transform *= A(2.4 * up, 0, 0.5 * up)
		left.Transform *= A(2.4 * up, 0, -0.5 * up)
	elseif kind == "spin" then
		-- the whole body turns once, the sword arm held out
		if root then
			root.Transform *= A(0, -(1 - (1 - t) ^ 2) * math.pi * 2, 0)
		end
		local out = math.sin(math.min(1, t * 4) * math.pi / 2) * (t < 0.8 and 1 or (1 - t) * 5)
		right.Transform *= A(1.5 * out, 0, 0.4 * out)
	end
end

local function watch(player)
	for _, attr in { "AttackReadyAt", "WhirlwindReadyAt", "LeapReadyAt" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			local ready = player:GetAttribute(attr) or 0
			if ready <= workspace:GetServerTimeNow() then
				return -- a reset, not a new attack
			end
			local moves = MOVES[player:GetAttribute("HeroId") or "Swordmaster"] or MOVES.Swordmaster
			local kind = moves[attr]
			playing[player] = { kind = kind, start = os.clock(), duration = DURATION[kind] }
		end)
	end
end
for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	playing[player] = nil
end)

-- after the normal animations have been applied each frame, add the move on top
RunService.Stepped:Connect(function()
	for player, move in playing do
		local t = (os.clock() - move.start) / move.duration
		local character = player.Character
		if t >= 1 or not character then
			playing[player] = nil
		else
			apply(character, move.kind, t)
		end
	end
end)
