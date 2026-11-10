-- The review screen for Application Staff. When an applicant at your window
-- submits their form, this shows their details and a countdown. Press Approve
-- to start their assessment quiz (and get paid). If time runs out, the server
-- approves it automatically with no pay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReviewDecision = Remotes:WaitForChild("ReviewDecision")

local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local endsAt = nil

local window = Ui.window("Review", "🗂️ Review Application", 460)
local reviewTitle = window:FindFirstChild("Title", true)
local whereLabel = text({ LayoutOrder = 1, TextSize = 16, TextColor3 = COLORS.muted, Parent = window })

local card = create("Frame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 100),
	BackgroundColor3 = WHITE,
	Parent = window,
}, {
	Ui.corner(UDim.new(0, 12)),
	create("UIStroke", { Thickness = 2, Color = COLORS.cardStroke }),
})
local photo = create("ImageLabel", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(80, 80),
	BackgroundColor3 = COLORS.barBack,
	Parent = card,
}, { Ui.corner(UDim.new(0, 10)) })
local nameLabel = text({ TextSize = 22, Position = UDim2.fromOffset(100, 10), Size = UDim2.new(1, -110, 0, 26), Parent = card })
local detailLabel = text({
	TextSize = 16,
	TextColor3 = COLORS.muted,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(100, 38),
	Size = UDim2.new(1, -110, 0, 56),
	Parent = card,
})

local checks = text({ LayoutOrder = 3, TextSize = 18, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = window })
local _, timeFill = Ui.bar(4, window, COLORS.header)
local timeLabel = text({ LayoutOrder = 5, TextSize = 16, TextColor3 = COLORS.muted, Parent = window })
local approveButton = Ui.button({ LayoutOrder = 6, Text = "✅ Approve and start assessment", TextSize = 20, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = COLORS.good, Parent = window })

local totalSeconds = 30

approveButton.Activated:Connect(function()
	ReviewDecision:FireServer()
	Ui.close("Review")
	endsAt = nil
end)

RunService.Heartbeat:Connect(function()
	if not endsAt or not Ui.isOpen("Review") then
		return
	end
	local left = math.max(0, endsAt - os.clock())
	timeFill.Size = UDim2.fromScale(left / totalSeconds, 1)
	timeLabel.Text = ("Approve within %d seconds, or it is approved automatically with no pay."):format(math.ceil(left))
end)

Remotes:WaitForChild("ReviewRequest").OnClientEvent:Connect(function(info)
	whereLabel.Text = ("%s  •  Window %d"):format(info.centerName, info.window)
	photo.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(info.applicantId)
	nameLabel.Text = info.applicantName
	if info.kind == "permit" then
		reviewTitle.Text = "🧾 Review Business Permit"
		detailLabel.Text = ("@%s\nBusiness: %s\nType: %s"):format(info.applicantUser, info.businessName, info.businessType)
		checks.Text = ("Requirements:\n✅ Rank %s or higher\n✅ Barangay Clearance\n✅ Permit fee ready (%d coins)"):format(info.rankName, info.fee)
		approveButton.Text = "✅ Approve and issue the permit"
	else
		reviewTitle.Text = "🗂️ Review Application"
		detailLabel.Text = ("@%s\nApplying for: %s %s\nPreferred shift: %s"):format(info.applicantUser, info.jobIcon, info.jobName, info.shift)
		checks.Text = ("Requirements:\n✅ %s\n✅ Application form filled in"):format(info.uniformName)
		approveButton.Text = "✅ Approve and start assessment"
	end
	totalSeconds = info.seconds
	endsAt = os.clock() + info.seconds
	Ui.open("Review")
end)

Remotes:WaitForChild("ReviewClosed").OnClientEvent:Connect(function()
	endsAt = nil
	Ui.close("Review")
end)
