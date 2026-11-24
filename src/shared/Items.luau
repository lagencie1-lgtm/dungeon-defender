-- Everything about gear (weapons, helmets, armor, boots, trinkets):
-- rarities, stats, names, upgrade costs. Shared so the screen can show
-- the same numbers the server uses.
local Items = {}

Items.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(190, 190, 190), Mult = 1, Stats = 1, Scrap = 1, Weight = 60 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), Mult = 1.25, Stats = 2, Scrap = 3, Weight = 25 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Mult = 1.55, Stats = 2, Scrap = 8, Weight = 10, Beam = true },
	{ Name = "Epic", Color = Color3.fromRGB(180, 90, 255), Mult = 1.9, Stats = 3, Scrap = 18, Weight = 4, Beam = true },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 160, 40), Mult = 2.4, Stats = 3, Scrap = 40, Weight = 0.9, Beam = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 120), Mult = 3, Stats = 4, Scrap = 90, Weight = 0.1, Beam = true },
}

-- what the stats do (all are percents)
Items.Stats = {
	Power = { Name = "Power", Text = "hero damage", Base = 4, PerLevel = 0.6 },
	Command = { Name = "Command", Text = "defender damage", Base = 4, PerLevel = 0.6 },
	Engineering = { Name = "Engineering", Text = "defender speed and range", Base = 2.5, PerLevel = 0.35 },
	Crit = { Name = "Crit", Text = "chance for double hero damage", Base = 2, PerLevel = 0.15, Max = 60 },
	GoldFind = { Name = "Gold Find", Text = "more gold after each run", Base = 5, PerLevel = 0.5 },
}
Items.StatOrder = { "Power", "Command", "Engineering", "Crit", "GoldFind" }

Items.Slots = { "Weapon", "Helmet", "Armor", "Boots", "Trinket" }
Items.SlotWeights = { Weapon = 40, Helmet = 15, Armor = 15, Boots = 15, Trinket = 15 }
-- each slot leans towards one stat (it always has that one)
Items.SlotMainStat = { Weapon = "Power", Helmet = "Command", Armor = "Engineering", Boots = "Crit", Trinket = "GoldFind" }

-- the Swordmaster's weapon types change how the sword hit (F) works
Items.WeaponTypes = {
	Longsword = { Name = "Longsword", Damage = 1, Cooldown = 0.5, Range = 10, Targets = 3, Text = "Balanced" },
	Greatsword = { Name = "Greatsword", Damage = 1.7, Cooldown = 0.85, Range = 13, Targets = 6, Text = "Slow, hits a crowd" },
	TwinBlades = { Name = "Twin Blades", Damage = 0.55, Cooldown = 0.25, Range = 9, Targets = 1, Text = "Very fast, one goblin" },
	-- the Goblin King's own weapon (Config.BossRewards): never rolled at random, only from the King.
	-- ArmorBreak = seconds an armored enemy you hit takes full damage, from you AND from every defender
	KingsCleaver = { Name = "King's Cleaver", Damage = 1.3, Cooldown = 0.65, Range = 12, Targets = 4, ArmorBreak = 3,
		Text = "Cracks armor: armored enemies you hit take full damage from you and your defenders for 3 s" },
}
Items.WeaponTypeOrder = { "Longsword", "Greatsword", "TwinBlades" }
Items.ArmorNames = { Helmet = { "Helm", "Hood", "Crown" }, Armor = { "Chestplate", "Tunic", "Mail" },
	Boots = { "Boots", "Sandals", "Greaves" }, Trinket = { "Amulet", "Ring", "Charm" } }

Items.Prefixes = {
	{ "Rusty", "Chipped", "Old", "Bent", "Budget" },
	{ "Sturdy", "Sharp", "Polished", "Trusty" },
	{ "Gleaming", "Runed", "Moonlit", "Sneaky" },
	{ "Arcane", "Stormforged", "Shadow", "Frostbitten" },
	{ "Kingsbane", "Sunfire", "Dragonbone", "Starfall" },
	{ "Mythic", "Void-Touched", "World-Ending", "Absolutely Cracked" },
}
-- very rare joke names for Mythic items
Items.MemeNames = {
	Weapon = { "Goblin Bonker 9000", "The Last Braincell", "Certified Pointy Stick", "Big Sword Energy" },
	Helmet = { "Thinking Cap (Unused)", "Hat of Infinite Rizz" },
	Armor = { "Hoodie of Main Character Energy" },
	Boots = { "Zoomies" },
	Trinket = { "Lucky Rock", "Pebble of Pure Vibes" },
}

Items.MaxPlus = 10
Items.BackpackSize = 60

-- a stat's value on an item, with its +level included
function Items.StatValue(item, stat)
	local v = item.stats[stat]
	if not v then
		return 0
	end
	return v * (1 + 0.1 * (item.plus or 0))
end

function Items.UpgradeCost(item)
	local plus = item.plus or 0
	if plus >= Items.MaxPlus then
		return nil, nil
	end
	local gold = math.floor(25 * (plus + 1) ^ 1.7 * (1 + item.rarity * 0.3))
	local scrap = 0
	if plus >= 7 then
		scrap = (plus - 6) * 2 * item.rarity -- the last steps also need scrap
	end
	return gold, scrap
end

-- Gear sets (Loot screen): save what you wear in a slot, put it all back on in one tap (research report: a
-- player must be able to try another build quickly). Free for everyone.
Items.GearSets = 3
-- Auto-salvage (Loot screen): new drops up to this rarity that are worse than what you wear in their slot become
-- scrap straight away. 0 = off. The choices the button steps through:
Items.AutoSalvageSteps = { 0, 1, 2 } -- off, Common, Common and Uncommon

function Items.SalvageValue(item)
	return Items.Rarities[item.rarity].Scrap + (item.plus or 0) * 2
end

function Items.DisplayName(item)
	return (item.plus and item.plus > 0) and (item.name .. " +" .. item.plus) or item.name
end

-- add up everything a player has equipped. equipped = { Weapon = item, ... }
-- one number for a set of gear (Might): every stat counts, rarer stats weigh more, upgrades included
Items.MightWeights = { Power = 1, Command = 1, Engineering = 1.5, Crit = 3, GoldFind = 0.5 }
function Items.Might(equipped)
	local might = 0
	for _, item in equipped do
		for stat in item.stats do
			might += Items.StatValue(item, stat) * (Items.MightWeights[stat] or 1)
		end
	end
	return math.floor(might + 0.5)
end

function Items.Totals(equipped)
	local totals = { Power = 0, Command = 0, Engineering = 0, Crit = 0, GoldFind = 0 }
	for _, item in equipped do
		for stat in item.stats do
			if totals[stat] then
				totals[stat] += Items.StatValue(item, stat)
			end
		end
	end
	totals.Crit = math.min(totals.Crit, Items.Stats.Crit.Max)
	return totals
end

function Items.FormatStat(stat, value)
	return string.format("+%.1f%% %s", value, Items.Stats[stat].Name)
end

return Items
