-- Phone check for the barricade looks (test/shots only). When the server sets the player attribute "CheckLook" to
-- "<shot name>|<model name>", wait until the wall's look has really loaded on this client (every painted mesh has
-- its texture, the mesh and texture are fetched, nothing left in the download queue), print what the client holds
-- next to the ids in Art, then print the "[SHOT]" line the screenshot script grabs at and tell the server.
-- "WhatBar" lists everything drawn in the top right of the screen (bars, billboards), to name what shows there.
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage.Shared.Art)
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local done = ReplicatedStorage:WaitForChild("ShotDone")

local function findLook()
	local towers = workspace:FindFirstChild("Towers")
	for _, m in towers and towers:GetChildren() or {} do
		if m:GetAttribute("TowerType") == "Barricade" and m:FindFirstChild("Look") then
			return m.Look
		end
	end
end

local function checkLook(value)
	local shotName, modelName = string.match(value, "^(.-)|(.+)$")
	local look, parts
	for _ = 1, 60 do
		look = findLook()
		parts = {}
		local ready = look ~= nil
		for _, p in look and look:GetDescendants() or {} do
			if p:IsA("MeshPart") then
				table.insert(parts, p)
				if p.Name == "Body" and p.TextureID == "" then
					ready = false
				end
			end
		end
		if ready and #parts > 0 then
			break
		end
		task.wait(0.5)
	end
	local ids = {}
	for _, p in parts do
		table.insert(ids, p.MeshId)
		if p.TextureID ~= "" then
			table.insert(ids, p.TextureID)
		end
	end
	local states = {}
	pcall(function()
		ContentProvider:PreloadAsync(ids, function(id, status)
			states[id] = status.Name
		end)
	end)
	for _ = 1, 40 do
		if ContentProvider.RequestQueueSize == 0 then
			break
		end
		task.wait(0.25)
	end
	local _, size = look and look:GetBoundingBox()
	print("[LOOKCHECK]", shotName, "model", modelName, "Art model", Art.Models[modelName], "Art paint",
		(Art.Textures or {})["paint_" .. modelName], "look size", size, "meshparts", #parts)
	for _, p in parts do
		print("[LOOKCHECK]", shotName, p.Name, "MeshId", p.MeshId, states[p.MeshId], "TextureID", p.TextureID,
			states[p.TextureID], "Color", p.Color, "Material", p.Material.Name, "Transparency", p.Transparency)
	end
	task.wait(1) -- (one more frame or so to draw it)
	print("[SHOT]", DateTime.now().UnixTimestampMillis, shotName)
	done:FireServer(shotName)
end

local function whatBar()
	local vp = camera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	local function topRight(x, y)
		return x > vp.X * 0.5 and y < vp.Y * 0.5
	end
	for _, gui in workspace:GetDescendants() do
		-- (a billboard parented to a part or model with no Adornee hangs on its parent)
		local on = gui:IsA("BillboardGui") and gui.Enabled and (gui.Adornee or gui.Parent)
		if on and on:IsA("Model") then
			on = on.PrimaryPart or on:FindFirstChildWhichIsA("BasePart", true)
		end
		if on and on:IsA("BasePart") then
			local world = on.CFrame:PointToWorldSpace(gui.StudsOffsetWorldSpace)
			local p, front = camera:WorldToViewportPoint(world)
			if front and topRight(p.X, p.Y) then
				print(string.format("[WHATBAR] billboard %s on %s at %.0f,%.0f size %s AlwaysOnTop %s MaxDistance %s",
					gui:GetFullName(), on:GetFullName(), p.X, p.Y, tostring(gui.Size), tostring(gui.AlwaysOnTop), tostring(gui.MaxDistance)))
			end
		end
	end
	for _, g in player.PlayerGui:GetDescendants() do
		if g:IsA("GuiObject") and g.AbsoluteSize.X > 20 then
			local node, shown = g, true
			while node and node:IsA("GuiObject") do
				shown = shown and node.Visible
				node = node.Parent
			end
			local screen = g:FindFirstAncestorOfClass("ScreenGui")
			local cx, cy = g.AbsolutePosition.X + g.AbsoluteSize.X / 2, g.AbsolutePosition.Y + inset.Y + g.AbsoluteSize.Y / 2
			if shown and screen and screen.Enabled and topRight(cx, cy) and g.BackgroundTransparency < 0.95 then
				print(string.format("[WHATBAR] %s size %.0fx%.0f at %.0f,%.0f colour %s", (g:GetFullName():gsub("^.-PlayerGui%.", "")),
					g.AbsoluteSize.X, g.AbsoluteSize.Y, cx, cy, tostring(g.BackgroundColor3)))
			end
		end
	end
	for _, gui in workspace:GetDescendants() do
		if gui:IsA("BillboardGui") and gui.Name == "WallHealth" then
			local a = gui.Adornee
			local world = a and a.CFrame:PointToWorldSpace(gui.StudsOffsetWorldSpace)
			local p = world and camera:WorldToViewportPoint(world)
			print("[WHATBAR] wall bar", gui:GetFullName(), "enabled", gui.Enabled, "adornee", a and a:GetFullName(),
				"adornee parent", a and a.Parent and a.Parent:GetFullName(), "adornee at", a and a.Position,
				"turn", a and math.deg(select(2, a.CFrame:ToEulerAnglesYXZ())), "offset", gui.StudsOffsetWorldSpace,
				"world", world, "screen", p, "model at", gui.Parent:IsA("Model") and gui.Parent:GetPivot().Position)
		end
	end
	print(string.format("[WHATBAR] viewport %.0fx%.0f", vp.X, vp.Y))
end

player:GetAttributeChangedSignal("CheckLook"):Connect(function()
	local v = player:GetAttribute("CheckLook")
	if v and v ~= "" then
		checkLook(v)
	end
end)
player:GetAttributeChangedSignal("WhatBar"):Connect(function()
	if player:GetAttribute("WhatBar") then
		whatBar()
	end
end)
-- "PickWall": press the gamepad's Y (pick the nearest defender), so the info panel opens the way a player opens it
player:GetAttributeChangedSignal("PickWall"):Connect(function()
	local Gamepad = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("Gamepad"))
	print("[LOOKCHECK] pick wall", Gamepad.Press(Enum.KeyCode.ButtonY))
end)
