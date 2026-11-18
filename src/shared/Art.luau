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
	tower_frost = "",
	tower_storm = "",
	tower_ballista = "",
	hero_swordmaster = "107097240985907",
	hero_hunter = "",
	hero_mage = "",
	hero_engineer = "",
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
