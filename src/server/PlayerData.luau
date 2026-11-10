-- Loads, keeps and saves each player's progress: coins, XP, energy, bag, DTR.
-- Only the server changes these values. The client only reads them.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Progression = require(ReplicatedStorage.Shared.Progression)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DtrData = Remotes:WaitForChild("DtrData")
local BagData = Remotes:WaitForChild("BagData")
local EmployeeData = Remotes:WaitForChild("EmployeeData")
local PayData = Remotes:WaitForChild("PayData")
local FridgeData = Remotes:WaitForChild("FridgeData")
local Notify = Remotes:WaitForChild("Notify")

-- A fresh copy each time, so players never share the same tables.
-- Brand-new players start with the starter coins.
local function defaultData()
	return {
		coins = Config.Economy.starterCoins,
		xp = 0,
		energy = Config.Energy.start,
		bag = {}, -- bread the player bought: { [itemId] = count }
		restDay = 0, -- the last game day the player got their night rest
		uniforms = {}, -- uniforms the player owns: { [jobId] = true }
		passed = {}, -- jobs the player is hired for (applied and passed): { [jobId] = true }
		employment = {}, -- { [jobId] = { hiredDay, shift } } for the Employee ID
		workStats = {}, -- lifetime work history: { [jobId] = { shifts, orders, earned } }
		-- Payroll: wages since the last payday, payslips, and lifetime contributions
		payroll = { pending = 0, periodStart = 0, shifts = 0, hours = 0, late = 0, undertime = 0 },
		payslips = {}, -- newest first
		contributions = {}, -- { SSS = coins, PhilHealth = coins, ["Pag-IBIG"] = coins }
		lastPayday = 0, -- the last payday (game day) this player was paid for
		tutorialDone = false, -- finished or skipped the welcome tutorial
		renting = false, -- rents a house (it takes a free house in their subdivision when they join)
		rentArea = "heights", -- which subdivision (a key of Config.Housing.areas)
		missedRent = 0, -- missed rents in a row
		fridge = {}, -- bread in the house fridge: { [itemId] = count }
		sleptDay = 0, -- the last game day they slept in their bed
		clearance = false, -- Barangay Clearance
		permit = {}, -- Business Permit: { number, businessName, businessType, issuedDay }, empty = none
		ownsStore = false, -- bought the right to a store (it takes a free lot on each server)
		ownsBakery = false, -- used by the "become the owner" step later
		dtr = {}, -- Daily Time Record, newest shift first
	}
end
local DEFAULT_DATA = defaultData() -- only used to check field names and types

local LOAD_TRIES = 3

local PlayerData = {}

-- [Player] = { data = table, canSave = boolean }
local profiles = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.dataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore not available. Progress will not save:", result)
	end
end

local function keyFor(player)
	return "player_" .. player.UserId
end

-- Returns data, canSave, isNew (true when the player has no saved data yet).
local function loadData(player)
	local data = defaultData()
	if not store then
		return data, false, true
	end

	for try = 1, LOAD_TRIES do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			if type(result) == "table" then
				-- Copy only known fields with the right type.
				for key, value in result do
					if DEFAULT_DATA[key] ~= nil and type(value) == type(DEFAULT_DATA[key]) then
						data[key] = value
					end
				end
			end
			return data, true, result == nil
		end
		warn(("[PlayerData] Load try %d failed for %s: %s"):format(try, player.Name, tostring(result)))
		task.wait(1)
	end

	-- Loading failed. The player gets fresh data, but we never save it,
	-- so we don't overwrite their real progress. (Not "new": they may have saved data.)
	return data, false, false
end

local function saveData(player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	local ok, result = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return profile.data
		end)
	end)
	if not ok then
		warn(("[PlayerData] Save failed for %s: %s"):format(player.Name, tostring(result)))
	end
end

-- Copies the values to attributes (read by the HUD) and leaderstats (the player list).
local function publish(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	local rankName = if data.ownsBakery then "Owner" else Progression.getRank(data.xp).name

	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("Rank", rankName)
	player:SetAttribute("Energy", math.floor(data.energy))
	-- Job requirements, for the HUD checklist: Uniform_baker, Hired_baker, ...
	for jobId in Config.Jobs do
		player:SetAttribute("Uniform_" .. jobId, data.uniforms[jobId] == true)
		player:SetAttribute("Hired_" .. jobId, data.passed[jobId] == true)
	end
	-- Business: for the HUD and the permit form
	player:SetAttribute("HasClearance", data.clearance)
	player:SetAttribute("HasPermit", data.permit.number ~= nil)
	player:SetAttribute("BusinessName", data.permit.businessName or "")
	player:SetAttribute("OwnsStore", data.ownsStore)
	player:SetAttribute("TutorialDone", data.tutorialDone)
	player:SetAttribute("Renting", data.renting)
	player:SetAttribute("RentArea", data.rentArea)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = data.coins
		leaderstats.Rank.Value = rankName
	end
end

local function sendBag(player)
	local profile = profiles[player]
	if profile then
		BagData:FireClient(player, profile.data.bag)
		FridgeData:FireClient(player, profile.data.fridge)
	end
end

-- The next payday (game day) after `day`.
local function nextPayday(day)
	local every = Config.Payroll.paydayEveryDays
	return (math.floor(day / every) + 1) * every
end

-- Payroll for the payslip window: pending pay, payslips, contributions.
local function sendPay(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	PayData:FireClient(player, {
		payroll = data.payroll,
		payslips = data.payslips,
		contributions = data.contributions,
		nextPayday = nextPayday(GameClock.day(workspace:GetServerTimeNow())),
	})
end

-- Hiring record and work history, for the Employee ID card.
local function sendEmployee(player)
	local profile = profiles[player]
	if profile then
		EmployeeData:FireClient(player, {
			employment = profile.data.employment,
			workStats = profile.data.workStats,
			permit = profile.data.permit,
		})
	end
end

-- Night rest: once per game day, energy goes up to at least the rest level.
-- Returns true if the player got rest now.
function PlayerData.applyRest(player, day)
	local profile = profiles[player]
	if not profile or profile.data.restDay == day then
		return false
	end
	profile.data.restDay = day
	local before = profile.data.energy
	profile.data.energy = math.max(before, Config.Energy.restLevel)
	player:SetAttribute("Energy", math.floor(profile.data.energy))
	return profile.data.energy > before
end

local function onPlayerAdded(player)
	local data, canSave, isNew = loadData(player)
	if not player.Parent then
		return -- the player left while we were loading
	end
	profiles[player] = { data = data, canSave = canSave }

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = leaderstats
	leaderstats.Parent = player

	PlayerData.applyRest(player, GameClock.day(workspace:GetServerTimeNow()))
	publish(player)
	DtrData:FireClient(player, data.dtr)
	sendBag(player)
	sendEmployee(player)
	-- Catch up on a payday that passed while the player was away.
	local day = GameClock.day(workspace:GetServerTimeNow())
	local every = Config.Payroll.paydayEveryDays
	local lastPaydayDay = math.floor(day / every) * every
	if lastPaydayDay > data.lastPayday then
		PlayerData.runPayday(player, lastPaydayDay)
	else
		sendPay(player)
	end
	player:SetAttribute("SaveOff", not canSave)
	player:SetAttribute("DataLoaded", true)
	if isNew then
		Notify:FireClient(
			player,
			("Welcome to Bayan Life! Here are %d starter coins. Buy bread at Order Here, or clock in to work."):format(
				Config.Economy.starterCoins
			),
			"rank"
		)
	end
end

-- Functions to run when a player leaves, before their data is saved
-- (for example, to write an unfinished shift to the DTR, or refund an order).
local leavingCallbacks = {}

function PlayerData.onLeaving(callback)
	table.insert(leavingCallbacks, callback)
end

local function onPlayerRemoving(player)
	for _, callback in leavingCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn("[PlayerData] onLeaving callback failed:", err)
		end
	end
	saveData(player)
	profiles[player] = nil
end

-- Returns the player's data table, or nil while it is still loading.
function PlayerData.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerData.addCoins(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.coins += amount
	publish(player)
end

-- Takes coins if the player has enough. Returns true if paid.
function PlayerData.spendCoins(player, amount)
	local profile = profiles[player]
	if not profile or profile.data.coins < amount then
		return false
	end
	profile.data.coins -= amount
	publish(player)
	return true
end

-- Returns the new rank if this XP made the player rank up, else nil.
function PlayerData.addXP(player, amount)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local before = Progression.getRankIndex(profile.data.xp)
	profile.data.xp += amount
	local after = Progression.getRankIndex(profile.data.xp)
	publish(player)
	if after > before then
		return Config.Ranks[after]
	end
	return nil
end

-- Changes energy (negative to use it). Keeps it between 0 and max. Returns the new value.
function PlayerData.addEnergy(player, amount)
	local profile = profiles[player]
	if not profile then
		return 0
	end
	local data = profile.data
	data.energy = math.clamp(data.energy + amount, 0, Config.Energy.max)
	player:SetAttribute("Energy", math.floor(data.energy))
	return data.energy
end

-- Job requirements: uniform and assessment.
function PlayerData.hasUniform(player, jobId)
	local data = PlayerData.get(player)
	return data ~= nil and data.uniforms[jobId] == true
end

function PlayerData.giveUniform(player, jobId)
	local data = PlayerData.get(player)
	if data then
		data.uniforms[jobId] = true
		publish(player)
	end
end

function PlayerData.hasPassed(player, jobId)
	local data = PlayerData.get(player)
	return data ~= nil and data.passed[jobId] == true
end

-- Hires the player for a job (after the application and quiz).
function PlayerData.hire(player, jobId, shift, day)
	local data = PlayerData.get(player)
	if data then
		data.passed[jobId] = true
		data.employment[jobId] = { hiredDay = day, shift = shift }
		publish(player)
		sendEmployee(player)
	end
end

-- Adds one shift's wage to the pay period. r = { hours, late, undertime, wage }
function PlayerData.addPayrollShift(player, r)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local p = data.payroll
	if p.shifts == 0 then
		p.periodStart = GameClock.day(workspace:GetServerTimeNow())
	end
	p.pending += r.wage
	p.hours += r.hours
	p.late += r.late
	p.undertime += r.undertime
	p.shifts += 1
	sendPay(player)
end

-- Functions to run when a player is moved out for missing rent (Housing uses this).
local evictedCallbacks = {}
function PlayerData.onEvicted(callback)
	table.insert(evictedCallbacks, callback)
end

-- Payday: pays the pending wage minus government deductions and rent, and keeps a payslip.
-- Rent is due every payday while renting, even with no shifts. If the pay is
-- not enough, the rest comes from coins; if coins are not enough either, the
-- rent is missed. Too many missed rents in a row = moved out.
function PlayerData.runPayday(player, paydayDay)
	local data = PlayerData.get(player)
	if not data or data.lastPayday >= paydayDay then
		return
	end
	data.lastPayday = paydayDay
	local p = data.payroll
	local renting = data.renting
	if p.shifts == 0 and not renting then
		sendPay(player)
		return
	end

	local gross = p.pending
	local deductions, totalDeductions = {}, 0
	for _, d in Config.Payroll.deductions do
		local amount = math.floor(gross * d.rate + 0.5)
		table.insert(deductions, { name = d.name, amount = amount })
		totalDeductions += amount
		data.contributions[d.name] = (data.contributions[d.name] or 0) + amount
	end
	local net = math.max(0, gross - totalDeductions)

	-- Rent
	local rentNote = nil
	local evicted = false
	if renting then
		local rent = Config.housingArea(data.rentArea).rent
		local fromPay = math.min(rent, net)
		local short = rent - fromPay
		net -= fromPay
		if short == 0 then
			data.missedRent = 0
			table.insert(deductions, { name = "Rent", amount = rent })
		elseif data.coins >= short then
			data.coins -= short
			data.missedRent = 0
			table.insert(deductions, { name = "Rent", amount = rent })
			rentNote = ("%d of the rent came from your coins."):format(short)
		else
			data.missedRent += 1
			table.insert(deductions, { name = "Rent (MISSED)", amount = fromPay })
			rentNote = ("Rent missed (%d of %d allowed)."):format(data.missedRent, Config.Housing.maxMissedRent)
			if data.missedRent >= Config.Housing.maxMissedRent then
				evicted = true
				data.renting = false
				data.missedRent = 0
			end
		end
	end

	table.insert(data.payslips, 1, {
		payday = paydayDay,
		periodStart = p.periodStart,
		shifts = p.shifts,
		hours = math.floor(p.hours * 10 + 0.5) / 10,
		late = p.late,
		undertime = p.undertime,
		gross = gross,
		deductions = deductions,
		net = net,
		note = rentNote,
	})
	while #data.payslips > Config.Payroll.maxPayslips do
		table.remove(data.payslips)
	end
	data.payroll = { pending = 0, periodStart = 0, shifts = 0, hours = 0, late = 0, undertime = 0 }
	data.coins += net
	publish(player)
	sendPay(player)
	local rentText = if renting then " (after rent)" else ""
	Notify:FireClient(
		player,
		("💰 Payday! Net pay: %d coins%s. Open 💰 Pay to see your payslip.%s"):format(net, rentText, if rentNote then " " .. rentNote else ""),
		"rank",
		"payday"
	)
	if evicted then
		Notify:FireClient(player, "You missed rent too many times, so you were moved out of your house.", "bad")
		for _, callback in evictedCallbacks do
			task.spawn(callback, player)
		end
	end
end

-- Renting a house. area is a key of Config.Housing.areas.
function PlayerData.startRent(player, area)
	local data = PlayerData.get(player)
	if data then
		data.renting = true
		data.rentArea = area
		data.missedRent = 0
		publish(player)
	end
end

function PlayerData.endRent(player)
	local data = PlayerData.get(player)
	if data then
		data.renting = false
		data.missedRent = 0
		publish(player)
	end
end

-- Sleeping in your bed: full energy, once per game day. Returns true if slept.
function PlayerData.sleep(player, day)
	local data = PlayerData.get(player)
	if not data or data.sleptDay == day then
		return false
	end
	data.sleptDay = day
	data.energy = Config.Energy.max
	player:SetAttribute("Energy", math.floor(data.energy))
	return true
end

-- The fridge: move one bread between the bag and the fridge. Returns true if moved.
function PlayerData.moveFridge(player, itemId, intoFridge)
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local from = if intoFridge then data.bag else data.fridge
	local to = if intoFridge then data.fridge else data.bag
	if (from[itemId] or 0) <= 0 then
		return false
	end
	if intoFridge then
		local stored = 0
		for _, n in data.fridge do
			stored += n
		end
		if stored >= Config.Housing.fridgeSize then
			return false
		end
	end
	from[itemId] -= 1
	if from[itemId] == 0 then
		from[itemId] = nil
	end
	to[itemId] = (to[itemId] or 0) + 1
	sendBag(player)
	return true
end

-- Business: clearance, permit and store.
function PlayerData.giveClearance(player)
	local data = PlayerData.get(player)
	if data then
		data.clearance = true
		publish(player)
	end
end

function PlayerData.setPermit(player, permit)
	local data = PlayerData.get(player)
	if data then
		data.permit = permit
		publish(player)
		sendEmployee(player)
	end
end

function PlayerData.giveStore(player)
	local data = PlayerData.get(player)
	if data then
		data.ownsStore = true
		publish(player)
	end
end

-- Adds bread to the bag. items = { [itemId] = count }
function PlayerData.addToBag(player, items)
	local profile = profiles[player]
	if not profile then
		return
	end
	local bag = profile.data.bag
	for id, count in items do
		bag[id] = (bag[id] or 0) + count
	end
	sendBag(player)
end

-- Takes one bread from the bag. Returns true if there was one.
function PlayerData.takeFromBag(player, itemId)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local bag = profile.data.bag
	if (bag[itemId] or 0) <= 0 then
		return false
	end
	bag[itemId] -= 1
	if bag[itemId] == 0 then
		bag[itemId] = nil
	end
	sendBag(player)
	return true
end

-- Adds one shift to the player's Daily Time Record (newest first), adds it to
-- their lifetime work history, and sends both to them.
-- entry = { jobId, job, day, timeIn, timeOut, orders, earned, at }
function PlayerData.addDtrEntry(player, entry)
	local profile = profiles[player]
	if not profile then
		return
	end
	local dtr = profile.data.dtr
	table.insert(dtr, 1, entry)
	while #dtr > Config.Dtr.maxEntries do
		table.remove(dtr)
	end

	local jobId = entry.jobId or "unknown"
	local stats = profile.data.workStats[jobId] or { shifts = 0, orders = 0, earned = 0 }
	stats.shifts += 1
	stats.orders += entry.orders
	stats.earned += entry.earned
	profile.data.workStats[jobId] = stats

	DtrData:FireClient(player, dtr)
	sendEmployee(player)
end

function PlayerData.start()
	-- The welcome tutorial was finished or skipped.
	Remotes:WaitForChild("TutorialDone").OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if data and not data.tutorialDone then
			data.tutorialDone = true
			publish(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Save.autosaveSeconds)
			for player in profiles do
				task.spawn(saveData, player)
			end
		end
	end)

	-- Save everyone before the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveData(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return PlayerData
