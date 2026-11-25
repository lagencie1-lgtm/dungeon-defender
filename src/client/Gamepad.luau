-- Controller (Xbox / PlayStation) support shared by every screen.
--
-- What each button does (the same everywhere):
--   Left stick        walk (Roblox does this). Placing a defender: the ghost stands in front of the hero
--   Right stick       camera (Roblox does this)
--   A                 jump. Placing: build here. In a menu: press the highlighted button
--   B                 close the top panel, cancel placing, close the defender info
--   X                 build the highlighted defender card (in a run; in the Outpost X uses the station prompts)
--   Y                 pick your nearest defender (14 studs) and open its upgrade / sell panel
--   D-pad left/right  step through the defender cards
--   D-pad up          the side menu (Shop, Daily, Backpack, Heroes...)
--   D-pad down        game speed
--   RT / RB / LB      hero attack / second ability / third ability (F / E / R on a keyboard)
--   LT                start the next wave now
--
-- While a gamepad is the last thing the player touched, buttons show small round badges ("A", "B", "LB"...)
-- and the screens are drawn a bit bigger for a TV. Touch and mouse hide the badges again.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gamepad = {}

-- the test build (test/gamepad.project.json) pretends a controller is plugged in
local forced = RunService:IsStudio() and ReplicatedStorage:FindFirstChild("GamepadTest") ~= nil

local function isPad(inputType)
	return inputType.Name:sub(1, 7) == "Gamepad"
end

-- inputs that mean "not a controller any more" (anything else, like text focus, keeps the current state)
local NOT_PAD = {
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.MouseMovement] = true,
}

Gamepad.active = forced or isPad(UserInputService:GetLastInputType())
local changed = Instance.new("BindableEvent")

local function setActive(value)
	value = value or forced
	if value ~= Gamepad.active then
		Gamepad.active = value
		changed:Fire(value)
	end
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if isPad(inputType) then
		setActive(true)
	elseif NOT_PAD[inputType] then
		setActive(false)
	end
end)

-- calls fn(active) now and every time the player switches between controller and touch/mouse
function Gamepad.OnChanged(fn)
	task.spawn(fn, Gamepad.active)
	return changed.Event:Connect(fn)
end

-------------------------------------------------------------------------------
-- button names for the badges
-------------------------------------------------------------------------------
local XBOX = {
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
	ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	DPadUp = "Up", DPadDown = "Down", DPadLeft = "Left", DPadRight = "Right",
	ButtonSelect = "View", ButtonStart = "Menu", ButtonL3 = "LS", ButtonR3 = "RS",
}
-- what Roblox reports for a PlayStation controller, made short enough for a badge
local PLAYSTATION = {
	ButtonCross = "Cross", ButtonCircle = "Circle", ButtonSquare = "Square", ButtonTriangle = "Triangle",
	ButtonL1 = "L1", ButtonR1 = "R1", ButtonL2 = "L2", ButtonR2 = "R2",
	ButtonOptions = "Options", ButtonTouchpad = "Pad", ButtonShare = "Share",
}

function Gamepad.Name(keyCode)
	-- Roblox knows which controller is plugged in; it names PlayStation buttons "ButtonCross" and so on
	local ok, text = pcall(UserInputService.GetStringForKeyCode, UserInputService, keyCode)
	if ok and type(text) == "string" and PLAYSTATION[text] then
		return PLAYSTATION[text]
	end
	return XBOX[keyCode.Name] or keyCode.Name
end

-------------------------------------------------------------------------------
-- badges: a small dark circle with the button's name, next to an action button
-------------------------------------------------------------------------------
local badges = {}

local function showBadge(badge)
	badge.Visible = Gamepad.active and badge:GetAttribute("Show") ~= false
end

-- adds a badge to `parent`. `position` is where its middle goes (default: the top-left corner).
function Gamepad.Hint(parent, keyCode, position)
	local text = Gamepad.Name(keyCode)
	local height = 26
	local badge = Instance.new("Frame")
	badge.Name = "PadHint"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = position or UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(math.max(height, 12 + #text * 10), height)
	badge.BackgroundColor3 = Color3.fromRGB(28, 22, 18)
	badge.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 6
	badge.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(235, 205, 140)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = badge
	local label = Instance.new("TextLabel")
	label.Name = "Key"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -6, 1, -6)
	label.Position = UDim2.fromOffset(3, 3)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.ZIndex = badge.ZIndex + 1
	label.Parent = badge
	badge:SetAttribute("Key", keyCode.Name)
	badges[badge] = true
	badge.Destroying:Connect(function()
		badges[badge] = nil
	end)
	showBadge(badge)
	badge.Parent = parent
	return badge
end

-- shows or hides one badge on top of the controller rule (for example only on the highlighted card)
function Gamepad.ShowHint(badge, show)
	badge:SetAttribute("Show", show)
	showBadge(badge)
end

changed.Event:Connect(function()
	for badge in badges do
		showBadge(badge)
	end
end)

-------------------------------------------------------------------------------
-- panels: the highlight jumps into a panel when it opens, B closes it
-------------------------------------------------------------------------------
local open = {} -- open panels, the newest last
local registered = {} -- every panel frame -> its entry (open or not)
local areas = {} -- frames a controller button jumps into (the side menu...) -> that button's name
local backHandlers = {}

local function shownIn(obj, panel)
	local node = obj
	while node and node ~= panel do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == panel
end

local function usable(obj, panel)
	return obj and obj.Parent and obj:IsA("GuiObject") and obj.Selectable and shownIn(obj, panel)
		and (not obj:IsA("GuiButton") or obj.Interactable)
end

-- the button to highlight when a panel opens: its own pick, or else the first button, top to bottom
local function defaultIn(entry)
	local panel = entry.frame
	local wanted = entry.default
	if type(wanted) == "function" then
		wanted = wanted()
	end
	if usable(wanted, panel) then
		return wanted
	end
	local best, bestY, bestX
	for _, obj in panel:GetDescendants() do
		if obj:IsA("GuiButton") and obj ~= entry.closeButton and usable(obj, panel) then
			local at = obj.AbsolutePosition
			if not best or at.Y < bestY - 4 or (math.abs(at.Y - bestY) <= 4 and at.X < bestX) then
				best, bestY, bestX = obj, at.Y, at.X
			end
		end
	end
	return best or (usable(entry.closeButton, panel) and entry.closeButton) or nil
end

local function selectionIn(frame)
	local current = GuiService.SelectedObject
	return current ~= nil and (current == frame or current:IsDescendantOf(frame))
end

-- puts the highlight into the newest open panel (or clears it when none is open)
function Gamepad.Focus()
	local top = open[#open]
	if not Gamepad.active then
		return
	end
	if top then
		if not selectionIn(top.frame) then
			GuiService.SelectedObject = defaultIn(top)
		end
	end
end

local function remove(entry)
	local index = table.find(open, entry)
	if index then
		table.remove(open, index)
	end
	if selectionIn(entry.frame) then
		local top = open[#open]
		GuiService.SelectedObject = (Gamepad.active and top) and defaultIn(top) or nil
	end
end

-- registers a panel. options (all optional):
--   default     the button (or a function giving it) to highlight first
--   close       how to close it (default: hide the frame)
--   closeButton its X button: gets the B badge and is not the first pick
--   closable    false for screens B must not close (the end of a run)
function Gamepad.Panel(frame, options)
	options = options or {}
	local entry = { frame = frame, default = options.default, close = options.close, closeButton = options.closeButton,
		closable = options.closable ~= false }
	registered[frame] = entry
	frame.Destroying:Connect(function()
		registered[frame] = nil
	end)
	-- the d-pad stays inside this panel while it has the highlight
	frame.SelectionGroup = true
	if entry.closeButton then
		Gamepad.Hint(entry.closeButton, Enum.KeyCode.ButtonB, UDim2.fromOffset(2, 2))
	end
	local function update()
		if frame.Visible and frame.Parent then
			if not table.find(open, entry) then
				table.insert(open, entry)
			end
			-- wait a moment: most screens fill their buttons right after showing the frame
			task.defer(function()
				if frame.Visible and open[#open] == entry and Gamepad.active then
					Gamepad.Focus()
				end
			end)
		else
			remove(entry)
		end
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(update)
	frame.AncestryChanged:Connect(update)
	update()
	return entry
end

-- the panel B would close next, or nil
function Gamepad.TopPanel()
	local top = open[#open]
	return top and top.frame
end

-- extra things B can do when no panel is open (cancel placing...). fn returns true when it did something.
function Gamepad.OnBack(fn)
	table.insert(backHandlers, fn)
end

-- what B does: close the top panel, else the first handler that wants it, else drop the highlight
function Gamepad.Back()
	for i = #open, 1, -1 do
		local entry = open[i]
		if entry.closable then
			if entry.close then
				entry.close()
			else
				entry.frame.Visible = false
			end
			remove(entry) -- (in case closing did not hide the frame right away)
			return true
		end
	end
	for _, fn in backHandlers do
		if fn() then
			return true
		end
	end
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
		return true
	end
	return false
end

-- marks a row of buttons that one controller button puts the highlight into (d-pad up: the side menu)
function Gamepad.Area(frame, keyCode)
	frame.SelectionGroup = true
	areas[frame] = Gamepad.Name(keyCode)
end

-- how a controller player gets to `button`, as a short text, or nil when they can't (the gamepad test fails then):
--   its own badge (a controller button does the same thing), inside a panel (the highlight jumps in when it
--   opens), inside an area (a controller button jumps into it), or a "PadReach" attribute that says how
function Gamepad.Reach(button)
	local reason = button:GetAttribute("PadReach")
	if type(reason) == "string" and reason ~= "" then
		return reason
	end
	local badge = button:FindFirstChild("PadHint")
	if badge then
		return "button " .. Gamepad.Name(Enum.KeyCode[badge:GetAttribute("Key")])
	end
	local node = button
	while node and node:IsA("GuiObject") do
		if registered[node] then
			return button.Selectable and ("in panel " .. node.Name) or nil
		end
		if areas[node] then
			return button.Selectable and ("in " .. node.Name .. " (" .. areas[node] .. ")") or nil
		end
		node = node.Parent
	end
	return nil
end

-- Every keyboard key the game listens to, and what does the same on a controller. scripts/pad_parity.py fails
-- when a script listens to a key that is missing here, so a PC shortcut can never be the only way to do something.
Gamepad.KEYBOARD = {
	One = "d-pad left/right picks the card, X builds", Two = "d-pad left/right, X", Three = "d-pad left/right, X",
	Four = "d-pad left/right, X", Five = "d-pad left/right, X",
	Q = "B (cancel, close)",
	F = "RT (hero attack)", E = "RB (second ability)", R = "LB (third ability)",
	B = "d-pad up, Shop", I = "d-pad up, Backpack", P = "d-pad up, Pets", K = "d-pad up, Season",
	J = "d-pad up, Quests", H = "d-pad up, Heroes",
	G = "LS click (ping)",
	LeftShift = "keeps building on PC; a controller presses X again",
}

-------------------------------------------------------------------------------
-- button bindings
-------------------------------------------------------------------------------
local actions = {} -- keyCode name -> list of handlers

-- binds a controller button. fn(keyCode) returns true when it used the press (then the hero does not also
-- jump on A, for example). While a menu button is highlighted the d-pad and A belong to the menu.
function Gamepad.Bind(name, keyCodes, fn)
	for _, keyCode in keyCodes do
		actions[keyCode.Name] = actions[keyCode.Name] or {}
		table.insert(actions[keyCode.Name], fn)
	end
	ContextActionService:BindActionAtPriority("HTD_Pad_" .. name, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass
		end
		return fn(input.KeyCode) and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(keyCodes))
end

-- presses a controller button from code (the gamepad test uses this; scripts can't press real buttons)
function Gamepad.Press(keyCode)
	if keyCode == Enum.KeyCode.ButtonB then
		return Gamepad.Back()
	end
	for _, fn in actions[keyCode.Name] or {} do
		if fn(keyCode) then
			return true
		end
	end
	return false
end

-- B works even while a menu button is highlighted (Roblox marks those presses as "used by the menu")
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonB then
		Gamepad.Back()
	end
end)

-- switching to a controller with a panel open: put the highlight in it
changed.Event:Connect(function(active)
	if active then
		Gamepad.Focus()
	end
end)

return Gamepad
