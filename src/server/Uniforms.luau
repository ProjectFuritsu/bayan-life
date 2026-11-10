-- Work uniforms, worn on the character only while on shift.
-- They are welded to the character, so every player can see them.
--   baker:   white chef hat and apron
--   staff:   blue polo front and an ID lanyard
--   cleanup: orange safety vest with stripes and an orange cap

local Uniforms = {}

local FOLDER_NAME = "WorkUniform"

local function piece(folder, attachTo, name, shape, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Fabric
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local BUILDERS = {}

BUILDERS.baker = function(folder, head, root)
	local white = Color3.fromRGB(250, 250, 250)
	local headTop = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	piece(folder, head, "HatBand", Enum.PartType.Cylinder, Vector3.new(0.6, 1.25, 1.25), headTop * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), white)
	piece(folder, head, "HatPuff", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), headTop * CFrame.new(0, 0.95, 0), white)
	piece(folder, root, "Apron", Enum.PartType.Block, Vector3.new(1.7, 2.3, 0.1), root.CFrame * CFrame.new(0, -0.4, -0.56), white)
end

BUILDERS.staff = function(folder, head, root)
	piece(folder, root, "Polo", Enum.PartType.Block, Vector3.new(1.9, 1.6, 0.1), root.CFrame * CFrame.new(0, 0.2, -0.56), Color3.fromRGB(60, 100, 180))
	piece(folder, root, "Lanyard", Enum.PartType.Block, Vector3.new(0.12, 1, 0.05), root.CFrame * CFrame.new(0, 0.5, -0.63), Color3.fromRGB(200, 40, 40))
	piece(folder, root, "IdCard", Enum.PartType.Block, Vector3.new(0.5, 0.65, 0.05), root.CFrame * CFrame.new(0, -0.1, -0.64), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic)
end

BUILDERS.cleanup = function(folder, head, root)
	local orange = Color3.fromRGB(255, 130, 20)
	local stripe = Color3.fromRGB(230, 230, 210)
	piece(folder, root, "VestFront", Enum.PartType.Block, Vector3.new(1.9, 1.9, 0.1), root.CFrame * CFrame.new(0, 0.05, -0.56), orange)
	piece(folder, root, "VestBack", Enum.PartType.Block, Vector3.new(1.9, 1.9, 0.1), root.CFrame * CFrame.new(0, 0.05, 0.56), orange)
	piece(folder, root, "StripeFront", Enum.PartType.Block, Vector3.new(1.95, 0.18, 0.05), root.CFrame * CFrame.new(0, -0.3, -0.62), stripe, Enum.Material.Neon)
	piece(folder, root, "StripeBack", Enum.PartType.Block, Vector3.new(1.95, 0.18, 0.05), root.CFrame * CFrame.new(0, -0.3, 0.62), stripe, Enum.Material.Neon)
	local headTop = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	piece(folder, head, "Cap", Enum.PartType.Block, Vector3.new(1.25, 0.35, 1.25), headTop * CFrame.new(0, 0.15, 0), orange)
	piece(folder, head, "CapBrim", Enum.PartType.Block, Vector3.new(1.1, 0.1, 0.6), headTop * CFrame.new(0, 0.02, -0.85), orange)
end

function Uniforms.remove(player)
	local character = player.Character
	local old = character and character:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

function Uniforms.wear(player, jobId)
	Uniforms.remove(player)
	local builder = BUILDERS[jobId]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not builder or not head or not root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	builder(folder, head, root)
	folder.Parent = character
end

return Uniforms
