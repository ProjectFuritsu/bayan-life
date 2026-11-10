-- The bakery job. Made to order: bakers only bake what real customers ordered.
--
-- Baker:     Time Clock (clock in) → Oven (bake what orders need) → Bread Rack (pick up)
--            → Serve spot behind the counter (stock the glass case, serve orders) → coins + XP
-- Customer:  Order spot in front of the counter (order and pay) → bread goes to the 🎒 Bag
--
-- Working uses energy. Work hours are 6:00 AM to 5:00 PM (game clock).
-- Every check happens on the server. Messages from the client (BakeRequest,
-- PlaceOrder) are checked here and in BakeryOrders.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Orders = require(script.Parent.BakeryOrders)
local Shifts = require(script.Parent.Shifts)
local Poses = require(script.Parent.Poses)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local JobState = Remotes:WaitForChild("JobState")
local Notify = Remotes:WaitForChild("Notify")
local OpenOvenMenu = Remotes:WaitForChild("OpenOvenMenu")
local BakeRequest = Remotes:WaitForChild("BakeRequest")
local OpenOrderMenu = Remotes:WaitForChild("OpenOrderMenu")
local PlaceOrder = Remotes:WaitForChild("PlaceOrder")

local JOB_ID = "baker"
local JOB_NAME = Config.Jobs[JOB_ID].name
local settings = Config.Bakery

local itemsById = {}
for _, item in settings.items do
	itemsById[item.id] = item
end

local BakeryJob = {}

local ovenPart = nil
local orderSpot = nil

-- [Player] = shift
-- shift = {
--   rack = counts,       baked bread on the racks
--   carrying = counts,   bread in the baker's hands
--   case = counts,       bread in the glass case, ready to serve
--   ovenQueue = { item, ... },          breads waiting to bake
--   baking = { id, endsAt } or nil,     the bread in the oven now
-- }
-- (Time in, coins earned and tasks done are kept by Shifts.)
-- counts = { [itemId] = number }
local shifts = {}

local function now()
	return workspace:GetServerTimeNow() -- same clock on server and client
end

local function emptyCounts()
	local counts = {}
	for _, item in settings.items do
		counts[item.id] = 0
	end
	return counts
end

local function total(counts)
	local sum = 0
	for _, n in counts do
		sum += n
	end
	return sum
end

-- Moves up to `limit` breads from one place to another. Returns how many moved.
local function move(from, to, limit)
	local moved = 0
	for _, item in settings.items do
		local id = item.id
		while from[id] > 0 and moved < limit do
			from[id] -= 1
			to[id] += 1
			moved += 1
		end
	end
	return moved
end

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

local function canBake(player, itemId)
	local data = PlayerData.get(player)
	local item = itemsById[itemId]
	return data ~= nil and item ~= nil and Progression.getRankIndex(data.xp) >= item.unlockRank
end

local function pushState(player)
	if not player.Parent then
		return
	end
	local shift = shifts[player]
	if not shift then
		JobState:FireClient(player, { onShift = false })
		return
	end
	local queueIds = {}
	for i, item in shift.ovenQueue do
		queueIds[i] = item.id
	end
	local orderList = {}
	for i, order in Orders.forBaker(player) do
		orderList[i] = {
			id = order.id,
			customerName = order.customer.DisplayName,
			items = order.items,
			createdAt = order.createdAt,
			expiresAt = order.expiresAt,
		}
	end
	local work = Shifts.get(player) or {}
	JobState:FireClient(player, {
		onShift = true,
		rack = shift.rack,
		carrying = shift.carrying,
		case = shift.case,
		rackLimit = settings.rackLimit,
		carryLimit = settings.carryLimit,
		caseLimit = settings.caseLimit,
		baking = shift.baking,
		queued = #shift.ovenQueue,
		queueIds = queueIds,
		orders = orderList,
		job = JOB_NAME,
		day = work.day,
		timeIn = work.timeIn,
		served = work.tasks,
		earned = work.earned,
	})
end

-- Shows a tray of bread in front of the baker while they carry bread.
-- It is welded to the character, so every player can see it.
local function updateCarryTray(player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("BreadTray")
	if old then
		old:Destroy()
	end
	local shift = shifts[player]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not shift or not root or total(shift.carrying) == 0 then
		Poses.setHolding(player, false)
		return
	end
	Poses.setHolding(player, true) -- arms forward, holding the tray

	local function setup(part)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end

	local tray = Instance.new("Part")
	tray.Name = "BreadTray"
	tray.Size = Vector3.new(2.2, 0.2, 1.4)
	tray.Color = Color3.fromRGB(150, 100, 60)
	tray.Material = Enum.Material.Wood
	setup(tray)
	tray.CFrame = root.CFrame * CFrame.new(0, 0.3, -1.3)

	local index = 0
	for _, item in settings.items do
		for _ = 1, shift.carrying[item.id] do
			index += 1
			local col = (index - 1) % 3
			local row = math.floor((index - 1) / 3)
			local piece = Instance.new("Part")
			piece.Name = item.id
			piece.Shape = Enum.PartType.Ball
			piece.Size = Vector3.new(0.55, 0.55, 0.55)
			piece.Color = item.color
			setup(piece)
			piece.CFrame = tray.CFrame * CFrame.new((col - 1) * 0.65, 0.35, (row - 0.5) * 0.6)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = tray
			weld.Part1 = piece
			weld.Parent = piece
			piece.Parent = tray
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = tray
	weld.Parent = tray
	tray.Parent = character
end

------------------------------------------------------------------------
-- Shift start and end (Shifts calls these; it handles the time clock,
-- requirements, energy, closing time, uniform and DTR for every job)
------------------------------------------------------------------------

local function onShiftStart(player)
	shifts[player] = {
		rack = emptyCounts(),
		carrying = emptyCounts(),
		case = emptyCounts(),
		ovenQueue = {},
		baking = nil,
	}
	pushState(player)
	notify(player, "Wait for customers to order at the counter.", "info")
end

-- Their open orders go to another baker, or are refunded.
-- closing = true at 5:00 PM (orders are refunded instead of passed on).
local function onShiftEnd(player, closing, silent)
	if not shifts[player] then
		return
	end
	shifts[player] = nil
	Orders.reassignFrom(player, closing)
	if not silent then
		updateCarryTray(player)
		pushState(player)
	end
end

------------------------------------------------------------------------
-- Oven: bake only what your orders need
------------------------------------------------------------------------

-- Bread on the racks + in the oven + waiting for the oven.
local function rackSpaceUsed(shift)
	return total(shift.rack) + #shift.ovenQueue + (if shift.baking then 1 else 0)
end

-- How many of this bread the baker has anywhere (case, hands, racks, oven).
local function haveCount(shift, itemId)
	local n = shift.case[itemId] + shift.carrying[itemId] + shift.rack[itemId]
	if shift.baking and shift.baking.id == itemId then
		n += 1
	end
	for _, item in shift.ovenQueue do
		if item.id == itemId then
			n += 1
		end
	end
	return n
end

-- Bakes everything in the baker's oven queue, one bread at a time.
local function runOven(player, shift)
	while shifts[player] == shift and #shift.ovenQueue > 0 do
		local item = table.remove(shift.ovenQueue, 1)
		shift.baking = { id = item.id, endsAt = now() + item.bakeSeconds }
		pushState(player)
		task.wait(item.bakeSeconds)
		if shifts[player] ~= shift then
			return -- clocked out while baking
		end
		shift.rack[item.id] += 1
		shift.baking = nil
	end
	pushState(player)
end

local function isNearOven(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and ovenPart ~= nil and (root.Position - ovenPart.Position).Magnitude <= settings.ovenReach
end

local function useOven(player)
	if not shifts[player] then
		notify(player, "Clock in first at the Time Clock.", "bad")
		return
	end
	if #Orders.forBaker(player) == 0 then
		notify(player, "No orders yet. Wait for a customer to order.", "info")
		return
	end
	OpenOvenMenu:FireClient(player, ovenPart.Position)
end

local function requestBake(player, itemId)
	-- Never trust what the client sends: check the type and that the bread exists.
	if type(itemId) ~= "string" then
		return
	end
	local item = itemsById[itemId]
	local shift = shifts[player]
	if not item or not shift or not isNearOven(player) then
		return
	end
	if not canBake(player, itemId) then
		notify(player, ("%s unlocks at %s rank."):format(item.name, Config.Ranks[item.unlockRank].name), "bad")
		return
	end
	local needed = (Orders.neededBy(player)[itemId] or 0) - haveCount(shift, itemId)
	if needed <= 0 then
		notify(player, ("Your orders don't need more %s."):format(item.name), "info")
		return
	end
	if rackSpaceUsed(shift) >= settings.rackLimit then
		notify(player, "The racks are full. Pick up the bread and serve it.", "bad")
		return
	end

	table.insert(shift.ovenQueue, item)
	if shift.baking then
		pushState(player) -- the oven is busy; this bread waits in line
	else
		task.spawn(runOven, player, shift)
	end
end

------------------------------------------------------------------------
-- Bread Rack: pick up
------------------------------------------------------------------------

local function pickUp(player)
	local shift = shifts[player]
	if not shift then
		notify(player, "Clock in first at the Time Clock.", "bad")
		return
	end
	if total(shift.rack) == 0 then
		notify(player, "The racks are empty. Bake bread at the oven first.", "info")
		return
	end
	local room = settings.carryLimit - total(shift.carrying)
	if room <= 0 then
		notify(player, "Your hands are full. Bring the bread to the counter.", "bad")
		return
	end
	local moved = move(shift.rack, shift.carrying, room)
	updateCarryTray(player)
	pushState(player)
	notify(player, ("Picked up %d bread. Bring it to the counter."):format(moved), "info")
end

------------------------------------------------------------------------
-- Serve spot (behind the counter): stock the glass case, then serve orders
------------------------------------------------------------------------

local function payBaker(player, shift, order)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local rank = Progression.getRank(data.xp)
	local pay = math.max(1, math.round(order.price * rank.payMultiplier))
	local bonus = pay - order.price
	local fast = now() - order.createdAt <= settings.fastServeSeconds
	local xp = settings.xpPerItem * order.count
	if fast then
		xp = math.round(xp * (1 + settings.fastXpBonus))
	end

	PlayerData.addCoins(player, pay)
	local newRank = PlayerData.addXP(player, xp)
	Shifts.addWork(player, pay, 1)

	local bonusText = if bonus > 0 then (" (+%d rank bonus)"):format(bonus) else ""
	local fastText = if fast then " Fast service!" else ""
	notify(player, ("Served %s! +%d coins%s, +%d XP.%s"):format(order.customer.DisplayName, pay, bonusText, xp, fastText), "good")

	if newRank then
		local rankIndex = Progression.getRankIndex(data.xp)
		local unlockedNow = {}
		for _, item in settings.items do
			if item.unlockRank == rankIndex then
				table.insert(unlockedNow, item.name)
			end
		end
		local extra = if #unlockedNow > 0 then " New bread: " .. table.concat(unlockedNow, ", ") .. "!" else ""
		notify(player, ("Rank up! You are now a %s.%s"):format(newRank.name, extra), "rank")
	end
end

local function serveOrders(player)
	local shift = shifts[player]
	if not shift then
		notify(player, "Clock in first at the Time Clock.", "bad")
		return
	end

	-- 1. Put what the baker carries into the glass case.
	local stocked = 0
	if total(shift.carrying) > 0 then
		stocked = move(shift.carrying, shift.case, settings.caseLimit - total(shift.case))
		updateCarryTray(player)
		if total(shift.carrying) > 0 then
			notify(player, "The glass case is full. Use the trash for extra bread.", "bad")
		end
	end

	-- 2. Serve every order the glass case can fill, oldest first.
	local myOrders = Orders.forBaker(player)
	local servedNow = 0
	for _, order in myOrders do
		local complete = true
		for id, needed in order.items do
			if shift.case[id] < needed then
				complete = false
				break
			end
		end
		if complete then
			for id, needed in order.items do
				shift.case[id] -= needed
			end
			Orders.complete(order)
			payBaker(player, shift, order)
			servedNow += 1
		end
	end
	pushState(player)

	if servedNow > 0 then
		return
	end
	local stockedText = if stocked > 0 then ("Stocked %d bread. "):format(stocked) else ""
	local first = myOrders[1]
	if not first then
		notify(player, stockedText .. "No orders right now.", "info")
		return
	end
	local missing = {}
	for id, needed in first.items do
		local short = needed - shift.case[id]
		if short > 0 then
			table.insert(missing, ("%d %s"):format(short, itemsById[id].name))
		end
	end
	notify(player, ("%sStill missing for %s: %s"):format(stockedText, first.customer.DisplayName, table.concat(missing, ", ")), "bad")
end

------------------------------------------------------------------------
-- Trash: throw away what you carry; if your hands are empty, clear the glass case
------------------------------------------------------------------------

local function throwAway(player)
	local shift = shifts[player]
	if not shift then
		return
	end
	local carried = total(shift.carrying)
	local inCase = total(shift.case)
	if carried > 0 then
		shift.carrying = emptyCounts()
		updateCarryTray(player)
		notify(player, ("Threw away %d bread you were carrying."):format(carried), "info")
	elseif inCase > 0 then
		shift.case = emptyCounts()
		notify(player, ("Cleared %d bread from the glass case."):format(inCase), "info")
	else
		notify(player, "Nothing to throw away.", "info")
	end
	pushState(player)
end

------------------------------------------------------------------------
-- Order spot (in front of the counter): customers order here
------------------------------------------------------------------------

local function openOrderMenu(player)
	if shifts[player] then
		notify(player, "You are working. Clock out to order bread.", "info")
		return
	end
	if Orders.forCustomer(player) then
		notify(player, "You already have an order. Wait for your bread!", "info")
		return
	end
	local available = Orders.availableFor(player)
	if #available == 0 then
		notify(player, "No bakers are working right now. Come back later!", "bad")
		return
	end
	OpenOrderMenu:FireClient(player, available, orderSpot.Position)
end

local function placeOrder(player, cart)
	local ok, message = Orders.place(player, cart)
	notify(player, message, if ok then "good" else "bad")
end

------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------

-- role: "baker" (only on a baker shift), "customer" (not on a baker shift) or "any".
-- The client hides prompts that are not for the player's role right now
-- (prompts are tagged "RolePrompt" so the client can find them).
local function addPrompt(part, actionText, objectText, holdSeconds, role, onTriggered, distance)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdSeconds
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Role", role)
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	CollectionService:AddTag(prompt, "RolePrompt")
end

function BakeryJob.start(stations)
	assert(
		settings.maxOrderItems <= settings.rackLimit and settings.maxOrderItems <= settings.caseLimit,
		"Config: maxOrderItems must be <= rackLimit and caseLimit"
	)
	assert(settings.items[1].unlockRank == 1, "Config: the first bread must unlock at rank 1")

	Orders.init({
		isOnShift = function(player)
			return shifts[player] ~= nil
		end,
		canBake = canBake,
		onBakerChanged = pushState,
	})

	-- Clock in/out, requirements, energy, closing time, uniform and DTR: Shifts.
	Shifts.register(JOB_ID, {
		place = "the bakery",
		isOpen = GameClock.isOpen, -- work hours, 6:00 AM to 5:00 PM
		closeHour = Config.Clock.closeHour,
		onStart = onShiftStart,
		onEnd = onShiftEnd,
	})

	ovenPart = stations.oven
	orderSpot = stations.orderSpot
	addPrompt(stations.timeClock, "Clock In / Out", "Time Clock", 0, "any", function(player)
		Shifts.toggle(player, JOB_ID)
	end)
	addPrompt(stations.oven, "Use Oven", "Oven", 0, "baker", useOven)
	for _, rack in stations.racks do
		addPrompt(rack, "Pick Up Bread", "Bread Rack", 0, "baker", pickUp)
	end
	addPrompt(stations.serveSpot, "Serve Orders", "Counter", 0, "baker", serveOrders, 6)
	addPrompt(stations.orderSpot, "Order Bread", "Counter", 0, "customer", openOrderMenu, 6)
	addPrompt(stations.trash, "Throw Away", "Trash", 0.5, "baker", throwAway)

	BakeRequest.OnServerEvent:Connect(requestBake)
	PlaceOrder.OnServerEvent:Connect(placeOrder)

	-- Show the carry tray again after the player respawns.
	local function watchCharacter(player)
		player.CharacterAdded:Connect(function()
			task.wait() -- let the character finish loading
			updateCarryTray(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	-- A customer who leaves gets their order refunded (before their data is saved).
	PlayerData.onLeaving(function(player)
		Orders.cancelFor(player)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			Orders.checkExpired()
		end
	end)
end

return BakeryJob
