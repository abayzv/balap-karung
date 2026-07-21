local PlayerData = {}

PlayerData.template = {
	Playtime = 0,
	Win = 0,
	BestWinStreak = 0,
	WinStreak = 0,
}

local function sanitizeCounter(value)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

function PlayerData.sanitize(data)
	data.Playtime = sanitizeCounter(data.Playtime)
	data.Win = sanitizeCounter(data.Win)
	data.BestWinStreak = sanitizeCounter(data.BestWinStreak)
	data.WinStreak = sanitizeCounter(data.WinStreak)
	data.BestWinStreak = math.max(data.BestWinStreak, data.WinStreak)
	return data
end

function PlayerData.applyRaceResult(data, won)
	PlayerData.sanitize(data)
	if won then
		data.Win += 1
		data.WinStreak += 1
		data.BestWinStreak = math.max(data.BestWinStreak, data.WinStreak)
	else
		data.WinStreak = 0
	end
	return data
end

return PlayerData
