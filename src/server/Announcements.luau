-- Admin announcements: an admin types "/announce your message" in chat (or uses
-- the 📢 button), and every player sees it as a banner at the top of the screen.
-- The client sends the text (Announce remote); the server checks the admin,
-- runs Roblox's text filter (required for text other players see), and sends
-- it to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Admin = require(ReplicatedStorage.Shared.Admin)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Announce = Remotes:WaitForChild("Announce")
local Notify = Remotes:WaitForChild("Notify")

local MAX_LENGTH = 150 -- characters
local COOLDOWN = 5 -- seconds between announcements

local Announcements = {}

local lastSent = {} -- [Player] = os.clock()

local function onAnnounce(player, text)
	if type(text) ~= "string" then
		return
	end
	if not Admin.isAdmin(player) then
		Notify:FireClient(player, "Only the admin can make announcements.", "bad")
		return
	end
	text = text:match("^%s*(.-)%s*$") or ""
	if text == "" or not utf8.len(text) then
		Notify:FireClient(player, "Type /announce and then your message.", "info")
		return
	end
	local cut = utf8.offset(text, MAX_LENGTH + 1)
	if cut then
		text = text:sub(1, cut - 1)
	end
	if os.clock() - (lastSent[player] or 0) < COOLDOWN then
		Notify:FireClient(player, "Wait a few seconds before the next announcement.", "info")
		return
	end
	lastSent[player] = os.clock()

	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(filtered) ~= "string" then
		Notify:FireClient(player, "The announcement could not be sent. Try again.", "bad")
		return
	end
	Announce:FireAllClients(player.DisplayName, filtered)
end

function Announcements.start()
	Announce.OnServerEvent:Connect(onAnnounce)
	-- Lets the client show the 📢 button to admins only (the server still checks)
	local function mark(player)
		player:SetAttribute("IsAdmin", Admin.isAdmin(player))
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
end

return Announcements
