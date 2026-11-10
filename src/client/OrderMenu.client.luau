-- The order menu (for customers). Pick breads with + and -, see the total,
-- and place the order. A working baker bakes it; the bread goes to your Bag.
-- The server checks the order and takes the coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceOrder = Remotes:WaitForChild("PlaceOrder")

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text
local MAX_ITEMS = Config.Bakery.maxOrderItems

local cart = {} -- { [itemId] = count }
local onShift = false
local counterPosition = nil -- set while the menu is open

local menu = Ui.window("Order", "🥖 Order Bread", 440)
text({
	LayoutOrder = 1,
	Text = "Pick your bread. A baker bakes it, and it goes to your 🎒 Bag.",
	TextSize = 16,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	TextColor3 = COLORS.muted,
	Parent = menu,
})

local list = create("Frame", {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = menu,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local summary = text({ LayoutOrder = 3, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu })
local coinsLine = text({ LayoutOrder = 4, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu })
local placeButton = Ui.button({ LayoutOrder = 5, Text = "Place Order", TextSize = 20, Size = UDim2.new(1, 0, 0, 42), Parent = menu })

local rows = {} -- [itemId] = { frame, countLabel }
local refresh -- defined below

local function stepButton(label, x, parent)
	return Ui.button({
		Text = label,
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = COLORS.header,
		Parent = parent,
	})
end

for i, item in Config.Bakery.items do
	local frame = create("Frame", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = COLORS.card,
		Visible = false,
		Parent = list,
	}, {
		Ui.corner(UDim.new(0, 12)),
		create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	text({
		Text = item.icon,
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(54, 54),
		Parent = frame,
	})
	text({ Text = item.name, TextSize = 20, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -200, 0, 24), Parent = frame })
	text({
		Text = ("+%d ⚡  •  %d coins"):format(item.energy, item.price),
		TextSize = 15,
		TextColor3 = COLORS.muted,
		Position = UDim2.fromOffset(64, 34),
		Size = UDim2.new(1, -200, 0, 20),
		Parent = frame,
	})
	local plus = stepButton("+", -10, frame)
	local countLabel = text({
		Text = "0",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -50, 0.5, 0),
		Size = UDim2.fromOffset(34, 36),
		Parent = frame,
	})
	local minus = stepButton("-", -88, frame)

	plus.Activated:Connect(function()
		if Ui.total(cart) < MAX_ITEMS then
			cart[item.id] = (cart[item.id] or 0) + 1
			refresh()
		end
	end)
	minus.Activated:Connect(function()
		local n = cart[item.id] or 0
		if n > 0 then
			cart[item.id] = if n == 1 then nil else n - 1
			refresh()
		end
	end)
	rows[item.id] = { frame = frame, countLabel = countLabel }
end

local function cartTotals()
	local count, price, energy = 0, 0, 0
	for id, n in cart do
		local item = Ui.itemsById[id]
		count += n
		price += item.price * n
		energy += item.energy * n
	end
	return count, price, energy
end

refresh = function()
	for id, row in rows do
		row.countLabel.Text = tostring(cart[id] or 0)
	end
	local count, price, energy = cartTotals()
	local coins = player:GetAttribute("Coins") or 0
	summary.Text = ("%d/%d breads  •  +%d energy  •  %d coins"):format(count, MAX_ITEMS, energy, price)
	coinsLine.Text = ("You have %d coins"):format(coins)
	coinsLine.TextColor3 = if coins < price then COLORS.bad else COLORS.muted

	local canOrder = count > 0 and coins >= price
	placeButton.BackgroundColor3 = if canOrder then COLORS.good else COLORS.lockedStroke
	placeButton.AutoButtonColor = canOrder
	placeButton.Text = if count == 0 then "Pick some bread" elseif coins < price then "Not enough coins" else "Place Order"
end

placeButton.Activated:Connect(function()
	local count, price = cartTotals()
	if count == 0 or (player:GetAttribute("Coins") or 0) < price then
		return
	end
	PlaceOrder:FireServer(cart)
	Ui.close("Order")
end)

-- Close the menu when the customer walks away or starts working.
RunService.Heartbeat:Connect(function()
	if not counterPosition or not Ui.isOpen("Order") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if onShift or not root or (root.Position - counterPosition).Magnitude > Config.Bakery.counterReach then
		Ui.close("Order")
		counterPosition = nil
	end
end)

-- availableIds: breads a working baker can make right now.
Remotes:WaitForChild("OpenOrderMenu").OnClientEvent:Connect(function(availableIds, position)
	cart = {}
	local available = {}
	for _, id in availableIds do
		available[id] = true
	end
	for id, row in rows do
		row.frame.Visible = available[id] == true
	end
	counterPosition = position
	refresh()
	Ui.open("Order")
end)
Remotes:WaitForChild("JobState").OnClientEvent:Connect(function(state)
	onShift = state.onShift == true
end)
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if Ui.isOpen("Order") then
		refresh()
	end
end)
