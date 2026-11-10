-- Admin announcements.
--   Admins: type "/announce your message" (or "/ann ...") in chat, or press the
--   📢 Announce button under the coins card (left side). The server checks and filters it.
--   Everyone: the announcement drops in as a banner at the top of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local Announce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Announce")

local MAX_LENGTH = 150
local GOLD = Color3.fromRGB(225, 185, 70)
local HIDDEN = UDim2.new(0.5, 0, 0, -160)
local SHOWN = UDim2.new(0.5, 0, 0, 12) -- top center

------------------------------------------------------------------------
-- The banner everyone sees
------------------------------------------------------------------------

local banner = Ui.create("Frame", {
	Name = "AnnouncementBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = HIDDEN,
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(40, 35, 30),
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = Ui.screen,
}, {
	Ui.corner(),
	Ui.create("UISizeConstraint", { MaxSize = Vector2.new(560, math.huge) }),
	Ui.create("UIStroke", { Color = GOLD, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	Ui.create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}),
	Ui.create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local fromLabel = Ui.text({ LayoutOrder = 1, TextSize = 17, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
local messageLabel = Ui.text({
	LayoutOrder = 2,
	TextSize = 22,
	TextColor3 = Ui.WHITE,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = banner,
})

local showing = nil -- token of the banner on screen (a newer one replaces it)

Announce.OnClientEvent:Connect(function(adminName, text)
	fromLabel.Text = ("📢 Admin %s"):format(adminName)
	messageLabel.Text = text
	banner.Position = HIDDEN
	banner.Visible = true
	Ui.tween(banner, 0.45, { Position = SHOWN }, Enum.EasingStyle.Back)
	Ui.playSound("announce", 1, 0.6, "pop")
	local token = {}
	showing = token
	task.delay(8, function()
		if showing ~= token then
			return
		end
		Ui.tween(banner, 0.3, { Position = HIDDEN }).Completed:Wait()
		if showing == token then
			banner.Visible = false
		end
	end)
end)

------------------------------------------------------------------------
-- Admins: the /announce chat command
------------------------------------------------------------------------

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	local command = Instance.new("TextChatCommand")
	command.Name = "AnnounceCommand"
	command.PrimaryAlias = "/announce"
	command.SecondaryAlias = "/ann"
	command.Parent = TextChatService
	command.Triggered:Connect(function(_, unfilteredText)
		Announce:FireServer(unfilteredText:match("^%s*/%S+%s*(.*)$") or "")
	end)
end

------------------------------------------------------------------------
-- Admins: the 📢 button and a small window to type in
------------------------------------------------------------------------

local window = Ui.window("Announce", "📢 Announcement", 400)
Ui.text({
	LayoutOrder = 1,
	Text = "Everyone on this server will see it at the top of their screen.",
	TextSize = 15,
	TextColor3 = Ui.COLORS.muted,
	TextWrapped = true,
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = window,
})
local box = Ui.create("TextBox", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundColor3 = Ui.COLORS.card,
	Font = Ui.FONT,
	TextSize = 18,
	TextColor3 = Ui.COLORS.text,
	PlaceholderText = "Type your message...",
	Text = "",
	ClearTextOnFocus = false,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = window,
}, {
	Ui.corner(UDim.new(0, 8)),
	Ui.create("UIStroke", { Color = Ui.COLORS.cardStroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	Ui.create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}),
})
local counter = Ui.text({ LayoutOrder = 3, TextSize = 14, TextColor3 = Ui.COLORS.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = ("0 / %d"):format(MAX_LENGTH), Parent = window })
local send = Ui.button({ LayoutOrder = 4, Text = "📢 Send to everyone", BackgroundColor3 = Ui.COLORS.good, Parent = window })

box:GetPropertyChangedSignal("Text"):Connect(function()
	local length = utf8.len(box.Text) or #box.Text
	if length > MAX_LENGTH then
		local cut = utf8.offset(box.Text, MAX_LENGTH + 1)
		if cut then
			box.Text = box.Text:sub(1, cut - 1)
			return
		end
	end
	counter.Text = ("%d / %d"):format(length, MAX_LENGTH)
end)

local function submit()
	if box.Text:match("%S") then
		Announce:FireServer(box.Text)
		box.Text = ""
		Ui.close("Announce")
	end
end
send.Activated:Connect(submit)
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
end)

local adminButton = Ui.button({
	Name = "AnnounceButton",
	LayoutOrder = 3, -- after Help, in the left tool row under the coins card
	Text = "📢 Announce",
	TextSize = 15,
	Size = UDim2.fromOffset(112, 28),
	BackgroundColor3 = Color3.fromRGB(40, 35, 30),
	TextColor3 = GOLD,
	Visible = false,
	Parent = Ui.toolRow,
})
adminButton.Activated:Connect(function()
	Ui.toggle("Announce")
end)
local function refresh()
	adminButton.Visible = player:GetAttribute("IsAdmin") == true
end
player:GetAttributeChangedSignal("IsAdmin"):Connect(refresh)
refresh()
