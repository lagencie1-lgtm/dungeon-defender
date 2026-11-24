-- The messages the players' computers and the server send each other.
-- The server makes them, players' computers wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"StartWave", "HeroAttack", "HeroWhirlwind", "HeroLeap", "PlayAgain", "Notify",
	"SetSpeed", "PickDifficulty",
	"LootDrop", "LootPicked", "PickupLoot", "VictoryChest", "Inventory", "SeenGear",
	"OpenPanel", "PickMap", "StartRun", "Quests", "PickMode", "Pets", "FinishTutorial", "Season", "Ping",
}
local FUNCTIONS = { "GearSet", "AutoSalvage", "PlaceTower", "UpgradeTower", "SellTower", "BuyItem", "EquipItem", "ClaimDaily",
	"EquipGear", "UpgradeGear", "SalvageGear", "GetInventory", "SelectHero", "SpendPoint", "ResetPoints",
	"ClaimQuest", "GetQuests", "Rebirth", "SpendAscension", "RedeemCode", "BuySkin", "EquipSkin", "ClaimSeason", "GetSeason",
	"HatchEgg", "EquipPet", "EvolvePet", "ReleasePet", "GetPets", "GetLookPreview", "FusePet", "FuseAllPets", "BuyPetWithDust" }

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			Instance.new("RemoteEvent", folder).Name = name
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			Instance.new("RemoteFunction", folder).Name = name
		end
	end
	if not folder:FindFirstChild("CombatFx") then
		Instance.new("UnreliableRemoteEvent", folder).Name = "CombatFx"
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in FUNCTIONS do
	Remotes[name] = folder:WaitForChild(name)
end
Remotes.CombatFx = folder:WaitForChild("CombatFx")

return Remotes
