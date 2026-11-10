-- Who is an admin: the game owner, anyone in Config.Admins, and (in Studio
-- solo Play) your own account. Used for the Admin Mansion in Veterans Parc.

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Admin = {}

function Admin.isAdmin(player)
	if Config.Admins[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and player.UserId == game.CreatorId then
		return true
	end
	if Config.StudioOwnerIsAdmin and RunService:IsStudio() and player.UserId > 0 then
		return true
	end
	return false
end

return Admin
