-- The first-wave rescue (research report 2026-11-24, priority one): towers handle the slow goblins, then a Goblin Sneak
-- slips out past the first Ranger's reach and runs for the portal. It is too tough for one Ranger on its own, slow
-- enough for a hero to catch: the player runs over and saves the portal. A defender that catches it anyway is a
-- success too (a good spot). If it gets through, the portal takes a small, recoverable hit.
--
-- The server marks the Sneak (a small diamond over it, seen through trees), plays quick footsteps and tells every
-- hero where they can still catch it: player attribute "RescueAt" (drawn by RescueCue.client.luau). It works out that
-- spot from the path and the hero's own position, so it fits any map layout without fixed coordinates.
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Clock = require(script.Parent.Clock)
local State = require(script.Parent.State)
local EnemyService = require(script.Parent.EnemyService)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Telemetry = require(script.Parent.Telemetry)

local RescueService = {}

local MARK_COLOR = Color3.fromRGB(255, 170, 50)
local watching = {} -- [enemy] = { escaped = bool }

local function notify(text, color, player)
	if player then
		Remotes.Notify:FireClient(player, text, color)
	else
		Remotes.Notify:FireAllClients(text, color)
	end
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- a small warm diamond over the Sneak, drawn on top of trees and walls (no Highlight: those crash weak phones, 6A)
local function mark(enemy)
	local head = enemy.head
	if not head or not head.Parent then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RescueMark"
	gui.Size = UDim2.fromOffset(18, 18)
	gui.StudsOffset = Vector3.new(0, enemy.stats.Size * 1.1 + 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.72, 0.72)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = MARK_COLOR
	diamond.BorderSizePixel = 0
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(70, 35, 10)
	outline.Thickness = 2
	outline.Parent = diamond
	diamond.Parent = gui
	gui.Parent = head
end

-- where this hero can still get in front of the Sneak: the first point ahead on its path that the hero reaches
-- (running straight, a little slower for turns and stairs) before the Sneak does. nil when there is none.
local function catchSpot(enemy, root)
	local speed = enemy.stats.Speed * (enemy.speedMult or 1)
	local length = EnemyService.PathLength()
	local d = enemy.distance + 4
	while d < length do
		local at = EnemyService.PathPoint(d)
		local heroTime = (Vector3.new(at.X, 0, at.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			/ Config.Rescue.HeroSpeed
		if heroTime + Config.Rescue.Margin <= (d - enemy.distance) / speed then
			return at
		end
		d += 3
	end
	return nil
end

local function clearSpots()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("RescueAt", nil)
	end
end

local function log(player, name, value)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = State.Get("Map") or "",
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = State.Get("Difficulty") or "",
		})
	end)
end

-- the wave code calls this for every enemy it spawns; only Rescue enemies are watched
function RescueService.Spawned(enemy)
	if not enemy or not enemy.stats.Rescue then
		return
	end
	local state = { escaped = false, born = Clock.now }
	watching[enemy] = state
	mark(enemy)
	Effects.Burst(enemy.position + Vector3.new(0, 1.5, 0), 3, MARK_COLOR, 0.3)
	Sound.Play("Sneak", enemy.position)
	task.spawn(function()
		local length = EnemyService.PathLength()
		while watching[enemy] and not enemy.dead do
			if not state.escaped and enemy.distance >= length * Config.Rescue.EscapeAt then
				state.escaped = true
				-- the moment it gets past: one line, one sound, then the catch-it-here ring for every hero
				notify("A Goblin Sneak slipped past! Run and catch it before the portal", MARK_COLOR)
				Sound.Play("Sneak")
			end
			if state.escaped then
				for _, player in Players:GetPlayers() do
					local root = rootOf(player)
					local spot = root and catchSpot(enemy, root)
					-- already right next to it: no ring needed
					if spot and (root.Position - enemy.position).Magnitude < 10 then
						spot = nil
					end
					player:SetAttribute("RescueAt", spot)
				end
			end
			task.wait(0.25)
		end
		clearSpots()
	end)
end

function RescueService.Killed(enemy, player)
	local state = watching[enemy]
	if not state then
		return
	end
	watching[enemy] = nil
	clearSpots()
	if player then
		notify(player.DisplayName .. " caught the Sneak! The portal is safe", Color3.fromRGB(140, 255, 160))
		player:SetAttribute("Rescues", (player:GetAttribute("Rescues") or 0) + 1)
		log(player, "Rescue", math.floor(Clock.now - state.born))
		Telemetry.First(player, "FirstRescue")
	else
		notify("Your defenders caught the Sneak. Good spot!", Color3.fromRGB(140, 255, 160))
		for _, p in Players:GetPlayers() do
			log(p, "RescueByDefender", math.floor(Clock.now - state.born))
		end
	end
end

function RescueService.Leaked(enemy)
	if not watching[enemy] then
		return
	end
	watching[enemy] = nil
	clearSpots()
	notify("The Sneak reached the portal. Heroes can run and catch runaways!", Color3.fromRGB(255, 150, 120))
	for _, p in Players:GetPlayers() do
		log(p, "RescueMissed", 0)
	end
end

-- a run ends or restarts
function RescueService.Clear()
	table.clear(watching)
	clearSpots()
end

return RescueService
