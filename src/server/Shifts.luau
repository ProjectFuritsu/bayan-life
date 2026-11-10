-- Shifts for every job: clock in and out, hiring requirements, work hours,
-- energy use, closing time, uniforms and the Daily Time Record.
-- A player works one job at a time.
--
-- Each job registers itself:
--   Shifts.register(jobId, {
--     place = "the bakery",                 -- used in messages
--     isOpen = function(serverTime) -> bool,
--     closeHour = 17,                       -- for the "closing soon" warning
--     onStart = function(player),           -- make the job's own state
--     onEnd = function(player, closing, silent),  -- clean up (closing = closing time)
--   })
-- Jobs report their work with Shifts.addWork(player, coins, tasks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(script.Parent.PlayerData)
local Uniforms = require(script.Parent.Uniforms)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local Shifts = {}

local jobs = {} -- [jobId] = definition
local active = {} -- [Player] = { jobId, day, timeIn, tasks, earned, lowWarned }

local function now()
	return workspace:GetServerTimeNow()
end

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

-- "the bakery" → "The bakery"
local function capitalize(text)
	return (text:gsub("^%l", string.upper))
end

function Shifts.register(jobId, definition)
	jobs[jobId] = definition
end

-- The player's shift, or nil.
function Shifts.get(player)
	return active[player]
end

-- The job the player is working now, or nil.
function Shifts.jobOf(player)
	local shift = active[player]
	return shift and shift.jobId
end

-- Counts work done this shift (for the DTR): coins earned and tasks done.
function Shifts.addWork(player, coins, tasks)
	local shift = active[player]
	if shift then
		shift.earned += coins
		shift.tasks += tasks
	end
end

-- The player's work schedule for a job (from their application), and its name.
local function scheduleFor(player, jobId)
	local data = PlayerData.get(player)
	local record = data and data.employment[jobId]
	local name = record and record.shift
	if not Config.Schedules[name] then
		name = "Whole day"
	end
	return Config.Schedules[name], name
end

local function scheduleText(schedule, name)
	return ("%s (%s - %s)"):format(name, GameClock.format(schedule.start), GameClock.format(schedule.finish))
end

-- Compares a shift with the schedule. Returns paid hours, late minutes,
-- undertime minutes, and whether the shift was outside the schedule.
local function timeReport(schedule, timeIn, timeOut)
	if timeIn >= schedule.finish or timeOut <= schedule.start then
		return 0, 0, 0, true
	end
	local paidHours = math.min(timeOut, schedule.finish) - math.max(timeIn, schedule.start)
	local late = (timeIn - schedule.start) * 60
	if late <= Config.Payroll.graceMinutes then
		late = 0
	end
	local undertime = if timeOut < schedule.finish then (schedule.finish - timeOut) * 60 else 0
	return math.max(0, paidHours), math.floor(late), math.floor(undertime), false
end

-- Ends the shift, works out the pay, and writes it to the DTR.
-- silent = true when the player is leaving the game.
-- closing = true at closing time.
function Shifts.finish(player, reason, silent, closing)
	local shift = active[player]
	if not shift then
		return
	end
	local job = Config.Jobs[shift.jobId]
	local definition = jobs[shift.jobId]
	definition.onEnd(player, closing, silent) -- the job may still add work (for example, a last bag)
	active[player] = nil
	player:SetAttribute("OnShift", "")

	-- Hours inside the schedule earn the hourly wage, paid on payday.
	local timeOut = GameClock.hour(now())
	local schedule, scheduleName = scheduleFor(player, shift.jobId)
	local paidHours, late, undertime, outside = timeReport(schedule, shift.timeIn, timeOut)
	local data = PlayerData.get(player)
	local bonus = if data then Progression.getRank(data.xp).payMultiplier else 1
	local rate = Config.Payroll.hourlyRate[shift.jobId] or 0
	local wage = math.floor(paidHours * rate * bonus + 0.5)
	PlayerData.addPayrollShift(player, { hours = paidHours, late = late, undertime = undertime, wage = wage })

	PlayerData.addDtrEntry(player, {
		jobId = shift.jobId,
		job = job.name,
		day = shift.day,
		timeIn = shift.timeIn,
		timeOut = timeOut,
		schedule = scheduleName,
		hours = math.floor(paidHours * 10 + 0.5) / 10,
		late = late,
		undertime = undertime,
		wage = wage,
		orders = shift.tasks,
		earned = shift.earned,
		at = os.time(),
	})
	if silent then
		return
	end
	Uniforms.remove(player)

	local notes = {}
	if outside then
		table.insert(notes, "outside your schedule (no hourly wage)")
	else
		if late > 0 then
			table.insert(notes, ("late %d min"):format(late))
		end
		if undertime > 0 then
			table.insert(notes, ("undertime %d min"):format(undertime))
		end
	end
	local noteText = if #notes > 0 then " • " .. table.concat(notes, ", ") else ""
	notify(
		player,
		("%s In %s, out %s • %.1f paid hours%s • Wage +%d (on payday) • %d tasks, +%d coins now."):format(
			reason,
			GameClock.format(shift.timeIn),
			GameClock.format(timeOut),
			paidHours,
			noteText,
			wage,
			shift.tasks,
			shift.earned
		),
		"rank"
	)
end

-- The time clock: clock in to a job, or clock out.
function Shifts.toggle(player, jobId)
	local current = active[player]
	if current then
		if current.jobId == jobId then
			Shifts.finish(player, "You clocked out.")
		else
			notify(player, ("You are working as %s. Clock out there first."):format(Config.Jobs[current.jobId].name), "bad")
		end
		return
	end

	local data = PlayerData.get(player)
	local job = Config.Jobs[jobId]
	local definition = jobs[jobId]
	if not data or not job or not definition then
		return
	end

	-- Hiring requirements: the uniform (mall 2nd floor) and the application.
	local missing = {}
	if not PlayerData.hasUniform(player, jobId) then
		table.insert(missing, ("the %s (Mall 2nd floor, %d coins)"):format(job.uniform.name, job.uniform.price))
	end
	if not PlayerData.hasPassed(player, jobId) then
		local where = if job.applyAt == "townhall" then "the Town Hall Job Center" else "the Mall Job Center"
		table.insert(missing, ("to apply at %s"):format(where))
	end
	if #missing > 0 then
		notify(player, ("To work as %s, you need %s."):format(job.name, table.concat(missing, " and ")), "bad")
		return
	end

	local t = now()
	if not definition.isOpen(t) then
		notify(player, ("%s is closed right now."):format(capitalize(definition.place)), "bad")
		return
	end
	if data.energy < Config.Energy.minToWork then
		notify(player, ("You are too tired to work (energy %d). Eat some bread, or rest until morning."):format(math.floor(data.energy)), "bad")
		return
	end

	active[player] = {
		jobId = jobId,
		day = GameClock.day(t),
		timeIn = GameClock.hour(t),
		tasks = 0,
		earned = 0,
		lowWarned = false,
	}
	player:SetAttribute("OnShift", jobId)
	Uniforms.wear(player, jobId)
	definition.onStart(player)

	-- Tell the worker if they are on time, late, or outside their schedule.
	local timeIn = GameClock.hour(t)
	local schedule, scheduleName = scheduleFor(player, jobId)
	local _, late, _, outside = timeReport(schedule, timeIn, schedule.finish)
	local status, kind
	if outside then
		status, kind = "Outside your schedule: tasks still pay, but no hourly wage.", "info"
	elseif late > 0 then
		status, kind = ("LATE by %d minutes."):format(late), "bad"
	else
		status, kind = "On time! ✅", "good"
	end
	notify(
		player,
		("Time in %s as %s. %s Schedule: %s."):format(GameClock.format(timeIn), job.name, status, scheduleText(schedule, scheduleName)),
		kind
	)
end

function Shifts.start()
	-- A player who leaves mid-shift still gets a DTR entry (before the save).
	PlayerData.onLeaving(function(player)
		Shifts.finish(player, "Left the game.", true)
	end)

	-- Put the uniform back on after a respawn.
	local function watch(player)
		player:SetAttribute("OnShift", "")
		player.CharacterAdded:Connect(function()
			task.wait()
			local shift = active[player]
			if shift then
				Uniforms.wear(player, shift.jobId)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local drainPerSecond = Config.Energy.drainPerMinute / 60
	local wasOpen = {} -- [jobId] = boolean
	local warnedDay = {} -- [jobId] = day

	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()

			-- Working uses energy.
			for player, shift in active do
				local energy = PlayerData.addEnergy(player, -drainPerSecond)
				if energy <= 0 then
					Shifts.finish(player, "You are too tired! Eat some bread.")
				elseif energy < Config.Energy.lowWarning and not shift.lowWarned then
					shift.lowWarned = true
					notify(player, ("Low energy (%d)! Buy and eat bread on your break."):format(math.floor(energy)), "rank")
				end
			end

			-- Closing time for each job: a warning, then everyone is clocked out.
			for jobId, definition in jobs do
				local open = definition.isOpen(t)
				local day = GameClock.day(t)
				if open then
					local minutesLeft = (definition.closeHour - GameClock.hour(t)) * 60
					if minutesLeft <= Config.Clock.warningGameMinutes and warnedDay[jobId] ~= day then
						warnedDay[jobId] = day
						for player, shift in active do
							if shift.jobId == jobId then
								notify(player, ("%d minutes to closing time!"):format(Config.Clock.warningGameMinutes), "rank")
							end
						end
					end
				elseif wasOpen[jobId] then
					local closing = GameClock.format(definition.closeHour)
					for player, shift in active do
						if shift.jobId == jobId then
							Shifts.finish(player, ("%s! %s is closed."):format(closing, capitalize(definition.place)), false, true)
						end
					end
				end
				wasOpen[jobId] = open
			end
		end
	end)
end

return Shifts
