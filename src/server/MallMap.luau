-- Builds BAYAN MALL: a 2-floor mall at the north end of the city.
--
-- 1st floor: glass entrance with sliding doors, a big atrium with a skylight,
--            a grand staircase, the mall directory, the Job Center with a
--            waiting area (benches you can sit on) and a job board screen,
--            and a food court that is coming soon.
-- 2nd floor: a row of uniform stalls, one per job (Config.JobOrder). Open jobs
--            have a counter, a mannequin and a rack; coming-soon jobs have
--            their shutters down.
--
-- To use your own art later: put a Model named "Mall" in Workspace with a part
-- named JobCenterDesk, parts named UniformStall_<jobId> (for example
-- UniformStall_baker), and doors / OPEN sign as described in Establishments.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Establishments = require(script.Parent.Establishments)

local MallMap = {}

-- Turned 180°, so the mall's front (local +Z) faces the spawn point.
-- North end of the city.
local ORIGIN = CFrame.new(0, 0, 170) * CFrame.Angles(0, math.pi, 0)
local HALF_X, HALF_Z = 40, 24 -- outside size: 80 x 48 studs
local FLOOR2 = 16 -- 2nd floor slab bottom (top is FLOOR2 + 1)
local TOP = 32 -- roof bottom

local COLORS = {
	wall = Color3.fromRGB(236, 240, 246),
	trim = Color3.fromRGB(60, 95, 160),
	roof = Color3.fromRGB(95, 100, 115),
	floor = Color3.fromRGB(230, 228, 222),
	floor2 = Color3.fromRGB(215, 210, 200),
	glass = Color3.fromRGB(175, 215, 235),
	path = Color3.fromRGB(190, 190, 185),
	wood = Color3.fromRGB(150, 100, 60),
	darkWood = Color3.fromRGB(105, 65, 40),
	white = Color3.fromRGB(250, 250, 250),
	metal = Color3.fromRGB(150, 155, 165),
	darkMetal = Color3.fromRGB(70, 72, 80),
	screen = Color3.fromRGB(25, 40, 70),
	green = Color3.fromRGB(70, 150, 80),
	pot = Color3.fromRGB(170, 100, 60),
	lamp = Color3.fromRGB(255, 242, 215),
	shutter = Color3.fromRGB(160, 165, 170),
	skin = Color3.fromRGB(210, 200, 190),
	accentOpen = Color3.fromRGB(245, 150, 60),
	accentSoon = Color3.fromRGB(120, 130, 150),
}

------------------------------------------------------------------------
-- Building helpers (all positions are measured from the mall's origin)
------------------------------------------------------------------------

-- An anchored block between two corners.
local function box(parent, name, x1, y1, z1, x2, y2, z2, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
	part.CFrame = ORIGIN * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function glassBox(parent, name, x1, y1, z1, x2, y2, z2, transparency)
	local part = box(parent, name, x1, y1, z1, x2, y2, z2, COLORS.glass, Enum.Material.Glass)
	part.Transparency = transparency or 0.5
	return part
end

local function marker(parent, name, x1, y1, z1, x2, y2, z2)
	local part = box(parent, name, x1, y1, z1, x2, y2, z2, COLORS.white)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function ball(parent, name, size, x, y, z, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = ORIGIN * CFrame.new(x, y, z)
	part.Parent = parent
	return part
end

-- Text on one face of a part (signs, boards, screens). Returns the TextLabel.
local function surfaceText(part, face, text, color, background)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new()
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
	return label
end

local function addLabel(part, text, extraHeight)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5 + (extraHeight or 0), 0)
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = part
end

local function lamp(parent, x, y, z)
	local part = box(parent, "Lamp", x - 1.2, y - 0.4, z - 1.2, x + 1.2, y, z + 1.2, COLORS.lamp, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 0.6
	light.Color = COLORS.lamp
	light.Parent = part
end

local function plant(parent, x, y, z)
	box(parent, "Pot", x - 1, y, z - 1, x + 1, y + 1.8, z + 1, COLORS.pot)
	ball(parent, "Plant", 3, x, y + 3, z, COLORS.green, Enum.Material.Grass)
end

-- A bench players can sit on. angle turns it; the sitter faces the bench's front (-Z).
local function bench(parent, x, y, z, angle)
	local base = ORIGIN * CFrame.new(x, y, z) * CFrame.Angles(0, angle, 0)
	local function piece(className, name, size, offset, color, material)
		local part = Instance.new(className)
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.Color = color
		part.Material = material
		part.CFrame = base * offset
		part.Parent = parent
	end
	piece("Seat", "BenchSeat", Vector3.new(6, 0.4, 1.6), CFrame.new(0, 1.9, 0), COLORS.wood, Enum.Material.Wood)
	piece("Part", "BenchBack", Vector3.new(6, 1.8, 0.25), CFrame.new(0, 3, 0.75), COLORS.wood, Enum.Material.Wood)
	piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(-2.6, 0.95, 0), COLORS.darkMetal, Enum.Material.Metal)
	piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(2.6, 0.95, 0), COLORS.darkMetal, Enum.Material.Metal)
end

------------------------------------------------------------------------
-- Parts of the mall
------------------------------------------------------------------------

local function buildShell(model)
	-- Floors and the path to the spawn point
	box(model, "Floor", -HALF_X, 0, -HALF_Z, HALF_X, 0.2, HALF_Z, COLORS.floor, Enum.Material.Marble)
	box(model, "FloorInlay", -8, 0.2, 14, 8, 0.25, 22, COLORS.trim, Enum.Material.Marble)
	box(model, "Path", -5, 0, HALF_Z, 5, 0.1, HALF_Z + 34, COLORS.path, Enum.Material.Concrete)

	-- Back and side walls
	box(model, "BackWall", -HALF_X, 0, -HALF_Z, HALF_X, TOP, -HALF_Z + 1, COLORS.wall)
	box(model, "LeftWall", -HALF_X, 0, -HALF_Z + 1, -HALF_X + 1, TOP, HALF_Z - 1, COLORS.wall)
	box(model, "RightWall", HALF_X - 1, 0, -HALF_Z + 1, HALF_X, TOP, HALF_Z - 1, COLORS.wall)

	-- Glass front with a blue frame, and a wide door gap in the middle
	local z1, z2 = HALF_Z - 1, HALF_Z
	for _, side in { { -HALF_X, -5 }, { 5, HALF_X } } do
		local x1, x2 = side[1], side[2]
		box(model, "FrontBase", x1, 0, z1, x2, 1.5, z2, COLORS.trim)
		glassBox(model, "FrontGlass", x1, 1.5, z1 + 0.4, x2, 15, z2 - 0.4)
		box(model, "FrontBand", x1, 15, z1, x2, 17, z2, COLORS.trim)
		glassBox(model, "FrontGlass", x1, 17, z1 + 0.4, x2, TOP - 1, z2 - 0.4)
		for x = x1 + 0.5, x2 - 1, 7 do -- window frames (none in the door gap)
			box(model, "Mullion", x - 0.25, 1.5, z1 + 0.2, x + 0.25, TOP - 1, z2 - 0.2, COLORS.trim)
		end
	end
	box(model, "AboveDoor", -5, 10, z1, 5, 15, z2, COLORS.trim)
	box(model, "FrontBand", -5, 15, z1, 5, 17, z2, COLORS.trim)
	glassBox(model, "FrontGlass", -5, 17, z1 + 0.4, 5, TOP - 1, z2 - 0.4)
	box(model, "FrontTop", -HALF_X, TOP - 1, z1, HALF_X, TOP, z2, COLORS.trim)

	-- Sliding glass doors (Establishments opens and closes them)
	for _, side in { { "DoorLeft", -5, 0, -5 }, { "DoorRight", 0, 5, 5 } } do
		local door = glassBox(model, side[1], side[2], 0.2, HALF_Z - 0.7, side[3], 10, HALF_Z - 0.3, 0.35)
		door:SetAttribute("OpenOffsetX", side[4])
	end

	-- Big sign and OPEN / CLOSED sign
	local sign = box(model, "Sign", -14, 19, HALF_Z, 14, 25, HALF_Z + 0.6, COLORS.trim)
	surfaceText(sign, Enum.NormalId.Back, "BAYAN MALL", COLORS.white)
	local openBoard = box(model, "OpenSignBoard", 6, 6.5, HALF_Z, 10, 8.5, HALF_Z + 0.25, COLORS.darkMetal)
	surfaceText(openBoard, Enum.NormalId.Back, "OPEN", COLORS.white).Name = "OpenSignText"

	-- Roof with a glass skylight over the atrium
	box(model, "Roof", -HALF_X - 1, TOP, -HALF_Z - 1, HALF_X + 1, TOP + 1, -4, COLORS.roof, Enum.Material.Slate)
	box(model, "Roof", -HALF_X - 1, TOP, 18, HALF_X + 1, TOP + 1, HALF_Z + 1, COLORS.roof, Enum.Material.Slate)
	box(model, "Roof", -HALF_X - 1, TOP, -4, -16, TOP + 1, 18, COLORS.roof, Enum.Material.Slate)
	box(model, "Roof", 16, TOP, -4, HALF_X + 1, TOP + 1, 18, COLORS.roof, Enum.Material.Slate)
	glassBox(model, "Skylight", -16, TOP + 0.3, -4, 16, TOP + 0.7, 18, 0.4)
end

local function buildSecondFloor(model)
	-- The 2nd floor covers the back half; the front half is a tall atrium.
	box(model, "Floor2", -HALF_X + 1, FLOOR2, -HALF_Z + 1, HALF_X - 1, FLOOR2 + 1, -4, COLORS.floor2, Enum.Material.Marble)
	box(model, "Floor2Edge", -HALF_X + 1, FLOOR2, -4, HALF_X - 1, FLOOR2 + 1, -3.6, COLORS.trim)

	-- Glass railing along the edge, with a gap for the stairs
	for _, side in { { -HALF_X + 1, -5 }, { 5, HALF_X - 1 } } do
		glassBox(model, "Railing", side[1], FLOOR2 + 1, -4.3, side[2], FLOOR2 + 4, -4.1, 0.55)
		box(model, "RailTop", side[1], FLOOR2 + 4, -4.4, side[2], FLOOR2 + 4.3, -4, COLORS.metal, Enum.Material.Metal)
	end

	-- Grand staircase from the entrance side up to the 2nd floor
	local steps = 16
	local rise = (FLOOR2 + 1) / steps
	for i = 1, steps do
		local zBack, zFront = 12 - i, 13 - i
		box(model, "Step", -5, 0, zBack, 5, i * rise, zFront, COLORS.floor2, Enum.Material.Marble)
		for _, x in { -5.3, 5 } do
			glassBox(model, "StairRail", x, i * rise, zBack, x + 0.3, i * rise + 3, zFront, 0.55)
		end
	end
	box(model, "StairSign", -3, 0.2, 13.2, 3, 2.4, 13.6, COLORS.trim)
	surfaceText(model:FindFirstChild("StairSign"), Enum.NormalId.Back, "2F: UNIFORMS", COLORS.white)
end

-- What each job's mannequin wears: body color, top color, hat color (nil = none),
-- hat style, and the color of the clothes on the rack.
local OUTFITS = {
	baker = { top = Color3.fromRGB(250, 250, 250), hat = Color3.fromRGB(250, 250, 250), hatStyle = "chef", rack = Color3.fromRGB(250, 250, 250) },
	staff = { top = Color3.fromRGB(60, 100, 180), lanyard = true, rack = Color3.fromRGB(60, 100, 180) },
	cleanup = { top = Color3.fromRGB(255, 130, 20), hat = Color3.fromRGB(255, 130, 20), hatStyle = "cap", stripe = true, rack = Color3.fromRGB(255, 130, 20) },
}
local DEFAULT_OUTFIT = { top = Color3.fromRGB(200, 200, 200), rack = Color3.fromRGB(200, 200, 200) }

local STALL_HALF = 6 -- stalls are 12 studs wide

-- One uniform stall on the 2nd floor. Returns its prompt marker (open jobs only).
local function buildStall(model, jobId, job, cx)
	local y = FLOOR2 + 1
	local z1, z2 = -HALF_Z + 1, -14 -- back to front
	local w = STALL_HALF
	local open = not job.comingSoon
	local accent = if open then COLORS.accentOpen else COLORS.accentSoon

	box(model, "StallBack", cx - w, y, z1, cx + w, y + 10, z1 + 0.3, accent)
	box(model, "StallWall", cx - w, y, z1, cx - w + 0.3, y + 10, z2, COLORS.wall)
	box(model, "StallWall", cx + w - 0.3, y, z1, cx + w, y + 10, z2, COLORS.wall)
	local header = box(model, "StallSign", cx - w, y + 8, z2 - 0.3, cx + w, y + 10.5, z2, accent)
	surfaceText(header, Enum.NormalId.Back, ("%s %s"):format(job.icon, string.upper(job.uniform.name .. "S")), COLORS.white)

	if not open then
		local shutter = box(model, "Shutter", cx - w + 0.3, y, z2 - 0.25, cx + w - 0.3, y + 8, z2 - 0.05, COLORS.shutter, Enum.Material.DiamondPlate)
		surfaceText(shutter, Enum.NormalId.Back, "COMING SOON", COLORS.darkMetal)
		return nil
	end

	-- Counter
	box(model, "StallCounter", cx - 4.5, y, z2 - 2.2, cx + 4.5, y + 3.4, z2 - 1, COLORS.wood, Enum.Material.Wood)
	box(model, "CounterTop", cx - 4.7, y + 3.4, z2 - 2.4, cx + 4.7, y + 3.6, z2 - 0.8, COLORS.darkWood, Enum.Material.Wood)

	-- A mannequin wearing this job's uniform
	local outfit = OUTFITS[jobId] or DEFAULT_OUTFIT
	local mx, mz = cx - 3, z1 + 3
	box(model, "MannequinStand", mx - 0.3, y, mz - 0.6, mx + 0.3, y + 2.6, mz + 0.6, COLORS.darkMetal, Enum.Material.Metal)
	box(model, "MannequinBody", mx - 1, y + 2.6, mz - 0.5, mx + 1, y + 5.4, mz + 0.5, COLORS.skin)
	ball(model, "MannequinHead", 1.3, mx, y + 6.1, mz, COLORS.skin)
	box(model, "MannequinTop", mx - 1.05, y + 3, mz - 0.55, mx + 1.05, y + 5.3, mz + 0.6, outfit.top, Enum.Material.Fabric)
	if outfit.stripe then
		box(model, "MannequinStripe", mx - 1.08, y + 3.7, mz + 0.6, mx + 1.08, y + 3.9, mz + 0.65, Color3.fromRGB(230, 230, 210), Enum.Material.Neon)
	end
	if outfit.lanyard then
		box(model, "MannequinLanyard", mx - 0.06, y + 4.3, mz + 0.6, mx + 0.06, y + 5.3, mz + 0.65, Color3.fromRGB(200, 40, 40))
		box(model, "MannequinIdCard", mx - 0.25, y + 3.7, mz + 0.62, mx + 0.25, y + 4.35, mz + 0.67, COLORS.white)
	end
	if outfit.hatStyle == "chef" then
		box(model, "MannequinHatBand", mx - 0.6, y + 6.7, mz - 0.6, mx + 0.6, y + 7.2, mz + 0.6, outfit.hat, Enum.Material.Fabric)
		ball(model, "MannequinHat", 1.5, mx, y + 7.7, mz, outfit.hat, Enum.Material.Fabric)
	elseif outfit.hatStyle == "cap" then
		box(model, "MannequinCap", mx - 0.65, y + 6.6, mz - 0.65, mx + 0.65, y + 7, mz + 0.65, outfit.hat, Enum.Material.Fabric)
		box(model, "MannequinCapBrim", mx - 0.55, y + 6.6, mz + 0.65, mx + 0.55, y + 6.7, mz + 1.2, outfit.hat, Enum.Material.Fabric)
	end

	-- A rack of the same uniform
	box(model, "RackBar", cx + 0.5, y + 6, mz - 0.1, cx + 5.2, y + 6.3, mz + 0.1, COLORS.metal, Enum.Material.Metal)
	box(model, "RackPost", cx + 0.5, y, mz - 0.1, cx + 0.8, y + 6.3, mz + 0.1, COLORS.metal, Enum.Material.Metal)
	box(model, "RackPost", cx + 4.9, y, mz - 0.1, cx + 5.2, y + 6.3, mz + 0.1, COLORS.metal, Enum.Material.Metal)
	for x = cx + 1.6, cx + 4.4, 1.4 do
		box(model, "HangingUniform", x - 0.6, y + 3.2, mz + 0.15, x + 0.6, y + 5.9, mz + 0.25, outfit.rack, Enum.Material.Fabric)
	end

	local prompt = marker(model, "UniformStall_" .. jobId, cx - 4.5, y, z2 - 0.8, cx + 4.5, y + 4, z2 - 0.4)
	addLabel(prompt, ("%s - %d coins"):format(job.uniform.name, job.uniform.price), 1.5)
	return prompt
end

local function buildJobCenter(model)
	-- Desk under the 2nd floor, on the right
	box(model, "JobDesk", 20, 0.2, -14, 32, 3.4, -12, COLORS.white)
	box(model, "JobDeskTop", 19.8, 3.4, -14.2, 32.2, 3.6, -11.8, COLORS.trim)
	for _, x in { 23, 29 } do
		box(model, "Monitor", x - 1.4, 3.6, -13.7, x + 1.4, 5.6, -13.5, COLORS.screen)
		box(model, "MonitorStand", x - 0.3, 3.6, -13.9, x + 0.3, 4, -13.3, COLORS.darkMetal)
		box(model, "StaffChair", x - 1, 1.6, -17, x + 1, 1.9, -15, COLORS.trim)
		box(model, "StaffChairBack", x - 1, 1.9, -17.3, x + 1, 4.2, -17, COLORS.trim)
	end
	local sign = box(model, "JobCenterSign", 20, 11, -14.3, 32, 13.5, -14, COLORS.trim)
	surfaceText(sign, Enum.NormalId.Back, "💼 JOB CENTER", COLORS.white)

	-- Service window numbers over the computers (one window per computer)
	for n, x in { 23, 29 } do
		if n <= Config.JobCenter.windows then
			local windowSign = box(model, "WindowSign", x - 1.5, 6, -14.3, x + 1.5, 7, -14, COLORS.white)
			surfaceText(windowSign, Enum.NormalId.Back, ("WINDOW %d"):format(n), COLORS.trim)
			-- Where Application Staff stand to take this window
			marker(model, "StaffSpot_" .. n, x - 1.5, 0.2, -15.4, x + 1.5, 4, -15)
		end
	end

	-- NOW SERVING board (JobCenter updates the text)
	local board = box(model, "QueueBoard", 20, 7.5, -14.3, 32, 10.5, -14, COLORS.screen)
	local queueText = surfaceText(board, Enum.NormalId.Back, "NOW SERVING", Color3.fromRGB(255, 220, 90))
	queueText.Name = "QueueText"
	local desk = marker(model, "JobCenterDesk", 20, 0.2, -11.8, 32, 4, -11.4)
	addLabel(desk, "Apply for a Job", 1)

	-- Waiting area: two rows of benches facing the desk
	for _, z in { -4, 1 } do
		for _, x in { 20, 26, 32 } do
			bench(model, x, 0.2, z, 0)
		end
	end
	plant(model, 37, 0.2, -2)
	plant(model, 15, 0.2, -2)

	-- Job board screen on the right wall
	local lines = { "NOW HIRING" }
	for _, jobId in Config.JobOrder do
		local job = Config.Jobs[jobId]
		table.insert(lines, ("%s %s - %s"):format(job.icon, job.name, if job.comingSoon then "soon" else "OPEN"))
	end
	local screen = box(model, "JobBoard", HALF_X - 1.2, 4, -4, HALF_X - 1, 11, 8, COLORS.screen)
	local text = surfaceText(screen, Enum.NormalId.Left, table.concat(lines, "\n"), COLORS.white)
	text.TextXAlignment = Enum.TextXAlignment.Left
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 30)
	padding.Parent = text
end

local function buildGroundFloorExtras(model)
	-- Mall directory near the entrance
	box(model, "DirectoryStand", -12.3, 0.2, 16.8, -11.7, 1.5, 17.4, COLORS.darkMetal, Enum.Material.Metal)
	local directory = box(model, "Directory", -15, 1.5, 16.9, -9, 8, 17.3, COLORS.screen)
	local text = surfaceText(directory, Enum.NormalId.Back, "MALL DIRECTORY\n\n1F  Job Center (right)\n1F  Food Court (soon)\n2F  Uniform Stalls\n     (take the stairs)", COLORS.white)
	text.TextXAlignment = Enum.TextXAlignment.Left

	-- Food court along the left wall (coming soon)
	for _, x1 in { -HALF_X + 1, -26 } do
		local x2 = x1 + 12
		box(model, "FoodStall", x1, 0.2, -HALF_Z + 1, x2, 10, -HALF_Z + 1.3, COLORS.accentSoon)
		local shutter = box(model, "Shutter", x1 + 0.3, 0.2, -16.3, x2 - 0.3, 8, -16, COLORS.shutter, Enum.Material.DiamondPlate)
		surfaceText(shutter, Enum.NormalId.Back, "FOOD COURT\nCOMING SOON", COLORS.darkMetal)
		box(model, "FoodStallWall", x1, 0.2, -HALF_Z + 1, x1 + 0.3, 10, -16, COLORS.wall)
		box(model, "FoodStallWall", x2 - 0.3, 0.2, -HALF_Z + 1, x2, 10, -16, COLORS.wall)
		box(model, "FoodStallTop", x1, 8, -16.3, x2, 10, -16, COLORS.accentSoon)
	end
	-- A few tables in front of the food court
	for _, x in { -34, -26, -18 } do
		box(model, "TableLeg", x - 0.3, 0.2, -8.3, x + 0.3, 2.8, -7.7, COLORS.darkMetal, Enum.Material.Metal)
		box(model, "TableTop", x - 1.8, 2.8, -9.8, x + 1.8, 3, -6.2, COLORS.white)
	end

	-- Plants around the atrium and entrance
	for _, spot in { { -36, 20 }, { 36, 20 }, { -10, 6 }, { 10, 6 } } do
		plant(model, spot[1], 0.2, spot[2])
	end
	plant(model, -36, FLOOR2 + 1, -6.5)
	plant(model, 36, FLOOR2 + 1, -6.5)

	-- Benches in the atrium, facing the stairs
	bench(model, -20, 0.2, 10, -math.pi / 2)
	bench(model, 20, 0.2, 10, math.pi / 2)
end

local function buildLights(model)
	for _, x in { -30, -15, 15, 30 } do
		for _, z in { -18, -9 } do
			lamp(model, x, FLOOR2 - 0.01, z) -- under the 2nd floor
		end
	end
	for _, x in { -28, 0, 28 } do
		lamp(model, x, TOP - 0.01, -14) -- 2nd floor
	end
	for _, x in { -28, 28 } do
		lamp(model, x, TOP - 0.01, 8) -- atrium sides (the middle has the skylight)
	end
end

local function build()
	local model = Instance.new("Model")
	model.Name = "Mall"

	buildShell(model)
	buildSecondFloor(model)
	for i, jobId in Config.JobOrder do
		local job = Config.Jobs[jobId]
		buildStall(model, jobId, job, -HALF_X + 1 + STALL_HALF + 0.5 + (i - 1) * (STALL_HALF * 2 + 1))
	end
	buildJobCenter(model)
	buildGroundFloorExtras(model)
	buildLights(model)

	model.Parent = workspace
	return model
end

-- Returns { jobDesk, queueText, staffSpots, stalls = { [jobId] = part }, establishment }.
function MallMap.getOrBuild()
	local model = workspace:FindFirstChild("Mall") or build()

	local stalls = {}
	for jobId in Config.Jobs do
		local part = model:FindFirstChild("UniformStall_" .. jobId, true)
		if part then
			stalls[jobId] = part
		end
	end
	local desk = model:FindFirstChild("JobCenterDesk", true)
	if not desk then
		warn("[MallMap] The Mall model has no part named \"JobCenterDesk\"")
	end

	local doors, signs = Establishments.findDoorsAndSigns(model)

	local staffSpots = {}
	for n = 1, Config.JobCenter.windows do
		staffSpots[n] = model:FindFirstChild("StaffSpot_" .. n, true)
	end

	return {
		jobDesk = desk,
		queueText = model:FindFirstChild("QueueText", true),
		staffSpots = staffSpots,
		stalls = stalls,
		establishment = {
			name = "Mall",
			origin = ORIGIN,
			halfSize = Vector3.new(HALF_X - 1, TOP / 2, HALF_Z - 1),
			outside = ORIGIN * CFrame.new(0, 0, HALF_Z + 8),
			doors = doors,
			signs = signs,
			closedMessage = ("The mall is closed. It opens at %d:00 AM."):format(Config.Mall.openHour),
		},
	}
end

return MallMap
