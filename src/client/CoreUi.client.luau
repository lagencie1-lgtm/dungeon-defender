-- Roblox's own screens that repeat ours are switched off on this device:
--   Health   the small red/green bar in the top bar when the hero is hurt (the hero panel shows health; on phones it
--            sat in the top strip next to our run bar)
--   Backpack Roblox's tool hotbar (our heroes use buttons and the Backpack screen, not Tools)
-- Kept on: the player list (it shows leaderstats on purpose), chat, emotes and the Roblox menu.
local StarterGui = game:GetService("StarterGui")

for _, kind in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	StarterGui:SetCoreGuiEnabled(kind, false)
end
