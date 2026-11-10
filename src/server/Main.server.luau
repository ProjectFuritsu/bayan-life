-- Server start point. Builds the town and starts each system in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)
local Atmosphere = require(script.Parent.Atmosphere)
local Energy = require(script.Parent.Energy)
local Payroll = require(script.Parent.Payroll)
local Shifts = require(script.Parent.Shifts)
local Establishments = require(script.Parent.Establishments)
local CityMap = require(script.Parent.CityMap)
local BakeryMap = require(script.Parent.BakeryMap)
local BakeryJob = require(script.Parent.BakeryJob)
local MallMap = require(script.Parent.MallMap)
local TownHallMap = require(script.Parent.TownHallMap)
local JobCenter = require(script.Parent.JobCenter)
local CleanupJob = require(script.Parent.CleanupJob)
local Business = require(script.Parent.Business)
local Housing = require(script.Parent.Housing)
local AdminCar = require(script.Parent.AdminCar)
local Announcements = require(script.Parent.Announcements)

-- Opening hours
local function bakeryOpen(t)
	return GameClock.isOpen(t) -- work hours: Config.Clock
end
local function mallOpen(t)
	return GameClock.isWithin(t, Config.Mall.openHour, Config.Mall.closeHour)
end
local function townHallOpen(t)
	return GameClock.isWithin(t, Config.TownHall.openHour, Config.TownHall.closeHour)
end

Atmosphere.apply()
PlayerData.start()
Energy.start()
Payroll.start()
Shifts.start()

-- The city: roads, plaza, park, court, palengke, houses
local city = CityMap.getOrBuild()

-- Bakery: the Baker job, and customers ordering bread
local bakery = BakeryMap.getOrBuild()
BakeryJob.start(bakery)
bakery.establishment.isOpen = bakeryOpen
Establishments.add(bakery.establishment)

-- Mall: uniform stalls and the Mall Job Center
local mall = MallMap.getOrBuild()
JobCenter.addStalls(mall.stalls)
JobCenter.addCenter("mall", "Mall Job Center", mallOpen, mall)
mall.establishment.isOpen = mallOpen
Establishments.add(mall.establishment)

-- Town Hall: the Town Hall Job Center, Application Staff and Cleanup Crew
local townHall = TownHallMap.getOrBuild()
JobCenter.addCenter("townhall", "Town Hall Job Center", townHallOpen, townHall)
JobCenter.addCenter("bplo", "Business Permit Office", townHallOpen, townHall.bplo, {
	kind = "permits",
	windows = 1,
	promptText = "Apply for a Business Permit",
})
JobCenter.addStaffJob(townHall.timeClockStaff, townHallOpen, Config.TownHall.closeHour)

-- Renting a house (Bayan Heights and Bayan Heights II), and the Admin Mansion in Veterans Parc
Housing.start({
	houses = city.houses,
	leasing = city.leasing,
	adminHouse = city.adminHouse,
})
-- The admin's drivable car, parked at the mansion
AdminCar.start(city.adminHouse and city.adminHouse.carSpot)
-- Admin announcements (/announce in chat, or the 📢 button)
Announcements.start()

-- Owning a business: Barangay Clearance kiosk and the store lots
Business.start({
	clearanceKiosk = townHall.clearanceKiosk,
	lots = city.storeLots,
})
local litterAreas = table.clone(townHall.litterAreas)
for _, area in city.litterAreas do
	table.insert(litterAreas, area)
end
CleanupJob.start({
	timeClock = townHall.timeClockCleanup,
	dumpster = townHall.dumpster,
	litterAreas = litterAreas,
}, townHallOpen, Config.TownHall.closeHour)
townHall.establishment.isOpen = townHallOpen
Establishments.add(townHall.establishment)

JobCenter.start()
Establishments.start()

print("[Bayan Life] Server ready")
