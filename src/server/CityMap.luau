-- Builds the city of Bayan around the spawn point: roads, the central plaza,
-- Bayan Park, the covered court, the Bayan Public Market (business stalls) and houses.
-- The workplaces (BakeryMap, MallMap, TownHallMap) stand at the ends of the roads:
--
--                Bayan Mall (+Z)          Veterans Parc (NE)
--                     |
--   Town Hall ---- Town center ---- Bakery & Public Market ---- Rotonda (+X)
--   (-X)  Park (NW)   |   Court (SE)
--          Bayan Heights (-Z)   Bayan Heights II (SE)
--
-- The town center (spawn) is a walking plaza inside a ring road where the 4
-- main roads meet (see buildPlaza).
--
-- Everything here is for looks and fun (benches, swings and bleachers can be
-- sat on). Positions are world positions (studs from the spawn point).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameClock = require(ReplicatedStorage.Shared.GameClock)
local MapKit = require(script.Parent.MapKit)
local Atmosphere = require(script.Parent.Atmosphere)

local CityMap = {}

local kit = MapKit.new(CFrame.new())
local box, ball, pillar, surfaceText, label = kit.box, kit.ball, kit.pillar, kit.surfaceText, kit.label

local COLORS = {
	grass = Color3.fromRGB(95, 160, 80),
	asphalt = Color3.fromRGB(55, 57, 62),
	line = Color3.fromRGB(245, 240, 210),
	sidewalk = Color3.fromRGB(200, 198, 190),
	plaza = Color3.fromRGB(205, 185, 160),
	stone = Color3.fromRGB(225, 222, 212),
	water = Color3.fromRGB(80, 160, 220),
	wood = Color3.fromRGB(140, 95, 55),
	darkWood = Color3.fromRGB(100, 65, 40),
	metal = Color3.fromRGB(70, 72, 80),
	red = Color3.fromRGB(210, 60, 50),
	blue = Color3.fromRGB(50, 100, 180),
	yellow = Color3.fromRGB(245, 200, 60),
	green = Color3.fromRGB(60, 130, 70),
	sand = Color3.fromRGB(230, 210, 160),
	thatch = Color3.fromRGB(185, 150, 90),
	bamboo = Color3.fromRGB(190, 170, 110),
	white = Color3.fromRGB(245, 245, 245),
}

-- A block placed with any CFrame (for tilted roofs, slides and planks).
local function part(parent, name, size, cframe, color, material, className)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A flat disc (pond, fountain water) at height y.
local function disc(parent, name, x, z, y1, y2, diameter, color, material)
	return pillar(parent, name, x, z, y1, y2, diameter, color, material)
end

-- A sign board that faces a direction (angle turns it around Y). Returns the board.
local function signBoard(parent, text, x, y, z, width, height, angle, color, textColor)
	local board = part(parent, "SignBoard", Vector3.new(width, height, 0.3), CFrame.new(x, y, z) * CFrame.Angles(0, angle, 0), color or COLORS.green)
	surfaceText(board, Enum.NormalId.Front, text, textColor or COLORS.white)
	surfaceText(board, Enum.NormalId.Back, text, textColor or COLORS.white)
	return board
end

------------------------------------------------------------------------
-- Ground and roads
------------------------------------------------------------------------

local function buildGround(model)
	box(model, "Grass", -270, -0.95, -440, 270, 0.05, 230, COLORS.grass, Enum.Material.Grass)
end

-- A straight road with a dashed center line, sidewalks, lamps and trees.
-- alongX = true: the road runs along X (from a to b) at z = c; else along Z at x = c.
-- options = { noTrees = true, treesUntil = number, sidewalkTop = number, lampGaps = { { from, to } } }
-- (treesUntil: no trees past this point; sidewalkTop helps where sidewalks cross;
-- lampGaps: no lamp posts there, for example where a side road joins)
local function road(model, alongX, a, b, c, width, options)
	width = width or 20
	options = options or {}
	local sidewalkTop = options.sidewalkTop or 0.16
	local half = width / 2
	local function rect(name, u1, u2, v1, v2, y2, color, material)
		if alongX then
			return box(model, name, u1, 0, v1, u2, y2, v2, color, material)
		end
		return box(model, name, v1, 0, u1, v2, y2, u2, color, material)
	end
	rect("Road", a, b, c - half, c + half, 0.12, COLORS.asphalt, Enum.Material.Asphalt)
	for u = a + 3, b - 5, 8 do
		rect("LaneLine", u, u + 4, c - 0.2, c + 0.2, 0.13, COLORS.line)
	end
	rect("Sidewalk", a, b, c - half - 4, c - half, sidewalkTop, COLORS.sidewalk, Enum.Material.Concrete)
	rect("Sidewalk", a, b, c + half, c + half + 4, sidewalkTop, COLORS.sidewalk, Enum.Material.Concrete)
	rect("Curb", a, b, c - half - 0.3, c - half, 0.25, COLORS.white)
	rect("Curb", a, b, c + half, c + half + 0.3, 0.25, COLORS.white)
	local i = 0
	for u = a + 10, b - 6, 30 do
		i += 1
		local v1, v2 = c - half - 2, c + half + 6.5
		local treeAt = u + 15
		-- never past the end of the road, and never on the main avenues' sidewalks
		local lastTree = math.min(b - 3, options.treesUntil or math.huge)
		local hasTree = not options.noTrees and treeAt <= lastTree and math.abs(treeAt) >= 16
		local hasLamp = true
		for _, gap in options.lampGaps or {} do
			hasLamp = hasLamp and not (u >= gap[1] and u <= gap[2])
		end
		if alongX then
			if hasLamp then
				kit.lampPost(model, u, v1)
			end
			if hasTree then
				kit.tree(model, treeAt, v2, 0.8)
			end
		else
			if hasLamp then
				kit.lampPost(model, v1, u)
			end
			if hasTree then
				kit.tree(model, v2, treeAt, 0.8)
			end
		end
	end
end

------------------------------------------------------------------------
-- Town center (spawn): a walking plaza (x and z from -38 to 38) inside a
-- ring road (38..50) where the 4 main roads meet, with an outer sidewalk
-- (50..54) and zebra crossings. The middle stays clear for the spawn point.
------------------------------------------------------------------------

local PLAZA, RING, OUTER = 38, 50, 54

-- Zebra stripes. acrossX = true: stripes run along X, spread from v1 to v2 on Z
-- (a crossing over a road that runs along X); false: the other way round.
local function zebra(model, acrossX, u1, u2, v1, v2)
	for v = v1 + 0.6, v2 - 1.2, 1.6 do
		if acrossX then
			box(model, "ZebraStripe", u1 + 0.3, 0.12, v, u2 - 0.3, 0.14, v + 0.8, COLORS.white)
		else
			box(model, "ZebraStripe", v, 0.12, u1 + 0.3, v + 0.8, 0.14, u2 - 0.3, COLORS.white)
		end
	end
end

local function buildRingRoad(model)
	local asphalt, material = COLORS.asphalt, Enum.Material.Asphalt
	box(model, "RingRoad", -RING, 0, PLAZA, RING, 0.12, RING, asphalt, material) -- north side
	box(model, "RingRoad", -RING, 0, -RING, RING, 0.12, -PLAZA, asphalt, material) -- south side
	box(model, "RingRoad", -RING, 0, -PLAZA, -PLAZA, 0.12, PLAZA, asphalt, material) -- west side
	box(model, "RingRoad", PLAZA, 0, -PLAZA, RING, 0.12, PLAZA, asphalt, material) -- east side
	-- Dashed center line, away from the junctions and corners
	local mid = (PLAZA + RING) / 2
	for _, c in { -34, -26, -18, 18, 26, 34 } do
		for _, side in { -1, 1 } do
			box(model, "LaneLine", c - 2, 0.12, side * mid - 0.2, c + 2, 0.13, side * mid + 0.2, COLORS.line)
			box(model, "LaneLine", side * mid - 0.2, 0.12, c - 2, side * mid + 0.2, 0.13, c + 2, COLORS.line)
		end
	end
	for _, side in { -1, 1 } do
		-- Curb around the plaza
		box(model, "Curb", -PLAZA, 0, side * PLAZA - 0.15, PLAZA, 0.25, side * PLAZA + 0.15, COLORS.white)
		box(model, "Curb", side * PLAZA - 0.15, 0, -PLAZA, side * PLAZA + 0.15, 0.25, PLAZA, COLORS.white)
		-- Outer sidewalk (open where the roads join), with its curb
		for _, seg in { { -OUTER, -10 }, { 10, OUTER } } do
			box(model, "Sidewalk", seg[1], 0, side * RING, seg[2], 0.16, side * OUTER, COLORS.sidewalk, Enum.Material.Concrete)
		end
		for _, seg in { { -RING, -10 }, { 10, RING } } do
			box(model, "Sidewalk", side * RING, 0, seg[1], side * OUTER, 0.16, seg[2], COLORS.sidewalk, Enum.Material.Concrete)
			box(model, "Curb", seg[1], 0, side * (RING - 0.3), seg[2], 0.25, side * RING, COLORS.white)
			box(model, "Curb", side * (RING - 0.3), 0, seg[1], side * RING, 0.25, seg[2], COLORS.white)
		end
		-- Zebra crossings in line with each road's sidewalks
		local v1, v2 = math.min(side * PLAZA, side * RING), math.max(side * PLAZA, side * RING)
		for _, u in { -14, 10 } do
			zebra(model, true, u, u + 4, v1, v2) -- north / south sides
			zebra(model, false, u, u + 4, v1, v2) -- west / east sides
		end
		-- Lamps on the outer corners
		kit.lampPost(model, side * 52, 52)
		kit.lampPost(model, side * 52, -52)
	end
end

-- A street food cart facing its front (local -Z) the way of the angle.
local function foodCart(model, x, z, angle, name, bodyColor, umbrellaColor)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	part(model, "CartBody", Vector3.new(4, 2.4, 2.4), at(0, 2.2, 0), bodyColor)
	local case = part(model, "CartCase", Vector3.new(3, 1, 1.8), at(0, 3.9, 0), Color3.fromRGB(190, 225, 240), Enum.Material.Glass)
	case.Transparency = 0.4
	for _, dz in { -1.3, 1.3 } do
		local wheel = part(model, "CartWheel", Vector3.new(0.3, 1.6, 1.6), at(-1, 0.8, dz) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 30))
		wheel.Shape = Enum.PartType.Cylinder
	end
	part(model, "CartLeg", Vector3.new(0.3, 1, 0.3), at(1.6, 0.5, 0), COLORS.metal, Enum.Material.Metal)
	part(model, "UmbrellaPole", Vector3.new(0.2, 4.6, 0.2), at(1.3, 5.7, 0.6), COLORS.metal, Enum.Material.Metal)
	local umbrella = part(model, "Umbrella", Vector3.new(0.3, 5, 5), at(1.3, 8.1, 0.6) * CFrame.Angles(0, 0, math.rad(90)), umbrellaColor, Enum.Material.Fabric)
	umbrella.Shape = Enum.PartType.Cylinder
	local sign = part(model, "CartSign", Vector3.new(3.6, 0.9, 0.1), at(0, 2.6, -1.26), COLORS.white)
	surfaceText(sign, Enum.NormalId.Front, name, COLORS.metal)
end

local function buildPlaza(model)
	buildRingRoad(model)
	box(model, "Plaza", -PLAZA, 0, -PLAZA, PLAZA, 0.15, PLAZA, COLORS.plaza, Enum.Material.Brick)

	-- Spawn medallion in the middle (kept clear)
	disc(model, "SpawnMedallion", 0, 0, 0, 0.17, 16, COLORS.stone, Enum.Material.Marble)
	disc(model, "SpawnMedallion", 0, 0, 0, 0.18, 12, Color3.fromRGB(190, 150, 120), Enum.Material.Brick)
	disc(model, "SpawnMedallion", 0, 0, 0, 0.19, 4, COLORS.yellow, Enum.Material.Marble)

	-- Fountain (north side, so the spawn stays clear): two bowls and a spray
	local fz = 20
	disc(model, "FountainPaving", 0, fz, 0, 0.17, 22, COLORS.stone, Enum.Material.Marble)
	disc(model, "FountainBase", 0, fz, 0, 1.6, 16, COLORS.stone, Enum.Material.Marble)
	local water = disc(model, "FountainWater", 0, fz, 1.3, 1.65, 14.6, COLORS.water, Enum.Material.Glass)
	water.Transparency = 0.25
	pillar(model, "FountainColumn", 0, fz, 1.6, 6, 1.4, COLORS.stone, Enum.Material.Marble)
	disc(model, "FountainBowl", 0, fz, 6, 6.6, 6, COLORS.stone, Enum.Material.Marble)
	pillar(model, "FountainColumn", 0, fz, 6.6, 8.6, 0.8, COLORS.stone, Enum.Material.Marble)
	disc(model, "FountainBowl", 0, fz, 8.6, 9.1, 3.2, COLORS.stone, Enum.Material.Marble)
	local jet = pillar(model, "FountainJet", 0, fz, 9.1, 11.2, 0.6, Color3.fromRGB(170, 220, 255), Enum.Material.Neon)
	jet.Transparency = 0.3
	jet.CanCollide = false

	-- Water spray from the top, falling back into the bowl
	local spout = Instance.new("Attachment")
	spout.Name = "Spout"
	spout.Position = Vector3.new(jet.Size.X / 2, 0, 0) -- the cylinder's top end (its axis is X)
	spout.Parent = jet
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255), Color3.fromRGB(140, 200, 245))
	spray.LightEmission = 0.4
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.25) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 45
	spray.Speed = NumberRange.new(7, 9)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- along the cylinder's axis = up
	spray.Parent = spout
	Atmosphere.loopSound(jet, "fountain", 0.4, 40)

	-- Benches and flower beds around the fountain
	kit.bench(model, -12, 0.17, fz, -math.pi / 2)
	kit.bench(model, 12, 0.17, fz, math.pi / 2)
	kit.bench(model, -5, 0.17, fz + 11, 0)
	kit.bench(model, 5, 0.17, fz + 11, 0)
	local flowers = { Color3.fromRGB(240, 110, 150), Color3.fromRGB(250, 210, 70), Color3.fromRGB(245, 245, 245), Color3.fromRGB(200, 90, 200) }
	for i, spot in { { -11, fz - 9 }, { 11, fz - 9 }, { -11, fz + 9 }, { 11, fz + 9 } } do
		box(model, "FlowerBed", spot[1] - 2, 0, spot[2] - 2, spot[1] + 2, 0.6, spot[2] + 2, COLORS.darkWood, Enum.Material.Wood)
		for dx = -1.2, 1.2, 1.2 do
			for dz = -1.2, 1.2, 1.2 do
				ball(model, "Flower", 0.8, spot[1] + dx, 0.9, spot[2] + dz, flowers[(i + math.floor(dx + dz)) % #flowers + 1])
			end
		end
	end

	-- Gazebo (west side), open toward the plaza, with benches and a lamp
	local gx, gz = -24, -4
	box(model, "GazeboFloor", gx - 8, 0, gz - 8, gx + 8, 0.4, gz + 8, COLORS.wood, Enum.Material.WoodPlanks)
	box(model, "GazeboStep", gx + 8, 0, gz - 3, gx + 9.5, 0.2, gz + 3, COLORS.stone, Enum.Material.Concrete)
	for _, dx in { -7, 7 } do
		for _, dz in { -7, 7 } do
			pillar(model, "GazeboPost", gx + dx, gz + dz, 0.4, 9, 0.7, COLORS.white)
		end
	end
	box(model, "GazeboRail", gx - 7, 2.4, gz - 7.1, gx + 7, 2.6, gz - 6.9, COLORS.white)
	box(model, "GazeboRail", gx - 7, 2.4, gz + 6.9, gx + 7, 2.6, gz + 7.1, COLORS.white)
	box(model, "GazeboRail", gx - 7.1, 2.4, gz - 7, gx - 6.9, 2.6, gz + 7, COLORS.white)
	for i, size in { 19, 15, 11, 7, 3 } do
		local y = 9 + (i - 1) * 0.7
		box(model, "GazeboRoof", gx - size / 2, y, gz - size / 2, gx + size / 2, y + 0.7, gz + size / 2, COLORS.red, Enum.Material.Slate)
	end
	ball(model, "GazeboTop", 1, gx, 12.9, gz, COLORS.yellow)
	kit.bench(model, gx, 0.4, gz - 4, math.pi)
	kit.bench(model, gx, 0.4, gz + 4, 0)
	kit.lamp(model, gx, 8.99, gz)

	-- Clock tower (north-east corner): its 4 faces show the game time
	local cx, cz = 27, 27
	local cream = Color3.fromRGB(240, 232, 214)
	box(model, "ClockTowerBase", cx - 5, 0, cz - 5, cx + 5, 1, cz + 5, COLORS.stone, Enum.Material.Marble)
	box(model, "ClockTower", cx - 3, 1, cz - 3, cx + 3, 24, cz + 3, cream, Enum.Material.Plaster)
	box(model, "ClockTowerBand", cx - 3.4, 12, cz - 3.4, cx + 3.4, 12.6, cz + 3.4, COLORS.stone, Enum.Material.Marble)
	box(model, "ClockRoom", cx - 3.6, 24, cz - 3.6, cx + 3.6, 31, cz + 3.6, cream, Enum.Material.Plaster)
	for i, size in { 8.4, 6.4, 4.4, 2.4 } do
		local y = 31 + (i - 1) * 0.9
		box(model, "ClockTowerRoof", cx - size / 2, y, cz - size / 2, cx + size / 2, y + 0.9, cz + size / 2, COLORS.red, Enum.Material.Slate)
	end
	ball(model, "ClockTowerTop", 1.2, cx, 35.2, cz, COLORS.yellow, Enum.Material.Neon)
	local clockFaces, clockTexts = {}, {}
	for _, dir in { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		local center = Vector3.new(cx, 27.5, cz) + dir * 3.7
		local face = part(model, "ClockFace", Vector3.new(0.2, 5.4, 5.4), CFrame.new(center) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0), COLORS.white)
		face.Shape = Enum.PartType.Cylinder -- its round end (local +X) faces out
		table.insert(clockFaces, face)
		table.insert(clockTexts, surfaceText(face, Enum.NormalId.Right, "6:00 AM", COLORS.metal))
	end
	task.spawn(function()
		while clockFaces[1].Parent do
			local now = GameClock.format(GameClock.hour(workspace:GetServerTimeNow()))
			for _, label in clockTexts do
				label.Text = now
			end
			task.wait(1)
		end
	end)

	-- Street food carts (north-west), facing the fountain, with benches
	foodCart(model, -28, 14, -math.pi / 2, "🥛 TAHO", Color3.fromRGB(150, 100, 60), Color3.fromRGB(240, 220, 160))
	foodCart(model, -28, 22, -math.pi / 2, "🍦 SORBETES", Color3.fromRGB(240, 70, 60), Color3.fromRGB(250, 210, 60))
	foodCart(model, -28, 30, -math.pi / 2, "🍢 FISHBALL", Color3.fromRGB(245, 160, 50), Color3.fromRGB(70, 140, 220))
	kit.bench(model, -20, 0.15, 18, math.pi / 2)
	kit.bench(model, -20, 0.15, 26, math.pi / 2)

	-- Jeepney terminal (east side, for the future Jeepney Driver job), with a
	-- stop marked on the ring road beside it
	for _, px in { 30, 37 } do
		for _, pz in { -30, -24, -18 } do
			pillar(model, "ShedPost", px, pz, 0, 8, 0.4, COLORS.metal, Enum.Material.Metal)
		end
	end
	box(model, "ShedRoof", 29.2, 8, -31, 37.8, 8.4, -17, COLORS.blue, Enum.Material.Metal)
	kit.bench(model, 32, 0.15, -27, -math.pi / 2)
	kit.bench(model, 32, 0.15, -21, -math.pi / 2)
	signBoard(model, "🚏 JEEPNEY TERMINAL\n(coming soon)", 33.5, 9.6, -24, 12, 2, math.pi / 2, COLORS.blue)
	box(model, "JeepneyStopLine", 38.6, 0.12, -30, 43.4, 0.135, -29.7, COLORS.yellow)
	box(model, "JeepneyStopLine", 38.6, 0.12, -17.3, 43.4, 0.135, -17, COLORS.yellow)
	box(model, "JeepneyStopLine", 43.1, 0.12, -30, 43.4, 0.135, -17, COLORS.yellow)

	-- Trees in planters (south corners) and benches facing the middle
	for _, spot in { { -28, -28 }, { 24, -30 } } do
		disc(model, "Planter", spot[1], spot[2], 0, 1, 6, COLORS.stone, Enum.Material.Concrete)
		disc(model, "PlanterSoil", spot[1], spot[2], 0, 1.1, 5.2, COLORS.grass, Enum.Material.Grass)
		kit.tree(model, spot[1], spot[2], 1.1)
	end
	kit.bench(model, -8, 0.15, -30, math.pi)
	kit.bench(model, 8, 0.15, -30, math.pi)

	-- Low hedges along the plaza edge, open at the crossings and the jeepney terminal
	for _, side in { -1, 1 } do
		for _, seg in { { -35, -17 }, { 17, 35 } } do
			box(model, "Hedge", seg[1], 0, side * 35.5, seg[2], 1.4, side * 36.5, COLORS.green, Enum.Material.Grass)
			if not (side == 1 and seg[2] < 0) then
				box(model, "Hedge", side * 35.5, 0, seg[1], side * 36.5, 1.4, seg[2], COLORS.green, Enum.Material.Grass)
			end
		end
	end
	for _, spot in { { -15.5, 36 }, { 15.5, 36 }, { -15.5, -36 }, { 15.5, -36 }, { -36, 15.5 }, { -36, -15.5 }, { 36, 15.5 }, { -36, 36 }, { 36, 36 }, { -36, -36 }, { 36, -36 } } do
		kit.lampPost(model, spot[1], spot[2])
	end

	-- Signpost (south of the spawn): one blade per place, pointing its real way
	local px, pz = 0, -16
	pillar(model, "SignpostPole", px, pz, 0, 13.5, 0.5, COLORS.metal, Enum.Material.Metal)
	ball(model, "SignpostTop", 1, px, 13.8, pz, COLORS.yellow)
	local places = {
		{ "🛍️ Bayan Mall", 0, 146 },
		{ "🏰 Veterans Parc", 120, 100 },
		{ "🍞 Bakery & 🏪 Market", 137, 34 },
		{ "⭕ Rotonda", 206, 0 },
		{ "🏘️ Heights II", 150, -92 },
		{ "🏀 Covered Court", 76, -71 },
		{ "🏘️ Bayan Heights", 0, -92 },
		{ "🏛️ Town Hall", -150, 0 },
		{ "🌳 Bayan Park", -89, 75 },
	}
	for i, place in places do
		local yaw = math.atan2(-(place[3] - pz), place[2] - px)
		local frame = CFrame.new(px, 12.6 - (i - 1) * 1.1, pz) * CFrame.Angles(0, yaw, 0)
		local blade = part(model, "SignBlade", Vector3.new(7, 0.9, 0.2), frame * CFrame.new(3.8, 0, 0), COLORS.green)
		blade.CanCollide = false
		surfaceText(blade, Enum.NormalId.Front, place[1], COLORS.white)
		surfaceText(blade, Enum.NormalId.Back, place[1], COLORS.white)
		local tip = part(model, "SignTip", Vector3.new(0.7, 0.9, 0.25), frame * CFrame.new(7.65, 0, 0), COLORS.yellow)
		tip.CanCollide = false
	end

	-- Welcome arch over the south road, just outside the ring
	pillar(model, "ArchPillar", -12, -58, 0, 14, 2, COLORS.stone, Enum.Material.Marble)
	pillar(model, "ArchPillar", 12, -58, 0, 14, 2, COLORS.stone, Enum.Material.Marble)
	local arch = box(model, "ArchBeam", -14, 14, -59, 14, 17.5, -57, COLORS.green)
	surfaceText(arch, Enum.NormalId.Front, "WELCOME TO BAYAN", COLORS.yellow)
	surfaceText(arch, Enum.NormalId.Back, "MABUHAY! WELCOME TO BAYAN", COLORS.yellow)
end

------------------------------------------------------------------------
-- Bayan Park (north-west)
------------------------------------------------------------------------

-- A playground centered at (lx, lz): sandbox, slide, swings (sit-able) and a see-saw.
-- It covers x lx-12..lx+12 and z lz-8..lz+8.
local function playground(model, lx, lz)
	box(model, "Sandbox", lx - 12, 0, lz - 8, lx + 12, 0.2, lz + 8, COLORS.sand, Enum.Material.Sand)
	-- Slide: platform on posts, a ladder, and a tilted slide
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			pillar(model, "SlidePost", lx - 6 + dx, lz + dz, 0, 5, 0.3, COLORS.yellow)
		end
	end
	box(model, "SlidePlatform", lx - 7.2, 4.6, lz - 1.2, lx - 4.8, 5, lz + 1.2, COLORS.red)
	for y = 1, 4 do
		box(model, "LadderRung", lx - 7.2, y, lz - 1.3, lx - 4.8, y + 0.2, lz - 1.1, COLORS.metal, Enum.Material.Metal)
	end
	part(model, "Slide", Vector3.new(2, 0.3, 7), CFrame.new(lx - 6, 2.6, lz + 4.2) * CFrame.Angles(math.rad(38), 0, 0), COLORS.blue, Enum.Material.SmoothPlastic)
	-- Swings (you can sit on them)
	local sx = lx + 4
	for _, dz in { -3, 3 } do
		part(model, "SwingFrame", Vector3.new(0.3, 7, 0.3), CFrame.new(sx - 1, 3.4, lz + dz) * CFrame.Angles(0, 0, math.rad(12)), COLORS.metal, Enum.Material.Metal)
		part(model, "SwingFrame", Vector3.new(0.3, 7, 0.3), CFrame.new(sx + 1, 3.4, lz + dz) * CFrame.Angles(0, 0, math.rad(-12)), COLORS.metal, Enum.Material.Metal)
	end
	box(model, "SwingBar", sx - 0.2, 6.8, lz - 3.2, sx + 0.2, 7.1, lz + 3.2, COLORS.metal, Enum.Material.Metal)
	for _, dz in { -1.5, 1.5 } do
		box(model, "SwingRope", sx - 0.05, 2.4, lz + dz - 0.05, sx + 0.05, 6.8, lz + dz + 0.05, COLORS.metal)
		part(model, "SwingSeat", Vector3.new(1.4, 0.2, 1), CFrame.new(sx, 2.3, lz + dz) * CFrame.Angles(0, math.rad(90), 0), COLORS.red, nil, "Seat")
	end
	-- See-saw
	box(model, "SeesawBase", lx + 8.5, 0, lz - 0.4, lx + 9.5, 1.2, lz + 0.4, COLORS.metal, Enum.Material.Metal)
	part(model, "SeesawPlank", Vector3.new(8, 0.3, 1), CFrame.new(lx + 9, 1.4, lz) * CFrame.Angles(0, 0, math.rad(10)), COLORS.yellow)
end

local function buildPark(model)
	local x1, x2, z1, z2 = -110, -40, 40, 110
	-- Hedge around the park, with an opening on the plaza side
	box(model, "Hedge", x1, 0, z1, x2 - 18, 1.6, z1 + 1, COLORS.green, Enum.Material.Grass)
	box(model, "Hedge", x2 - 8, 0, z1, x2, 1.6, z1 + 1, COLORS.green, Enum.Material.Grass)
	box(model, "Hedge", x1, 0, z2 - 1, x2, 1.6, z2, COLORS.green, Enum.Material.Grass)
	box(model, "Hedge", x1, 0, z1, x1 + 1, 1.6, z2, COLORS.green, Enum.Material.Grass)
	box(model, "Hedge", x2 - 1, 0, z1, x2, 1.6, z2, COLORS.green, Enum.Material.Grass)
	signBoard(model, "🌳 BAYAN PARK", x2 - 13, 5, z1 + 0.5, 12, 2.5, 0, COLORS.green)
	pillar(model, "GatePost", x2 - 18.5, z1 + 0.5, 0, 6, 0.8, COLORS.stone)
	pillar(model, "GatePost", x2 - 7.5, z1 + 0.5, 0, 6, 0.8, COLORS.stone)

	-- Walking path loop
	local p = 5
	box(model, "ParkPath", x1 + p, 0, z1 + p, x2 - p, 0.12, z1 + p + 3, COLORS.sidewalk, Enum.Material.Concrete)
	box(model, "ParkPath", x1 + p, 0, z2 - p - 3, x2 - p, 0.12, z2 - p, COLORS.sidewalk, Enum.Material.Concrete)
	box(model, "ParkPath", x1 + p, 0, z1 + p, x1 + p + 3, 0.12, z2 - p, COLORS.sidewalk, Enum.Material.Concrete)
	box(model, "ParkPath", x2 - p - 3, 0, z1 + p, x2 - p, 0.12, z2 - p, COLORS.sidewalk, Enum.Material.Concrete)
	box(model, "ParkPath", x2 - 16, 0, z1, x2 - 10, 0.12, z1 + p, COLORS.sidewalk, Enum.Material.Concrete)

	-- Pond with rocks
	local px, pz = -88, 88
	local pond = disc(model, "Pond", px, pz, 0, 0.2, 18, COLORS.water, Enum.Material.Glass)
	pond.Transparency = 0.2
	for a = 0, 330, 30 do
		local r = math.rad(a)
		ball(model, "Rock", 1.6, px + math.cos(r) * 9.5, 0.3, pz + math.sin(r) * 9.5, Color3.fromRGB(130, 130, 125), Enum.Material.Slate)
	end

	playground(model, -62, 62)

	-- Bahay kubo (nipa hut) on stilts
	local kx, kz = -96, 54
	for _, dx in { -3, 3 } do
		for _, dz in { -3, 3 } do
			pillar(model, "KuboStilt", kx + dx, kz + dz, 0, 3, 0.5, COLORS.bamboo, Enum.Material.Wood)
		end
	end
	box(model, "KuboFloor", kx - 3.5, 3, kz - 3.5, kx + 3.5, 3.3, kz + 3.5, COLORS.bamboo, Enum.Material.WoodPlanks)
	box(model, "KuboWall", kx - 3.3, 3.3, kz - 3.3, kx + 3.3, 6.5, kz - 3, COLORS.bamboo, Enum.Material.Wood)
	box(model, "KuboWall", kx - 3.3, 3.3, kz - 3.3, kx - 3, 6.5, kz + 3.3, COLORS.bamboo, Enum.Material.Wood)
	box(model, "KuboWall", kx + 3, 3.3, kz - 3.3, kx + 3.3, 6.5, kz + 3.3, COLORS.bamboo, Enum.Material.Wood)
	for i, size in { 9, 7, 5, 3 } do
		local y = 6.5 + (i - 1) * 0.9
		box(model, "KuboRoof", kx - size / 2, y, kz - size / 2, kx + size / 2, y + 0.9, kz + size / 2, COLORS.thatch, Enum.Material.Grass)
	end

	-- Flower beds, picnic tables, benches, trees and lamps
	local flowerColors = { Color3.fromRGB(240, 110, 150), Color3.fromRGB(250, 210, 70), Color3.fromRGB(245, 245, 245), Color3.fromRGB(200, 90, 200) }
	for i, spot in { { -75, 75 }, { -55, 95 }, { -100, 72 } } do
		box(model, "FlowerBed", spot[1] - 3, 0, spot[2] - 2, spot[1] + 3, 0.6, spot[2] + 2, COLORS.darkWood, Enum.Material.Wood)
		for x = spot[1] - 2.2, spot[1] + 2.2, 1.1 do
			ball(model, "Flower", 0.8, x, 0.9, spot[2] + ((i % 2) - 0.5), flowerColors[(math.floor(x) % #flowerColors) + 1])
		end
	end
	for _, spot in { { -78, 58 }, { -70, 100 } } do
		box(model, "PicnicTable", spot[1] - 2.5, 2.4, spot[2] - 1.5, spot[1] + 2.5, 2.7, spot[2] + 1.5, COLORS.wood, Enum.Material.Wood)
		box(model, "TableLeg", spot[1] - 0.3, 0, spot[2] - 0.3, spot[1] + 0.3, 2.4, spot[2] + 0.3, COLORS.darkWood)
		kit.bench(model, spot[1], 0, spot[2] - 2.8, math.pi)
		kit.bench(model, spot[1], 0, spot[2] + 2.8, 0)
	end
	kit.bench(model, -88, 0, 76, math.pi) -- by the pond
	for _, spot in { { -104, 46 }, { -104, 104 }, { -46, 104 }, { -60, 80 }, { -84, 100 }, { -100, 88 } } do
		kit.tree(model, spot[1], spot[2], 1.1)
	end
	for _, spot in { { -60, 46 }, { -104, 75 }, { -75, 104 } } do
		kit.lampPost(model, spot[1], spot[2])
	end
end

------------------------------------------------------------------------
-- Covered court (south-east)
------------------------------------------------------------------------

-- A 40 x 26 covered court from its south-west corner (x1, z1); bleachers on the z1 side.
local function buildCourt(model, x1, z1, title)
	x1, z1 = x1 or 40, z1 or -70
	local x2, z2 = x1 + 40, z1 + 26
	box(model, "CourtFloor", x1, 0, z1, x2, 0.2, z2, Color3.fromRGB(60, 120, 170), Enum.Material.Concrete)
	box(model, "CourtInner", x1 + 2, 0.2, z1 + 2, x2 - 2, 0.22, z2 - 2, Color3.fromRGB(200, 110, 60), Enum.Material.Concrete)
	local function line(lx1, lz1, lx2, lz2)
		box(model, "CourtLine", lx1, 0.22, lz1, lx2, 0.24, lz2, COLORS.white)
	end
	line(x1 + 2, z1 + 2, x2 - 2, z1 + 2.3)
	line(x1 + 2, z2 - 2.3, x2 - 2, z2 - 2)
	line(x1 + 2, z1 + 2, x1 + 2.3, z2 - 2)
	line(x2 - 2.3, z1 + 2, x2 - 2, z2 - 2)
	line((x1 + x2) / 2 - 0.15, z1 + 2, (x1 + x2) / 2 + 0.15, z2 - 2)

	-- Hoops at both ends
	local cz = (z1 + z2) / 2
	for _, side in { { x1 + 1, 1 }, { x2 - 1, -1 } } do
		local hx, dir = side[1], side[2]
		pillar(model, "HoopPole", hx, cz, 0, 10, 0.5, COLORS.metal, Enum.Material.Metal)
		box(model, "Backboard", hx + dir * 0.5 - 0.15, 8.5, cz - 2.5, hx + dir * 0.5 + 0.15, 11.5, cz + 2.5, COLORS.white)
		local rimX = hx + dir * 1.6
		box(model, "Rim", rimX - 0.9, 9.2, cz - 0.9, rimX + 0.9, 9.3, cz - 0.75, Color3.fromRGB(240, 110, 30))
		box(model, "Rim", rimX - 0.9, 9.2, cz + 0.75, rimX + 0.9, 9.3, cz + 0.9, Color3.fromRGB(240, 110, 30))
		box(model, "Rim", rimX - 0.9, 9.2, cz - 0.9, rimX - 0.75, 9.3, cz + 0.9, Color3.fromRGB(240, 110, 30))
		box(model, "Rim", rimX + 0.75, 9.2, cz - 0.9, rimX + 0.9, 9.3, cz + 0.9, Color3.fromRGB(240, 110, 30))
	end

	-- Roof on columns, and the sign
	for _, x in { x1, (x1 + x2) / 2, x2 } do
		for _, z in { z1, z2 } do
			pillar(model, "CourtColumn", x, z, 0, 14, 1.2, COLORS.stone)
		end
	end
	box(model, "CourtRoof", x1 - 2, 14, z1 - 2, x2 + 2, 14.6, z2 + 2, Color3.fromRGB(160, 50, 45), Enum.Material.Metal)
	signBoard(model, title or "🏀 BARANGAY COVERED COURT", (x1 + x2) / 2, 16.5, z2 + 2, 24, 3, 0, COLORS.blue)

	-- Bleachers along one side (you can sit on them)
	for row = 0, 2 do
		local y = 0.8 + row * 1.2
		local z = z1 - 2 - row * 1.8
		box(model, "BleacherStep", x1 + 4, 0, z - 0.9, x2 - 4, y, z + 0.9, COLORS.stone, Enum.Material.Concrete)
		part(model, "BleacherSeat", Vector3.new(x2 - x1 - 8, 0.3, 1.6), CFrame.new((x1 + x2) / 2, y + 0.15, z) * CFrame.Angles(0, math.pi, 0), COLORS.yellow, nil, "Seat")
	end
end

------------------------------------------------------------------------
-- Rotonda: the east road ends in a loop past the bakery, so it turns back
-- instead of dead-ending. A raised island in the middle with a monument.
------------------------------------------------------------------------

local function buildRotonda(model)
	local cx, cz = 206, 0
	-- Layers from the outside in: sidewalk, white curb, road ring, island
	disc(model, "RotondaSidewalk", cx, cz, 0, 0.15, 48, COLORS.sidewalk, Enum.Material.Concrete)
	disc(model, "RotondaCurb", cx, cz, 0, 0.2, 40.6, COLORS.white)
	disc(model, "RotondaRoad", cx, cz, 0, 0.21, 40, COLORS.asphalt, Enum.Material.Asphalt)
	box(model, "RotondaEntry", 180, 0, -10, 190, 0.21, 10, COLORS.asphalt, Enum.Material.Asphalt) -- joins the east road
	for i = 0, 15 do -- dashed lane line around the ring
		local a = i * math.pi / 8
		part(model, "LaneLine", Vector3.new(0.4, 0.04, 3), CFrame.new(cx + math.cos(a) * 15, 0.22, cz + math.sin(a) * 15) * CFrame.Angles(0, -a, 0), COLORS.line)
	end

	-- The island: curb, grass, a ring of flowers and the Bayan Monument
	disc(model, "IslandCurb", cx, cz, 0, 0.7, 20.6, COLORS.stone, Enum.Material.Concrete)
	disc(model, "IslandGrass", cx, cz, 0, 0.8, 20, COLORS.grass, Enum.Material.Grass)
	local flowerColors = { Color3.fromRGB(240, 110, 150), Color3.fromRGB(250, 210, 70), Color3.fromRGB(245, 245, 245) }
	for i = 0, 11 do
		local a = i * math.pi / 6
		ball(model, "Flower", 1.2, cx + math.cos(a) * 8, 1.3, cz + math.sin(a) * 8, flowerColors[i % #flowerColors + 1])
	end
	local base = box(model, "MonumentBase", cx - 2.5, 0.8, cz - 2.5, cx + 2.5, 2.6, cz + 2.5, COLORS.stone, Enum.Material.Marble)
	surfaceText(base, Enum.NormalId.Left, "BAYAN ROTONDA", COLORS.darkWood) -- faces the road in
	box(model, "MonumentShaft", cx - 0.9, 2.6, cz - 0.9, cx + 0.9, 14, cz + 0.9, COLORS.stone, Enum.Material.Marble)
	ball(model, "MonumentTop", 2.2, cx, 14.8, cz, COLORS.yellow, Enum.Material.Neon)

	-- Lamps on the outer sidewalk, and trees beyond the far side
	for _, a in { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 } do
		kit.lampPost(model, cx + math.cos(a) * 22, cz + math.sin(a) * 22)
	end
	for _, spot in { { cx + 32, cz }, { cx + 22, cz + 26 }, { cx + 22, cz - 26 } } do
		kit.tree(model, spot[1], spot[2], 1)
	end
end

------------------------------------------------------------------------
-- Bayan Public Market (next to the bakery): every business stall is here
------------------------------------------------------------------------

local storeLots = {} -- the market stalls, filled when the city is built

-- One market stall. angle turns it so its front (local -Z) faces the aisle.
-- Returns what the Business module needs to show FOR SALE or the owner's name.
local function buildMarketStall(model, n, x, z, angle, tarpColor)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	part(model, "StallFloor", Vector3.new(10, 0.3, 7), at(0, 0.15, 0), COLORS.stone, Enum.Material.Concrete)
	part(model, "StallBack", Vector3.new(10, 8, 0.4), at(0, 4, 3.3), COLORS.white, Enum.Material.Plaster)
	part(model, "StallSide", Vector3.new(0.4, 8, 7), at(-4.8, 4, 0), COLORS.white, Enum.Material.Plaster)
	part(model, "StallSide", Vector3.new(0.4, 8, 7), at(4.8, 4, 0), COLORS.white, Enum.Material.Plaster)
	part(model, "StallCounter", Vector3.new(9, 3.2, 1.2), at(0, 1.6, -2.6), COLORS.wood, Enum.Material.WoodPlanks)
	part(model, "StallShelf", Vector3.new(9, 0.3, 1.2), at(0, 4.5, 2.6), COLORS.darkWood, Enum.Material.Wood)
	part(model, "StallTarp", Vector3.new(11, 0.3, 8.5), at(0, 8.4, -0.6) * CFrame.Angles(math.rad(8), 0, 0), tarpColor, Enum.Material.Fabric)
	local numberPlate = part(model, "StallNumber", Vector3.new(2, 1, 0.1), at(3.5, 7, 3.05), COLORS.green)
	surfaceText(numberPlate, Enum.NormalId.Front, ("STALL %d"):format(n), COLORS.white)

	local shutter = part(model, "StallShutter", Vector3.new(9.2, 6.2, 0.2), at(0, 3.4, -3.4), Color3.fromRGB(160, 165, 170), Enum.Material.DiamondPlate)
	local shutterText = surfaceText(shutter, Enum.NormalId.Front, "FOR SALE", COLORS.metal)

	local board = part(model, "StallSign", Vector3.new(9.5, 1.8, 0.3), at(0, 9.9, -4.2), COLORS.red)
	local signTexts = {
		surfaceText(board, Enum.NormalId.Front, "FOR SALE", COLORS.white),
		surfaceText(board, Enum.NormalId.Back, "FOR SALE", COLORS.white),
	}

	local promptSpot = part(model, "StallSpot_" .. n, Vector3.new(8, 4, 1), at(0, 2, -4.6), COLORS.white)
	promptSpot.Transparency = 1
	promptSpot.CanCollide = false
	promptSpot.CanQuery = false

	-- A floating line above the sign: "For sale: 2000 coins" or "Owner: Juan"
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 60
	local ownerText = Instance.new("TextLabel")
	ownerText.Size = UDim2.fromScale(1, 1)
	ownerText.BackgroundTransparency = 1
	ownerText.Font = Enum.Font.FredokaOne
	ownerText.TextScaled = true
	ownerText.TextColor3 = Color3.new(1, 1, 1)
	ownerText.TextStrokeTransparency = 0.2
	ownerText.Text = ""
	ownerText.Parent = gui
	gui.Parent = board

	return { prompt = promptSpot, signTexts = signTexts, shutterText = shutterText, ownerText = ownerText }
end

-- The market and the bakery stand side by side on one front line (z 20), both
-- facing the east road: market x 96-134, bakery x 138-178 (BakeryMap). A paved
-- front walk joins them into one commercial block.
local function buildMarket(model)
	local x1, x2, z1, z2 = 96, 134, 20, 60 -- under the roof
	box(model, "MarketFloor", x1, 0, z1, x2, 0.14, z2, COLORS.sidewalk, Enum.Material.Concrete)
	box(model, "FrontWalk", 90, 0, 14, 180, 0.15, z1, COLORS.plaza, Enum.Material.Brick) -- in front of the market and bakery
	box(model, "FrontWalkEdge", 90, 0, z1 - 0.3, x1, 0.25, z1, COLORS.white)

	-- Two rows of 3 stalls facing a straight aisle (x 107 to 123) that runs in from the road
	local tarps = { COLORS.red, COLORS.blue, COLORS.yellow, COLORS.green, Color3.fromRGB(240, 130, 40), Color3.fromRGB(150, 80, 170) }
	local n = 0
	for _, row in { { 103.5, -math.pi / 2 }, { 126.5, math.pi / 2 } } do
		for _, z in { 28, 40, 52 } do
			n += 1
			storeLots[n] = buildMarketStall(model, n, row[1], z, row[2], tarps[n])
		end
	end

	-- Roof on columns along both sides, and lights over the aisle
	for _, x in { x1, x2 } do
		for _, z in { z1, 40, z2 } do
			pillar(model, "MarketColumn", x, z, 0, 12.5, 1, COLORS.stone)
		end
	end
	box(model, "MarketRoof", x1 - 1.5, 12.5, z1 - 1.5, x2 + 1.5, 13.2, z2 + 1.5, Color3.fromRGB(60, 120, 90), Enum.Material.Metal)
	for _, z in { 28, 40, 52 } do
		kit.lamp(model, 115, 12.49, z)
	end

	-- Entrance arch over the aisle, facing the road
	for _, x in { 106.4, 123.6 } do
		pillar(model, "ArchPillar", x, z1, 0, 11, 1.2, COLORS.stone, Enum.Material.Marble)
	end
	local arch = box(model, "MarketArch", 105.6, 11, z1 - 0.4, 124.4, 13.4, z1 + 0.4, COLORS.green)
	surfaceText(arch, Enum.NormalId.Front, "🏪 BAYAN PUBLIC MARKET", COLORS.yellow)
	surfaceText(arch, Enum.NormalId.Back, "🏪 BAYAN PUBLIC MARKET", COLORS.yellow)

	-- Planters along the front walk
	for _, x in { 93, 100, 130, 136 } do -- 136: between the market and the bakery
		box(model, "Planter", x - 1.2, 0, 15.5, x + 1.2, 1.2, 17.5, COLORS.stone, Enum.Material.Concrete)
		ball(model, "Shrub", 2.2, x, 1.9, 16.5, COLORS.green, Enum.Material.Grass)
	end
end

------------------------------------------------------------------------
-- Houses and the sari-sari store (south)
------------------------------------------------------------------------

-- House styles: main walls, upper floor, accent, and trim colors.
local HOUSE_STYLES = {
	{ main = Color3.fromRGB(245, 243, 238), upper = Color3.fromRGB(150, 110, 80), trim = Color3.fromRGB(45, 45, 50) }, -- white + wood
	{ main = Color3.fromRGB(235, 232, 225), upper = Color3.fromRGB(70, 75, 82), trim = Color3.fromRGB(30, 30, 35) }, -- cream + charcoal
	{ main = Color3.fromRGB(240, 238, 232), upper = Color3.fromRGB(150, 170, 150), trim = Color3.fromRGB(50, 55, 50) }, -- white + sage
	{ main = Color3.fromRGB(225, 220, 212), upper = Color3.fromRGB(245, 243, 238), trim = Color3.fromRGB(110, 75, 50) }, -- greige + white
	{ main = Color3.fromRGB(248, 246, 240), upper = Color3.fromRGB(120, 140, 165), trim = Color3.fromRGB(40, 45, 55) }, -- white + blue gray
}

-- A premium 2-storey house on its lot, facing its front (local -Z) toward the
-- street. The lot runs from x -11 to 13 and from the front wall (z -12) to the
-- back (z 7.5). address (optional) goes on a plate by the door, like "Blk 2 Lot 5".
local function house(model, x, z, angle, style, address)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	local stone = Color3.fromRGB(110, 105, 100)
	local glassColor = Color3.fromRGB(150, 190, 215)
	local concrete = Color3.fromRGB(200, 198, 192)

	-- Driveway and walkway
	part(model, "Driveway", Vector3.new(6, 0.2, 17), at(9, 0.1, -3.5), concrete, Enum.Material.Concrete)
	part(model, "Walkway", Vector3.new(2.5, 0.2, 5), at(-2.75, 0.1, -9.5), concrete, Enum.Material.Concrete)

	-- Ground floor, stone accent, door and window
	part(model, "HouseMain", Vector3.new(16, 9, 14), at(-2, 4.5, 0), style.main, Enum.Material.Plaster)
	part(model, "StoneAccent", Vector3.new(3, 9.2, 0.5), at(-8.5, 4.6, -7.2), stone, Enum.Material.Slate)
	part(model, "FrontDoor", Vector3.new(2.5, 6, 0.2), at(-2.75, 3, -7.1), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	local side = part(model, "DoorGlass", Vector3.new(0.8, 6, 0.2), at(-0.9, 3, -7.1), glassColor, Enum.Material.Glass)
	side.Transparency = 0.3
	part(model, "DoorCanopy", Vector3.new(5, 0.4, 2.2), at(-2.75, 6.7, -8.1), style.trim, Enum.Material.Metal)
	local window = part(model, "Window", Vector3.new(5, 4.5, 0.2), at(3, 4.5, -7.1), glassColor, Enum.Material.Glass)
	window.Transparency = 0.25
	part(model, "WindowFrame", Vector3.new(5.4, 0.3, 0.3), at(3, 2.15, -7.15), style.trim, Enum.Material.Metal)
	part(model, "WindowFrame", Vector3.new(5.4, 0.3, 0.3), at(3, 6.85, -7.15), style.trim, Enum.Material.Metal)
	part(model, "WindowFrame", Vector3.new(0.2, 4.5, 0.3), at(3, 4.5, -7.15), style.trim, Enum.Material.Metal)

	-- A door lamp that glows at night (CityLights)
	local lamp = part(model, "DoorLamp", Vector3.new(0.5, 0.8, 0.3), at(-4.6, 5.4, -7.3), Color3.fromRGB(215, 215, 210), Enum.Material.Glass)
	CollectionService:AddTag(lamp, "NightLight")
	if address then
		local plate = part(model, "AddressPlate", Vector3.new(2.2, 0.8, 0.05), at(-8.5, 6.6, -7.48), Color3.fromRGB(245, 245, 240))
		surfaceText(plate, Enum.NormalId.Front, address, Color3.fromRGB(40, 40, 45))
	end

	-- Upper floor (sticks out a little at the front), with windows
	part(model, "HouseUpper", Vector3.new(16, 8, 15), at(-2, 13, -0.5), style.upper, Enum.Material.Plaster)
	local bigWindow = part(model, "UpperWindow", Vector3.new(7, 4, 0.2), at(-4.5, 13, -8.1), glassColor, Enum.Material.Glass)
	bigWindow.Transparency = 0.2
	CollectionService:AddTag(bigWindow, "NightLight") -- lights on inside at night
	part(model, "UpperWindowFrame", Vector3.new(7.4, 0.3, 0.3), at(-4.5, 10.85, -8.15), style.trim, Enum.Material.Metal)
	part(model, "UpperWindowFrame", Vector3.new(7.4, 0.3, 0.3), at(-4.5, 15.15, -8.15), style.trim, Enum.Material.Metal)
	local smallWindow = part(model, "UpperWindow", Vector3.new(2.6, 4, 0.2), at(2.8, 13, -8.1), glassColor, Enum.Material.Glass)
	smallWindow.Transparency = 0.2

	-- Garage with a roll-up door, and a balcony on top
	part(model, "Garage", Vector3.new(6, 9, 12), at(9, 4.5, -1), style.main, Enum.Material.Plaster)
	part(model, "GarageDoor", Vector3.new(5.2, 7, 0.2), at(9, 3.5, -7.1), Color3.fromRGB(150, 150, 155), Enum.Material.DiamondPlate)
	part(model, "BalconyFloor", Vector3.new(6.4, 0.4, 12.4), at(9, 9.2, -1), style.trim, Enum.Material.Concrete)
	local rail = part(model, "BalconyGlass", Vector3.new(6, 1.8, 0.15), at(9, 10.3, -7.05), glassColor, Enum.Material.Glass)
	rail.Transparency = 0.45
	local sideRail = part(model, "BalconyGlass", Vector3.new(0.15, 1.8, 12), at(12.05, 10.3, -1), glassColor, Enum.Material.Glass)
	sideRail.Transparency = 0.45
	part(model, "BalconyRail", Vector3.new(6.2, 0.15, 0.25), at(9, 11.25, -7.05), style.trim, Enum.Material.Metal)
	local slider = part(model, "BalconyDoor", Vector3.new(0.2, 6, 4), at(6.05, 12.4, -3), glassColor, Enum.Material.Glass)
	slider.Transparency = 0.3

	-- Flat roof with overhangs
	part(model, "Roof", Vector3.new(18, 0.6, 17), at(-2, 17.3, -0.5), Color3.fromRGB(60, 62, 68), Enum.Material.Concrete)
	part(model, "RoofEdge", Vector3.new(18.2, 0.5, 0.3), at(-2, 17.85, -9), style.trim, Enum.Material.Metal)

	-- Low stone front wall with railings, a gap for the walkway, and a sliding gate
	for _, seg in { { -11, -4 }, { -1.5, 6 }, { 12, 13 } } do
		local width = seg[2] - seg[1]
		local cx = (seg[1] + seg[2]) / 2
		part(model, "FrontWall", Vector3.new(width, 1.2, 0.6), at(cx, 0.6, -12), stone, Enum.Material.Slate)
		part(model, "FrontRail", Vector3.new(width, 0.15, 0.15), at(cx, 2.6, -12), style.trim, Enum.Material.Metal)
		for px = seg[1] + 0.3, seg[2] - 0.2, 1.2 do
			part(model, "RailBar", Vector3.new(0.1, 1.4, 0.1), at(px, 1.9, -12), style.trim, Enum.Material.Metal)
		end
	end
	part(model, "SlidingGate", Vector3.new(6, 2.4, 0.15), at(9, 1.4, -12.25), style.trim, Enum.Material.Metal)

	-- Shrubs along the front wall
	for _, sx in { -9.5, -7, -5.3, 1, 4 } do
		local shrub = part(model, "Shrub", Vector3.new(1.8, 1.8, 1.8), at(sx, 0.9, -10.8), Color3.fromRGB(70, 135, 75), Enum.Material.Grass)
		shrub.Shape = Enum.PartType.Ball
	end

	-- Name sign above the front wall (Housing sets it: FOR RENT, or the renter's name)
	part(model, "HouseSignPost", Vector3.new(0.2, 3.9, 0.2), at(-9.6, 1.95, -12.5), style.trim, Enum.Material.Metal)
	part(model, "HouseSignPost", Vector3.new(0.2, 3.9, 0.2), at(-5.4, 1.95, -12.5), style.trim, Enum.Material.Metal)
	local sign = part(model, "HouseSign", Vector3.new(5, 1.2, 0.15), at(-7.5, 4.1, -12.5), Color3.fromRGB(250, 248, 240))
	local signText = surfaceText(sign, Enum.NormalId.Front, "FOR RENT", Color3.fromRGB(40, 40, 45))

	-- An invisible spot at the front door for the "Enter House" prompt
	local doorSpot = part(model, "DoorSpot", Vector3.new(3, 5, 1), at(-2.75, 2.7, -8.2), Color3.new(1, 1, 1))
	doorSpot.Transparency = 1
	doorSpot.CanCollide = false
	doorSpot.CanQuery = false

	return {
		doorSpot = doorSpot,
		signText = signText,
		outside = at(-2.75, 3, -10.5), -- on the walkway, facing the street
		address = address or "a house",
	}
end

-- Bayan Heights: 5 streets crossing Rizal Avenue, premium houses on both sides
-- of each street (10 rows, 8 houses per row), back to back between streets.
-- Lots are 28 studs wide; each house stands 22 studs from its street.
local STREETS = {
	{ name = "Sampaguita St.", z = -130 },
	{ name = "Narra St.", z = -194 },
	{ name = "Mabini St.", z = -258 },
	{ name = "Ilang-Ilang St.", z = -322 },
	{ name = "Acacia St.", z = -386 },
}
local HOUSE_X = { -112, -84, -56, -28, 28, 56, 84, 112 } -- west to east
local HOUSE_SETBACK = 22 -- from the street's center line to the house's lot center

-- A street sign at a corner: green blades for the street and for the avenue.
local function streetSign(model, x, z, streetName, block, avenue)
	pillar(model, "StreetSignPole", x, z, 0, 9, 0.25, COLORS.metal, Enum.Material.Metal)
	signBoard(model, ("%s  •  Blk %d"):format(streetName, block), x, 8.4, z, 8, 0.9, 0, COLORS.green)
	signBoard(model, avenue or "Rizal Ave.", x, 7.3, z, 5, 0.9, math.pi / 2, COLORS.green)
end

local houseLots = {} -- every house, for renting (Housing), filled when the city is built
local leasingOffices = {} -- { area, rentSpot, endRentSpot } for each subdivision's Leasing Office

-- Adds a house to the rent list. area is a key of Config.Housing.areas.
local function addLot(lot, area)
	lot.area = area
	table.insert(houseLots, lot)
end

local function buildHouses(model)
	local count = 0
	for block, street in STREETS do
		-- North-side houses face the street to the south (angle 0); south-side
		-- houses face it to the north (angle pi). Lots 1-8 north, 9-16 south.
		for i, x in HOUSE_X do
			count += 1
			local styleA = HOUSE_STYLES[count % #HOUSE_STYLES + 1]
			local styleB = HOUSE_STYLES[(count + 2) % #HOUSE_STYLES + 1]
			addLot(house(model, x, street.z + HOUSE_SETBACK, 0, styleA, ("Blk %d Lot %d"):format(block, i)), "heights")
			addLot(house(model, x, street.z - HOUSE_SETBACK, math.pi, styleB, ("Blk %d Lot %d"):format(block, i + 8)), "heights")
		end
		-- The street, in two halves on each side of Rizal Avenue
		road(model, true, -128, -10, street.z, 12, { noTrees = true, sidewalkTop = 0.17 })
		road(model, true, 10, 128, street.z, 12, { noTrees = true, sidewalkTop = 0.17 })
		streetSign(model, 12, street.z + 8, street.name, block)
		streetSign(model, -12, street.z - 8, street.name, block)
	end
end

------------------------------------------------------------------------
-- Parking lots, fences and gates
------------------------------------------------------------------------

local carRandom = Random.new(7) -- fixed seed: the same parked cars every time

-- A straight fence from a to b. alongX = true: along X at z = c; else along Z at x = c.
-- gaps = { { from, to }, ... } along the fence (sorted), for gates.
local function fenceLine(model, alongX, a, b, c, gaps, color, height)
	color = color or Color3.fromRGB(40, 40, 45)
	height = height or 4
	local function rect(name, u1, u2, y1, y2, thick)
		if alongX then
			return box(model, name, u1, y1, c - thick, u2, y2, c + thick, color, Enum.Material.Metal)
		end
		return box(model, name, c - thick, y1, u1, c + thick, y2, u2, color, Enum.Material.Metal)
	end
	local segments, start = {}, a
	for _, gap in gaps or {} do
		if gap[1] > start then
			table.insert(segments, { start, gap[1] })
		end
		start = math.max(start, gap[2])
	end
	if start < b then
		table.insert(segments, { start, b })
	end
	for _, seg in segments do
		local u1, u2 = seg[1], seg[2]
		rect("FenceRail", u1, u2, height * 0.3, height * 0.3 + 0.2, 0.08)
		rect("FenceRail", u1, u2, height - 0.3, height - 0.1, 0.08)
		for u = u1, u2, 3 do
			rect("FencePost", u - 0.15, u + 0.15, 0, height, 0.15)
		end
		for u = u1 + 0.75, u2 - 0.5, 0.75 do -- thin bars between posts
			rect("FenceBar", u - 0.04, u + 0.04, 0.2, height - 0.2, 0.04)
		end
	end
end

-- A simple parked car facing its front (local -Z) the way of the angle.
local function car(model, x, z, angle, color)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	part(model, "CarBody", Vector3.new(3, 1.3, 6), base * CFrame.new(0, 1.15, 0), color, Enum.Material.SmoothPlastic)
	local cabin = part(model, "CarCabin", Vector3.new(2.7, 1.2, 3.2), base * CFrame.new(0, 2.4, 0.3), Color3.fromRGB(40, 55, 70), Enum.Material.Glass)
	cabin.Transparency = 0.15
	for _, dx in { -1.45, 1.45 } do
		for _, dz in { -1.9, 1.9 } do
			part(model, "CarWheel", Vector3.new(0.6, 1.3, 1.3), base * CFrame.new(dx, 0.65, dz), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, nil).Shape = Enum.PartType.Cylinder
		end
	end
	part(model, "CarLight", Vector3.new(2.4, 0.3, 0.1), base * CFrame.new(0, 1.3, -3.02), Color3.fromRGB(255, 245, 210), Enum.Material.Neon)
end

-- A parking lot with two rows of bays (along X) facing a middle driving lane.
-- walkway = { from, to } on X with no bays (a footpath across the lot), or nil.
local function parkingLot(model, x1, x2, z1, z2, walkway, carChance)
	local bayDepth, bayWidth = 7, 3.6
	box(model, "ParkingLot", x1, 0, z1, x2, 0.13, z2, COLORS.asphalt, Enum.Material.Asphalt)
	local carColors = {
		Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 35),
		Color3.fromRGB(60, 100, 180), Color3.fromRGB(190, 190, 195), Color3.fromRGB(240, 200, 60),
	}
	local function inWalkway(x)
		return walkway ~= nil and x > walkway[1] - 2 and x < walkway[2] + 2
	end
	for x = x1 + 1, x2 - bayWidth, bayWidth do
		for _, row in { { z1, z1 + bayDepth, math.pi }, { z2 - bayDepth, z2, 0 } } do
			if not inWalkway(x) and not inWalkway(x + bayWidth) then
				box(model, "BayLine", x - 0.1, 0.13, row[1], x + 0.1, 0.15, row[2], COLORS.line)
				if carRandom:NextNumber() < (carChance or 0.3) then
					car(model, x + bayWidth / 2, (row[1] + row[2]) / 2, row[3], carColors[carRandom:NextInteger(1, #carColors)])
				end
			end
		end
	end
	-- Driving lane arrows (dashes) and lamp posts down the middle
	local mid = (z1 + z2) / 2
	for x = x1 + 4, x2 - 6, 8 do
		if not inWalkway(x) then
			box(model, "LaneLine", x, 0.13, mid - 0.15, x + 4, 0.15, mid + 0.15, COLORS.line)
		end
	end
	for x = x1 + 12, x2 - 6, 26 do
		if not inWalkway(x) then
			kit.lampPost(model, x, mid)
		end
	end
	-- A footpath with zebra stripes across the lot
	if walkway then
		box(model, "Walkway", walkway[1], 0, z1, walkway[2], 0.16, z2, COLORS.sidewalk, Enum.Material.Concrete)
		for z = z1 + bayDepth + 1, z2 - bayDepth - 2, 2 do
			box(model, "ZebraStripe", walkway[1] + 0.5, 0.16, z, walkway[2] - 0.5, 0.18, z + 1, COLORS.white)
		end
	end
end

-- A parking entrance: guard booth, boom barrier (raised) and a sign arch.
-- (x, z) is the middle of the entrance; angle turns it; width is the opening.
local function parkingGate(model, x, z, angle, width, title)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local half = width / 2
	-- Arch over the entrance
	for _, dx in { -half - 0.6, half + 0.6 } do
		part(model, "GatePillar", Vector3.new(1.2, 10, 1.2), base * CFrame.new(dx, 5, 0), COLORS.stone, Enum.Material.Marble)
	end
	local arch = part(model, "GateArch", Vector3.new(width + 2.4, 2.4, 0.6), base * CFrame.new(0, 10.6, 0), COLORS.blue)
	surfaceText(arch, Enum.NormalId.Front, title, COLORS.white)
	surfaceText(arch, Enum.NormalId.Back, title, COLORS.white)
	-- Guard booth outside the opening
	local bx = -half - 4
	part(model, "GuardBooth", Vector3.new(4, 7, 4), base * CFrame.new(bx, 3.5, -3), COLORS.white, Enum.Material.Plaster)
	local window = part(model, "BoothWindow", Vector3.new(3, 2, 0.2), base * CFrame.new(bx, 4.6, -0.95), Color3.fromRGB(175, 215, 235), Enum.Material.Glass)
	window.Transparency = 0.3
	part(model, "BoothRoof", Vector3.new(5, 0.4, 5), base * CFrame.new(bx, 7.2, -3), COLORS.blue, Enum.Material.Metal)
	local guardSign = part(model, "BoothSign", Vector3.new(3.6, 0.8, 0.1), base * CFrame.new(bx, 6.3, -0.93), COLORS.yellow)
	surfaceText(guardSign, Enum.NormalId.Back, "GUARD", COLORS.metal)
	-- Boom barrier, raised (no cars to stop yet)
	local postX = -half + 0.6
	part(model, "BarrierPost", Vector3.new(0.9, 3, 0.9), base * CFrame.new(postX, 1.5, 0.8), COLORS.yellow)
	local lift = math.rad(78)
	local length = width - 1.5
	local armCenter = CFrame.new(postX + math.cos(lift) * length / 2, 3 + math.sin(lift) * length / 2, 0.8)
	part(model, "BarrierArm", Vector3.new(length, 0.3, 0.3), base * armCenter * CFrame.Angles(0, 0, lift), COLORS.red)
end

-- A solid concrete perimeter wall with a cap and pillars, like a subdivision wall.
-- alongX = true: along X at z = c; else along Z at x = c. gaps = { { from, to } }.
local function wallLine(model, alongX, a, b, c, gaps, height)
	height = height or 6
	local wallColor, capColor = Color3.fromRGB(235, 228, 210), Color3.fromRGB(150, 120, 90)
	local function rect(name, u1, u2, y1, y2, thick, color)
		if alongX then
			return box(model, name, u1, y1, c - thick, u2, y2, c + thick, color, Enum.Material.Concrete)
		end
		return box(model, name, c - thick, y1, u1, c + thick, y2, u2, color, Enum.Material.Concrete)
	end
	local segments, start = {}, a
	for _, gap in gaps or {} do
		if gap[1] > start then
			table.insert(segments, { start, gap[1] })
		end
		start = math.max(start, gap[2])
	end
	if start < b then
		table.insert(segments, { start, b })
	end
	for _, seg in segments do
		local u1, u2 = seg[1], seg[2]
		rect("PerimeterWall", u1, u2, 0, height, 0.4, wallColor)
		rect("WallCap", u1, u2, height, height + 0.3, 0.6, capColor)
		for u = u1, u2, 12 do
			rect("WallPillar", u - 0.6, u + 0.6, 0, height + 0.6, 0.7, capColor)
		end
		rect("WallPillar", u2 - 0.6, u2 + 0.6, 0, height + 0.6, 0.7, capColor)
	end
end

-- Bayan Heights: the houses inside a walled, gated subdivision.
-- The road from the plaza enters through the gate (guard house, barrier, arch)
-- and becomes Rizal Avenue, which runs to the far end across all 5 streets.
local function buildSubdivision(model)
	local x1, x2, z1, z2 = -130, 130, -420, -92
	buildHouses(model)
	road(model, false, z1, z2, 0, 20, { noTrees = true }) -- Rizal Avenue (inside the walls)
	local entrySign = box(model, "SubdivisionMap", 16, 0, z2 - 6, 17, 6, z2 - 2, COLORS.green)
	surfaceText(entrySign, Enum.NormalId.Left, "BAYAN HEIGHTS\nRizal Ave.\nBlk 1 Sampaguita\nBlk 2 Narra\nBlk 3 Mabini\nBlk 4 Ilang-Ilang\nBlk 5 Acacia", COLORS.white)

	-- Leasing Office just inside the gate, facing Rizal Avenue (rent a house here)
	local officeColor = Color3.fromRGB(245, 240, 230)
	box(model, "LeasingOffice", -40, 0, -99, -24, 7, -93, officeColor, Enum.Material.Plaster)
	box(model, "LeasingRoof", -41, 7, -100, -23, 7.6, -92.4, Color3.fromRGB(60, 62, 68), Enum.Material.Concrete)
	for _, z in { -97.2, -94.8 } do
		local window = box(model, "LeasingWindow", -24.1, 2.5, z - 0.9, -23.9, 5.5, z + 0.9, Color3.fromRGB(150, 190, 215), Enum.Material.Glass)
		window.Transparency = 0.3
	end
	local officeSign = box(model, "LeasingSign", -23.9, 7.7, -98.5, -23.7, 9.3, -93.5, COLORS.green)
	surfaceText(officeSign, Enum.NormalId.Right, "🏠 LEASING OFFICE", COLORS.white)
	local rentSpot = box(model, "RentSpot", -23.6, 0.2, -98, -23.2, 4, -96.4, COLORS.white)
	local endRentSpot = box(model, "EndRentSpot", -23.6, 0.2, -95.6, -23.2, 4, -94, COLORS.white)
	for _, spot in { rentSpot, endRentSpot } do
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
	end
	table.insert(leasingOffices, { area = "heights", rentSpot = rentSpot, endRentSpot = endRentSpot })
	wallLine(model, true, x1, x2, z2, { { -14, 14 } }) -- the plaza side, with the entrance
	wallLine(model, true, x1, x2, z1)
	wallLine(model, false, z1, z2, x1)
	wallLine(model, false, z1, z2, x2)
	parkingGate(model, 0, z2, 0, 26, "BAYAN HEIGHTS SUBDIVISION")
	-- Welcome planters on both sides of the gate (outside)
	for _, x in { -20, 20 } do
		box(model, "GatePlanter", x - 2.5, 0, z2 + 1.5, x + 2.5, 1.2, z2 + 4.5, COLORS.stone, Enum.Material.Concrete)
		for dx = -1.6, 1.6, 1.6 do
			ball(model, "Flower", 1, x + dx, 1.7, z2 + 3, Color3.fromRGB(240, 110, 150))
		end
	end
end

------------------------------------------------------------------------
-- Bayan Heights II: starter row houses (cheaper rent), east of Bayan Heights
------------------------------------------------------------------------

local ROW_COLORS = {
	Color3.fromRGB(170, 215, 190), -- mint
	Color3.fromRGB(245, 195, 160), -- peach
	Color3.fromRGB(165, 200, 235), -- sky
	Color3.fromRGB(245, 225, 140), -- lemon
	Color3.fromRGB(205, 180, 225), -- lilac
	Color3.fromRGB(240, 175, 180), -- rose
}

-- A small 2-storey row house (townhouse) unit, 14 studs wide, facing its front
-- (local -Z) toward the street. The lot runs from x -7 to 7 and from the front
-- fence (z -10) to the back wall (z 7). Units stand side by side in a row.
local function rowHouse(model, x, z, angle, color, address)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	-- A block from local corners (like kit.box, but turned with the house)
	local function piece(name, x1, y1, z1, x2, y2, z2, pieceColor, material)
		return part(model, name, Vector3.new(x2 - x1, y2 - y1, z2 - z1), at((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), pieceColor, material)
	end
	local white = Color3.fromRGB(245, 245, 240)
	local trim = Color3.fromRGB(60, 60, 65)
	local glassColor = Color3.fromRGB(150, 190, 215)

	-- Tiled front yard
	piece("FrontYard", -7, 0, -10, 7, 0.15, -5, Color3.fromRGB(205, 200, 190), Enum.Material.Slate)

	-- Body: ground floor, upper floor (sticks out a little), white pilasters between units
	piece("RowHouseMain", -6.6, 0, -5, 6.6, 8, 7, color, Enum.Material.Plaster)
	piece("RowHouseUpper", -6.6, 8, -5.6, 6.6, 15, 7, color, Enum.Material.Plaster)
	piece("FloorBand", -6.6, 7.8, -5.8, 6.6, 8.3, -5.6, white)
	for _, px in { -7, 6.6 } do
		piece("Pilaster", px, 0, -5.8, px + 0.4, 15.6, 7, white, Enum.Material.Concrete)
	end
	piece("Roof", -6.6, 15, -5.6, 6.6, 15.4, 7, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	piece("Parapet", -6.6, 15, -5.9, 6.6, 16.4, -5.5, white, Enum.Material.Concrete)

	-- Door, a grilled window and a "media agua" canopy over both
	piece("FrontDoor", -4.5, 0.15, -5.1, -1.5, 7, -5, Color3.fromRGB(120, 75, 45), Enum.Material.Wood)
	local window = piece("Window", 0.5, 2.5, -5.1, 5.5, 6, -5, glassColor, Enum.Material.Glass)
	window.Transparency = 0.25
	for gx = 0.9, 5.2, 0.9 do
		piece("WindowGrill", gx - 0.06, 2.5, -5.25, gx + 0.06, 6, -5.15, trim, Enum.Material.Metal)
	end
	piece("WindowGrill", 0.5, 4.2, -5.25, 5.5, 4.32, -5.15, trim, Enum.Material.Metal)
	part(model, "MediaAgua", Vector3.new(11, 0.3, 1.8), at(-0.5, 7.4, -5.9) * CFrame.Angles(math.rad(-12), 0, 0), trim, Enum.Material.Metal)
	local lamp = piece("DoorLamp", -0.75, 5.6, -5.3, -0.25, 6.4, -5, Color3.fromRGB(215, 215, 210), Enum.Material.Glass)
	CollectionService:AddTag(lamp, "NightLight")
	if address then
		local plate = piece("AddressPlate", -6.5, 5.6, -5.08, -4.6, 6.3, -5.03, white)
		surfaceText(plate, Enum.NormalId.Front, address, trim)
	end
	piece("PlantPot", -6.3, 0.15, -6.6, -5.3, 1.1, -5.6, Color3.fromRGB(170, 100, 60))
	local plantAt = at(-5.8, 1.6, -6.1).Position
	ball(model, "Plant", 1.4, plantAt.X, plantAt.Y, plantAt.Z, Color3.fromRGB(70, 140, 80), Enum.Material.Grass)

	-- Upper floor: two windows with sills (one lit at night) and an aircon unit
	for i, wx in { { -5.6, -1.4 }, { 1.4, 5.6 } } do
		local upper = piece("UpperWindow", wx[1], 9.6, -5.7, wx[2], 13.2, -5.6, glassColor, Enum.Material.Glass)
		upper.Transparency = 0.2
		if i == 1 then
			CollectionService:AddTag(upper, "NightLight")
		end
		piece("WindowSill", wx[1] - 0.2, 9.3, -6, wx[2] + 0.2, 9.6, -5.6, white)
		piece("WindowHead", wx[1] - 0.2, 13.2, -5.9, wx[2] + 0.2, 13.5, -5.6, white)
	end
	piece("Aircon", 2.6, 8.4, -6.4, 4.4, 9.2, -5.6, white)

	-- Low front wall with a grill fence, and an opening in front of the door
	for _, seg in { { -7, -4.5 }, { -1.5, 7 } } do
		piece("FenceWall", seg[1], 0, -10.3, seg[2], 1.2, -9.7, white, Enum.Material.Concrete)
		piece("FenceRail", seg[1], 3, -10.08, seg[2], 3.15, -9.92, trim, Enum.Material.Metal)
		for px = seg[1] + 0.4, seg[2] - 0.2, 1.2 do
			piece("FenceBar", px - 0.05, 1.2, -10.05, px + 0.05, 3, -9.95, trim, Enum.Material.Metal)
		end
	end

	-- Name sign on the fence (Housing sets it: FOR RENT, or the renter's name)
	for _, px in { 1.6, 5.4 } do
		piece("HouseSignPost", px - 0.1, 1.2, -10.5, px + 0.1, 4.6, -10.3, trim, Enum.Material.Metal)
	end
	local sign = piece("HouseSign", 1, 3.4, -10.55, 6, 4.6, -10.4, white)
	local signText = surfaceText(sign, Enum.NormalId.Front, "FOR RENT", trim)

	-- An invisible spot at the front door for the "Enter House" prompt
	local doorSpot = part(model, "DoorSpot", Vector3.new(3, 5, 1), at(-3, 2.7, -5.8), Color3.new(1, 1, 1))
	doorSpot.Transparency = 1
	doorSpot.CanCollide = false
	doorSpot.CanQuery = false

	return {
		doorSpot = doorSpot,
		signText = signText,
		outside = at(-3, 3, -8), -- in the front yard, facing the street
		address = address or "a row house",
	}
end

-- Inside the walls: Bonifacio Ave. runs south from the gate road past 4 streets
-- (Blk 6-9, 5 row houses on each side), to a covered court and a playground.
local HEIGHTS2_STREETS = {
	{ name = "Gumamela St.", z = -170 },
	{ name = "Molave St.", z = -230 },
	{ name = "Rosal St.", z = -290 },
	{ name = "Kamagong St.", z = -350 },
}
local ROW_X = { 177, 191, 205, 219, 233 } -- west to east, side by side
local ROW_SETBACK = 20.5 -- from the street's center line to the unit's center
local AVENUE_X = 150 -- Bonifacio Ave.

-- A separate subdivision with its own walls and main gate (north, at Bonifacio Ave.).
-- Its road comes from the east road (by the bakery): south on x 118, east on z -60.
local function buildHeightsII(model)
	local x1, x2, z1, z2 = 136, 254, -420, -92 -- a grass strip (x 130..136) between it and Bayan Heights
	local count = 0
	for i, street in HEIGHTS2_STREETS do
		local block = 5 + i
		for lot, x in ROW_X do
			count += 1
			local north = ROW_COLORS[count % #ROW_COLORS + 1]
			local south = ROW_COLORS[(count + 3) % #ROW_COLORS + 1]
			addLot(rowHouse(model, x, street.z + ROW_SETBACK, 0, north, ("Blk %d Lot %d"):format(block, lot)), "heights2")
			addLot(rowHouse(model, x, street.z - ROW_SETBACK, math.pi, south, ("Blk %d Lot %d"):format(block, lot + 5)), "heights2")
		end
		road(model, true, AVENUE_X + 7, x2 - 2, street.z, 12, { noTrees = true, sidewalkTop = 0.17 })
		streetSign(model, AVENUE_X + 9, street.z + 8, street.name, block, "Bonifacio Ave.")
	end
	-- Bonifacio Ave. runs out through the main gate, then the road to town:
	-- east on z -60 to x 118, then north on x 118 to the east road (across from the market)
	road(model, false, z1 + 2, -54, AVENUE_X, 14, { noTrees = true }) -- Bonifacio Ave.
	road(model, true, 112, AVENUE_X - 7, -60, 12, { noTrees = true, sidewalkTop = 0.17 })
	road(model, false, -54, -10, 118, 12, { noTrees = true, sidewalkTop = 0.17 })
	box(model, "Sidewalk", 108, 0, -70, 112, 0.17, -54, COLORS.sidewalk, Enum.Material.Concrete) -- corner

	-- Main gate (arch, guard house outside, barrier) and its own walls
	parkingGate(model, AVENUE_X, z2, math.pi, 20, "BAYAN HEIGHTS II")
	wallLine(model, true, x1, x2, z2, { { AVENUE_X - 11, AVENUE_X + 11 } })
	wallLine(model, true, x1, x2, z1)
	wallLine(model, false, z1, z2, x1)
	wallLine(model, false, z1, z2, x2)
	for _, x in { AVENUE_X - 16, AVENUE_X + 22 } do -- welcome planters outside the gate
		box(model, "GatePlanter", x - 2.5, 0, z2 + 1.5, x + 2.5, 1.2, z2 + 4.5, COLORS.stone, Enum.Material.Concrete)
		for dx = -1.6, 1.6, 1.6 do
			ball(model, "Flower", 1, x + dx, 1.7, z2 + 3, Color3.fromRGB(240, 180, 60))
		end
	end

	-- A sign on the east road (by the bakery) pointing down the road
	pillar(model, "SignPole", 127, -16, 0, 8, 0.25, COLORS.metal, Enum.Material.Metal)
	local pointer = part(model, "HeightsIISign", Vector3.new(7, 1.4, 0.2), CFrame.new(127, 7.4, -16) * CFrame.Angles(0, math.pi / 2, 0), COLORS.blue)
	surfaceText(pointer, Enum.NormalId.Front, "🏘️ To BAYAN HEIGHTS II", COLORS.white)

	-- Map just inside the gate, facing Bonifacio Ave.
	local map = box(model, "SubdivisionMap", 162, 0, -104, 163, 6, -99, COLORS.green)
	surfaceText(map, Enum.NormalId.Left, "BAYAN HEIGHTS II\nBonifacio Ave.\nBlk 6 Gumamela\nBlk 7 Molave\nBlk 8 Rosal\nBlk 9 Kamagong\n🏀 Court & Playground (south)", COLORS.white)

	-- Leasing Office II on Bonifacio Ave., just inside the gate (rents Heights II houses only)
	local officeColor = Color3.fromRGB(245, 240, 230)
	box(model, "LeasingOffice", 163, 0, -126, 179, 7, -120, officeColor, Enum.Material.Plaster)
	box(model, "LeasingRoof", 162.4, 7, -127, 180, 7.6, -119, Color3.fromRGB(60, 62, 68), Enum.Material.Concrete)
	for _, z in { -124.2, -121.8 } do
		local window = box(model, "LeasingWindow", 162.9, 2.5, z - 0.9, 163.1, 5.5, z + 0.9, Color3.fromRGB(150, 190, 215), Enum.Material.Glass)
		window.Transparency = 0.3
	end
	local officeSign = box(model, "LeasingSign", 162.7, 7.7, -125.5, 162.9, 9.3, -120.5, COLORS.green)
	surfaceText(officeSign, Enum.NormalId.Left, "🏠 LEASING OFFICE II", COLORS.white)
	local rentSpot = box(model, "RentSpot", 162.2, 0.2, -125, 162.6, 4, -123.4, COLORS.white)
	local endRentSpot = box(model, "EndRentSpot", 162.2, 0.2, -122.6, 162.6, 4, -121, COLORS.white)
	for _, spot in { rentSpot, endRentSpot } do
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
	end
	table.insert(leasingOffices, { area = "heights2", rentSpot = rentSpot, endRentSpot = endRentSpot })

	-- A small green by the gate: trees, a flower bed with benches, lamps
	for _, spot in { { 192, -102 }, { 216, -102 }, { 240, -102 }, { 192, -132 }, { 240, -132 } } do
		kit.tree(model, spot[1], spot[2], 1)
	end
	box(model, "FlowerBed", 211, 0, -119, 221, 0.6, -115, COLORS.darkWood, Enum.Material.Wood)
	for fx = 212, 220, 1.6 do
		ball(model, "Flower", 0.9, fx, 0.95, -117, Color3.fromRGB(240, 110, 150))
	end
	kit.bench(model, 216, 0, -122, math.pi)
	kit.bench(model, 216, 0, -112, 0)
	kit.lampPost(model, 200, -117)
	kit.lampPost(model, 232, -117)

	-- South end: covered court and playground
	buildCourt(model, 170, -408, "🏀 HEIGHTS II COVERED COURT")
	playground(model, 232, -396)
	kit.lampPost(model, 216, -396)
	kit.bench(model, 232, 0, -409, math.pi)
end

------------------------------------------------------------------------
-- Veterans Parc: an exclusive gated village (north-east), with the Admin Mansion
------------------------------------------------------------------------

local adminHouse = nil -- the Admin Mansion's door, sign and spots, filled when built

-- Turns a local position on a lot into world X and Z (for kit.tree, which takes world spots).
local function worldXZ(base, dx, dz)
	local p = (base * CFrame.new(dx, 0, dz)).Position
	return p.X, p.Z
end

-- A large villa (for sale later). Front faces local -Z; lot x -13..13, z -14..10.
local function villa(model, x, z, angle, style)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	local stone = Color3.fromRGB(110, 105, 100)
	local glassColor = Color3.fromRGB(150, 190, 215)
	part(model, "VillaDriveway", Vector3.new(6, 0.2, 10), at(10, 0.1, -9), Color3.fromRGB(200, 198, 192), Enum.Material.Concrete)
	part(model, "VillaMain", Vector3.new(20, 10, 16), at(-3, 5, 0), style.main, Enum.Material.Plaster)
	part(model, "VillaUpper", Vector3.new(20, 9, 16), at(-3, 14.5, 0), style.upper, Enum.Material.Plaster)
	part(model, "VillaGarage", Vector3.new(6, 10, 14), at(10, 5, 1), style.main, Enum.Material.Plaster)
	part(model, "VillaGarageDoor", Vector3.new(5, 7, 0.2), at(10, 3.5, -6.1), Color3.fromRGB(150, 150, 155), Enum.Material.DiamondPlate)
	part(model, "VillaRoof", Vector3.new(28, 0.8, 18), at(0, 19.4, 0), Color3.fromRGB(55, 57, 62), Enum.Material.Concrete)
	part(model, "VillaDoor", Vector3.new(3, 7, 0.2), at(-6, 3.5, -8.1), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	local window = part(model, "VillaWindow", Vector3.new(6, 6, 0.2), at(1, 5, -8.1), glassColor, Enum.Material.Glass)
	window.Transparency = 0.25
	local upper = part(model, "VillaUpperWindow", Vector3.new(14, 5, 0.2), at(-3, 14.5, -8.1), glassColor, Enum.Material.Glass)
	upper.Transparency = 0.2
	CollectionService:AddTag(upper, "NightLight")
	local rail = part(model, "VillaBalcony", Vector3.new(6, 2, 0.15), at(10, 11, -6.05), glassColor, Enum.Material.Glass)
	rail.Transparency = 0.45
	for _, seg in { { -13, -7.5 }, { -4.5, 6 }, { 12, 13 } } do
		part(model, "VillaFrontWall", Vector3.new(seg[2] - seg[1], 1.4, 0.6), at((seg[1] + seg[2]) / 2, 0.7, -14), stone, Enum.Material.Slate)
	end
	local sign = part(model, "VillaSign", Vector3.new(5, 1.6, 0.2), at(-9.5, 4.2, -14.5), Color3.fromRGB(250, 248, 240))
	surfaceText(sign, Enum.NormalId.Front, "FOR SALE\n(coming soon)", Color3.fromRGB(180, 40, 40))
	part(model, "VillaSignPost", Vector3.new(0.2, 4, 0.2), at(-11.5, 2, -14.5), style.trim, Enum.Material.Metal)
	part(model, "VillaSignPost", Vector3.new(0.2, 4, 0.2), at(-7.5, 2, -14.5), style.trim, Enum.Material.Metal)
	local tx, tz = worldXZ(base, -10, -11)
	kit.tree(model, tx, tz, 0.7)
end

-- The Admin Mansion. Front faces local -Z; grounds x -30..30, z -26..24.
local function adminMansion(model, x, z, angle)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, angle, 0)
	local function at(dx, dy, dz)
		return base * CFrame.new(dx, dy, dz)
	end
	local white = Color3.fromRGB(248, 246, 240)
	local cream = Color3.fromRGB(240, 232, 214)
	local stone = Color3.fromRGB(120, 112, 104)
	local dark = Color3.fromRGB(45, 45, 52)
	local gold = Color3.fromRGB(225, 185, 70)
	local glassColor = Color3.fromRGB(150, 190, 215)
	local function glassPart(name, size, cframe, night)
		local g = part(model, name, size, cframe, glassColor, Enum.Material.Glass)
		g.Transparency = 0.25
		if night then
			CollectionService:AddTag(g, "NightLight")
		end
		return g
	end

	-- Forecourt paving and a fountain
	part(model, "Forecourt", Vector3.new(16, 0.22, 16), at(0, 0.11, -18), Color3.fromRGB(215, 205, 190), Enum.Material.Pavement)
	local fountainBase = part(model, "FountainBase", Vector3.new(1.2, 7, 7), at(0, 0.6, -18) * CFrame.Angles(0, 0, math.rad(90)), stone, Enum.Material.Marble)
	fountainBase.Shape = Enum.PartType.Cylinder
	local water = part(model, "FountainWater", Vector3.new(0.3, 6, 6), at(0, 1.1, -18) * CFrame.Angles(0, 0, math.rad(90)), COLORS.water, Enum.Material.Glass)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.25
	local column = part(model, "FountainColumn", Vector3.new(3, 0.8, 0.8), at(0, 2.7, -18) * CFrame.Angles(0, 0, math.rad(90)), stone, Enum.Material.Marble)
	column.Shape = Enum.PartType.Cylinder

	-- Front wall with a grand gate, the name sign, and a car gate (x 18.4..28.6)
	for _, seg in { { -30, -6 }, { 6, 17.2 } } do
		local cx = (seg[1] + seg[2]) / 2
		part(model, "MansionWall", Vector3.new(seg[2] - seg[1], 2.2, 0.8), at(cx, 1.1, -26), stone, Enum.Material.Slate)
		part(model, "MansionRail", Vector3.new(seg[2] - seg[1], 0.2, 0.2), at(cx, 3.6, -26), dark, Enum.Material.Metal)
		for px = seg[1] + 0.5, seg[2] - 0.4, 1.2 do
			part(model, "MansionRailBar", Vector3.new(0.12, 1.4, 0.12), at(px, 2.9, -26), dark, Enum.Material.Metal)
		end
	end
	for _, gx in { -6.6, 6.6 } do
		part(model, "GatePillar", Vector3.new(1.6, 7, 1.6), at(gx, 3.5, -26), white, Enum.Material.Marble)
		local lampBall = part(model, "GateLamp", Vector3.new(1.2, 1.2, 1.2), at(gx, 7.6, -26), Color3.fromRGB(255, 235, 185), Enum.Material.Neon)
		lampBall.Shape = Enum.PartType.Ball
	end
	local nameBoard = part(model, "MansionNameSign", Vector3.new(12, 2, 0.4), at(0, 7.4, -26), dark, Enum.Material.Metal)
	local nameFront = surfaceText(nameBoard, Enum.NormalId.Front, "🏰 THE ADMIN'S RESIDENCE", gold)
	local nameBack = surfaceText(nameBoard, Enum.NormalId.Back, "🏰 THE ADMIN'S RESIDENCE", gold)
	-- Hedges around the sides and back
	part(model, "Hedge", Vector3.new(0.8, 3, 50), at(-30, 1.5, -1), COLORS.green, Enum.Material.Grass)
	part(model, "Hedge", Vector3.new(0.8, 3, 50), at(30, 1.5, -1), COLORS.green, Enum.Material.Grass)
	part(model, "Hedge", Vector3.new(60, 3, 0.8), at(0, 1.5, 24), COLORS.green, Enum.Material.Grass)

	-- The house: two big floors, a smaller third floor, a roof crown
	part(model, "MansionMain", Vector3.new(40, 20, 30), at(0, 10, 5), white, Enum.Material.Plaster)
	part(model, "MansionBand", Vector3.new(40.4, 0.8, 30.4), at(0, 10, 5), cream, Enum.Material.Plaster)
	part(model, "MansionTop", Vector3.new(30, 9, 22), at(0, 24.5, 7), cream, Enum.Material.Plaster)
	part(model, "MansionRoof", Vector3.new(32, 1, 24), at(0, 29.5, 7), dark, Enum.Material.Slate)
	part(model, "MansionRoofCrown", Vector3.new(20, 1, 14), at(0, 30.5, 7), dark, Enum.Material.Slate)
	part(model, "MansionMainRoof", Vector3.new(42, 0.8, 32), at(0, 20.4, 5), dark, Enum.Material.Slate)

	-- Columned portico with a balcony on top
	for _, cx in { -12, -4, 4, 12 } do
		local col = part(model, "Column", Vector3.new(19.6, 1.6, 1.6), at(cx, 9.8, -13) * CFrame.Angles(0, 0, math.rad(90)), white, Enum.Material.Marble)
		col.Shape = Enum.PartType.Cylinder
	end
	part(model, "PorticoBalcony", Vector3.new(30, 1, 5.5), at(0, 20.1, -12.25), cream, Enum.Material.Marble)
	local balconyGlass = part(model, "BalconyGlass", Vector3.new(30, 2, 0.2), at(0, 21.6, -14.9), glassColor, Enum.Material.Glass)
	balconyGlass.Transparency = 0.45
	part(model, "BalconyRail", Vector3.new(30.2, 0.2, 0.3), at(0, 22.65, -14.9), gold, Enum.Material.Metal)

	-- Grand entrance and windows
	part(model, "MansionDoor", Vector3.new(5, 9, 0.3), at(0, 4.5, -10.15), Color3.fromRGB(95, 60, 35), Enum.Material.Wood)
	part(model, "DoorHandle", Vector3.new(0.2, 1.2, 0.3), at(0.4, 4.5, -10.35), gold, Enum.Material.Metal)
	glassPart("Transom", Vector3.new(5, 2, 0.3), at(0, 10, -10.15), true)
	for _, wx in { -15, -9, 9, 15 } do
		glassPart("Window", Vector3.new(4, 6, 0.2), at(wx, 5, -10.1), false)
		glassPart("Window", Vector3.new(4, 5, 0.2), at(wx, 15, -10.1), true)
	end
	for _, wx in { -9, 0, 9 } do
		glassPart("TopWindow", Vector3.new(5, 4, 0.2), at(wx, 24.5, -4.1), true)
	end

	-- Garage wing for two cars
	part(model, "GarageWing", Vector3.new(10, 10, 18), at(25, 5, 2), white, Enum.Material.Plaster)
	part(model, "GarageRoof", Vector3.new(10.6, 0.6, 18.6), at(25, 10.3, 2), dark, Enum.Material.Slate)
	for _, gx in { 22.5, 27.5 } do
		part(model, "GarageDoor", Vector3.new(4, 7, 0.2), at(gx, 3.5, -7.1), Color3.fromRGB(160, 160, 165), Enum.Material.DiamondPlate)
	end
	-- Admin parking: a motor court from the car gate to the garage, with 3 reserved
	-- bays on its west side (2 cars parked) and a sign
	part(model, "MotorCourt", Vector3.new(18, 0.2, 18.5), at(21, 0.1, -16.25), Color3.fromRGB(205, 200, 192), Enum.Material.Pavement)
	for _, gx in { 17.8, 29.2 } do
		part(model, "CarGatePillar", Vector3.new(1.2, 6, 1.2), at(gx, 3, -26), white, Enum.Material.Marble)
	end
	part(model, "CarGate", Vector3.new(10, 2.6, 0.15), at(12, 1.6, -25.3), dark, Enum.Material.Metal) -- slid open
	for _, bz in { -24, -20.4, -16.8, -13.2 } do
		part(model, "BayLine", Vector3.new(7, 0.05, 0.2), at(15.5, 0.22, bz), COLORS.white)
	end
	-- Bay 1 (z -22.2) is for the drivable admin car (AdminCar); bay 2 has a parked car
	local px, pz = worldXZ(base, 15.5, -18.6)
	car(model, px, pz, angle + math.pi / 2, Color3.fromRGB(240, 240, 240))
	local parkingSign = part(model, "ParkingSign", Vector3.new(8, 1.4, 0.2), at(11.6, 3, -18.6) * CFrame.Angles(0, -math.pi / 2, 0), dark, Enum.Material.Metal)
	surfaceText(parkingSign, Enum.NormalId.Front, "🅿️ ADMIN PARKING", gold)
	for _, pz in { -22, -15.2 } do
		part(model, "ParkingSignPost", Vector3.new(0.2, 3, 0.2), at(11.6, 1.5, pz), dark, Enum.Material.Metal)
	end

	-- Swimming pool on the left side, with loungers
	part(model, "PoolDeck", Vector3.new(10, 0.4, 24), at(-25, 0.2, 4), Color3.fromRGB(225, 220, 210), Enum.Material.Pavement)
	local pool = part(model, "Pool", Vector3.new(7, 0.3, 19), at(-25, 0.5, 5), Color3.fromRGB(70, 170, 230), Enum.Material.Glass)
	pool.Transparency = 0.25
	for _, lz in { -9.5, -6 } do
		part(model, "Lounger", Vector3.new(2.2, 0.5, 3), at(-25, 0.75, lz), Color3.fromRGB(245, 245, 245), Enum.Material.Fabric, "Seat")
	end

	-- Gardens: trees and flower beds
	for _, spot in { { -24, -21 }, { -13, -22 }, { -26, 19 }, { 26, 19 }, { 0, 21 } } do
		local tx, tz = worldXZ(base, spot[1], spot[2])
		kit.tree(model, tx, tz, 1.1)
	end
	local flowers = { Color3.fromRGB(240, 110, 150), Color3.fromRGB(250, 210, 70), Color3.fromRGB(245, 245, 245) }
	for _, bed in { { -18, -6 }, { 6, 11 } } do
		part(model, "FlowerBed", Vector3.new(bed[2] - bed[1], 0.6, 1.6), at((bed[1] + bed[2]) / 2, 0.3, -11.6), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
		local i = 0
		for fx = bed[1] + 0.8, bed[2] - 0.6, 1.2 do
			i += 1
			local f = part(model, "Flower", Vector3.new(0.8, 0.8, 0.8), at(fx, 0.9, -11.6), flowers[i % #flowers + 1])
			f.Shape = Enum.PartType.Ball
			f.CanCollide = false
		end
	end

	-- Door spot for the "Enter House" prompt
	local doorSpot = part(model, "MansionDoorSpot", Vector3.new(5, 6, 1), at(0, 3, -11.5), Color3.new(1, 1, 1))
	doorSpot.Transparency = 1
	doorSpot.CanCollide = false
	doorSpot.CanQuery = false

	return {
		doorSpot = doorSpot,
		signTexts = { nameFront, nameBack },
		outside = at(0, 3, -12.8), -- under the portico, clear of the fountain
		address = "Veterans Parc",
		carSpot = at(15.5, 0.3, -22.2) * CFrame.Angles(0, math.pi / 2, 0), -- bay 1, nose to the sign
	}
end

local function buildVeteransParc(model)
	local x1, x2, z1, z2 = 120, 264, 63, 230
	-- Access road from the mall avenue, through the gate, and down the main drive
	road(model, true, 14, 206, 100, 14, { noTrees = true })
	-- The arrow points east from both sides (the back is read by people walking south)
	local parcSign = part(model, "SignBoard", Vector3.new(12, 2, 0.3), CFrame.new(16, 6, 112.5), COLORS.green)
	surfaceText(parcSign, Enum.NormalId.Front, "🏰 VETERANS PARC  →", COLORS.white)
	surfaceText(parcSign, Enum.NormalId.Back, "←  🏰 VETERANS PARC", COLORS.white)
	pillar(model, "SignPole", 16, 112.5, 0, 5, 0.3, COLORS.metal, Enum.Material.Metal)

	-- Walls and the grand gate (on the west side, facing the access road)
	wallLine(model, false, z1, z2, x1, { { 88, 112 } }, 7)
	wallLine(model, false, z1, z2, x2, nil, 7)
	wallLine(model, true, x1, x2, z1, nil, 7)
	wallLine(model, true, x1, x2, z2, nil, 7)
	parkingGate(model, x1, 100, -math.pi / 2, 22, "VETERANS PARC")

	-- Trees along the drive (placed between the street lamps)
	for x = 136, 184, 16 do
		kit.tree(model, x, 91, 0.9)
		kit.tree(model, x + 8, 109, 0.9)
	end

	-- 6 large villas, 3 on each side of the drive
	for i, x in { 138, 164, 190 } do
		villa(model, x, 75, math.pi, HOUSE_STYLES[i % #HOUSE_STYLES + 1]) -- south side, facing the drive
		villa(model, x, 125, 0, HOUSE_STYLES[(i + 2) % #HOUSE_STYLES + 1]) -- north side
	end

	-- The Admin Mansion at the end of the drive (facing west, toward the gate)
	box(model, "MansionApproach", 206, 0, 94, 212, 0.14, 106, Color3.fromRGB(215, 205, 190), Enum.Material.Pavement)
	adminHouse = adminMansion(model, 238, 100, math.pi / 2)
	-- Car drive from the end of the main drive to the mansion's car gate (z 71..82)
	box(model, "MansionCarDrive", 205, 0, 71, 212, 0.17, 93, COLORS.asphalt, Enum.Material.Asphalt)

	-- Path from the drive up to the clubhouse
	box(model, "ClubPath", 204, 0, 111, 208, 0.14, 150, COLORS.sidewalk, Enum.Material.Concrete)

	-- Clubhouse with a pool
	box(model, "Clubhouse", 130, 0, 152, 166, 9, 176, Color3.fromRGB(245, 240, 228), Enum.Material.Plaster)
	box(model, "ClubhouseRoof", 129, 9, 151, 167, 9.8, 177, Color3.fromRGB(60, 62, 68), Enum.Material.Slate)
	local clubSign = box(model, "ClubhouseSign", 138, 10, 150.6, 158, 12.4, 151, COLORS.green)
	surfaceText(clubSign, Enum.NormalId.Front, "🏊 VETERANS PARC CLUBHOUSE", COLORS.white)
	for _, wx in { 135, 145, 155, 162 } do
		local w = box(model, "ClubWindow", wx - 2, 2.5, 151.9, wx + 2, 6.5, 152, Color3.fromRGB(150, 190, 215), Enum.Material.Glass)
		w.Transparency = 0.3
	end
	box(model, "PoolDeck", 168, 0, 148, 212, 0.3, 180, Color3.fromRGB(225, 220, 210), Enum.Material.Pavement)
	local clubPool = box(model, "ClubPool", 173, 0.3, 153, 207, 0.55, 175, Color3.fromRGB(70, 170, 230), Enum.Material.Glass)
	clubPool.Transparency = 0.25
	for lx = 176, 204, 7 do
		part(model, "PoolLounger", Vector3.new(2.2, 0.5, 3), CFrame.new(lx, 0.55, 177.5), Color3.fromRGB(245, 245, 245), Enum.Material.Fabric, "Seat")
	end
	for _, ux in { 180, 200 } do
		pillar(model, "UmbrellaPole", ux, 150, 0.3, 6, 0.2, COLORS.metal, Enum.Material.Metal)
		disc(model, "Umbrella", ux, 150, 6, 6.3, 5, COLORS.red, Enum.Material.Fabric)
	end

	-- A small park with trees, benches and lamps
	for x = 136, 256, 20 do
		for _, z in { 196, 218 } do
			kit.tree(model, x, z, 1)
		end
	end
	for _, spot in { { 150, 207 }, { 190, 207 }, { 230, 207 }, { 236, 160 } } do
		kit.bench(model, spot[1], 0.05, spot[2], math.pi)
	end
	for _, spot in { { 170, 207 }, { 210, 207 }, { 240, 150 } } do
		kit.lampPost(model, spot[1], spot[2])
	end
end

local function buildMallParking(model)
	-- In front of Bayan Mall (the mall front is at z = 146)
	local x1, x2, z1, z2 = -86, 86, 114, 144
	parkingLot(model, x1, x2, z1, z2, { -5, 5 }, 0.32)
	box(model, "ParkingSidewalk", x1, 0, z2, x2, 0.16, 146, COLORS.sidewalk, Enum.Material.Concrete)
	-- Fence: the plaza side (with the entrance), both ends, and beside the mall
	fenceLine(model, true, x1, x2, z1 - 0.5, { { -14, 14 } })
	fenceLine(model, false, z1 - 0.5, 146, x1)
	fenceLine(model, false, z1 - 0.5, 146, x2)
	fenceLine(model, true, x1, -41, 146)
	fenceLine(model, true, 41, x2, 146)
	parkingGate(model, 0, z1 - 0.5, 0, 26, "BAYAN MALL PARKING")
end

local function buildTownHallCompound(model)
	-- An iron fence around the Town Hall and its plaza, with a main gate in front
	-- (the path at z -4..4) and a side gate to the parking lot.
	local gold = Color3.fromRGB(220, 180, 60)
	local x1, x2, z1, z2 = -170, -102, -32, 28
	fenceLine(model, false, z1, z2, x2, { { -5.5, 5.5 } }, nil, 5)
	fenceLine(model, true, x1, x2, z2, nil, nil, 5)
	fenceLine(model, false, z1, z2, x1, nil, nil, 5)
	fenceLine(model, true, x1, x2, z1, { { -124, -114 } }, nil, 5)
	for _, z in { -6.6, 6.6 } do
		pillar(model, "MainGatePillar", x2, z, 0, 9, 2, COLORS.stone, Enum.Material.Marble)
		ball(model, "PillarLamp", 1.4, x2, 9.7, z, gold, Enum.Material.Neon)
	end
	local arch = part(model, "MainGateArch", Vector3.new(0.6, 2, 14.4), CFrame.new(x2, 10.2, 0), COLORS.green)
	surfaceText(arch, Enum.NormalId.Right, "BAYAN TOWN HALL", gold)
	surfaceText(arch, Enum.NormalId.Left, "BAYAN TOWN HALL", gold)
	-- Open gate panels, swung against the fence inside
	part(model, "GatePanel", Vector3.new(4.5, 4.5, 0.15), CFrame.new(x2 - 2.6, 2.25, -5.6), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	part(model, "GatePanel", Vector3.new(4.5, 4.5, 0.15), CFrame.new(x2 - 2.6, 2.25, 5.6), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)

	-- Town Hall parking, south of the compound, through the side gate
	local px1, px2, pz1, pz2 = -170, -104, -78, -36
	box(model, "ParkingDrive", -124, 0, pz2, -114, 0.13, z1, COLORS.asphalt, Enum.Material.Asphalt)
	parkingLot(model, px1, px2, pz1, pz2, nil, 0.4)
	fenceLine(model, true, px1, px2, pz1 - 0.5)
	fenceLine(model, false, pz1 - 0.5, z1, px1)
	fenceLine(model, false, pz1 - 0.5, z1, px2 + 2)
	parkingGate(model, -119, z1, math.pi, 10, "TOWN HALL PARKING")
end

local function build()
	local model = Instance.new("Model")
	model.Name = "City"
	buildGround(model)
	-- Main roads from the town center's ring road (|x| or |z| = 50) to each place
	road(model, true, -84, -50, 0) -- west to the Town Hall
	road(model, true, 50, 184, 0, 20, { treesUntil = 90, lampGaps = { { 108, 130 } } }) -- east, past the market and bakery
	buildRotonda(model) -- the loop at its end
	road(model, false, 50, 112, 0, 20, { treesUntil = 85 }) -- north to the mall
	road(model, false, -92, -50, 0) -- south to the Bayan Heights gate
	buildPlaza(model)
	-- Bayan Park sits 14 studs west of where it was first built, to make room for the town center
	local park = Instance.new("Model")
	park.Name = "BayanPark"
	park.Parent = model
	buildPark(park)
	park:PivotTo(park:GetPivot() + Vector3.new(-14, 0, 0))
	buildCourt(model, 56, -84) -- south-east, clear of the town center
	buildMarket(model)
	buildSubdivision(model)
	buildHeightsII(model)
	buildMallParking(model)
	buildTownHallCompound(model)
	buildVeteransParc(model)
	model.Parent = workspace
	return model
end

-- Builds the city (once) and returns the litter areas and the store lots.
function CityMap.getOrBuild()
	if not workspace:FindFirstChild("City") then
		build()
	end
	return {
		storeLots = storeLots,
		houses = houseLots,
		adminHouse = adminHouse,
		leasing = leasingOffices,
		litterAreas = {
			{ cframe = CFrame.new(0, 0, -21), sizeX = 28, sizeZ = 30 }, -- plaza (south part, open paving)
			{ cframe = CFrame.new(0, 0, 44), sizeX = 96, sizeZ = 10 }, -- ring road (north side)
			{ cframe = CFrame.new(0, 0, -44), sizeX = 96, sizeZ = 10 }, -- ring road (south side)
			{ cframe = CFrame.new(-67, 0, 0), sizeX = 34, sizeZ = 26 }, -- west road
			{ cframe = CFrame.new(117, 0, 0), sizeX = 134, sizeZ = 26 }, -- east road (to the bakery)
			{ cframe = CFrame.new(0, 0, 81), sizeX = 26, sizeZ = 62 }, -- north road
			{ cframe = CFrame.new(0, 0, -71), sizeX = 26, sizeZ = 42 }, -- south road
			{ cframe = CFrame.new(0, 0, -256), sizeX = 26, sizeZ = 320 }, -- Rizal Avenue (Bayan Heights)
			{ cframe = CFrame.new(0, 0, -130), sizeX = 240, sizeZ = 16 }, -- Sampaguita St.
			{ cframe = CFrame.new(0, 0, -258), sizeX = 240, sizeZ = 16 }, -- Mabini St.
			{ cframe = CFrame.new(-89, 0, 75), sizeX = 60, sizeZ = 60 }, -- park (moved 14 west)
			{ cframe = CFrame.new(115, 0, 40), sizeX = 13, sizeZ = 36 }, -- market aisle
			{ cframe = CFrame.new(0, 0, 129), sizeX = 160, sizeZ = 12 }, -- mall parking lane
		},
	}
end

return CityMap
