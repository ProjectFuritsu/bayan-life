-- The Business Permit application form (BPLO window at the Town Hall).
-- Shows the requirements, lets you pick the business type and name, and sends
-- the form. The server checks everything again; then a staff member reviews it,
-- or it is processed automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SubmitPermit = Remotes:WaitForChild("SubmitPermit")

local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local window = Ui.window("Permit", "🧾 Business Permit Application", 500)
local body = create("Frame", {
	LayoutOrder = 1,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function optionButton(order, label, selected, enabled)
	return Ui.button({
		LayoutOrder = order,
		Text = label,
		TextSize = 17,
		TextColor3 = if selected then WHITE elseif enabled then COLORS.text else COLORS.muted,
		BackgroundColor3 = if selected then COLORS.header elseif enabled then COLORS.card else COLORS.locked,
		AutoButtonColor = enabled,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = body,
	}, { create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
end

local function render(info, typeNumber, nameNumber, agreed)
	clear()
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function line(message, color, size)
		text({ LayoutOrder = nextOrder(), Text = message, TextColor3 = color or COLORS.text, TextSize = size or 17, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	end

	local req = info.requirements
	if req.hasPermit then
		line("You already have a Business Permit. Buy a FOR SALE stall at the Bayan Public Market.", COLORS.good)
		return
	end

	-- Requirements
	line("REQUIREMENTS", COLORS.info, 16)
	line(("%s  Rank %s or higher"):format(if req.rankOk then "✅" else "⬜", req.rankName), if req.rankOk then COLORS.good else COLORS.bad)
	line(
		("%s  Barangay Clearance (kiosk inside the Town Hall, %d coins)"):format(if req.clearance then "✅" else "⬜", info.clearancePrice),
		if req.clearance then COLORS.good else COLORS.bad
	)
	line(("%s  Permit fee: %d coins (paid when approved)"):format(if req.coinsOk then "✅" else "⬜", info.fee), if req.coinsOk then COLORS.good else COLORS.bad)

	-- Business type
	line("BUSINESS TYPE", COLORS.info, 16)
	for i, typeName in info.types do
		optionButton(nextOrder(), typeName, i == typeNumber, true).Activated:Connect(function()
			render(info, i, nameNumber, agreed)
		end)
	end
	for _, typeName in info.comingSoonTypes do
		optionButton(nextOrder(), typeName .. " (coming soon)", false, false)
	end

	-- Business name
	line("BUSINESS NAME", COLORS.info, 16)
	for i, name in info.names do
		optionButton(nextOrder(), name, i == nameNumber, true).Activated:Connect(function()
			render(info, typeNumber, i, agreed)
		end)
	end

	local agree = Ui.button({
		LayoutOrder = nextOrder(),
		Text = ("%s  I declare that the information above is true."):format(if agreed then "☑" else "☐"),
		TextSize = 16,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = body,
	})
	agree.Activated:Connect(function()
		render(info, typeNumber, nameNumber, not agreed)
	end)

	local allMet = req.rankOk and req.clearance and req.coinsOk
	local ready = allMet and typeNumber ~= nil and nameNumber ~= nil and agreed
	local submit = Ui.button({
		LayoutOrder = nextOrder(),
		Text = if not allMet then "Complete the requirements first" elseif ready then "Submit application ›" else "Pick a type and name, and tick the box",
		TextSize = 19,
		BackgroundColor3 = if ready then COLORS.good else COLORS.lockedStroke,
		AutoButtonColor = ready,
		Size = UDim2.new(1, 0, 0, 42),
		Parent = body,
	})
	submit.Activated:Connect(function()
		if ready then
			SubmitPermit:FireServer(typeNumber, nameNumber)
			Ui.close("Permit")
		end
	end)
end

local titleLabel = window:FindFirstChild("Title", true)

Remotes:WaitForChild("OpenPermitForm").OnClientEvent:Connect(function(info)
	titleLabel.Text = "🧾 " .. (info.centerName or "Business Permit")
	render(info, 1, nil, false)
	Ui.open("Permit")
end)
