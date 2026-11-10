-- Payroll window: wages this pay period, the latest payslip (gross, government
-- deductions, net pay), older payslips, and your total contributions.
-- Opened with the 💰 Pay button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local COLORS = Ui.COLORS
local create, text = Ui.create, Ui.text

local window = Ui.window("Pay", "💰 Payroll", 480)
local list = create("ScrollingFrame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 380),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.outline,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = window,
}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(message, color, size)
		order += 1
		text({
			LayoutOrder = order,
			Text = message,
			TextSize = size or 16,
			TextColor3 = color or COLORS.text,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -10, 0, 20),
			Parent = list,
		})
	end
	local function title(message)
		line(message, COLORS.info, 17)
	end

	local pay = Ui.pay
	local p = pay.payroll or {}

	-- This pay period
	title(("THIS PAY PERIOD  •  next payday: Day %d"):format(pay.nextPayday or 0))
	if (p.shifts or 0) == 0 then
		line("No shifts yet this period. Work inside your schedule to earn your hourly wage.", COLORS.muted)
	else
		line(("Since Day %d: %d shifts  •  %.1f paid hours"):format(p.periodStart or 0, p.shifts, p.hours or 0))
		line(("Late: %d min  •  Undertime: %d min"):format(p.late or 0, p.undertime or 0), if (p.late or 0) + (p.undertime or 0) > 0 then COLORS.bad else COLORS.muted, 15)
		line(("Wage so far (before deductions): %d coins"):format(p.pending or 0), COLORS.good)
	end

	-- Latest payslip
	local latest = pay.payslips and pay.payslips[1]
	title("LATEST PAYSLIP")
	if not latest then
		line("No payslip yet. Your first one comes on payday.", COLORS.muted)
	else
		line(("Payday: Day %d  •  Period: Day %d to %d"):format(latest.payday, latest.periodStart, latest.payday - 1))
		line(("%d shifts  •  %.1f paid hours  •  Late %d min  •  Undertime %d min"):format(latest.shifts, latest.hours, latest.late, latest.undertime), COLORS.muted, 15)
		line(("Gross pay: %d coins"):format(latest.gross))
		for _, d in latest.deductions do
			line(("   − %s: %d"):format(d.name, d.amount), COLORS.bad, 15)
		end
		line("   − Withholding tax: exempt (minimum wage)", COLORS.muted, 15)
		line(("NET PAY: %d coins ✅"):format(latest.net), COLORS.good, 19)
		if latest.note then
			line(latest.note, COLORS.bad, 15)
		end
	end

	-- Older payslips
	if pay.payslips and #pay.payslips > 1 then
		title("OLDER PAYSLIPS")
		for i = 2, #pay.payslips do
			local s = pay.payslips[i]
			line(("Day %d  •  gross %d  •  net %d"):format(s.payday, s.gross, s.net), COLORS.muted, 15)
		end
	end

	-- Contributions
	title("YOUR CONTRIBUTIONS SO FAR")
	local c = pay.contributions or {}
	local parts = {}
	for _, d in Config.Payroll.deductions do
		table.insert(parts, ("%s %d"):format(d.name, c[d.name] or 0))
	end
	line(table.concat(parts, "  •  "))
	line("SSS: pension and help when sick or retired.  PhilHealth: health insurance.  Pag-IBIG: savings and housing loans.", COLORS.muted, 14)
end

Ui.onOpen("Pay", refresh)
Ui.onChanged("pay", function()
	if Ui.isOpen("Pay") then
		refresh()
	end
end)
