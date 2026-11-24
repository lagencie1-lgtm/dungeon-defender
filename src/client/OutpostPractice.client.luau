-- A single local arrow demonstrates the Ranger only while the courtyard is in view.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local arrow = Instance.new("Part")
arrow.Name = "PracticeArrow"
arrow.Size = Vector3.new(0.13, 0.13, 2.4)
arrow.Material = Enum.Material.Neon
arrow.Color = Color3.fromRGB(243, 196, 113)
arrow.Anchored, arrow.CanCollide, arrow.CanQuery, arrow.CanTouch, arrow.CastShadow = true, false, false, false, false
while task.wait(3.5) do
	local hub = workspace:FindFirstChild("Outpost")
	local gate = hub and hub:FindFirstChild("RangerGatehouse")
	local origin = gate and gate:GetAttribute("ArrowOrigin")
	local target = gate and gate:GetAttribute("PracticeTarget")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if origin and target and root and camera and (root.Position - target).Magnitude < 95 then
		local _, visible = camera:WorldToViewportPoint((origin + target) / 2)
		if visible then
			local direction = (target - origin).Unit
			arrow.CFrame = CFrame.lookAt(origin, target)
			arrow.Parent = workspace
			local shot = TweenService:Create(arrow, TweenInfo.new(0.45, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + direction) })
			shot:Play()
			shot.Completed:Wait()
			arrow.Parent = nil
			shot:Destroy()
		end
	end
end
