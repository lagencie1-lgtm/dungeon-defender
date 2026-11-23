-- The Ranger's archers come alive (coordinator 2026-11-23: "it turns toward the target, draws and releases on each
-- shot, idle breathing; level 3's two archers do not mirror each other"). The server places each archer (its own
-- painted model "ranger_archer": Head, Body, ArmL, ArmR, Bow, Quiver) and, on every shot, sets AimX/AimZ and counts
-- Shots up. Here, on the client only: the archer turns (spring) to face the target, raises the bow arm and draws with
-- the other arm, lets go (a small kick back), and lowers the bow again a while after the last shot; between shots he
-- breathes. Springs, no linear tweens (6A). Nothing here changes the game; it is how it looks.
local RunService = game:GetService("RunService")

local archers = {} -- [model] = state

local function setup(archer)
	if archers[archer] or not archer:IsA("Model") then
		return
	end
	local pivot = archer:GetPivot()
	local box, size = archer:GetBoundingBox()
	local feet = pivot:PointToObjectSpace(box.Position - Vector3.new(0, size.Y / 2, 0))
	local parts = {}
	for _, p in archer:GetChildren() do
		if p:IsA("BasePart") then
			parts[p.Name] = { part = p, rel = pivot:ToObjectSpace(p.CFrame), size = p.Size }
		end
	end
	local function shoulder(name)
		local info = parts[name]
		if not info then
			return Vector3.zero
		end
		-- the top of the arm, a little inside it: where it turns
		return info.rel.Position + Vector3.new(0, info.size.Y * 0.42, 0)
	end
	archers[archer] = {
		model = archer,
		pivot = pivot,
		feet = feet,
		height = size.Y,
		parts = parts,
		shoulderL = shoulder("ArmL"),
		shoulderR = shoulder("ArmR"),
		yaw = 0, yawVel = 0,
		draw = 0, drawVel = 0,
		kick = 0, kickVel = 0,
		shots = archer:GetAttribute("Shots") or 0,
		lastShot = -10,
		phase = archer:GetAttribute("Phase") or math.random() * 6,
		baseYaw = math.rad(archer:GetAttribute("Yaw") or 0),
	}
end

local function watch(folder)
	for _, d in folder:GetDescendants() do
		if d.Name == "Archer" then
			setup(d)
		end
	end
	folder.DescendantAdded:Connect(function(d)
		if d.Name == "Archer" then
			task.defer(setup, d)
		end
	end)
end

task.spawn(function()
	local towers = workspace:WaitForChild("Towers", 60)
	if towers then
		watch(towers)
	end
end)

-- a damped spring step (stiffness k, damping c) toward `goal`
local function spring(x, v, goal, k, c, dt)
	local a = (goal - x) * k - v * c
	v += a * dt
	return x + v * dt, v
end

local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local now = os.clock()
	for archer, st in archers do
		if not archer.Parent then
			archers[archer] = nil
			continue
		end
		-- a new shot: draw again, and let go a moment later
		local shots = archer:GetAttribute("Shots") or 0
		if shots ~= st.shots then
			st.shots = shots
			st.lastShot = now
		end
		local since = now - st.lastShot
		-- face the target: the yaw that turns his front (-Z) toward it, relative to how he was placed
		local goalYaw = 0
		local ax, az = archer:GetAttribute("AimX"), archer:GetAttribute("AimZ")
		if ax and since < 2.5 then
			local feetWorld = st.pivot:PointToWorldSpace(st.feet)
			local dx, dz = ax - feetWorld.X, az - feetWorld.Z
			if dx * dx + dz * dz > 0.25 then
				goalYaw = angleDiff(math.atan2(-dx, -dz), st.baseYaw)
			end
		end
		st.yaw, st.yawVel = spring(st.yaw, st.yawVel, st.yaw + angleDiff(goalYaw, st.yaw), 90, 15, dt)
		-- the bow comes up for a shot (drawn within 0.12 s), stays up between quick shots, goes down after a while
		local goalDraw = since < 1.4 and 1 or 0
		st.draw, st.drawVel = spring(st.draw, st.drawVel, goalDraw, 160, 22, dt)
		-- the release: the string hand flies back a little 0.15 s after each shot, then settles (overshoot)
		if since > 0.15 and since < 0.17 and st.kick < 0.5 then
			st.kickVel = 9
		end
		st.kick, st.kickVel = spring(st.kick, st.kickVel, 0, 220, 14, dt)
		local breathe = math.sin(now * 1.7 + st.phase) * 0.012 * st.height

		local frame = st.pivot * CFrame.new(st.feet) * CFrame.Angles(0, st.yaw, 0) * CFrame.new(-st.feet)
		local d = math.clamp(st.draw, -0.2, 1.2)
		for name, info in st.parts do
			local cf
			if name == "ArmL" or name == "Bow" then
				-- the bow arm swings forward and up to point at the target
				local s = st.shoulderL
				local arm = CFrame.new(s) * CFrame.Angles(math.rad(84) * d, 0, math.rad(-6) * d) * CFrame.new(-s)
				cf = frame * arm * info.rel
				if name == "Bow" then
					-- the bow stands upright across the line of the shot
					cf = cf * CFrame.Angles(math.rad(-84) * d, math.rad(90) * d, 0)
				end
			elseif name == "ArmR" then
				-- the string arm comes up and in to the cheek; the release kicks it back
				local s = st.shoulderR
				local arm = CFrame.new(s)
					* CFrame.Angles(math.rad(78) * d - math.rad(18) * st.kick, math.rad(-38) * d, math.rad(10) * d)
					* CFrame.new(-s)
				cf = frame * arm * info.rel
			elseif name == "Head" then
				cf = frame * CFrame.new(0, breathe * 1.3, 0) * info.rel
			else
				cf = frame * CFrame.new(0, breathe, 0) * info.rel
			end
			info.part.CFrame = cf
		end
	end
end)
