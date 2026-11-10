-- The game clock: turns server time into a game time of day.
--
-- A game day = the work part (open → close) + the night part (close → next open).
-- The night runs faster, so players do not wait long. Server and client both use
-- this with workspace:GetServerTimeNow(), so they always agree without messages.

local Config = require(script.Parent.Config)

local C = Config.Clock
local WORK = C.workRealMinutes * 60 -- real seconds
local NIGHT = C.nightRealMinutes * 60
local CYCLE = WORK + NIGHT
local WORK_HOURS = C.closeHour - C.openHour -- game hours
local NIGHT_HOURS = 24 - WORK_HOURS

local GameClock = {}

-- Real seconds that pass for one game minute while the bakery is open.
GameClock.realSecondsPerWorkMinute = WORK / (WORK_HOURS * 60)

local function phase(serverTime)
	return (serverTime - C.firstDay) % CYCLE
end

-- The game hour, from 0 to 24. For example, 16.5 means 4:30 PM.
function GameClock.hour(serverTime)
	local p = phase(serverTime)
	local h
	if p < WORK then
		h = C.openHour + p / WORK * WORK_HOURS
	else
		h = C.closeHour + (p - WORK) / NIGHT * NIGHT_HOURS
	end
	return h % 24
end

-- The game day number: 1, 2, 3... A new day starts at opening time.
function GameClock.day(serverTime)
	return math.floor((serverTime - C.firstDay) / CYCLE) + 1
end

function GameClock.isOpen(serverTime)
	return phase(serverTime) < WORK
end

-- True if the game hour is between openHour and closeHour (for example, mall hours).
function GameClock.isWithin(serverTime, openHour, closeHour)
	local h = GameClock.hour(serverTime)
	return h >= openHour and h < closeHour
end

-- Real seconds until closing. Only makes sense while open.
function GameClock.secondsUntilClose(serverTime)
	return WORK - phase(serverTime)
end

-- Real seconds until the next opening. Only makes sense while closed.
function GameClock.secondsUntilOpen(serverTime)
	return CYCLE - phase(serverTime)
end

-- 16.5 → "4:30 PM"
function GameClock.format(hour)
	local h = math.floor(hour) % 24
	local m = math.floor((hour - math.floor(hour)) * 60)
	local suffix = if h < 12 then "AM" else "PM"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return ("%d:%02d %s"):format(h12, m, suffix)
end

return GameClock
