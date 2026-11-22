-- Sends only the selected shop model to the requesting player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local GearLooks = require(ReplicatedStorage.Shared.GearLooks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Store = require(ReplicatedStorage.Shared.Store)
local ArtService = require(script.Parent.ArtService)
local HeroService = require(script.Parent.HeroService)
local PetService = require(script.Parent.PetService)
local StoreService = require(script.Parent.StoreService)

local ShopPreviewService = {}
local V = Vector3.new
local wood = Color3.fromRGB(151, 116, 85)
local cloth = Color3.fromRGB(74, 64, 56)
local lastRequest = {}

local function figurePart(model, name, size, x, y, z, color, rotation)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(x, y, z) * (rotation or CFrame.identity)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Parent = model
	return part
end

local function gearPreview(player, slotId, id, outfitId)
	local model = Instance.new("Model")
	local hero = player:GetAttribute("HeroId") or "Swordmaster"
	model:SetAttribute("HeroId", hero)
	model:SetAttribute("WeaponType", player:GetAttribute("WeaponType"))
	model:SetAttribute("WeaponRarity", player:GetAttribute("WeaponRarity"))
	local anchors = {}
	local function body(name, size, x, y, z, color, rotation)
		table.insert(anchors, figurePart(model, name, size, x, y, z, color, rotation))
	end

	for _, slot in GearLooks.Slots do
		if outfitId or slot.Id == slotId then
			model:SetAttribute("Equipped" .. slot.Field, outfitId and GearLooks.OutfitItem(slot, outfitId) or id)
		end
	end
	if outfitId == "Original" or slotId == "HelmSkins" then
		model:SetAttribute("WornHelmet", player:GetAttribute("WornHelmet"))
	end
	if outfitId == "Original" or slotId == "ArmorSkins" then
		model:SetAttribute("WornArmor", player:GetAttribute("WornArmor"))
	end

	if outfitId or slotId == "ArmorSkins" or slotId == "AmuletSkins" then
		body("UpperTorso", V(2, 1.5, 1), 0, 3.05, 0, cloth)
	end
	if outfitId or slotId == "HelmSkins" then
		local head = figurePart(model, "Head", V(1.16, 1.16, 1.16), 0, 4.39, 0, wood)
		head.Shape = Enum.PartType.Ball
		table.insert(anchors, head)
	end
	if outfitId or slotId == "BootSkins" then
		for _, side in { -1, 1 } do
			local prefix = side < 0 and "Left" or "Right"
			body(prefix .. "Foot", V(0.83, 0.56, 1.07), side * 0.5, 0.28, -0.08, cloth)
			if outfitId then
				body(prefix .. "Leg", V(0.81, 1.66, 0.83), side * 0.5, 1.29, 0, cloth)
			end
		end
	end
	if outfitId or slotId == "Swords" then
		local angle = hero == "Engineer" or hero == "Swordmaster"
		local right = CFrame.Angles(math.rad(angle and 72 or -5), 0, math.rad(-14))
		local left = CFrame.Angles(math.rad(angle and 67 or 0), 0, math.rad(14))
		body("RightHand", V(0.51, 0.63, 0.52), 1.41, 2.05, -0.29, wood, right)
		body("LeftHand", V(0.51, 0.63, 0.52), -1.39, 2.03, -0.08, wood, left)
		if outfitId then
			body("RightArm", V(0.65, 1.13, 0.75), 1.35, 2.85, -0.1, cloth, CFrame.Angles(0, 0, math.rad(9)))
			body("LeftArm", V(0.65, 1.13, 0.75), -1.35, 2.85, 0, cloth, CFrame.Angles(0, 0, math.rad(-9)))
		end
	end
	HeroService.RenderAppearance(model)
	for _, part in model:GetChildren() do
		part.Anchored = true
		local weld = part:FindFirstChildOfClass("WeldConstraint")
		if weld then
			weld:Destroy()
		end
	end
	if not outfitId then
		-- The piece alone fills the frame. Keep the head and chest only for crowns and pendants.
		local hasPiece = #model:GetChildren() > #anchors
		for _, anchor in anchors do
			if not hasPiece or (slotId ~= "AmuletSkins" and slotId ~= "HelmSkins") then
				anchor:Destroy()
			end
		end
	end
	return model
end

local function skinPreview(player, skin)
	if skin.Outfit then
		return gearPreview(player, nil, nil, skin.Outfit)
	end
	if skin.Target == "Cape" then
		local model = Instance.new("Model")
		figurePart(model, "UpperTorso", V(2, 1.5, 1), 0, 2.4, 0, cloth)
		StoreService.AttachCape(model, skin)
		model:SetAttribute("RearView", true)
		return model
	end
	local modelName = Config.TowerIcons[skin.Target]
	if skin.Target == "Pet" then
		local pet = PetService.EquippedPet(player)
		modelName = "pet_" .. string.lower(pet and pet.kind or "babydragon")
	end
	local template = modelName and ArtService.Model(modelName)
	if not template then
		return nil
	end
	local model = template:Clone()
	StoreService.ApplyModelSkin(model, skin)
	return model
end

local function preview(player, kind, id)
	if type(kind) ~= "string" or type(id) ~= "string" then
		return nil
	end
	local skin = kind == "Skins" and Store.Skins[id]
	local gear = GearLooks.Find(kind, id)
	if not skin and not gear then
		return nil
	end
	local now = os.clock()
	if now - (lastRequest[player] or -1) < 0.15 then
		return nil, "Try again"
	end
	lastRequest[player] = now
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil, "Preview is loading"
	end
	local model = skin and skinPreview(player, skin) or (gear and gearPreview(player, kind, id))
	if not model or #model:GetChildren() == 0 then
		if model then
			model:Destroy()
		end
		local slot = GearLooks.BySlot[kind]
		local original = slot and id == slot.Default
		return nil, original and "No piece equipped in this slot" or "Preview is loading", original
	end

	local transport = gui:FindFirstChild("ShopPreviewModels")
	if not transport then
		transport = Instance.new("Folder")
		transport.Name = "ShopPreviewModels"
		transport.Parent = gui
	end
	transport:ClearAllChildren()
	model.Name = HttpService:GenerateGUID(false)
	model.Parent = transport
	task.delay(15, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	return model.Name
end

function ShopPreviewService.Start()
	Remotes.GetLookPreview.OnServerInvoke = preview
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopPreviewService
