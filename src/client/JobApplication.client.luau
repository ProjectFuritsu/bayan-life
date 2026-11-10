-- The job application at the Job Center (mall, 1st floor).
-- Step 1: choose a job.  Step 2: requirements check.  Step 3: application form.
-- Then the server checks everything again and starts Step 4: the assessment quiz
-- (QuizWindow). Step 5 is the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameClock = require(Shared:WaitForChild("GameClock"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SubmitApplication = Remotes:WaitForChild("SubmitApplication")

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local STEP_NAMES = { "Choose a job", "Requirements", "Application form", "Assessment", "Result" }

local jobs = {} -- from the server when the menu opens
local chosen = nil -- the job being applied for
local shiftNumber = nil
local agreed = false

local window = Ui.window("Apply", "💼 Job Application", 520)

-- Step bar: 5 numbered dots and the step name
local stepBar = create("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Parent = window,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local dots = {}
for i = 1, #STEP_NAMES do
	dots[i] = text({
		LayoutOrder = i,
		Text = tostring(i),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(26, 26),
		Parent = stepBar,
	}, { Ui.round() })
end
local stepLabel = text({ LayoutOrder = 10, TextSize = 17, Size = UDim2.new(1, -170, 1, 0), Parent = stepBar })

local function setStep(step)
	for i, dot in dots do
		local done, current = i < step, i == step
		dot.BackgroundColor3 = if current then COLORS.header elseif done then COLORS.good else COLORS.barBack
		dot.TextColor3 = if current or done then WHITE else COLORS.muted
	end
	stepLabel.Text = ("  Step %d of %d: %s"):format(step, #STEP_NAMES, STEP_NAMES[step])
end

local function page(order)
	return create("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = window,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(parent, order, height)
	return create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height or 56),
		BackgroundColor3 = COLORS.card,
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 12)),
		create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
end

local choosePage = page(2)
local requirementsPage = page(3)
local formPage = page(4)
local pages = { choosePage, requirementsPage, formPage }

local function showPage(n)
	for i, p in pages do
		p.Visible = i == n
	end
	setStep(n)
end

local showRequirements, showForm -- defined below

------------------------------------------------------------------------
-- Step 1: choose a job
------------------------------------------------------------------------
local function showChoose()
	clear(choosePage)
	text({ LayoutOrder = 0, Text = "Which job are you applying for?", TextSize = 20, Parent = choosePage })
	for i, job in jobs do
		local r = row(choosePage, i)
		local button = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r })
		text({ Text = job.icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(52, 56), Parent = r })
		text({ Text = job.name, TextSize = 20, Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -200, 1, 0), Parent = r })
		local status, color
		if job.hired then
			status, color = "Hired ✅", COLORS.good
		elseif job.comingSoon then
			status, color = "Coming soon", COLORS.lockedStroke
		else
			status, color = "Apply  ›", COLORS.header
		end
		text({
			Text = status,
			TextSize = 16,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 32),
			Parent = r,
		}, { Ui.round() })
		if job.comingSoon or job.hired then
			r.BackgroundTransparency = 0.4
		else
			button.Activated:Connect(function()
				chosen = job
				showRequirements()
			end)
		end
	end
	showPage(1)
end

------------------------------------------------------------------------
-- Step 2: requirements
------------------------------------------------------------------------
showRequirements = function()
	clear(requirementsPage)
	text({ LayoutOrder = 0, Text = ("Requirements for %s %s"):format(chosen.icon, chosen.name), TextSize = 20, Parent = requirementsPage })

	local r1 = row(requirementsPage, 1)
	text({
		Text = ("%s  %s"):format(if chosen.hasUniform then "✅" else "⬜", chosen.uniformName),
		TextSize = 19,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = r1,
	})
	text({
		Text = if chosen.hasUniform then "You have it." else ("Buy it at the 2nd floor stall (%d coins)."):format(chosen.uniformPrice),
		TextSize = 15,
		TextColor3 = if chosen.hasUniform then COLORS.good else COLORS.bad,
		Position = UDim2.fromOffset(40, 30),
		Size = UDim2.new(1, -52, 0, 20),
		Parent = r1,
	})
	local r2 = row(requirementsPage, 2)
	text({ Text = "⬜  Pass the assessment", TextSize = 19, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 26), Parent = r2 })
	text({
		Text = "A short quiz after the form (step 4).",
		TextSize = 15,
		TextColor3 = COLORS.muted,
		Position = UDim2.fromOffset(40, 30),
		Size = UDim2.new(1, -52, 0, 20),
		Parent = r2,
	})

	local buttons = create("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = requirementsPage }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local back = Ui.button({ LayoutOrder = 1, Text = "‹ Back", Size = UDim2.new(0.3, -4, 1, 0), BackgroundColor3 = COLORS.barBack, TextColor3 = COLORS.text, Parent = buttons })
	local nextButton = Ui.button({
		LayoutOrder = 2,
		Text = if chosen.hasUniform then "Next ›" else "Get the uniform first",
		Size = UDim2.new(0.7, -4, 1, 0),
		BackgroundColor3 = if chosen.hasUniform then COLORS.good else COLORS.lockedStroke,
		AutoButtonColor = chosen.hasUniform,
		Parent = buttons,
	})
	back.Activated:Connect(showChoose)
	nextButton.Activated:Connect(function()
		if chosen.hasUniform then
			showForm()
		end
	end)
	showPage(2)
end

------------------------------------------------------------------------
-- Step 3: application form
------------------------------------------------------------------------
showForm = function()
	clear(formPage)
	shiftNumber, agreed = nil, false
	local today = GameClock.day(workspace:GetServerTimeNow())

	local function field(order, label, value)
		local r = row(formPage, order, 40)
		text({ Text = label, TextSize = 16, TextColor3 = COLORS.muted, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.35, 0, 1, 0), Parent = r })
		text({ Text = value, TextSize = 18, Position = UDim2.new(0.35, 0, 0, 0), Size = UDim2.new(0.65, -12, 1, 0), Parent = r })
	end
	field(1, "Name", ("%s (@%s)"):format(player.DisplayName, player.Name))
	field(2, "Applying for", ("%s %s"):format(chosen.icon, chosen.name))
	field(3, "Date", ("Day %d"):format(today))

	text({ LayoutOrder = 4, Text = "Preferred shift:", TextSize = 17, Parent = formPage })
	local shiftButtons = {}
	local submit -- defined below
	local agreeButton

	local function refresh()
		for n, b in shiftButtons do
			local on = n == shiftNumber
			b.BackgroundColor3 = if on then COLORS.header else COLORS.card
			b.TextColor3 = if on then WHITE else COLORS.text
		end
		agreeButton.Text = ("%s  I will follow the work hours and bakery rules."):format(if agreed then "☑" else "☐")
		local wait = chosen.waitSeconds or 0
		local ready = shiftNumber ~= nil and agreed and wait <= 0
		submit.BackgroundColor3 = if ready then COLORS.good else COLORS.lockedStroke
		submit.AutoButtonColor = ready
		submit.Text = if wait > 0 then ("Retake the assessment in %ds"):format(wait) else "Submit and take the assessment ›"
	end

	for n, shift in Config.Shifts do
		local b = Ui.button({
			LayoutOrder = 4 + n,
			Text = shift,
			TextColor3 = COLORS.text,
			BackgroundColor3 = COLORS.card,
			Size = UDim2.new(1, 0, 0, 36),
			Parent = formPage,
		}, { create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		b.Activated:Connect(function()
			shiftNumber = n
			refresh()
		end)
		shiftButtons[n] = b
	end

	agreeButton = Ui.button({
		LayoutOrder = 10,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = formPage,
	})
	agreeButton.Activated:Connect(function()
		agreed = not agreed
		refresh()
	end)

	local buttons = create("Frame", { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = formPage }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local back = Ui.button({ LayoutOrder = 1, Text = "‹ Back", Size = UDim2.new(0.25, -4, 1, 0), BackgroundColor3 = COLORS.barBack, TextColor3 = COLORS.text, Parent = buttons })
	submit = Ui.button({ LayoutOrder = 2, Size = UDim2.new(0.75, -4, 1, 0), Parent = buttons })
	back.Activated:Connect(showRequirements)
	submit.Activated:Connect(function()
		if shiftNumber and agreed and (chosen.waitSeconds or 0) <= 0 then
			SubmitApplication:FireServer(chosen.id, shiftNumber)
			Ui.close("Apply") -- the server opens the quiz next
		end
	end)

	refresh()
	showPage(3)
end

local titleLabel = window:FindFirstChild("Title", true)

Remotes:WaitForChild("OpenJobMenu").OnClientEvent:Connect(function(jobList, centerName)
	jobs = jobList
	chosen = nil
	titleLabel.Text = ("💼 %s"):format(centerName or "Job Application")
	showChoose()
	Ui.open("Apply")
end)
