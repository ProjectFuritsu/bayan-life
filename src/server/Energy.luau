-- Energy: eating bread from the bag, and the night rest at the start of each day.
-- (Using energy while working is in BakeryJob.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EatRequest = Remotes:WaitForChild("EatRequest")
local Notify = Remotes:WaitForChild("Notify")

local itemsById = {}
for _, item in Config.Bakery.items do
	itemsById[item.id] = item
end

local Energy = {}

local function eat(player, itemId)
	-- Never trust what the client sends.
	if type(itemId) ~= "string" then
		return
	end
	local item = itemsById[itemId]
	local data = PlayerData.get(player)
	if not item or not data then
		return
	end
	if data.energy >= Config.Energy.max then
		Notify:FireClient(player, "Your energy is already full.", "info")
		return
	end
	if not PlayerData.takeFromBag(player, itemId) then
		return
	end
	local energy = PlayerData.addEnergy(player, item.energy)
	Notify:FireClient(
		player,
		("Yum! %s %s: +%d energy (%d/%d)"):format(item.icon, item.name, item.energy, math.floor(energy), Config.Energy.max),
		"good"
	)
end

function Energy.start()
	EatRequest.OnServerEvent:Connect(eat)

	-- Night rest: when a new game day starts (6:00 AM), everyone online gets rest.
	-- Players who join later get it when their data loads (PlayerData).
	local lastDay = GameClock.day(workspace:GetServerTimeNow())
	task.spawn(function()
		while true do
			task.wait(1)
			local day = GameClock.day(workspace:GetServerTimeNow())
			if day ~= lastDay then
				lastDay = day
				for _, player in Players:GetPlayers() do
					if PlayerData.applyRest(player, day) then
						Notify:FireClient(player, ("Good morning! You rested. Energy is up to %d."):format(Config.Energy.restLevel), "info")
					end
				end
			end
		end
	end)
end

return Energy
