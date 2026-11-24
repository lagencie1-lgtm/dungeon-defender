-- The opening is 16 studs wide. Gate pieces are anchored and reuse built-in materials.
local Gatehouse = {}
function Gatehouse.build(hub, center, placeRanger)
	local gate = Instance.new("Model")
	gate.Name = "RangerGatehouse"
	gate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local origin = CFrame.new(center + Vector3.new(0, 0, -13))
	local stone = Color3.fromRGB(160, 150, 130)
	local limestone = Color3.fromRGB(202, 186, 148)
	local timber = Color3.fromRGB(83, 54, 34)
	local gold = Color3.fromRGB(199, 155, 72)
	local function piece(name, size, frame, material, color, solid)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, origin * frame
		p.Material, p.Color = material, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid == true, false, solid == true
		p.Parent = gate
		return p
	end
	for _, side in { -1, 1 } do
		local x = side * 12
		piece("Bastion", Vector3.new(8, 10, 8), CFrame.new(x, 5, 0), Enum.Material.Cobblestone, stone, true)
		piece("Coping", Vector3.new(9, 1, 9), CFrame.new(x, 10.5, 0), Enum.Material.Limestone, limestone, true)
		piece("GateJamb", Vector3.new(1.3, 10, 1), CFrame.new(side * 8.7, 5, 4), Enum.Material.Limestone, limestone)
		piece("Brace", Vector3.new(0.85, 6, 1), CFrame.new(side * 6.4, 9.5, 3) * CFrame.Angles(0, 0, -side * math.rad(46)), Enum.Material.Wood, timber)
	end
	piece("WallWalk", Vector3.new(25, 1.5, 6.5), CFrame.new(0, 12, 0), Enum.Material.WoodPlanks, timber, true)
	for _, z in { -2.9, 2.9 } do
		piece("Parapet", Vector3.new(24, 1.5, 0.65), CFrame.new(0, 13.3, z), Enum.Material.Wood, timber)
	end
	for x = -8, 8, 4 do
		piece("Merlon", Vector3.new(2, 1.65, 0.8), CFrame.new(x, 14.75, 2.9), Enum.Material.Wood, timber)
	end
	piece("Keystone", Vector3.new(1.65, 1.65, 0.6), CFrame.new(0, 12.65, 3.45) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Metal, gold)
	local foot = origin.Position + Vector3.new(-12, 10.95, 0)
	local target = origin.Position + Vector3.new(-11, 4, 19)
	piece("TargetPost", Vector3.new(0.8, 4.4, 0.8), CFrame.new(-11, 2.2, 19), Enum.Material.Wood, timber)
	local face = CFrame.new(-11, 4, 19) * CFrame.Angles(0, math.rad(25), 0)
	for i, diameter in { 4.3, 3.1, 1.75, 0.7 } do
		local colors = { gold, Color3.fromRGB(128, 49, 41), Color3.fromRGB(218, 191, 139), Color3.fromRGB(128, 49, 41) }
		local disc = piece("TargetRing", Vector3.new(0.18, diameter, diameter), face * CFrame.new(0, 0, 0.12 * i)
			* CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Wood, colors[i])
		disc.Shape = Enum.PartType.Cylinder
	end
	gate:SetAttribute("PracticeTarget", target)
	gate.Parent = hub
	task.spawn(function()
		local facing = CFrame.lookAt(foot, Vector3.new(target.X, foot.Y, target.Z))
		local ranger = placeRanger(gate, facing)
		if ranger then
			local _, size = ranger:GetBoundingBox()
			gate:SetAttribute("ArrowOrigin", facing:PointToWorldSpace(Vector3.new(0, size.Y * 0.54, -size.Z * 0.28)))
		end
	end)
end
return Gatehouse
