-- A loaded image is not a drawn image (6A engine facts): a painted mesh whose texture the client has not fetched
-- yet can stay blank for good. The Ranger's level 2 showed plain white this way in the phone film while the server
-- had its paint. So: every painted mesh that appears in the towers, the map or the hub gets its texture fetched
-- first, then the texture is set again so it is drawn.
local ContentProvider = game:GetService("ContentProvider")

local done = setmetatable({}, { __mode = "k" })

local function warm(part)
	if done[part] or not part:IsA("MeshPart") or part.TextureID == "" then
		return
	end
	done[part] = true
	task.spawn(function()
		local id = part.TextureID
		pcall(function()
			ContentProvider:PreloadAsync({ id })
		end)
		if part.Parent and part.TextureID == id then
			part.TextureID = ""
			part.TextureID = id
		end
	end)
end

local function watch(folder)
	for _, d in folder:GetDescendants() do
		warm(d)
	end
	folder.DescendantAdded:Connect(warm)
end

for _, name in { "Towers", "Map", "Outpost" } do
	task.spawn(function()
		local folder = workspace:WaitForChild(name, 60)
		if folder then
			watch(folder)
		end
	end)
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" or child.Name == "Outpost" then
		watch(child)
	end
end)
