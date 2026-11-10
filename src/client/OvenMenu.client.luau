-- The oven menu (for bakers). Each bread is a card.
-- Green = your orders still need it. Plain = not needed now. Grey = locked.
-- Clicking a card (or pressing 1-4) asks the server to bake it; the server checks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Progression = require(Shared:WaitForChild("Progression"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BakeRequest = Remotes:WaitForChild("BakeRequest")

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local state = { onShift = false }
local ovenPosition = nil -- set while the menu is open

local menu = Ui.window("Oven", "🔥 What will you bake?", 460)

local grid = create("Frame", {
	LayoutOrder = 1,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = menu,
}, {
	create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 112),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local footer = text({ LayoutOrder = 2, TextSize = 15, TextColor3 = COLORS.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu })

local cards = {}

local function pressCard(card)
	card.scale.Scale = 0.92
	Ui.tween(card.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	BakeRequest:FireServer(card.item.id)
end

for i, item in Config.Bakery.items do
	local button = create("TextButton", {
		LayoutOrder = i,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = COLORS.card,
		Parent = grid,
	}, { Ui.corner(UDim.new(0, 14)) })
	local card = {
		item = item,
		button = button,
		stroke = create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button }),
		scale = create("UIScale", { Parent = button }),
		icon = text({
			Text = item.icon,
			TextSize = 40,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(54, 54),
			Parent = button,
		}),
	}
	text({
		Text = item.name,
		TextScaled = true,
		Position = UDim2.fromOffset(64, 10),
		Size = UDim2.new(1, -100, 0, 26),
		Parent = button,
	}, { create("UITextSizeConstraint", { MaxTextSize = 20 }) })
	text({
		Text = ("Bakes in %ss"):format(tostring(item.bakeSeconds)),
		TextSize = 15,
		TextColor3 = COLORS.muted,
		Position = UDim2.fromOffset(64, 38),
		Size = UDim2.new(1, -70, 0, 18),
		Parent = button,
	})
	text({ -- keyboard shortcut badge
		Text = tostring(i),
		TextSize = 14,
		TextColor3 = COLORS.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.pill,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(22, 22),
		Parent = button,
	}, { Ui.round() })
	card.pill = text({
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.pill,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 28),
		Parent = button,
	}, { Ui.round() })

	button.MouseEnter:Connect(function()
		Ui.tween(card.scale, 0.12, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(card.scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		pressCard(card)
	end)
	cards[i] = card
end

-- How many of each bread the baker has anywhere (case, hands, racks, oven).
local function haveCounts()
	local counts = {}
	for _, source in { state.case, state.carrying, state.rack } do
		for id, n in source or {} do
			counts[id] = (counts[id] or 0) + n
		end
	end
	if state.baking then
		counts[state.baking.id] = (counts[state.baking.id] or 0) + 1
	end
	for _, id in state.queueIds or {} do
		counts[id] = (counts[id] or 0) + 1
	end
	return counts
end

local function neededCounts()
	local counts = {}
	for _, order in state.orders or {} do
		for id, n in order.items do
			counts[id] = (counts[id] or 0) + n
		end
	end
	return counts
end

local function refresh()
	local rankIndex = Progression.getRankIndex(player:GetAttribute("XP") or 0)
	local have, need = haveCounts(), neededCounts()

	for _, card in cards do
		local item = card.item
		local stillNeeded = (need[item.id] or 0) - (have[item.id] or 0)
		if rankIndex < item.unlockRank then
			card.button.BackgroundColor3 = COLORS.locked
			card.stroke.Color = COLORS.lockedStroke
			card.icon.TextTransparency = 0.5
			card.pill.BackgroundColor3 = COLORS.lockedStroke
			card.pill.TextColor3 = COLORS.text
			card.pill.Text = ("🔒 Unlocks at %s"):format(Config.Ranks[item.unlockRank].name)
		elseif stillNeeded > 0 then
			card.button.BackgroundColor3 = COLORS.needed
			card.stroke.Color = COLORS.good
			card.icon.TextTransparency = 0
			card.pill.BackgroundColor3 = COLORS.good
			card.pill.TextColor3 = WHITE
			card.pill.Text = ("Orders need %d more"):format(stillNeeded)
		else
			card.button.BackgroundColor3 = COLORS.card
			card.stroke.Color = COLORS.cardStroke
			card.icon.TextTransparency = 0.4
			card.pill.BackgroundColor3 = COLORS.pill
			card.pill.TextColor3 = COLORS.muted
			card.pill.Text = "Not needed now"
		end
	end

	local rackUsed = Ui.total(state.rack) + (if state.baking then 1 else 0) + (state.queued or 0)
	footer.Text = ("Racks %d/%d  •  Press 1-%d to bake fast"):format(
		rackUsed,
		state.rackLimit or Config.Bakery.rackLimit,
		#Config.Bakery.items
	)
end

-- Number keys 1, 2, 3... bake the matching card while the menu is open.
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not Ui.isOpen("Oven") then
		return
	end
	for i, key in NUMBER_KEYS do
		if input.KeyCode == key and cards[i] then
			pressCard(cards[i])
		end
	end
end)

-- Close the menu when the baker walks away or stops working.
RunService.Heartbeat:Connect(function()
	if not ovenPosition or not Ui.isOpen("Oven") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state.onShift or not root or (root.Position - ovenPosition).Magnitude > Config.Bakery.ovenReach then
		Ui.close("Oven")
		ovenPosition = nil
	end
end)

Ui.onOpen("Oven", refresh)

Remotes:WaitForChild("OpenOvenMenu").OnClientEvent:Connect(function(position)
	ovenPosition = position
	Ui.open("Oven")
end)
Remotes:WaitForChild("JobState").OnClientEvent:Connect(function(newState)
	state = newState
	if Ui.isOpen("Oven") then
		refresh()
	end
end)
player:GetAttributeChangedSignal("XP"):Connect(function()
	if Ui.isOpen("Oven") then
		refresh()
	end
end)
