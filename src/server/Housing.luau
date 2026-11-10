-- Renting a house in Bayan Heights (premium) or Bayan Heights II (starter row houses).
--   Each subdivision's Leasing Office rents only its own houses, at its own rent
--   (Config.Housing.areas): rent a house (must be hired for a job; one period's
--   rent upfront) or end the rent. One house at a time. Rent then comes out of
--   the payslip on payday (PlayerData.runPayday).
--   Your house takes a free house each time you join (like tycoon plots), with
--   your name on the sign. The front door takes you to its private interior.
--   Inside: sleep (full energy once per game day), the fridge, and an
--   "Open house" switch so friends can come in.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admin = require(ReplicatedStorage.Shared.Admin)
local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)
local HouseInterior = require(script.Parent.HouseInterior)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local OpenFridge = Remotes:WaitForChild("OpenFridge")
local FridgeAction = Remotes:WaitForChild("FridgeAction")
local ScreenFade = Remotes:WaitForChild("ScreenFade")

local settings = Config.Housing

local Housing = {}

-- [n] = { doorSpot, signText, outside (CFrame), address,
--         occupant = Player or nil, open = boolean, interior = table or nil }
local lots = {}
local waiting = {} -- renters with no free house yet
local lastKnock = {} -- [Player] = os.clock() of their last knock

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

local function addPrompt(part, actionText, objectText, holdSeconds, onTriggered)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdSeconds
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Role", "any")
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	CollectionService:AddTag(prompt, "RolePrompt")
	return prompt
end

-- Where each house's interior is built: far away from the city, one spot per house.
local function interiorOrigin(n)
	return CFrame.new(3000 + ((n - 1) % 10) * 70, 0, 3000 + math.floor((n - 1) / 10) * 70)
end

-- Moves a player, loading the area around the spot first so they don't fall.
local function teleport(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position)
	end)
	character:PivotTo(cframe)
end

local function lotOf(player)
	for n, lot in lots do
		if lot.occupant == player then
			return n, lot
		end
	end
	return nil, nil
end

local function playersInside(n)
	local list = {}
	local center = interiorOrigin(n).Position
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - center).Magnitude < 30 then
			table.insert(list, player)
		end
	end
	return list
end

local function destroyInterior(n)
	local lot = lots[n]
	if not lot.interior then
		return
	end
	for _, player in playersInside(n) do
		teleport(player, lot.outside)
		notify(player, "You left the house.", "info")
	end
	lot.interior.model:Destroy()
	lot.interior = nil
end

-- Inside the house: sleep, fridge, open house switch, exit.
local function ensureInterior(n)
	local lot = lots[n]
	if lot.interior then
		return lot.interior
	end
	local interior = HouseInterior.build(interiorOrigin(n), lot.occupant.DisplayName)
	lot.interior = interior

	addPrompt(interior.exitDoor, "Go Outside", lot.address, 0, function(player)
		teleport(player, lot.outside)
	end)

	addPrompt(interior.bed, "Sleep", "Bed", 1.5, function(player)
		if player ~= lot.occupant then
			notify(player, "This isn't your bed.", "bad")
			return
		end
		if PlayerData.sleep(player, GameClock.day(workspace:GetServerTimeNow())) then
			ScreenFade:FireClient(player)
			notify(player, "You slept well. Energy is full! 😴", "good")
		else
			notify(player, "You already slept today. You can sleep again after 6:00 AM.", "info")
		end
	end)

	addPrompt(interior.fridge, "Open Fridge", "Fridge", 0, function(player)
		if player ~= lot.occupant then
			notify(player, "Only the owner can use this fridge.", "bad")
			return
		end
		OpenFridge:FireClient(player)
	end)

	local switchPrompt
	switchPrompt = addPrompt(interior.openSwitch, "Open House: OFF", "Visitors", 0, function(player)
		if player ~= lot.occupant then
			return
		end
		lot.open = not lot.open
		switchPrompt.ActionText = if lot.open then "Open House: ON" else "Open House: OFF"
		notify(player, if lot.open then "Open house! Anyone can come in now." else "Your door is locked again.", "info")
	end)
	return interior
end

local function setLot(n, occupant)
	local lot = lots[n]
	if not occupant then
		destroyInterior(n)
	end
	lot.occupant = occupant
	lot.open = false
	if occupant then
		lot.signText.Text = ("🏠 %s's House"):format(occupant.DisplayName)
		occupant:SetAttribute("HomeAddress", lot.address)
	else
		lot.signText.Text = "FOR RENT"
	end
end

-- The subdivision (Config.Housing.areas key) a renter's house is in.
local function rentAreaOf(player)
	local data = PlayerData.get(player)
	local key = data and data.rentArea
	if not key or not settings.areas[key] then
		return "heights" -- old saves, or an area removed from Config
	end
	return key
end

-- Gives a renter a free house in their subdivision (or puts them on the waiting list).
local function placeRenter(player)
	if lotOf(player) then
		return
	end
	local areaKey = rentAreaOf(player)
	local areaName = Config.housingArea(areaKey).name
	for n, lot in lots do
		if not lot.occupant and lot.area == areaKey then
			setLot(n, player)
			notify(player, ("Your house is %s, %s. 🏠"):format(lot.address, areaName), "good")
			return
		end
	end
	if not table.find(waiting, player) then
		table.insert(waiting, player)
	end
	notify(player, ("All houses in %s are taken on this server. Yours will appear when one is free."):format(areaName), "info")
end

local function freeHouse(player)
	local i = table.find(waiting, player)
	if i then
		table.remove(waiting, i)
	end
	local n = lotOf(player)
	if not n then
		return
	end
	local freedArea = lots[n].area
	setLot(n, nil)
	player:SetAttribute("HomeAddress", nil)
	-- The first waiting renter from the same subdivision gets the house
	for w, nextRenter in waiting do
		if nextRenter.Parent and rentAreaOf(nextRenter) == freedArea then
			table.remove(waiting, w)
			placeRenter(nextRenter)
			break
		end
	end
end

local function onDoor(n, player)
	local lot = lots[n]
	if not lot.occupant then
		notify(player, ("%s is for rent. Visit the %s Leasing Office by the gate."):format(lot.address, Config.housingArea(lot.area).name), "info")
		return
	end
	if lot.occupant == player or lot.open then
		local interior = ensureInterior(n)
		teleport(player, interior.spawn)
		if lot.occupant ~= player then
			notify(lot.occupant, ("%s came into your house. 👋"):format(player.DisplayName), "info")
		end
		return
	end
	notify(player, ("This is %s's house. The door is locked."):format(lot.occupant.DisplayName), "info")
	if os.clock() - (lastKnock[player] or 0) > 10 then
		lastKnock[player] = os.clock()
		notify(lot.occupant, ("%s knocked on your door. Turn on Open House inside to let them in."):format(player.DisplayName), "info")
	end
end

------------------------------------------------------------------------
-- The Admin Mansion (Veterans Parc): free and permanent for the admin.
-- Only an admin can go in, unless the admin turns on Open House.
------------------------------------------------------------------------

local MANSION_ORIGIN = CFrame.new(2700, 0, 2700)
local MANSION_SIGN = "🏰 THE ADMIN'S RESIDENCE"
local mansion = nil -- { doorSpot, signTexts, outside, address, owner, open, interior }

local function playersInMansion()
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - MANSION_ORIGIN.Position).Magnitude < 40 then
			table.insert(list, player)
		end
	end
	return list
end

local function setMansionSign(text)
	for _, signText in mansion.signTexts do
		signText.Text = text
	end
end

local function closeMansion()
	if not mansion.interior then
		return
	end
	for _, player in playersInMansion() do
		teleport(player, mansion.outside)
		notify(player, "You left the Admin's Residence.", "info")
	end
	mansion.interior.model:Destroy()
	mansion.interior = nil
end

local function setMansionOwner(player)
	if mansion.owner == player then
		return
	end
	closeMansion()
	mansion.owner = player
	mansion.open = false
	setMansionSign(if player then ("🏰 %s's Residence"):format(player.DisplayName) else MANSION_SIGN)
end

local function ensureMansion()
	if mansion.interior then
		return mansion.interior
	end
	local interior = HouseInterior.build(MANSION_ORIGIN, mansion.owner.DisplayName, true)
	mansion.interior = interior

	addPrompt(interior.exitDoor, "Go Outside", mansion.address, 0, function(player)
		teleport(player, mansion.outside)
	end)

	addPrompt(interior.bed, "Sleep", "Master Bed", 1.5, function(player)
		if not Admin.isAdmin(player) then
			notify(player, "This is the admin's bed.", "bad")
			return
		end
		if PlayerData.sleep(player, GameClock.day(workspace:GetServerTimeNow())) then
			ScreenFade:FireClient(player)
			notify(player, "You slept well. Energy is full! 😴", "good")
		else
			notify(player, "You already slept today. You can sleep again after 6:00 AM.", "info")
		end
	end)

	addPrompt(interior.fridge, "Open Fridge", "Fridge", 0, function(player)
		if not Admin.isAdmin(player) then
			notify(player, "Only the admin can use this fridge.", "bad")
			return
		end
		OpenFridge:FireClient(player)
	end)

	local switchPrompt
	switchPrompt = addPrompt(interior.openSwitch, "Open House: OFF", "Visitors", 0, function(player)
		if not Admin.isAdmin(player) then
			return
		end
		mansion.open = not mansion.open
		switchPrompt.ActionText = if mansion.open then "Open House: ON" else "Open House: OFF"
		notify(player, if mansion.open then "Open house! Anyone can visit the Residence now." else "The Residence is private again.", "info")
	end)
	return interior
end

local function onMansionDoor(player)
	if Admin.isAdmin(player) then
		if not mansion.owner then
			setMansionOwner(player)
		end
		teleport(player, ensureMansion().spawn)
		return
	end
	if mansion.owner and mansion.open then
		teleport(player, ensureMansion().spawn)
		notify(mansion.owner, ("%s came into the Residence. 👋"):format(player.DisplayName), "info")
		return
	end
	if not mansion.owner then
		notify(player, "The admin is not in town. The Residence is closed.", "info")
		return
	end
	notify(player, "This is the Admin's Residence. The door is locked.", "info")
	if os.clock() - (lastKnock[player] or 0) > 10 then
		lastKnock[player] = os.clock()
		notify(mansion.owner, ("%s knocked on the Residence door. Turn on Open House inside to let them in."):format(player.DisplayName), "info")
	end
end

-- When the admin leaves, another admin on the server takes the house (or it closes).
local function onAdminLeaving(player)
	if not mansion or mansion.owner ~= player then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and Admin.isAdmin(other) then
			setMansionOwner(other)
			return
		end
	end
	setMansionOwner(nil)
end

------------------------------------------------------------------------
-- Spawning at home: players with a home appear at its front door when they
-- spawn (the admin at the mansion, renters at their house). No home = the plaza.
------------------------------------------------------------------------

local function homeSpot(player)
	if mansion and mansion.owner == player then
		return mansion.outside
	end
	local _, lot = lotOf(player)
	return lot and lot.outside
end

local function spawnAtHome(player, character)
	-- On the first spawn, wait for their data so their house is placed first
	local waited = 0
	while player.Parent and not player:GetAttribute("DataLoaded") and waited < 15 do
		waited += task.wait(0.5)
	end
	task.wait(0.3)
	if player.Character ~= character or not character:WaitForChild("HumanoidRootPart", 5) then
		return
	end
	local spot = homeSpot(player)
	if spot then
		teleport(player, spot)
	end
end

------------------------------------------------------------------------
-- Leasing Office
------------------------------------------------------------------------

local function rent(player, areaKey)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local area = Config.housingArea(areaKey)
	if data.renting then
		local current = rentAreaOf(player)
		local _, lot = lotOf(player)
		if current ~= areaKey then
			notify(player, ("You already rent in %s. End your rent first (at any Leasing Office) to move here."):format(Config.housingArea(current).name), "info")
		else
			notify(player, if lot then ("You already rent %s, %s."):format(lot.address, area.name) else "You already rent a house here.", "info")
		end
		return
	end
	local hired = false
	for _, isHired in data.passed do
		hired = hired or isHired
	end
	if not hired then
		notify(player, "You need a job first (proof of income). Apply at a Job Center.", "bad")
		return
	end
	if not PlayerData.spendCoins(player, area.rent) then
		notify(player, ("You need %d coins to pay the first rent."):format(area.rent), "bad")
		return
	end
	PlayerData.startRent(player, areaKey)
	placeRenter(player)
	notify(player, ("Welcome to %s! Rent is %d coins per pay period, taken from your payslip on payday."):format(area.name, area.rent), "rank")
end

-- Moving out works at any Leasing Office.
local function endRent(player)
	local data = PlayerData.get(player)
	if not data or not data.renting then
		notify(player, "You don't rent a house.", "info")
		return
	end
	local areaName = Config.housingArea(rentAreaOf(player)).name
	freeHouse(player)
	PlayerData.endRent(player)
	notify(player, ("You moved out. Thank you for staying in %s!"):format(areaName), "info")
end

local function onFridgeAction(player, itemId, intoFridge)
	if type(itemId) ~= "string" or type(intoFridge) ~= "boolean" then
		return
	end
	-- The player must stand by their own fridge (rented house or the mansion).
	local fridges = {}
	local _, lot = lotOf(player)
	if lot and lot.interior then
		table.insert(fridges, lot.interior.fridge)
	end
	if mansion and mansion.interior and Admin.isAdmin(player) then
		table.insert(fridges, mansion.interior.fridge)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = false
	for _, fridge in fridges do
		near = near or (root ~= nil and (root.Position - fridge.Position).Magnitude <= 14)
	end
	if not near then
		return
	end
	if not PlayerData.moveFridge(player, itemId, intoFridge) and intoFridge then
		notify(player, ("The fridge is full (%d bread)."):format(settings.fridgeSize), "bad")
	end
end

-- stations = { houses = { { doorSpot, signText, outside, address, area }, ... },
--             leasing = { { area, rentSpot, endRentSpot }, ... },
--             adminHouse = { doorSpot, signTexts, outside, address } }
function Housing.start(stations)
	if stations.adminHouse then
		local house = stations.adminHouse
		mansion = {
			doorSpot = house.doorSpot,
			signTexts = house.signTexts,
			outside = house.outside,
			address = house.address,
			owner = nil,
			open = false,
			interior = nil,
		}
		setMansionSign(MANSION_SIGN)
		addPrompt(house.doorSpot, "Enter Residence", "Admin's Residence", 0, onMansionDoor)
	end

	for n, house in stations.houses do
		lots[n] = {
			doorSpot = house.doorSpot,
			signText = house.signText,
			outside = house.outside,
			address = house.address,
			area = house.area or "heights",
			occupant = nil,
			open = false,
			interior = nil,
		}
		setLot(n, nil)
		addPrompt(house.doorSpot, "Enter House", house.address, 0, function(player)
			onDoor(n, player)
		end)
	end
	for _, office in stations.leasing do
		local area = Config.housingArea(office.area)
		local officeName = "Leasing Office • " .. area.name
		addPrompt(office.rentSpot, ("Rent a House (%d/period)"):format(area.rent), officeName, 1, function(player)
			rent(player, office.area)
		end)
		addPrompt(office.endRentSpot, "End Rent (move out)", officeName, 2, endRent)
	end
	FridgeAction.OnServerEvent:Connect(onFridgeAction)

	-- Renters get their house when their data has loaded; the admin gets the mansion.
	local function watch(player)
		local function check()
			if not player:GetAttribute("DataLoaded") then
				return
			end
			if player:GetAttribute("Renting") then
				placeRenter(player)
			end
			if mansion and not mansion.owner and Admin.isAdmin(player) then
				setMansionOwner(player)
				notify(player, "Welcome back, admin! Your Residence is in Veterans Parc. 🏰", "rank")
			end
		end
		player:GetAttributeChangedSignal("DataLoaded"):Connect(check)
		check()
		-- Every spawn (joining, resetting, falling) starts at home, if they have one
		player.CharacterAdded:Connect(function(character)
			spawnAtHome(player, character)
		end)
		if player.Character then
			task.spawn(spawnAtHome, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		freeHouse(player)
		onAdminLeaving(player)
		lastKnock[player] = nil
	end)
	PlayerData.onEvicted(freeHouse)
end

return Housing
