-- Opening hours for buildings: sliding doors and an OPEN / CLOSED sign.
-- When a building closes, anyone inside is walked out front, then the doors shut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Atmosphere = require(script.Parent.Atmosphere)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local OPEN_COLOR = Color3.fromRGB(90, 220, 120)
local CLOSED_COLOR = Color3.fromRGB(240, 80, 70)

local Establishments = {}

local places = {}

-- place = {
--   name = "Bakery",
--   isOpen = function(serverTime) -> boolean,
--   origin = CFrame,      the building's center at floor level
--   halfSize = Vector3,   half of the inside size (used to find who is inside)
--   outside = CFrame,     where people inside are moved when it closes
--   doors = { { part = Part, open = CFrame, closed = CFrame }, ... },
--   signs = { TextLabel, ... },
--   closedMessage = "The bakery is closed. ...",
-- }
-- Finds doors (parts with an OpenOffsetX attribute: how far they slide along
-- their own X when open) and OPEN/CLOSED signs (TextLabels named OpenSignText)
-- in a building model. Call it while the doors are still closed.
function Establishments.findDoorsAndSigns(model)
	local doors, signs = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("OpenOffsetX") then
			table.insert(doors, {
				part = d,
				closed = d.CFrame,
				open = d.CFrame * CFrame.new(d:GetAttribute("OpenOffsetX"), 0, 0),
			})
		elseif d:IsA("TextLabel") and d.Name == "OpenSignText" then
			table.insert(signs, d)
		end
	end
	return doors, signs
end

function Establishments.add(place)
	if place then
		table.insert(places, place)
	end
end

local function setOpen(place, open, instant)
	for _, door in place.doors do
		door.part.CanCollide = not open
		local goal = if open then door.open else door.closed
		if instant then
			door.part.CFrame = goal
		else
			TweenService:Create(door.part, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
		end
	end
	for _, sign in place.signs do
		sign.Text = if open then "OPEN" else "CLOSED"
		sign.TextColor3 = if open then OPEN_COLOR else CLOSED_COLOR
	end
	if not instant and place.doors[1] then
		Atmosphere.playAt(place.doors[1].part, "door", 0.6)
	end
end

local function isInside(place, position)
	local p = place.origin:PointToObjectSpace(position)
	return math.abs(p.X) < place.halfSize.X
		and math.abs(p.Z) < place.halfSize.Z
		and p.Y > -2
		and p.Y < place.halfSize.Y * 2
end

local function walkOut(place)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and isInside(place, root.Position) then
			character:PivotTo(place.outside * CFrame.new(math.random(-4, 4), 3, 0))
			Notify:FireClient(player, place.closedMessage, "info")
		end
	end
end

function Establishments.start()
	local t = workspace:GetServerTimeNow()
	for _, place in places do
		place.wasOpen = place.isOpen(t)
		setOpen(place, place.wasOpen, true)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for _, place in places do
				local open = place.isOpen(now)
				if open ~= place.wasOpen then
					place.wasOpen = open
					if not open then
						walkOut(place)
					end
					setOpen(place, open, false)
				end
			end
		end
	end)
end

return Establishments
