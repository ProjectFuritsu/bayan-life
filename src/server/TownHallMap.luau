-- Builds BAYAN TOWN HALL and its plaza, at the west end of the city.
--
-- Outside: white columns, front steps, a big sign, a plaza with a flagpole,
--          trees, benches and lamp posts, the Cleanup Crew dumpster, and the
--          long time clock shed (all Town Hall time clocks in one row).
-- Inside:  the Town Hall Job Center (2 windows, staff spots, NOW SERVING board,
--          waiting benches), the Business Permit Office, the Barangay
--          Clearance kiosk, the Cleanup office with lockers, and the Mayor's office.
-- (The fence, main gate and parking lot are built by CityMap.)
--
-- To use your own art later: put a Model named "TownHall" in Workspace with
-- parts named JobCenterDesk, StaffSpot_1, StaffSpot_2, TimeClockStaff,
-- TimeClockCleanup and Dumpster, plus doors / OPEN sign (see Establishments).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Establishments = require(script.Parent.Establishments)
local MapKit = require(script.Parent.MapKit)

local TownHallMap = {}

-- West end of the city, turned so the front (local +Z) faces the plaza (world +X).
local ORIGIN = CFrame.new(-150, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
local HX, HZ, TOP = 22, 16, 18 -- half width, half depth, wall height

local kit = MapKit.new(ORIGIN)
local box, glass, marker, ball, pillar, surfaceText, label = kit.box, kit.glass, kit.marker, kit.ball, kit.pillar, kit.surfaceText, kit.label

local COLORS = {
	wall = Color3.fromRGB(245, 243, 236),
	trim = Color3.fromRGB(150, 120, 80),
	roof = Color3.fromRGB(150, 60, 50),
	floor = Color3.fromRGB(225, 222, 212),
	plaza = Color3.fromRGB(200, 190, 175),
	stone = Color3.fromRGB(230, 228, 220),
	wood = Color3.fromRGB(120, 80, 50),
	desk = Color3.fromRGB(235, 235, 235),
	blue = Color3.fromRGB(50, 90, 160),
	screen = Color3.fromRGB(25, 40, 70),
	metal = Color3.fromRGB(70, 72, 80),
	orange = Color3.fromRGB(240, 130, 30),
	green = Color3.fromRGB(50, 120, 70),
	gold = Color3.fromRGB(240, 200, 60),
}

local function buildShell(model)
	box(model, "Floor", -HX, 0, -HZ, HX, 0.2, HZ, COLORS.floor, Enum.Material.Marble)
	box(model, "BackWall", -HX, 0, -HZ, HX, TOP, -HZ + 1, COLORS.wall)
	box(model, "LeftWall", -HX, 0, -HZ + 1, -HX + 1, TOP, HZ - 1, COLORS.wall)
	box(model, "RightWall", HX - 1, 0, -HZ + 1, HX, TOP, HZ - 1, COLORS.wall)
	box(model, "Baseboard", -HX + 1, 0.2, -HZ + 1, HX - 1, 0.8, -HZ + 1.1, COLORS.trim)

	-- Front wall: a door in the middle and two tall windows
	local z1, z2 = HZ - 1, HZ
	for _, side in { { -HX, -4, -18, -10 }, { 4, HX, 10, 18 } } do
		local x1, x2, wx1, wx2 = side[1], side[2], side[3], side[4]
		box(model, "Wall", x1, 0, z1, x2, 4, z2, COLORS.wall)
		box(model, "Wall", x1, 12, z1, x2, TOP, z2, COLORS.wall)
		box(model, "Wall", x1, 4, z1, wx1, 12, z2, COLORS.wall)
		box(model, "Wall", wx2, 4, z1, x2, 12, z2, COLORS.wall)
		glass(model, "Window", wx1, 4, z1 + 0.4, wx2, 12, z2 - 0.4)
		box(model, "WindowFrame", wx1 - 0.3, 3.6, z2, wx2 + 0.3, 4, z2 + 0.4, COLORS.trim)
		box(model, "WindowFrame", wx1 - 0.3, 12, z2, wx2 + 0.3, 12.4, z2 + 0.4, COLORS.trim)
	end
	box(model, "AboveDoor", -4, 10, z1, 4, TOP, z2, COLORS.wall)

	-- Sliding doors (Establishments opens and closes them)
	for _, side in { { "DoorLeft", -4, 0, -4 }, { "DoorRight", 0, 4, 4 } } do
		local door = box(model, side[1], side[2], 0.2, HZ - 0.7, side[3], 10, HZ - 0.3, COLORS.wood, Enum.Material.Wood)
		door:SetAttribute("OpenOffsetX", side[4])
	end
	local openBoard = box(model, "OpenSignBoard", 5, 6, HZ, 8.5, 7.6, HZ + 0.25, COLORS.metal)
	surfaceText(openBoard, Enum.NormalId.Back, "OPEN", Color3.new(1, 1, 1)).Name = "OpenSignText"

	-- Roof, portico with columns, and the sign
	box(model, "Roof", -HX - 1, TOP, -HZ - 1, HX + 1, TOP + 1.2, HZ + 1, COLORS.roof, Enum.Material.Slate)
	box(model, "Portico", -14, 15, HZ, 14, 16.2, HZ + 6, COLORS.stone)
	for _, x in { -12, -6, 6, 12 } do
		pillar(model, "Column", x, HZ + 5, 0.4, 15, 1.6, COLORS.stone, Enum.Material.Marble)
	end
	local sign = box(model, "Sign", -11, 16.2, HZ + 5.5, 11, 18.6, HZ + 6, COLORS.stone)
	surfaceText(sign, Enum.NormalId.Back, "BAYAN TOWN HALL", COLORS.blue)
	-- Front steps (flat, easy to walk on)
	box(model, "Step", -14, 0, HZ, 14, 0.2, HZ + 6, COLORS.stone, Enum.Material.Marble)
	box(model, "Step", -12, 0, HZ + 6, 12, 0.1, HZ + 7.5, COLORS.stone, Enum.Material.Marble)
end

local function buildJobCenter(model)
	-- Desk on the left side, facing the waiting benches
	box(model, "JobDesk", -18, 0.2, -8, -6, 3.4, -6, COLORS.desk)
	box(model, "JobDeskTop", -18.2, 3.4, -8.2, -5.8, 3.6, -5.8, COLORS.blue)
	local staffSpots = {}
	for n, x in { -15, -9 } do
		box(model, "Monitor", x - 1.4, 3.6, -7.7, x + 1.4, 5.6, -7.5, COLORS.screen)
		box(model, "MonitorStand", x - 0.3, 3.6, -7.9, x + 0.3, 4, -7.3, COLORS.metal)
		box(model, "StaffChair", x - 1, 1.6, -11, x + 1, 1.9, -9.5, COLORS.blue)
		box(model, "StaffChairBack", x - 1, 1.9, -11.3, x + 1, 4.2, -11, COLORS.blue)
		if n <= Config.JobCenter.windows then
			local windowSign = box(model, "WindowSign", x - 1.5, 6, -8.3, x + 1.5, 7, -8, Color3.new(1, 1, 1))
			surfaceText(windowSign, Enum.NormalId.Back, ("WINDOW %d"):format(n), COLORS.blue)
			staffSpots[n] = marker(model, "StaffSpot_" .. n, x - 1.5, 0.2, -9.4, x + 1.5, 4, -9)
		end
	end
	local board = box(model, "QueueBoard", -18, 7.5, -8.3, -6, 10, -8, COLORS.screen)
	surfaceText(board, Enum.NormalId.Back, "NOW SERVING", Color3.fromRGB(255, 220, 90)).Name = "QueueText"
	local sign = box(model, "JobCenterSign", -18, 10.5, -8.3, -6, 13, -8, COLORS.blue)
	surfaceText(sign, Enum.NormalId.Back, "💼 TOWN HALL JOB CENTER", Color3.new(1, 1, 1))
	local desk = marker(model, "JobCenterDesk", -18, 0.2, -5.8, -6, 4, -5.4)
	label(desk, "Apply for a Job", 1)

	-- Waiting benches facing the desk
	for _, z in { 0, 5 } do
		for _, x in { -16, -9 } do
			kit.bench(model, x, 0.2, z, 0)
		end
	end
	return staffSpots
end

-- Business Permit Office (BPLO): 1 window on the right side, benches, and the
-- Barangay Clearance kiosk near the door.
local function buildPermitOffice(model)
	box(model, "BploDesk", 8, 0.2, -2, 18, 3.4, 0, COLORS.desk)
	box(model, "BploDeskTop", 7.8, 3.4, -2.2, 18.2, 3.6, 0.2, COLORS.gold)
	box(model, "BploMonitor", 11.6, 3.6, -1.7, 14.4, 5.6, -1.5, COLORS.screen)
	box(model, "BploChair", 12, 1.6, -5.5, 14, 1.9, -4, COLORS.blue)
	box(model, "BploChairBack", 12, 1.9, -5.8, 14, 4.2, -5.5, COLORS.blue)
	local board = box(model, "BploQueueBoard", 8, 6.2, -2.3, 18, 8.8, -2, COLORS.screen)
	surfaceText(board, Enum.NormalId.Back, "NOW SERVING", Color3.fromRGB(255, 220, 90)).Name = "BploQueueText"
	local sign = box(model, "BploSign", 8, 9.3, -2.3, 18, 11.8, -2, COLORS.gold)
	surfaceText(sign, Enum.NormalId.Back, "🧾 BUSINESS PERMIT OFFICE", COLORS.wood)
	local staffSpot = marker(model, "BploStaffSpot", 11.5, 0.2, -3.6, 14.5, 4, -3.2)
	local desk = marker(model, "BploDeskSpot", 8, 0.2, 0.2, 18, 4, 0.6)
	label(desk, "Business Permit (BPLO)", 1)
	for _, z in { 6, 10 } do
		for _, x in { 11, 17 } do
			kit.bench(model, x, 0.2, z, 0)
		end
	end

	-- Barangay Clearance kiosk, just inside the door on the right
	local kiosk = box(model, "ClearanceKiosk", 4.6, 0.2, 10, 6.6, 5, 11.5, COLORS.metal, Enum.Material.Metal)
	local screen = box(model, "ClearanceScreen", 4.8, 2.8, 11.5, 6.4, 4.4, 11.7, COLORS.screen)
	surfaceText(screen, Enum.NormalId.Back, "BARANGAY\nCLEARANCE", Color3.new(1, 1, 1)) -- faces the door
	label(kiosk, "Barangay Clearance")
	return { jobDesk = desk, staffSpots = { staffSpot } }, kiosk
end

-- The time clock shed: a long covered shed along the outside of the left wall,
-- with every Town Hall time clock in one row and a rail so workers line up.
-- (Entrance at the plaza end; the far clocks are for future jobs.)
local function buildClockShed(model)
	local x1, x2, z1, z2 = -27.6, -HX, -12, 14 -- outside the left wall
	box(model, "ShedFloor", x1, 0, z1, x2, 0.2, z2, COLORS.stone, Enum.Material.Concrete)
	for z = z1 + 0.5, z2, 6.4 do
		pillar(model, "ShedPost", x1 + 0.3, z, 0.2, 9, 0.5, COLORS.metal, Enum.Material.Metal)
	end
	box(model, "ShedRoof", x1 - 0.8, 9, z1 - 0.8, x2, 9.4, z2 + 0.8, COLORS.blue, Enum.Material.Metal)
	local sign = box(model, "ShedSign", x1, 9.5, z2 + 0.5, x2, 11.6, z2 + 0.8, COLORS.blue)
	surfaceText(sign, Enum.NormalId.Back, "🕐 TIME CLOCK SHED", Color3.new(1, 1, 1))
	local floorSign = box(model, "LineUpHere", x2 - 3, 0.2, z2 - 2.2, x2 - 0.4, 0.22, z2 - 0.4, COLORS.gold)
	surfaceText(floorSign, Enum.NormalId.Top, "LINE UP ↓", COLORS.wood)

	-- The time clocks, in a row on the wall. Only Staff and Cleanup work for now.
	local clocks = {}
	local row = {
		{ "TimeClockStaff", 8, "Time Clock: Staff", COLORS.blue },
		{ "TimeClockCleanup", 2, "Time Clock: Cleanup", COLORS.orange },
		{ "TimeClockSpare1", -4, "Time Clock: (coming soon)", Color3.fromRGB(150, 150, 150) },
		{ "TimeClockSpare2", -10, "Time Clock: (coming soon)", Color3.fromRGB(150, 150, 150) },
	}
	for _, info in row do
		local name, z, text, color = info[1], info[2], info[3], info[4]
		local clock = box(model, name, x2 - 0.6, 3.5, z - 0.8, x2, 6.5, z + 0.8, COLORS.metal, Enum.Material.Metal)
		box(model, "ClockFace", x2 - 0.65, 5.2, z - 0.5, x2 - 0.6, 6.2, z + 0.5, Color3.new(1, 1, 1))
		box(model, "ClockStripe", x2 - 0.62, 3.6, z - 0.8, x2 - 0.58, 4, z + 0.8, color)
		box(model, "CardRack", x2 - 0.3, 3, z + 1, x2, 6.5, z + 2.2, COLORS.wood, Enum.Material.Wood)
		label(clock, text)
		clocks[name] = clock
	end

	-- A rail along the shed, so workers line up between the rail and the wall
	box(model, "LineRail", x2 - 3.3, 2.2, z1 + 1, x2 - 3.1, 2.45, z2 - 1, COLORS.gold, Enum.Material.Metal)
	for z = z1 + 1, z2 - 1, 4 do
		box(model, "RailPost", x2 - 3.3, 0.2, z - 0.1, x2 - 3.1, 2.45, z + 0.1, COLORS.gold, Enum.Material.Metal)
	end
	for _, z in { -6, 2, 10 } do
		box(model, "ShedLamp", x2 - 3, 8.6, z - 0.6, x2 - 1.8, 9, z + 0.6, Color3.fromRGB(255, 242, 215), Enum.Material.Neon)
	end
	return clocks
end

local function buildOffices(model)
	-- Cleanup office: orange lockers and a notice board
	for i = 0, 5 do
		local x = 8 + i * 2
		box(model, "Locker", x, 0.2, -HZ + 1, x + 1.9, 7, -HZ + 2.6, COLORS.orange, Enum.Material.Metal)
	end
	local notice = box(model, "NoticeBoard", 8, 8, -HZ + 1, 19.8, 12, -HZ + 1.2, COLORS.green)
	surfaceText(notice, Enum.NormalId.Back, "🧹 KEEP BAYAN CLEAN!\nCleanup Crew: pick up litter,\nempty bags at the dumpster.", Color3.new(1, 1, 1))

	-- Mayor's office door at the back
	box(model, "MayorDoor", -3, 0.2, -HZ + 1, 3, 10, -HZ + 1.3, COLORS.wood, Enum.Material.Wood)
	local mayorSign = box(model, "MayorSign", -3, 10.5, -HZ + 1, 3, 12, -HZ + 1.3, COLORS.gold)
	surfaceText(mayorSign, Enum.NormalId.Back, "MAYOR'S OFFICE", COLORS.wood)

	-- Plants and lights
	for _, spot in { { -19, 13 }, { 19, 13 }, { 6, -4 } } do
		box(model, "Pot", spot[1] - 1, 0.2, spot[2] - 1, spot[1] + 1, 2, spot[2] + 1, Color3.fromRGB(170, 100, 60))
		ball(model, "Plant", 3, spot[1], 3.2, spot[2], Color3.fromRGB(70, 150, 80), Enum.Material.Grass)
	end
	for _, x in { -12, 0, 12 } do
		for _, z in { -6, 6 } do
			kit.lamp(model, x, TOP - 0.01, z)
		end
	end
end

local function buildPlaza(model)
	-- Plaza tiles and the path to the spawn point
	box(model, "Plaza", -24, 0, HZ + 7.5, 24, 0.15, HZ + 30, COLORS.plaza, Enum.Material.Brick)
	box(model, "PlazaBorder", -24, 0, HZ + 30, 24, 0.25, HZ + 31, COLORS.stone, Enum.Material.Marble)
	box(model, "Path", -4, 0, HZ + 31, 4, 0.1, 66, Color3.fromRGB(190, 190, 185), Enum.Material.Concrete)

	-- Flagpole with the town flag in the middle
	local fz = HZ + 18
	box(model, "FlagBase", -2, 0, fz - 2, 2, 1, fz + 2, COLORS.stone, Enum.Material.Marble)
	pillar(model, "FlagPole", 0, fz, 1, 20, 0.35, Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
	local flag = box(model, "Flag", 0.2, 15.5, fz - 0.05, 6.2, 19.5, fz + 0.05, COLORS.green, Enum.Material.Fabric)
	surfaceText(flag, Enum.NormalId.Back, "☀ BAYAN", COLORS.gold)
	surfaceText(flag, Enum.NormalId.Front, "☀ BAYAN", COLORS.gold)

	-- Trees, benches and lamp posts around the plaza
	for _, x in { -20, 20 } do
		for _, z in { HZ + 11, HZ + 26 } do
			kit.tree(model, x, z, 1)
		end
	end
	kit.bench(model, -10, 0.15, HZ + 12, math.pi) -- facing the flag
	kit.bench(model, 10, 0.15, HZ + 12, math.pi)
	kit.bench(model, -10, 0.15, HZ + 25, 0)
	kit.bench(model, 10, 0.15, HZ + 25, 0)
	for _, x in { -14, 14 } do
		kit.lampPost(model, x, HZ + 18)
	end

	-- Cleanup Crew dumpster, to the right of the building
	box(model, "DumpsterBody", HX + 3, 0, 4, HX + 8, 4, 8, COLORS.green, Enum.Material.Metal)
	box(model, "DumpsterLid", HX + 2.8, 4, 3.8, HX + 8.2, 4.4, 8.2, Color3.fromRGB(40, 90, 55), Enum.Material.Metal)
	local dumpster = marker(model, "Dumpster", HX + 2.5, 0, 3.5, HX + 8.5, 5, 8.5)
	label(dumpster, "Dumpster (Cleanup Crew)", 0.5)
	return dumpster
end

local function build()
	local model = Instance.new("Model")
	model.Name = "TownHall"
	buildShell(model)
	buildJobCenter(model)
	buildPermitOffice(model)
	buildOffices(model)
	buildClockShed(model)
	buildPlaza(model)
	model.Parent = workspace
	return model
end

-- Returns the Town Hall's parts for the jobs, litter areas and opening hours.
function TownHallMap.getOrBuild()
	local model = workspace:FindFirstChild("TownHall") or build()
	local function find(name)
		local part = model:FindFirstChild(name, true)
		if not part then
			warn(("[TownHallMap] The TownHall model has no part named %q"):format(name))
		end
		return part
	end

	local staffSpots = {}
	for n = 1, Config.JobCenter.windows do
		staffSpots[n] = model:FindFirstChild("StaffSpot_" .. n, true)
	end
	local doors, signs = Establishments.findDoorsAndSigns(model)

	return {
		jobDesk = find("JobCenterDesk"),
		queueText = model:FindFirstChild("QueueText", true),
		staffSpots = staffSpots,
		timeClockStaff = find("TimeClockStaff"),
		timeClockCleanup = find("TimeClockCleanup"),
		dumpster = find("Dumpster"),
		-- Business Permit Office (1 window) and the Barangay Clearance kiosk
		bplo = {
			jobDesk = find("BploDeskSpot"),
			queueText = model:FindFirstChild("BploQueueText", true),
			staffSpots = { model:FindFirstChild("BploStaffSpot", true) },
		},
		clearanceKiosk = find("ClearanceKiosk"),
		-- Where litter appears near the Town Hall: its plaza and path.
		-- (CityMap adds the city's streets and park.)
		litterAreas = {
			kit.area(-22, HZ + 8, 22, HZ + 29),
			kit.area(-3.5, HZ + 32, 3.5, 64),
		},
		establishment = {
			name = "Town Hall",
			origin = ORIGIN,
			halfSize = Vector3.new(HX - 1, TOP / 2, HZ - 1),
			outside = ORIGIN * CFrame.new(0, 0, HZ + 12),
			doors = doors,
			signs = signs,
			closedMessage = ("The Town Hall is closed. Office hours: %d AM to 5 PM."):format(Config.TownHall.openHour),
		},
	}
end

return TownHallMap
