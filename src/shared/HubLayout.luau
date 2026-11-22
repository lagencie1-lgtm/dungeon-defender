-- The Watch Keep (the new Outpost) as data: every place in studs from Config.OutpostCenter, +Z towards the
-- spawn (south), -Z towards the portal (north). The builder (server/OutpostKeep) and the screens read this,
-- so the layout can be checked and changed in one place. Concept and reasons: reviews/hub/benchmark.md.
local HubLayout = {}

HubLayout.Size = Vector2.new(116, 96) -- inside the walls (X, Z)
HubLayout.Spawn = Vector3.new(0, 0, 36) -- faces north, straight at the portal
-- the Beacon Tower (Lemp's pick): the landmark, with the portal standing in the archway at its foot
HubLayout.Portal = Vector3.new(0, 0, -36) -- 72 studs ahead of the spawn: the whole tower fits the spawn view
HubLayout.PortalHeight = 12 -- the portal model, sized to fit the Tripo tower's archway (about 9 wide, 13 tall)
HubLayout.BeaconHeight = 42
-- walk-in map pads in front of the gate (one per map, in Config.MapOrder)
HubLayout.Pads = {
	{ Map = "CursedForest", At = Vector3.new(-19, 0, -15) },
	{ Map = "MagmaFortress", At = Vector3.new(0, 0, -13) },
	{ Map = "CrystalCaves", At = Vector3.new(19, 0, -15) },
}
HubLayout.PadRadius = 5.5
HubLayout.PadCountdown = 4 -- seconds standing on a pad before the run starts

-- stations on the ring around the plaza: one big word, the icon beside it, the painted prop, a walk-in ring
HubLayout.Stations = {
	{ Id = "Forge", Word = "FORGE", Icon = "backpack", Model = "keep_forge", Height = 17, At = Vector3.new(-37, 0, -15),
		Action = "Backpack", Color = Color3.fromRGB(255, 170, 80) },
	{ Id = "Heroes", Word = "HEROES", Icon = "heroes", Model = "keep_hero", Height = 20, At = Vector3.new(-37, 0, 13),
		Action = "Heroes", Color = Color3.fromRGB(120, 230, 120) },
	{ Id = "Shop", Word = "SHOP", Icon = "shop", Model = "keep_shop", Height = 15, At = Vector3.new(37, 0, -15),
		Action = "Shop", Color = Color3.fromRGB(90, 220, 255) },
	{ Id = "Pets", Word = "PETS", Icon = "pets", Model = "keep_pets", Height = 14, At = Vector3.new(37, 0, 13),
		Action = "Pets", Color = Color3.fromRGB(170, 240, 120) },
	{ Id = "Quests", Word = "QUESTS", Icon = "quests", Model = "keep_quests", Height = 13, At = Vector3.new(-25, 0, 31),
		Action = "Quests", Color = Color3.fromRGB(255, 215, 120) },
	{ Id = "Rewards", Word = "REWARDS", Icon = "daily", Model = "keep_chest", Height = 8, At = Vector3.new(25, 0, 31),
		Action = "Daily", Color = Color3.fromRGB(255, 205, 80) },
}
HubLayout.RingRadius = 5 -- walk into it to open the station
HubLayout.RingOffset = 9 -- the ring lies this far in front of the station, towards the plaza

-- the five real defenders on pedestals by the gate (left three, right two), and the trophy board
HubLayout.Showcase = {
	{ Tower = "Ranger", At = Vector3.new(-26, 0, -36) },
	{ Tower = "FlameCannon", At = Vector3.new(-36, 0, -34) },
	{ Tower = "FrostCrystal", At = Vector3.new(-46, 0, -32) },
	{ Tower = "StormObelisk", At = Vector3.new(26, 0, -36) },
	{ Tower = "Ballista", At = Vector3.new(36, 0, -34) },
}
HubLayout.Trophies = Vector3.new(48, 0, -30)

-- life: keepers stand beside their stations and turn to whoever comes close
HubLayout.Keepers = {
	{ Station = "Forge", Side = 7 },
	{ Station = "Shop", Side = -7 },
	{ Station = "Pets", Side = -6 },
}

-- dressing, each piece with a reason (Blender: art/blender/keep_dressing.py). At is from the hub centre, Turn in
-- degrees, Height in studs. The keep should feel lived in, with no stretch of bare lawn in the spawn view.
HubLayout.Dressing = {
	-- the forge works: coal, a weapon rack, a quench barrel
	{ Model = "keep_coal", At = Vector3.new(-28, 0, -24), Height = 2.2 },
	{ Model = "keep_rack", At = Vector3.new(-45, 0, -4), Turn = 90, Height = 3.4 },
	{ Model = "keep_barrel", At = Vector3.new(-27, 0, -8), Height = 3 },
	-- the shop's stock waits in crates and barrels
	{ Model = "keep_crate", At = Vector3.new(29, 0, -24), Turn = 20, Height = 2.6 },
	{ Model = "keep_crate", At = Vector3.new(31.5, 0, -26), Turn = -10, Height = 2.2 },
	{ Model = "keep_barrel", At = Vector3.new(46, 0, -6), Height = 3 },
	-- the well in the middle of the plaza (water for the keep, a meeting point)
	{ Model = "keep_well", At = Vector3.new(11, 0, 6), Height = 6.5 }, -- (off the spawn-to-portal line)
	-- lanterns light the avenue and the paths to the stations
	{ Model = "keep_lantern", At = Vector3.new(-8, 0, 30), Turn = 0, Height = 6.5 },
	{ Model = "keep_lantern", At = Vector3.new(8, 0, 30), Turn = 180, Height = 6.5 },
	{ Model = "keep_lantern", At = Vector3.new(-8, 0, -24), Turn = 0, Height = 6.5 },
	{ Model = "keep_lantern", At = Vector3.new(8, 0, -24), Turn = 180, Height = 6.5 },
	{ Model = "keep_lantern", At = Vector3.new(-20, 0, 0), Turn = 90, Height = 6.5 },
	{ Model = "keep_lantern", At = Vector3.new(20, 0, 0), Turn = -90, Height = 6.5 },
	-- flower beds where people don't walk
	{ Model = "keep_flowerbed", At = Vector3.new(-14, 0, 22), Turn = 0, Height = 1.4 },
	{ Model = "keep_flowerbed", At = Vector3.new(14, 0, 22), Turn = 0, Height = 1.4 },
	{ Model = "keep_flowerbed", At = Vector3.new(-48, 0, 30), Turn = 90, Height = 1.4 },
	{ Model = "keep_flowerbed", At = Vector3.new(48, 0, 30), Turn = 90, Height = 1.4 },
	{ Model = "keep_flowerbed", At = Vector3.new(-17, 0, -30), Turn = 0, Height = 1.4 },
	{ Model = "keep_flowerbed", At = Vector3.new(17, 0, -30), Turn = 0, Height = 1.4 },
}
-- the keep's banners hang on the inside of the palisade
HubLayout.Banners = {
	{ At = Vector3.new(-30, 0, -47), Turn = 0 }, { At = Vector3.new(30, 0, -47), Turn = 0 },
	{ At = Vector3.new(-57, 0, -20), Turn = 90 }, { At = Vector3.new(57, 0, -20), Turn = -90 },
	{ At = Vector3.new(-57, 0, 20), Turn = 90 }, { At = Vector3.new(57, 0, 20), Turn = -90 },
	{ At = Vector3.new(-14, 0, 47), Turn = 180 }, { At = Vector3.new(14, 0, 47), Turn = 180 },
}
-- where the main avenue and the round plaza are paved (TerrainBuilder.Keep); paths lead from the plaza to every station
HubLayout.Avenue = { From = Vector3.new(0, 0, 44), To = Vector3.new(0, 0, -30), Width = 12 }
HubLayout.Plaza = { At = Vector3.new(0, 0, 2), Radius = 20 }
HubLayout.PathWidth = 8

-- an offset from the hub centre to a world position
function HubLayout.World(center, offset)
	return center + offset
end

return HubLayout
