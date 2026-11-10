-- Shared look and helpers for every screen in the game.
-- All client scripts use the same ScreenGui (Ui.screen), colors and helpers,
-- so the game looks like one piece. (A ModuleScript runs once per player, so
-- every script that requires it gets the same table.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ui = {}

-- Plays a sound from Config.Sounds on this player's screen.
-- If that sound is empty, plays `fallback` instead (if given). pitch changes the tone.
function Ui.playSound(name, pitch, volume, fallback)
	local id = Config.Sounds[name]
	if (not id or id == "") and fallback then
		id = Config.Sounds[fallback]
	end
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

Ui.FONT = Enum.Font.FredokaOne
Ui.WHITE = Color3.new(1, 1, 1)
Ui.COLORS = {
	panel = Color3.fromRGB(255, 248, 235),
	text = Color3.fromRGB(60, 45, 30),
	muted = Color3.fromRGB(140, 120, 100),
	good = Color3.fromRGB(60, 170, 90),
	bad = Color3.fromRGB(210, 70, 60),
	info = Color3.fromRGB(70, 120, 200),
	rank = Color3.fromRGB(230, 150, 20),
	energy = Color3.fromRGB(240, 190, 40),
	barBack = Color3.fromRGB(225, 215, 195),
	outline = Color3.fromRGB(190, 130, 70),
	header = Color3.fromRGB(245, 150, 60),
	card = Color3.fromRGB(255, 252, 245),
	cardStroke = Color3.fromRGB(230, 205, 165),
	needed = Color3.fromRGB(222, 246, 215),
	locked = Color3.fromRGB(228, 223, 214),
	lockedStroke = Color3.fromRGB(200, 194, 184),
	pill = Color3.fromRGB(250, 228, 190),
}

Ui.itemsById = {}
for _, item in Config.Bakery.items do
	Ui.itemsById[item.id] = item
end

-- Make an instance, set its properties, add children, then parent it.
function Ui.create(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end
local create = Ui.create

function Ui.corner(radius)
	return create("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

function Ui.round()
	return Ui.corner(UDim.new(1, 0))
end

function Ui.text(props, children)
	local all = {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextColor3 = Ui.COLORS.text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		all[key] = value
	end
	return create("TextLabel", all, children)
end

function Ui.button(props, children)
	local all = {
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Ui.WHITE,
		BackgroundColor3 = Ui.COLORS.header,
		Size = UDim2.new(1, 0, 0, 34),
	}
	for key, value in props do
		all[key] = value
	end
	local scale = create("UIScale", {})
	local list = { Ui.corner(UDim.new(0, 10)), scale }
	for _, child in children or {} do
		table.insert(list, child)
	end
	local button = create("TextButton", all, list)
	-- A small grow on hover, a bounce and a click sound when pressed.
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.1, { Scale = 1.03 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.1, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.94
		Ui.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		Ui.playSound("click", 1.1, 0.35)
	end)
	return button
end

-- A cream panel that grows to fit its content, with a vertical list layout.
function Ui.panel(props, width)
	props.BackgroundColor3 = Ui.COLORS.panel
	props.Size = UDim2.fromOffset(width or 270, 0)
	props.AutomaticSize = Enum.AutomaticSize.Y
	return create("Frame", props, {
		Ui.corner(),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

-- A progress bar. Returns the back frame and the fill frame.
function Ui.bar(layoutOrder, parent, color)
	local back = create("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Ui.COLORS.barBack,
		Parent = parent,
	}, { Ui.round() })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Ui.COLORS.good,
		Parent = back,
	}, { Ui.round() })
	return back, fill
end

function Ui.tween(instance, seconds, goal, style, direction)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

function Ui.total(counts)
	local sum = 0
	for _, n in counts or {} do
		sum += n
	end
	return sum
end

-- 125 seconds → "2:05"
function Ui.minutes(seconds)
	local s = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
Ui.screen = create("ScreenGui", { Name = "BayanUi", ResetOnSpawn = false, Parent = playerGui })

-- The left edge, top to bottom: the clock (Hud, LayoutOrder 0), the stats
-- panel (Hud, 1), and a tool row (2) with ❓ Help (Tutorial) and 📢 Announce
-- (Announcements). Scripts parent their pieces here; LayoutOrder sets the order.
Ui.leftColumn = create("Frame", {
	Name = "LeftColumn",
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
	Parent = Ui.screen,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
Ui.toolRow = create("Frame", {
	Name = "ToolRow",
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 28),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = Ui.leftColumn,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

-- Data the server sends when you join (and when it changes) is kept here, so
-- every script sees it. Roblox gives a message sent before anyone listens to
-- only one listener, so this module is the only one that listens.
--   Ui.bag      = { [itemId] = count }
--   Ui.dtr      = DTR entries, newest first
--   Ui.employee = { employment = { [jobId] = { hiredDay, shift } }, workStats = { [jobId] = { shifts, orders, earned } } }
Ui.bag = {}
Ui.dtr = {}
Ui.employee = { employment = {}, workStats = {} }
--   Ui.pay = { payroll = { pending, periodStart, shifts, hours, late, undertime }, payslips, contributions, nextPayday }
Ui.pay = { payroll = { pending = 0, periodStart = 0, shifts = 0, hours = 0, late = 0, undertime = 0 }, payslips = {}, contributions = {}, nextPayday = 0 }
local changed = {}

local function keep(remoteName, key)
	changed[key] = Instance.new("BindableEvent")
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(remoteName).OnClientEvent:Connect(function(value)
		Ui[key] = value
		changed[key]:Fire()
	end)
end
keep("BagData", "bag")
keep("DtrData", "dtr")
keep("EmployeeData", "employee")
keep("PayData", "pay")
Ui.fridge = {}
keep("FridgeData", "fridge") -- bread in your house fridge: { [itemId] = count }

-- Runs callback when Ui.bag / Ui.dtr / Ui.employee / Ui.pay changes. key = "bag", "dtr", "employee" or "pay".
function Ui.onChanged(key, callback)
	return changed[key].Event:Connect(callback)
end

function Ui.onBagChanged(callback)
	return Ui.onChanged("bag", callback)
end

------------------------------------------------------------------------
-- Windows: big centered panels (oven menu, order menu, bag, DTR).
-- Only one is open at a time.
------------------------------------------------------------------------
local windows = {} -- [name] = { frame, onOpen }

-- Makes a window with an orange header and a close (X) button.
-- Returns the window frame.
function Ui.window(name, title, width)
	local window = Ui.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Visible = false,
		Parent = Ui.screen,
	}, width)
	create("UIStroke", { Color = Ui.COLORS.outline, Thickness = 3, Parent = window })
	create("UIScale", { Parent = window })

	local header = create("Frame", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Ui.COLORS.header,
		Parent = window,
	}, { Ui.corner() })
	Ui.text({
		Name = "Title",
		Text = title,
		TextSize = 24,
		TextColor3 = Ui.WHITE,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Parent = header,
	})
	local close = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		Text = "X",
		Font = Ui.FONT,
		TextSize = 20,
		TextColor3 = Ui.COLORS.header,
		BackgroundColor3 = Ui.WHITE,
		Parent = header,
	}, { Ui.round() })
	close.Activated:Connect(function()
		Ui.playSound("click", 0.9, 0.35)
		Ui.close(name)
	end)

	windows[name] = { frame = window }
	return window
end

-- Opens a window with a small pop, and closes the others.
function Ui.open(name)
	local entry = windows[name]
	if not entry then
		return
	end
	for otherName, other in windows do
		if otherName ~= name then
			other.frame.Visible = false
		end
	end
	if entry.onOpen then
		entry.onOpen()
	end
	if entry.closing then
		-- It was shrinking closed: cancel that and grow back.
		entry.closing = nil
		Ui.tween(entry.frame:FindFirstChildOfClass("UIScale"), 0.15, { Scale = 1 })
	end
	if not entry.frame.Visible then
		entry.frame.Visible = true
		local scale = entry.frame:FindFirstChildOfClass("UIScale")
		scale.Scale = 0.8
		Ui.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Closes a window with a quick shrink.
function Ui.close(name)
	local entry = windows[name]
	if not entry or not entry.frame.Visible then
		return
	end
	local token = {}
	entry.closing = token
	local scale = entry.frame:FindFirstChildOfClass("UIScale")
	Ui.tween(scale, 0.1, { Scale = 0.85 })
	task.delay(0.1, function()
		if entry.closing == token then -- not reopened meanwhile
			entry.closing = nil
			entry.frame.Visible = false
		end
	end)
end

function Ui.isOpen(name)
	local entry = windows[name]
	return entry ~= nil and entry.frame.Visible
end

function Ui.toggle(name)
	if Ui.isOpen(name) then
		Ui.close(name)
	else
		Ui.open(name)
	end
end

-- Runs `callback` every time the window opens (to refresh its content).
function Ui.onOpen(name, callback)
	local entry = windows[name]
	if entry then
		entry.onOpen = callback
	end
end

return Ui
