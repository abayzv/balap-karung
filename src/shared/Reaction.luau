local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Reaction = {}

function Reaction.verdictFor(reactionSeconds, windowDurationSeconds)
	if reactionSeconds < 0 or reactionSeconds > windowDurationSeconds then
		return nil
	end

	if reactionSeconds <= GameConfig.reactionWindow.perfectThresholdSeconds then
		return "Perfect"
	end

	return "Good"
end

return table.freeze(Reaction)
