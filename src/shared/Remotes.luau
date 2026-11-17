-- The messages the players' computers and the server send each other.
-- The server makes them, players' computers wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "StartWave", "HeroAttack", "HeroWhirlwind", "PlayAgain", "Notify" }
local FUNCTIONS = { "PlaceTower", "UpgradeTower", "SellTower" }

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			Instance.new("RemoteEvent", folder).Name = name
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			Instance.new("RemoteFunction", folder).Name = name
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in FUNCTIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
