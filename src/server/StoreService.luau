-- Skins (bought with gems, looks only) and the Robux shop: game passes,
-- developer products (gem packs, boosts, starter pack). Every purchase is
-- saved before Roblox is told it went through, so nobody pays for nothing.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Store = require(ReplicatedStorage.Shared.Store)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local StoreService = {}

local function skinsOf(profile)
	profile.Owned.Skins = profile.Owned.Skins or {}
	profile.Equipped.Skins = profile.Equipped.Skins or {}
	return profile.Owned.Skins, profile.Equipped.Skins
end

local function publish(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local owned, equipped = skinsOf(profile)
	player:SetAttribute("OwnedSkins", HttpService:JSONEncode(owned))
	player:SetAttribute("EquippedSkins", HttpService:JSONEncode(equipped))
	player:SetAttribute("EquippedCape", equipped.Cape or "")
	player:SetAttribute("StarterBought", profile.StarterBought == true)
	local boosts = profile.Boosts or {}
	player:SetAttribute("BoostXpUntil", boosts.Xp or 0)
	player:SetAttribute("BoostGoldUntil", boosts.Gold or 0)
end

-- the skin a player wears for a target ("Ranger", "Cape"...), or nil
function StoreService.SkinFor(player, target)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local _, equipped = skinsOf(profile)
	local id = equipped[target]
	return id and Store.Skins[id] or nil
end

-- recolours a defender model with a skin (placeholder look)
function StoreService.ApplyTowerSkin(model, skin)
	if not skin then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Material == Enum.Material.Neon then
				part.Color = skin.Accent or skin.Primary
			elseif part.Name ~= "Base" then
				part.Color = skin.Primary:Lerp(part.Color, 0.25)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- capes
-------------------------------------------------------------------------------
local function giveCape(player, character)
	for _, old in character:GetChildren() do
		if old.Name == "HeroCape" then
			old:Destroy()
		end
	end
	local skin = StoreService.SkinFor(player, "Cape")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not skin or not torso then
		return
	end
	local cape = Instance.new("Part")
	cape.Name = "HeroCape"
	cape.Size = Vector3.new(2.2, 3.2, 0.12)
	cape.Color = skin.Primary
	cape.Material = Enum.Material.Fabric
	cape.CanCollide = false
	cape.CanQuery = false
	cape.Massless = true
	cape.CFrame = torso.CFrame * CFrame.new(0, -0.9, 0.62) * CFrame.Angles(math.rad(8), 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = cape
	weld.Parent = cape
	cape.Parent = character
	if skin.Accent then
		local stripe = cape:Clone()
		stripe.Name = "HeroCape"
		stripe:ClearAllChildren()
		stripe.Size = Vector3.new(2.25, 0.3, 0.14)
		stripe.Color = skin.Accent
		stripe.Material = Enum.Material.Neon
		stripe.CFrame = cape.CFrame * CFrame.new(0, -1.3, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = stripe
		w.Parent = stripe
		stripe.Parent = character
	end
end

-------------------------------------------------------------------------------
-- skins bought with gems
-------------------------------------------------------------------------------
local function buySkin(player, id)
	local profile = DataService.Get(player)
	local skin = Store.Skins[id]
	if not profile or not skin then
		return false, "Unknown skin"
	end
	local owned = skinsOf(profile)
	if owned[id] then
		return false, "You already own this"
	end
	if skin.NotForSale then
		return false, "This skin comes from a pack or pass"
	end
	local price = Store.PriceOf(id)
	if profile.Gems < price then
		return false, "Not enough gems (need " .. price .. ")"
	end
	profile.Gems -= price
	owned[id] = true
	local _, equipped = skinsOf(profile)
	equipped[skin.Target] = id -- wear it right away
	DataService.Publish(player)
	publish(player)
	if skin.Target == "Cape" and player.Character then
		giveCape(player, player.Character)
	end
	task.spawn(DataService.Save, player)
	return true
end

-- id = a skin to wear, or "None:<target>" to take it off
local function equipSkin(player, id)
	local profile = DataService.Get(player)
	if not profile or type(id) ~= "string" then
		return false, "Still loading"
	end
	local owned, equipped = skinsOf(profile)
	local target = id:match("^None:(.+)$")
	if target then
		equipped[target] = nil
	else
		local skin = Store.Skins[id]
		if not skin or not owned[id] then
			return false, "You don't own this skin"
		end
		equipped[skin.Target] = id
		target = skin.Target
	end
	publish(player)
	if target == "Cape" and player.Character then
		giveCape(player, player.Character)
	end
	return true
end

-------------------------------------------------------------------------------
-- Robux: game passes
-------------------------------------------------------------------------------
local function passKeyById(id)
	for key, pass in Store.GamePasses do
		if pass.Id ~= 0 and pass.Id == id then
			return key
		end
	end
	return nil
end

local function grantPass(player, key)
	player:SetAttribute("Pass" .. key, true)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if key == "VIP" then
		skinsOf(profile).CapeVIP = true
	end
	publish(player)
end

local function checkPasses(player)
	for key, pass in Store.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

function StoreService.HasPass(player, key)
	return player:GetAttribute("Pass" .. key) == true
end

-------------------------------------------------------------------------------
-- Robux: developer products
-------------------------------------------------------------------------------
local function productById(id)
	for key, product in Store.Products do
		if product.Id ~= 0 and product.Id == id then
			return key, product
		end
	end
	return nil, nil
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox will try again later
	end
	profile.Receipts = profile.Receipts or {}
	if profile.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end
	local key, product = productById(receipt.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.Gems then
		profile.Gems += product.Gems
	end
	if product.Boost then
		profile.Boosts = profile.Boosts or {}
		local now = os.time()
		profile.Boosts[product.Boost] = math.max(profile.Boosts[product.Boost] or 0, now) + product.Minutes * 60
	end
	if product.Skin then
		skinsOf(profile)[product.Skin] = true
	end
	if key == "StarterPack" then
		profile.StarterBought = true
	end
	profile.Receipts[receipt.PurchaseId] = true
	DataService.Publish(player)
	publish(player)
	-- save first: only tell Roblox it worked once it's stored
	local saved = DataService.SaveNow(player)
	if not saved and not player:GetAttribute("SavesOff") then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Remotes.Notify:FireClient(player, "Thank you! " .. product.Name .. " added", Color3.fromRGB(120, 255, 160))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- true while a 2x boost is running
function StoreService.Boosted(player, kind)
	return (player:GetAttribute("Boost" .. kind .. "Until") or 0) > os.time()
end

function StoreService.Start()
	Remotes.BuySkin.OnServerInvoke = buySkin
	Remotes.EquipSkin.OnServerInvoke = equipSkin
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById(passId)
		if purchased and key then
			grantPass(player, key)
			Remotes.Notify:FireClient(player, "Thank you! " .. Store.GamePasses[key].Name .. " is yours", Color3.fromRGB(120, 255, 160))
		end
	end)
	table.insert(DataService.OnLoaded, function(player, profile)
		-- free skins for everyone
		local owned = skinsOf(profile)
		for id, skin in Store.Skins do
			if skin.Free then
				owned[id] = true
			end
		end
		publish(player)
		checkPasses(player)
		if player.Character then
			giveCape(player, player.Character)
		end
	end)
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("UpperTorso", 5)
			giveCape(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return StoreService
