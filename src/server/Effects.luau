-- Short visual effects: arrows, explosions, frost rings, sword swings.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = {}

-- These short-lived effects are visual. Gameplay and attack telegraphs stay on the server.
for _, name in { "Arc", "Bolt", "Burst", "Lightning", "Particles", "Shards", "Text" } do
	Effects[name] = function(...)
		Remotes.CombatFx:FireAllClients(name, ...)
	end
end

function Effects.Projectile(from, to, color, size, time, onHit)
	time = time or 0.25
	Remotes.CombatFx:FireAllClients("Projectile", from, to, color, size, time)
	if onHit then
		task.delay(time, onHit)
	end
end

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

Effects.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
}

-- a shockwave ring + smoke on the ground
function Effects.Shockwave(position, radius, color)
	Effects.Ring(position + Vector3.new(0, 0.3, 0), radius, color, 0.45)
	Effects.Particles(position + Vector3.new(0, 0.5, 0), { Texture = "Smoke", Color = Color3.fromRGB(180, 170, 160), Count = 16,
		Size = radius * 0.35, EndSize = 1.5, Speed = radius * 1.5, Life = 0.8, Spread = 80, LightEmission = 0 })
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
