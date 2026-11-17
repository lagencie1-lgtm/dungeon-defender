-- Short visual effects: arrows, explosions, frost rings, sword swings.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local function folder()
	return workspace:FindFirstChild("Effects") or workspace
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
	local p = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Position = position,
		Color = color,
		Transparency = transparency or 0.3,
	})
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, time)
end

-- a flat ring on the ground that spreads out
function Effects.Ring(position, radius, color, time)
	time = time or 0.4
	local p = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = 0.2,
	})
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, time)
end

-- floating text, like damage numbers or "+15 gold"
function Effects.Text(position, text, color)
	local anchor = fxPart({ Size = Vector3.one * 0.1, Position = position, Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 30)
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

return Effects
