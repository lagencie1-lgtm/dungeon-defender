-- The wall reacts to the pile smashing it (Lemp 2026-11-26, option C2): each blow MonsterAnim lands on a wall
-- (the PileBlow event) makes it shudder at the base with the top boards flexing back further, sometimes knocks a few
-- small wood chips off, and flashes its health bar. All numbers: MonsterMoves.WallHit. Client only: the parts are
-- moved for 0.12 s and put back exactly; a wall that is broken or being rebuilt (the server moves it then) is left alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Moves = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterMoves"))
local W = Moves.WallHit

local blow = ReplicatedStorage:FindFirstChild("PileBlow") or Instance.new("BindableEvent")
blow.Name = "PileBlow"
blow.Parent = ReplicatedStorage

local shaking = {}

-- the barricade the monster is hitting: the nearest standing one
local function wallNear(pos)
	local towers = workspace:FindFirstChild("Towers")
	local best, bestD = nil, 24
	for _, m in towers and towers:GetChildren() or {} do
		if m:IsA("Model") and m:GetAttribute("TowerType") == "Barricade" and not m:GetAttribute("Broken")
			and not m:GetAttribute("Rebuilding") then
			local d = (m:GetPivot().Position - pos).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function shudder(wall, from)
	local look = wall:FindFirstChild("Look")
	if not look or shaking[wall] then
		return
	end
	shaking[wall] = true
	local parts = {}
	for _, d in look:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d] = d.CFrame
		end
	end
	local cf, size = look:GetBoundingBox()
	local push = (cf.Position - from) * Vector3.new(1, 0, 1)
	push = push.Magnitude > 0.01 and push.Unit or Vector3.zero
	local bottom = cf.Position.Y - size.Y / 2
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= W.Time or not wall.Parent or wall:GetAttribute("Broken") or wall:GetAttribute("Rebuilding") then
			conn:Disconnect()
			if not wall:GetAttribute("Rebuilding") then
				for part, c in parts do
					if part.Parent then
						part.CFrame = c
					end
				end
			end
			shaking[wall] = nil
			return
		end
		-- (out and back once, damped)
		local k = math.sin(t / W.Time * math.pi) * (1 - t / W.Time)
		for part, c in parts do
			local up = math.clamp((c.Position.Y - bottom) / size.Y, 0, 1)
			part.CFrame = c + push * (W.Base + W.Top * up * up) * k
		end
	end)
end

local function flash(wall)
	local gui = wall:FindFirstChild("WallHealth")
	local back = gui and gui:FindFirstChild("Back")
	if back and not back:GetAttribute("Flashing") then
		back:SetAttribute("Flashing", true)
		local was = back.BackgroundColor3
		back.BackgroundColor3 = Color3.new(1, 1, 1)
		task.delay(W.Flash, function()
			back.BackgroundColor3 = was
			back:SetAttribute("Flashing", nil)
		end)
	end
end

local function chips(wall, from)
	if math.random() >= W.ChipChance then
		return
	end
	local at = from + (wall:GetPivot().Position - from) * 0.7 + Vector3.new(0, 2.5, 0)
	for _ = 1, math.random(W.Chips[1], W.Chips[2]) do
		local chip = Instance.new("Part")
		chip.Name = "WallChip"
		chip.Size = Vector3.new(0.35, 0.12, 0.2)
		chip.Color = Color3.fromRGB(150, 100, 55)
		chip.Material = Enum.Material.Wood
		chip.CanCollide, chip.CanQuery, chip.CanTouch = false, false, false
		chip.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.AssemblyLinearVelocity = Vector3.new(math.random() * 8 - 4, 9 + math.random() * 5, math.random() * 8 - 4)
		chip.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, 0)
		chip.Parent = workspace
		Debris:AddItem(chip, W.ChipLife)
	end
end

blow.Event:Connect(function(monster)
	if not monster.Parent then
		return
	end
	local from = monster:GetPivot().Position
	local wall = wallNear(from)
	if not wall then
		return
	end
	shudder(wall, from)
	flash(wall)
	chips(wall, from)
end)
