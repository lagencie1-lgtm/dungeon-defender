-- The game's own clock. It runs faster when the speed button is on 2x,
-- so goblins, defenders and wave timers all speed up together.
local RunService = game:GetService("RunService")

local Clock = {
	now = 0,
	scale = 1,
}

RunService.Heartbeat:Connect(function(dt)
	Clock.now += dt * Clock.scale
end)

-- like task.wait, but in game time (half as long on 2x speed)
function Clock.Wait(seconds)
	local target = Clock.now + seconds
	while Clock.now < target do
		task.wait()
	end
end

return Clock
