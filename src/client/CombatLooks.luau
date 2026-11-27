-- Short visual effects: arrows, explosions, frost rings, sword swings.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}
local tier = 0

function Effects.SetTier(value)
	tier = value
end

-- 6A restraint: effects are smaller and lighter than the first instinct
Effects.SizeScale = 0.6
Effects.CountScale = 0.5

local function folder()
	return workspace:FindFirstChild("LocalCombatEffects") or workspace
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder()
	return p
end

-- a small glowing bolt flying from one point to another
function Effects.Bolt(from, to, color, size, time)
	time = time or 0.15
	local p = fxPart({
		Size = Vector3.new(size or 0.4, size or 0.4, math.max((to - from).Magnitude * 0.3, 1)),
		CFrame = CFrame.lookAt(from, to),
		Color = color,
	})
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) }):Play()
	Debris:AddItem(p, time)
end

-- a ball that grows and fades (explosions, whirlwind, frost)
function Effects.Burst(position, radius, color, time, transparency)
	time = time or 0.35
	-- 6A: never a wall of colour; capped and see-through
	radius = math.min(radius * Effects.SizeScale, 6)
	local p = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Position = position,
		Color = color,
		Transparency = math.max(transparency or 0.3, 0.55),
	})
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, time)
end

-- floating text, like damage numbers or "+15 gold"
function Effects.Text(position, text, color, scale)
	scale = scale or 1
	local anchor = fxPart({ Size = Vector3.one * 0.1, Position = position, Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120 * scale, 30 * scale)
	gui.MaxDistance = 160
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end

-------------------------------------------------------------------------------
-- particles (textures that come with Roblox)
-------------------------------------------------------------------------------
Effects.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
}

-- a one-time puff of particles at a spot
-- opts: Texture, Color, Count, Size, Speed, Life, Spread (degrees), Drag, Gravity
function Effects.Particles(position, opts)
	local holder = fxPart({ Size = Vector3.one * 0.2, Position = position, Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = Effects.Textures[opts.Texture or "Sparkle"] or opts.Texture
	e.Color = ColorSequence.new(opts.Color or Color3.new(1, 1, 1), opts.Color2 or opts.Color or Color3.new(1, 1, 1))
	e.LightEmission = opts.LightEmission or 1
	local size = (opts.Size or 1) * Effects.SizeScale
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * (opts.EndSize or 0.2)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	local life = opts.Life or 0.6
	e.Lifetime = NumberRange.new(life * 0.6, life)
	local speed = opts.Speed or 12
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Drag = opts.Drag or 2
	e.Acceleration = Vector3.new(0, opts.Gravity or 0, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rate = 0
	e.Parent = holder
	e:Emit(math.max(1, math.floor((opts.Count or 20) * Effects.CountScale / (tier + 1))))
	Debris:AddItem(holder, life + 0.5)
end

-- a glowing ball that flies with a trail, then pops with sparks
function Effects.Projectile(from, to, color, size, time)
	time = time or 0.25
	size = size or 1
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = from, Color = color })
	if tier < 2 then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, size * 0.35, 0)
		a0.Parent = ball
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -size * 0.35, 0)
		a1.Parent = ball
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = 1
		trail.Lifetime = 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = ball
	end
	TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Linear), { Position = to }):Play()
	task.delay(time, function()
		ball.Transparency = 1
		Effects.Particles(to, { Color = color, Count = math.floor(10 + size * 8), Size = size * 0.8, Speed = 10 + size * 4, Life = 0.4 })
		Debris:AddItem(ball, 0.3)
	end)
end

-- pieces that fly outwards from a spot and fade (ice shards, rocks, splinters)
function Effects.Shards(position, radius, color, count, material)
	local pieces = math.max(3, math.floor((count or 10) / (tier + 1)))
	for i = 1, pieces do
		local angle = (i / pieces) * math.pi * 2 + math.random() * 0.4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local shard = fxPart({
			Size = Vector3.new(0.5, 0.5 + math.random() * 1.2, 0.5),
			CFrame = CFrame.lookAt(position, position + dir) * CFrame.Angles(math.rad(-60), 0, 0),
			Color = color,
			Material = material or Enum.Material.Neon,
			Transparency = 0.1,
		})
		local target = CFrame.lookAt(position + dir * radius + Vector3.new(0, math.random() * 2, 0), position + dir * (radius + 1))
			* CFrame.Angles(math.rad(-80), 0, 0)
		TweenService:Create(shard, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = target, Transparency = 1 }):Play()
		Debris:AddItem(shard, 0.5)
	end
end

-- a sword swing: a glowing arc in front of the hero
function Effects.Arc(cframe, radius, color, wide)
	local segments = 9 - tier * 2
	local spread = wide and math.rad(220) or math.rad(140)
	for i = 0, segments - 1 do
		local a = -spread / 2 + spread * i / (segments - 1)
		local piece = fxPart({
			Size = Vector3.new(0.25, 0.6, radius * spread / segments * 1.2),
			CFrame = cframe * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color,
			Transparency = 1,
		})
		task.delay(i * 0.012, function()
			piece.Transparency = 0.15
			TweenService:Create(piece, TweenInfo.new(0.22), { Transparency = 1, Size = piece.Size * Vector3.new(1, 0.2, 1) }):Play()
		end)
		Debris:AddItem(piece, 0.4)
	end
end

-- a zig-zag lightning bolt
function Effects.Lightning(from, to, color)
	local points = { from }
	local steps = 6 - tier   -- (more corners: jagged)
	for i = 1, steps - 1 do
		local p = from:Lerp(to, i / steps)
		table.insert(points, p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.5)
	end
	table.insert(points, to)
	-- (2026-11-27, shot polish: a thicker jagged bolt with a bright core, held a little longer so it registers on a phone)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local glow = fxPart({
			Size = Vector3.new(0.75, 0.75, (b - a).Magnitude + 0.3),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color,
			Transparency = 0.35,
		})
		local core = fxPart({
			Size = Vector3.new(0.26, 0.26, (b - a).Magnitude + 0.2),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = Color3.fromRGB(250, 245, 255),
		})
		for _, p in { glow, core } do
			TweenService:Create(p, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			Debris:AddItem(p, 0.28)
		end
	end
end

return Effects
