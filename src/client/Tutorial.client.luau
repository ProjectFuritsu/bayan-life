-- The welcome tutorial: a few short pages about how Bayan Life works.
-- It opens by itself for new players (once), and any time with the ❓ Help button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TutorialDone = Remotes:WaitForChild("TutorialDone")

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local PAGES = {
	{
		icon = "🇵🇭",
		title = "Welcome to Bayan Life!",
		body = "Work real jobs, earn coins, and build your own business in the town of Bayan.\n\nThis short guide shows you how. You can open it again anytime with the ❓ Help button.",
	},
	{
		icon = "🚏",
		title = "The town",
		body = "You start at the plaza. Follow the signs:\n🍞 Bakery and 🏪 Market (east)\n🛍️ Bayan Mall (north)\n🏛️ Town Hall (west)\n🏘️ Bayan Heights houses (south)",
	},
	{
		icon = "💼",
		title = "Get a job",
		body = "1. Buy the job's uniform at Bayan Mall, 2nd floor.\n2. Apply at its Job Center: the Mall (Baker) or the Town Hall (Staff, Cleanup Crew).\n3. Take a number, fill in the form, and pass a short quiz.",
	},
	{
		icon = "🕐",
		title = "Go to work",
		body = "Clock in at your job's time clock during your schedule. Be on time!\n\nTasks pay right away. Your hourly wage is paid on payday, with a payslip (open 💰 Pay). Your DTR keeps every shift.",
	},
	{
		icon = "⚡",
		title = "Energy",
		body = "Working uses energy. Buy bread at the bakery's \"Order Here\" counter, then eat it from your 🎒 Bag.\n\nYou also rest a little every night.",
	},
	{
		icon = "🏪",
		title = "Own a business",
		body = "Reach Worker rank, get a Barangay Clearance and a Business Permit at the Town Hall, then buy a stall at the Bayan Public Market.\n\nHave fun, and welcome to Bayan!",
	},
}

local page = 1

local window = Ui.window("Tutorial", "❓ How to play", 480)
local iconLabel = text({ LayoutOrder = 1, TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 64), Parent = window })
local titleLabel = text({ LayoutOrder = 2, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 32), Parent = window })
local bodyLabel = text({
	LayoutOrder = 3,
	TextSize = 18,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 0, 160),
	Parent = window,
})

-- Page dots
local dotRow = create("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = window }, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local dots = {}
for i = 1, #PAGES do
	dots[i] = create("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(10, 10), BackgroundColor3 = COLORS.barBack, Parent = dotRow }, { Ui.round() })
end

local buttons = create("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = window }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local skipButton = Ui.button({ LayoutOrder = 1, Text = "Skip", Size = UDim2.new(0.25, -6, 1, 0), BackgroundColor3 = COLORS.barBack, TextColor3 = COLORS.text, Parent = buttons })
local backButton = Ui.button({ LayoutOrder = 2, Text = "‹ Back", Size = UDim2.new(0.3, -6, 1, 0), BackgroundColor3 = COLORS.card, TextColor3 = COLORS.text, Parent = buttons })
local nextButton = Ui.button({ LayoutOrder = 3, Size = UDim2.new(0.45, -6, 1, 0), BackgroundColor3 = COLORS.good, Parent = buttons })

local function show()
	local p = PAGES[page]
	iconLabel.Text = p.icon
	titleLabel.Text = p.title
	bodyLabel.Text = p.body
	for i, dot in dots do
		dot.BackgroundColor3 = if i == page then COLORS.header else COLORS.barBack
	end
	backButton.Visible = page > 1
	nextButton.Text = if page == #PAGES then "Let's go! ✅" else "Next ›"
end

local function finish()
	Ui.close("Tutorial")
	if not player:GetAttribute("TutorialDone") then
		TutorialDone:FireServer()
	end
end

nextButton.Activated:Connect(function()
	if page < #PAGES then
		page += 1
		show()
	else
		finish()
	end
end)
backButton.Activated:Connect(function()
	if page > 1 then
		page -= 1
		show()
	end
end)
skipButton.Activated:Connect(finish)

Ui.onOpen("Tutorial", function()
	page = 1
	show()
end)

-- The ❓ Help button, in the left tool row under the coins card
local help = Ui.button({
	Name = "HelpButton",
	LayoutOrder = 2,
	Text = "❓ Help",
	TextSize = 15,
	Size = UDim2.fromOffset(84, 28),
	BackgroundColor3 = COLORS.info,
	TextColor3 = WHITE,
	Parent = Ui.toolRow,
})
help.Activated:Connect(function()
	Ui.toggle("Tutorial")
end)

-- New players see the tutorial once, a moment after their data loads.
local function maybeOpen()
	if player:GetAttribute("DataLoaded") and player:GetAttribute("TutorialDone") == false then
		task.delay(2, function()
			if player:GetAttribute("TutorialDone") == false then
				Ui.open("Tutorial")
			end
		end)
	end
end
player:GetAttributeChangedSignal("DataLoaded"):Connect(maybeOpen)
maybeOpen()
