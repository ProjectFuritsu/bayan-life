-- The Cleanup Crew job. Works even on an empty server: the barangay pays.
--
-- Clock in at the Town Hall ("Time Clock: Cleanup") → pick up litter around the
-- plaza and paths (your bag holds Config.Cleanup.bagSize) → empty the bag at
-- the Town Hall dumpster → coins and XP per piece.
-- Litter piles up overnight: a big batch appears when the day starts, a little
-- more comes during the morning, then none until the next morning.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)
local Shifts = require(script.Parent.Shifts)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local WorkState = Remotes:WaitForChild("WorkState")

local JOB_ID = "cleanup"
local settings = Config.Cleanup
local random = Random.new()

local CleanupJob = {}

local bags = {} -- [Player] = pieces in the bag
local litterFolder = nil
local areas = {}

-- The kinds of litter: size, color, shape.
local LITTER = {
	{ name = "Can", shape = Enum.PartType.Cylinder, size = Vector3.new(0.7, 0.45, 0.45), color = Color3.fromRGB(200, 50, 50), material = Enum.Material.Metal },
	{ name = "Bottle", shape = Enum.PartType.Cylinder, size = Vector3.new(1.1, 0.4, 0.4), color = Color3.fromRGB(120, 200, 140), material = Enum.Material.Glass },
	{ name = "Wrapper", shape = Enum.PartType.Block, size = Vector3.new(0.8, 0.08, 0.6), color = Color3.fromRGB(240, 200, 60), material = Enum.Material.Plastic },
	{ name = "PaperBall", shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.6, 0.6), color = Color3.fromRGB(235, 235, 230), material = Enum.Material.SmoothPlastic },
}

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

local function pushState(player)
	if not player.Parent then
		return
	end
	local work = Shifts.get(player)
	if not work or work.jobId ~= JOB_ID then
		WorkState:FireClient(player, nil)
		return
	end
	WorkState:FireClient(player, {
		jobId = JOB_ID,
		bag = bags[player] or 0,
		bagSize = settings.bagSize,
		tasks = work.tasks,
		earned = work.earned,
		litterLeft = #litterFolder:GetChildren(),
	})
end

-- A trash bag on the worker's back that grows as it fills.
local function updateBag(player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("TrashBag")
	if old then
		old:Destroy()
	end
	local count = bags[player] or 0
	local root = character:FindFirstChild("HumanoidRootPart")
	if count == 0 or not root then
		return
	end
	local size = 0.8 + 1.2 * (count / settings.bagSize)
	local bag = Instance.new("Part")
	bag.Name = "TrashBag"
	bag.Shape = Enum.PartType.Ball
	bag.Size = Vector3.new(size, size, size)
	bag.Color = Color3.fromRGB(30, 30, 35)
	bag.Material = Enum.Material.Plastic
	bag.Anchored = false
	bag.Massless = true
	bag.CanCollide = false
	bag.CanQuery = false
	bag.CanTouch = false
	bag.CFrame = root.CFrame * CFrame.new(0, 0.2, 0.6 + size / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bag
	weld.Parent = bag
	bag.Parent = character
end

local function pickUp(player, piece)
	if Shifts.jobOf(player) ~= JOB_ID then
		notify(player, "Clock in as Cleanup Crew at the Town Hall to pick up litter.", "info")
		return
	end
	if not piece.Parent then
		return -- someone else got it first
	end
	local count = bags[player] or 0
	if count >= settings.bagSize then
		notify(player, "Your bag is full! Empty it at the Town Hall dumpster.", "bad")
		return
	end
	piece:Destroy()
	bags[player] = count + 1
	updateBag(player)
	pushState(player)
	if bags[player] == settings.bagSize then
		notify(player, "Bag full! Bring it to the Town Hall dumpster.", "info")
	end
end

-- Pays for the bag and empties it. Returns the coins paid.
local function payForBag(player)
	local count = bags[player] or 0
	if count == 0 then
		return 0
	end
	local pay = count * settings.payPerPiece
	PlayerData.addCoins(player, pay)
	PlayerData.addXP(player, count * settings.xpPerPiece)
	Shifts.addWork(player, pay, count)
	bags[player] = 0
	updateBag(player)
	return pay, count
end

local function emptyBag(player)
	if Shifts.jobOf(player) ~= JOB_ID then
		return
	end
	local pay, count = payForBag(player)
	if pay == 0 then
		notify(player, "Your bag is empty. Pick up litter first.", "info")
		return
	end
	notify(player, ("Emptied %d pieces. The barangay paid you %d coins! +%d XP"):format(count, pay, count * settings.xpPerPiece), "good")
	pushState(player)
end

local function spawnLitter()
	if #litterFolder:GetChildren() >= settings.maxLitter or #areas == 0 then
		return
	end
	local area = areas[random:NextInteger(1, #areas)]
	local kind = LITTER[random:NextInteger(1, #LITTER)]
	local x = (random:NextNumber() - 0.5) * area.sizeX
	local z = (random:NextNumber() - 0.5) * area.sizeZ
	local position = (area.cframe * CFrame.new(x, 0, z)).Position

	local piece = Instance.new("Part")
	piece.Name = kind.name
	piece.Shape = kind.shape
	piece.Size = kind.size
	piece.Color = kind.color
	piece.Material = kind.material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0)
	piece.Parent = litterFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = "Litter"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Role", JOB_ID)
	prompt.Triggered:Connect(function(player)
		pickUp(player, piece)
	end)
	prompt.Parent = piece
	CollectionService:AddTag(prompt, "RolePrompt")
end

-- stations = { timeClock, dumpster, litterAreas }
function CleanupJob.start(stations, isOpen, closeHour)
	areas = stations.litterAreas or {}
	litterFolder = Instance.new("Folder")
	litterFolder.Name = "Litter"
	litterFolder.Parent = workspace

	Shifts.register(JOB_ID, {
		place = "the Town Hall",
		isOpen = isOpen,
		closeHour = closeHour,
		onStart = function(player)
			bags[player] = 0
			pushState(player)
			notify(player, "Pick up litter around the plaza and paths, then empty your bag at the dumpster.", "info")
		end,
		onEnd = function(player, _closing, silent)
			-- Pay for what is still in the bag, so no work is lost.
			local pay = payForBag(player)
			bags[player] = nil
			if not silent then
				if pay > 0 then
					notify(player, ("The barangay paid %d coins for your last bag."):format(pay), "good")
				end
				WorkState:FireClient(player, nil)
			end
		end,
	})

	local function addPrompt(part, actionText, objectText, holdSeconds, role, onTriggered)
		if not part then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = holdSeconds
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Role", role)
		prompt.Triggered:Connect(onTriggered)
		prompt.Parent = part
		CollectionService:AddTag(prompt, "RolePrompt")
	end
	addPrompt(stations.timeClock, "Clock In / Out", "Time Clock: Cleanup", 0, "any", function(player)
		Shifts.toggle(player, JOB_ID)
	end)
	addPrompt(stations.dumpster, "Empty Bag", "Dumpster", 0.5, JOB_ID, emptyBag)

	-- Litter in the morning only.
	local function isMorning(t)
		return GameClock.isWithin(t, Config.Clock.openHour, settings.morningEndHour)
	end
	local function morningBatch()
		for _ = 1, settings.morningBatch do
			spawnLitter()
		end
		for player in bags do
			notify(player, "Good morning! Litter piled up overnight. Time to clean the town!", "info")
			pushState(player)
		end
	end

	-- If the server starts during work hours, this morning's litter is still there.
	local t0 = workspace:GetServerTimeNow()
	local lastBatchDay = nil
	if isOpen(t0) then
		lastBatchDay = GameClock.day(t0)
		morningBatch()
	end

	task.spawn(function()
		local sinceSpawn = 0
		while true do
			task.wait(1)
			local t = workspace:GetServerTimeNow()
			if isMorning(t) then
				local day = GameClock.day(t)
				if lastBatchDay ~= day then
					lastBatchDay = day
					morningBatch()
				end
				sinceSpawn += 1
				if sinceSpawn >= settings.spawnSeconds then
					sinceSpawn = 0
					spawnLitter()
				end
			end
		end
	end)
end

return CleanupJob
