-- What the equipped pet does in a fight. Its bonus stat picks the move (Config.PetMoves):
--   Power       Pounce  hits the enemy furthest along the path near the hero (Leafling slows, dragons burn)
--   Command     Rally   the nearest defender deals more damage for a moment
--   Engineering Spark   the nearest defender shoots faster for a moment
--   Crit        Mark    an enemy gets a small mark; the next hit on it is a sure crit
--   GoldFind    Dig     now and then the pet digs up a little mana for the team
-- Only the LEAD pet of the team does its move. Every pet of the team fetches loot.
-- Every pet also fetches loot from the ground (Config.PetCarry: what, how far, how fast, by pet rarity):
-- it trots to gems and gear lying near its hero, grabs them and carries them back. Better pets carry more, faster.
-- 6A: rare and small, nothing to press, the same on phone, console and PC.
-- The server decides and applies every move. It only tells the pet model what happened ("PetAct" attributes),
-- and every device draws the lunge and the little shot from where it shows the pet (PetFollow.client.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Clock = require(script.Parent.Clock)
local EnemyService = require(script.Parent.EnemyService)
local TowerService = require(script.Parent.TowerService)
local LootService = require(script.Parent.LootService)
local ItemService = require(script.Parent.ItemService)
local Items = require(ReplicatedStorage.Shared.Items)
local PetService = require(script.Parent.PetService)

local PetMoves = {}

local HIT_DELAY = 0.22 -- the pet's lunge reaches the target after this long (game time)
local MARK_COLOR = Color3.fromRGB(255, 225, 90)

local timers = {} -- [player] = { move = game time of the next move, dig = next mana dig }

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- 10% more per pet level, x1.5 when evolved (the same growth as the pet's bonus, a bit gentler on evolving),
-- x1.25 Golden and x1.5 Rainbow (Config.PetTiers Move)
local function strength(pet)
	return (1 + 0.1 * ((pet.level or 1) - 1)) * (pet.evolved and 1.5 or 1) * Config.PetTierOf(pet).Move
end

local function waitFor(pet, seconds)
	return seconds * (pet.evolved and Config.PetEvolvedEvery or 1)
end

-- tells every device to play the move on the pet model
local function act(player, move, at)
	local model = PetService.FollowerOf(player)
	if not model or not at then
		return
	end
	model:SetAttribute("PetActMove", move)
	model:SetAttribute("PetActAt", at)
	model:SetAttribute("PetAct", (model:GetAttribute("PetAct") or 0) + 1) -- last, so the two above have arrived
end

-- a small gold diamond over the enemy until the next hit uses it up (EnemyService.Damage)
local function markEnemy(enemy)
	local head = enemy.head
	if not head or not head.Parent then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetMark"
	gui.Size = UDim2.fromOffset(14, 14)
	gui.StudsOffset = Vector3.new(0, enemy.stats.Size * 0.9 + 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.7, 0.7)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = MARK_COLOR
	diamond.BorderSizePixel = 0
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(60, 40, 10)
	outline.Thickness = 1.5
	outline.Parent = diamond
	diamond.Parent = gui
	gui.Parent = head
	enemy.petMark = gui
end

local MOVES = {}

function MOVES.Power(player, pet, info, move, root)
	if State.Get("Mode") == "Pacifist" then
		return false -- "Hands Off": the hero's side doesn't attack, the pet neither
	end
	local enemy = EnemyService.InRange(root.Position, move.Range)[1]
	if not enemy then
		return false
	end
	act(player, "Pounce", enemy.position)
	local level = player:GetAttribute("HeroLevel") or 1
	local power = (player:GetAttribute("BonusPower") or 0) / 100
	local damage = move.Damage * strength(pet) * (1 + (level - 1) * Config.DamagePerHeroLevel) * (1 + power)
	task.delay(HIT_DELAY / Clock.scale, function()
		if enemy.dead then
			return
		end
		EnemyService.Damage(enemy, damage, player, true, false)
		EnemyService.Knockback(enemy, 0.8)
		if info.MoveSlow then
			EnemyService.Slow(enemy, 0.6, 1.5)
		elseif info.MoveBurn then
			EnemyService.Burn(enemy, damage * 0.15, 3, player)
		end
	end)
	return true
end

local function boost(kind, amountKey)
	return function(player, pet, _info, move, root)
		local at = TowerService.PetBoost(root.Position, move.Range, kind, move[amountKey] * strength(pet), move.Time)
		if not at then
			return false
		end
		act(player, kind, at)
		return true
	end
end
MOVES.Command = boost("Rally", "Boost")
MOVES.Engineering = boost("Spark", "Speed")

function MOVES.Crit(player, _pet, _info, move, root)
	for _, enemy in EnemyService.InRange(root.Position, move.Range) do
		if not enemy.petMark then
			act(player, "Mark", enemy.position)
			task.delay(HIT_DELAY / Clock.scale, function()
				if not enemy.dead and not enemy.petMark then
					markEnemy(enemy)
				end
			end)
			return true
		end
	end
	return false
end

function MOVES.GoldFind(player, pet, _info, move, root)
	State.AddGold(math.floor(move.Mana * strength(pet) + 0.5))
	act(player, "Dig", root.Position)
	return true
end

-------------------------------------------------------------------------------
-- fetching loot from the ground (real time: it is only walking, and the walk is drawn in real time)
-------------------------------------------------------------------------------
local GEM_COLOR = Color3.fromRGB(90, 220, 255)
local trips = {} -- [player] = { [pet id] = { busy = true while on a trip, next = os.clock() of the next trip } }
local claimed = {} -- loot a pet is already walking to: [gem part or drop id] = true

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- the model of one pet of the team (looked up every time: a level-up rebuilds the models)
local function modelOf(player, petId)
	for _, f in PetService.FollowersOf(player) do
		if f.pet.id == petId then
			return f.model
		end
	end
	return nil
end

-- the nearest loot this pet may take, plus whatever lies close to it (up to `carry` pieces)
local function pickLoot(player, root, carry)
	local found = {}
	if carry.Gems then
		for _, g in LootService.GemsNear(root.Position, carry.Range) do
			if not claimed[g.gem] then
				table.insert(found, g)
			end
		end
	end
	for _, d in ItemService.DropsNear(player, root.Position, carry.Range, carry.MaxItemRarity) do
		if not claimed[d.dropId] then
			table.insert(found, d)
		end
	end
	if #found == 0 then
		return nil
	end
	table.sort(found, function(a, b)
		return flatDistance(a.position, root.Position) < flatDistance(b.position, root.Position)
	end)
	local first = found[1]
	local load = { first }
	for i = 2, #found do
		if #load >= carry.Carry then
			break
		end
		if flatDistance(found[i].position, first.position) <= 8 then
			table.insert(load, found[i])
		end
	end
	return first.position, load
end

local function setTrip(model, phase, at, speed, color)
	if not model or not model.Parent then
		return
	end
	if at then
		model:SetAttribute("FetchAt", at)
	end
	if speed then
		model:SetAttribute("FetchSpeed", speed)
	end
	model:SetAttribute("CarryColor", color)
	model:SetAttribute("FetchPhase", phase) -- last: "go", "back" or "" (just following)
end

local function fetchStep(player, pet, root)
	trips[player] = trips[player] or {}
	local trip = trips[player][pet.id]
	if not trip then
		trip = { next = os.clock() + 0.5 + math.random() } -- the team doesn't set off in the same instant
		trips[player][pet.id] = trip
	end
	if trip.busy or os.clock() < trip.next then
		return
	end
	local carry = Config.PetCarryOf(pet.kind, pet.evolved, player:GetAttribute("PassAutoCollect") == true, pet.tier)
	local at, load = pickLoot(player, root, carry)
	if not at then
		trip.next = os.clock() + 0.5
		return
	end
	trip.busy = true
	for _, piece in load do
		claimed[piece.gem or piece.dropId] = true
	end
	local there = math.max(flatDistance(at, root.Position) - 2, 1) / carry.Speed + 0.25
	setTrip(modelOf(player, pet.id), "go", at, carry.Speed, nil)
	task.delay(there, function()
		-- grab: whatever is still lying there (someone may have walked over it) goes into the backpack now
		local best = nil
		local carriesGear = false
		for _, piece in load do
			claimed[piece.gem or piece.dropId] = nil
			if not player.Parent then
				continue
			end
			if piece.gem then
				if LootService.TakeGem(piece.gem, player) then
					best = best or GEM_COLOR
				end
			elseif ItemService.TakeDrop(player, piece.dropId, modelOf(player, pet.id)) then
				carriesGear = true -- (the item itself rides on the pet: Loot.client.luau)
			end
		end
		local model = modelOf(player, pet.id)
		if (best or carriesGear) and model and model.Parent then
			model:SetAttribute("PetFetched", (model:GetAttribute("PetFetched") or 0) + 1) -- read by the autotest
		end
		local hero = rootOf(player)
		local back = hero and flatDistance(at, hero.Position) / carry.Speed or 1
		setTrip(model, "back", nil, nil, best)
		task.delay(back, function()
			setTrip(modelOf(player, pet.id), "", nil, nil, nil)
			trip.busy = false
			trip.next = os.clock() + carry.Rest
		end)
	end)
end

local function step()
	local now = Clock.now
	local inWave = State.Get("State") == "Wave"
	local inRun = State.Get("State") == "Wave" or State.Get("State") == "Break"
	for _, player in Players:GetPlayers() do
		local pet = PetService.EquippedPet(player)
		local info = pet and Config.Pets[pet.kind]
		local move = info and Config.PetMoves[info.Stat]
		local root = rootOf(player)
		if root and inRun then
			-- every pet of the team fetches; only the lead does its move
			for _, follower in PetService.FollowersOf(player) do
				fetchStep(player, follower.pet, root)
			end
		end
		if not move or not root or not inWave then
			timers[player] = nil -- a fresh start every wave, so nothing fires the moment a wave begins
			continue
		end
		local t = timers[player]
		if not t then
			-- the first move comes a little after the wave starts, not all pets on the same frame
			t = { move = now + waitFor(pet, move.Every) * (0.5 + math.random() * 0.5) }
			timers[player] = t
		end
		if now >= t.move then
			local did = MOVES[info.Stat](player, pet, info, move, root)
			-- nothing to do: look again soon instead of waiting a whole turn
			t.move = now + (did and waitFor(pet, move.Every) or 0.5)
		end
	end
end

function PetMoves.Start()
	Players.PlayerRemoving:Connect(function(player)
		timers[player] = nil
		trips[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then
				warn("[PetMoves] " .. tostring(err))
			end
		end
	end)
end

return PetMoves
