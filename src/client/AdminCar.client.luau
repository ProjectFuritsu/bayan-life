-- Drives the admin car while you sit in its driver seat (W/S or the thumbstick
-- for gas and reverse, A/D to steer). The server gives the driver control of
-- the car's physics, so this sets the car's two constraints on your side:
-- "Drive" (flat speed along the car's nose) and "Turn" (turning speed).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local MAX_SPEED = 60 -- studs per second forward
local REVERSE_SPEED = 20
local ACCELERATION = 30 -- studs per second, each second
local BRAKING = 70
local TURN_RATE = 1.8 -- radians per second when moving

local function drive(seat, humanoid)
	local chassis = seat.Parent and seat.Parent:FindFirstChild("Chassis")
	local move = chassis and chassis:FindFirstChild("Drive")
	local turn = chassis and chassis:FindFirstChild("Turn")
	if not move or not turn then
		return
	end
	local speed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if seat.Occupant ~= humanoid then
			move.PlaneVelocity = Vector2.zero
			turn.AngularVelocity = Vector3.zero
			connection:Disconnect()
			return
		end
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
		local target = if throttle > 0 then throttle * MAX_SPEED else throttle * REVERSE_SPEED
		-- Brake harder when letting go or switching direction
		local rate = if target == 0 or (speed ~= 0 and math.sign(target) ~= math.sign(speed)) then BRAKING else ACCELERATION
		if speed < target then
			speed = math.min(target, speed + rate * dt)
		else
			speed = math.max(target, speed - rate * dt)
		end
		local look = chassis.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
		move.PlaneVelocity = Vector2.new(flat.X * speed, flat.Z * speed)
		-- Turn only while moving (and the other way when reversing, like a real car)
		turn.AngularVelocity = Vector3.new(0, -steer * TURN_RATE * math.clamp(speed / 15, -1, 1), 0)
	end)
end

local function watch(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and CollectionService:HasTag(seatPart, "AdminCarSeat") then
			drive(seatPart, humanoid)
		end
	end)
end

player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
