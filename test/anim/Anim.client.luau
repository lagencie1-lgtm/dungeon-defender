-- Animation test rig client: a real run as the Swordmaster, every move filmed from close by, plus numbers
-- (feet against the ground, torso upright, head height, joint turns at rest) printed as [ANIM] lines.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local cue = ReplicatedStorage.AnimCue
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function mark(name)
	print("[FILM]", DateTime.now().UnixTimestampMillis, name)
end
local function say(...)
	print("[ANIM]", ...)
end
local waiting = {}
cue.OnClientEvent:Connect(function(step)
	waiting[step] = true
end)
local function await(step, limit)
	local deadline = os.clock() + (limit or 60)
	while not waiting[step] and os.clock() < deadline do
		task.wait(0.1)
	end
	waiting[step] = nil
end

local character = player.Character or player.CharacterAdded:Wait()
player.CharacterAdded:Connect(function(c)
	character = c
end)
local function rootPart()
	return character and character:FindFirstChild("HumanoidRootPart")
end
local function humanoidOf()
	return character and character:FindFirstChildOfClass("Humanoid")
end

-------------------------------------------------------------------------------
-- measuring every frame
-------------------------------------------------------------------------------
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(pos)
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("Enemies") }
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	return hit and hit.Position.Y
end
local function lowestY(part)
	local cf, s = part.CFrame, part.Size / 2
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, (cf * Vector3.new(s.X * x, s.Y * y, s.Z * z)).Y)
			end
		end
	end
	return low
end

local seg = nil -- the segment being measured
local function begin(name)
	seg = { name = name, footMin = math.huge, footMax = -math.huge, upMin = 1, headMin = math.huge, bodyMin = math.huge,
		frames = 0, grounded = 0 }
end
local function finish()
	if not seg then
		return
	end
	local s = seg
	seg = nil
	say(string.format("%-14s frames %3d  feet gap (grounded frames) min %.2f max %.2f  torso up min %.2f  head above ground min %.2f  lowest body part %.2f",
		s.name, s.frames, s.footMin == math.huge and 0 or s.footMin, s.footMax == -math.huge and 0 or s.footMax,
		s.upMin, s.headMin, s.bodyMin))
end
RunService.Heartbeat:Connect(function()
	if not seg or not character then
		return
	end
	local root, h = rootPart(), humanoidOf()
	if not root or not h then
		return
	end
	seg.frames += 1
	local g = groundBelow(root.Position)
	if not g then
		return
	end
	-- feet only count while the humanoid stands (not in the air during the leap)
	local state = h:GetState()
	local standing = h.FloorMaterial ~= Enum.Material.Air and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Jumping
	if standing then
		seg.grounded += 1
		for _, n in { "LeftFoot", "RightFoot" } do
			local f = character:FindFirstChild(n)
			if f then
				local gf = groundBelow(f.Position) or g
				local gap = lowestY(f) - gf
				seg.footMin = math.min(seg.footMin, gap)
				seg.footMax = math.max(seg.footMax, gap)
			end
		end
	end
	local ut = character:FindFirstChild("UpperTorso")
	if ut then
		seg.upMin = math.min(seg.upMin, ut.CFrame.UpVector.Y)
	end
	local head = character:FindFirstChild("Head")
	if head then
		seg.headMin = math.min(seg.headMin, lowestY(head) - g)
	end
	for _, p in character:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			seg.bodyMin = math.min(seg.bodyMin, lowestY(p) - g)
		end
	end
end)

-- every joint's turn at rest (degrees from its plain pose), to compare over time: Transform piling up shows here
local rest = {}
local function checkpoint(name)
	local line = {}
	local motors = 0
	for _, m in character:GetDescendants() do
		if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then
			motors += 1
		end
	end
	local h, root = humanoidOf(), rootPart()
	local g = root and groundBelow(root.Position)
	local hit = root and workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	local kinds = {}
	for _, n in { "RightShoulder", "Root", "RightHip", "Neck" } do
		local found = character:FindFirstChild(n, true)
		table.insert(kinds, n .. "=" .. (found and (found.ClassName .. " in " .. found.Parent.Name) or "none"))
	end
	say("joints " .. table.concat(kinds, ", "))
	say(string.format("body %s parts %d motors %d rig %s hipheight %.2f root above ground %.2f ground is %s scale %.2f",
		character:GetFullName(), #character:GetChildren(), motors, h and tostring(h.RigType) or "?", h and h.HipHeight or -1,
		(root and g) and (root.Position.Y - root.Size.Y / 2 - g) or -1, hit and hit.Instance:GetFullName() or "nothing",
		character:GetScale()))
	for _, m in character:GetDescendants() do
		if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then
			local _, angle = m.Transform:ToAxisAngle()
			local deg = math.deg(angle)
			local first = rest[m.Name]
			if not first then
				rest[m.Name] = deg
				first = deg
			end
			table.insert(line, string.format("%s %.0f(%+.0f)", m.Name, deg, deg - first))
		end
	end
	table.sort(line)
	say("rest " .. name .. ": " .. table.concat(line, " "))
end

-------------------------------------------------------------------------------
-- camera: close by the hero, following him
-------------------------------------------------------------------------------
local view = nil -- function(rootCFrame) -> camera CFrame, or nil for the game's own camera
local anchorCF = nil
RunService:BindToRenderStep("AnimCam", Enum.RenderPriority.Camera.Value + 1, function()
	local root = rootPart()
	if view and root then
		camera.CameraType = Enum.CameraType.Scriptable
		local base = anchorCF and CFrame.new(root.Position) * anchorCF.Rotation or root.CFrame
		camera.CFrame = view(base)
	end
end)
local function side(dist, up)
	return function(cf)
		local at = cf.Position + Vector3.new(0, 0.3, 0)
		return CFrame.lookAt(at + cf.RightVector * dist + Vector3.new(0, up or 1, 0) + cf.LookVector * dist * 0.15, at)
	end
end
local function threeQuarter(dist, up)
	return function(cf)
		local at = cf.Position + Vector3.new(0, 0.3, 0)
		return CFrame.lookAt(at + (cf.LookVector + cf.RightVector * 0.8).Unit * dist + Vector3.new(0, up or 3, 0), at)
	end
end
local function gameCam()
	view = nil
	anchorCF = nil
	camera.CameraType = Enum.CameraType.Custom
end
-- hold the camera's direction still (the spin would turn a body-locked camera with him)
local function lockDirection()
	local root = rootPart()
	anchorCF = root and root.CFrame
end

local function walk(target, limit)
	local h = humanoidOf()
	if not h then
		return
	end
	h:MoveTo(target)
	local done = false
	local c = h.MoveToFinished:Connect(function()
		done = true
	end)
	local deadline = os.clock() + (limit or 8)
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	c:Disconnect()
end
local function face(dir)
	local root = rootPart()
	if root then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(dir.X, 0, dir.Z))
	end
end

-- the Swordmaster's leap, as the HUD's R button does it
local function leap()
	local r, h = rootPart(), humanoidOf()
	if not r or not h then
		return
	end
	h:ChangeState(Enum.HumanoidStateType.Jumping)
	local forward = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit
	r.AssemblyLinearVelocity = forward * (Config.Hero.Leap.Distance * 1.8) + Vector3.new(0, 55, 0)
	Remotes.HeroLeap:FireServer()
end

-------------------------------------------------------------------------------
-- the route
-------------------------------------------------------------------------------
character:WaitForChild("Humanoid")
workspace:WaitForChild("Outpost")
task.wait(12)
mark("film start")
say("hero", player:GetAttribute("HeroId") or "Swordmaster (default)")

-- knock-out only (test/anim-ko.project.json): the fall, measured part by part against the ground
local function lowestParts()
	local worst, worstName, perPart = math.huge, "", {}
	for _, p in character:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			local g = groundBelow(p.Position)
			if g then
				local gap = lowestY(p) - g
				perPart[p.Name] = gap
				if gap < worst then
					worst, worstName = gap, p.Name
				end
			end
		end
	end
	return worst, worstName, perPart
end
-- the rigged goblin in a real run (test/anim-goblin.project.json): walking from 3/4 and side, bashing the
-- hero, hit, knocked out; feet measured against the ground, frame time
-- the rigged goblin alone (test/anim-goblin.project.json): one goblin spawned on an empty path, its run from the
-- side and 3/4, two hits from the hero's side, then knocked out; feet, bob and step rate measured
if cue:GetAttribute("Mode") == "goblin" then
	cue:FireServer("StartRun", "CursedForest")
	await("RunReady", 60)
	task.wait(10) -- the models load
	local pts0 = Config.Path
	local folder = workspace:WaitForChild("Enemies")
	walk(pts0[2] + (pts0[3] - pts0[2]) * 0.5 + Vector3.new(10, 0, 0), 12)
	workspace:SetAttribute("MonsterAnimDebug", true)
	cue:FireServer("SpawnGoblin", 0)
	local m
	local deadline = os.clock() + 10
	while not m and os.clock() < deadline do
		for _, x in folder:GetChildren() do
			if x:GetAttribute("Rigged") then
				m = x
			end
		end
		task.wait(0.1)
	end
	if not m then
		say("no rigged goblin appeared")
		say("DONE")
		cue:FireServer("Done")
		return
	end
	local function bone(name)
		for _, d in m:GetDescendants() do
			if d:IsA("Bone") and (string.gsub(d.Name, "[^%w]", "")) == name then
				return d
			end
		end
	end
	local fl, fr, hips = bone("FootL"), bone("FootR"), bone("Hips")
	task.wait(0.3)
	local rest = fl and (fl.TransformedWorldCFrame.Position.Y - (groundBelow(fl.TransformedWorldCFrame.Position) or 0)) or 0.27
	say(string.format("ankle bone at rest %.2f above the ground", rest))
	local function threeQ(dist, up)
		return function(cf)
			local at = cf.Position + Vector3.new(0, 1, 0)
			return CFrame.lookAt(at + (cf.LookVector + cf.RightVector * 0.9).Unit * dist + Vector3.new(0, up, 0), at)
		end
	end
	local function sideOf(dist, up)
		return function(cf)
			local at = cf.Position + Vector3.new(0, 1, 0)
			return CFrame.lookAt(at + cf.RightVector * dist + Vector3.new(0, up, 0), at)
		end
	end
	-- frame time, all through
	local frames, total, worst = 0, 0, 0
	local fconn = RunService.RenderStepped:Connect(function(dt)
		frames += 1
		total += dt
		worst = math.max(worst, dt)
	end)
	local function follow(view_, seconds, label)
		local lastL, lastR, lastPlanted = nil, nil, nil
		local contacts, slide, slideFrames, worstContact = 0, 0, 0, 0
		local contactSlide = 0
		local bobMin, bobMax = math.huge, -math.huge
		local t0 = os.clock()
		mark(label)
		while os.clock() - t0 < seconds and m.Parent and not m:GetAttribute("Dead") do
			local cf = m:GetPivot()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = view_(cf)
			if fl and fr and hips then
				local pl, pr = fl.TransformedWorldCFrame.Position, fr.TransformedWorldCFrame.Position
				local gl, gr = groundBelow(pl) or cf.Position.Y, groundBelow(pr) or cf.Position.Y
				local hl, hr = pl.Y - gl, pr.Y - gr
				local bob = hips.TransformedWorldCFrame.Position.Y - cf.Position.Y
				bobMin, bobMax = math.min(bobMin, bob), math.max(bobMax, bob)
				-- which foot MonsterAnim has planted (its debug attribute)
				local down = m:GetAttribute("FootDown")
				local planted = (down == "L" or down == "R") and down or nil
				if planted and planted == lastPlanted and lastL then
					local p, lp = planted == "L" and pl or pr, planted == "L" and lastL or lastR
					local d = Vector3.new(p.X - lp.X, 0, p.Z - lp.Z).Magnitude
					contactSlide += d
					slide += d
					slideFrames += 1
				elseif planted ~= lastPlanted then
					if lastPlanted then
						worstContact = math.max(worstContact, contactSlide)
					end
					contactSlide = 0
					if planted then
						contacts += 1
					end
				end
				lastPlanted = planted
				lastL, lastR = pl, pr
			end
			RunService.RenderStepped:Wait()
		end
		local secs = os.clock() - t0
		local n0, s0 = m:GetAttribute("SlideContacts0") or 0, m:GetAttribute("SlideTotal0") or 0
		local n1, s1 = m:GetAttribute("SlideContacts") or 0, m:GetAttribute("SlideTotal") or 0
		m:SetAttribute("SlideContacts0", n1)
		m:SetAttribute("SlideTotal0", s1)
		say(string.format("%s, measured inside MonsterAnim right after posing: %d contacts, %.3f studs per contact, worst contact so far %.3f",
			label, n1 - n0, (s1 - s0) / math.max(n1 - n0, 1), m:GetAttribute("SlideWorst") or 0))
		m:SetAttribute("SlideWorst", 0)
		say(string.format("%s: %d foot contacts in %.1f s (%.2f steps/s); planted foot slid %.3f studs per contact on average, worst contact %.3f (%d frames in contact); hips bob %.2f studs (%.2f..%.2f over the pivot)",
			label, contacts, secs, contacts / secs, slide / math.max(contacts, 1), worstContact, slideFrames, bobMax - bobMin, bobMin, bobMax))
	end
	follow(sideOf(12, 1.5), 6, "run side")
	follow(threeQ(12, 3.5), 5, "run 3/4")
	-- two hits from the hero's side, then out
	local cf = m:GetPivot()
	local spot = cf.Position + cf.RightVector * 7 + cf.LookVector * 3
	rootPart().CFrame = CFrame.new(Vector3.new(spot.X, rootPart().Position.Y, spot.Z))
	mark("hit from the side")
	for _ = 1, 2 do
		cue:FireServer("HitEnemy", m)
		local t1 = os.clock()
		while os.clock() - t1 < 0.6 and m.Parent do
			camera.CFrame = sideOf(-10, 2)(m:GetPivot())
			RunService.RenderStepped:Wait()
		end
	end
	say("hit from", tostring(m:GetAttribute("HitFromX")), tostring(m:GetAttribute("HitFromZ")))
	local fallCF = m:GetPivot()
	mark("knock out alone")
	cue:FireServer("KillEnemy", m)
	local t2 = os.clock()
	while os.clock() - t2 < 2.2 do
		camera.CFrame = sideOf(-9, 1.5)(fallCF) -- (from the far side: the hero stands on the near one)
		RunService.RenderStepped:Wait()
	end
	say("dead", tostring(m:GetAttribute("Dead")), "removed", tostring(m.Parent == nil))
	fconn:Disconnect()
	say(string.format("frame time: %d frames, mean %.1f ms, worst %.1f ms", frames, total / math.max(frames, 1) * 1000, worst * 1000))
	camera.CameraType = Enum.CameraType.Custom
	say("DONE")
	mark("film end")
	cue:FireServer("Done")
	return
end

if cue:GetAttribute("Mode") == "ko" then
	local c0 = Config.OutpostCenter
	walk(c0 + Vector3.new(0, 0, 10), 5)
	cue:FireServer("StartRun", "CursedForest")
	await("RunReady", 60)
	task.wait(6)
	for take = 1, 3 do
		local pts0 = Config.Path
		if take < 3 then
			-- off the spawn pad, onto the open map ground (beside a wall and a grass bank)
			walk(rootPart().Position + (pts0[#pts0] - pts0[#pts0 - 1]).Unit * -14, 5)
		else
			-- the middle of the goblins' path: open, flat ground
			local mid = pts0[math.floor(#pts0 / 2)]
			walk(mid, 12)
		end
		task.wait(1)
		lockDirection()
		view = side(9, 2)
		task.wait(0.5)
		local base = lowestParts()
		say(string.format("ko%d standing lowest before %.2f (terrain under the feet is not flat: compare with this)", take, base))
		mark("knock out " .. take)
		local t0 = os.clock()
		cue:FireServer("KO")
		local minPart = {}
		local nextPrint = 0
		while os.clock() - t0 < 3.2 do
			local worst, name, per = lowestParts()
			for n, g in per do
				minPart[n] = math.min(minPart[n] or math.huge, g)
			end
			local dt = os.clock() - t0
			if dt >= nextPrint then
				nextPrint += 0.25
				local ut = character:FindFirstChild("UpperTorso")
				local lt = character:FindFirstChild("LowerTorso")
				local rj = lt and lt:FindFirstChild("Root")
				local h = humanoidOf()
				local rx = rj and math.deg((rj.Transform:ToEulerAnglesYXZ())) or 0
				local r = rootPart()
				say(string.format("ko%d t %.2f lowest %.2f (%s) torso up %.2f chest faces up %.2f | root joint x %.0f kinematic %s hp %.0f root anchored %s root up %.2f",
					take, dt, worst, name, ut and ut.CFrame.UpVector.Y or 0, ut and ut.CFrame.LookVector.Y or 0, rx,
					rj and rj:IsA("AnimationConstraint") and (tostring(rj.IsKinematic) .. " enabled " .. tostring(rj.Enabled)) or "-", h and h.Health or -1,
					r and tostring(r.Anchored) or "?", r and r.CFrame.UpVector.Y or 0))
			end
			RunService.Heartbeat:Wait()
		end
		local parts = {}
		for n, g in minPart do
			table.insert(parts, string.format("%s %.2f", n, g))
		end
		table.sort(parts)
		say("ko" .. take .. " lowest point of each part over 3 s: " .. table.concat(parts, ", "))
		local worst, name = lowestParts()
		say(string.format("ko%d final lowest %.2f (%s)", take, worst, name))
		anchorCF = nil
		gameCam()
		mark("back " .. take)
		player.CharacterAdded:Wait()
		task.wait(3)
	end
	say("DONE")
	mark("film end")
	cue:FireServer("Done")
	return
end

-- a short walk in the Outpost: lean and stride (game camera)
local c = Config.OutpostCenter
mark("outpost walk")
begin("outpost walk")
walk(c + Vector3.new(0, 0, 10), 5)
walk(c + Vector3.new(8, 0, 0), 5)
finish()

mark("run start")
cue:FireServer("StartRun", "CursedForest")
await("RunReady", 60)
task.wait(6)
-- face along the path, on open ground
local pts = Config.Path
local hereDir = (pts[#pts] - pts[#pts - 1])
face(-hereDir)
task.wait(0.5)

view = side(9, 1)
mark("idle side")
begin("idle")
task.wait(3)
finish()
checkpoint("start")

for take, v in { { "side", side(8, 0.8) }, { "3/4", threeQuarter(9, 2.5) } } do
	view = v[2]
	task.wait(0.6)
	mark("combo " .. v[1])
	begin("combo " .. v[1])
	for i = 1, 3 do
		mark("attack " .. i)
		Remotes.HeroAttack:FireServer()
		task.wait(0.56)
	end
	task.wait(1.6)
	finish()
	mark("stance " .. v[1])
	begin("ready stance")
	task.wait(2)
	finish()
	task.wait(2.5)
	checkpoint("after combo " .. take)
end

for take, v in { { "3/4", threeQuarter(11, 5) }, { "side", side(10, 1.5) } } do
	lockDirection()
	view = v[2]
	task.wait(0.6)
	mark("whirlwind " .. v[1])
	begin("whirlwind " .. v[1])
	Remotes.HeroWhirlwind:FireServer()
	task.wait(1.6)
	finish()
	anchorCF = nil
	if take == 1 then
		task.wait(Config.Hero.Whirlwind.Cooldown - 1.5)
	end
	task.wait(1)
	checkpoint("after whirlwind " .. take)
end
face(-hereDir)
task.wait(0.3)

view = side(22, 3)
lockDirection()
task.wait(0.6)
mark("leap")
begin("leap")
leap()
task.wait(2.2)
finish()
anchorCF = nil
task.wait(1.5)
checkpoint("after leap")

view = side(8, 0.8)
task.wait(0.5)
mark("hurt")
begin("hurt")
for _ = 1, 2 do
	cue:FireServer("Hit", 6)
	task.wait(1.1)
end
finish()
cue:FireServer("Heal")

-- a real wave: stand on the path near where the goblins come in and let them hit (game camera)
gameCam()
mark("wave")
Remotes.StartWave:FireServer()
walk(pts[2] + Vector3.new(0, 0, 0), 10)
local h = humanoidOf()
local hp = h and h.Health or 0
local hits = 0
local conn = h and h.HealthChanged:Connect(function(n)
	if n < hp then
		hits += 1
		if hits == 1 then
			mark("goblin hit")
		end
	end
	hp = n
end)
local deadline = os.clock() + 30
while hits < 3 and os.clock() < deadline do
	task.wait(0.2)
end
if conn then
	conn:Disconnect()
end
say("goblin hits taken", hits)
cue:FireServer("Heal")
-- walk away and stand still a while: anything piling up over time shows in the rest numbers
walk(pts[2] + (pts[1] - pts[2]).Unit * -12 + Vector3.new(12, 0, 0), 6)
view = side(9, 1)
mark("long idle")
begin("long idle")
task.wait(12)
finish()
checkpoint("end")

view = side(10, 1.5)
lockDirection()
mark("knock out")
begin("knock out")
cue:FireServer("KO")
task.wait(4)
finish()
anchorCF = nil
mark("back")
task.wait(6)
say("DONE")
mark("film end")
cue:FireServer("Done")
