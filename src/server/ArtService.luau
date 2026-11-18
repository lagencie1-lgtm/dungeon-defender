-- Turns the uploaded icon decals into image ids the screens can show.
-- (An upload makes a Decal; ImageLabels need the image inside it.)
-- Results go on ReplicatedStorage.ArtImages as attributes: name -> "rbxassetid://..."
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage.Shared.Art)

local ArtService = {}

function ArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "ArtImages"
	folder.Parent = ReplicatedStorage
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
