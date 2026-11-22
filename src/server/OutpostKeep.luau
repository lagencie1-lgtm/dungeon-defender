-- The Watch Keep: the new Outpost, built from HubLayout (shared/HubLayout.luau). A walled courtyard where the spawn
-- faces the portal gate (PLAY), map pads in front of it, painted stations with one big word on a ring around the
-- plaza, the five real defenders on pedestals, walls and trees as the skyline. Mobile and console first: every
-- station opens by walking into its ring (no small prompt to tap), and its ProximityPrompt shows the gamepad button.
-- Until a Blender piece is uploaded its slot shows a plain grey-box stand-in of the same size (6A: all or nothing).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local HubLayout = require(ReplicatedStorage.Shared.HubLayout)
local ArtService = require(script.Parent.ArtService)
local State = require(script.Parent.State)

local Keep = {}

local WOOD = Color3.fromRGB(110, 74, 44)
local STONE = Color3.fromRGB(150, 142, 128)
local CREAM = Color3.fromRGB(243, 230, 200)
local INK = Color3.fromRGB(46, 30, 18)

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- a painted Blender piece in its slot, or a plain stand-in of the same size until it has loaded
local function piece(ctx, parent, model, cframe, height, standIn)
	local stand
	if standIn then
		stand = ctx.part({ Name = model .. "_standin", Size = standIn, CFrame = cframe * CFrame.new(0, standIn.Y / 2, 0),
			Color = STONE, Material = Enum.Material.SmoothPlastic, CanCollide = true, Parent = parent })
	end
	task.spawn(function()
		if ArtService.WaitModel(model, 40) then
			local look = ctx.placeModel(parent, model, cframe, height)
			if look and stand then
				stand:Destroy()
			end
		end
	end)
end

-- a hanging word sign facing `toward`: painted icon on the left, one big word (SurfaceGui text: never emoji)
local function sign(ctx, parent, name, at, toward, word, icon, color, width, height, textSize)
	width, height, textSize = width or 14, height or 4, textSize or 128
	-- Roblox caps text at 100 px, so big letters need fewer pixels per stud: letters are textSize / 40 studs tall
	local letters = textSize / 40
	local pps = 90 / letters
	local k = pps / 40
	local board = ctx.part({ Name = name, Size = Vector3.new(width, height, 0.5), CFrame = CFrame.lookAt(at, flat(toward) + Vector3.new(0, at.Y, 0)),
		Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = false, CanQuery = false, Parent = parent })
	local trim = ctx.part({ Name = name .. "Trim", Size = Vector3.new(width + 0.6, height + 0.6, 0.3),
		CFrame = board.CFrame * CFrame.new(0, 0, 0.3), Color = Color3.fromRGB(196, 150, 70), Material = Enum.Material.Metal,
		CanCollide = false, CanQuery = false, Parent = parent })
	trim.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0.35
	gui.MaxDistance = 220
	gui.Parent = board
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, math.floor(12 * k))
	list.Parent = row
	if icon then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(math.floor(textSize * 1.1 * k), math.floor(textSize * 1.1 * k))
		image.Parent = row
		task.spawn(function()
			local id = ArtService.Image(icon, 30)
			if id then
				image.Image = id
			else
				image:Destroy()
			end
		end)
	end
	local text = Instance.new("TextLabel")
	text.Name = "Word"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, 110)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 90
	text.Text = word
	text.TextColor3 = CREAM
	text.Parent = row
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = math.max(2, math.floor(6 * k + 0.5))
	stroke.Parent = text
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = color
	accent.AnchorPoint = Vector2.new(0.5, 1)
	accent.Position = UDim2.new(0.5, 0, 1, -math.floor(8 * k))
	accent.Size = UDim2.new(0.6, 0, 0, math.max(3, math.floor(10 * k)))
	accent.Parent = gui
	return board, text
end

-- a flat disc lying on the ground (rings and pads)
local function disc(ctx, parent, name, at, radius, color, transparency)
	return ctx.part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color,
		Material = Enum.Material.SmoothPlastic, Transparency = transparency or 0.45, CanCollide = false, CanQuery = false,
		CastShadow = false, Parent = parent })
end

-- a crisp painted ring on the ground (a SurfaceGui circle with a thick edge): where you walk in to use a station
local function ring(ctx, parent, name, at, radius, color, fill)
	local holder = ctx.part({ Name = name, Size = Vector3.new(radius * 2, 0.1, radius * 2), CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)),
		Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.5
	gui.Parent = holder
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.new(1, -16, 1, -16)
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = fill or 0.8
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = 10
	edge.Transparency = 0.15
	edge.Parent = circle
	return holder
end

function Keep.Build(hub, c, ctx)
	local spawnAt = c + HubLayout.Spawn
	local portalAt = c + HubLayout.Portal
	local spawn = ctx.part({ ClassName = "SpawnLocation", Name = "OutpostSpawn", Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.lookAt(spawnAt + Vector3.new(0, 0.3, 0), portalAt + Vector3.new(0, 0.3, 0)),
		Transparency = 1, CanCollide = false, Enabled = true, Parent = hub })
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- the Beacon Tower: the landmark you see from everywhere, and the PLAY gate at its foot
	local scale = HubLayout.PortalHeight / 20
	local towerFacing = CFrame.lookAt(portalAt, portalAt + Vector3.new(0, 0, 1))
	piece(ctx, hub, "keep_beacon", towerFacing, HubLayout.BeaconHeight, Vector3.new(22, HubLayout.BeaconHeight, 14))
	piece(ctx, hub, "map_portal", towerFacing, HubLayout.PortalHeight, nil)
	local glow = ctx.part({ Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 14 * scale, 14 * scale),
		CFrame = CFrame.new(portalAt + Vector3.new(0, 10.4 * scale, 0)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(150, 100, 255), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false,
		CanQuery = false, Parent = hub })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 130, 255)
	light.Range = 22
	light.Brightness = 0.6 -- brighter tinted the pale stone pink
	light.Parent = glow
	-- inside the ring you see where you are going: the picked map's own painted sky, behind a thin violet veil
	glow.Transparency = 0.72
	local window = ctx.part({ Name = "PortalView", Size = Vector3.new(13 * scale, 13 * scale, 0.05),
		CFrame = CFrame.new(portalAt + Vector3.new(0, 10.4 * scale, -0.4)), Transparency = 1,
		CanCollide = false, CanTouch = false, CanQuery = false, Parent = hub })
	local view = Instance.new("SurfaceGui")
	view.Face = Enum.NormalId.Back
	view.CanvasSize = Vector2.new(384, 384)
	view.LightInfluence = 0
	view.Parent = window
	local vista = Instance.new("ImageLabel")
	vista.Name = "Vista"
	vista.BackgroundColor3 = Color3.fromRGB(70, 40, 120)
	vista.Size = UDim2.fromScale(1, 1)
	vista.ScaleType = Enum.ScaleType.Crop
	vista.ImageColor3 = Color3.fromRGB(225, 210, 255)
	vista.Parent = view
	local mask = Instance.new("UICorner")
	mask.CornerRadius = UDim.new(0.5, 0)
	mask.Parent = vista
	local SKY = { Forest = "sky_forest_side", Magma = "sky_magma_side", Crystal = "sky_crystal_side" }
	local shownMap = nil
	local function showMap()
		local mapId = State.Get("Map") or Config.MapOrder[1]
		if mapId == shownMap then
			return
		end
		shownMap = mapId
		local theme = Config.Maps[mapId] and Config.Maps[mapId].Theme
		task.spawn(function()
			local image = theme and ArtService.Image(SKY[theme], 30)
			if image and shownMap == mapId then
				vista.Image = image
			end
		end)
	end
	showMap()
	-- the one word you must read from the spawn, 76 studs away: letters about 6 studs tall
	sign(ctx, hub, "PlaySign", portalAt + Vector3.new(0, HubLayout.BeaconHeight * 0.4, HubLayout.BeaconHeight * 0.23), spawnAt, "PLAY", nil,
		Color3.fromRGB(170, 120, 255), 16, 5.5, 200)

	-- the map pads: walk on one with your party to start that map
	local pads = {}
	for _, info in HubLayout.Pads do
		local map = Config.Maps[info.Map]
		local at = c + info.At
		-- (the first map's pad keeps the old name StartPad: the tutorial arrow and the tests look for it)
		local pad = disc(ctx, hub, info.Map == Config.MapOrder[1] and "StartPad" or "Pad_" .. info.Map, at,
			HubLayout.PadRadius, map.Color, 0.25)
		pad.Material = Enum.Material.Slate
		ring(ctx, hub, "PadRing_" .. info.Map, at + Vector3.new(0, 0.12, 0), HubLayout.PadRadius + 0.6, CREAM, 1)
		-- a low sign behind the pad: the map's name, below the portal so it never hides it
		-- an upright sign on two posts behind the pad: the map's painted sky as its picture, and its name
		local skyName = ({ Forest = "sky_forest_side", Magma = "sky_magma_side", Crystal = "sky_crystal_side" })[map.Theme]
		local board = sign(ctx, hub, "PadSign_" .. info.Map, at + Vector3.new(0, 4.4, -HubLayout.PadRadius - 1.2), spawnAt,
			map.Name, skyName, map.Color, 12.5, 3.4, 72)
		for _, side in { -1, 1 } do
			ctx.part({ Name = "PadPost", Size = Vector3.new(0.5, 4.4, 0.5), CFrame = board.CFrame * CFrame.new(side * 5.6, -2.6, 0.35),
				Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = hub })
		end
		local count = Instance.new("TextLabel")
		count.Name = "Party"
		count.BackgroundTransparency = 1
		count.AnchorPoint = Vector2.new(0.5, 0)
		count.Position = UDim2.new(0.5, 0, 1, 6)
		count.Size = UDim2.fromOffset(300, 60)
		count.Font = Enum.Font.FredokaOne
		count.TextSize = 56
		count.TextColor3 = CREAM
		count.Text = ""
		local holder = ctx.part({ Name = "PadCount_" .. info.Map, Size = Vector3.new(12, 2, 0.2), CFrame = board.CFrame * CFrame.new(0, 2.6, 0),
			Transparency = 1, CanCollide = false, CanQuery = false, Parent = hub })
		local gui = Instance.new("SurfaceGui")
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = holder
		count.Position = UDim2.fromScale(0.5, 0)
		count.Size = UDim2.fromScale(1, 1)
		count.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 4
		stroke.Parent = count
		ctx.prompt(pad, "Start", map.Name, "Map:" .. info.Map, 0)
		table.insert(pads, { map = info.Map, at = at, pad = pad, count = count })
	end

	-- the stations on the ring
	local rings = {}
	for _, s in HubLayout.Stations do
		local at = c + s.At
		local inward = (flat(c) - flat(at)).Unit
		local facing = CFrame.lookAt(at, at + inward)
		piece(ctx, hub, s.Model, facing, s.Height, Vector3.new(8, s.Height, 6))
		sign(ctx, hub, s.Id .. "Sign", at + Vector3.new(0, s.Height + 4, 0) + inward * 2, at + inward * 20, s.Word, s.Icon, s.Color)
		local ringAt = at + inward * HubLayout.RingOffset
		-- one soft cream ring for every station (the sign above carries its colour): calmer than six colours on the grass
		local walkIn = ring(ctx, hub, s.Id .. "Ring", ringAt, HubLayout.RingRadius, CREAM, 0.88)
		ctx.prompt(walkIn, s.Word:sub(1, 1) .. s.Word:sub(2):lower(), "", s.Action, 0)
		-- the painted stone rune ring set in the paving replaces the flat circle once it has loaded;
		-- its runes take the station's colour (KeepLife makes them glow softly while you stand near)
		task.spawn(function()
			if not ArtService.WaitModel("keep_ring", 40) then
				return
			end
			local look = ctx.placeModel(hub, "keep_ring", CFrame.new(ringAt), 0.3)
			if not look then
				return
			end
			look.Name = s.Id .. "RuneRing"
			look:SetAttribute("Station", s.Id)
			for _, p in look:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					if p.Name:match("^c_") then
						p.Name = "Runes"
						p.Color = s.Color
						p.Material = Enum.Material.Neon
						p.Transparency = 0.35
					end
				end
			end
			local gui = walkIn:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = false
			end
		end)
		table.insert(rings, { at = ringAt, action = s.Action, id = s.Id })
	end

	-- dressing and banners (HubLayout.Dressing / Banners): every piece has a reason, see the list
	for _, d in HubLayout.Dressing do
		local at = c + d.At
		piece(ctx, hub, d.Model, CFrame.new(at) * CFrame.Angles(0, math.rad(d.Turn or 0), 0), d.Height, nil)
	end
	for _, b in HubLayout.Banners do
		local at = c + b.At
		-- hung 2.5 up the palisade, facing into the courtyard
		local up = at + Vector3.new(0, 2.5, 0)
		piece(ctx, hub, "keep_banner", CFrame.lookAt(up, Vector3.new(c.X, up.Y, c.Z)), 7.3, nil)
	end

	-- the five real defenders on pedestals
	for _, show in HubLayout.Showcase do
		local at = c + show.At
		local facing = CFrame.lookAt(at, at + (flat(spawnAt) - flat(at)).Unit)
		piece(ctx, hub, "keep_pedestal", facing, 1.55, Vector3.new(7, 1.55, 7))
		local name = ({ Ranger = "tower_ranger", FlameCannon = "tower_flame", FrostCrystal = "tower_frost",
			StormObelisk = "tower_storm", Ballista = "tower_ballista" })[show.Tower]
		local heights = { Ranger = 11, FlameCannon = 5.5, FrostCrystal = 7.5, StormObelisk = 10, Ballista = 5.9 }
		piece(ctx, hub, name, facing + Vector3.new(0, 1.6, 0), heights[show.Tower], nil)
		sign(ctx, hub, "ShowcaseTag_" .. show.Tower, at + Vector3.new(0, 1, 0) + facing.LookVector * 4,
			at + facing.LookVector * 20, Config.Towers[show.Tower].DisplayName, nil, Config.Towers[show.Tower].Color, 9, 1.6, 50)
	end

	-- the trophy board (MapBuilder.UpdateTrophies writes onto TrophyWall.Board.Text)
	local trophyAt = c + HubLayout.Trophies
	local wall = ctx.part({ Name = "TrophyWall", Size = Vector3.new(14, 10, 0.6),
		CFrame = CFrame.lookAt(trophyAt + Vector3.new(0, 6, 0), flat(c) + Vector3.new(0, 6, 0)), Color = WOOD,
		Material = Enum.Material.WoodPlanks, Parent = hub })
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.Parent = wall
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 225, 150)
	text.Text = "TROPHIES"
	text.Parent = surface

	-- walls and corner towers all round, trees and hills behind them: the skyline (no empty horizon)
	local half = HubLayout.Size / 2
	local function wallRun(from, to)
		local length = (to - from).Magnitude
		local steps = math.max(1, math.floor(length / 12 + 0.5))
		local along = (to - from).Unit
		local inward = Vector3.new(-along.Z, 0, along.X)
		if inward:Dot(-(from + to) / 2) < 0 then
			inward = -inward
		end
		for i = 0, steps - 1 do
			local a = from:Lerp(to, (i + 0.5) / steps)
			piece(ctx, hub, "keep_palisade", CFrame.lookAt(c + a, c + a + inward), 10, Vector3.new(length / steps, 10, 1.4))
		end
	end
	local corners = { Vector3.new(-half.X, 0, -half.Y), Vector3.new(half.X, 0, -half.Y), Vector3.new(half.X, 0, half.Y),
		Vector3.new(-half.X, 0, half.Y) }
	for i, a in corners do
		local b = corners[i % 4 + 1]
		local dir = (b - a).Unit
		wallRun(a + dir * 5, b - dir * 5)
		piece(ctx, hub, "keep_watchtower", CFrame.lookAt(c + a, c), 24, Vector3.new(9, 24, 9))
	end
	task.spawn(function()
		ArtService.WaitModel("tree_oak", 30)
		local rng = Random.new(41)
		-- a close ring of tall trees just behind the palisade (their crowns are the skyline), then the woods further out
		for i = 1, 64 do
			local a = (i <= 28) and (i / 28 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)) or rng:NextNumber(0, math.pi * 2)
			local d = (i <= 28) and rng:NextNumber(66, 76) or rng:NextNumber(80, 125)
			local pos = c + Vector3.new(math.cos(a) * d * 1.05, 0, math.sin(a) * d * 0.9)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { workspace.Terrain }
			local hit = workspace:Raycast(pos + Vector3.new(0, 150, 0), Vector3.new(0, -300, 0), params)
			pos = hit and hit.Position - Vector3.new(0, 0.5, 0) or pos
			ctx.placeModel(hub, "tree_oak", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				i <= 28 and rng:NextNumber(30, 42) or rng:NextNumber(20, 32))
			if i % 8 == 0 then
				task.wait()
			end
		end
	end)

	-- walk-in stations and party pads (checked 5 times a second on the server)
	local inside = {}
	local padTimer = { map = nil, startAt = 0 }
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not hub.Parent then
			connection:Disconnect()
			return
		end
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		showMap()
		local lobby = State.Get("State") == "Lobby" and not State.Get("LoadingRun")
		local onPad = {}
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local here = root and (root.Position - c).Magnitude < 150
			inside[player] = inside[player] or {}
			for _, r in rings do
				local within = here and (flat(root.Position) - flat(r.at)).Magnitude < HubLayout.RingRadius
				if within and not inside[player][r.id] and lobby then
					ctx.onPrompt(player, r.action)
				end
				inside[player][r.id] = within
			end
			for _, p in pads do
				if here and (flat(root.Position) - flat(p.at)).Magnitude < HubLayout.PadRadius then
					onPad[p.map] = (onPad[p.map] or 0) + 1
				end
			end
		end
		local total = #Players:GetPlayers()
		local chosen
		for _, p in pads do
			local n = onPad[p.map] or 0
			if n > 0 and not chosen then
				chosen = p
			end
			p.count.Text = n > 0 and (n .. "/" .. total .. " ready") or ""
		end
		if not lobby or not chosen then
			padTimer.map = nil
			return
		end
		if padTimer.map ~= chosen.map then
			padTimer.map = chosen.map
			padTimer.startAt = os.clock()
			ctx.onPrompt(nil, "Map:" .. chosen.map)
		end
		local left = HubLayout.PadCountdown - (os.clock() - padTimer.startAt)
		chosen.count.Text = (onPad[chosen.map] or 0) .. "/" .. total .. "  starting in " .. math.max(1, math.ceil(left))
		if left <= 0 then
			padTimer.map = nil
			ctx.onPrompt(nil, "Start")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)
	return hub
end

return Keep
