-- Getting hired, and the Application Staff job.
--
-- Uniform stalls (mall 2nd floor): buy a job's uniform.
-- Job Centers: the mall (private jobs) and the Town Hall (government jobs).
-- Each lists only jobs whose applyAt matches it (Config.Jobs).
--
-- At a Job Center: get a queue number → wait on the benches → get called to a
-- window → 1. choose a job  2. requirements  3. application form → (staff
-- review, if a staff member is at the window) → 4. assessment quiz → 5. hired.
--
-- Application Staff (on shift) press "Take Window" behind a desk. When an
-- applicant at their window submits the form, the staff gets a review screen
-- and presses Approve. Staff are paid per approved applicant. No answer in time
-- = approved automatically (no pay). Windows without staff run automatically.
--
-- The quiz is graded only here: the client never sees the right answers.
--
-- The Town Hall's Business Permit Office (BPLO) is a center of kind "permits":
-- the same queue and staff windows, but the form is a Business Permit
-- application, and approving it issues the permit (no quiz). With no staff at
-- the window, a permit is approved after a processing wait.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)
local Shifts = require(script.Parent.Shifts)
local Business = require(script.Parent.Business)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local OpenJobMenu = Remotes:WaitForChild("OpenJobMenu")
local SubmitApplication = Remotes:WaitForChild("SubmitApplication")
local OpenQuiz = Remotes:WaitForChild("OpenQuiz")
local SubmitQuiz = Remotes:WaitForChild("SubmitQuiz")
local QuizResult = Remotes:WaitForChild("QuizResult")
local QueueState = Remotes:WaitForChild("QueueState")
local WorkState = Remotes:WaitForChild("WorkState")
local ReviewRequest = Remotes:WaitForChild("ReviewRequest")
local ReviewDecision = Remotes:WaitForChild("ReviewDecision")
local ReviewClosed = Remotes:WaitForChild("ReviewClosed")
local OpenPermitForm = Remotes:WaitForChild("OpenPermitForm")
local SubmitPermit = Remotes:WaitForChild("SubmitPermit")

local random = Random.new()
local STAFF_JOB = "staff"

local JobCenter = {}

-- [centerId] = {
--   id, name, kind ("jobs" or "permits"), isOpen(serverTime), desk, queueText,
--   staffSpots = { [n] = part }, windowCount,
--   windows = { [n] = { applicant = { player, ticket, startedAt } or nil,
--                        staff = Player or nil,
--                        review = nil or { kind = "job", jobId, shift, startedAt, autoAfter }
--                                     or { kind = "permit", businessName, businessType, startedAt, autoAfter } } },
--   queue = { { player, ticket }, ... }, nextTicket,
-- }
local centers = {}
local sessions = {} -- [Player] = { jobId, shift, correct = { [question] = choice } }
local retryAt = {} -- [Player] = { [jobId] = server time when they may try again }

local function now()
	return workspace:GetServerTimeNow()
end

local function notify(player, message, kind)
	if player.Parent then
		Notify:FireClient(player, message, kind)
	end
end

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function waitLeft(player, jobId)
	local times = retryAt[player]
	return math.max(0, (times and times[jobId] or 0) - now())
end

local function distanceTo(player, part)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not part then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

------------------------------------------------------------------------
-- Finding players in windows and queues
------------------------------------------------------------------------

local function findApplicant(player)
	for _, center in centers do
		for n = 1, center.windowCount do
			local applicant = center.windows[n].applicant
			if applicant and applicant.player == player then
				return center, n
			end
		end
	end
	return nil, nil
end

local function findInQueue(player)
	for _, center in centers do
		for i, entry in center.queue do
			if entry.player == player then
				return center, i, entry
			end
		end
	end
	return nil, nil, nil
end

local function findStaffWindow(player)
	for _, center in centers do
		for n = 1, center.windowCount do
			if center.windows[n].staff == player then
				return center, n
			end
		end
	end
	return nil, nil
end

------------------------------------------------------------------------
-- Screens: the NOW SERVING board, queue numbers, and the staff panel
------------------------------------------------------------------------

local function updateBoard(center)
	if not center.queueText then
		return
	end
	local parts = {}
	for n = 1, center.windowCount do
		local w = center.windows[n]
		local serving = if w.applicant then "#" .. w.applicant.ticket else "open"
		local staffMark = if w.staff then "*" else ""
		table.insert(parts, ("W%d%s: %s"):format(n, staffMark, serving))
	end
	center.queueText.Text = ("NOW SERVING\n%s\nWaiting: %d"):format(table.concat(parts, "   "), #center.queue)
end

local function sendQueueStates(center)
	for i, entry in center.queue do
		QueueState:FireClient(entry.player, { ticket = entry.ticket, ahead = i - 1 })
	end
end

-- The side panel for a staff member on shift.
local function pushStaffState(player)
	if not player.Parent then
		return
	end
	if Shifts.jobOf(player) ~= STAFF_JOB then
		WorkState:FireClient(player, nil)
		return
	end
	local center, n = findStaffWindow(player)
	local work = Shifts.get(player)
	local status = "Go behind a Job Center desk and press Take Window."
	if center then
		local w = center.windows[n]
		if w.review then
			local what = if w.review.kind == "permit" then "business permit" else "application"
			status = ("Review %s's %s!"):format(w.applicant.player.DisplayName, what)
		elseif w.applicant then
			status = ("%s is filling in the form..."):format(w.applicant.player.DisplayName)
		else
			status = "Waiting for the next applicant."
		end
	end
	WorkState:FireClient(player, {
		jobId = STAFF_JOB,
		window = if center then ("%s • Window %d"):format(center.name, n) else nil,
		status = status,
		tasks = work.tasks,
		earned = work.earned,
	})
end

------------------------------------------------------------------------
-- Uniform stalls
------------------------------------------------------------------------

local function mallOpen()
	return GameClock.isWithin(now(), Config.Mall.openHour, Config.Mall.closeHour)
end

local function buyUniform(player, jobId)
	local job = Config.Jobs[jobId]
	if not job or job.comingSoon or not PlayerData.get(player) then
		return
	end
	if not mallOpen() then
		notify(player, "The mall is closed.", "bad")
		return
	end
	local uniform = job.uniform
	if PlayerData.hasUniform(player, jobId) then
		notify(player, ("You already own the %s."):format(uniform.name), "info")
		return
	end
	if not PlayerData.spendCoins(player, uniform.price) then
		notify(player, ("You need %d coins for the %s."):format(uniform.price, uniform.name), "bad")
		return
	end
	PlayerData.giveUniform(player, jobId)
	local where = if job.applyAt == "townhall" then "the Town Hall Job Center" else "the Job Center on the 1st floor"
	local nextStep = if PlayerData.hasPassed(player, jobId) then "You wear it when you clock in." else ("Next: apply at %s."):format(where)
	notify(player, ("You bought the %s! %s"):format(uniform.name, nextStep), "good")
end

------------------------------------------------------------------------
-- The application
------------------------------------------------------------------------

local function openJobMenu(center, player)
	local jobs = {}
	for _, jobId in Config.JobOrder do
		local job = Config.Jobs[jobId]
		if job.applyAt == center.id then
			table.insert(jobs, {
				id = jobId,
				name = job.name,
				icon = job.icon,
				comingSoon = job.comingSoon == true,
				uniformName = job.uniform.name,
				uniformPrice = job.uniform.price,
				hasUniform = PlayerData.hasUniform(player, jobId),
				hired = PlayerData.hasPassed(player, jobId),
				waitSeconds = math.ceil(waitLeft(player, jobId)),
			})
		end
	end
	OpenJobMenu:FireClient(player, jobs, center.name)
end

local function startQuiz(player, jobId, shift)
	local quiz = Config.Jobs[jobId].quiz
	local picked = shuffled(quiz.pool)
	local questions, correct = {}, {}
	for i = 1, math.min(quiz.questionsPerTest, #picked) do
		local q = picked[i]
		local order = {}
		for k = 1, #q.choices do
			order[k] = k
		end
		order = shuffled(order)
		local choices = {}
		for position, original in order do
			choices[position] = q.choices[original]
			if original == q.answer then
				correct[i] = position
			end
		end
		questions[i] = { question = q.question, choices = choices }
	end
	sessions[player] = { jobId = jobId, shift = shift, correct = correct }
	OpenQuiz:FireClient(player, Config.Jobs[jobId].name, questions, quiz.passScore)
end

-- The Business Permit form (BPLO): requirements, business type and name choices.
local function openPermitForm(center, player)
	local req = Business.requirements(player)
	if not req then
		return
	end
	local types = {}
	for i, t in Config.Business.types do
		types[i] = t.name
	end
	OpenPermitForm:FireClient(player, {
		centerName = center.name,
		requirements = req,
		fee = Config.Business.permitFee,
		clearancePrice = Config.Business.clearancePrice,
		types = types,
		comingSoonTypes = Config.Business.comingSoonTypes,
		names = Business.nameChoices(player),
	})
end

-- Opens the right form for the center.
local function openForm(center, player)
	if center.kind == "permits" then
		openPermitForm(center, player)
	else
		openJobMenu(center, player)
	end
end

local function serve(center, player, ticket, n)
	local w = center.windows[n]
	w.applicant = { player = player, ticket = ticket, startedAt = now() }
	w.review = nil
	QueueState:FireClient(player, nil)
	local staffText = if w.staff then (" Staff: %s."):format(w.staff.DisplayName) else ""
	notify(player, ("Now serving #%d at Window %d.%s Fill in your application."):format(ticket, n, staffText), "rank")
	openForm(center, player)
	if w.staff then
		notify(w.staff, ("Applicant %s is at your window."):format(player.DisplayName), "info")
		pushStaffState(w.staff)
	end
end

local function callNext(center)
	for n = 1, center.windowCount do
		local w = center.windows[n]
		while not w.applicant and #center.queue > 0 do
			local entry = table.remove(center.queue, 1)
			local p = entry.player
			if p.Parent and distanceTo(p, center.desk) <= Config.JobCenter.walkAwayStuds then
				serve(center, p, entry.ticket, n)
			elseif p.Parent then
				QueueState:FireClient(p, nil)
				notify(p, ("You missed your turn (#%d). Get a new number at the Job Center."):format(entry.ticket), "bad")
			end
		end
	end
	sendQueueStates(center)
	updateBoard(center)
end

local freeWindow -- defined below

-- After a review is approved (by staff, or automatically):
--   job application → the assessment quiz starts
--   business permit → the permit is issued and the turn ends
local function approve(center, n, paidStaff)
	local w = center.windows[n]
	local review = w.review
	if not review or not w.applicant then
		return
	end
	w.review = nil
	local applicant = w.applicant.player
	local isPermit = review.kind == "permit"
	if w.staff then
		ReviewClosed:FireClient(w.staff)
		if paidStaff then
			local pay = if isPermit then Config.Business.staffPay else Config.Staff.payPerApplicant
			local xp = if isPermit then Config.Business.staffXp else Config.Staff.xpPerApplicant
			PlayerData.addCoins(w.staff, pay)
			PlayerData.addXP(w.staff, xp)
			Shifts.addWork(w.staff, pay, 1)
			notify(w.staff, ("Approved %s! +%d coins, +%d XP."):format(applicant.DisplayName, pay, xp), "good")
		else
			notify(w.staff, ("%s was approved automatically (no pay). Review faster next time!"):format(applicant.DisplayName), "bad")
		end
		pushStaffState(w.staff)
	end
	QueueState:FireClient(applicant, nil)

	if isPermit then
		local ok, message = Business.issuePermit(applicant, review.businessName, review.businessType)
		notify(applicant, message, if ok then "rank" else "bad")
		freeWindow(applicant)
	else
		notify(applicant, "Your application was approved. Time for the assessment!", "good")
		startQuiz(applicant, review.jobId, review.shift)
	end
end

-- Ends an applicant's turn at the window, then calls the next number.
freeWindow = function(player, message)
	local center, n = findApplicant(player)
	if not center then
		return
	end
	local w = center.windows[n]
	if w.review and w.staff then
		ReviewClosed:FireClient(w.staff)
	end
	w.applicant = nil
	w.review = nil
	sessions[player] = nil
	QueueState:FireClient(player, nil)
	if message then
		notify(player, message, "info")
	end
	if w.staff then
		pushStaffState(w.staff)
	end
	callNext(center)
end

local function leaveQueue(player)
	local center, i = findInQueue(player)
	if center then
		table.remove(center.queue, i)
		sendQueueStates(center)
		updateBoard(center)
	end
end

-- The "Apply for a Job" prompt.
local function onDesk(center, player)
	if not PlayerData.get(player) then
		return
	end
	if not center.isOpen(now()) then
		notify(player, ("The %s is closed."):format(center.name), "bad")
		return
	end
	if Shifts.jobOf(player) then
		notify(player, "You are working right now. Clock out first to apply for a job.", "bad")
		return
	end
	local atCenter = findApplicant(player)
	if atCenter == center then
		openForm(center, player) -- already at a window: open the form again
		return
	elseif atCenter then
		notify(player, ("You are being served at the %s."):format(atCenter.name), "info")
		return
	end
	local queuedAt, i, entry = findInQueue(player)
	if queuedAt then
		notify(player, ("Your number is #%d at the %s. %d ahead of you."):format(entry.ticket, queuedAt.name, i - 1), "info")
		return
	end

	center.nextTicket += 1
	local ticket = center.nextTicket
	local free = nil
	for n = 1, center.windowCount do
		if not center.windows[n].applicant then
			free = n
			break
		end
	end
	if free and #center.queue == 0 then
		serve(center, player, ticket, free)
	else
		table.insert(center.queue, { player = player, ticket = ticket })
		notify(player, ("Your number is #%d. Please wait on the benches. We will call you."):format(ticket), "info")
		sendQueueStates(center)
	end
	updateBoard(center)
end

-- Step 3: the client sends the form. Check everything again.
local function submitApplication(player, jobId, shiftNumber)
	if type(jobId) ~= "string" or type(shiftNumber) ~= "number" then
		return
	end
	local center, n = findApplicant(player)
	if not center then
		notify(player, "Please get a number at the Job Center desk first.", "bad")
		return
	end
	local w = center.windows[n]
	local job = Config.Jobs[jobId]
	local shift = Config.Shifts[shiftNumber]
	if not job or not shift or job.applyAt ~= center.id or w.review then
		return
	end
	if job.comingSoon then
		notify(player, ("%s jobs are coming soon."):format(job.name), "info")
		return
	end
	if PlayerData.hasPassed(player, jobId) then
		notify(player, ("You are already hired as %s."):format(job.name), "info")
		return
	end
	if not PlayerData.hasUniform(player, jobId) then
		notify(player, ("You need the %s first (mall 2nd floor)."):format(job.uniform.name), "bad")
		return
	end
	local wait = waitLeft(player, jobId)
	if wait > 0 then
		notify(player, ("You can take the assessment again in %d seconds."):format(math.ceil(wait)), "bad")
		return
	end

	local staff = w.staff
	if staff and staff.Parent and Shifts.jobOf(staff) == STAFF_JOB then
		-- A real staff member reviews the application first.
		w.review = { kind = "job", jobId = jobId, shift = shift, startedAt = now(), autoAfter = Config.Staff.reviewSeconds }
		ReviewRequest:FireClient(staff, {
			kind = "job",
			applicantName = player.DisplayName,
			applicantUser = player.Name,
			applicantId = player.UserId,
			jobName = job.name,
			jobIcon = job.icon,
			shift = shift,
			uniformName = job.uniform.name,
			hasUniform = true,
			centerName = center.name,
			window = n,
			seconds = Config.Staff.reviewSeconds,
		})
		QueueState:FireClient(player, { reviewBy = staff.DisplayName })
		notify(player, ("Please wait. %s is reviewing your application."):format(staff.DisplayName), "info")
		pushStaffState(staff)
	else
		startQuiz(player, jobId, shift)
	end
end

-- The Business Permit form (BPLO). Check everything again.
-- typeNumber and nameNumber pick from Config.Business.types and the name choices.
local function submitPermit(player, typeNumber, nameNumber)
	if type(typeNumber) ~= "number" or type(nameNumber) ~= "number" then
		return
	end
	local center, n = findApplicant(player)
	if not center or center.kind ~= "permits" then
		notify(player, "Please get a number at the BPLO window first.", "bad")
		return
	end
	local w = center.windows[n]
	local businessType = Config.Business.types[typeNumber]
	local businessName = Business.nameChoices(player)[nameNumber]
	if w.review or not businessType or not businessName then
		return
	end
	local req = Business.requirements(player)
	if not req then
		return
	end
	if req.hasPermit then
		notify(player, "You already have a Business Permit.", "info")
		return
	end
	if not req.rankOk then
		notify(player, ("You need to be at least %s rank. Work a few more shifts first."):format(req.rankName), "bad")
		return
	end
	if not req.clearance then
		notify(player, "You need a Barangay Clearance first (kiosk inside the Town Hall).", "bad")
		return
	end
	if not req.coinsOk then
		notify(player, ("You need %d coins for the permit fee."):format(Config.Business.permitFee), "bad")
		return
	end

	local staff = w.staff
	local hasStaff = staff ~= nil and staff.Parent ~= nil and Shifts.jobOf(staff) == STAFF_JOB
	w.review = {
		kind = "permit",
		businessName = businessName,
		businessType = businessType.name,
		startedAt = now(),
		autoAfter = if hasStaff then Config.Staff.reviewSeconds else Config.Business.processingSeconds,
	}
	if hasStaff then
		ReviewRequest:FireClient(staff, {
			kind = "permit",
			applicantName = player.DisplayName,
			applicantUser = player.Name,
			applicantId = player.UserId,
			businessName = businessName,
			businessType = businessType.name,
			rankName = req.rankName,
			fee = Config.Business.permitFee,
			centerName = center.name,
			window = n,
			seconds = Config.Staff.reviewSeconds,
		})
		QueueState:FireClient(player, { reviewBy = staff.DisplayName })
		notify(player, ("Please wait. %s is reviewing your Business Permit application."):format(staff.DisplayName), "info")
		pushStaffState(staff)
	else
		QueueState:FireClient(player, { reviewBy = "The BPLO", processingUntil = now() + Config.Business.processingSeconds })
		notify(player, ("Your application is being processed. Please wait about %d seconds at the window."):format(Config.Business.processingSeconds), "info")
	end
end

-- The staff member presses Approve.
local function reviewDecision(staff)
	local center, n = findStaffWindow(staff)
	if center and center.windows[n].review then
		approve(center, n, true)
	end
end

-- Step 4 → 5: grade the quiz. Pass = hired.
local function submitQuiz(player, answers)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if type(answers) ~= "table" then
		return
	end

	local score = 0
	for i, rightChoice in session.correct do
		if answers[i] == rightChoice then
			score += 1
		end
	end

	local job = Config.Jobs[session.jobId]
	local quiz = job.quiz
	local passed = score >= quiz.passScore
	if passed then
		PlayerData.hire(player, session.jobId, session.shift, GameClock.day(now()))
	else
		retryAt[player] = retryAt[player] or {}
		retryAt[player][session.jobId] = now() + quiz.retrySeconds
	end
	QuizResult:FireClient(player, {
		jobName = job.name,
		score = score,
		total = #session.correct,
		passScore = quiz.passScore,
		passed = passed,
		retrySeconds = quiz.retrySeconds,
	})
	if passed then
		notify(player, ("You are hired as %s! Find your time clock and start working."):format(job.name), "rank")
	end
	freeWindow(player)
end

------------------------------------------------------------------------
-- Staff windows
------------------------------------------------------------------------

-- Gives up the staff member's window. A pending review is approved automatically.
local function releaseStaff(player, message)
	local center, n = findStaffWindow(player)
	if not center then
		return
	end
	local w = center.windows[n]
	if w.review then
		approve(center, n, false)
	end
	w.staff = nil
	ReviewClosed:FireClient(player)
	if message then
		notify(player, message, "info")
	end
	updateBoard(center)
	pushStaffState(player)
end

local function takeWindow(center, n, player)
	if Shifts.jobOf(player) ~= STAFF_JOB then
		notify(player, "Only Application Staff on shift can take a window.", "bad")
		return
	end
	local w = center.windows[n]
	if w.staff == player then
		notify(player, ("You are already at Window %d."):format(n), "info")
		return
	end
	if w.staff then
		notify(player, ("%s is already at Window %d."):format(w.staff.DisplayName, n), "bad")
		return
	end
	releaseStaff(player) -- leave any other window first
	w.staff = player
	notify(player, ("You are now at %s, Window %d. Applicants will come to you."):format(center.name, n), "good")
	if w.applicant then
		notify(w.applicant.player, ("Staff %s is now at your window."):format(player.DisplayName), "info")
	end
	updateBoard(center)
	pushStaffState(player)
end

------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------

local function addPrompt(part, actionText, objectText, holdSeconds, role, onTriggered, distance)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdSeconds
	prompt.MaxActivationDistance = distance or 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Role", role)
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	CollectionService:AddTag(prompt, "RolePrompt")
end

-- Adds a service center. stations = { jobDesk, queueText, staffSpots }.
-- options = { kind = "jobs" (default) or "permits", windows = number, promptText = string }
function JobCenter.addCenter(id, name, isOpen, stations, options)
	options = options or {}
	local center = {
		id = id,
		name = name,
		kind = options.kind or "jobs",
		isOpen = isOpen,
		desk = stations.jobDesk,
		queueText = stations.queueText,
		staffSpots = stations.staffSpots or {},
		windowCount = options.windows or Config.JobCenter.windows,
		windows = {},
		queue = {},
		nextTicket = 0,
	}
	for n = 1, center.windowCount do
		center.windows[n] = { applicant = nil, staff = nil, review = nil }
		addPrompt(center.staffSpots[n], ("Take Window %d"):format(n), name, 0, "staff", function(player)
			takeWindow(center, n, player)
		end, 6)
	end
	addPrompt(center.desk, options.promptText or "Apply for a Job", name, 0, "any", function(player)
		onDesk(center, player)
	end)
	centers[id] = center
	updateBoard(center)
end

-- Uniform stalls at the mall: stalls = { [jobId] = part }.
function JobCenter.addStalls(stalls)
	for jobId, part in stalls do
		local job = Config.Jobs[jobId]
		if job and not job.comingSoon then
			addPrompt(part, ("Buy (%d coins)"):format(job.uniform.price), job.uniform.name, 1, "any", function(player)
				buyUniform(player, jobId)
			end)
		end
	end
end

-- The Application Staff job and its time clock.
function JobCenter.addStaffJob(timeClock, isOpen, closeHour)
	Shifts.register(STAFF_JOB, {
		place = "the Town Hall",
		isOpen = isOpen,
		closeHour = closeHour,
		onStart = function(player)
			pushStaffState(player)
			notify(player, "Go behind a Job Center desk (Town Hall or Mall) and press Take Window.", "info")
		end,
		onEnd = function(player, _closing, silent)
			releaseStaff(player)
			if not silent then
				WorkState:FireClient(player, nil)
			end
		end,
	})
	addPrompt(timeClock, "Clock In / Out", "Time Clock: Staff", 0, "any", function(player)
		Shifts.toggle(player, STAFF_JOB)
	end)
end

function JobCenter.start()
	SubmitApplication.OnServerEvent:Connect(submitApplication)
	SubmitPermit.OnServerEvent:Connect(submitPermit)
	SubmitQuiz.OnServerEvent:Connect(submitQuiz)
	ReviewDecision.OnServerEvent:Connect(reviewDecision)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
		freeWindow(player)
		releaseStaff(player)
		sessions[player] = nil
		retryAt[player] = nil
	end)

	-- Every second: review time-outs, applicant turn time-outs and walk-aways,
	-- staff walk-aways, and clearing a center when it closes.
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for _, center in centers do
				if not center.isOpen(t) then
					-- Clear the queue first, so nobody is called while closing.
					for _, entry in center.queue do
						QueueState:FireClient(entry.player, nil)
					end
					table.clear(center.queue)
					for n = 1, center.windowCount do
						local w = center.windows[n]
						if w.applicant then
							freeWindow(w.applicant.player)
						end
						if w.staff then
							releaseStaff(w.staff)
						end
					end
					updateBoard(center)
				else
					for n = 1, center.windowCount do
						local w = center.windows[n]
						if w.review and t - w.review.startedAt > w.review.autoAfter then
							approve(center, n, false)
						end
						if w.applicant then
							local p = w.applicant.player
							if t - w.applicant.startedAt > Config.JobCenter.turnSeconds then
								freeWindow(p, "Your time at the window ran out. Get a new number to try again.")
							elseif distanceTo(p, center.desk) > Config.JobCenter.walkAwayStuds then
								freeWindow(p, "You left the Job Center window. Get a new number to try again.")
							end
						end
						if w.staff and distanceTo(w.staff, center.staffSpots[n]) > Config.Staff.leaveWindowStuds then
							releaseStaff(w.staff, ("You left Window %d."):format(n))
						end
					end
				end
			end
		end
	end)
end

return JobCenter
