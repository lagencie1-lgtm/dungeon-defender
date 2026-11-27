-- The defenders' shots, on the client only (Lemp 2026-11-27: "the tower shooting animations are still way behind").
-- The server says which defender shoots where (CombatFx "TowerShot": from, model, kind, weapon index, aim, wind-up,
-- travel time) and lands the damage when the projectile arrives; here each shot gets three beats, all springs (no
-- tweens, 6A): a wind-up, the release in one frame, a recoil that settles. Numbers in Config.TowerShots.
--   Ballista: the weapon turns to the target, creeps back as the string is drawn, snaps on release and kicks back;
--   a real bolt (shaft, iron tip, red fletching) flies a slight arc and sparks small where it lands.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local fx = workspace:FindFirstChild("LocalCombatEffects") or Instance.new("Folder")
fx.Name = "LocalCombatEffects"
fx.Parent = workspace

-- a damped spring step (stiffness k, damping c) toward `goal`
local function spring(x, v, goal, k, c, dt)
	local a = (goal - x) * k - v * c
	v += a * dt
	return x + v * dt, v
end

local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = fx
	return p
end

-- [weapon part] = state; the part's home CFrame is taken the first time it shoots (and again after an upgrade swaps
-- the look, when the part is a new one)
local weapons = {}

local function weaponOf(model)
	local look = model and model:FindFirstChild("Look")
	return look and look:FindFirstChild("Skin_barrel")
end

local function stateOf(p, model)
	local st = weapons[p]
	if not st then
		st = { home = p.CFrame, model = model, yaw = 0, yawVel = 0, goalYaw = 0, pull = 0, pullVel = 0, goalPull = 0,
			kick = 0, kickVel = 0 }
		-- (level 3 carries both weapons in one part: it doesn't turn, it only pulls and kicks)
		st.turns = (model:GetAttribute("Level") or 1) < 3
		weapons[p] = st
	end
	return st
end

-- a ballista bolt: dark shaft, iron tip, red fletching (about the size the weapon's own bolt is drawn)
local function bolt(len)
	local m = Instance.new("Model")
	m.Name = "Bolt"
	local shaft = part({ Size = Vector3.new(0.16, 0.16, len), Color = Color3.fromRGB(92, 62, 40) })
	local tip = part({ Size = Vector3.new(0.3, 0.3, 0.42), Color = Color3.fromRGB(205, 205, 212), Material = Enum.Material.Metal })
	local f1 = part({ Size = Vector3.new(0.04, 0.32, 0.4), Color = Color3.fromRGB(200, 45, 40) })
	local f2 = part({ Size = Vector3.new(0.32, 0.04, 0.4), Color = Color3.fromRGB(200, 45, 40) })
	for _, p in { shaft, tip, f1, f2 } do
		p.Parent = m
	end
	m.PrimaryPart = shaft
	m.Parent = fx
	return m, function(cf)
		shaft.CFrame = cf
		tip.CFrame = cf * CFrame.new(0, 0, -len / 2 - 0.15) * CFrame.Angles(0, 0, math.pi / 4)
		f1.CFrame = cf * CFrame.new(0, 0, len / 2 - 0.25)
		f2.CFrame = f1.CFrame
	end
end

local flights = {}

local function spark(at)
	-- small and short (6A): a few bright chips and a quick flash, under a fifth of the shot's distance
	local flash = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = at, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 236, 190), Transparency = 0.2 })
	table.insert(flights, { kind = "flash", p = flash, t = 0, life = 0.16 })
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.random() * 0.6
		local chip = part({ Size = Vector3.one * 0.16, Position = at, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 150) })
		table.insert(flights, { kind = "chip", p = chip, t = 0, life = 0.22,
			vel = Vector3.new(math.cos(a) * 9, 7 + math.random() * 4, math.sin(a) * 9) })
	end
end

local function ballistaShot(from, model, index, aim, windUp, travel)
	local cfg = Config.TowerShots.Ballista
	local p = weaponOf(model)
	if p then
		local st = stateOf(p, model)
		if st.turns then
			-- the weapon's rest direction is from its centre to its bolt tip (the muzzle), flat
			local rest = Vector3.new(from.X - st.home.Position.X, 0, from.Z - st.home.Position.Z)
			local want = Vector3.new(aim.X - st.home.Position.X, 0, aim.Z - st.home.Position.Z)
			if rest.Magnitude > 0.1 and want.Magnitude > 0.1 then
				st.goalYaw = angleDiff(math.atan2(-want.X, -want.Z), math.atan2(-rest.X, -rest.Z))
			end
		end
		if not st.backDir then
			local r = Vector3.new(from.X - st.home.Position.X, 0, from.Z - st.home.Position.Z)
			st.backDir = r.Magnitude > 0.1 and -r.Unit or Vector3.zero
		end
		st.goalPull = cfg.Pull
		st.releaseAt = os.clock() + windUp
	end
	-- the bolt leaves on release, from where the (turned) weapon's tip is
	task.delay(windUp, function()
		local st = p and weapons[p]
		if st then
			st.goalPull = 0
			st.pull = -cfg.Pull * 0.3          -- (the snap: the string slams forward in one frame)
			st.kickVel = st.kickVel + cfg.Kick * 22
		end
		local start = from
		if st and st.turns then
			local c = st.home.Position
			local r = Vector3.new(from.X - c.X, 0, from.Z - c.Z)
			local turned = CFrame.Angles(0, st.yaw, 0) * r
			start = Vector3.new(c.X + turned.X, from.Y, c.Z + turned.Z)
		end
		local dist = (aim - start).Magnitude
		local m, place = bolt(math.clamp(dist * 0.06, 1.4, 2.4))
		table.insert(flights, { kind = "bolt", m = m, place = place, from = start, to = aim, t = 0, life = math.max(travel, 0.05),
			arc = dist * cfg.Arc })
	end)
end

Remotes.CombatFx.OnClientEvent:Connect(function(name, from, model, kind, index, aim, windUp, travel)
	if name ~= "TowerShot" then
		return
	end
	if kind == "Ballista" then
		ballistaShot(from, model, index, aim, windUp, travel)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local cfg = Config.TowerShots.Ballista
	for p, st in weapons do
		if not p.Parent then
			weapons[p] = nil
			continue
		end
		st.yaw, st.yawVel = spring(st.yaw, st.yawVel, st.goalYaw, cfg.TurnSpeed, cfg.TurnDamp, dt)
		st.pull, st.pullVel = spring(st.pull, st.pullVel, st.goalPull, 260, 26, dt)
		st.kick, st.kickVel = spring(st.kick, st.kickVel, 0, 170, 16, dt)
		-- the turn about the weapon's own centre; the pull and the kick move it back along its aim (away from the tip)
		local c = st.home.Position
		local turn = CFrame.Angles(0, st.turns and st.yaw or 0, 0)
		local cf = CFrame.new(c) * turn * CFrame.new(-c) * st.home
		p.CFrame = cf + (turn * (st.backDir or Vector3.zero)) * (st.pull + st.kick)
	end
	for i = #flights, 1, -1 do
		local f = flights[i]
		f.t += dt
		local a = math.min(f.t / f.life, 1)
		if f.kind == "bolt" then
			local pos = f.from:Lerp(f.to, a) + Vector3.new(0, f.arc * 4 * a * (1 - a), 0)
			local ahead = f.from:Lerp(f.to, math.min(a + 0.02, 1)) + Vector3.new(0, f.arc * 4 * math.min(a + 0.02, 1) * (1 - math.min(a + 0.02, 1)), 0)
			if (ahead - pos).Magnitude > 1e-3 then
				f.place(CFrame.lookAt(pos, ahead))
			end
			if a >= 1 then
				spark(f.to)
				f.m:Destroy()
				table.remove(flights, i)
			end
		elseif f.kind == "flash" then
			f.p.Size = Vector3.one * (0.6 + 1.6 * a)
			f.p.Transparency = 0.2 + 0.8 * a
			if a >= 1 then
				f.p:Destroy()
				table.remove(flights, i)
			end
		elseif f.kind == "chip" then
			f.vel += Vector3.new(0, -40, 0) * dt
			f.p.Position += f.vel * dt
			f.p.Transparency = a
			if a >= 1 then
				f.p:Destroy()
				table.remove(flights, i)
			end
		end
	end
end)
