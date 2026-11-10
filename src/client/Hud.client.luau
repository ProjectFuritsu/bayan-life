-- The always-on screen: coins, rank, XP, energy, the clock, the job panel
-- (for bakers) or your order (for customers), and pop-up messages.
-- It also hides prompts that are not for your role right now
-- (bakers see work prompts, customers see "Order Bread").
-- It only shows data; the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameClock = require(Shared:WaitForChild("GameClock"))
local Progression = require(Shared:WaitForChild("Progression"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local COLORS, WHITE = Ui.COLORS, Ui.WHITE
local create, text, total = Ui.create, Ui.text, Ui.total

local state = { onShift = false } -- the baker state from the server
local myOrder = nil -- the order I placed as a customer, or nil
local myQueue = nil -- Job Center: { ticket, ahead } while waiting, { reviewBy } during review, or nil
local workState = nil -- Staff or Cleanup shift info from the server, or nil
local bagCount = 0

------------------------------------------------------------------------
-- Top left: coins, rank, XP, energy, and the DTR / Bag buttons.
------------------------------------------------------------------------
local stats = Ui.panel({ Name = "Stats", LayoutOrder = 1, Parent = Ui.leftColumn }) -- under the clock
local coinsLabel = text({ LayoutOrder = 1, TextSize = 26, Parent = stats })
local rankLabel = text({ LayoutOrder = 2, TextColor3 = COLORS.rank, Parent = stats })
local _, xpFill = Ui.bar(3, stats)
local goalLabel = text({ LayoutOrder = 4, TextSize = 16, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = stats })
local energyLabel = text({ LayoutOrder = 5, TextSize = 18, Parent = stats })
local _, energyFill = Ui.bar(6, stats, COLORS.energy)
local payLabel = text({ LayoutOrder = 7, TextSize = 15, TextColor3 = COLORS.muted, Parent = stats })

local buttonRow = create("Frame", {
	LayoutOrder = 8,
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Parent = stats,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local quarter = UDim2.new(1 / 4, -6, 1, 0)
local dtrButton = Ui.button({ LayoutOrder = 1, Text = "📋 DTR", TextSize = 14, Size = quarter, Parent = buttonRow })
local bagButton = Ui.button({ LayoutOrder = 2, Text = "🎒 Bag", TextSize = 14, Size = quarter, Parent = buttonRow })
local idButton = Ui.button({ LayoutOrder = 3, Text = "🪪 ID", TextSize = 14, Size = quarter, Parent = buttonRow })
local payButton = Ui.button({ LayoutOrder = 4, Text = "💰 Pay", TextSize = 14, Size = quarter, Parent = buttonRow })
payButton.Activated:Connect(function()
	Ui.toggle("Pay")
end)
dtrButton.Activated:Connect(function()
	Ui.toggle("DTR")
end)
bagButton.Activated:Connect(function()
	Ui.toggle("Bag")
end)
idButton.Activated:Connect(function()
	Ui.toggle("EmployeeID")
end)

-- A "+12" or "-500" that floats up from the coins and fades.
local lastCoins = nil
local function coinPop()
	local coins = player:GetAttribute("Coins")
	if coins == nil then
		return
	end
	local diff = if lastCoins then coins - lastCoins else 0
	lastCoins = coins
	if diff == 0 then
		return
	end
	local gain = diff > 0
	local pop = text({
		Text = if gain then ("+%d 🪙"):format(diff) else ("%d 🪙"):format(diff),
		TextSize = 22,
		TextColor3 = if gain then COLORS.good else COLORS.bad,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(146, -8), -- beside the coins number (it moves with the card)
		Size = UDim2.fromOffset(120, 28),
		ZIndex = 5,
		Parent = coinsLabel,
	})
	if gain then
		Ui.playSound("coin", 1, 0.45, "pop")
	end
	Ui.tween(pop, 1.1, { Position = UDim2.fromOffset(146, -32), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(1.2, function()
		pop:Destroy()
	end)
end
player:GetAttributeChangedSignal("Coins"):Connect(coinPop)

local function updateStats()
	local xp = player:GetAttribute("XP") or 0
	coinsLabel.Text = "Coins: " .. tostring(player:GetAttribute("Coins") or 0)
	rankLabel.Text = "Rank: " .. tostring(player:GetAttribute("Rank") or "...")

	local current = Progression.getRank(xp)
	local nextRank = Progression.getNextRank(xp)
	local goal
	if nextRank then
		local progress = (xp - current.minXP) / (nextRank.minXP - current.minXP)
		xpFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		goal = ("Next goal: %s in %d XP"):format(nextRank.name, nextRank.minXP - xp)
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		goal = "Top rank! Next goal: save up to own a bakery (coming soon)."
	end
	if player:GetAttribute("SaveOff") then
		goal ..= "\nProgress is not saving in this session."
	end
	goalLabel.Text = goal

	local energy = player:GetAttribute("Energy") or 0
	local low = energy < Config.Energy.lowWarning
	energyLabel.Text = ("⚡ Energy %d/%d"):format(energy, Config.Energy.max)
	energyLabel.TextColor3 = if low then COLORS.bad else COLORS.text
	energyFill.Size = UDim2.fromScale(math.clamp(energy / Config.Energy.max, 0, 1), 1)
	energyFill.BackgroundColor3 = if low then COLORS.bad else COLORS.energy
end

local function updateBagButton()
	bagButton.Text = if bagCount > 0 then ("🎒 %d"):format(bagCount) else "🎒 Bag"
end

local function updatePayLabel()
	local pay = Ui.pay
	local pending = pay.payroll and pay.payroll.pending or 0
	payLabel.Text = ("💰 Payday: Day %d  •  Wage so far: %d"):format(pay.nextPayday or 0, pending)
end
Ui.onChanged("pay", updatePayLabel)
updatePayLabel()

------------------------------------------------------------------------
-- Left edge, at the very top (above the coins card): the game clock.
------------------------------------------------------------------------
local clockPill = create("Frame", {
	Name = "Clock",
	LayoutOrder = 0,
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = COLORS.panel,
	Parent = Ui.leftColumn,
}, {
	Ui.round(),
	create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	create("UIStroke", { Color = COLORS.outline, Thickness = 2 }),
})
local clockLabel = text({ Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = clockPill })

------------------------------------------------------------------------
-- Mid right: the job panel (baker) or "your order" (customer).
-- Placed below the top so the Roblox player list does not cover it.
------------------------------------------------------------------------
local job = Ui.panel({ Name = "Job", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Parent = Ui.screen }, 300)
local jobTitle = text({ LayoutOrder = 1, TextSize = 24, Parent = job })
local jobLines = create("Frame", {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = job,
}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local timerBack, timerFill = Ui.bar(3, job, COLORS.info)
local timerLabel = text({ LayoutOrder = 4, TextSize = 16, Parent = job })
local ovenLabel = text({ LayoutOrder = 5, TextSize = 16, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = job })

-- Bread in the oven and waiting for the oven, as counts.
local function ovenCounts()
	local counts = {}
	if state.baking then
		counts[state.baking.id] = 1
	end
	for _, id in state.queueIds or {} do
		counts[id] = (counts[id] or 0) + 1
	end
	return counts
end

-- True if these places together hold everything the order needs.
local function covers(order, ...)
	local sources = { ... }
	for id, needed in order.items do
		local have = 0
		for _, counts in sources do
			have += counts[id] or 0
		end
		if have < needed then
			return false
		end
	end
	return true
end

-- A short tip for the baker on what to do next.
local function nextStep()
	local first = state.orders and state.orders[1]
	if not first then
		return "Wait for a customer to order."
	end
	if covers(first, state.case) then
		return "Serve the order at the Counter!"
	elseif covers(first, state.case, state.carrying) then
		return "Bring the bread to the Counter."
	elseif covers(first, state.case, state.carrying, state.rack) then
		return "Pick up bread at a Bread Rack."
	elseif covers(first, state.case, state.carrying, state.rack, ovenCounts()) then
		return "Wait for the oven, then pick up."
	end
	return "Bake the missing bread at the Oven."
end

local function itemsText(items)
	local parts = {}
	for _, item in Config.Bakery.items do
		local n = items[item.id]
		if n then
			table.insert(parts, ("%s %d %s"):format(item.icon, n, item.name))
		end
	end
	return table.concat(parts, ", ")
end

local function renderPanel()
	for _, child in jobLines:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local count = 0
	local function line(message, color, size)
		count += 1
		text({
			LayoutOrder = count,
			Text = message,
			TextColor3 = color or COLORS.text,
			TextSize = size or 18,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = jobLines,
		})
	end

	-- The panel shows only when there is something to follow: a shift, a bread
	-- order, or the steps to get hired. Otherwise it is hidden.
	job.Visible = true

	if not state.onShift then
		ovenLabel.Visible = false
		timerBack.Visible = false
		timerLabel.Visible = false

		if workState and workState.jobId == "staff" then
			-- Application Staff on shift.
			jobTitle.Text = "🗂️ Application Staff"
			line(workState.window or "No window yet", if workState.window then COLORS.text else COLORS.muted)
			line("👉 " .. workState.status, COLORS.info)
			line(("Approved: %d  •  +%d coins"):format(workState.tasks, workState.earned), COLORS.muted, 16)
			return
		elseif workState and workState.jobId == "cleanup" then
			-- Cleanup Crew on shift.
			local full = workState.bag >= workState.bagSize
			local clean = workState.litterLeft == 0
			jobTitle.Text = "🧹 Cleanup Crew"
			line(("Bag: %d/%d"):format(workState.bag, workState.bagSize), if full then COLORS.bad else COLORS.text)
			local hint
			if full or (clean and workState.bag > 0) then
				hint = "👉 Empty your bag at the Town Hall dumpster."
			elseif clean then
				hint = "✨ The town is clean! New litter comes tomorrow morning."
			else
				hint = "👉 Pick up litter around the plaza and paths."
			end
			line(hint, if clean and workState.bag == 0 then COLORS.good else COLORS.info)
			line(("Litter in town: %d"):format(workState.litterLeft), COLORS.muted, 15)
			line(("Collected: %d  •  +%d coins"):format(workState.tasks, workState.earned), COLORS.muted, 16)
			return
		end

		if myQueue and myQueue.processingUntil then
			-- No staff at the BPLO window: the permit is processed after a wait.
			jobTitle.Text = "🧾 Processing your permit"
			local seconds = math.max(0, math.ceil(myQueue.processingUntil - workspace:GetServerTimeNow()))
			line(("Ready in about %d seconds."):format(seconds))
			line("👉 Please wait at the window.", COLORS.info)
			return
		elseif myQueue and myQueue.reviewBy then
			-- A staff member is reviewing the application.
			jobTitle.Text = "📝 Application review"
			line(("%s is reviewing your application."):format(myQueue.reviewBy))
			line("👉 Please wait at the window.", COLORS.info)
			return
		elseif myQueue then
			-- Waiting for a Job Center window.
			jobTitle.Text = ("🎫 Your number: #%d"):format(myQueue.ticket)
			line(if myQueue.ahead == 0 then "You are next!" else ("%d ahead of you"):format(myQueue.ahead))
			line("👉 Please wait on the benches. We will call you.", COLORS.info)
			return
		end

		if myOrder then
			-- Customer with a bread order.
			jobTitle.Text = "🧾 Your order"
			line(itemsText(myOrder.items))
			line(("Baker: %s  •  Paid %d coins"):format(myOrder.bakerName, myOrder.price), COLORS.muted, 16)
			line("👉 Wait here. Your bread goes to your 🎒 Bag.", COLORS.info)
			timerBack.Visible = true
			timerLabel.Visible = true
			return
		end

		-- Not hired for any job yet: show where to apply.
		local hiredAny = false
		local byPlace = { mall = {}, townhall = {} }
		for _, jobId in Config.JobOrder do
			local info = Config.Jobs[jobId]
			if player:GetAttribute("Hired_" .. jobId) == true then
				hiredAny = true
			end
			if not info.comingSoon and byPlace[info.applyAt] then
				table.insert(byPlace[info.applyAt], info.icon .. " " .. info.name)
			end
		end
		if hiredAny then
			job.Visible = false -- nothing to follow right now
			return
		end
		jobTitle.Text = "💼 Get a job"
		line("1. Buy the job's uniform (Mall 2nd floor).", nil, 16)
		line("2. Apply at its Job Center:", nil, 16)
		line("Mall: " .. table.concat(byPlace.mall, ", "), COLORS.muted, 15)
		line("Town Hall: " .. table.concat(byPlace.townhall, ", "), COLORS.muted, 15)
		return
	end

	-- Baker on shift.
	jobTitle.Text = "Bakery: on shift"
	ovenLabel.Visible = true
	local orders = state.orders or {}
	local first = orders[1]
	timerBack.Visible = first ~= nil
	timerLabel.Visible = first ~= nil

	if not first then
		line("No orders yet.", COLORS.muted)
	else
		line(("Order for %s:"):format(first.customerName))
		for _, item in Config.Bakery.items do
			local needed = first.items[item.id]
			if needed then
				local have = math.min(state.case[item.id] or 0, needed)
				local done = have >= needed
				line(("%s %s %s  %d/%d"):format(if done then "✅" else "⬜", item.icon, item.name, have, needed), if done then COLORS.good else nil)
			end
		end
		if #orders > 1 then
			line(("+ %d more order(s) waiting"):format(#orders - 1), COLORS.muted, 16)
		end
	end

	line(("Racks %d/%d  •  Hands %d/%d  •  Case %d/%d"):format(
		total(state.rack), state.rackLimit,
		total(state.carrying), state.carryLimit,
		total(state.case), state.caseLimit
	), COLORS.muted, 15)
	line("👉 " .. nextStep(), COLORS.info)
end

------------------------------------------------------------------------
-- Prompts: show each one only to the right role.
------------------------------------------------------------------------
-- Roles: "any", "customer" (not on a baker shift), or a job id ("baker",
-- "staff", "cleanup") = only while on that job's shift. The server tags every
-- such prompt "RolePrompt" and sets the player's "OnShift" attribute.
local function promptAllowed(prompt)
	local role = prompt:GetAttribute("Role")
	local onShift = player:GetAttribute("OnShift") or ""
	if role == nil or role == "any" then
		return true
	elseif role == "customer" then
		return onShift ~= "baker"
	end
	return onShift == role
end

local function applyPromptRoles()
	for _, prompt in CollectionService:GetTagged("RolePrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = promptAllowed(prompt)
		end
	end
end

CollectionService:GetInstanceAddedSignal("RolePrompt"):Connect(function(prompt)
	if prompt:IsA("ProximityPrompt") then
		prompt.Enabled = promptAllowed(prompt)
	end
end)
player:GetAttributeChangedSignal("OnShift"):Connect(function()
	applyPromptRoles()
	renderPanel()
end)
applyPromptRoles()

------------------------------------------------------------------------
-- Every frame: clock and sun, timers, oven countdown.
------------------------------------------------------------------------
local closeText = GameClock.format(Config.Clock.closeHour)
local wasOpen = nil

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()

	-- The game clock and the sun.
	local hour = GameClock.hour(t)
	Lighting.ClockTime = hour
	local open = GameClock.isOpen(t)
	local timeText = GameClock.format(hour)
	if open then
		local minutesLeft = GameClock.secondsUntilClose(t) / GameClock.realSecondsPerWorkMinute
		if minutesLeft <= Config.Clock.warningGameMinutes then
			clockLabel.Text = ("🕐 %s  •  Closing soon!"):format(timeText)
			clockLabel.TextColor3 = COLORS.rank
		else
			clockLabel.Text = ("🕐 %s  •  Day %d  •  Open until %s"):format(timeText, GameClock.day(t), closeText)
			clockLabel.TextColor3 = COLORS.text
		end
	else
		clockLabel.Text = ("🌙 %s  •  Closed, opens in %s"):format(timeText, Ui.minutes(GameClock.secondsUntilOpen(t)))
		clockLabel.TextColor3 = COLORS.bad
	end
	if open ~= wasOpen then
		wasOpen = open
		renderPanel() -- switch the "closed" / "go to work" lines
	end

	-- The order timer: the baker's oldest order, or the customer's own order.
	local order = if state.onShift then (state.orders and state.orders[1]) else myOrder
	if order then
		local left = math.max(0, order.expiresAt - t)
		timerFill.Size = UDim2.fromScale(left / (order.expiresAt - order.createdAt), 1)
		timerFill.BackgroundColor3 = if left < 30 then COLORS.bad else COLORS.info
		timerLabel.Text = ("Time left: %s"):format(Ui.minutes(left))
	end

	if state.onShift then
		local baking = state.baking
		local waiting = if state.queued > 0 then (" (+%d waiting)"):format(state.queued) else ""
		if baking then
			local item = Ui.itemsById[baking.id]
			ovenLabel.Text = ("Oven: %s %s %.1fs%s"):format(item.icon, item.name, math.max(0, baking.endsAt - t), waiting)
			ovenLabel.TextColor3 = COLORS.rank
		else
			ovenLabel.Text = "Oven: empty."
			ovenLabel.TextColor3 = COLORS.muted
		end
	end
end)

------------------------------------------------------------------------
-- Bottom center: short pop-up messages from the server.
------------------------------------------------------------------------
local toasts = create("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(480, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = Ui.screen,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local toastCount = 0
-- The sound for each kind of message (the empty ones fall back to "pop").
local TOAST_SOUNDS = {
	good = { "good", 1.15 },
	bad = { "bad", 0.75 },
	rank = { "fanfare", 1.4 },
	info = { "pop", 1 },
}

local function toast(message, kind, soundName)
	toastCount += 1
	local big = kind == "rank"
	if soundName then
		Ui.playSound(soundName, 1, 0.6, "pop")
	else
		local s = TOAST_SOUNDS[kind] or TOAST_SOUNDS.info
		Ui.playSound(s[1], s[2], 0.4, "pop")
	end
	local label = text({
		LayoutOrder = toastCount,
		Text = message,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		TextSize = if big then 22 else 19,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		BackgroundColor3 = COLORS[kind] or COLORS.info,
		Parent = toasts,
	}, {
		Ui.corner(UDim.new(0, 10)),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})

	task.delay(if big then 4.5 else 3, function()
		local fade = Ui.tween(label, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
		fade.Completed:Wait()
		label:Destroy()
	end)
end

------------------------------------------------------------------------
-- Wire up events.
------------------------------------------------------------------------
for _, name in { "Coins", "XP", "Rank", "SaveOff", "Energy" } do
	player:GetAttributeChangedSignal(name):Connect(updateStats)
end
for jobId in Config.Jobs do
	player:GetAttributeChangedSignal("Hired_" .. jobId):Connect(renderPanel)
end

Remotes:WaitForChild("JobState").OnClientEvent:Connect(function(newState)
	state = newState
	applyPromptRoles()
	renderPanel()
end)
Remotes:WaitForChild("CustomerState").OnClientEvent:Connect(function(order)
	myOrder = order
	renderPanel()
end)
Remotes:WaitForChild("QueueState").OnClientEvent:Connect(function(queueInfo)
	myQueue = queueInfo
	renderPanel()
end)
Remotes:WaitForChild("WorkState").OnClientEvent:Connect(function(info)
	workState = info
	renderPanel()
end)
Ui.onBagChanged(function()
	bagCount = total(Ui.bag)
	updateBagButton()
end)
bagCount = total(Ui.bag)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(toast)

-- Sleeping: the screen fades to black and back.
local fade = create("Frame", {
	Name = "SleepFade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 50,
	Visible = false,
	Parent = Ui.screen,
})
Remotes:WaitForChild("ScreenFade").OnClientEvent:Connect(function()
	fade.Visible = true
	fade.BackgroundTransparency = 1
	Ui.tween(fade, 0.8, { BackgroundTransparency = 0 })
	task.delay(1.6, function()
		Ui.tween(fade, 1, { BackgroundTransparency = 1 }).Completed:Wait()
		fade.Visible = false
	end)
end)

updateStats()
updateBagButton()
renderPanel()
