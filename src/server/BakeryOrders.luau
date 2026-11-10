-- The order board. Orders come only from real players (no NPC customers).
--
-- A customer (a player who is not working) orders bread at the counter.
-- The order goes to the working baker with the fewest orders who can bake
-- every bread in it. The customer pays when ordering; the coins are held here
-- until the baker serves the order. Not served in time = full refund.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local CustomerState = Remotes:WaitForChild("CustomerState")

local settings = Config.Bakery

local itemsById = {}
for _, item in settings.items do
	itemsById[item.id] = item
end

local Orders = {}

-- [orderId] = order
-- order = { id, customer, baker, items = { [itemId] = count }, count, price, createdAt, expiresAt }
local orders = {}
local nextId = 0

-- Set by BakeryJob with Orders.init:
--   isOnShift(player) -> boolean
--   canBake(player, itemId) -> boolean
--   onBakerChanged(baker)   (sends the baker their new job state)
local hooks = nil

local function now()
	return workspace:GetServerTimeNow()
end

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

-- { pandesal = 2, spanishbread = 1 } → "2 Pandesal, 1 Spanish Bread"
function Orders.describe(items)
	local parts = {}
	for _, item in settings.items do
		local n = items[item.id]
		if n then
			table.insert(parts, ("%d %s"):format(n, item.name))
		end
	end
	return table.concat(parts, ", ")
end

function Orders.init(h)
	hooks = h
end

function Orders.forCustomer(customer)
	for _, order in orders do
		if order.customer == customer then
			return order
		end
	end
	return nil
end

-- The baker's orders, oldest first.
function Orders.forBaker(baker)
	local list = {}
	for _, order in orders do
		if order.baker == baker then
			table.insert(list, order)
		end
	end
	table.sort(list, function(a, b)
		return a.createdAt < b.createdAt
	end)
	return list
end

-- Everything the baker's orders need, added up: { [itemId] = count }
function Orders.neededBy(baker)
	local need = {}
	for _, order in orders do
		if order.baker == baker then
			for id, n in order.items do
				need[id] = (need[id] or 0) + n
			end
		end
	end
	return need
end

local function sendCustomerState(customer)
	if not customer.Parent then
		return
	end
	local order = Orders.forCustomer(customer)
	if order then
		CustomerState:FireClient(customer, {
			items = order.items,
			price = order.price,
			bakerName = order.baker.DisplayName,
			createdAt = order.createdAt,
			expiresAt = order.expiresAt,
		})
	else
		CustomerState:FireClient(customer, nil)
	end
end
Orders.sendCustomerState = sendCustomerState

-- Working bakers (not the customer) who can bake every bread in `items`.
local function bakersFor(customer, items)
	local list = {}
	for _, player in Players:GetPlayers() do
		if player ~= customer and hooks.isOnShift(player) then
			local canMakeAll = true
			for id in items do
				if not hooks.canBake(player, id) then
					canMakeAll = false
					break
				end
			end
			if canMakeAll then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function leastBusy(bakers)
	local best, bestLoad = nil, math.huge
	for _, baker in bakers do
		local load = #Orders.forBaker(baker)
		if load < bestLoad then
			best, bestLoad = baker, load
		end
	end
	return best
end

-- Bread ids that at least one working baker can make for this customer.
function Orders.availableFor(customer)
	local ids = {}
	for _, item in settings.items do
		if #bakersFor(customer, { [item.id] = 1 }) > 0 then
			table.insert(ids, item.id)
		end
	end
	return ids
end

-- Checks a cart sent by the client. Returns items, count, price,
-- or nil and a reason. Never trust what the client sends.
local function cleanCart(cart)
	if type(cart) ~= "table" then
		return nil, "That order did not work. Try again."
	end
	local items, count, price = {}, 0, 0
	for id, n in cart do
		local item = if type(id) == "string" then itemsById[id] else nil
		if not item or type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > settings.maxOrderItems then
			return nil, "That order did not work. Try again."
		end
		items[id] = n
		count += n
		price += item.price * n
	end
	if count < 1 then
		return nil, "Pick at least one bread."
	end
	if count > settings.maxOrderItems then
		return nil, ("You can order up to %d breads."):format(settings.maxOrderItems)
	end
	return items, count, price
end

-- Places an order. Returns ok (boolean) and a message for the customer.
function Orders.place(customer, cart)
	if not PlayerData.get(customer) then
		return false, "Still loading your data. Try again in a moment."
	end
	if hooks.isOnShift(customer) then
		return false, "You are working. Clock out to order bread."
	end
	if Orders.forCustomer(customer) then
		return false, "You already have an order. Wait for your bread!"
	end
	local items, count, price = cleanCart(cart)
	if not items then
		return false, count -- count holds the reason here
	end
	local baker = leastBusy(bakersFor(customer, items))
	if not baker then
		return false, "No working baker can make that right now."
	end
	if not PlayerData.spendCoins(customer, price) then
		return false, ("You need %d coins for this order."):format(price)
	end

	nextId += 1
	local t = now()
	local order = {
		id = nextId,
		customer = customer,
		baker = baker,
		items = items,
		count = count,
		price = price,
		createdAt = t,
		expiresAt = t + settings.orderTimeoutSeconds,
	}
	orders[order.id] = order
	sendCustomerState(customer)
	hooks.onBakerChanged(baker)
	notify(baker, ("New order from %s: %s"):format(customer.DisplayName, Orders.describe(items)), "rank")
	return true, ("Order placed! %s is baking it. You paid %d coins."):format(baker.DisplayName, price)
end

-- Cancels an order and gives the customer their coins back.
local function cancel(order, customerMessage, bakerMessage)
	orders[order.id] = nil
	PlayerData.addCoins(order.customer, order.price) -- refund
	sendCustomerState(order.customer)
	if customerMessage then
		notify(order.customer, customerMessage, "bad")
	end
	if bakerMessage then
		notify(order.baker, bakerMessage, "bad")
	end
	hooks.onBakerChanged(order.baker)
end

-- Called when the baker serves the order: the bread goes into the customer's bag.
-- (BakeryJob pays the baker.)
function Orders.complete(order)
	orders[order.id] = nil
	PlayerData.addToBag(order.customer, order.items)
	sendCustomerState(order.customer)
	notify(order.customer, ("Your bread is ready! %s is in your 🎒 Bag."):format(Orders.describe(order.items)), "good")
end

-- A baker stopped working: give their orders to another baker, or refund.
-- closing = true at 5:00 PM: refund right away (every baker is leaving).
-- Call this after the baker's shift is removed.
function Orders.reassignFrom(baker, closing)
	for _, order in Orders.forBaker(baker) do
		local newBaker = if closing then nil else leastBusy(bakersFor(order.customer, order.items))
		if newBaker then
			local t = now()
			order.baker = newBaker
			order.createdAt = t -- the new baker gets a fair time
			order.expiresAt = t + settings.orderTimeoutSeconds
			sendCustomerState(order.customer)
			notify(order.customer, ("Your baker stopped working. %s will bake your order now."):format(newBaker.DisplayName), "info")
			notify(newBaker, ("New order from %s: %s"):format(order.customer.DisplayName, Orders.describe(order.items)), "rank")
			hooks.onBakerChanged(newBaker)
		elseif closing then
			cancel(order, ("The bakery closed. You got your %d coins back."):format(order.price), nil)
		else
			cancel(order, ("Your baker stopped working. You got your %d coins back."):format(order.price), nil)
		end
	end
end

-- A customer left the game: cancel their order (the refund is saved with their data).
function Orders.cancelFor(customer)
	local order = Orders.forCustomer(customer)
	if order then
		cancel(order, nil, ("%s left the game. Their order was cancelled."):format(customer.DisplayName))
	end
end

-- Refunds orders that were not served in time.
function Orders.checkExpired()
	local t = now()
	for _, order in orders do
		if t > order.expiresAt then
			cancel(
				order,
				("Your order took too long. You got your %d coins back."):format(order.price),
				("The order for %s ran out of time."):format(order.customer.DisplayName)
			)
		end
	end
end

return Orders
