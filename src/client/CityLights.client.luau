-- Street lamps turn on at dusk and off in the morning (game clock).
-- Lamps are parts tagged "NightLight" with a PointLight inside.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameClock = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameClock"))

local ON_COLOR = Color3.fromRGB(255, 235, 185)
local OFF_COLOR = Color3.fromRGB(215, 215, 210)
local DUSK, DAWN = 17.5, 6.3 -- lamps on from 5:30 PM to 6:18 AM

local lampsOn = nil

local function setLamp(part, on)
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = on
	end
	part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
	part.Color = if on then ON_COLOR else OFF_COLOR
end

CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(part)
	if part:IsA("BasePart") then
		setLamp(part, lampsOn == true)
	end
end)

while true do
	local hour = GameClock.hour(workspace:GetServerTimeNow())
	local on = hour >= DUSK or hour < DAWN
	if on ~= lampsOn then
		lampsOn = on
		for _, part in CollectionService:GetTagged("NightLight") do
			if part:IsA("BasePart") then
				setLamp(part, on)
			end
		end
	end
	task.wait(1)
end
