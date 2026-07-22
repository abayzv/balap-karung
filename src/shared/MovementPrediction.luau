local MovementPrediction = {}

function MovementPrediction.advanceDistance(distance, speed, deltaTime, trackLength)
	local currentDistance = math.max(0, tonumber(distance) or 0)
	local forwardSpeed = math.max(0, tonumber(speed) or 0)
	local elapsed = math.max(0, tonumber(deltaTime) or 0)
	local maximumDistance = math.max(0, tonumber(trackLength) or 0)
	return math.clamp(currentDistance + forwardSpeed * elapsed, 0, maximumDistance)
end

function MovementPrediction.extrapolateDistance(
	distance,
	speed,
	updatedAt,
	now,
	maximumExtrapolation,
	trackLength
)
	local elapsed = math.clamp(
		(tonumber(now) or 0) - (tonumber(updatedAt) or 0),
		0,
		math.max(0, tonumber(maximumExtrapolation) or 0)
	)
	return MovementPrediction.advanceDistance(distance, speed, elapsed, trackLength)
end

function MovementPrediction.progressAt(position, startOrigin, forward, trackLength)
	local maximumDistance = math.max(0, tonumber(trackLength) or 0)
	if maximumDistance == 0 or forward.Magnitude < 0.001 then
		return 0
	end
	return math.clamp((position - startOrigin):Dot(forward.Unit), 0, maximumDistance)
end

function MovementPrediction.reconciliationMode(
	localDistance,
	authoritativeDistance,
	smoothThreshold,
	snapThreshold
)
	local difference = authoritativeDistance - localDistance
	local absoluteDifference = math.abs(difference)
	if absoluteDifference > snapThreshold then
		return "Snap", difference
	elseif absoluteDifference > smoothThreshold then
		return "Smooth", difference
	end
	return "None", difference
end

function MovementPrediction.smoothingAlpha(deltaTime, correctionRate)
	return math.clamp(math.max(0, deltaTime) * math.max(0, correctionRate), 0, 1)
end

return table.freeze(MovementPrediction)
