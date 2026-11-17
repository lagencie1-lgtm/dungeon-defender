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

-- a zig-zag lightning bolt
function Effects.Lightning(from, to, color)
	local points = { from }
	local steps = 4
	for i = 1, steps - 1 do
		local p = from:Lerp(to, i / steps)
		table.insert(points, p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.5)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local p = fxPart({
			Size = Vector3.new(0.35, 0.35, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color,
		})
		TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		Debris:AddItem(p, 0.2)
	end
end

-- a quick "kick back" when a defender shoots
function Effects.Kick(part, amount)
	if not part or not part.Parent then
		return
	end
	local home = part:GetAttribute("HomeCFrame")
	if not home then
		home = part.CFrame
		part:SetAttribute("HomeCFrame", home)
	end
	part.CFrame = home * CFrame.new(0, -(amount or 0.4), 0)
	TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = home }):Play()
end

-- a speech bubble over something's head
local bubbleCount = 0
function Effects.Bubble(adornee, text, color, seconds)
	if bubbleCount >= 8 or not adornee or not adornee.Parent then
		return -- not too many at once
	end
	bubbleCount += 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(180, 34)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.1
	frame.TextColor3 = color or Color3.fromRGB(30, 30, 30)
	frame.Font = Enum.Font.GothamBold
	frame.TextScaled = true
	frame.Text = text
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.4, 0)
	c.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = frame
	gui.Parent = adornee
	task.delay(seconds or 2.5, function()
		bubbleCount -= 1
		gui:Destroy()
	end)
end

return Effects
