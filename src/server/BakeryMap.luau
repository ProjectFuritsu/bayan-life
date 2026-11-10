-- Builds the bakery building, or uses your own model.
--
-- To use your own art later: put a Model named "Bakery" in Workspace with parts
-- named TimeClock, ServeSpot (behind the counter), OrderSpot (in front of it),
-- Oven, TrashBin and one or more BreadRack parts.
-- For bread to show, add small invisible parts with a "RackSlot" attribute (1-6)
-- on the shelves and a "CaseSlot" attribute (1-8) inside the glass case.
-- This script then uses your model instead of building this one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Establishments = require(script.Parent.Establishments)
local Atmosphere = require(script.Parent.Atmosphere)

local BakeryMap = {}

-- East of the plaza, right beside the Bayan Public Market (x 96-134): the same
-- front line (z 20), facing the east road (world -Z). The building is x 138-178, z 20-48.
local ORIGIN = CFrame.new(158, 0, 34) * CFrame.Angles(0, math.pi, 0)
local WALL_HEIGHT = 14

local COLORS = {
	wall = Color3.fromRGB(250, 235, 200),
	roof = Color3.fromRGB(190, 90, 60),
	floor = Color3.fromRGB(205, 160, 110),
	wood = Color3.fromRGB(150, 100, 60),
	darkWood = Color3.fromRGB(105, 65, 40),
	brick = Color3.fromRGB(170, 75, 50),
	glass = Color3.fromRGB(180, 220, 240),
	bread = Color3.fromRGB(205, 140, 70),
	metal = Color3.fromRGB(70, 70, 80),
	green = Color3.fromRGB(60, 110, 70),
	path = Color3.fromRGB(190, 190, 185),
	red = Color3.fromRGB(200, 50, 50),
	white = Color3.fromRGB(245, 245, 245),
	fire = Color3.fromRGB(255, 140, 40),
	lamp = Color3.fromRGB(255, 230, 170),
	signText = Color3.fromRGB(255, 220, 120),
}

-- Makes an anchored block between two corners, measured from the bakery's origin.
-- Corners are easier to lay out than center + size.
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

local function addLabel(part, text, extraHeight)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(170, 36) -- in pixels, so it stays small when you stand close
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

local function lamp(parent, x, z)
	local part = box(parent, "Lamp", x - 0.75, WALL_HEIGHT - 0.5, z - 0.75, x + 0.75, WALL_HEIGHT, z + 0.75, COLORS.lamp, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 0.6 -- soft; brighter washes the room out
	light.Color = COLORS.lamp
	light.Parent = part
end

-- A front wall piece (from x1 to x2) with a real window hole and a glass pane.
local function wallWithWindow(parent, x1, x2, wx1, wx2)
	local z1, z2 = 13, 14
	local wy1, wy2 = 4, 9
	box(parent, "Wall", x1, 0, z1, x2, wy1, z2, COLORS.wall) -- below the window
	box(parent, "Wall", x1, wy2, z1, x2, WALL_HEIGHT, z2, COLORS.wall) -- above
	box(parent, "Wall", x1, wy1, z1, wx1, wy2, z2, COLORS.wall) -- left
	box(parent, "Wall", wx2, wy1, z1, x2, wy2, z2, COLORS.wall) -- right
	local glass = box(parent, "Window", wx1, wy1, 13.4, wx2, wy2, 13.6, COLORS.glass, Enum.Material.Glass)
	glass.Transparency = 0.5
	box(parent, "Sill", wx1 - 0.3, wy1 - 0.4, z2, wx2 + 0.3, wy1, z2 + 0.5, COLORS.darkWood, Enum.Material.Wood)
end

-- Text on one face of a part (for signs and boards). Returns the TextLabel.
local function surfaceText(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
	return label
end

local function ball(parent, name, size, x, y, z, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.CFrame = ORIGIN * CFrame.new(x, y, z)
	part.Parent = parent
	return part
end

-- A bench players can sit on. angle turns it; the sitter faces the bench's front.
local function bench(parent, x, z, angle)
	local base = ORIGIN * CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function piece(className, name, size, offset, color)
		local part = Instance.new(className)
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.Color = color
		part.Material = Enum.Material.Wood
		part.CFrame = base * offset
		part.Parent = parent
		return part
	end
	piece("Seat", "BenchSeat", Vector3.new(6, 0.4, 1.6), CFrame.new(0, 1.9, 0), COLORS.wood)
	piece("Part", "BenchBack", Vector3.new(6, 1.8, 0.25), CFrame.new(0, 3, 0.75), COLORS.wood)
	piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(-2.6, 0.95, 0), COLORS.darkWood)
	piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(2.6, 0.95, 0), COLORS.darkWood)
end

-- An invisible marker. The client (BakeryShelves) puts bread on these.
local function marker(parent, name, x1, y1, z1, x2, y2, z2, attribute, number)
	local part = box(parent, name, x1, y1, z1, x2, y2, z2, COLORS.wood)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	if attribute then
		part:SetAttribute(attribute, number)
	end
	return part
end

-- A bread rack with 3 empty shelves (bottom, middle, top).
-- Each shelf has a RackSlot marker. An invisible BreadRack part in front holds
-- the "Pick Up Bread" prompt.
local SHELF_HEIGHTS = { 1.5, 3.5, 5.5 }

local function rack(parent, x1, x2, slotNumbers)
	box(parent, "RackPost", x1, 0.2, -12.8, x1 + 0.3, 7, -10.5, COLORS.darkWood, Enum.Material.Wood)
	box(parent, "RackPost", x2 - 0.3, 0.2, -12.8, x2, 7, -10.5, COLORS.darkWood, Enum.Material.Wood)
	for i, y in SHELF_HEIGHTS do
		box(parent, "Shelf", x1, y, -12.8, x2, y + 0.2, -10.5, COLORS.wood, Enum.Material.Wood)
		marker(parent, "RackSlot", x1 + 0.3, y + 0.2, -12.6, x2 - 0.3, y + 0.25, -10.7, "RackSlot", slotNumbers[i])
	end
	local pickup = marker(parent, "BreadRack", x1, 0.2, -10.5, x2, 7, -10.3)
	addLabel(pickup, "Bread Rack")
end

-- Markers inside the glass case: 2 rows of 4. The front row (customer side) fills first.
local function caseSlots(parent)
	for n = 1, Config.Bakery.caseLimit do
		local col = (n - 1) % 4
		local row = math.floor((n - 1) / 4)
		local x = (col - 1.5) * 2.6
		local z = 4.65 - row * 0.8
		marker(parent, "CaseSlot", x - 1, 3.6, z - 0.35, x + 1, 3.65, z + 0.35, "CaseSlot", n)
	end
end

local function build()
	local model = Instance.new("Model")
	model.Name = "Bakery"

	-- Ground
	box(model, "Floor", -20, 0, -14, 20, 0.2, 14, COLORS.floor, Enum.Material.WoodPlanks)
	box(model, "Path", -3, 0, 14, 3, 0.1, 20, COLORS.path, Enum.Material.Concrete) -- to the shared front walk
	box(model, "DoorMat", -2.5, 0.2, 10.5, 2.5, 0.25, 12.8, COLORS.red, Enum.Material.Fabric)

	-- Walls: back, sides, and a front with a door in the middle and two windows
	box(model, "BackWall", -20, 0, -14, 20, WALL_HEIGHT, -13, COLORS.wall)
	box(model, "LeftWall", -20, 0, -13, -19, WALL_HEIGHT, 13, COLORS.wall)
	box(model, "RightWall", 19, 0, -13, 20, WALL_HEIGHT, 13, COLORS.wall)
	wallWithWindow(model, -20, -3, -14, -8)
	wallWithWindow(model, 3, 20, 8, 14)
	box(model, "AboveDoor", -3, 9, 13, 3, WALL_HEIGHT, 14, COLORS.wall)

	-- Roof
	box(model, "Roof", -21, WALL_HEIGHT, -15, 21, WALL_HEIGHT + 1, 15.5, COLORS.roof, Enum.Material.Slate)

	-- Sign above the door, facing the street
	local sign = box(model, "Sign", -8, 10, 14, 8, 13, 14.6, COLORS.darkWood, Enum.Material.Wood)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back -- the +Z side, toward the spawn point
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 50
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Text = "PANADERYA"
	signText.Font = Enum.Font.FredokaOne
	signText.TextScaled = true
	signText.TextColor3 = COLORS.signText
	signText.Parent = signGui
	signGui.Parent = sign

	-- Striped awning over the door
	for i = 0, 8 do
		local stripe = Instance.new("Part")
		stripe.Name = "Awning"
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.Size = Vector3.new(1, 0.3, 3.6)
		stripe.CFrame = ORIGIN * CFrame.new(-4 + i, 9.3, 15.6) * CFrame.Angles(math.rad(20), 0, 0)
		stripe.Color = if i % 2 == 0 then COLORS.red else COLORS.white
		stripe.Material = Enum.Material.Fabric
		stripe.Parent = model
	end

	-- Time clock on the wall, just inside the door
	local clock = box(model, "TimeClock", -7, 3.5, 12.4, -5.5, 6.5, 13, COLORS.metal, Enum.Material.Metal)
	addLabel(clock, "Time Clock")

	-- Counter with a glass case
	box(model, "Counter", -8, 0.2, 3, 8, 3.6, 5.5, COLORS.wood, Enum.Material.Wood)
	local case = box(model, "DisplayCase", -6, 3.6, 3.3, 6, 5.4, 5.2, COLORS.glass, Enum.Material.Glass)
	case.Transparency = 0.6
	caseSlots(model)
	-- Invisible prompt spots: bakers serve from behind the counter,
	-- customers order in front of it.
	marker(model, "ServeSpot", -4, 0.2, 1.2, 4, 4, 1.6)
	local orderSpot = marker(model, "OrderSpot", -4, 0.2, 6.2, 4, 4, 6.6)
	addLabel(orderSpot, "Order Here", 2.5)

	-- One brick oven against the back wall, for every kind of bread
	local oven = box(model, "Oven", -4, 0.2, -13, 4, 6, -8.5, COLORS.brick, Enum.Material.Brick)
	addLabel(oven, "Oven", 1.5)
	box(model, "OvenTop", -3, 6, -13, 3, 7.5, -9.5, COLORS.brick, Enum.Material.Brick)
	box(model, "OvenMouth", -2, 1.5, -8.6, 2, 4.2, -8.4, Color3.fromRGB(25, 20, 20))
	local fire = box(model, "OvenFire", -1.6, 1.6, -8.45, 1.6, 2.4, -8.3, COLORS.fire, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.fire
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = fire
	local chimney = box(model, "Chimney", -1, 7.5, -12.5, 1, WALL_HEIGHT + 4, -10.5, COLORS.brick, Enum.Material.Brick)

	-- Little flames in the oven mouth
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.LightEmission = 1
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 90, 30))
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.4, 0.7)
	flames.Rate = 18
	flames.Speed = NumberRange.new(0.5, 1.2)
	flames.EmissionDirection = Enum.NormalId.Top
	flames.SpreadAngle = Vector2.new(10, 10)
	flames.Parent = fire

	-- Smoke from the chimney, drifting with the wind
	local top = Instance.new("Attachment")
	top.Name = "ChimneyTop"
	top.Position = Vector3.new(0, chimney.Size.Y / 2, 0)
	top.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(150, 150, 150))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 5
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Acceleration = Vector3.new(1.5, 0.5, 0)
	smoke.Parent = top

	-- Crackling oven sound (if set in Config.Sounds.oven)
	Atmosphere.loopSound(oven, "oven", 0.35, 30)

	-- Bread racks on both sides of the oven. They start empty.
	-- Slot numbers fill eye-level shelves first: middle (1, 2), top (3, 4), bottom (5, 6).
	-- 6 slots = Config.Bakery.rackLimit.
	rack(model, -18, -12, { 5, 1, 3 })
	rack(model, 12, 18, { 6, 2, 4 })

	-- Trash bin
	local trash = box(model, "TrashBin", 15, 0.2, 4, 17, 3.2, 6, COLORS.green)
	addLabel(trash, "Trash")

	-- Ceiling lamps
	lamp(model, -10, 0)
	lamp(model, 10, 0)
	lamp(model, 0, -5)

	-- Front door: two sliding wooden panels that slide into the wall when open.
	-- OpenOffsetX = how far each panel moves (studs) when the bakery opens.
	for _, side in { { "DoorLeft", -3, 0, -3 }, { "DoorRight", 0, 3, 3 } } do
		local door = box(model, side[1], side[2], 0.2, 13.3, side[3], 9, 13.7, COLORS.darkWood, Enum.Material.Wood)
		door:SetAttribute("OpenOffsetX", side[4])
	end

	-- OPEN / CLOSED sign beside the door (Establishments sets the text)
	local openBoard = box(model, "OpenSignBoard", 3.6, 5.5, 14, 6.8, 7.3, 14.25, COLORS.darkWood, Enum.Material.Wood)
	surfaceText(openBoard, Enum.NormalId.Back, "OPEN", COLORS.signText).Name = "OpenSignText"

	-- Menu board with prices, on the left wall
	local menuBoard = box(model, "MenuBoard", -19, 5, -4, -18.8, 10.5, 7, Color3.fromRGB(35, 45, 40))
	local menuLines = { "MENU" }
	for _, item in Config.Bakery.items do
		table.insert(menuLines, ("%s %s - %d coins"):format(item.icon, item.name, item.price))
	end
	local menuText = surfaceText(menuBoard, Enum.NormalId.Right, table.concat(menuLines, "\n"), COLORS.white)
	menuText.TextScaled = false
	menuText.TextSize = 40
	menuText.TextXAlignment = Enum.TextXAlignment.Left
	menuText.LineHeight = 1.15
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 30)
	padding.Parent = menuText

	-- Flower boxes under the front windows
	local flowerColors = { Color3.fromRGB(240, 110, 150), Color3.fromRGB(250, 210, 70), Color3.fromRGB(245, 245, 245) }
	for _, window in { { -14, -8 }, { 8, 14 } } do
		box(model, "FlowerBox", window[1], 2.4, 14.5, window[2], 3.4, 15.4, COLORS.darkWood, Enum.Material.Wood)
		local i = 0
		for x = window[1] + 0.6, window[2] - 0.6, 0.9 do
			i += 1
			ball(model, "Flower", 0.75, x, 3.7, 14.95, flowerColors[(i - 1) % #flowerColors + 1])
		end
	end

	-- A bench out front, facing the street
	bench(model, 11, 19.5, math.pi)

	model.Parent = workspace
	return model
end

-- Returns { timeClock, serveSpot, orderSpot, oven, trash, racks = { part, ... }, establishment }.
function BakeryMap.getOrBuild()
	local model = workspace:FindFirstChild("Bakery") or build()

	local function find(name)
		local part = model:FindFirstChild(name, true)
		if not part then
			warn(("[BakeryMap] The Bakery model has no part named %q"):format(name))
		end
		return part
	end

	local racks = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "BreadRack" then
			table.insert(racks, d)
		end
	end
	if #racks == 0 then
		warn("[BakeryMap] The Bakery model has no part named \"BreadRack\"")
	end

	local doors, signs = Establishments.findDoorsAndSigns(model)

	return {
		timeClock = find("TimeClock"),
		serveSpot = find("ServeSpot"),
		orderSpot = find("OrderSpot"),
		oven = find("Oven"),
		trash = find("TrashBin"),
		racks = racks,
		-- For Establishments: open hours, doors and the OPEN/CLOSED sign.
		establishment = {
			name = "Bakery",
			origin = ORIGIN,
			halfSize = Vector3.new(19, 7, 13),
			outside = ORIGIN * CFrame.new(0, 0, 20),
			doors = doors,
			signs = signs,
			closedMessage = "The bakery is closed for the night. It opens at 6:00 AM.",
		},
	}
end

return BakeryMap
