-- Cosmetic palettes shared by the shop and the character renderer.
local Config = require(script.Parent.Config)

local GearLooks = {}

GearLooks.Slots = {
	{ Id = "Swords", Field = "Sword", Name = "Weapons", Default = "Classic" },
	{ Id = "ArmorSkins", Field = "ArmorSkin", Name = "Armor", Default = "Default" },
	{ Id = "HelmSkins", Field = "HelmSkin", Name = "Helms", Default = "Default" },
	{ Id = "BootSkins", Field = "BootSkin", Name = "Boots", Default = "Default" },
	{ Id = "AmuletSkins", Field = "AmuletSkin", Name = "Amulets", Default = "Default" },
}

local rgb = Color3.fromRGB
GearLooks.Sets = {
	{ Id = "Brambleguard", Name = "Brambleguard", Finish = "Moss green and aged brass", Color = rgb(171, 222, 108), PaintTint = rgb(147, 194, 108),
		Leather = rgb(68, 97, 57), Metal = rgb(162, 130, 72), Armor = "Tunic", Helm = "Hood",
		Jewel = Enum.PartType.Ball, BootCuff = 0.28 },
	{ Id = "Cinderforge", Name = "Cinderforge", Finish = "Ember orange and hammered copper", Color = rgb(246, 150, 70), PaintTint = rgb(209, 133, 102),
		Leather = rgb(88, 56, 47), Metal = rgb(180, 114, 69), Armor = "Chestplate", Helm = "Helm",
		Jewel = Enum.PartType.Block, BootCuff = 0.42 },
	{ Id = "Rimewarden", Name = "Rimewarden", Finish = "Ice blue and silver", Color = rgb(150, 227, 247), PaintTint = rgb(139, 191, 225),
		Leather = rgb(63, 87, 111), Metal = rgb(161, 188, 196), Armor = "Mail", Helm = "Crown",
		Jewel = Enum.PartType.Block, BootCuff = 0.36 },
	{ Id = "Riftkeeper", Name = "Riftkeeper", Finish = "Amethyst and pale iron", Color = rgb(199, 160, 245), PaintTint = rgb(162, 132, 211),
		Leather = rgb(81, 64, 112), Metal = rgb(169, 152, 197), Armor = "Chestplate", Helm = "Helm",
		Jewel = Enum.PartType.Ball, BootCuff = 0.32 },
	{ Id = "Hearthwatch", Name = "Hearthwatch", Finish = "Brick red and worn bronze", Color = rgb(220, 151, 91),
		PaintTint = rgb(181, 103, 94), Leather = rgb(103, 59, 51), Metal = rgb(152, 112, 78),
		Armor = "Mail", Helm = "Helm", Jewel = Enum.PartType.Block, BootCuff = 0.38 },
	{ Id = "Lanternwood", Name = "Lanternwood", Finish = "Honey amber and dark oak", Color = rgb(255, 205, 118),
		PaintTint = rgb(217, 168, 102), Leather = rgb(110, 79, 54), Metal = rgb(174, 130, 64),
		Armor = "Tunic", Helm = "Hood", Jewel = Enum.PartType.Ball, BootCuff = 0.25 },
	{ Id = "Moonstone", Name = "Moonstone", Finish = "Pearl white and slate blue", Color = rgb(206, 219, 248),
		PaintTint = rgb(166, 171, 210), Leather = rgb(60, 75, 108), Metal = rgb(206, 195, 179),
		Armor = "Mail", Helm = "Crown", Jewel = Enum.PartType.Block, BootCuff = 0.28 },
	{ Id = "Suncrest", Name = "Suncrest", Finish = "Sunlit brass and ivory", Color = rgb(255, 224, 139),
		PaintTint = rgb(229, 197, 143), Leather = rgb(114, 85, 63), Metal = rgb(188, 138, 69),
		Armor = "Chestplate", Helm = "Crown", Jewel = Enum.PartType.Ball, BootCuff = 0.45 },
}

GearLooks.BySlot = {}
GearLooks.Items = {}
for _, slot in GearLooks.Slots do
	GearLooks.BySlot[slot.Id] = slot
	local items = {}
	if slot.Id == "Swords" then
		items[1] = Config.Swords[1]
	else
		items[1] = { Id = slot.Default, Name = "Default", Price = 0, Color = rgb(201, 194, 179) }
	end
	for _, set in GearLooks.Sets do
		local item = table.clone(set)
		item.Price = 0
		item.Free = true
		table.insert(items, item)
	end
	if slot.Id == "Swords" then
		for i = 2, #Config.Swords do
			table.insert(items, Config.Swords[i])
		end
	end
	GearLooks.Items[slot.Id] = items
end

function GearLooks.OutfitItem(slot, outfitId)
	return outfitId == "Original" and slot.Default or outfitId
end

function GearLooks.IsOutfitWorn(player, outfitId)
	for _, slot in GearLooks.Slots do
		if player:GetAttribute("Equipped" .. slot.Field) ~= GearLooks.OutfitItem(slot, outfitId) then
			return false
		end
	end
	return true
end

function GearLooks.Find(kind, id)
	local items = GearLooks.Items[kind]
	return items and Config.FindById(items, id) or nil
end

function GearLooks.Worn(player, kind, field)
	local look = GearLooks.Find(kind, player:GetAttribute("Equipped" .. field))
	return look and look.PaintTint and look or nil
end

return GearLooks
