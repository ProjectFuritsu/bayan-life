-- Simple body poses without animation files: moves the shoulder joints so the
-- arms reach forward (for example, holding a tray). Works for R15 and R6.
-- The walk animation still plays on top, so the arms swing a little.

local Poses = {}

local original = setmetatable({}, { __mode = "k" }) -- [Motor6D] = its normal C0

local function shoulders(character)
	local rightArm = character:FindFirstChild("RightUpperArm")
	local leftArm = character:FindFirstChild("LeftUpperArm")
	if rightArm and leftArm then
		return rightArm:FindFirstChild("RightShoulder"), leftArm:FindFirstChild("LeftShoulder"), "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder"), torso:FindFirstChild("Left Shoulder"), "R6"
	end
	return nil, nil, nil
end

-- holding = true: both arms forward. false: back to normal.
function Poses.setHolding(player, holding)
	local character = player.Character
	if not character then
		return
	end
	local right, left, rig = shoulders(character)
	if not right or not left then
		return
	end
	for _, motor in { right, left } do
		if original[motor] == nil then
			original[motor] = motor.C0
		end
	end
	if not holding then
		right.C0 = original[right]
		left.C0 = original[left]
	elseif rig == "R15" then
		local forward = CFrame.Angles(math.rad(75), 0, 0)
		right.C0 = original[right] * forward
		left.C0 = original[left] * forward
	else
		right.C0 = original[right] * CFrame.Angles(0, 0, math.rad(75))
		left.C0 = original[left] * CFrame.Angles(0, 0, math.rad(-75))
	end
end

return Poses
