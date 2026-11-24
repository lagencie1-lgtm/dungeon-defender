-- A boss with two jobs (research report 2026-11-24, priority two): while the boss's escort presses the portal,
-- the boss winds up a charge at one defender. Everyone sees which one: a marker over that defender, a line of beads
-- on the ground from the boss to it, and one line of text naming it. Heroes who hit the boss during the wind-up
-- break the charge: it staggers back and takes more damage for a moment. Nobody answers: the charge lands and
-- jams that defender for a few seconds (it is never destroyed). The numbers are the boss's own Charge in
-- Config.Enemies; EnemyService runs the wind-up, this module draws it and answers it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(ReplicatedStorage.Shared.Ground)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local BossService = {}

local TELL = Color3.fromRGB(255, 90, 60)
local tells = {} -- [enemy] = { parts to remove }

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function towerName(model)
	local info = Config.Towers[model:GetAttribute("TowerType") or ""]
	return info and (info.DisplayName or model:GetAttribute("TowerType")) or "defender"
end

-- the defender nearest to the boss, within reach
local function pickTarget(enemy, range)
	local folder = workspace:FindFirstChild("Towers")
	local best, bestDistance = nil, range
	for _, model in folder and folder:GetChildren() or {} do
		if model:IsA("Model") and model:GetAttribute("TowerType") then
			local d = (flat(model:GetPivot().Position) - flat(enemy.position)).Magnitude
			if d <= bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

local function clearTell(enemy)
	for _, thing in tells[enemy] or {} do
		thing:Destroy()
	end
	tells[enemy] = nil
end

-- the tell: a marker over the defender, a dotted line on the ground to it, one line of text
local function showTell(enemy, target, seconds)
	clearTell(enemy)
	local list = {}
	local folder = workspace:FindFirstChild("Effects") or workspace
	local top = target:GetPivot().Position
	local _, size = target:GetBoundingBox()
	-- (on the defender's body, not over its roof: from the battle camera on a phone the roof sits under the wave
	-- panel at the top of the screen, and the first film showed the marker hidden there)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChargeTarget"
	gui.Size = UDim2.fromOffset(34, 34)
	gui.StudsOffset = Vector3.new(0, size.Y * 0.1, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.72, 0.72)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = TELL
	diamond.BorderSizePixel = 0
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(60, 15, 10)
	outline.Thickness = 2
	outline.Parent = diamond
	diamond.Parent = gui
	gui.Adornee = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	gui.Parent = target
	table.insert(list, gui)
	-- beads on the ground from the boss to the defender
	local from, to = flat(enemy.position), flat(top)
	local steps = math.clamp(math.floor((to - from).Magnitude / 3), 4, 16)
	for i = 1, steps - 1 do
		local p = from:Lerp(to, i / steps)
		local bead = Instance.new("Part")
		bead.Name = "ChargeLine"
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.one * 0.6
		bead.Material = Enum.Material.Neon
		bead.Color = TELL
		bead.Transparency = 0.25
		bead.Anchored, bead.CanCollide, bead.CanQuery, bead.CanTouch = true, false, false, false
		bead.CastShadow = false
		bead.Position = Vector3.new(p.X, (Ground.At(p.X, p.Z)) + 0.35, p.Z)
		bead.Parent = folder
		table.insert(list, bead)
	end
	-- and a ring of the same beads on the ground round the defender's feet: readable from the high camera even when
	-- the boss stands in front of it
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local x, z = top.X + math.cos(a) * 5, top.Z + math.sin(a) * 5
		local bead = Instance.new("Part")
		bead.Name = "ChargeLine"
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.one * 0.7
		bead.Material = Enum.Material.Neon
		bead.Color = TELL
		bead.Transparency = 0.2
		bead.Anchored, bead.CanCollide, bead.CanQuery, bead.CanTouch = true, false, false, false
		bead.CastShadow = false
		bead.Position = Vector3.new(x, (Ground.At(x, z)) + 0.4, z)
		bead.Parent = folder
		table.insert(list, bead)
	end
	tells[enemy] = list
	Remotes.Notify:FireAllClients(string.format("The %s is charging your %s! Hit him to stop it", enemy.stats.DisplayName,
		towerName(target)), TELL)
	Sound.Play("PortalHit", enemy.position)
	task.delay(seconds + 1, function()
		if tells[enemy] == list then
			clearTell(enemy)
		end
	end)
end

-- the wind-up is over: broken by heroes, or it lands on the defender
local function endCharge(enemy, target, broken, by)
	clearTell(enemy)
	local charge = enemy.stats.Charge
	if broken then
		Remotes.Notify:FireAllClients((by and by.DisplayName or "Heroes") .. " broke the charge! Hit him while he staggers",
			Color3.fromRGB(140, 255, 160))
		Effects.Text(enemy.position + Vector3.new(0, enemy.stats.Size * 1.5, 0), "Staggered", Color3.fromRGB(255, 230, 140), 1.2)
		return
	end
	if not target or not target.Parent then
		return
	end
	local at = target:GetPivot().Position
	Effects.Projectile(enemy.position + Vector3.new(0, enemy.stats.Size * 0.6, 0), at + Vector3.new(0, 2, 0), TELL, 2, 0.35)
	task.delay(0.35, function()
		if not target.Parent then
			return
		end
		Effects.Shockwave(at, 6, TELL)
		Sound.Play("Explosion", at)
		TowerService.Stun(at, 3, charge.Stun)
		Remotes.Notify:FireAllClients(string.format("Your %s is jammed for %d seconds", towerName(target), charge.Stun),
			Color3.fromRGB(255, 160, 120))
	end)
end

function BossService.Start()
	EnemyService.PickChargeTarget = pickTarget
	EnemyService.OnChargeTell = showTell
	EnemyService.OnChargeEnd = endCharge
end

-- a run ends or restarts
function BossService.Clear()
	for enemy in tells do
		clearTell(enemy)
	end
end

return BossService
