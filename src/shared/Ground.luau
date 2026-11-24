-- The one place that knows how high the ground is: a ray straight down that only sees terrain.
-- Server and client use the same rule, so the placement ghost stands exactly where the defender will.
-- (Roblox draws a terrain surface 2 studs above the top of a filled block: TerrainBuilder fills 2 studs lower so
-- flat ground sits at y = 0, and this function covers everything that is not flat: boulders, hollows, smoothing.)
local Ground = {}

Ground.MaxBump = 0.6 -- a defender's footprint may rise at most this much; its plinth reaches down to the low side
Ground.Feet = 0.05 -- enemies' feet float this much over the ground (never in it)
-- how wide each defender stands: the radius of ground it needs
Ground.Foot = { Ranger = 2.5, FlameCannon = 2.75, FrostCrystal = 2.5, StormObelisk = 2.5, Ballista = 3, Barricade = 2.5 }

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = false

-- ground height and material at (x, z); y = 0 when there is no terrain there yet
function Ground.At(x, z)
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -500, 0), params)
	if not hit then
		return 0, Enum.Material.Air
	end
	return hit.Position.Y, hit.Material
end

-- the ground under a round footprint: centre and 8 points on its rim.
-- Returns the highest point, the lowest point and whether any of it is water.
-- these terrain materials have bumpy ground of their own (measured +-0.4 to +-1.1 studs): nothing stands on them
local ROUGH = { [Enum.Material.Basalt] = true, [Enum.Material.Slate] = true, [Enum.Material.Rock] = true,
	[Enum.Material.Ice] = true, [Enum.Material.CrackedLava] = true }
Ground.Rough = ROUGH

function Ground.Footprint(position, radius)
	local top, bottom, water, rough = -math.huge, math.huge, false, false
	local function sample(x, z)
		local y, material = Ground.At(x, z)
		top, bottom = math.max(top, y), math.min(bottom, y)
		water = water or material == Enum.Material.Water
		rough = rough or ROUGH[material] == true
	end
	sample(position.X, position.Z)
	for i = 0, 7 do
		local a = i * math.pi / 4
		sample(position.X + math.cos(a) * radius, position.Z + math.sin(a) * radius)
	end
	return top, bottom, water, rough
end

-- why a defender can't stand here because of the ground (nil when it can), and the height it stands at
function Ground.Pad(position, radius)
	local top, bottom, water, rough = Ground.Footprint(position, radius)
	if water then
		return nil, "Can't build on water"
	end
	if rough then
		return nil, "Too rocky here"
	end
	if top - bottom > Ground.MaxBump then
		return nil, "Too bumpy here"
	end
	return top
end

return Ground
