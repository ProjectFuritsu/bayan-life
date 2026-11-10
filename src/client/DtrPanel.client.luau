-- Daily Time Record (DTR): one row per shift — day, job, time in, time out,
-- orders served and coins earned. The current shift is on top in green.
-- Opened with the 📋 DTR button. The server saves the DTR with your progress.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameClock = require(Shared:WaitForChild("GameClock"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local COLORS = Ui.COLORS
local create, text = Ui.create, Ui.text

local state = { onShift = false }

local window = Ui.window("DTR", "📋 Daily Time Record", 700)

-- Column widths (as a share of the row) and titles.
-- Hours = paid hours inside your schedule. Late / UT = late and undertime minutes.
-- Wage = hourly pay (paid on payday). Tasks = coins earned right away.
local COLUMNS = {
	{ title = "Day", width = 0.09 },
	{ title = "Job", width = 0.16 },
	{ title = "Time In", width = 0.14 },
	{ title = "Time Out", width = 0.14 },
	{ title = "Hours", width = 0.09 },
	{ title = "Late / UT", width = 0.15 },
	{ title = "Wage", width = 0.1 },
	{ title = "Tasks", width = 0.13 },
}

local function lateText(entry)
	if entry.hours == nil then
		return "-" -- an older entry, before schedules
	elseif entry.hours == 0 and (entry.late or 0) == 0 then
		return "Outside"
	elseif (entry.late or 0) + (entry.undertime or 0) == 0 then
		return "On time"
	end
	return ("%dm / %dm"):format(entry.late or 0, entry.undertime or 0)
end

local function row(values, layoutOrder, background, color, parent)
	local frame = create("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundColor3 = background,
		BackgroundTransparency = if background then 0 else 1,
		Parent = parent,
	}, {
		Ui.corner(UDim.new(0, 8)),
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, column in COLUMNS do
		text({
			LayoutOrder = i,
			Text = values[i] or "",
			TextSize = 15,
			TextColor3 = color or COLORS.text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(column.width, 0, 1, 0),
			Parent = frame,
		})
	end
	return frame
end

local titles = {}
for i, column in COLUMNS do
	titles[i] = column.title
end
row(titles, 1, COLORS.barBack, COLORS.text, window)

local list = create("ScrollingFrame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 260),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.outline,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local footer = text({ LayoutOrder = 3, TextSize = 16, TextColor3 = COLORS.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = window })

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local count = 0
	if state.onShift then
		count += 1
		row({
			tostring(state.day),
			state.job,
			GameClock.format(state.timeIn),
			"On shift",
			"",
			"",
			"",
			"+" .. tostring(state.earned),
		}, count, COLORS.needed, COLORS.good, list)
	end

	local entries = Ui.dtr
	local totalWage, totalTasks = 0, 0
	for _, entry in entries do
		count += 1
		totalWage += entry.wage or 0
		totalTasks += entry.earned or 0
		local late = (entry.late or 0) + (entry.undertime or 0) > 0
		row({
			tostring(entry.day),
			entry.job,
			GameClock.format(entry.timeIn),
			GameClock.format(entry.timeOut),
			if entry.hours then ("%.1f"):format(entry.hours) else "-",
			lateText(entry),
			if entry.wage then tostring(entry.wage) else "-",
			"+" .. tostring(entry.earned),
		}, count, if count % 2 == 0 then COLORS.card else nil, if late then COLORS.bad else nil, list)
	end

	if count == 0 then
		row({ "", "", "No shifts", "yet.", "", "Clock in!", "", "" }, 1, nil, COLORS.muted, list)
	end
	footer.Text = ("%d saved shifts  •  Wages: %d (paid on payday)  •  Tasks: %d coins"):format(#entries, totalWage, totalTasks)
end

Ui.onOpen("DTR", refresh)

Ui.onChanged("dtr", function()
	if Ui.isOpen("DTR") then
		refresh()
	end
end)
Remotes:WaitForChild("JobState").OnClientEvent:Connect(function(newState)
	state = newState
	if Ui.isOpen("DTR") then
		refresh()
	end
end)
