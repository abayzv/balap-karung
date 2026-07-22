local ImpactFeedback = {}

function ImpactFeedback.shouldPlaySound(localUserId, soundUserId, alreadyPlayedLocally)
	return alreadyPlayedLocally ~= true
		and type(localUserId) == "number"
		and type(soundUserId) == "number"
		and localUserId == soundUserId
end

return table.freeze(ImpactFeedback)
