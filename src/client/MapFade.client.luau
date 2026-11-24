-- Tall things on the battlefield (gate arches, ruined walls, pillars, trees) turn see-through while they stand
-- between the camera and your hero, so an obstacle never hides the fight on a phone (6A world guide: "fade tree
-- trunks on the line from the camera to the player"). Only the picture fades, for this player only; what is solid
-- stays solid. MapBuilder marks the models with the attribute "Tall".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FADED = 0.78 -- how see-through a blocking piece gets
local RATE = 14 -- eased with 1 - exp(-RATE * dt): about a fifth of a second

local tracked = {} -- model -> { parts, box cframe, half size, amount }
local lastScan = 0

local function scan()
	local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	for model in tracked do
		if not model.Parent then
			tracked[model] = nil
		end
	end
	if not decor then
		return
	end
	for _, model in decor:GetChildren() do
		if model:GetAttribute("Tall") and not tracked[model] and model:IsA("Model") then
			local parts = {}
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 0.95 then
					table.insert(parts, p)
				end
			end
			local cframe, size = model:GetBoundingBox()
			tracked[model] = { parts = parts, cframe = cframe, half = size / 2 + Vector3.new(0.5, 0.5, 0.5), amount = 0 }
		end
	end
end

-- does the segment a -> b pass through the box? (slab test in the box's own space)
local function crosses(entry, a, b)
	local from = entry.cframe:PointToObjectSpace(a)
	local dir = entry.cframe:PointToObjectSpace(b) - from
	local near, far = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local o, d, h = from[axis], dir[axis], entry.half[axis]
		if math.abs(d) < 1e-4 then
			if math.abs(o) > h then
				return false
			end
		else
			local t1, t2 = (-h - o) / d, (h - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			near, far = math.max(near, t1), math.min(far, t2)
			if near > far then
				return false
			end
		end
	end
	return true
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if now - lastScan > 1 then
		lastScan = now
		scan()
	end
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return
	end
	local eye = camera.CFrame.Position
	-- aim at the hero's chest and stop a little short, so a piece the hero leans on does not count
	local target = root.Position + (eye - root.Position).Unit * 1.5
	local ease = 1 - math.exp(-RATE * dt)
	for _, entry in tracked do
		local want = crosses(entry, eye, target) and FADED or 0
		if math.abs(entry.amount - want) > 0.005 then
			entry.amount += (want - entry.amount) * ease
			for _, p in entry.parts do
				p.LocalTransparencyModifier = entry.amount
			end
		end
	end
end)
