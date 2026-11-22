-- The Daily Quests screen: today's 3 quests, progress bars and claim buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local make, corner, stroke, label, button = Ui.make, Ui.corner, Ui.stroke, Ui.label, Ui.button

local player = Players.LocalPlayer

local gui = make("ScreenGui", { Name = "QuestHud", ResetOnSpawn = false, DisplayOrder = 3,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = make("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
Ui.fitRoot(gui, root, 624, 354)

local questButton, readyDot = require(script.Parent.Menu).Add("Quests", "Quests", 5)

local panel = make("Frame", { Size = UDim2.fromOffset(600, 330), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Ui.DARK, Visible = false, ZIndex = 30, Parent = root },
	{ corner(18), stroke(Color3.fromRGB(255, 210, 120), 3) })
label({ Size = UDim2.fromOffset(300, 36), Position = UDim2.fromOffset(16, 10), Text = "Daily Quests",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = panel })
local resetLabel = label({ Size = UDim2.fromOffset(240, 22), Position = UDim2.new(1, -70, 0, 18), AnchorPoint = Vector2.new(1, 0),
	Text = "", Font = Enum.Font.Gotham, TextColor3 = Ui.TEXT_DIM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 31, Parent = panel })
local closeButton = button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0),
	Text = "X", BackgroundColor3 = Color3.fromRGB(140, 50, 50), ZIndex = 31, Parent = panel })

local rows = {}
for i = 1, Config.QuestsPerDay do
	local row = make("Frame", { Size = UDim2.new(1, -32, 0, 76), Position = UDim2.fromOffset(16, 56 + (i - 1) * 86),
		BackgroundColor3 = Ui.PANEL, ZIndex = 31, Parent = panel }, { corner(10) })
	local text = label({ Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(12, 8), Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = row })
	local reward = label({ Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(12, 34), Text = "",
		Font = Enum.Font.Gotham, TextColor3 = Ui.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = row })
	local barBack = make("Frame", { Size = UDim2.new(1, -200, 0, 10), Position = UDim2.fromOffset(12, 58),
		BackgroundColor3 = Color3.fromRGB(50, 45, 60), ZIndex = 32, Parent = row }, { corner(4) })
	local bar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 220, 120), ZIndex = 33,
		Parent = barBack }, { corner(4) })
	local claim = button({ Size = UDim2.fromOffset(160, 50), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		Text = "", ZIndex = 32, Parent = row })
	claim.Activated:Connect(function()
		local ok, gold, gems = Remotes.ClaimQuest:InvokeServer(i)
		if ok then
			Ui.playSound("Coin")
			claim.Text = "+" .. tostring(gold) .. " gold +" .. tostring(gems) .. " gems"
		end
	end)
	rows[i] = { text = text, reward = reward, bar = bar, claim = claim }
end

local function show(list)
	for i, r in rows do
		local quest = list and list[i]
		local info = quest and Config.FindById(Config.Quests, quest.Id)
		if info then
			r.text.Text = string.format(info.Text, info.Goal)
			r.reward.Text = "Reward: " .. info.Gold .. " gold, " .. info.Gems .. " gems"
			r.bar.Size = UDim2.fromScale(math.clamp(quest.Progress / info.Goal, 0, 1), 1)
			if quest.Claimed then
				r.claim.Text = "Claimed"
				r.claim.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			elseif quest.Progress >= info.Goal then
				r.claim.Text = "Claim!"
				r.claim.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
			else
				r.claim.Text = quest.Progress .. " / " .. info.Goal
				r.claim.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			end
		end
	end
	local left = 86400 - os.time() % 86400
	resetLabel.Text = string.format("New quests in %dh %dm", left // 3600, (left % 3600) // 60)
end

Remotes.Quests.OnClientEvent:Connect(show)
task.spawn(function()
	show(Remotes.GetQuests:InvokeServer())
end)
player:GetAttributeChangedSignal("QuestsReady"):Connect(function()
	readyDot.Visible = (player:GetAttribute("QuestsReady") or 0) > 0
end)

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Ui.pop(panel, 0.85)
		show(Remotes.GetQuests:InvokeServer())
	end
end
questButton.Activated:Connect(toggle)
questButton.Press.Event:Connect(toggle)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Quests" and not panel.Visible then
		toggle()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.J then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.Q then
		panel.Visible = false
	end
end)
