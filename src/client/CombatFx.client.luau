local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatLooks = require(script.Parent.CombatLooks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local mobile = UserInputService.TouchEnabled or (RunService:IsStudio() and ReplicatedStorage:FindFirstChild("MobileTest") ~= nil)
local effects = Instance.new("Folder")
effects.Name = "LocalCombatEffects"
effects.Parent = workspace

local tier = mobile and 1 or 0
CombatLooks.SetTier(tier)
local visualBudget = { 60, 36, 22 }
local visualRange = { 155, 115, 85 }
local tokens, lastUpdate = visualBudget[tier + 1], os.clock()
local damageTextAt = 0
local costs = { Arc = 3, Lightning = 2, Shards = 3 }

Remotes.CombatFx.OnClientEvent:Connect(function(name, origin, ...)
	local camera = workspace.CurrentCamera
	local render = CombatLooks[name]
	if not camera or not render then
		return
	end
	local position = typeof(origin) == "CFrame" and origin.Position or origin
	if (position - camera.CFrame.Position).Magnitude > visualRange[tier + 1] then
		return
	end
	local now = os.clock()
	if name == "Text" and tier > 0 and (select(3, ...) or 1) < 1 then
		if now < damageTextAt then
			return
		end
		damageTextAt = now + 0.08 * tier
	end
	local budget = visualBudget[tier + 1]
	tokens = math.min(budget, tokens + (now - lastUpdate) * budget)
	lastUpdate = now
	local cost = costs[name] or 1
	if tokens >= cost then
		tokens -= cost
		render(origin, ...)
	end
end)

if not mobile then
	return
end

local slowTime, recovery, frames = 0, 0, 0
local focused = true
UserInputService.WindowFocusReleased:Connect(function()
	focused = false
	slowTime, recovery, frames = 0, 0, 0
end)
UserInputService.WindowFocused:Connect(function()
	focused = true
end)

RunService.Heartbeat:Connect(function(dt)
	if not focused then
		return
	end
	slowTime += dt
	frames += 1
	if slowTime < 3 then
		return
	end
	local fps = frames / slowTime
	local nextTier = tier
	if fps < 14 then
		nextTier = 2
	elseif fps < 22 then
		nextTier = math.min(2, tier + 1)
	end
	if fps >= 32 then
		recovery += slowTime
		if recovery >= 12 then
			nextTier = math.max(0, tier - 1)
			recovery = 0
		end
	else
		recovery = 0
	end
	slowTime, frames = 0, 0
	if nextTier ~= tier then
		tier = nextTier
		CombatLooks.SetTier(tier)
	end
end)

-- Map ambience is set once on the server. Only the closest lights and emitters
-- matter to the player, and the budget can follow the client's frame rate.
local ambient = {}
local watched = {}

local function register(effect)
	if effect:IsA("Light") or effect:IsA("Fire") or (effect:IsA("ParticleEmitter") and effect.Rate > 0) then
		local part = effect:FindFirstAncestorWhichIsA("BasePart")
		if part then
			ambient[effect] = { part = part, enabled = effect.Enabled }
		end
	end
end

local function watch(world)
	if world.Name ~= "Outpost" and world.Name ~= "Map" then
		return
	end
	watched[world] = {
		world.DescendantAdded:Connect(register),
		world.DescendantRemoving:Connect(function(effect)
			ambient[effect] = nil
		end),
	}
	for _, descendant in world:GetDescendants() do
		register(descendant)
	end
end

workspace.ChildAdded:Connect(watch)
workspace.ChildRemoved:Connect(function(world)
	if watched[world] then
		for _, connection in watched[world] do
			connection:Disconnect()
		end
		watched[world] = nil
	end
end)
for _, world in workspace:GetChildren() do
	watch(world)
end

local lightCaps = { 6, 3, 1 }
while task.wait(0.4) do
	local camera = workspace.CurrentCamera
	if not camera then
		continue
	end
	local lights = {}
	for effect, spec in ambient do
		local distance = (spec.part.Position - camera.CFrame.Position).Magnitude
		if effect:IsA("Light") then
			if spec.enabled and distance < effect.Range * 3 then
				table.insert(lights, { effect = effect, distance = distance })
			else
				effect.Enabled = false
			end
		else
			effect.Enabled = spec.enabled and distance < (tier == 2 and 45 or 85)
		end
	end
	table.sort(lights, function(a, b)
		return a.distance < b.distance
	end)
	for index, light in lights do
		light.effect.Enabled = index <= lightCaps[tier + 1]
	end
end
