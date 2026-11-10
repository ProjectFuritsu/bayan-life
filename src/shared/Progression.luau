-- Rank math. Shared so the server (pay) and the client (XP bar) agree.

local Config = require(script.Parent.Config)

local Progression = {}

function Progression.getRankIndex(xp)
	local index = 1
	for i, rank in Config.Ranks do
		if xp >= rank.minXP then
			index = i
		end
	end
	return index
end

function Progression.getRank(xp)
	return Config.Ranks[Progression.getRankIndex(xp)]
end

-- Returns nil at the top rank.
function Progression.getNextRank(xp)
	return Config.Ranks[Progression.getRankIndex(xp) + 1]
end

return Progression
