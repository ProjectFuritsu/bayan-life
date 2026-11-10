-- The job assessment (quiz). One question at a time, three choices each.
-- The client never knows the right answers: it sends the picks to the server,
-- and the server sends back the score.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SubmitQuiz = Remotes:WaitForChild("SubmitQuiz")

local COLORS = Ui.COLORS
local create, text = Ui.create, Ui.text

local questions = {}
local answers = {}
local index = 1

local window = Ui.window("Quiz", "📝 Assessment", 480)
local title = window:FindFirstChild("Title", true)

-- Quiz page
local quizPage = create("Frame", {
	LayoutOrder = 1,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local progressLabel = text({ LayoutOrder = 1, TextSize = 16, TextColor3 = COLORS.muted, Parent = quizPage })
local _, progressFill = Ui.bar(2, quizPage, COLORS.header)
local questionLabel = text({
	LayoutOrder = 3,
	TextSize = 22,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = quizPage,
})
local choiceList = create("Frame", {
	LayoutOrder = 4,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = quizPage,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local footer = text({
	LayoutOrder = 5,
	TextSize = 15,
	TextColor3 = COLORS.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = quizPage,
})

-- Result page
local resultPage = create("Frame", {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
local resultTitle = text({ LayoutOrder = 1, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 36), Parent = resultPage })
local resultText = text({
	LayoutOrder = 2,
	TextSize = 18,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = resultPage,
})
local idButton = Ui.button({ LayoutOrder = 3, Text = "🪪 View my Employee ID", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = COLORS.info, Parent = resultPage })
idButton.Activated:Connect(function()
	Ui.open("EmployeeID")
end)
local closeButton = Ui.button({ LayoutOrder = 4, Text = "Close", Size = UDim2.new(1, 0, 0, 40), Parent = resultPage })
closeButton.Activated:Connect(function()
	Ui.close("Quiz")
end)

local showQuestion -- defined below

local function choiceButton(label, number)
	local button = Ui.button({
		LayoutOrder = number,
		Text = label,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = COLORS.text,
		BackgroundColor3 = COLORS.card,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = choiceList,
	}, { create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	button.Activated:Connect(function()
		if answers[index] then
			return -- already picked for this question
		end
		answers[index] = number
		button.BackgroundColor3 = COLORS.pill -- show the pick; no right/wrong yet
		task.delay(0.25, function()
			index += 1
			if index > #questions then
				questionLabel.Text = "Checking your answers..."
				for _, child in choiceList:GetChildren() do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				SubmitQuiz:FireServer(answers)
			else
				showQuestion()
			end
		end)
	end)
end

showQuestion = function()
	local q = questions[index]
	progressLabel.Text = ("Application step 4 of 5  •  Question %d of %d"):format(index, #questions)
	progressFill.Size = UDim2.fromScale((index - 1) / #questions, 1)
	questionLabel.Text = q.question
	for _, child in choiceList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for number, label in q.choices do
		choiceButton(label, number)
	end
end

Remotes:WaitForChild("OpenQuiz").OnClientEvent:Connect(function(jobName, newQuestions, passScore)
	questions = newQuestions
	answers = {}
	index = 1
	title.Text = ("📝 %s Assessment"):format(jobName)
	footer.Text = ("Get %d of %d right to pass."):format(passScore, #questions)
	quizPage.Visible = true
	resultPage.Visible = false
	showQuestion()
	Ui.open("Quiz")
end)

Remotes:WaitForChild("QuizResult").OnClientEvent:Connect(function(result)
	quizPage.Visible = false
	resultPage.Visible = true
	idButton.Visible = result.passed
	if result.passed then
		resultTitle.Text = ("🎉 Hired! %d/%d"):format(result.score, result.total)
		resultTitle.TextColor3 = COLORS.good
		resultText.Text = ("Welcome to the team! You are now a %s. Clock in at the bakery's Time Clock to start."):format(result.jobName)
	else
		resultTitle.Text = ("You got %d/%d"):format(result.score, result.total)
		resultTitle.TextColor3 = COLORS.bad
		resultText.Text = ("You need %d to pass. Study the job tips and try again in %d seconds."):format(result.passScore, result.retrySeconds)
	end
	closeButton.BackgroundColor3 = if result.passed then COLORS.good else COLORS.header
	Ui.open("Quiz")
end)
