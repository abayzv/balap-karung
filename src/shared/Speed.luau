local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Speed = {}

function Speed.clampProgress(progress)
	return math.clamp(progress, 0, GameConfig.speed.onFireRequiredHits)
end

function Speed.stageForProgress(progress)
	local safeProgress = Speed.clampProgress(progress)
	if safeProgress >= GameConfig.speed.onFireRequiredHits then
		return 3
	elseif safeProgress >= GameConfig.speed.fastTempoRequiredHits then
		return 2
	end
	return 1
end

function Speed.tempoForProgress(progress)
	return GameConfig.speed.tempos[Speed.stageForProgress(progress)]
end

function Speed.valueForOnFire(onFire)
	return if onFire then GameConfig.speed.onFireValue else GameConfig.speed.normalValue
end

function Speed.applyVerdict(currentProgress, verdict)
	local progress = Speed.clampProgress(currentProgress)
	if verdict == "Perfect" or verdict == "Good" then
		progress = Speed.clampProgress(progress + 1)
	elseif verdict == "Early" or verdict == "Miss" then
		progress = 0
	else
		error(`Unknown reaction verdict: {tostring(verdict)}`)
	end

	local stage = Speed.stageForProgress(progress)
	return progress, stage, stage == 3
end

return table.freeze(Speed)
