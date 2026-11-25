-- Only in the device pass builds (scripts/device_pass.py makes one per device; Studio's Device Emulator shows the
-- device). At each step the server asks for (Outpost, Shop, Pets, Backpack, Run, Defender) this script measures the
-- screen, prints the results, draws thin outlines of Roblox's own touch controls and the TV-safe frame, and holds
-- still while the runner takes a screenshot.
--
-- Rules (numbers checked here; the runner turns them into the labelled sheet):
--   Cut      nothing of ours sticks out of its screen area (the safe area: no notch, no Roblox top bar)   2 px slack
--   TV safe  with a controller, every button and text sits inside the middle 90% of the TV (5% margin per side)
--   Thumbs   on touch, no button of ours lies on the jump button or the thumbstick's resting place
--   Tap      on touch, buttons always on screen are at least 44 px tall and wide, buttons in a panel at least 36
--   Text     text at least 11 px tall on phones and tablets, 12 on PC, 18 per 1080 lines of TV
--   Fits     no text cut off (TextFits)
--   Overlap  no two buttons on top of each other (more than 20% of the smaller one) while no panel is open
--   Road     in a run, at most 8% of the road ahead (middle 40% wide, 18-45% down) under our UI, chips and text too
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local probe = ReplicatedStorage:WaitForChild("DeviceTest")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Gamepad = require(Client:WaitForChild("Gamepad"))
local Ui = require(Client:WaitForChild("Ui"))

local HOLD = probe:GetAttribute("Hold") or 4 -- seconds kept still for the screenshot
local DEVICE = probe:GetAttribute("Device") or "unknown"
local INPUT = probe:GetAttribute("Input") or "mouse" -- touch / pad / mouse

local NOT_OURS = { TouchGui = true, ProximityPrompts = true, BubbleChat = true, Chat = true, Freecam = true,
	DeviceTestMarks = true, DevPanel = true } -- (DevPanel: the owner's test buttons, never shown to players)

local function shown(obj)
	local node = obj
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node.Enabled
end

-- where (0,0) of a screen's own positions is on the real screen: screens that keep clear of Roblox's top bar
-- start below it
local function origin(screen)
	if screen:IsA("ScreenGui") and (screen.ScreenInsets == Enum.ScreenInsets.None or screen.IgnoreGuiInset) then
		return Vector2.zero
	end
	return (GuiService:GetGuiInset())
end
local function rectOf(obj)
	local screen = obj:FindFirstAncestorWhichIsA("LayerCollector")
	local at = obj.AbsolutePosition + origin(screen)
	return at, at + obj.AbsoluteSize
end
local function overlap(a0, a1, b0, b1)
	local w = math.min(a1.X, b1.X) - math.max(a0.X, b0.X)
	local h = math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y)
	return (w > 0 and h > 0) and w * h or 0
end
local function inScroll(obj)
	return obj:FindFirstAncestorWhichIsA("ScrollingFrame") ~= nil
end
local function nameOf(obj)
	return (obj:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", ""):gsub("%.Root%.", "."))
end
local function inPanel(obj)
	local node = obj
	while node and node:IsA("GuiObject") do
		if node.SelectionGroup and Gamepad.TopPanel() == node then
			return true
		end
		node = node.Parent
	end
	-- (closed panels can't hold visible buttons, so the open one is enough)
	return false
end

-- Roblox's own touch controls (only on touch devices): the jump button and where the thumb rests
local function touchZones(viewport)
	local zones = {}
	local touch = gui:FindFirstChild("TouchGui")
	local frame = touch and touch:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump.Visible then
		local a, b = rectOf(jump)
		zones.Jump = { a, b }
	else
		-- the same sizes as Roblox's TouchJump: 70 px on small screens (short side 500 or less), else 120
		local small = math.min(viewport.X, viewport.Y) <= 500
		local size = small and 70 or 120
		local x = viewport.X - (size * 1.5 - 10)
		local y = viewport.Y + (small and (-size - 20) or (-size * 1.75))
		zones.Jump = { Vector2.new(x, y), Vector2.new(x + size, y + size) }
	end
	-- the thumb's resting place: bottom-left, up to 25% of the width (220 px) and 45% of the height (200 px)
	local w, h = math.min(viewport.X * 0.25, 220), math.min(viewport.Y * 0.45, 200)
	zones.Thumbstick = { Vector2.new(0, viewport.Y - h), Vector2.new(w, viewport.Y) }
	return zones
end

-- thin outlines in the screenshot: Roblox's touch controls (blue), the TV-safe frame (green)
local marks = Instance.new("ScreenGui")
marks.Name = "DeviceTestMarks"
marks.ScreenInsets = Enum.ScreenInsets.None
marks.DisplayOrder = 1000
marks.ResetOnSpawn = false
marks.Parent = gui
local function outline(name, a, b, color)
	local f = marks:FindFirstChild(name) or Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(a.X, a.Y)
	f.Size = UDim2.fromOffset(b.X - a.X, b.Y - a.Y)
	f.Active = false
	local stroke = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = f
	f.Parent = marks
end

local function measure(step)
	local viewport = workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local problems = {} -- check -> list
	local counts = { buttons = 0, texts = 0 }
	local function add(check, text)
		problems[check] = problems[check] or {}
		if #problems[check] < 12 then
			table.insert(problems[check], text)
		end
		problems[check].n = (problems[check].n or 0) + 1
	end
	local zones = INPUT == "touch" and touchZones(viewport) or {}
	for name, z in zones do
		outline(name, z[1], z[2], Color3.fromRGB(90, 170, 255))
	end
	local tvSafe
	if INPUT == "pad" then
		tvSafe = { viewport * 0.05, viewport * 0.95 }
		outline("TvSafe", tvSafe[1], tvSafe[2], Color3.fromRGB(110, 230, 120))
	end
	local textLeast = INPUT == "pad" and 18 * viewport.Y / 1080 or (INPUT == "touch" and 11 or 12)
	local buttons = {}
	for _, screen in gui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and not NOT_OURS[screen.Name] then
			local area = screen.AbsoluteSize
			for _, obj in screen:GetDescendants() do
				if obj:IsA("GuiObject") and obj.AbsoluteSize.X > 3 and obj.AbsoluteSize.Y > 3 and shown(obj) then
					local isButton = obj:IsA("GuiButton") and obj.Interactable
					local hasText = (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= ""
						and obj.TextTransparency < 0.5
					local isPicture = (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= ""
						and obj.ImageTransparency < 0.5
					if isButton or hasText or isPicture then
						-- (positions inside its own screen: a screen that reaches up into Roblox's top bar band,
						-- DeviceSafeInsets, starts above the usual (0,0))
						local own0 = obj.AbsolutePosition - screen.AbsolutePosition
						local own1 = own0 + obj.AbsoluteSize
						local a, b = rectOf(obj)
						if not inScroll(obj) then
							if own0.X < -2 or own0.Y < -2 or own1.X > area.X + 2 or own1.Y > area.Y + 2 then
								add("Cut", nameOf(obj))
							end
							if tvSafe and (isButton or hasText)
								and (a.X < tvSafe[1].X - 2 or a.Y < tvSafe[1].Y - 2 or b.X > tvSafe[2].X + 2 or b.Y > tvSafe[2].Y + 2) then
								add("TV safe", nameOf(obj))
							end
						end
						if isButton then
							counts.buttons += 1
							table.insert(buttons, { obj = obj, a = a, b = b })
							for zone, z in zones do
								if overlap(a, b, z[1], z[2]) > 4 then
									add("Thumbs", nameOf(obj) .. " on the " .. zone)
								end
							end
							if INPUT == "touch" then
								local least = inPanel(obj) and 36 or 44
								local size = obj.AbsoluteSize
								if math.min(size.X, size.Y) < least - 0.5 then
									add("Tap", string.format("%s %dx%d (needs %d)", nameOf(obj), size.X, size.Y, least))
								end
							end
						end
						if hasText then
							counts.texts += 1
							if not obj.TextFits then
								add("Fits", nameOf(obj) .. " '" .. obj.Text:sub(1, 18) .. "'")
							end
							-- one line of text: its letters' height (wrapped text: the size it was given)
							local height = obj.TextBounds.Y
							if obj.TextWrapped and not obj.TextScaled then
								local scale = 1
								local node = obj
								while node do
									local s = node:FindFirstChildOfClass("UIScale")
									if s then
										scale *= s.Scale
									end
									node = node.Parent
								end
								height = obj.TextSize * scale
							elseif obj.TextWrapped then
								height = math.huge -- (can't tell one line from several)
							end
							if height < textLeast - 0.5 then
								add("Text", string.format("%s '%s' %.0f px", nameOf(obj), obj.Text:sub(1, 14), height))
							end
						end
					end
				end
			end
		end
	end
	if Gamepad.TopPanel() == nil then
		for i = 1, #buttons do
			for j = i + 1, #buttons do
				local p, q = buttons[i], buttons[j]
				if not p.obj:IsAncestorOf(q.obj) and not q.obj:IsAncestorOf(p.obj) then
					local area = math.min(p.obj.AbsoluteSize.X * p.obj.AbsoluteSize.Y, q.obj.AbsoluteSize.X * q.obj.AbsoluteSize.Y)
					if overlap(p.a, p.b, q.a, q.b) > 0.2 * area then
						add("Overlap", nameOf(p.obj) .. " / " .. nameOf(q.obj))
					end
				end
			end
		end
	end
	-- Road: in a run, the road ahead (the middle 40% of the width, 18-45% down the screen: 30+ studs down the lane
	-- on the run camera) stays at least 92% clear of our UI, counting see-through chips and text too
	if step == "Run" or step == "Defender" then
		local r0, r1 = viewport * Vector2.new(0.3, 0.18), viewport * Vector2.new(0.7, 0.45)
		outline("RoadAhead", r0, r1, Color3.fromRGB(255, 190, 70))
		local cols, rows, cells, covered = 40, 27, {}, 0
		local cw, ch = (r1.X - r0.X) / cols, (r1.Y - r0.Y) / rows
		for _, screen in gui:GetChildren() do
			if screen:IsA("ScreenGui") and screen.Enabled and not NOT_OURS[screen.Name] then
				for _, obj in screen:GetDescendants() do
					if obj:IsA("GuiObject") and shown(obj) and obj.AbsoluteSize.X > 2 and obj.AbsoluteSize.Y > 2
						and not (step == "Defender" and Gamepad.TopPanel() and obj:IsDescendantOf(Gamepad.TopPanel())) then
						local seen = obj.BackgroundTransparency < 0.95
							or ((obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image ~= "" and obj.ImageTransparency < 0.95)
							or ((obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" and obj.TextTransparency < 0.95)
						if seen then
							local a, b = rectOf(obj)
							for c = math.max(0, math.floor((a.X - r0.X) / cw)), math.min(cols - 1, math.floor((b.X - r0.X) / cw)) do
								for r = math.max(0, math.floor((a.Y - r0.Y) / ch)), math.min(rows - 1, math.floor((b.Y - r0.Y) / ch)) do
									if not cells[r * cols + c] then
										cells[r * cols + c] = nameOf(obj)
										covered += 1
									end
								end
							end
						end
					end
				end
			end
		end
		local share = covered / (cols * rows)
		if share > 0.08 then
			local names = {}
			for _, name in cells do
				names[name] = true
			end
			local list = {}
			for name in names do
				table.insert(list, name)
			end
			add("Road", string.format("%.0f%% of the road ahead covered by %s", share * 100, table.concat(list, ", ")))
		end
	end
	local scale = gui:FindFirstChild("RealmGuardiansHud") and gui.RealmGuardiansHud.Root:FindFirstChildOfClass("UIScale")
	print(string.format("[DEVICES] SIZE %s %s viewport %dx%d inset %d,%d touch %s pad %s hud scale %.2f, %d buttons, %d texts",
		DEVICE, step, viewport.X, viewport.Y, inset.X, inset.Y, tostring(Ui.isTouch), tostring(Gamepad.active),
		scale and scale.Scale or 0, counts.buttons, counts.texts))
	local total = 0
	for _, check in { "Cut", "TV safe", "Thumbs", "Tap", "Text", "Fits", "Overlap", "Road" } do
		local list = problems[check]
		local n = list and list.n or 0
		total += n
		print(string.format("[DEVICES] CHECK %s %s %s %d%s", DEVICE, step, check, n,
			n > 0 and (": " .. table.concat(list, "; ")) or ""))
	end
	return total
end

local function closeAll()
	for _ = 1, 6 do
		if not Gamepad.TopPanel() then
			break
		end
		Gamepad.Back()
		task.wait(0.2)
	end
	GuiService.SelectedObject = nil
end

local function run()
	local step = probe:GetAttribute("Step")
	if not step then
		return
	end
	if string.sub(step, 1, 6) == "Clear-" then
		closeAll()
		task.wait(0.4)
		probe:FireServer(step, 0)
		return
	end
	local ok, result = pcall(function()
		if step == "Outpost" or step == "Run" then
			closeAll()
		elseif step == "Defender" then
			closeAll()
			-- the nearest defender's info panel, the way a controller opens it (works with any input)
			assert(Gamepad.Press(Enum.KeyCode.ButtonY), "Y did nothing")
		end
		task.wait(1.5) -- springs and pictures settle
		local count = measure(step)
		print("[DEVICES] SHOT", DEVICE, step)
		task.wait(HOLD)
		return count
	end)
	if not ok then
		print("[DEVICES] CHECK", DEVICE, step, "Step 1: FAILED " .. tostring(result))
	end
	probe:FireServer(step, ok and result or -1)
end

print("[DEVICES] client ready", DEVICE, INPUT, "touch enabled", UserInputService.TouchEnabled,
	"preferred", tostring(UserInputService.PreferredInput))
probe:GetAttributeChangedSignal("Step"):Connect(run)
run()
