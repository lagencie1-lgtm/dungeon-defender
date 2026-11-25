-- Phone check for the wall's health bar (test/shots only): when the server sets the player attribute "CheckBar", find
-- every WallHealth bar on screen, project it with the camera and compare its rectangle with every visible HUD panel.
-- Rule: a wall within 60 studs of the hero has its bar on screen and not covered by any HUD panel.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function rectOf(g)
	return g.AbsolutePosition.X, g.AbsolutePosition.Y, g.AbsolutePosition.X + g.AbsoluteSize.X, g.AbsolutePosition.Y + g.AbsoluteSize.Y
end

local function visible(g)
	local node = g
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	local screen = g:FindFirstAncestorOfClass("ScreenGui")
	return screen ~= nil and screen.Enabled
end

local function check()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inset = game:GetService("GuiService"):GetGuiInset()
	for _, gui in workspace:GetDescendants() do
		if gui:IsA("BillboardGui") and gui.Name == "WallHealth" and gui.Adornee then
			local world = gui.Adornee.Position + gui.StudsOffsetWorldSpace
			local dist = root and (root.Position - world).Magnitude or -1
			local p, onScreen = camera:WorldToViewportPoint(world)
			local vp = camera.ViewportSize
			-- the bar's rectangle in GUI space (ScreenGuis without IgnoreGuiInset start below the top bar)
			local bw, bh = gui.Size.X.Offset, gui.Size.Y.Offset
			local x0, y0 = p.X - bw / 2, p.Y - inset.Y - bh / 2
			local x1, y1 = x0 + bw, y0 + bh
			local inside = onScreen and p.X > 0 and p.X < vp.X and p.Y > 0 and p.Y < vp.Y
			local covers = {}
			for _, g in player.PlayerGui:GetDescendants() do
				if g:IsA("GuiObject") and visible(g) and g.BackgroundTransparency < 0.95 and g.AbsoluteSize.X > 30 and g.AbsoluteSize.Y > 20 then
					local a0, b0, a1, b1 = rectOf(g)
					if a0 < x1 and a1 > x0 and b0 < y1 and b1 > y0 then
						table.insert(covers, g:GetFullName():gsub("^.-PlayerGui%.", ""))
					end
				end
			end
			print(string.format("[BARCHECK] camera %.1f studs away, MaxDistance %d, LightInfluence %.2f, AlwaysOnTop %s",
				(camera.CFrame.Position - world).Magnitude, gui.MaxDistance, gui.LightInfluence, tostring(gui.AlwaysOnTop)))
			print("[BARCHECK] adornee", gui.Adornee:GetFullName(), "transparency", gui.Adornee.Transparency, "size", gui.Size,
				"back", gui:FindFirstChild("Back") and gui.Back.AbsoluteSize, "fill", gui:FindFirstChild("Back") and gui.Back.Fill.Size,
				"gui parent", gui.Parent and gui.Parent:GetFullName(), "AbsoluteSize", gui.AbsoluteSize, "offset", gui.StudsOffsetWorldSpace)
			print(string.format("[BARCHECK] dist %.1f onscreen %s at %.0f,%.0f of %.0fx%.0f enabled %s covered by %d: %s", dist,
				tostring(inside), p.X, p.Y, vp.X, vp.Y, tostring(gui.Enabled), #covers, table.concat(covers, ", "):sub(1, 300)))
			local pass = dist <= 60 and inside and #covers == 0
			print("[BARCHECK]", (dist > 60 and "SKIP (further than 60 studs)") or (pass and "PASS" or "FAIL"))
		end
	end
end

player:GetAttributeChangedSignal("CheckBar"):Connect(function()
	if player:GetAttribute("CheckBar") then
		check()
	end
end)
