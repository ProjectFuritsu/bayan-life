-- Owning a business (stage 1).
--   Barangay Clearance kiosk (Town Hall) → Business Permit (BPLO window, see
--   JobCenter) → buy the right to a store → your store takes a free lot.
-- Store lots work like tycoon plots: owning a store is saved, and each time an
-- owner joins a server, their store takes a free lot and shows their business
-- name. If every lot is busy, they wait for one to free up.
-- Running the store (stock, prices, selling) is stage 2.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local settings = Config.Business

local Business = {}

-- [n] = { prompt, signTexts = { TextLabel }, shutterText = TextLabel, ownerText = TextLabel, owner = Player or nil }
local lots = {}
local waiting = {} -- store owners with no free lot yet

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

------------------------------------------------------------------------
-- Permit helpers (used by the BPLO window in JobCenter)
------------------------------------------------------------------------

-- What the player has for the permit. Returns nil while data is loading.
function Business.requirements(player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	return {
		rankOk = Progression.getRankIndex(data.xp) >= settings.minRank,
		rankName = Config.Ranks[settings.minRank].name,
		clearance = data.clearance,
		coinsOk = data.coins >= settings.permitFee,
		hasPermit = data.permit.number ~= nil,
	}
end

-- The business name choices for this player.
function Business.nameChoices(player)
	local list = {}
	for i, style in settings.nameStyles do
		list[i] = style:format(player.DisplayName)
	end
	return list
end

-- Charges the fee and saves the permit. Returns ok and a message.
function Business.issuePermit(player, businessName, typeName)
	if not PlayerData.spendCoins(player, settings.permitFee) then
		return false, ("You need %d coins for the permit fee."):format(settings.permitFee)
	end
	local day = GameClock.day(workspace:GetServerTimeNow())
	local number = ("BP-%d-%04d"):format(day, player.UserId % 10000)
	PlayerData.setPermit(player, {
		number = number,
		businessName = businessName,
		businessType = typeName,
		issuedDay = day,
	})
	return true, ('Business Permit %s issued for "%s"! Next: buy a FOR SALE stall at the Bayan Public Market (next to the bakery).'):format(number, businessName)
end

------------------------------------------------------------------------
-- Store lots
------------------------------------------------------------------------

local function setLot(lot, owner)
	lot.owner = owner
	if owner then
		local name = owner:GetAttribute("BusinessName")
		if name == nil or name == "" then
			name = owner.DisplayName .. "'s Store"
		end
		for _, label in lot.signTexts do
			label.Text = name
		end
		lot.shutterText.Text = "OPENING SOON!"
		lot.ownerText.Text = "Owner: " .. owner.DisplayName
	else
		for _, label in lot.signTexts do
			label.Text = "FOR SALE"
		end
		lot.shutterText.Text = "FOR SALE\nBusiness Permit needed"
		lot.ownerText.Text = ("Stall for sale: %d coins"):format(settings.storePrice)
	end
end

local function lotOf(player)
	for n, lot in lots do
		if lot.owner == player then
			return n
		end
	end
	return nil
end

local function freeLot()
	for n, lot in lots do
		if not lot.owner then
			return n
		end
	end
	return nil
end

-- Puts an owner's store on a free lot (or adds them to the waiting list).
local function placeStore(player)
	if lotOf(player) then
		return
	end
	local n = freeLot()
	if not n then
		if not table.find(waiting, player) then
			table.insert(waiting, player)
		end
		notify(player, "All market stalls are busy on this server. Your stall will appear when one is free.", "info")
		return
	end
	setLot(lots[n], player)
	notify(player, ('Your stall "%s" is at Stall %d in the Bayan Public Market.'):format(player:GetAttribute("BusinessName") or "", n), "good")
end

local function removeStore(player)
	local i = table.find(waiting, player)
	if i then
		table.remove(waiting, i)
	end
	local n = lotOf(player)
	if not n then
		return
	end
	setLot(lots[n], nil)
	-- Give the lot to the next owner who is waiting.
	while #waiting > 0 do
		local nextOwner = table.remove(waiting, 1)
		if nextOwner.Parent then
			placeStore(nextOwner)
			break
		end
	end
end

local function onLot(n, player)
	local lot = lots[n]
	if lot.owner == player then
		notify(player, "This is your stall! Running it (stock, prices, selling) comes in the next update.", "info")
		return
	elseif lot.owner then
		notify(player, ("This is %s's stall. Opening soon!"):format(lot.owner.DisplayName), "info")
		return
	end

	local data = PlayerData.get(player)
	if not data then
		return
	end
	if data.ownsStore then
		local mine = lotOf(player)
		notify(player, if mine then ("You already have a stall: Stall %d."):format(mine) else "You already own a market stall.", "info")
		return
	end
	if not data.permit.number then
		notify(player, "You need a Business Permit first. Apply at the Town Hall BPLO window.", "bad")
		return
	end
	if not PlayerData.spendCoins(player, settings.storePrice) then
		notify(player, ("You need %d coins to buy a market stall."):format(settings.storePrice), "bad")
		return
	end
	PlayerData.giveStore(player)
	setLot(lot, player)
	notify(player, ('Congratulations! You own "%s" at Stall %d. Running it comes in the next update.'):format(data.permit.businessName, n), "rank")
end

------------------------------------------------------------------------
-- Barangay Clearance kiosk
------------------------------------------------------------------------

local function onClearance(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if data.clearance then
		notify(player, "You already have a Barangay Clearance.", "info")
		return
	end
	if not PlayerData.spendCoins(player, settings.clearancePrice) then
		notify(player, ("A Barangay Clearance costs %d coins."):format(settings.clearancePrice), "bad")
		return
	end
	PlayerData.giveClearance(player)
	notify(player, "Barangay Clearance issued! Next: apply for a Business Permit at the BPLO window.", "good")
end

------------------------------------------------------------------------

local function addPrompt(part, actionText, objectText, holdSeconds, onTriggered)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Role", "any")
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	CollectionService:AddTag(prompt, "RolePrompt")
end

-- stations = { clearanceKiosk = part, lots = { { prompt, signTexts, shutterText, ownerText }, ... } }
function Business.start(stations)
	addPrompt(stations.clearanceKiosk, ("Get Clearance (%d coins)"):format(settings.clearancePrice), "Barangay Clearance", 1, onClearance)

	for n, lot in stations.lots do
		lots[n] = lot
		setLot(lot, nil)
		addPrompt(lot.prompt, "Buy / Visit Stall", ("Market Stall %d"):format(n), 0.5, function(player)
			onLot(n, player)
		end)
	end

	-- Owners get their store when their data has loaded.
	local function watch(player)
		local function check()
			if player:GetAttribute("DataLoaded") and player:GetAttribute("OwnsStore") then
				placeStore(player)
			end
		end
		player:GetAttributeChangedSignal("DataLoaded"):Connect(check)
		check()
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(removeStore)
end

return Business
