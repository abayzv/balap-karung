local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Speed = {}

function Speed.clampTier(tier)
	return math.clamp(tier, 1, #GameConfig.speed.tiers)
end

function Speed.getTier(tier)
	return GameConfig.speed.tiers[Speed.clampTier(tier)]
end

function Speed.valueForTier(tier)
	return Speed.getTier(tier).value
end

function Speed.reactionDurationForTier(tier)
	return Speed.getTier(tier).reactionDurationSeconds
end

function Speed.applyVerdict(currentTier, currentStreak, verdict)
	local tier = Speed.clampTier(currentTier)
	local streak = currentStreak

	if verdict == "Perfect" then
		streak += 1
		if streak >= GameConfig.speed.perfectsPerTier then
			if tier < #GameConfig.speed.tiers then
				tier += 1
				streak = 0
			else
				streak = GameConfig.speed.perfectsPerTier
			end
		end
	elseif verdict == "Good" then
		streak = 0
	elseif verdict == "Miss" then
		tier = math.max(1, tier - 1)
		streak = 0
	else
		error(`Unknown reaction verdict: {tostring(verdict)}`)
	end

	return tier, streak
end

return table.freeze(Speed)
