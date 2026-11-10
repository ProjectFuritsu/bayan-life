-- All game numbers live here. To balance the game, change these, not the job code.

local Config = {}

-- Ranks you earn with XP. A higher rank pays a bonus on top of what the
-- customer pays, and unlocks new breads. "Owner" is not on this list: you become
-- an Owner by buying your own bakery (a later build step).
Config.Ranks = {
	{ name = "Helper", minXP = 0, payMultiplier = 1 },
	{ name = "Worker", minXP = 100, payMultiplier = 1.25 },
	{ name = "Boss", minXP = 400, payMultiplier = 1.5 },
}

Config.Bakery = {
	-- The breads. One oven bakes all of them; the baker picks which one.
	-- unlockRank: the rank number that unlocks baking it (1 = Helper, 2 = Worker, 3 = Boss).
	-- price: coins the customer pays. energy: energy the customer gets when eating it.
	-- color: used for bread on the racks, in the glass case and on the carry tray.
	items = {
		{ id = "pandesal", name = "Pandesal", icon = "🍞", color = Color3.fromRGB(200, 135, 65), bakeSeconds = 2, price = 3, energy = 10, unlockRank = 1 },
		{ id = "spanishbread", name = "Spanish Bread", icon = "🥖", color = Color3.fromRGB(215, 155, 85), bakeSeconds = 2.5, price = 5, energy = 15, unlockRank = 1 },
		{ id = "pandecoco", name = "Pan de Coco", icon = "🥥", color = Color3.fromRGB(235, 195, 125), bakeSeconds = 3, price = 7, energy = 20, unlockRank = 2 },
		{ id = "ensaymada", name = "Ensaymada", icon = "🧁", color = Color3.fromRGB(250, 220, 140), bakeSeconds = 3.5, price = 10, energy = 30, unlockRank = 3 },
	},
	
	-- Where bread goes: Oven → Bread Rack → baker's hands → Glass case → customer's bag.
	rackLimit = 6, -- bread on the racks + in the oven; the map has 6 rack shelves
	carryLimit = 6, -- bread a baker can carry at once
	caseLimit = 8, -- bread in the glass case; the map layout fits up to 8

	-- Orders come only from real players (made to order, no NPC customers).
	maxOrderItems = 6, -- most breads in one order; must be <= rackLimit and caseLimit
	orderTimeoutSeconds = 180, -- not served in time = full refund to the customer
	fastServeSeconds = 90, -- served within this time = bonus XP for the baker
	fastXpBonus = 0.5, -- +50% XP

	xpPerItem = 5,
	ovenReach = 14, -- how close (studs) a player must be to use the oven menu
	counterReach = 12, -- how close a customer must be to use the order menu
}

-- Jobs and how you get hired:
--   1. Buy the job's uniform at its stall on the mall's 2nd floor.
--   2. Apply at the job's Job Center (applyAt): "mall" (Bayan Mall, 1st floor) or
--      "townhall" (Bayan Town Hall). Choose the job, check the requirements,
--      fill in the form, and pass the assessment quiz.
-- Each Job Center lists only its own jobs. To move or add a job, set applyAt.
-- Being hired is saved, so it is a one-time thing per job.
-- Quiz answers are checked only on the server; the client never sees them.
-- comingSoon jobs show in the job menu and have a closed stall, but can't be applied for yet.
Config.JobOrder = { "baker", "staff", "cleanup", "clerk", "driver", "fisher" } -- menu and stall order

-- Preferred shift on the application form. It becomes the worker's schedule.
Config.Shifts = { "Morning", "Afternoon", "Whole day" }

-- Work schedules (game hours). Clocking in after start + grace = Late;
-- clocking out before the end = Undertime. Only hours inside the schedule
-- earn the hourly wage (tasks, tips and customer payments always pay).
Config.Schedules = {
	Morning = { start = 6, finish = 11 },
	Afternoon = { start = 11, finish = 17 },
	["Whole day"] = { start = 6, finish = 17 },
}

-- Payroll ("sahod"): the hourly wage adds up and is paid on payday, with a
-- payslip and government deductions (employee share).
Config.Payroll = {
	paydayEveryDays = 3, -- a payday every 3 game days (about 45 real minutes)
	graceMinutes = 10, -- game minutes before you count as late
	hourlyRate = { baker = 6, staff = 8, cleanup = 5 }, -- coins per paid game hour (times the rank bonus)
	deductions = {
		{ name = "SSS", rate = 0.045 },
		{ name = "PhilHealth", rate = 0.025 },
		{ name = "Pag-IBIG", rate = 0.02 },
	},
	maxPayslips = 10, -- keep the newest 10 payslips
}

Config.Jobs = {
	clerk = { name = "Sari-sari Clerk", icon = "🏪", applyAt = "mall", comingSoon = true, uniform = { name = "Clerk Uniform", price = 400 } },
	driver = { name = "Jeepney Driver", icon = "🚌", applyAt = "mall", comingSoon = true, uniform = { name = "Driver Uniform", price = 600 } },
	fisher = { name = "Fisher", icon = "🎣", applyAt = "mall", comingSoon = true, uniform = { name = "Fisher Uniform", price = 450 } },

	staff = {
		name = "Application Staff",
		icon = "🗂️",
		applyAt = "townhall",
		uniform = { name = "Staff Uniform", price = 450 },
		quiz = {
			questionsPerTest = 5,
			passScore = 4,
			retrySeconds = 30,
			pool = {
				{ question = "Where do application staff clock in?", choices = { "At the bakery", "At the Town Hall time clock", "At the mall stalls" }, answer = 2 },
				{ question = "How do you start working at a window?", choices = { "Press Take Window behind a Job Center desk", "Sit on a bench", "Buy a uniform" }, answer = 1 },
				{ question = "An applicant is at your window. What do you do?", choices = { "Ignore them", "Review their application and press Approve", "Send them home" }, answer = 2 },
				{ question = "What does an applicant need before applying?", choices = { "The job's uniform", "500 bread", "A jeepney" }, answer = 1 },
				{ question = "What happens if you wait too long to review?", choices = { "The applicant waits forever", "It is approved automatically and you get no pay", "You get double pay" }, answer = 2 },
				{ question = "Where can staff work?", choices = { "Only at home", "At any Job Center desk (Town Hall or Mall)", "Only in the bakery" }, answer = 2 },
				{ question = "Can you review your own application?", choices = { "Yes, anytime", "Only on weekends", "No, never" }, answer = 3 },
				{ question = "What time does the Town Hall close?", choices = { "5:00 PM", "10:00 PM", "8:00 AM" }, answer = 1 },
			},
		},
	},

	cleanup = {
		name = "Cleanup Crew",
		icon = "🧹",
		applyAt = "townhall",
		uniform = { name = "Cleanup Uniform", price = 350 },
		quiz = {
			questionsPerTest = 5,
			passScore = 4,
			retrySeconds = 30,
			pool = {
				{ question = "Where does the Cleanup Crew clock in?", choices = { "At the Town Hall time clock", "At the bakery oven", "At the mall stairs" }, answer = 1 },
				{ question = "What does the Cleanup Crew pick up?", choices = { "Bread", "Litter like cans, bottles and wrappers", "Coins" }, answer = 2 },
				{ question = "Where do you empty a full bag?", choices = { "In the bakery", "Anywhere", "At the Town Hall dumpster" }, answer = 3 },
				{ question = "Who pays the Cleanup Crew?", choices = { "The barangay", "The customers", "Nobody" }, answer = 1 },
				{ question = "How many pieces fit in your bag?", choices = { "3", "10", "100" }, answer = 2 },
				{ question = "Where is most litter found?", choices = { "On the roof", "Around the plaza and paths", "Inside the oven" }, answer = 2 },
				{ question = "What happens when your energy reaches 0?", choices = { "You are sent home to rest", "You get more coins", "Nothing happens" }, answer = 1 },
				{ question = "What time does the Town Hall close?", choices = { "12:00 PM", "5:00 PM", "11:00 PM" }, answer = 2 },
			},
		},
	},

	baker = {
		name = "Baker",
		icon = "🍞",
		applyAt = "mall",
		uniform = { name = "Baker Uniform", price = 500 },
		quiz = {
			questionsPerTest = 5,
			passScore = 4, -- right answers needed to pass
			retrySeconds = 30, -- wait after a failed try
			-- answer = the number of the right choice (1, 2 or 3).
			-- If you change the work hours in Config.Clock, update the closing-time question.
			pool = {
				{ question = "Where do you clock in to start work?", choices = { "At the Time Clock", "At the Oven", "At the Trash bin" }, answer = 1 },
				{ question = "When can a baker bake bread?", choices = { "Anytime they want", "When a customer has ordered", "Only at night" }, answer = 2 },
				{ question = "Where does bread go after the oven?", choices = { "Into the customer's bag", "Onto the Bread Racks", "Into the trash" }, answer = 2 },
				{ question = "How does bread get to the counter?", choices = { "It flies there", "The customer gets it", "You pick it up at a Bread Rack and carry it" }, answer = 3 },
				{ question = "Where do you serve orders?", choices = { "Behind the counter", "At the Time Clock", "At the Mall" }, answer = 1 },
				{ question = "What time does the bakery close?", choices = { "12:00 PM", "5:00 PM", "9:00 PM" }, answer = 2 },
				{ question = "What happens when your energy reaches 0?", choices = { "You get more coins", "Nothing happens", "You are sent home to rest" }, answer = 3 },
				{ question = "Which bread can a new Helper bake?", choices = { "Pandesal", "Ensaymada", "Pan de Coco" }, answer = 1 },
				{ question = "What happens if an order is not served in time?", choices = { "The customer gets their coins back", "The baker gets double pay", "Nothing happens" }, answer = 1 },
			},
		},
	},
}

-- Bayan Town Hall: office hours (game time) for the building and its jobs.
Config.TownHall = {
	openHour = 6, -- 6:00 AM, same as the bakery
	closeHour = 17, -- 5:00 PM
}

-- Application Staff: review applicants at Job Center windows.
Config.Staff = {
	payPerApplicant = 20, -- coins from the town, per approved applicant
	xpPerApplicant = 10,
	reviewSeconds = 30, -- no answer in time = approved automatically, no pay
	leaveWindowStuds = 12, -- walking this far from your window gives it up
}

-- Cleanup Crew: pick up litter and empty the bag at the Town Hall dumpster.
-- Litter piles up overnight: a big batch appears in the morning, a little more
-- comes until morningEndHour, then none until the next morning.
Config.Cleanup = {
	morningBatch = 30, -- pieces that appear at once when the day starts (6:00 AM)
	morningEndHour = 9, -- more litter trickles in until 9:00 AM
	spawnSeconds = 5, -- one new piece every few seconds during the morning
	maxLitter = 45, -- most pieces in town at once
	bagSize = 10,
	payPerPiece = 3, -- coins from the barangay
	xpPerPiece = 2,
}

-- Owning a business (stage 1): Barangay Clearance → Business Permit (BPLO at
-- the Town Hall, reviewed by Application Staff or processed automatically) →
-- buy the right to a store → your store takes a free lot when you join.
Config.Business = {
	minRank = 2, -- rank number needed to apply (2 = Worker)
	clearancePrice = 100, -- Barangay Clearance kiosk at the Town Hall
	permitFee = 1000, -- paid when the permit is approved
	storePrice = 2000, -- one-time, after you have a permit
	processingSeconds = 60, -- no staff at the BPLO window = approved after this wait
	staffPay = 30, -- coins for the staff member who approves a permit
	staffXp = 10,
	types = { { id = "sarisari", name = "Sari-sari Store" } }, -- more types later
	comingSoonTypes = { "Carinderia", "Bakery Branch" },
	-- Business name choices; %s = the player's display name (already moderated by Roblox).
	nameStyles = { "Tindahan ni %s", "%s's Sari-sari Store", "%s Mini Mart" },
}

-- Job Center service windows. Only this many players apply at the same time;
-- everyone else gets a queue number and waits on the benches.
Config.JobCenter = {
	windows = 2, -- service windows (set to 1 for one at a time)
	turnSeconds = 150, -- real seconds a player may hold a window (form + quiz)
	walkAwayStuds = 30, -- walking this far from the desk gives up your turn
}

-- Mall opening hours (game time). Outside these hours the doors close and
-- anyone inside is walked out. The bakery uses Config.Clock open/close hours.
Config.Mall = {
	openHour = 6, -- 6:00 AM
	closeHour = 22, -- 10:00 PM
}

-- Coins. Customers pay bakers, so coins move between players. New players get
-- starter coins once, so a server of new players can buy the first bread.
Config.Economy = {
	starterCoins = 5000, -- given once, to brand-new players only
}

-- Energy: working uses it, eating bread refills it.
Config.Energy = {
	max = 100,
	start = 100, -- new players start full
	drainPerMinute = 8, -- real minutes on shift; a 12-minute work day uses about 96
	minToWork = 10, -- you can't clock in below this
	lowWarning = 20, -- warn the worker once when energy drops below this
	restLevel = 40, -- each new day (6:00 AM), energy refills to at least this
}

-- The game clock. Every server shows the same time of day.
Config.Clock = {
	openHour = 6, -- 6:00 AM: you can clock in
	closeHour = 17, -- 5:00 PM: everyone is clocked out
	workRealMinutes = 12, -- real minutes from open to close (set to 2 to test closing fast)
	nightRealMinutes = 3, -- real minutes from close to the next open
	warningGameMinutes = 30, -- warn this many game minutes before closing
	firstDay = 1794182400, -- server time when "Day 1" began (9 Nov 2026, 00:00 UTC)
}

-- Daily Time Record: one entry per shift.
Config.Dtr = {
	maxEntries = 30, -- keep the newest 30 shifts
}

-- Admins. The game owner is always an admin (after you publish the place under
-- your account). Add more admins by Roblox user ID: Admins = { [12345678] = true }.
-- StudioOwnerIsAdmin: in Studio "Play" (solo), your own account counts as admin.
-- (Studio's multi-player test players have negative IDs, so they never count.)
Config.Admins = {}
Config.StudioOwnerIsAdmin = true

-- Renting a house. Rent comes out of your payslip on payday.
-- Each subdivision has its own Leasing Office and rent (coins per pay period;
-- one period is paid upfront when you move in). You rent one house at a time.
Config.Housing = {
	areas = {
		heights2 = { name = "Bayan Heights II", rent = 80 }, -- starter row houses
		heights = { name = "Bayan Heights", rent = 150 }, -- premium 2-storey houses
	},
	maxMissedRent = 2, -- missed rents in a row before you are moved out
	fridgeSize = 20, -- bread the fridge can hold
}

-- The subdivision settings for an area key (old saves have none: Bayan Heights).
function Config.housingArea(key)
	return Config.Housing.areas[key] or Config.Housing.areas.heights
end

-- Sounds. Empty = silent. To add one: in Studio open Toolbox → Audio, search
-- (for example "cash register"), pick one made by Roblox, right-click → Copy
-- Asset ID, and paste it here as "rbxassetid://123456". Only a few sounds come
-- built into Roblox ("rbxasset://sounds/..."), so most start empty.
Config.Sounds = {
	click = "rbxasset://sounds/volume_slider.ogg", -- buttons
	pop = "rbxasset://sounds/volume_slider.ogg", -- messages (fallback for the ones below)
	good = "", -- a good message (served, bought, hired)
	bad = "", -- a "can't do that" message
	fanfare = "", -- rank up, hired, big news
	payday = "", -- payday (try a cash register)
	announce = "", -- admin announcement banner (try a chime or bell)
	coin = "", -- coins go up
	door = "", -- building doors open or close
	fountain = "", -- water loop at the plaza fountain
	oven = "", -- crackling loop at the bakery oven
	splash = "rbxasset://sounds/impact_water.mp3", -- (built in)
}

Config.Save = {
	dataStoreName = "BayanLife_PlayerData_v1",
	autosaveSeconds = 120,
}

return Config
