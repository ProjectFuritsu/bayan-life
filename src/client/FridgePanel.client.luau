-- The house fridge: move bread between your Bag and the fridge.
-- Opened from the fridge inside your house. The server checks every move.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FridgeAction = Remotes:WaitForChild("FridgeAction")

local COLORS = Ui.COLORS
local create, text = Ui.create, Ui.text

local window = Ui.window("Fridge", "🧊 Fridge", 460)
local summary = text({ LayoutOrder = 1, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Parent = window })
local list = create("Frame", {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local rows = {}
for i, item in Config.Bakery.items do
	local frame = create("Frame", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = COLORS.card,
		Parent = list,
	}, {
		Ui.corner(UDim.new(0, 12)),
		create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	text({ Text = item.icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(50, 56), Parent = frame })
	local countLabel = text({ TextSize = 17, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -230, 1, 0), TextWrapped = true, Parent = frame })
	local put = Ui.button({
		Text = "Put in ›",
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(80, 34),
		BackgroundColor3 = COLORS.info,
		Parent = frame,
	})
	local take = Ui.button({
		Text = "‹ Take",
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(80, 34),
		BackgroundColor3 = COLORS.good,
		Parent = frame,
	})
	put.Activated:Connect(function()
		FridgeAction:FireServer(item.id, true)
	end)
	take.Activated:Connect(function()
		FridgeAction:FireServer(item.id, false)
	end)
	rows[item.id] = { countLabel = countLabel, item = item }
end

local function refresh()
	local stored = 0
	for id, row in rows do
		local inBag = Ui.bag[id] or 0
		local inFridge = Ui.fridge[id] or 0
		stored += inFridge
		row.countLabel.Text = ("%s\nBag %d  •  Fridge %d"):format(row.item.name, inBag, inFridge)
	end
	summary.Text = ("Fridge: %d / %d bread  •  Bread in the fridge stays home, safe and saved."):format(stored, Config.Housing.fridgeSize)
end

Ui.onOpen("Fridge", refresh)
for _, key in { "bag", "fridge" } do
	Ui.onChanged(key, function()
		if Ui.isOpen("Fridge") then
			refresh()
		end
	end)
end
Remotes:WaitForChild("OpenFridge").OnClientEvent:Connect(function()
	Ui.open("Fridge")
end)
