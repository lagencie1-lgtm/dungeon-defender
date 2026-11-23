-- Gems that goblins drop. Walk your hero close to pick them up!
-- Gems nobody picks up fly to everyone after a while, so nobody loses out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local DataService = require(script.Parent.DataService)

local LootService = {}

local gems = {} -- [part] = { amount, dropped, base }
local GEM_COLOR = Color3.fromRGB(90, 220, 255)
local AUTO_COLLECT_AFTER = 45 -- long enough for a pet to fetch them first

function LootService.DropGems(position, amount)
	if amount <= 0 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Gem"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = Vector3.one * (amount >= 10 and 2.2 or 1.3)
	p.Material = Enum.Material.Neon
	p.Color = GEM_COLOR
	local base = Vector3.new(position.X + math.random() * 4 - 2, 1.8, position.Z + math.random() * 4 - 2)
	p.CFrame = CFrame.new(base)
	local light = Instance.new("PointLight")
	light.Color = GEM_COLOR
	light.Range = 8
	light.Parent = p
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(60, 20)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.MaxDistance = 80
	label.Parent = p
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = GEM_COLOR
	text.TextStrokeTransparency = 0.3
	text.Text = amount .. " gem" .. (amount == 1 and "" or "s")
	text.Parent = label
	p.Parent = workspace:FindFirstChild("Effects") or workspace
	gems[p] = { amount = amount, dropped = os.clock(), base = base }
end

local function give(player, amount, from)
	DataService.AddGems(player, amount)
	Sound.Play("Coin", from)
end

local function collect(part, player)
	local g = gems[part]
	gems[part] = nil
	if not g then
		return
	end
	if player then
		give(player, g.amount, part.Position)
	else
		for _, p in Players:GetPlayers() do
			give(p, g.amount, part.Position)
		end
	end
	-- fly up and vanish
	TweenService:Create(part, TweenInfo.new(0.25), { Size = Vector3.one * 0.1, Position = part.Position + Vector3.new(0, 4, 0) }):Play()
	task.delay(0.25, function()
		part:Destroy()
	end)
end

-- for pets fetching loot (PetMoves): the gems lying near a spot, and taking one
function LootService.GemsNear(position, radius)
	local found = {}
	for part, g in gems do
		if Vector3.new(g.base.X - position.X, 0, g.base.Z - position.Z).Magnitude <= radius then
			table.insert(found, { gem = part, position = g.base })
		end
	end
	return found
end

function LootService.TakeGem(part, player)
	if not gems[part] then
		return false
	end
	collect(part, player)
	return true
end

function LootService.Clear()
	for part in gems do
		part:Destroy()
	end
	table.clear(gems)
end

function LootService.Start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for part, g in gems do
			-- spin and bob
			part.CFrame = CFrame.new(g.base + Vector3.new(0, math.sin(now * 3) * 0.4, 0)) * CFrame.Angles(0, now * 2, math.rad(45))
			local taken = false
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - part.Position).Magnitude <= Config.Hero.GemPickupRange then
					collect(part, player)
					taken = true
					break
				end
			end
			local autoCollect = false
			for _, player in Players:GetPlayers() do
				autoCollect = autoCollect or player:GetAttribute("PassAutoCollect") == true
			end
			if not taken and (now - g.dropped > AUTO_COLLECT_AFTER or (autoCollect and now - g.dropped > 1)) then
				collect(part, nil)
			end
		end
	end)
end

return LootService
