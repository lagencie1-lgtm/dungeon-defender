local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local images = ReplicatedStorage:WaitForChild("ArtImages")
local theme, sky, loading
local revision = 0

local function update()
	local nextTheme = Lighting:GetAttribute("Theme")
	if nextTheme ~= theme then
		theme = nextTheme
		revision += 1
		loading = false
		if sky then
			sky:Destroy()
			sky = nil
		end
	end
	if not theme or sky or loading then
		return
	end
	local prefix = "sky_" .. string.lower(theme) .. "_"
	local side, up, down = images:GetAttribute(prefix .. "side"), images:GetAttribute(prefix .. "up"), images:GetAttribute(prefix .. "down")
	if not side or not up or not down then
		return
	end
	loading = true
	local requested = revision
	task.spawn(function()
		local ready = true
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ side, up, down }, function(_, status)
				ready = ready and status == Enum.AssetFetchStatus.Success
			end)
		end)
		if not ok or not ready or requested ~= revision then
			return
		end
		sky = Instance.new("Sky")
		sky.Name = "MapSky"
		sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt = side, side, side, side
		sky.SkyboxUp, sky.SkyboxDn = up, down
		sky.CelestialBodiesShown = false
		sky.StarCount = 0
		sky.Parent = Lighting
	end)
end

Lighting:GetAttributeChangedSignal("Theme"):Connect(update)
images.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 4) == "sky_" then
		update()
	end
end)
update()
