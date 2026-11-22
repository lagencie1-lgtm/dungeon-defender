-- The Watch Keep (the new Outpost) as data: every place in studs from Config.OutpostCenter, +Z towards the
-- spawn (south), -Z towards the portal (north). The builder (server/OutpostKeep) and the screens read this,
-- so the layout can be checked and changed in one place. Concept and reasons: reviews/hub/benchmark.md.
local HubLayout = {}

HubLayout.Size = Vector2.new(116, 96) -- inside the walls (X, Z)
HubLayout.Spawn = Vector3.new(0, 0, 36) -- faces north, straight at the portal
-- the Beacon Tower (Lemp's pick): the landmark, with the portal standing in the archway at its foot
HubLayout.Portal = Vector3.new(0, 0, -36) -- 72 studs ahead of the spawn: the whole tower fits the spawn view
HubLayout.PortalHeight = 18 -- the portal model, sized to fit the archway (14 wide at a 42-stud tower)
HubLayout.BeaconHeight = 42
-- walk-in map pads in front of the gate (one per map, in Config.MapOrder)
HubLayout.Pads = {
	{ Map = "CursedForest", At = Vector3.new(-16, 0, -15) },
	{ Map = "MagmaFortress", At = Vector3.new(0, 0, -13) },
	{ Map = "CrystalCaves", At = Vector3.new(16, 0, -15) },
}
HubLayout.PadRadius = 5.5
HubLayout.PadCountdown = 4 -- seconds standing on a pad before the run starts

-- stations on the ring around the plaza: one big word, the icon beside it, the painted prop, a walk-in ring
HubLayout.Stations = {
	{ Id = "Forge", Word = "FORGE", Icon = "backpack", Model = "outpost_forge", Height = 13, At = Vector3.new(-42, 0, -14),
		Action = "Backpack", Color = Color3.fromRGB(255, 170, 80) },
	{ Id = "Heroes", Word = "HEROES", Icon = "heroes", Model = "outpost_altar", Height = 13, At = Vector3.new(-42, 0, 12),
		Action = "Heroes", Color = Color3.fromRGB(120, 230, 120) },
	{ Id = "Shop", Word = "SHOP", Icon = "shop", Model = "outpost_stall", Height = 10, At = Vector3.new(42, 0, -14),
		Action = "Shop", Color = Color3.fromRGB(90, 220, 255) },
	{ Id = "Pets", Word = "PETS", Icon = "pets", Model = "outpost_nest", Height = 6, At = Vector3.new(42, 0, 12),
		Action = "Pets", Color = Color3.fromRGB(170, 240, 120) },
	{ Id = "Quests", Word = "QUESTS", Icon = "quests", Model = "outpost_questboard", Height = 9, At = Vector3.new(-26, 0, 32),
		Action = "Quests", Color = Color3.fromRGB(255, 215, 120) },
	{ Id = "Rewards", Word = "REWARDS", Icon = "daily", Model = "outpost_chest", Height = 5, At = Vector3.new(26, 0, 32),
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

-- where the main avenue and the round plaza are paved (TerrainBuilder.Keep)
HubLayout.Avenue = { From = Vector3.new(0, 0, 44), To = Vector3.new(0, 0, -30), Width = 12 }
HubLayout.Plaza = { At = Vector3.new(0, 0, 2), Radius = 17 }

-- an offset from the hub centre to a world position
function HubLayout.World(center, offset)
	return center + offset
end

return HubLayout
