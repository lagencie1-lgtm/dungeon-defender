-- Simple flat icons drawn from UI shapes, all in one style (no emoji).
-- Icons.Draw(parent, name, color) fills the parent with the icon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage.Shared.Art)

local Icons = {}

local function frame(parent, props, radius)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = radius
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local ROUND = UDim.new(0.5, 0)
local SOFT = UDim.new(0.18, 0)

-- an outlined ring (circle with a stroke and no fill)
local function ring(parent, pos, size, color, thickness)
	local r = frame(parent, { Position = pos, Size = size, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, ROUND)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 3
	s.Parent = r
	return r
end

local DRAW = {}

DRAW.Shop = function(box, c) -- a shopping bag
	frame(box, { Position = UDim2.fromScale(0.2, 0.38), Size = UDim2.fromScale(0.6, 0.52), BackgroundColor3 = c }, SOFT)
	local clip = frame(box, { Position = UDim2.fromScale(0.3, 0.12), Size = UDim2.fromScale(0.4, 0.28), BackgroundTransparency = 1,
		ClipsDescendants = true })
	ring(clip, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.85, 1.6), c, 3)
end

DRAW.Daily = function(box, c) -- a gift box
	frame(box, { Position = UDim2.fromScale(0.18, 0.38), Size = UDim2.fromScale(0.64, 0.5), BackgroundColor3 = c }, SOFT)
	frame(box, { Position = UDim2.fromScale(0.13, 0.26), Size = UDim2.fromScale(0.74, 0.16), BackgroundColor3 = c }, SOFT)
	local dark = c:Lerp(Color3.new(0, 0, 0), 0.45)
	frame(box, { Position = UDim2.fromScale(0.45, 0.26), Size = UDim2.fromScale(0.1, 0.62), BackgroundColor3 = dark })
	ring(box, UDim2.fromScale(0.4, 0.2), UDim2.fromScale(0.16, 0.14), c, 3)
	ring(box, UDim2.fromScale(0.6, 0.2), UDim2.fromScale(0.16, 0.14), c, 3)
end

DRAW.Backpack = function(box, c) -- a bag with a flap and a strap
	frame(box, { Position = UDim2.fromScale(0.22, 0.2), Size = UDim2.fromScale(0.56, 0.68), BackgroundColor3 = c }, UDim.new(0.25, 0))
	frame(box, { Position = UDim2.fromScale(0.22, 0.2), Size = UDim2.fromScale(0.56, 0.26), BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.3) },
		UDim.new(0.25, 0))
	frame(box, { Position = UDim2.fromScale(0.34, 0.6), Size = UDim2.fromScale(0.32, 0.16), BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.3) },
		SOFT)
end

DRAW.Heroes = function(box, c) -- two crossed swords
	for _, angle in { 45, -45 } do
		local blade = frame(box, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.12, 0.8), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = c, Rotation = angle }, UDim.new(0.4, 0))
		frame(blade, { Position = UDim2.fromScale(-1.2, 0.72), Size = UDim2.fromScale(3.4, 0.07), BackgroundColor3 = c })
	end
end

DRAW.Quests = function(box, c) -- a scroll
	frame(box, { Position = UDim2.fromScale(0.24, 0.2), Size = UDim2.fromScale(0.52, 0.62), BackgroundColor3 = c }, UDim.new(0.08, 0))
	for _, y in { 0.16, 0.78 } do
		frame(box, { Position = UDim2.fromScale(0.16, y), Size = UDim2.fromScale(0.68, 0.1), BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.3) },
			ROUND)
	end
	local ink = c:Lerp(Color3.new(0, 0, 0), 0.55)
	for i = 0, 2 do
		frame(box, { Position = UDim2.fromScale(0.32, 0.36 + i * 0.12), Size = UDim2.fromScale(i == 2 and 0.22 or 0.36, 0.05), BackgroundColor3 = ink },
			ROUND)
	end
end

DRAW.Pets = function(box, c) -- a paw print
	frame(box, { Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.42, 0.34), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = c }, ROUND)
	for _, p in { { 0.24, 0.4 }, { 0.4, 0.24 }, { 0.6, 0.24 }, { 0.76, 0.4 } } do
		frame(box, { Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromScale(0.17, 0.2), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = c }, ROUND)
	end
end

DRAW.Season = function(box, c) -- a trophy cup
	frame(box, { Position = UDim2.fromScale(0.26, 0.14), Size = UDim2.fromScale(0.48, 0.42), BackgroundColor3 = c }, UDim.new(0.45, 0))
	frame(box, { Position = UDim2.fromScale(0.26, 0.14), Size = UDim2.fromScale(0.48, 0.18), BackgroundColor3 = c })
	frame(box, { Position = UDim2.fromScale(0.45, 0.52), Size = UDim2.fromScale(0.1, 0.2), BackgroundColor3 = c })
	frame(box, { Position = UDim2.fromScale(0.3, 0.72), Size = UDim2.fromScale(0.4, 0.12), BackgroundColor3 = c }, SOFT)
	ring(box, UDim2.fromScale(0.24, 0.3), UDim2.fromScale(0.18, 0.2), c, 3)
	ring(box, UDim2.fromScale(0.76, 0.3), UDim2.fromScale(0.18, 0.2), c, 3)
end

DRAW.Gem = function(box, c) -- a diamond
	frame(box, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = c, Rotation = 45 }, UDim.new(0.12, 0))
	frame(box, { Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.2, 0.2), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.4, Rotation = 45 }, UDim.new(0.2, 0))
end

DRAW.Gold = function(box, c) -- a coin
	frame(box, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = c }, ROUND)
	ring(box, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.46, 0.46), c:Lerp(Color3.new(0, 0, 0), 0.35), 2)
end

DRAW.Lock = function(box, c) -- a padlock
	frame(box, { Position = UDim2.fromScale(0.25, 0.44), Size = UDim2.fromScale(0.5, 0.42), BackgroundColor3 = c }, SOFT)
	local clip = frame(box, { Position = UDim2.fromScale(0.3, 0.12), Size = UDim2.fromScale(0.4, 0.34), BackgroundTransparency = 1,
		ClipsDescendants = true })
	ring(clip, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.8, 1.6), c, 4)
	frame(box, { Position = UDim2.fromScale(0.46, 0.56), Size = UDim2.fromScale(0.08, 0.16), BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.6) },
		ROUND)
end

-- draws an icon into a square box inside `parent`, keeping it square
function Icons.Draw(parent, name, color, props)
	local box = Instance.new("Frame")
	box.Name = "Icon"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	for k, v in props or {} do
		box[k] = v
	end
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = box
	box.Parent = parent
	-- painted icon when it's uploaded, otherwise the simple drawn shape
	local image = Art.Image(name)
	if image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = box
		return box
	end
	local draw = DRAW[name]
	if draw then
		draw(box, color or Color3.fromRGB(230, 190, 110))
	end
	return box
end

return Icons
