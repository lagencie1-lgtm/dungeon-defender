-- Made by scripts/map_kit_data.py from the built kit (art/models/mapkit). Do not edit by hand.
-- Boxes: each kit model's box in the piece's own space (X right, Y up, front at -Z), in studs.
-- Solid: what a hero bumps into (the pictures themselves never collide: an arch's rough hull would block the lane).
local MapKit = {}

MapKit.Boxes = {
	mapkit_arch_crystal = { Min = Vector3.new(-10.55, -0.205, -4.075), Max = Vector3.new(10.55, 16.497, 1.95) },
	mapkit_arch_forest = { Min = Vector3.new(-10.776, -0.232, -3.43), Max = Vector3.new(10.55, 15.882, 3.125) },
	mapkit_arch_magma = { Min = Vector3.new(-11.462, -0.189, -4.26), Max = Vector3.new(10.55, 15.882, 1.95) },
	mapkit_bridge_crystal = { Min = Vector3.new(-9.3, -0, -9.1), Max = Vector3.new(9.3, 4.4, 9.1) },
	mapkit_bridge_forest = { Min = Vector3.new(-9.427, -0, -9.356), Max = Vector3.new(9.3, 4.132, 9.223) },
	mapkit_bridge_magma = { Min = Vector3.new(-9.3, -0, -9.1), Max = Vector3.new(9.3, 4.4, 9.1) },
	mapkit_face_crystal = { Min = Vector3.new(-5.98, -1.48, -0.925), Max = Vector3.new(5.98, 6.525, 5.175) },
	mapkit_face_forest = { Min = Vector3.new(-5.98, -1.48, -1.111), Max = Vector3.new(5.98, 5.512, 5.175) },
	mapkit_face_magma = { Min = Vector3.new(-5.98, -1.48, -0.925), Max = Vector3.new(5.98, 5.16, 5.175) },
	mapkit_flags_crystal = { Min = Vector3.new(-2.006, -0, -1.402), Max = Vector3.new(1.958, 0.13, 1.415) },
	mapkit_flags_forest = { Min = Vector3.new(-1.879, -0, -1.392), Max = Vector3.new(1.884, 0.13, 1.476) },
	mapkit_flags_magma = { Min = Vector3.new(-1.88, -0, -1.438), Max = Vector3.new(1.859, 0.13, 1.457) },
	mapkit_low_crystal = { Min = Vector3.new(-5.926, 0.02, -0.762), Max = Vector3.new(5.98, 4.782, 0.75) },
	mapkit_low_forest = { Min = Vector3.new(-6.636, -0.174, -2.557), Max = Vector3.new(6.432, 3.132, 1.176) },
	mapkit_low_magma = { Min = Vector3.new(-5.98, -0.721, -0.82), Max = Vector3.new(5.98, 2.625, 0.774) },
	mapkit_pad_crystal = { Min = Vector3.new(-3.372, -0.032, -3.484), Max = Vector3.new(3.425, 0.894, 3.457) },
	mapkit_pad_forest = { Min = Vector3.new(-3.434, -0.183, -3.771), Max = Vector3.new(3.474, 0.263, 3.388) },
	mapkit_pad_magma = { Min = Vector3.new(-3.387, -0, -3.376), Max = Vector3.new(3.448, 0.16, 3.455) },
	mapkit_pillar_crystal = { Min = Vector3.new(-3.713, -0.178, -2.282), Max = Vector3.new(3.047, 8.811, 2.47) },
	mapkit_pillar_forest = { Min = Vector3.new(-3.713, -0.192, -2.282), Max = Vector3.new(1.5, 7.696, 2.972) },
	mapkit_pillar_magma = { Min = Vector3.new(-3.713, -0.207, -2.282), Max = Vector3.new(2.242, 7.517, 1.817) },
	mapkit_set_crystal = { Min = Vector3.new(-3.823, -0.134, -2.047), Max = Vector3.new(3.75, 4.413, 2.007) },
	mapkit_set_forest = { Min = Vector3.new(-8.327, -0.353, -3.473), Max = Vector3.new(4.281, 8.996, 1.436) },
	mapkit_set_magma = { Min = Vector3.new(-1.7, -0, -1.7), Max = Vector3.new(1.7, 4.638, 1.7) },
	mapkit_stairs_crystal = { Min = Vector3.new(-4.35, -1.5, -4.1), Max = Vector3.new(3.28, 5.6, -0.65) },
	mapkit_stairs_forest = { Min = Vector3.new(-4.35, -1.5, -4.224), Max = Vector3.new(3.28, 6.011, -0.65) },
	mapkit_stairs_magma = { Min = Vector3.new(-4.35, -1.5, -4.1), Max = Vector3.new(3.28, 5.6, -0.65) },
	mapkit_tower_forest = { Min = Vector3.new(-8.196, -0.604, -7.5), Max = Vector3.new(6.542, 24.632, 7.969) },
	mapkit_wall_crystal = { Min = Vector3.new(-7.05, -0.275, -2.568), Max = Vector3.new(6.98, 7.961, 2.7) },
	mapkit_wall_forest = { Min = Vector3.new(-7.05, -0.206, -3.217), Max = Vector3.new(6.98, 6.379, 2.7) },
	mapkit_wall_magma = { Min = Vector3.new(-7.05, -0.199, -3.436), Max = Vector3.new(6.98, 5.697, 2.7) },
}

MapKit.Solid = {
	wall = { { Centre = Vector3.new(3.5, 2.4, 0), Size = Vector3.new(7, 4.8, 1.8) }, { Centre = Vector3.new(-3.5, 1.5, 0), Size = Vector3.new(7, 3, 1.8) } },
	low = { { Centre = Vector3.new(0, 1.2, 0), Size = Vector3.new(12, 2.4, 1.4) } },
	arch = { { Centre = Vector3.new(8.6, 4.5, 0), Size = Vector3.new(3.6, 9, 3.6) }, { Centre = Vector3.new(-8.6, 4.5, 0), Size = Vector3.new(3.6, 9, 3.6) } },
	pillar = { { Centre = Vector3.new(0, 3.4, 0), Size = Vector3.new(2.4, 6.8, 2.4) } },
	bridge = { { Centre = Vector3.new(0, 1.3, -8.1), Size = Vector3.new(17, 2.6, 1.5) }, { Centre = Vector3.new(0, 1.3, 8.1), Size = Vector3.new(17, 2.6, 1.5) } },
	set_forest = { { Centre = Vector3.new(2.6, 3.6, 0), Size = Vector3.new(2, 7.2, 1.5) }, { Centre = Vector3.new(-2.6, 3.6, 0), Size = Vector3.new(2, 7.2, 1.5) } },
	set_magma = { { Centre = Vector3.new(0, 2.2, 0), Size = Vector3.new(3.4, 4.4, 3.4) } },
	set_crystal = { { Centre = Vector3.new(0, 1.4, 0), Size = Vector3.new(4, 2.8, 2.8) } },
	face = { { Centre = Vector3.new(0, 1.55, 0), Size = Vector3.new(12, 6.1, 1.3) }, { Centre = Vector3.new(0, 4.87, 2.15), Size = Vector3.new(12, 0.55, 6.2) } },
	tower = { { Centre = Vector3.new(0, 9, 0), Size = Vector3.new(9.6, 18, 9.6) } },
}

return MapKit
