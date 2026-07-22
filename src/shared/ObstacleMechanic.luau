local ObstacleMechanic = {}

local function distanceBetween(left, right)
	local deltaX = left.x - right.x
	local deltaY = left.y - right.y
	return math.sqrt(deltaX * deltaX + deltaY * deltaY)
end

function ObstacleMechanic.generatePromptPositions(random, count, bounds, minimumDistance, attempts)
	local positions = {}
	for _ = 1, count do
		local selected = nil
		local selectedClearance = -math.huge
		for _ = 1, attempts do
			local candidate = {
				x = random:NextNumber(bounds.minimumX, bounds.maximumX),
				y = random:NextNumber(bounds.minimumY, bounds.maximumY),
			}
			local clearance = math.huge
			for _, position in positions do
				clearance = math.min(clearance, distanceBetween(candidate, position))
			end

			if clearance >= minimumDistance then
				selected = candidate
				break
			elseif clearance > selectedClearance then
				selected = candidate
				selectedClearance = clearance
			end
		end
		table.insert(positions, selected)
	end
	return positions
end

function ObstacleMechanic.classifyVerdicts(verdicts, requiredCount)
	if #verdicts ~= requiredCount then
		return nil
	end

	local perfectCount = 0
	local goodCount = 0
	for _, verdict in verdicts do
		if verdict == "Perfect" then
			perfectCount += 1
		elseif verdict == "Good" then
			goodCount += 1
		else
			return nil
		end
	end

	if perfectCount == requiredCount then
		return "TriplePerfect"
	elseif goodCount == requiredCount then
		return "TripleGood"
	end
	return "Mixed"
end

return table.freeze(ObstacleMechanic)
