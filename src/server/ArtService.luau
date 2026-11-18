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
						if r then
							part.Color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
							-- very bright, strong colours glow (cannon fire, magic)
							local _, sat, val = part.Color:ToHSV()
							if val >= 0.95 and sat >= 0.6 then
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
		end
	end
	end)
	task.spawn(function()
		for name, decalId in Art.Icons do
			if decalId ~= "" then
				local ok, model = pcall(function()
					return InsertService:LoadAsset(tonumber(decalId))
				end)
				local decal = ok and model and model:FindFirstChildWhichIsA("Decal", true)
				if decal and decal.Texture ~= "" then
					folder:SetAttribute(name, decal.Texture)
				else
					warn("Art: could not load icon " .. name)
				end
				if ok and model then
					model:Destroy()
				end
			end
		end
	end)
end

return ArtService
