-- Only in the test build: uses hero abilities, switches heroes, spends stat
-- points and works the backpack, printing [AUTOTEST-CLIENT] lines.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameState = ReplicatedStorage:WaitForChild("GameState")

local function log(...)
	print("[AUTOTEST-CLIENT]", ...)
end

task.wait(8)
log("client started, state", GameState:GetAttribute("State"))

local heroes = { "Swordmaster", "RuneMage", "Engineer" }
local i = 0
task.spawn(function()
	while true do
		task.wait(0.4)
		Remotes.HeroAttack:FireServer()
		Remotes.HeroWhirlwind:FireServer()
		Remotes.HeroLeap:FireServer()
	end
end)

task.spawn(function()
	while true do
		task.wait(6)
		i += 1
		local ok, reason = Remotes.SelectHero:InvokeServer(heroes[i % #heroes + 1])
		log("select hero", heroes[i % #heroes + 1], ok, reason)
		log("spend point", Remotes.SpendPoint:InvokeServer("Power"))
	end
end)

task.wait(10)
local items, gear = Remotes.GetInventory:InvokeServer()
log("inventory", items and #items or "nil")
if items and #items > 0 then
	for n = 1, math.min(5, #items) do
		local item = items[n]
		log("equip", item.name, Remotes.EquipGear:InvokeServer(item.id))
		log("upgrade", item.name, Remotes.UpgradeGear:InvokeServer(item.id))
	end
	local last = items[#items]
	log("salvage", last.name, Remotes.SalvageGear:InvokeServer(last.id))
end
log("buy", Remotes.BuyItem:InvokeServer("Swords", "Baguette"))
log("buy rebirth sword (should fail)", Remotes.BuyItem:InvokeServer("Swords", "Starforged"))
for _ = 1, 3 do
	local ok, pet = Remotes.HatchEgg:InvokeServer("ForestEgg")
	log("hatch", ok, ok and pet.kind or pet)
	if ok then
		log("equip pet", Remotes.EquipPet:InvokeServer(pet.id))
	end
end
log("quests", #Remotes.GetQuests:InvokeServer())
log("claim quest 1", Remotes.ClaimQuest:InvokeServer(1))
task.delay(200, function()
	log("spend ascension", Remotes.SpendAscension:InvokeServer("Power"))
	log("rebirth", Remotes.Rebirth:InvokeServer())
end)
log("daily", Remotes.ClaimDaily:InvokeServer())
