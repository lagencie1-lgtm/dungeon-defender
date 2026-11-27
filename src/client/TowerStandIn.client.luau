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

-- (a fetch that failed counts as finished: the look draws what it has. And never longer than MAX_WAIT seconds from
-- when a look appears: the film once caught a stand-in kept for good next to the real tower while one fresh texture
-- was still processing on Roblox's side)
local MAX_WAIT = 1.5
local firstSeen = setmetatable({}, { __mode = "k" })
local function finished(id)
	local st = ContentProvider:GetAssetFetchStatus(id)
	return st == Enum.AssetFetchStatus.Success or st == Enum.AssetFetchStatus.Failure
end

local function ready(look)
	if not look then
		return false
	end
	firstSeen[look] = firstSeen[look] or os.clock()
	if os.clock() - firstSeen[look] > MAX_WAIT then
		return true
	end
	local texturesDone = true
	for _, d in look:GetDescendants() do
		if d:IsA("MeshPart") then
			if not finished(d.MeshId) then
				return false
			end
			if d.TextureID ~= "" and not finished(d.TextureID) then
				texturesDone = false
			end
		end
	end
	-- (the shapes are in: the paint gets a moment more, then the real look shows even unpainted, rather than the
	-- stand-in standing beside it)
	return texturesDone or os.clock() - firstSeen[look] > 0.8
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
			end
			-- (every frame, not only on a change: the camera's occlusion handling writes LocalTransparencyModifier
			-- too and set a hidden stand-in visible again when the camera moved; 2026-11-25, the Flame Cannon's
			-- level 3 showed its stand-in over the real model in the film's view shot)
			show(standIn, not done)
		end
	end
end)
