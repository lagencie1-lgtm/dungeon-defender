-- Heroes Tower Defense film helper (copy to %LOCALAPPDATA%\Roblox\Plugins\HTD_Film.lua).
-- Does nothing unless the opened file is named htd-film-*.rbxl:
--   htd-film-phone*  iPhone 13 landscape in the device simulator, graphics quality 1 (a cheap phone)
--   htd-film-phonehq* iPhone 13 landscape, graphics quality 8
--   htd-film-pc*     the plain Studio window
-- then starts a play test so test/film runs its route (scripts/film.ps1 films the window).
local RunService = game:GetService("RunService")
if RunService:IsRunning() or not string.find(game.Name, "htd%-film") then
	return
end
task.delay(8, function()
	local phone = string.find(game.Name, "phone") ~= nil
	if phone then
		local sim = game:GetService("StudioDeviceSimulatorService")
		pcall(function()
			sim:SetDeviceAsync("iphone_13")
			sim:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)
		end)
	end
	local rendering = settings().Rendering
	local previous = rendering.QualityLevel
	if string.find(game.Name, "phonehq") then
		rendering.QualityLevel = Enum.QualityLevel.Level08
	elseif phone then
		rendering.QualityLevel = Enum.QualityLevel.Level01
	end
	print("[FILM] plugin starting play test", game.Name, rendering.QualityLevel)
	local ok, err = pcall(function()
		game:GetService("StudioTestService"):ExecutePlayModeAsync({})
	end)
	rendering.QualityLevel = previous
	print("[FILM] play test finished", ok, err)
end)
