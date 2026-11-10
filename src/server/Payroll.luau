-- Payday: every Config.Payroll.paydayEveryDays game days, at the start of the
-- day (6:00 AM), everyone online is paid their wages minus deductions.
-- (Players who were away get paid when they join; see PlayerData.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)

local Payroll = {}

function Payroll.start()
	local lastDay = GameClock.day(workspace:GetServerTimeNow())
	task.spawn(function()
		while true do
			task.wait(1)
			local day = GameClock.day(workspace:GetServerTimeNow())
			if day ~= lastDay then
				lastDay = day
				if day % Config.Payroll.paydayEveryDays == 0 then
					for _, player in Players:GetPlayers() do
						PlayerData.runPayday(player, day)
					end
				end
			end
		end
	end)
end

return Payroll
