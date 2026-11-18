-- Skins (looks only, never stats) and the Robux shop.
--
-- ROBUX: create each game pass / developer product in Creator Hub
-- (your game > Monetization), then paste its ID number below instead of 0.
-- Anything with Id = 0 shows as "Coming soon" and can't be bought.
local Store = {}

-------------------------------------------------------------------------------
-- Game passes: bought once, kept forever
-------------------------------------------------------------------------------
Store.GamePasses = {
	VIP = { Id = 0, Name = "VIP", Price = 399,
		Text = "VIP name tag, +50% daily reward gems, VIP cape" },
	BigBackpack = { Id = 0, Name = "Bigger Backpack", Price = 199,
		Text = "Backpack holds 120 items instead of 60" },
	AutoCollect = { Id = 0, Name = "Auto Collect", Price = 149,
		Text = "Loot and gems are picked up for you" },
	Speed3x = { Id = 0, Name = "3x Speed", Price = 249,
		Text = "Adds a 3x step to the speed button" },
}
Store.GamePassOrder = { "VIP", "BigBackpack", "AutoCollect", "Speed3x" }

-------------------------------------------------------------------------------
-- Developer products: can be bought again and again
-------------------------------------------------------------------------------
Store.Products = {
	Gems100 = { Id = 0, Name = "100 Gems", Price = 49, Gems = 100 },
	Gems550 = { Id = 0, Name = "550 Gems", Price = 199, Gems = 550, Text = "10% bonus" },
	Gems1200 = { Id = 0, Name = "1,200 Gems", Price = 399, Gems = 1200, Text = "20% bonus" },
	Gems2600 = { Id = 0, Name = "2,600 Gems", Price = 799, Gems = 2600, Text = "30% bonus" },
	BoostXp = { Id = 0, Name = "2x XP (30 min)", Price = 79, Boost = "Xp", Minutes = 30 },
	BoostGold = { Id = 0, Name = "2x Gold (30 min)", Price = 79, Boost = "Gold", Minutes = 30 },
	StarterPack = { Id = 0, Name = "Starter Pack", Price = 99, Gems = 300, Skin = "CapeHero", Once = true,
		Text = "300 gems + the Hero cape. Only once!" },
}
Store.ProductOrder = { "StarterPack", "Gems100", "Gems550", "Gems1200", "Gems2600", "BoostXp", "BoostGold" }

-------------------------------------------------------------------------------
-- Skins: change looks only. Placeholders for now (colour changes = "Rare").
-- Target = a defender type, or "Cape" for the hero's cape.
-------------------------------------------------------------------------------
Store.Skins = {
	-- defenders
	RangerRoyal = { Target = "Ranger", Name = "Royal Ranger", Tier = "Rare", Price = 80,
		Primary = Color3.fromRGB(70, 60, 140), Accent = Color3.fromRGB(255, 210, 80) },
	RangerShadow = { Target = "Ranger", Name = "Shadow Ranger", Tier = "Rare", Price = 80,
		Primary = Color3.fromRGB(35, 30, 45), Accent = Color3.fromRGB(170, 80, 255) },
	FlameCandy = { Target = "FlameCannon", Name = "Candy Cannon", Tier = "Rare", Price = 100,
		Primary = Color3.fromRGB(255, 150, 200), Accent = Color3.fromRGB(120, 230, 255) },
	FlameGold = { Target = "FlameCannon", Name = "Golden Cannon", Tier = "Rare", Price = 120,
		Primary = Color3.fromRGB(220, 170, 50), Accent = Color3.fromRGB(255, 240, 160) },
	FrostToxic = { Target = "FrostCrystal", Name = "Toxic Crystal", Tier = "Rare", Price = 100,
		Primary = Color3.fromRGB(60, 80, 50), Accent = Color3.fromRGB(120, 255, 80) },
	StormSunset = { Target = "StormObelisk", Name = "Sunset Obelisk", Tier = "Rare", Price = 120,
		Primary = Color3.fromRGB(120, 60, 60), Accent = Color3.fromRGB(255, 160, 60) },
	BallistaBone = { Target = "Ballista", Name = "Bone Ballista", Tier = "Rare", Price = 120,
		Primary = Color3.fromRGB(230, 225, 210), Accent = Color3.fromRGB(200, 40, 40) },
	-- hero capes
	CapeRed = { Target = "Cape", Name = "Red Cape", Tier = "Rare", Price = 60, Primary = Color3.fromRGB(190, 30, 40) },
	CapeNight = { Target = "Cape", Name = "Night Cape", Tier = "Rare", Price = 90, Primary = Color3.fromRGB(30, 30, 70),
		Accent = Color3.fromRGB(200, 200, 255) },
	CapeHero = { Target = "Cape", Name = "Hero Cape", Tier = "Rare", Price = 0, NotForSale = true,
		Primary = Color3.fromRGB(40, 110, 220), Accent = Color3.fromRGB(255, 220, 80) },
	CapeVIP = { Target = "Cape", Name = "VIP Cape", Tier = "Rare", Price = 0, NotForSale = true,
		Primary = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(255, 255, 255) },
	-- free ones, so everyone has something to show
	CapeGreen = { Target = "Cape", Name = "Forest Cape", Tier = "Rare", Price = 0, Free = true, Primary = Color3.fromRGB(50, 120, 60) },
	RangerForest = { Target = "Ranger", Name = "Forest Ranger", Tier = "Rare", Price = 0, Free = true,
		Primary = Color3.fromRGB(60, 100, 50), Accent = Color3.fromRGB(150, 220, 100) },
}
Store.SkinOrder = { "CapeGreen", "RangerForest", "CapeRed", "CapeNight", "RangerRoyal", "RangerShadow", "FlameCandy",
	"FlameGold", "FrostToxic", "StormSunset", "BallistaBone", "CapeHero", "CapeVIP" }
Store.FeaturedCount = 4 -- skins on offer each day
Store.FeaturedDiscount = 0.2 -- 20% off

-- today's featured skins (the same for everyone, changes at UTC midnight)
function Store.Featured()
	local day = os.time() // 86400
	local rng = Random.new(day * 4567)
	local pool = {}
	for _, id in Store.SkinOrder do
		local skin = Store.Skins[id]
		if skin.Price > 0 and not skin.NotForSale then
			table.insert(pool, id)
		end
	end
	local picked = {}
	for _ = 1, math.min(Store.FeaturedCount, #pool) do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return picked
end

function Store.PriceOf(skinId)
	local skin = Store.Skins[skinId]
	if not skin then
		return nil
	end
	if table.find(Store.Featured(), skinId) then
		return math.floor(skin.Price * (1 - Store.FeaturedDiscount))
	end
	return skin.Price
end

return Store
