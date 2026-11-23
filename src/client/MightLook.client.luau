-- How grand a hero looks, from the Might of its gear (Config.MightRanks): a soft glow, a few slow rising sparks,
-- a thin ring of light at the feet and one over the head, in the rank's colour. The size step comes from the server
-- (MightService.luau). Drawn on this device for every hero.
-- A Might style from the shop (Store.Skins, Target "Aura") changes the colours and the bead shape, never what shows.
-- 6A: small and quiet; beads turn slowly on a fixed speed, nothing flashes; far heroes are not updated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Store = require(ReplicatedStorage.Shared.Store)

local FAR = 160
local FEET_BEADS, HALO_BEADS = 16, 10

local folder = Instance.new("Folder")
folder.Name = "MightLooks"
folder.Parent = workspace

local looks = {} -- [player] = { rank, parts... }

local function colorOf(rankIndex)
	local r = Config.MightRanks[rankIndex]
	return (r and r.Color) or Items.Rarities[math.clamp(rankIndex, 1, #Items.Rarities)].Color
end

local function clear(player)
	local look = looks[player]
	if not look then
		return
	end
	for _, thing in look.things do
		thing:Destroy()
	end
	looks[player] = nil
end

local function bead(color, size, shape)
	local p = Instance.new("Part")
	p.Shape = shape == "Block" and Enum.PartType.Block or Enum.PartType.Ball
	p.Size = Vector3.one * size * (shape == "Block" and 0.85 or 1)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function build(player)
	clear(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rankIndex = player:GetAttribute("MightRank") or 1
	local rank = Config.MightRanks[rankIndex]
	if not root or not rank or rankIndex <= 1 then
		return
	end
	local style = Store.Skins[player:GetAttribute("EquippedAura") or ""]
	if style and style.Target ~= "Aura" then
		style = nil
	end
	local color = style and style.Primary or colorOf(rankIndex)
	local accent = style and (style.Accent or style.Primary) or color
	local shape = style and style.Bead or "Ball"
	local look = { rank = rankIndex, things = {}, feet = {}, halo = {}, character = character, root = root,
		tumble = shape == "Block" }
	if rank.Glow then
		local light = Instance.new("PointLight")
		light.Name = "MightGlow"
		light.Color = color
		light.Range = 6 + rankIndex
		light.Brightness = 0.45
		light.Shadows = false
		light.Parent = root
		table.insert(look.things, light)
	end
	if rank.Motes then
		local holder = character:FindFirstChild("UpperTorso") or root
		local e = Instance.new("ParticleEmitter")
		e.Name = "MightMotes"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(accent)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Rate = 1 + rankIndex * 0.6
		e.Speed = NumberRange.new(0.6, 1.4)
		e.SpreadAngle = Vector2.new(25, 25)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, 0.8, 0)
		e.Parent = holder
		table.insert(look.things, e)
	end
	if rank.Ring then
		for _ = 1, FEET_BEADS do
			local p = bead(color, 0.22, shape)
			table.insert(look.feet, p)
			table.insert(look.things, p)
		end
	end
	if rank.Halo then
		for _ = 1, HALO_BEADS do
			local p = bead(accent, 0.16, shape)
			table.insert(look.halo, p)
			table.insert(look.things, p)
		end
	end
	looks[player] = look
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		build(player)
	end)
	for _, attribute in { "MightRank", "EquippedAura" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			build(player)
		end)
	end
	if player.Character then
		task.spawn(build, player)
	end
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)
for _, player in Players:GetPlayers() do
	watch(player)
end

local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local camera = workspace.CurrentCamera
	for player, look in looks do
		local root = look.root
		if not root.Parent then
			continue
		end
		local hidden = camera and (camera.CFrame.Position - root.Position).Magnitude > FAR
		local humanoid = look.character:FindFirstChildOfClass("Humanoid")
		local hip = humanoid and humanoid.HipHeight or 2
		local feet = root.Position - Vector3.new(0, hip + root.Size.Y / 2 - 0.1, 0)
		local head = look.character:FindFirstChild("Head")
		local top = head and (head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.55, 0)) or (root.Position + Vector3.new(0, 3, 0))
		for i, p in look.feet do
			if hidden then
				p.Position = Vector3.new(0, -500, 0)
			else
				local a = clock * 0.6 + i / #look.feet * math.pi * 2
				local at = feet + Vector3.new(math.cos(a) * 2.1, 0, math.sin(a) * 2.1)
				p.CFrame = look.tumble and CFrame.new(at) * CFrame.Angles(a, a * 1.3, 0) or CFrame.new(at)
			end
		end
		for i, p in look.halo do
			if hidden then
				p.Position = Vector3.new(0, -500, 0)
			else
				local a = -clock * 0.8 + i / #look.halo * math.pi * 2
				local at = top + Vector3.new(math.cos(a) * 0.75, math.sin(clock * 1.3) * 0.04, math.sin(a) * 0.75)
				p.CFrame = look.tumble and CFrame.new(at) * CFrame.Angles(a, a * 1.3, 0) or CFrame.new(at)
			end
		end
	end
end)
