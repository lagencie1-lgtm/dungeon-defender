-- Turns the uploaded icon decals into image ids the screens can show.
-- (An upload makes a Decal; ImageLabels need the image inside it.)
-- Results go on ReplicatedStorage.ArtImages as attributes: name -> "rbxassetid://..."
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage.Shared.Art)

local ServerStorage = game:GetService("ServerStorage")

local ArtService = {}

-- the loaded Blender models, ready to clone: ServerStorage.ArtModels.<name> (a Model of MeshParts,
-- one per colour; each part is named c_R_G_B by the Blender pipeline and coloured from that name)
function ArtService.Model(name)
	local folder = ServerStorage:FindFirstChild("ArtModels")
	return folder and folder:FindFirstChild(name) or nil
end

-- waits (up to `timeout` seconds) for a model to finish loading; nil if it doesn't
function ArtService.WaitModel(name, timeout)
	local deadline = os.clock() + (timeout or 8)
	local model = ArtService.Model(name)
	while not model and os.clock() < deadline and (Art.Models[name] or "") ~= "" do
		task.wait(0.2)
		model = ArtService.Model(name)
	end
	return model
end

-- the image of an icon or texture ("rbxassetid://..."), waiting up to `timeout` seconds while it loads
function ArtService.Image(name, timeout)
	local folder = ReplicatedStorage:WaitForChild("ArtImages")
	local deadline = os.clock() + (timeout or 0)
	local image = folder:GetAttribute(name)
	local known = (Art.Icons[name] or (Art.Textures or {})[name] or "") ~= ""
	while not image and known and os.clock() < deadline do
		task.wait(0.2)
		image = folder:GetAttribute(name)
	end
	return image
end

-- turns an uploaded Decal into its image id ("rbxassetid://..."), or nil
local function decalImage(decalId)
	local ok, model = pcall(function()
		return InsertService:LoadAsset(tonumber(decalId))
	end)
	local decal = ok and model and model:FindFirstChildWhichIsA("Decal", true)
	local texture = decal and decal.Texture ~= "" and decal.Texture or nil
	if ok and model then
		model:Destroy()
	end
	return texture
end

function ArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "ArtImages"
	folder.Parent = ReplicatedStorage
	local models = Instance.new("Folder")
	models.Name = "ArtModels"
	models.Parent = ServerStorage
	-- 3D models load in the background so the game starts right away
	-- (a defender built before its model arrives keeps the simple look)
	task.spawn(function()
	for name, id in Art.Models or {} do
		if id ~= "" then
			task.spawn(function() -- all models at once, so none waits behind the others
			local ok, asset = pcall(function()
				return InsertService:LoadAsset(tonumber(id))
			end)
			local holder = Instance.new("Model")
			holder.Name = name
			if ok and asset then
				for _, part in asset:GetDescendants() do
					if part:IsA("MeshPart") then
						local r, g, b = part.Name:match("^c_(%d+)_(%d+)_(%d+)")
						part.Material = Enum.Material.SmoothPlastic
						-- painted parts: "Body" wears paint_<model> (or paint_<model>_body), any other painted part its own
						-- texture paint_<model>_<part> (tower kit "Skin_roof" -> _roof; picture bodies "ArmL" -> _arml)
						local own = (Art.Textures or {})["paint_" .. name .. "_" .. part.Name:lower():gsub("^skin_", "")]
						if part.Name == "Body" or (own and own ~= "") then
							part.Color = Color3.new(1, 1, 1)
							local paintId = own or (Art.Textures or {})["paint_" .. name] or ""
							local image = paintId ~= "" and decalImage(paintId)
						-- a fresh upload can still be processing: try again a few times rather than stay grey
						for _ = 1, 4 do
							if image or paintId == "" then
								break
							end
							task.wait(6)
							image = decalImage(paintId)
						end
							if image then
								part.TextureID = image
							end
						end
						if r then
							part.Color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
							-- very bright, strong colours glow (cannon fire, magic)
							local _, sat, val = part.Color:ToHSV()
							if val >= 0.95 and sat >= 0.6 and part.Name ~= "c_0_255_0" then -- (pure green = skin marker, not a glow)
								part.Material = Enum.Material.Neon
							end
						end
						part.Anchored = true
						part.Parent = holder
					end
				end
				asset:Destroy()
			end
			if #holder:GetChildren() > 0 then
				holder.Parent = models
				print("Art: model " .. name .. " loaded, " .. #holder:GetChildren() .. " parts")
			else
				warn("Art: could not load model " .. name .. " " .. tostring(asset))
			end
			end)
		end
	end
	end)
	task.spawn(function()
		-- all at once (one by one took over half a minute); world textures first
		for _, list in { Art.Textures or {}, Art.Icons } do
			for name, decalId in list do
				if decalId ~= "" then
					task.spawn(function()
						local image = decalImage(decalId)
						if image then
							folder:SetAttribute(name, image)
							if list ~= Art.Icons then
								print("Art: image " .. name .. " " .. image)
							end
						else
							warn("Art: could not load image " .. name)
						end
					end)
				end
			end
		end
	end)
end

return ArtService
