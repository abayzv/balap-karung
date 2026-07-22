local LavaWaveMechanic = {}

local function horizontalUnit(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 0.001 then
		return nil
	end
	return horizontal.Unit
end

function LavaWaveMechanic.geometryForLanes(lanes, finish, lateralPaddingStuds, cleanupPaddingStuds)
	if #lanes == 0 then
		return nil
	end

	local averageSpawn = Vector3.zero
	local averageTarget = Vector3.zero
	for _, lane in lanes do
		averageSpawn += lane.spawn.Position
		averageTarget += lane.moveTarget.Position
	end
	averageSpawn /= #lanes
	averageTarget /= #lanes

	local direction = horizontalUnit(averageSpawn - averageTarget)
	if not direction then
		return nil
	end
	local right = Vector3.yAxis:Cross(direction).Unit
	local minimumLateral = math.huge
	local maximumLateral = -math.huge
	local maximumTravel = 0
	for _, lane in lanes do
		local lateral = (lane.spawn.Position - averageTarget):Dot(right)
		minimumLateral = math.min(minimumLateral, lateral)
		maximumLateral = math.max(maximumLateral, lateral)
		maximumTravel =
			math.max(maximumTravel, (lane.spawn.Position - averageTarget):Dot(direction))
	end

	return {
		origin = Vector3.new(averageTarget.X, averageSpawn.Y, averageTarget.Z),
		direction = direction,
		right = right,
		width = maximumLateral - minimumLateral + lateralPaddingStuds * 2,
		travelDistance = maximumTravel + cleanupPaddingStuds,
		finish = finish,
	}
end

function LavaWaveMechanic.timeToImpact(waveDistance, racerDistance, waveSpeed, racerForwardSpeed)
	local gap = racerDistance - waveDistance
	if gap <= 0 then
		return 0
	end
	return gap / math.max(0.001, waveSpeed + racerForwardSpeed)
end

function LavaWaveMechanic.variantForRoll(variants, roll)
	assert(#variants > 0, "Lava wave membutuhkan minimal satu variant")
	local totalWeight = 0
	for _, variant in variants do
		totalWeight += math.max(0, variant.weight or 0)
	end
	if totalWeight <= 0 then
		return variants[1]
	end

	local target = math.clamp(roll, 0, 0.999999) * totalWeight
	local accumulated = 0
	for _, variant in variants do
		accumulated += math.max(0, variant.weight or 0)
		if target < accumulated then
			return variant
		end
	end
	return variants[#variants]
end

return LavaWaveMechanic
