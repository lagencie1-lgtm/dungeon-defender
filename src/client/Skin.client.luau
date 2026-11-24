-- Gives every big wooden panel the painted frame from the UI kit (art/ui), so all screens share one look.
-- A panel is a Frame in the dark wood colour with rounded corners and a real size.
local Players = game:GetService("Players")
local Ui = require(script.Parent.Ui)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function check(obj)
	if not obj:IsA("Frame") or obj:FindFirstChild("Skin") then
		return
	end
	if obj.BackgroundColor3 ~= Ui.DARK or not obj:FindFirstChildOfClass("UICorner") then
		return
	end
	local size = obj.Size
	if size.X.Offset >= 260 and size.Y.Offset >= 160 then
		Ui.skin(obj, "ui_panel")
	end
end

for _, d in playerGui:GetDescendants() do
	check(d)
end
playerGui.DescendantAdded:Connect(function(d)
	task.defer(check, d) -- after its properties are set
end)
