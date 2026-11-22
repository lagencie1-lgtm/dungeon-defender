-- Small landmarks that sit outside the road and never become build or movement obstacles.
local MapProps = {}
local v = Vector3.new
local rgb = Color3.fromRGB
local mat = Enum.Material

local markers = {
	Forest = {
		Name = "Bramble Waystone",
		Segment = 3,
		Pieces = {
			{ "Footing", v(3.8, 0.48, 2.5), v(0, 0.14, 0), rgb(76, 83, 69), mat.Slate },
			{ "Standing stone", v(1.85, 3.3, 1.37), v(-0.12, 1.86, 0.08), rgb(117, 124, 107), mat.Slate, 7 },
			{ "Moss lip", v(1.57, 0.21, 0.85), v(-0.35, 3.52, 0.06), rgb(94, 128, 64), mat.Ground, 7 },
			{ "Brass inlay", v(0.67, 0.67, 0.12), v(-0.12, 2.38, -0.66), rgb(171, 143, 83), mat.Metal, 45 },
			{ "Green enamel", v(0.4, 0.4, 0.1), v(-0.12, 2.38, -0.71), rgb(156, 192, 94), mat.SmoothPlastic, 45 },
		},
	},
	Magma = {
		Name = "Forge Vent",
		Segment = 5,
		Pieces = {
			{ "Basalt footing", v(4.2, 0.5, 3), v(0, 0.14, 0), rgb(61, 53, 52), mat.Basalt },
			{ "Vent housing", v(2.75, 2.25, 1.9), v(0, 1.33, 0), rgb(76, 69, 67), mat.Slate },
			{ "Copper cap", v(2.96, 0.22, 2.09), v(0, 2.49, 0), rgb(170, 101, 62), mat.Metal },
			{ "Upper grate", v(1.62, 0.18, 0.13), v(0, 1.65, -0.98), rgb(213, 125, 68), mat.Metal },
			{ "Lower grate", v(1.62, 0.18, 0.13), v(0, 1.15, -0.98), rgb(171, 91, 57), mat.Metal },
			{ "Exhaust neck", v(0.78, 0.88, 0.69), v(0.55, 2.97, 0.15), rgb(97, 78, 69), mat.Metal },
		},
	},
	Crystal = {
		Name = "Crystal Survey Cairn",
		Segment = 7,
		Pieces = {
			{ "Stone footing", v(3.7, 0.55, 2.7), v(0, 0.17, 0), rgb(65, 65, 91), mat.Basalt },
			{ "Plinth", v(1.8, 1.24, 1.66), v(0, 0.92, 0), rgb(108, 109, 140), mat.Slate },
			{ "Tall shard", v(1.03, 2.48, 0.72), v(0.16, 2.68, -0.03), rgb(108, 195, 209), mat.SmoothPlastic, 13 },
			{ "Violet shard", v(0.75, 1.66, 0.72), v(-0.63, 1.82, 0.1), rgb(151, 130, 203), mat.SmoothPlastic, -19 },
			{ "Pale facet", v(0.25, 1.93, 0.09), v(0.16, 2.71, -0.42), rgb(174, 218, 218), mat.SmoothPlastic, 13 },
		},
	},
}

function MapProps.Place(map, info, pathWidth, distanceToPath)
	local marker = markers[info.Theme]
	if not marker then
		return
	end
	local a, b = info.Path[marker.Segment], info.Path[marker.Segment + 1]
	local forward = (b - a).Unit
	local side = v(-forward.Z, 0, forward.X)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _, fraction in { 0.5, 0.35, 0.65 } do
		local road = a:Lerp(b, fraction)
		for _, sign in { 1, -1 } do
			local candidate = road + side * sign * (pathWidth / 2 + 5)
			if distanceToPath(candidate) < pathWidth / 2 + 3 or (candidate - info.SpawnPoint).Magnitude < 15 then
				continue
			end
			local hit = workspace:Raycast(candidate + v(0, 16, 0), v(0, -25, 0), params)
			if not hit or math.abs(hit.Position.Y) > 2 or hit.Normal.Y < 0.8
				or hit.Material == mat.Water or hit.Material == mat.CrackedLava then
				continue
			end
			local origin = hit.Position
			local face = CFrame.lookAt(origin, v(road.X, origin.Y, road.Z))
			local model = Instance.new("Model")
			model.Name = marker.Name
			for _, piece in marker.Pieces do
				local name, size, offset, color, material, tilt = table.unpack(piece)
				local part = Instance.new("Part")
				part.Name, part.Size, part.Color, part.Material = name, size, color, material
				part.CFrame = face * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(tilt or 0))
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
				part.Parent = model
			end
			model.Parent = map
			return model
		end
	end
end

return MapProps
