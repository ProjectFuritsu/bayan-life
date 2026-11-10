-- The Employee ID card: who you are, the jobs you are hired for, your work
-- history (lifetime totals and your latest shifts), and your business permit.
-- Opened with the 🪪 ID button, or after you get hired.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameClock = require(Shared:WaitForChild("GameClock"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text = Ui.create, Ui.text

local RECENT_SHIFTS = 3

local window = Ui.window("EmployeeID", "🪪 Employee ID", 480)

-- The card
local card = create("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = WHITE,
	Parent = window,
}, {
	Ui.corner(UDim.new(0, 14)),
	create("UIStroke", { Thickness = 2, Color = COLORS.info }),
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
})
text({
	LayoutOrder = 1,
	Text = "BAYAN LIFE  •  EMPLOYEE ID",
	TextSize = 16,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Center,
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.info,
	Size = UDim2.new(1, 0, 0, 28),
	Parent = card,
}, { Ui.corner(UDim.new(0, 8)) })

-- Photo and details
local top = create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, Parent = card })
create("ImageLabel", {
	Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId),
	Size = UDim2.fromOffset(100, 100),
	BackgroundColor3 = COLORS.barBack,
	Parent = top,
}, { Ui.corner(UDim.new(0, 12)) })
local nameLabel = text({ TextSize = 22, Position = UDim2.fromOffset(112, 0), Size = UDim2.new(1, -112, 0, 28), Parent = top })
local detailLabel = text({
	TextSize = 15,
	TextColor3 = COLORS.muted,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(112, 30),
	Size = UDim2.new(1, -112, 0, 70),
	Parent = top,
})

local jobsBox = create("Frame", {
	LayoutOrder = 3,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = card,
}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function sectionTitle(parent, order, label)
	text({ LayoutOrder = order, Text = label, TextSize = 17, TextColor3 = COLORS.info, Parent = parent })
end

local function line(parent, order, message, color, size)
	text({
		LayoutOrder = order,
		Text = message,
		TextSize = size or 16,
		TextColor3 = color or COLORS.text,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
end

local function refresh()
	for _, child in jobsBox:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	nameLabel.Text = player.DisplayName
	detailLabel.Text = ("@%s\nEmployee No.: BL-%d\nRank: %s"):format(
		player.Name,
		player.UserId,
		tostring(player:GetAttribute("Rank") or "...")
	)

	local employment = Ui.employee.employment or {}
	local stats = Ui.employee.workStats or {}
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- Jobs
	sectionTitle(jobsBox, nextOrder(), "JOBS")
	local hiredAny = false
	for _, jobId in Config.JobOrder do
		local record = employment[jobId]
		if record then
			hiredAny = true
			local job = Config.Jobs[jobId]
			line(jobsBox, nextOrder(), ("%s %s  •  Hired Day %d"):format(job.icon, job.name, record.hiredDay or 0))
			line(jobsBox, nextOrder(), ("Preferred shift: %s"):format(record.shift or "-"), COLORS.muted, 14)
		end
	end
	if not hiredAny then
		line(jobsBox, nextOrder(), "Not hired yet. Apply at a Job Center (Bayan Mall or the Town Hall).", COLORS.muted)
	end

	-- Work history: lifetime totals per job
	sectionTitle(jobsBox, nextOrder(), "WORK HISTORY")
	local totalShifts, totalTasks, totalEarned = 0, 0, 0
	for _, jobId in Config.JobOrder do
		local s = stats[jobId]
		if s then
			local job = Config.Jobs[jobId]
			line(jobsBox, nextOrder(), ("%s %s: %d shifts  •  %d tasks  •  %d coins"):format(job.icon, job.name, s.shifts, s.orders, s.earned))
			totalShifts += s.shifts
			totalTasks += s.orders
			totalEarned += s.earned
		end
	end
	if totalShifts == 0 then
		line(jobsBox, nextOrder(), "No shifts worked yet.", COLORS.muted)
	else
		line(jobsBox, nextOrder(), ("Total: %d shifts  •  %d tasks  •  %d coins earned"):format(totalShifts, totalTasks, totalEarned), COLORS.good)
	end

	-- Business permit and market stall
	local permit = Ui.employee.permit or {}
	if permit.number then
		sectionTitle(jobsBox, nextOrder(), "BUSINESS")
		line(jobsBox, nextOrder(), ("🏪 %s  •  %s"):format(permit.businessName or "?", permit.businessType or "?"))
		line(jobsBox, nextOrder(), ("Permit %s  •  Issued Day %d"):format(permit.number, permit.issuedDay or 0), COLORS.muted, 14)
		local stall = if player:GetAttribute("OwnsStore") then "Market stall: owned ✅" else "Market stall: not bought yet (Bayan Public Market)"
		line(jobsBox, nextOrder(), stall, COLORS.muted, 14)
	end

	-- Home
	if player:GetAttribute("Renting") then
		sectionTitle(jobsBox, nextOrder(), "HOME")
		local address = player:GetAttribute("HomeAddress")
		local area = Config.housingArea(player:GetAttribute("RentArea"))
		line(jobsBox, nextOrder(), ("🏠 %s, %s  •  Rent %d per pay period"):format(address or "Waiting for a free house", area.name, area.rent))
	end

	-- Latest shifts (from the DTR)
	if #Ui.dtr > 0 then
		sectionTitle(jobsBox, nextOrder(), "LATEST SHIFTS")
		for i = 1, math.min(RECENT_SHIFTS, #Ui.dtr) do
			local entry = Ui.dtr[i]
			line(
				jobsBox,
				nextOrder(),
				("Day %d  •  %s  •  %s - %s  •  %d tasks  •  +%d"):format(
					entry.day or 0,
					entry.job or "?",
					GameClock.format(entry.timeIn or 0),
					GameClock.format(entry.timeOut or 0),
					entry.orders or 0,
					entry.earned or 0
				),
				COLORS.muted,
				14
			)
		end
	end
end

Ui.onOpen("EmployeeID", refresh)
for _, key in { "employee", "dtr" } do
	Ui.onChanged(key, function()
		if Ui.isOpen("EmployeeID") then
			refresh()
		end
	end)
end
for _, attribute in { "Rank", "OwnsStore" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if Ui.isOpen("EmployeeID") then
			refresh()
		end
	end)
end
