-- Uploaded art (painted icons). scripts/upload_art.py fills in the ids.
-- An empty id means "not uploaded yet": the game then draws a simple shape instead.
local Art = {}

Art.Icons = {
	shop = "",
	daily = "",
	backpack = "",
	heroes = "",
	quests = "",
	pets = "",
	season = "",
	gem = "",
	gold = "",
	mana = "",
	scrap = "",
	lock = "",
	tower_ranger = "",
	tower_flame = "",
	tower_frost = "",
	tower_storm = "",
	tower_ballista = "",
	hero_swordmaster = "",
	hero_hunter = "",
	hero_mage = "",
	hero_engineer = "",
}

-- "rbxassetid://123" for an icon name, or nil when it isn't uploaded yet
function Art.Image(name)
	local id = Art.Icons[string.lower(name or "")]
	if id and id ~= "" then
		return "rbxassetid://" .. id
	end
	return nil
end

return Art
