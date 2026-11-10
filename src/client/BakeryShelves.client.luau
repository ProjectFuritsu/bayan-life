-- Shows your bread on the Bread Racks and in the glass case.
--
-- Both start empty. Baked bread fills one rack shelf each (a batch of 8 pieces).
-- Stocked bread fills one glass-case spot each (2 pieces).
-- The bread parts are made on this player's screen only, so other workers
-- see their own bread. (When each player owns a bakery later, this fits well.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- How each bread looks. Cylinders point along X, so some are turned.
-- height = how tall the piece stands, used to sit it on the shelf.
local LOOKS = {
	pandesal = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.85, 0.85, 0.85),
		height = 0.85,
		turn = CFrame.new(),
	},
	spanishbread = { -- a long roll, lying front to back
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.2, 0.5, 0.5),
		height = 0.5,
		turn = CFrame.Angles(0, math.rad(90), 0),
	},
	pandecoco = {
		shape = Enum.PartType.Ball,
		size = Vector3.new(1, 1, 1),
		height = 1,
		turn = CFrame.new(),
	},
	ensaymada = { -- a flat round bun
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.45, 1.05, 1.05),
		height = 0.45,
		turn = CFrame.Angles(0, 0, math.rad(90)),
	},
}
local DEFAULT_LOOK = LOOKS.pandesal

local itemsById = {}
for _, item in Config.Bakery.items do
	itemsById[item.id] = item
end

-- Where the pieces sit on one slot, from the slot's center.
local RACK_PIECES = {} -- 2 rows of 4
for _, z in { -0.5, 0.5 } do
	for k = 1, 4 do
		table.insert(RACK_PIECES, Vector3.new((k - 2.5) * 1.25, 0, z))
	end
end
local CASE_PIECES = { Vector3.new(-0.45, 0, 0), Vector3.new(0.45, 0, 0) }

local folder = Instance.new("Folder")
folder.Name = "MyBakedBread"
folder.Parent = workspace

-- A display is a set of slot markers in the map (found by an attribute) that
-- show bread. show(counts) makes the slots match the counts. Slots that did
-- not change stay as they are, so bread does not jump around.
local function newDisplay(attribute, slotCount, pieceOffsets, scale)
	local slotParts = {} -- [n] = marker part
	local contents = {} -- [n] = itemId or nil
	local pieces = {} -- [n] = { parts }

	-- The map can arrive a little after this script starts, so search again if needed.
	local function getSlot(n)
		local part = slotParts[n]
		if part and part.Parent then
			return part
		end
		local bakery = workspace:FindFirstChild("Bakery")
		if not bakery then
			return nil
		end
		for _, d in bakery:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute(attribute) == n then
				slotParts[n] = d
				return d
			end
		end
		return nil
	end

	local function clear(n)
		for _, piece in pieces[n] or {} do
			TweenService:Create(piece, TweenInfo.new(0.2), { Size = piece.Size * 0.1 }):Play()
			task.delay(0.25, function()
				piece:Destroy()
			end)
		end
		pieces[n] = nil
		contents[n] = nil
	end

	local function fill(n, itemId)
		local slot = getSlot(n)
		if not slot then
			return
		end
		local look = LOOKS[itemId] or DEFAULT_LOOK
		local item = itemsById[itemId]
		local list = {}
		for i, offset in pieceOffsets do
			local final = slot.CFrame
				* CFrame.new(offset.X, slot.Size.Y / 2 + look.height * scale / 2, offset.Z)
				* look.turn

			local piece = Instance.new("Part")
			piece.Name = itemId
			piece.Shape = look.shape
			piece.Size = look.size * scale
			piece.Color = item and item.color or Color3.fromRGB(205, 140, 70)
			piece.Material = Enum.Material.SmoothPlastic
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CFrame = final + Vector3.new(0, 1.2, 0)
			piece.Parent = folder

			-- Drop in with a small bounce, one piece after another.
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, false, i * 0.02)
			TweenService:Create(piece, info, { CFrame = final }):Play()
			table.insert(list, piece)
		end
		pieces[n] = list
		contents[n] = itemId
	end

	local function firstEmpty()
		for n = 1, slotCount do
			if not contents[n] and getSlot(n) then
				return n
			end
		end
		return nil
	end

	local display = {}

	function display.show(want)
		local have = {}
		for n = 1, slotCount do
			local id = contents[n]
			if id then
				have[id] = (have[id] or 0) + 1
			end
		end

		-- Remove extra bread, from the last slot back.
		for n = slotCount, 1, -1 do
			local id = contents[n]
			if id and have[id] > (want[id] or 0) then
				have[id] -= 1
				clear(n)
			end
		end

		-- Add new bread into the first empty slots, in menu order.
		for _, item in Config.Bakery.items do
			for _ = 1, (want[item.id] or 0) - (have[item.id] or 0) do
				local n = firstEmpty()
				if not n then
					break
				end
				fill(n, item.id)
			end
		end
	end

	return display
end

local racks = newDisplay("RackSlot", Config.Bakery.rackLimit, RACK_PIECES, 1)
local glassCase = newDisplay("CaseSlot", Config.Bakery.caseLimit, CASE_PIECES, 0.85)

Remotes:WaitForChild("JobState").OnClientEvent:Connect(function(state)
	if not state.onShift then
		racks.show({})
		glassCase.show({})
		return
	end
	racks.show(state.rack)
	glassCase.show(state.case)
end)
