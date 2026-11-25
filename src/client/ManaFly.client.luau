-- Rewards fly to where they are counted (6A): when a monster falls and the mana goes up, two or three small mana
-- orbs rise from where it fell and fly into the mana counter at the top, which bumps when they land. Restraint: at
-- most one flight every 0.4 s, small, quick (about 0.45 s), and only for kills on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = ReplicatedStorage:WaitForChild("GameState")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local Ui = require(script.Parent:WaitForChild("Ui"))

local last = {} -- enemy model -> last position
local recent = nil -- { pos, time } of the last monster that left the field
local lastFlight = 0

local function enemies()
	return workspace:FindFirstChild("Enemies")
end

RunService.Heartbeat:Connect(function()
	local folder = enemies()
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			last[m] = m:GetPivot().Position
		end
	end
end)

local watched = nil
RunService.Heartbeat:Connect(function()
	local folder = enemies()
	if folder and folder ~= watched then
		watched = folder
		folder.ChildRemoved:Connect(function(m)
			local pos = last[m]
			last[m] = nil
			if pos then
				recent = { pos = pos, time = os.clock() }
			end
		end)
	end
end)

local function manaLabel()
	-- (on phones the run bar has its own screen, RunBar)
	local status = gui:FindFirstChild("RunStatus", true)
	if not status then
		return nil
	end
	for _, d in status:GetChildren() do
		if d:IsA("TextLabel") and d.Text:match(" mana$") then
			return d
		end
	end
	return nil
end

local function fly(from2d, target, count)
	local hud = gui:FindFirstChild("RealmGuardiansHud")
	if not hud then
		return
	end
	local goal = target.AbsolutePosition + target.AbsoluteSize * Vector2.new(0.15, 0.5)
	-- (a target on another screen with other insets, the phones' RunBar: into this screen's positions)
	local targetGui = target:FindFirstAncestorWhichIsA("ScreenGui")
	if targetGui and targetGui ~= hud then
		goal += targetGui.AbsolutePosition - hud.AbsolutePosition
	end
	for i = 1, count do
		local orb = Instance.new("Frame")
		orb.Size = UDim2.fromOffset(12, 12)
		orb.AnchorPoint = Vector2.new(0.5, 0.5)
		orb.BackgroundColor3 = Ui.MANA or Color3.fromRGB(170, 150, 255)
		orb.BorderSizePixel = 0
		orb.ZIndex = 40
		orb.Parent = hud
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = orb
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 1.5
		stroke.Parent = orb
		local start = from2d + Vector2.new((i - (count + 1) / 2) * 14, 0)
		local lift = start + Vector2.new((i - 2) * 10, -40)
		task.delay((i - 1) * 0.035, function()
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = math.min(1, (os.clock() - t0) / 0.45)
				-- an eased curve (rise, then pulled into the counter), not a straight linear slide
				local e = 1 - (1 - t) ^ 3
				local a = start:Lerp(lift, e)
				local b = lift:Lerp(goal, e)
				local p = a:Lerp(b, e)
				orb.Position = UDim2.fromOffset(p.X, p.Y - hud.AbsolutePosition.Y)
				if t >= 1 then
					conn:Disconnect()
					orb:Destroy()
					if i == count and Ui.pop then
						Ui.pop(target, 1.15)
					end
				end
			end)
		end)
	end
end

local shown = GameState:GetAttribute("Gold") or 0
GameState:GetAttributeChangedSignal("Gold"):Connect(function()
	local gold = GameState:GetAttribute("Gold") or 0
	local gained = gold - shown
	shown = gold
	local state = GameState:GetAttribute("State")
	if gained <= 0 or (state ~= "Wave" and state ~= "Break") or not recent or os.clock() - recent.time > 0.35 then
		return
	end
	if os.clock() - lastFlight < 0.4 then
		return
	end
	local camera = workspace.CurrentCamera
	local p, onScreen = camera:WorldToViewportPoint(recent.pos + Vector3.new(0, 2, 0))
	local target = manaLabel()
	if not onScreen or not target then
		return
	end
	lastFlight = os.clock()
	fly(Vector2.new(p.X, p.Y), target, math.clamp(math.ceil(gained / 8), 2, 3))
end)
