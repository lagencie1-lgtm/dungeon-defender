-- Towers visible while their art loads (2026-11-24, research brief; coordinator: preload at run start, a stand-in
-- until the meshes are ready, no pop).
-- 1. As a run starts loading, fetch every tower look's meshes and textures (ReplicatedStorage.TowerAssets, written
--    by ArtService as the models load), so a placement uses warm assets.
-- 2. Every tower carries a "StandIn" (a few parts in its own colours, its footprint and height: TowerService). Here it
--    is shown until this client has that tower's look meshes and textures, then hidden (LocalTransparencyModifier).
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local preloaded = {}
local function preload()
	local folder = ReplicatedStorage:FindFirstChild("TowerAssets")
	if not folder then
		return
	end
	local ids = {}
	for name, list in folder:GetAttributes() do
		if not preloaded[name] then
			preloaded[name] = true
			for id in tostring(list):gmatch("%S+") do
				table.insert(ids, id)
			end
		end
	end
	if #ids > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
		end)
	end
end

local GameState = ReplicatedStorage:WaitForChild("GameState")
GameState:GetAttributeChangedSignal("State"):Connect(preload)
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("TowerAssets", 120)
	if folder then
		preload()
		folder.AttributeChanged:Connect(preload)
	end
end)

local function ready(look)
	if not look then
		return false
	end
	for _, d in look:GetDescendants() do
		if d:IsA("MeshPart") then
			if ContentProvider:GetAssetFetchStatus(d.MeshId) ~= Enum.AssetFetchStatus.Success then
				return false
			end
			if d.TextureID ~= "" and ContentProvider:GetAssetFetchStatus(d.TextureID) ~= Enum.AssetFetchStatus.Success then
				return false
			end
		end
	end
	return true
end

local function show(standIn, visible)
	for _, p in standIn:GetChildren() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

RunService.Heartbeat:Connect(function()
	local towers = workspace:FindFirstChild("Towers")   -- (made again for every map and run)
	if not towers then
		return
	end
	for _, t in towers:GetChildren() do
		local standIn = t:FindFirstChild("StandIn")
		if standIn then
			local done = ready(t:FindFirstChild("Look"))
			if standIn:GetAttribute("Hidden") ~= done then
				standIn:SetAttribute("Hidden", done)
				show(standIn, not done)
			end
		end
	end
end)
