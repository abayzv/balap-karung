local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Reaction = {}

function Reaction.verdictFor(reactionSeconds, windowDurationSeconds)
	if reactionSeconds < 0 or reactionSeconds > windowDurationSeconds then
		return nil
	end

	local progress = reactionSeconds / windowDurationSeconds
	if progress < GameConfig.reactionWindow.earlyEndRatio then
		return "Early"
	end

	if
		progress >= GameConfig.reactionWindow.perfectStartRatio
		and progress <= GameConfig.reactionWindow.perfectEndRatio
	then
		return "Perfect"
	end

	return "Good"
end

return table.freeze(Reaction)
