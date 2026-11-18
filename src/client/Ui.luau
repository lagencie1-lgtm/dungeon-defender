-- Small helpers for building the game screen, plus click sounds and
-- a bouncy hover effect on every button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

Ui.GOLD = Color3.fromRGB(255, 210, 70)
Ui.MANA = Color3.fromRGB(170, 150, 255) -- the building money during a run
Ui.SCRAP = Color3.fromRGB(190, 170, 150)
Ui.GEM = Color3.fromRGB(90, 220, 255)
Ui.DARK = Color3.fromRGB(38, 27, 20) -- dark wood
Ui.PANEL = Color3.fromRGB(64, 45, 32) -- lighter wood
Ui.TEXT_DIM = Color3.fromRGB(225, 205, 175)
Ui.BAD = Color3.fromRGB(255, 120, 120)

function Ui.make(className, props, children)
	local obj = Instance.new(className)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = obj
	end
	obj.Parent = parent -- parent last, it's faster
	return obj
end

function Ui.corner(radius)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.stroke(color, thickness)
	return Ui.make("UIStroke", {
		Color = color or Color3.fromRGB(200, 160, 80), -- brass
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.make("TextLabel", defaults)
end

-- local sounds for clicks
local sounds = {}
local function sound(name)
	if not sounds[name] then
		local info = Config.Sounds[name]
		local s = Instance.new("Sound")
		s.SoundId = info.Id
		s.Volume = info.Volume or 0.5
		s.Parent = SoundService
		sounds[name] = s
	end
	return sounds[name]
end

function Ui.playSound(name)
	local info = Config.Sounds[name]
	if not info then
		return
	end
	local s = sound(name)
	if info.Pitch then
		s.PlaybackSpeed = info.Pitch[1] + math.random() * (info.Pitch[2] - info.Pitch[1])
	end
	SoundService:PlayLocalSound(s)
end

function Ui.button(props)
	local defaults = {
		BackgroundColor3 = Ui.PANEL,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = Ui.make("TextButton", defaults, { Ui.corner(10), Ui.stroke() })
	local scale = Ui.make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Ui.playSound("Click")
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	return b
end

-- make something pop (bigger for a moment)
function Ui.pop(guiObject, amount)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", { Parent = guiObject })
	scale.Scale = amount or 1.25
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Ui
