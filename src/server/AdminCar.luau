-- The admin's own car: a drivable convertible that parks in bay 1 of the
-- Admin Mansion's motor court (Veterans Parc).
--   Driver seat: admins only (Admin.isAdmin). Anyone may ride in the passenger seat.
--   Driving: the driver's client moves the car (AdminCar.client.luau) through
--   two constraints on the Chassis: "Drive" (LinearVelocity, flat X/Z) and
--   "Turn" (AngularVelocity, which also keeps the car upright).
--   Left somewhere for a minute (or fell off the map)? It goes back to its bay.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admin = require(ReplicatedStorage.Shared.Admin)
local MapKit = require(script.Parent.MapKit)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local AdminCar = {}

local RETURN_AFTER = 60 -- seconds with nobody driving before it drives itself home
local surfaceText = MapKit.new(CFrame.new()).surfaceText

local COLORS = {
	body = Color3.fromRGB(25, 25, 30),
	gold = Color3.fromRGB(225, 185, 70),
	tire = Color3.fromRGB(20, 20, 20),
	seat = Color3.fromRGB(150, 40, 40),
	glass = Color3.fromRGB(150, 190, 215),
}

-- Builds the car around the Chassis (car front = local -Z, origin at the ground).
local function build(spot)
	local model = Instance.new("Model")
	model.Name = "AdminCar"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(3.4, 0.6, 6.4)
	chassis.CFrame = spot * CFrame.new(0, 1.2, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.Parent = model
	model.PrimaryPart = chassis

	local function piece(className, name, size, offset, color, material)
		local p = Instance.new(className)
		p.Name = name
		p.Size = size
		p.CFrame = spot * offset
		p.Color = color or COLORS.body
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Body (solid, raised off the ground so curbs don't catch it)
	local body = piece("Part", "Body", Vector3.new(3.6, 1.2, 7), CFrame.new(0, 1.6, 0))
	body.CanCollide = true
	piece("Part", "Hood", Vector3.new(3.4, 0.3, 2.4), CFrame.new(0, 2.35, -2.2))
	piece("Part", "HoodStripe", Vector3.new(0.6, 0.05, 2.4), CFrame.new(0, 2.52, -2.2), COLORS.gold, Enum.Material.Metal)
	piece("Part", "Trunk", Vector3.new(3.4, 0.4, 1.6), CFrame.new(0, 2.4, 2.6))
	local windshield = piece("Part", "Windshield", Vector3.new(3.2, 1.1, 0.12), CFrame.new(0, 2.8, -1.05) * CFrame.Angles(math.rad(-25), 0, 0), COLORS.glass, Enum.Material.Glass)
	windshield.Transparency = 0.4
	for _, x in { -1.2, 1.2 } do
		piece("Part", "Headlight", Vector3.new(0.8, 0.4, 0.1), CFrame.new(x, 1.75, -3.52), Color3.fromRGB(255, 245, 210), Enum.Material.Neon)
		piece("Part", "TailLight", Vector3.new(0.8, 0.3, 0.1), CFrame.new(x, 1.75, 3.52), Color3.fromRGB(220, 30, 30), Enum.Material.Neon)
	end
	local plate = piece("Part", "Plate", Vector3.new(1.6, 0.5, 0.05), CFrame.new(0, 1.35, 3.53), Color3.fromRGB(245, 245, 240))
	surfaceText(plate, Enum.NormalId.Back, "ADMIN", COLORS.body)

	-- Wheels (for looks) and invisible ball colliders that slide on the ground
	for _, x in { -1.65, 1.65 } do
		for _, z in { -2.3, 2.3 } do
			local wheel = piece("Part", "Wheel", Vector3.new(0.6, 1.6, 1.6), CFrame.new(x, 0.8, z), COLORS.tire)
			wheel.Shape = Enum.PartType.Cylinder
			piece("Part", "Hubcap", Vector3.new(0.62, 0.8, 0.8), CFrame.new(x, 0.8, z), COLORS.gold, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
			local collider = piece("Part", "Collider", Vector3.new(1.7, 1.7, 1.7), CFrame.new(x * 0.75, 0.85, z))
			collider.Shape = Enum.PartType.Ball
			collider.Transparency = 1
			collider.CanCollide = true
			collider.Massless = false
			collider.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 100, 100)
		end
	end

	-- Seats: driver (left) and passenger (right), with a seat back each
	local driverSeat = piece("VehicleSeat", "DriverSeat", Vector3.new(1.4, 0.4, 1.6), CFrame.new(-0.75, 2.4, 0.7), COLORS.seat, Enum.Material.Fabric)
	driverSeat.HeadsUpDisplay = false
	CollectionService:AddTag(driverSeat, "AdminCarSeat")
	piece("Seat", "PassengerSeat", Vector3.new(1.4, 0.4, 1.6), CFrame.new(0.75, 2.4, 0.7), COLORS.seat, Enum.Material.Fabric)
	for _, x in { -0.75, 0.75 } do
		piece("Part", "SeatBack", Vector3.new(1.4, 1.4, 0.3), CFrame.new(x, 3.1, 1.6), COLORS.seat, Enum.Material.Fabric)
	end
	piece("Part", "SteeringWheel", Vector3.new(0.2, 1, 1), CFrame.new(-0.75, 3, -0.5) * CFrame.Angles(0, math.rad(90), math.rad(-60)), COLORS.tire).Shape = Enum.PartType.Cylinder

	-- The two constraints the driver's client controls
	local attachment = Instance.new("Attachment")
	attachment.Name = "Root"
	attachment.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	drive.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	drive.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	drive.MaxForce = 12000
	drive.PlaneVelocity = Vector2.zero
	drive.Parent = chassis
	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = attachment
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.MaxTorque = 200000
	turn.AngularVelocity = Vector3.zero
	turn.Parent = chassis

	model.Parent = workspace
	return model, chassis, driverSeat, drive, turn
end

-- spot = the bay's CFrame (car facing its front, at ground level)
function AdminCar.start(spot)
	if not spot then
		return
	end
	local model, chassis, seat, drive, turn = build(spot)
	local lastUsed = os.clock()
	local lastWarn = {} -- [Player] = os.clock()

	local function stop()
		drive.PlaneVelocity = Vector2.zero
		turn.AngularVelocity = Vector3.zero
		pcall(function()
			chassis:SetNetworkOwner(nil)
		end)
	end

	local function goHome()
		stop()
		model:PivotTo(spot * CFrame.new(0, 1.2, 0))
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		lastUsed = os.clock()
		local humanoid = seat.Occupant
		if not humanoid then
			stop()
			return
		end
		local player = Players:GetPlayerFromCharacter(humanoid.Parent)
		if player and Admin.isAdmin(player) then
			pcall(function()
				chassis:SetNetworkOwner(player) -- smooth driving on the driver's side
			end)
			return
		end
		-- Not an admin: out of the driver's seat
		task.defer(function()
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
			humanoid.Jump = true
		end)
		if player and os.clock() - (lastWarn[player] or 0) > 5 then
			lastWarn[player] = os.clock()
			Notify:FireClient(player, "Only the admin can drive this car. The passenger seat is free! 🚗", "info")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWarn[player] = nil
	end)

	-- Valet: drives itself home when left alone, or if it falls off the map
	task.spawn(function()
		while model.Parent do
			task.wait(5)
			if seat.Occupant then
				lastUsed = os.clock()
			elseif chassis.Position.Y < -30 then
				goHome()
			elseif os.clock() - lastUsed > RETURN_AFTER and (chassis.Position - spot.Position).Magnitude > 12 then
				goHome()
			end
		end
	end)
end

return AdminCar
