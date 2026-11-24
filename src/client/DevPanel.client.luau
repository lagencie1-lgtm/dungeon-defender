-- The developer panel (testing only). It only appears for the game's owner: the server marks that player
-- with the "Developer" attribute and checks every press again (see server/DevService). Everyone else never
-- sees anything.
--   Phone: the small "DEV" tab on the right edge.   Controller: press the right stick (R3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ui = require(script.Parent.Ui)
local Gamepad = Ui.Gamepad
local make, corner, label, button = Ui.make, Ui.corner, Ui.label, Ui.button

local player = Players.LocalPlayer

-- wait for the server's mark (a few seconds after joining); normal players stop here
if not player:GetAttribute("Developer") then
	local got = false
	local connection = player:GetAttributeChangedSignal("Developer"):Connect(function()
		got = true
	end)
	local waited = 0
	while not got and waited < 30 do
		waited += task.wait(0.5)
	end
	connection:Disconnect()
	if not player:GetAttribute("Developer") then
		return
	end
end

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DevGrant", 30)
if not remote then
	return
end

-- the buttons, same order and ids as DevService.Grants
local GRANTS = {
	{ Id = "Gems", Text = "+1000 Gems", Color = Ui.GEM },
	{ Id = "Gold", Text = "+5000 Gold", Color = Ui.GOLD },
	{ Id = "Scrap", Text = "+500 Scrap", Color = Ui.SCRAP },
	{ Id = "Mana", Text = "+1000 Mana", Color = Ui.MANA },
	{ Id = "HeroLevel", Text = "Hero +1 level", Color = Color3.fromRGB(255, 170, 110) },
	{ Id = "SeasonLevel", Text = "Season +1 level", Color = Color3.fromRGB(150, 230, 140) },
	{ Id = "PetDust", Text = "+500 Pet Dust", Color = Color3.fromRGB(200, 170, 255) },
	{ Id = "FivePets", Text = "+5 Slimey", Color = Color3.fromRGB(255, 196, 60) },
}

local gui = make("ScreenGui", { Name = "DevPanel", ResetOnSpawn = false, DisplayOrder = 6,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
Ui.fitRoot(gui, root, 520, 330)

-- the tab: small, on the right edge in the middle, away from the hero buttons and the joystick
local tab = button({ Name = "DevTab", Size = UDim2.fromOffset(52, 44), Position = UDim2.new(1, -4, 0.5, -60),
	AnchorPoint = Vector2.new(1, 0.5), Text = "DEV", BackgroundColor3 = Color3.fromRGB(90, 40, 40), ZIndex = 2, Parent = root })
Gamepad.Hint(tab, Enum.KeyCode.ButtonR3, UDim2.fromOffset(2, 2))

local COLS, CELL_W, CELL_H, GAP = 2, 170, 52, 8
local rows = math.ceil(#GRANTS / COLS)
local panelW = COLS * CELL_W + (COLS + 1) * GAP
local RESET_TOP = 40 + rows * (CELL_H + GAP) + 6 -- the reset button sits alone below the grid, set apart
local panelH = RESET_TOP + CELL_H + GAP + 34

local panel = make("Frame", { Name = "Panel", Size = UDim2.fromOffset(panelW, panelH), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 10, Parent = root },
	{ corner(12), Ui.stroke() })
Ui.skin(panel, "ui_parchment", Color3.fromRGB(120, 95, 80))
label({ Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(12, 7), Text = "Developer (only you see this)",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = panel })
local closeButton = button({ Name = "Close", Size = UDim2.fromOffset(40, 32), Position = UDim2.new(1, -8, 0, 4),
	AnchorPoint = Vector2.new(1, 0), Text = "X", BackgroundColor3 = Color3.fromRGB(110, 50, 45), ZIndex = 11, Parent = panel })
local status = label({ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 1, -28), Text = "",
	Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, ZIndex = 11, Parent = panel })

local busy = false
local firstButton
for i, g in GRANTS do
	local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
	local b = button({ Name = g.Id, Size = UDim2.fromOffset(CELL_W, CELL_H),
		Position = UDim2.fromOffset(GAP + col * (CELL_W + GAP), 40 + row * (CELL_H + GAP)),
		Text = g.Text, BackgroundColor3 = Ui.PANEL, TextColor3 = g.Color, ZIndex = 11, Parent = panel })
	firstButton = firstButton or b
	b.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, result = remote:InvokeServer(g.Id)
		busy = false
		status.Text = ok and ("Done: " .. g.Text) or tostring(result or "Didn't work")
		status.TextColor3 = ok and Ui.GEM or Ui.BAD
		if ok then
			Ui.playSound("Coin")
		end
	end)
end

-- Reset my save: press once to arm (the button turns red and asks again), press again within a few
-- seconds to delete the whole save. The server checks both presses and then sends you out of the game.
local CONFIRM_SECONDS = 8 -- a little under the server's 10 s, so an armed button never outlives the server
local RESET_TEXT = "Reset my save (start over)"
local resetButton = button({ Name = "ResetSave", Size = UDim2.fromOffset(panelW - 2 * GAP, CELL_H),
	Position = UDim2.fromOffset(GAP, RESET_TOP), Text = RESET_TEXT, BackgroundColor3 = Color3.fromRGB(90, 38, 34),
	TextColor3 = Ui.BAD, ZIndex = 11, Parent = panel })
local armedAt = nil
local function disarm()
	armedAt = nil
	resetButton.Text = RESET_TEXT
	resetButton.BackgroundColor3 = Color3.fromRGB(90, 38, 34)
	resetButton.TextColor3 = Ui.BAD
end
resetButton.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	local confirm = armedAt ~= nil
	local ok, result = remote:InvokeServer(confirm and "ResetSaveConfirm" or "ResetSave")
	busy = false
	if not ok then
		disarm()
		status.Text = tostring(result or "Didn't work")
		status.TextColor3 = Ui.BAD
		return
	end
	if confirm then
		armedAt = nil
		resetButton.Text = "Save deleted"
		status.Text = tostring(result or "Save reset. Join again to start fresh")
		status.TextColor3 = Ui.GEM
		return
	end
	local stamp = os.clock()
	armedAt = stamp
	resetButton.Text = "Press again to DELETE everything"
	resetButton.BackgroundColor3 = Color3.fromRGB(170, 45, 40)
	resetButton.TextColor3 = Color3.new(1, 1, 1)
	status.Text = "Deletes ALL progress for good. Press again within " .. CONFIRM_SECONDS .. " s"
	status.TextColor3 = Ui.BAD
	Ui.pop(resetButton, 0.94)
	task.delay(CONFIRM_SECONDS, function()
		if armedAt == stamp then
			disarm()
			status.Text = "Reset cancelled"
			status.TextColor3 = Ui.TEXT_DIM
		end
	end)
end)

local function setOpen(open)
	panel.Visible = open
	if not open and armedAt then
		disarm()
	end
	if open then
		-- the sound check's result (SoundBank): shows a sound this device could not load
		status.Text = require(script.Parent.SoundBank).Summary()
		status.TextColor3 = Ui.TEXT_DIM
		Ui.pop(panel, 0.92)
	end
end

Gamepad.Panel(panel, { default = firstButton, closeButton = closeButton, close = function()
	setOpen(false)
end })
tab.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
Gamepad.Bind("DevPanel", { Enum.KeyCode.ButtonR3 }, function()
	setOpen(not panel.Visible)
	return true
end)
