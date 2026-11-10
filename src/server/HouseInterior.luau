-- The inside of a rented house: a living room, a kitchen and a bedroom.
-- Each one is built far away from the city (players are moved there through
-- the front door), so the 80 houses outside can stay simple and fast.
--
-- HouseInterior.build(origin, ownerName) returns the model and the parts that
-- Housing puts prompts on: exitDoor, bed, fridge, openSwitch, and spawn (a CFrame).

local MapKit = require(script.Parent.MapKit)

local HouseInterior = {}

local COLORS = {
	floor = Color3.fromRGB(170, 120, 80),
	wall = Color3.fromRGB(240, 236, 228),
	accent = Color3.fromRGB(120, 140, 160),
	ceiling = Color3.fromRGB(250, 250, 248),
	wood = Color3.fromRGB(140, 95, 60),
	darkWood = Color3.fromRGB(90, 60, 40),
	sofa = Color3.fromRGB(90, 110, 140),
	rug = Color3.fromRGB(200, 170, 130),
	white = Color3.fromRGB(245, 245, 245),
	metal = Color3.fromRGB(190, 192, 198),
	black = Color3.fromRGB(25, 25, 28),
	blanket = Color3.fromRGB(190, 90, 80),
	plant = Color3.fromRGB(70, 140, 80),
	sky = Color3.fromRGB(170, 215, 245),
}

-- A seat players can sit on, from corners (like kit.box).
local function seat(kit, model, name, x1, y1, z1, x2, y2, z2, color)
	local part = kit.box(model, name, x1, y1, z1, x2, y2, z2, color, Enum.Material.Fabric)
	local s = Instance.new("Seat")
	s.Name = name
	s.Anchored = true
	s.Size = part.Size
	s.CFrame = part.CFrame
	s.Color = color
	s.Material = Enum.Material.Fabric
	s.Parent = model
	part:Destroy()
	return s
end

-- grand = true for the Admin Mansion: a bigger room with a kitchen island,
-- a home office and a chandelier.
function HouseInterior.build(origin, ownerName, grand)
	local kit = MapKit.new(origin)
	local box, glass, label = kit.box, kit.glass, kit.label
	local model = Instance.new("Model")
	model.Name = if grand then "MansionInterior" else "HouseInterior"

	local W, D, H = 15, 12, 10 -- half width, half depth, height
	if grand then
		W, D, H = 22, 16, 14
	end

	-- Room shell (the front is +Z, where the door is)
	box(model, "Floor", -W, 0, -D, W, 0.4, D, COLORS.floor, Enum.Material.WoodPlanks)
	box(model, "Ceiling", -W, H, -D, W, H + 0.4, D, COLORS.ceiling)
	box(model, "BackWall", -W, 0, -D - 0.5, W, H, -D, COLORS.wall, Enum.Material.Plaster)
	box(model, "LeftWall", -W - 0.5, 0, -D, -W, H, D, COLORS.wall, Enum.Material.Plaster)
	box(model, "RightWall", W, 0, -D, W + 0.5, H, D, COLORS.wall, Enum.Material.Plaster)
	box(model, "FrontWall", -W, 0, D, -2, H, D + 0.5, COLORS.wall, Enum.Material.Plaster)
	box(model, "FrontWall", 2, 0, D, W, H, D + 0.5, COLORS.wall, Enum.Material.Plaster)
	box(model, "FrontWall", -2, 7, D, 2, H, D + 0.5, COLORS.wall, Enum.Material.Plaster)
	box(model, "AccentWall", -W, 0.4, -D, -3, H, -D + 0.1, COLORS.accent, Enum.Material.Plaster)
	-- Windows showing the sky
	for _, x in { -10, 10 } do
		glass(model, "Window", x - 3, 4, D - 0.05, x + 3, 7.5, D + 0.05, 0.1).Color = COLORS.sky
	end

	-- Exit door
	local exitDoor = box(model, "ExitDoor", -2, 0.4, D - 0.1, 2, 7, D + 0.1, COLORS.darkWood, Enum.Material.Wood)
	label(exitDoor, "Exit", 0)

	-- Open house switch by the door
	local openSwitch = box(model, "OpenHouseSwitch", 2.6, 4, D - 0.3, 3.4, 5, D - 0.1, COLORS.white)

	-- Living room (front left): rug, sofa, coffee table, TV, plant
	box(model, "Rug", -13, 0.4, 1, -3, 0.45, 9, COLORS.rug, Enum.Material.Fabric)
	seat(kit, model, "Sofa", -12, 0.4, 7, -4, 1.9, 9, COLORS.sofa)
	box(model, "SofaBack", -12, 1.9, 8.6, -4, 4, 9.4, COLORS.sofa, Enum.Material.Fabric)
	box(model, "SofaArm", -12.8, 0.4, 7, -12, 2.8, 9.4, COLORS.sofa, Enum.Material.Fabric)
	box(model, "SofaArm", -4, 0.4, 7, -3.2, 2.8, 9.4, COLORS.sofa, Enum.Material.Fabric)
	box(model, "CoffeeTable", -10, 1.6, 3.5, -6, 1.9, 5.5, COLORS.wood, Enum.Material.Wood)
	box(model, "CoffeeTableLeg", -8.3, 0.4, 4.3, -7.7, 1.6, 4.7, COLORS.darkWood)
	box(model, "TvStand", -11, 0.4, 0.2, -5, 2, 1.4, COLORS.darkWood, Enum.Material.Wood)
	local tv = box(model, "TV", -10.5, 2.4, 0.5, -5.5, 5.2, 0.8, COLORS.black)
	local screen = Instance.new("SurfaceGui")
	screen.Face = Enum.NormalId.Back
	local show = Instance.new("TextLabel")
	show.Size = UDim2.fromScale(1, 1)
	show.BackgroundColor3 = Color3.fromRGB(40, 90, 150)
	show.Text = "📺 Bayan TV"
	show.TextScaled = true
	show.Font = Enum.Font.FredokaOne
	show.TextColor3 = Color3.new(1, 1, 1)
	show.Parent = screen
	screen.Parent = tv
	box(model, "PlantPot", -14, 0.4, 10, -12.6, 1.6, 11.4, Color3.fromRGB(170, 100, 60))
	kit.ball(model, "Plant", 2.2, -13.3, 2.6, 10.7, COLORS.plant, Enum.Material.Grass)

	-- Kitchen (back left): counter, fridge, dining table with chairs
	box(model, "Counter", -14.5, 0.4, -11.5, -3, 3.4, -9.5, COLORS.white)
	box(model, "CounterTop", -14.6, 3.4, -11.6, -2.9, 3.7, -9.3, Color3.fromRGB(60, 60, 65), Enum.Material.Marble)
	box(model, "Sink", -10, 3.5, -11, -8, 3.75, -10, COLORS.metal, Enum.Material.Metal)
	box(model, "Stove", -6.5, 3.7, -11.2, -4, 3.8, -9.8, COLORS.black)
	local fridge = box(model, "Fridge", -2.6, 0.4, -11.5, 0.4, 7.4, -9.5, COLORS.metal, Enum.Material.Metal)
	box(model, "FridgeHandle", -0.4, 3, -9.45, -0.2, 5.5, -9.35, COLORS.black)
	label(fridge, "Fridge", 0)
	box(model, "DiningTable", -11, 2.8, -6.5, -5, 3.1, -3.5, COLORS.wood, Enum.Material.Wood)
	box(model, "DiningTableLeg", -8.3, 0.4, -5.3, -7.7, 2.8, -4.7, COLORS.darkWood)
	for _, x in { -9.5, -6.5 } do
		seat(kit, model, "Chair", x - 0.8, 1.6, -8.2, x + 0.8, 1.9, -6.8, COLORS.wood)
		seat(kit, model, "Chair", x - 0.8, 1.6, -3.2, x + 0.8, 1.9, -1.8, COLORS.wood)
	end

	-- Bedroom (right), behind a half wall: bed, side table, lamp, wardrobe
	box(model, "PartitionWall", 1.5, 0.4, -D, 2, H, -2, COLORS.wall, Enum.Material.Plaster)
	box(model, "BedFrame", 6, 0.4, -11.5, 14, 1.6, -3.5, COLORS.darkWood, Enum.Material.Wood)
	box(model, "Headboard", 6, 1.6, -11.8, 14, 4.5, -11.3, COLORS.darkWood, Enum.Material.Wood)
	local bed = box(model, "Bed", 6.3, 1.6, -11.3, 13.7, 2.4, -3.7, COLORS.white, Enum.Material.Fabric)
	box(model, "Blanket", 6.2, 2.4, -8, 13.8, 2.5, -3.6, COLORS.blanket, Enum.Material.Fabric)
	box(model, "Pillow", 7, 2.4, -11, 13, 2.9, -9.6, COLORS.white, Enum.Material.Fabric)
	label(bed, "Bed", 0.5)
	box(model, "SideTable", 3, 0.4, -11.5, 5.5, 2.4, -9.5, COLORS.wood, Enum.Material.Wood)
	box(model, "BedLamp", 3.8, 2.4, -10.9, 4.7, 3.8, -10, Color3.fromRGB(255, 235, 180), Enum.Material.Neon)
	box(model, "Wardrobe", 11, 0.4, 2, 14.6, 8, 6, COLORS.wood, Enum.Material.Wood)

	-- Lights
	for _, x in { -8, 8 } do
		for _, z in { -6, 5 } do
			kit.lamp(model, x, H - 0.01, z)
		end
	end

	-- Name above the door inside
	local nameBoard = box(model, "NameBoard", -4, 7.6, D - 0.2, 4, 8.8, D - 0.05, COLORS.darkWood)
	local title = if grand then ("🏰 %s's Residence"):format(ownerName) else ("🏠 %s's House"):format(ownerName)
	kit.surfaceText(nameBoard, Enum.NormalId.Front, title, Color3.fromRGB(255, 230, 170))

	if grand then
		-- Kitchen island, home office, a second sofa, a chandelier and art
		box(model, "KitchenIsland", -18, 0.4, -8, -14, 3.4, -4, COLORS.white)
		box(model, "IslandTop", -18.2, 3.4, -8.2, -13.8, 3.7, -3.8, Color3.fromRGB(60, 60, 65), Enum.Material.Marble)
		box(model, "OfficeDesk", 15.5, 0.4, 4, 21.5, 3, 7, COLORS.darkWood, Enum.Material.Wood)
		local monitor = box(model, "OfficeMonitor", 17, 3, 6.4, 20, 5, 6.6, COLORS.black)
		kit.surfaceText(monitor, Enum.NormalId.Front, "ADMIN", Color3.fromRGB(120, 220, 255))
		seat(kit, model, "OfficeChair", 17.5, 1.6, 2, 19.5, 1.9, 3.6, COLORS.black)
		seat(kit, model, "Sofa2", -20, 0.4, -2, -18, 1.9, 8, COLORS.sofa)
		box(model, "Sofa2Back", -21, 1.9, -2, -20, 4, 8, COLORS.sofa, Enum.Material.Fabric)
		local chandelier = box(model, "Chandelier", -2, H - 2, -2, 2, H - 1, 2, Color3.fromRGB(255, 235, 185), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1
		light.Parent = chandelier
		box(model, "ChandelierChain", -0.1, H - 1, -0.1, 0.1, H, 0.1, Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
		local art = box(model, "Painting", -20, 6, -D + 0.1, -12, 11, -D + 0.3, Color3.fromRGB(70, 110, 150))
		kit.surfaceText(art, Enum.NormalId.Back, "🌅", Color3.new(1, 1, 1))
	end

	model.Parent = workspace
	return {
		model = model,
		exitDoor = exitDoor,
		bed = bed,
		fridge = fridge,
		openSwitch = openSwitch,
		spawn = origin * CFrame.new(0, 3.5, D - 4), -- just inside the door, facing into the room
	}
end

return HouseInterior
