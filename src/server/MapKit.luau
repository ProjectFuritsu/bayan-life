-- Building helpers for map scripts. MapKit.new(origin) returns a kit whose
-- positions are measured from `origin` (a CFrame: the building's center at
-- floor level, with its front facing local +Z).
-- (BakeryMap and MallMap have their own copies of these helpers; they can move
-- to MapKit later.)

local CollectionService = game:GetService("CollectionService")

local MapKit = {}

function MapKit.new(origin)
	local kit = {}

	-- An anchored block between two corners.
	function kit.box(parent, name, x1, y1, z1, x2, y2, z2, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
		part.CFrame = origin * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end

	function kit.glass(parent, name, x1, y1, z1, x2, y2, z2, transparency)
		local part = kit.box(parent, name, x1, y1, z1, x2, y2, z2, Color3.fromRGB(175, 215, 235), Enum.Material.Glass)
		part.Transparency = transparency or 0.5
		return part
	end

	-- An invisible part for prompts and spots.
	function kit.marker(parent, name, x1, y1, z1, x2, y2, z2)
		local part = kit.box(parent, name, x1, y1, z1, x2, y2, z2, Color3.new(1, 1, 1))
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end

	function kit.ball(parent, name, size, x, y, z, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(size, size, size)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CFrame = origin * CFrame.new(x, y, z)
		part.Parent = parent
		return part
	end

	-- A standing cylinder (pole, trunk, column) from y1 to y2.
	function kit.pillar(parent, name, x, z, y1, y2, diameter, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(y2 - y1, diameter, diameter)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CFrame = origin * CFrame.new(x, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		part.Parent = parent
		return part
	end

	-- Text on one face of a part. Returns the TextLabel.
	function kit.surfaceText(part, face, text, color)
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

	-- A floating name label above a part.
	function kit.label(part, text, extraHeight)
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

	function kit.lamp(parent, x, y, z)
		local part = kit.box(parent, "Lamp", x - 1, y - 0.4, z - 1, x + 1, y, z + 1, Color3.fromRGB(255, 242, 215), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 0.6
		light.Color = Color3.fromRGB(255, 242, 215)
		light.Parent = part
	end

	-- A street lamp post. Tagged "NightLight": it turns on at night (CityLights).
	function kit.lampPost(parent, x, z)
		kit.pillar(parent, "LampPost", x, z, 0, 9, 0.4, Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		kit.box(parent, "LampArm", x - 0.1, 8.8, z - 0.1, x + 0.1, 9.1, z + 0.1, Color3.fromRGB(50, 52, 60), Enum.Material.Metal)
		local bulb = kit.ball(parent, "LampBulb", 1.2, x, 9.4, z, Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 1
		light.Color = Color3.fromRGB(255, 225, 170)
		light.Parent = bulb
		CollectionService:AddTag(bulb, "NightLight")
	end

	function kit.tree(parent, x, z, size)
		size = size or 1
		kit.pillar(parent, "Trunk", x, z, 0, 5 * size, 0.9 * size, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
		kit.ball(parent, "Leaves", 5 * size, x, 6 * size, z, Color3.fromRGB(70, 140, 70), Enum.Material.Grass)
		kit.ball(parent, "Leaves", 3.5 * size, x + 1.2 * size, 7.6 * size, z - 0.6 * size, Color3.fromRGB(85, 155, 80), Enum.Material.Grass)
	end

	-- A bench players can sit on. angle turns it; the sitter faces the bench's front (-Z).
	function kit.bench(parent, x, y, z, angle)
		local base = origin * CFrame.new(x, y, z) * CFrame.Angles(0, angle or 0, 0)
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
		local wood, metal = Color3.fromRGB(150, 100, 60), Color3.fromRGB(70, 72, 80)
		piece("Seat", "BenchSeat", Vector3.new(6, 0.4, 1.6), CFrame.new(0, 1.9, 0), wood, Enum.Material.Wood)
		piece("Part", "BenchBack", Vector3.new(6, 1.8, 0.25), CFrame.new(0, 3, 0.75), wood, Enum.Material.Wood)
		piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(-2.6, 0.95, 0), metal, Enum.Material.Metal)
		piece("Part", "BenchLeg", Vector3.new(0.4, 1.7, 1.4), CFrame.new(2.6, 0.95, 0), metal, Enum.Material.Metal)
	end

	-- A world area (for litter): center CFrame and size, from local corners.
	function kit.area(x1, z1, x2, z2)
		return { cframe = origin * CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2), sizeX = math.abs(x2 - x1), sizeZ = math.abs(z2 - z1) }
	end

	return kit
end

return MapKit
