local LeaderboardPolicy = {}

function LeaderboardPolicy.isExcludedUserId(
	userId,
	configuredUserIds,
	isUserOwnedExperience,
	creatorId
)
	local numericUserId = tonumber(userId)
	if not numericUserId then
		return false
	end
	if isUserOwnedExperience == true and numericUserId == tonumber(creatorId) then
		return true
	end
	for _, configuredUserId in configuredUserIds or {} do
		if numericUserId == tonumber(configuredUserId) then
			return true
		end
	end
	return false
end

return table.freeze(LeaderboardPolicy)
