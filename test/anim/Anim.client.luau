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
	params.FilterDescendantsInstances = { character }
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
