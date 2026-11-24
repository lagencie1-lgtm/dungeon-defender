-- The outline of each battlefield (2026-11-24, cycle 6): the line where the floor ends and the ground rises away,
-- a valley side on the Forest, a crater wall on Magma, a cave wall in the caves. Before, each map was a rectangle of
-- open floor inside a ring of trees, with the lanes in its middle.
-- Shared, so the build ghost (Hud) and the server (TowerService) refuse the same spots; MapLayouts (server) builds
-- the rise from it. Points run clockwise seen from above (north = -Z), lines along X or Z lie on multiples of 4
-- (the terrain's cells), so the rock starts exactly on them.
local MapOutline = {}

local v = Vector3.new

-- the valley: it runs behind the goblin camp, along the back of the north bank (whose far half is the valley side),
-- 24 studs north of the two top lanes, down the east side behind the river's last bend, round the shrine (built
-- against the valley's end), back along the south 24 studs below the last lane, in behind the chapel and the south
-- wood, and round the standing stones to the camp
MapOutline.Forest = {
	v(-120, 0, -64), v(-94, 0, -64), v(-90, 0, -72), v(-38, 0, -72), v(-28, 0, -68), v(-12, 0, -64), v(20, 0, -60),
	v(64, 0, -60), v(84, 0, -44), v(84, 0, 16), v(92, 0, 24), v(116, 0, 24), v(116, 0, 68), v(44, 0, 68), v(32, 0, 56),
	v(14, 0, 48), v(8, 0, 44), v(-28, 0, 44), v(-60, 0, 36), v(-78, 0, 24), v(-88, 0, 0), v(-120, 0, -8),
}

-- the crater: 24 studs outside the outermost lanes; the portal keep and the demon gate stand against it, and the
-- south curtain wall (the south gate's) runs into it at z = 76
MapOutline.Magma = {
	v(-84, 0, -56), v(-68, 0, -76), v(4, 0, -76), v(16, 0, -84), v(104, 0, -84), v(104, 0, 4), v(116, 0, 4), v(116, 0, 40),
	v(104, 0, 48), v(64, 0, 52), v(56, 0, 64), v(32, 0, 76), v(-32, 0, 76), v(-40, 0, 84), v(-120, 0, 84), v(-120, 0, 36),
	v(-84, 0, 36),
}

-- the cave: the tunnels fill it from wall to wall, so the wall is close everywhere; it comes in behind the loading
-- dock in the north-east (the dock backs onto it), round the portal ledge, and into the dead end south of the east
-- terrace (the one pocket no lane reaches)
MapOutline.Crystal = {
	v(-120, 0, -88), v(68, 0, -88), v(80, 0, -72), v(80, 0, -52), v(100, 0, -52), v(108, 0, -44), v(120, 0, -28),
	v(120, 0, 24), v(112, 0, 24), v(112, 0, 56), v(104, 0, 64), v(56, 0, 64), v(48, 0, 72), v(28, 0, 72), v(20, 0, 84),
	v(-120, 0, 84),
}

-- Heroes are stopped this far inside the outline (an invisible wall). The camera behind a hero who stands there and
-- looks back into the field then stays above the first steps of the rise, so it is never pushed in
-- (MapLayouts.CameraLine, checked by the map tour).
MapOutline.HeroStop = 5
-- Defenders keep at least this far inside it ("Too close to the edge", like the old rectangle's 4 studs).
MapOutline.BuildStop = 4

-- How a run starts on each map (research briefs and Lemp's map audit, 2026-11-24: a fresh phone player should place
-- a defender within 90 seconds; "frame the first view with the broken keep and make the bridge visible"):
--   Look       which way the heroes face when they arrive, so the first view shows the map's landmark and a bridge
--   FirstSpot  the defender spot the tutorial points at: on clearly free ground beside the landmark, a few studs from
--              the spawn, in the first view, covering the lanes near it (the map tour checks it takes a Ranger)
MapOutline.Start = {
	-- the keep tower 30 degrees to the left, the first ford 30 degrees to the right; the spot is on the keep hill
	-- between the hero and the tower, where a Ranger covers the road on all four sides of the hill
	Forest = { Look = v(0.5, 0, -0.866), FirstSpot = v(-6, 0, -16.5) },
	-- on the heart bastion, looking west at the lava bridge it watches
	Magma = { Look = v(-0.92, 0, -0.4), FirstSpot = v(9, 0, 2) },
	-- in the great hall, looking west at the last tunnel
	Crystal = { Look = v(-1, 0, 0), FirstSpot = v(66, 0, -20) },
}

function MapOutline.For(theme)
	return MapOutline[theme]
end

-- How far (x, z) lies outside the outline, in studs: negative inside. Far inside for no outline.
function MapOutline.Outside(points, x, z)
	if not points then
		return -math.huge
	end
	local inside, best = false, math.huge
	for i = 1, #points do
		local a, b = points[i], points[i % #points + 1]
		if (a.Z > z) ~= (b.Z > z) and x < (b.X - a.X) * (z - a.Z) / (b.Z - a.Z) + a.X then
			inside = not inside
		end
		local abx, abz = b.X - a.X, b.Z - a.Z
		local t = math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / (abx * abx + abz * abz), 0, 1)
		local dx, dz = x - (a.X + abx * t), z - (a.Z + abz * t)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return inside and -best or best
end

-- the same for a map by its theme ("Forest", "Magma", "Crystal")
function MapOutline.OutsideOf(theme, x, z)
	return MapOutline.Outside(MapOutline[theme], x, z)
end

-- The outline moved `d` studs inwards (each corner mitred), for the heroes' invisible wall.
function MapOutline.Inset(points, d)
	local n = #points
	local normals = {}
	for i = 1, n do
		local a, b = points[i], points[i % n + 1]
		local dir = (b - a).Unit
		local normal = v(dir.Z, 0, -dir.X)
		local mid = (a + b) / 2
		if MapOutline.Outside(points, mid.X + normal.X * 0.5, mid.Z + normal.Z * 0.5) > 0 then
			normal = -normal
		end
		normals[i] = normal
	end
	local inset = {}
	for i = 1, n do
		local before, after = normals[(i - 2) % n + 1], normals[i]
		inset[i] = points[i] + (before + after) * (d / (1 + before:Dot(after)))
	end
	return inset
end

return MapOutline
