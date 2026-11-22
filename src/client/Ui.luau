-- Small helpers for building the game screen, plus click sounds and
-- a bouncy hover effect on every button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Gamepad = require(script.Parent.Gamepad)

local Ui = {}
Ui.Gamepad = Gamepad

Ui.isTouch = (UserInputService.TouchEnabled and UserInputService.PreferredInput == Enum.PreferredInput.Touch)
	or (RunService:IsStudio() and ReplicatedStorage:FindFirstChild("MobileTest") ~= nil)

function Ui.fitRoot(gui, root, mobileWidth, mobileHeight)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local width, height = 1280, 720
		-- a TV is far away: with a controller the screens may grow up to 1.5x (1080p shows the full
		-- 1280x720 layout at 1.5x, so the smallest HUD text is about 18 pixels or more)
		local biggest = Gamepad.active and 1.5 or 1.3
		if Ui.isTouch then
			width, height = mobileWidth, mobileHeight
			biggest = 1.3
		end
		local factor = math.min(size.X / width, size.Y / height, biggest)
		scale.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	Gamepad.OnChanged(fit)
	fit()
	return scale
end

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

-- puts a painted 9-slice image (the UI kit, art/ui) behind a frame or button: its border keeps its size,
-- the middle stretches. Waits for the image to load; until then the plain colours show.
-- `border` is the painted border width in image pixels, `width` how wide it shows on screen.
local KIT = {
	ui_panel = { border = 50, width = 20 },
	ui_button = { border = 66, width = 12 },
	ui_slot = { border = 66, width = 10 },
	ui_parchment = { border = 34, width = 12 },
	ui_ribbon = { border = 120, width = 30 },
}
function Ui.skin(obj, name, tint)
	-- Native text stays on the same render layer as its button on every device.
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		return
	end
	local kit = KIT[name]
	if not kit or obj:FindFirstChild("Skin") then
		return
	end
	local images = ReplicatedStorage:WaitForChild("ArtImages", 10)
	local function apply()
		local image = images and images:GetAttribute(name)
		if not image or obj:FindFirstChild("Skin") then
			return image ~= nil
		end
		local skin = Ui.make("ImageLabel", {
			Name = "Skin",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = image,
			ImageColor3 = tint or Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(kit.border, kit.border, 512 - kit.border, 512 - kit.border),
			SliceScale = kit.width / kit.border,
			ZIndex = obj.ZIndex > 1 and obj.ZIndex or 0,
			Parent = obj,
		})
		local connection
		local function reveal()
			if not skin.IsLoaded then
				return
			end
			connection:Disconnect()
			obj.BackgroundTransparency = 1
			local stroke = obj:FindFirstChildOfClass("UIStroke")
			if stroke and stroke.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Contextual then
				stroke.Enabled = false
			end
		end
		connection = skin:GetPropertyChangedSignal("IsLoaded"):Connect(reveal)
		reveal()
		return true
	end
	if not apply() and images then
		local connection
		connection = images:GetAttributeChangedSignal(name):Connect(function()
			if apply() then
				connection:Disconnect()
			end
		end)
	end
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
	local b = Ui.make("TextButton", defaults, { Ui.corner(Ui.isTouch and 8 or 10), Ui.stroke(nil, Ui.isTouch and 1 or 2) })
	-- painted brass-and-wood button, tinted with the button's own colour
	b.TextStrokeTransparency = 0.35
	Ui.skin(b, "ui_button", defaults.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.25))
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

-- The picture of a reward (season pass, daily reward): a gem pile, a gold stack, a medal, or a preview of a skin
-- (its defender's picture or a cape, in the skin's own colours). `reward` = { Kind, Amount, Id }, `skin` = the
-- skin's entry from Store.Skins for Kind "Skin". Fills `parent`. Returns the frame it made.
local TOWER_PICTURE = { Ranger = "tower_ranger", FlameCannon = "tower_flame", FrostCrystal = "tower_frost",
	StormObelisk = "tower_storm", Ballista = "tower_ballista" }
function Ui.rewardPicture(parent, reward, skin, zIndex)
	local Art = require(game:GetService("ReplicatedStorage").Shared.Art)
	local holder = Ui.make("Frame", { Name = "RewardPicture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		ZIndex = zIndex or 1, Parent = parent })
	local name, tint = nil, Color3.new(1, 1, 1)
	if reward.Kind == "Gems" then
		name = (reward.Amount or 0) >= 40 and "reward_gems_big" or "reward_gems_small"
	elseif reward.Kind == "Gold" then
		name = (reward.Amount or 0) >= 400 and "reward_gold_big" or "reward_gold_small"
	elseif reward.Kind == "Title" then
		name = "reward_title"
	elseif reward.Kind == "Skin" and skin then
		if skin.Target == "Cape" then
			name, tint = "reward_cape", skin.Primary
		else
			name = TOWER_PICTURE[skin.Target]
			-- the defender on a plate in the skin's colours
			holder.BackgroundTransparency = 0
			holder.BackgroundColor3 = skin.Primary
			Ui.make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = holder })
			Ui.make("UIStroke", { Color = skin.Accent or Color3.new(1, 1, 1), Thickness = 3, Parent = holder })
			tint = (skin.Accent or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.55)
		end
	end
	local image = name and Art.Image(name)
	if image then
		Ui.make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
			Image = image, ImageColor3 = tint, ScaleType = Enum.ScaleType.Fit, ZIndex = (zIndex or 1) + 1, Parent = holder })
	end
	return holder, image ~= nil
end

-- make something pop (bigger for a moment)
function Ui.pop(guiObject, amount)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", { Parent = guiObject })
	scale.Scale = amount or 1.25
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Ui
