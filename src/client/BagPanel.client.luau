-- The Bag: bread you bought. Eat it to refill energy.
-- Opened with the 🎒 Bag button. The server checks every "eat".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EatRequest = Remotes:WaitForChild("EatRequest")

local player = Players.LocalPlayer
local COLORS = Ui.COLORS
local create, text = Ui.create, Ui.text

local window = Ui.window("Bag", "🎒 My Bag", 400)
local energyLine = text({ LayoutOrder = 1, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Parent = window })
local list = create("Frame", {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local emptyLine = text({
	LayoutOrder = 3,
	Text = "Your bag is empty. Buy bread at Order Here by the counter!",
	TextSize = 16,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	TextColor3 = COLORS.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = window,
})

local rows = {} -- [itemId] = { frame, countLabel }

for i, item in Config.Bakery.items do
	local frame = create("Frame", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = COLORS.card,
		Visible = false,
		Parent = list,
	}, {
		Ui.corner(UDim.new(0, 12)),
		create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	text({
		Text = item.icon,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(52, 52),
		Parent = frame,
	})
	local countLabel = text({ TextSize = 20, Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -170, 0, 24), Parent = frame })
	text({
		Text = ("+%d energy each"):format(item.energy),
		TextSize = 15,
		TextColor3 = COLORS.muted,
		Position = UDim2.fromOffset(62, 32),
		Size = UDim2.new(1, -170, 0, 20),
		Parent = frame,
	})
	local eat = Ui.button({
		Text = "Eat",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(90, 40),
		BackgroundColor3 = COLORS.good,
		Parent = frame,
	})
	eat.Activated:Connect(function()
		EatRequest:FireServer(item.id)
	end)
	rows[item.id] = { frame = frame, countLabel = countLabel, item = item }
end

local function refresh()
	local energy = player:GetAttribute("Energy") or 0
	energyLine.Text = ("⚡ Energy %d/%d"):format(energy, Config.Energy.max)
	local any = false
	for id, row in rows do
		local n = Ui.bag[id] or 0
		row.frame.Visible = n > 0
		row.countLabel.Text = ("%s  x%d"):format(row.item.name, n)
		any = any or n > 0
	end
	emptyLine.Visible = not any
end

Ui.onOpen("Bag", refresh)

Ui.onBagChanged(function()
	if Ui.isOpen("Bag") then
		refresh()
	end
end)
player:GetAttributeChangedSignal("Energy"):Connect(function()
	if Ui.isOpen("Bag") then
		refresh()
	end
end)
