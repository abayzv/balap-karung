local NetworkTiming = {}

function NetworkTiming.smoothLatency(previousLatency, sampleLatency, alpha, maximumLatency)
	local previous = math.clamp(tonumber(previousLatency) or 0, 0, maximumLatency)
	local sample = math.clamp(tonumber(sampleLatency) or previous, 0, maximumLatency)
	return previous * (1 - alpha) + sample * alpha
end

function NetworkTiming.leadSeconds(oneWayLatency, baseLeadSeconds, config)
	local latency = math.clamp(
		oneWayLatency or config.initialOneWayLatencySeconds,
		0,
		config.maximumOneWayLatencySeconds
	)
	return math.max(config.minimumLeadSeconds, baseLeadSeconds or 0, latency)
end

function NetworkTiming.graceSeconds(oneWayLatency, config)
	local latency = math.clamp(
		oneWayLatency or config.initialOneWayLatencySeconds,
		0,
		config.maximumOneWayLatencySeconds
	)
	return math.min(latency * config.graceMultiplier, config.maximumGraceSeconds)
end

function NetworkTiming.validationDistance(oneWayLatency, effectiveSpeed, baseDistance, maxDistance)
	local latency = math.max(0, tonumber(oneWayLatency) or 0)
	local speed = math.max(0, tonumber(effectiveSpeed) or 0)
	local minimum = math.max(0, tonumber(baseDistance) or 0)
	local maximum = math.max(minimum, tonumber(maxDistance) or minimum)
	return math.min(minimum + speed * latency, maximum)
end

function NetworkTiming.resolveAt(closesAt, graceSeconds)
	return closesAt + math.max(0, graceSeconds or 0)
end

function NetworkTiming.isTimestampPlausible(serverNow, clientTimestamp, maximumDifference)
	return type(clientTimestamp) == "number"
		and math.abs(serverNow - clientTimestamp) <= maximumDifference
end

function NetworkTiming.reactionSeconds(event, clientPressedAt)
	local grace = event.graceSeconds or 0
	if clientPressedAt < event.opensAt - grace or clientPressedAt > event.closesAt then
		return nil
	end
	return math.max(0, clientPressedAt - event.opensAt)
end

function NetworkTiming.shouldDisplayPrompt(receivedAt, opensAt, duration, minimumRemaining)
	return opensAt + duration - receivedAt >= minimumRemaining
end

return table.freeze(NetworkTiming)
