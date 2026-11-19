-- Uploaded art (painted icons). scripts/upload_art.py fills in the ids.
-- An empty id means "not uploaded yet": the game then draws a simple shape instead.
local Art = {}

Art.Icons = {
	shop = "87928469399792",
	daily = "101791243220867",
	backpack = "123399618508905",
	heroes = "123510789295477",
	quests = "95883577356523",
	pets = "71590920948801",
	season = "115053825281188",
	gem = "137070824220084",
	gold = "97070240905377",
	mana = "98616273109384",
	scrap = "124525701613671",
	lock = "93238414154162",
	tower_ranger = "137781142830567",
	tower_flame = "84677455373197",
	tower_frost = "140456354843254",
	tower_storm = "138499479214660",
	tower_ballista = "109131683987177",
	hero_swordmaster = "107097240985907",
	hero_hunter = "77953179182389",
	hero_mage = "99257200114899",
	hero_engineer = "124423861529707",
}

-- 3D models built in Blender (art/blender), uploaded by scripts/upload_models.py
Art.Models = {
	map_rift = "110475421435503",
	crystal_cluster = "117863445799774",
	map_camp = "83613241654248",
	tree_oak = "86771716646437",
	tree_dead = "99347777983539",
	map_portal = "89487886262773",
	map_gate = "108646967586771",
	enemy_goblin = "96884241329919",
	tower_storm = "93542704210272",
	tower_frost = "119917165190696",
	tower_ballista = "97849324321352",
	tower_flame = "122997798823358",
	tower_ranger = "101150947788778",
}

-- painted textures (Decal ids, resolved like the icons into ReplicatedStorage.ArtImages):
-- sky boxes, terrain looks and the baked paint of the Blender models (paint_<model name>)
Art.Textures = {
	sky_magma_side = "86765015504788",
	sky_magma_up = "135493064995244",
	sky_forest_side = "130463897132256",
	sky_forest_up = "75511505634263",
	sky_forest_down = "112098184845061",
	t_grass = "125974768344376",
	t_forest_dirt = "125681691745978",
	t_moss_rock = "117697922325700",
	paint_tree_oak = "86099707359138",
	paint_tree_dead = "115071143061598",
	paint_map_camp = "130036189894827",
	sky_crystal_side = "94067426790712",
	sky_crystal_up = "104643682364756",
	sky_crystal_down = "109539278410545",
	t_cave_floor = "82346507296465",
	t_cave_wall = "131792067702208",
	paint_crystal_cluster = "117491160837660",
	paint_map_rift = "116951210349756",
	sky_magma_down = "77642380587896",
	t_ground = "112898416512039",
	t_cobble = "136419768665426",
	t_ash = "115420467601271",
	t_cliff = "131115628073221",
	basalt = "138199478287556",
	lava_rock = "79265173284282",
	paint_tower_ranger = "73163763407521",
	paint_map_gate = "108175438908847",
	paint_map_portal = "133190301467535",
	paint_tower_flame = "81135491074763",
	paint_tower_frost = "80064261233050",
	paint_tower_storm = "104244733902784",
	paint_tower_ballista = "132146592025438",
	rough_full = "76185652094317",
}

-- the image for an icon name (filled in by ArtService once loaded), or nil
function Art.Image(name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("ArtImages")
	return folder and folder:GetAttribute(string.lower(name or "")) or nil
end

-- true when this icon was uploaded (its image may still be loading)
function Art.Has(name)
	local id = Art.Icons[string.lower(name or "")]
	return id ~= nil and id ~= ""
end

return Art
