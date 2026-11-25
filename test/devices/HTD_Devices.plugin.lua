-- Heroes Tower Defense device pass helper (scripts/device_pass.py copies it to %LOCALAPPDATA%\Roblox\Plugins).
-- Does nothing unless the opened place has ReplicatedStorage.DeviceTest (only the htd-devices-* builds do). Then it
-- switches Studio's Device Emulator to that device (attribute SimDevice, landscape), prints what the emulator gives,
-- and starts a play test so test/devices runs its route and checks.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if RunService:IsRunning() or not string.find(game.Name, "htd%-devices") then
	return
end
task.delay(8, function()
	local probe = ReplicatedStorage:FindFirstChild("DeviceTest")
	if not probe then
		return
	end
	local device = probe:GetAttribute("SimDevice")
	local sim = game:GetService("StudioDeviceSimulatorService")
	local ok, err = true, nil
	if device and device ~= "" then
		ok, err = pcall(function()
			sim:SetDeviceAsync(device)
		end)
		-- (only phones and tablets turn: a TV or a PC preset says "orientation can only be set on mobile")
		pcall(function()
			if probe:GetAttribute("Portrait") then
				sim:SetOrientationAsync(Enum.ScreenOrientation.Portrait)
			else
				sim:SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)
			end
		end)
	end
	print("[DEVICES] plugin emulator", device, ok and "set" or ("FAILED: " .. tostring(err)))
	-- a list of what this Studio can emulate, so a wrong id can be fixed in scripts/device_pass.py
	local listed, list = pcall(function()
		return sim:GetDeviceListAsync()
	end)
	if listed and type(list) == "table" then
		local names = {}
		for key, value in list do
			table.insert(names, type(value) == "table" and tostring(value.Id or value.id or value.Name or key) or tostring(value))
		end
		print("[DEVICES] plugin devices", table.concat(names, ", "))
	end
	local played, playErr = pcall(function()
		game:GetService("StudioTestService"):ExecutePlayModeAsync({})
	end)
	print("[DEVICES] play test finished", played, playErr)
end)
