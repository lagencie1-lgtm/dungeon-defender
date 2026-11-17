-- The game's shared numbers (gold, wave, portal health...).
-- They live as attributes on ReplicatedStorage.GameState so every player's
-- screen can show them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {}

local folder = ReplicatedStorage:FindFirstChild("GameState") or Instance.new("Folder")
folder.Name = "GameState"
folder.Parent = ReplicatedStorage

function State.Get(key)
	return folder:GetAttribute(key)
end

function State.Set(key, value)
	folder:SetAttribute(key, value)
end

-- the whole team shares one gold pile
function State.AddGold(amount)
	State.Set("Gold", (State.Get("Gold") or 0) + amount)
end

function State.TrySpend(amount)
	local gold = State.Get("Gold") or 0
	if gold < amount then
		return false
	end
	State.Set("Gold", gold - amount)
	return true
end

return State
