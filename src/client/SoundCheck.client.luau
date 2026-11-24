-- Loads and checks every sound on this device right after joining (see SoundBank.luau for why and how), then
-- prints the result and tells the server once (it reports a device that missed sounds to Creator Hub analytics).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundBank = require(script.Parent.SoundBank)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local report = SoundBank.CheckAll()
local line = "[SOUNDCHECK] " .. SoundBank.Summary(report)
if #report.failed > 0 then
	warn(line)
else
	print(line)
end
local names = {}
for _, f in report.failed do
	table.insert(names, f.names)
end
Remotes.SoundReport:FireServer(report.files, report.loaded, table.concat(names, ","))
-- the autotest reads this (attributes set here stay on this device)
Players.LocalPlayer:SetAttribute("SoundCheck", #report.failed == 0 and "ok" or table.concat(names, ","))
