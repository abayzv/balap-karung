local LeaderboardFormat = {}

local FIELD_ALIASES = {
	win = "Win",
	wins = "Win",
	playtime = "Playtime",
	winstreak = "WinStreak",
	bestwinstreak = "BestWinStreak",
	coins = "Coins",
	coin = "Coins",
}

function LeaderboardFormat.normalizeDataKey(value)
	if type(value) ~= "string" then
		return "win"
	end
	local normalized = string.lower(value):gsub("[^%w]", "")
	return if normalized ~= "" then normalized else "win"
end

function LeaderboardFormat.resolveField(value)
	local key = LeaderboardFormat.normalizeDataKey(value)
	return FIELD_ALIASES[key] or value
end

function LeaderboardFormat.formatNumber(value)
	local digits = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local formatted = digits
	repeat
		local replaced
		formatted, replaced = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return formatted
end

function LeaderboardFormat.formatValue(dataKey, value)
	local numericValue = math.max(0, math.floor(tonumber(value) or 0))
	if LeaderboardFormat.normalizeDataKey(dataKey) ~= "playtime" then
		return LeaderboardFormat.formatNumber(numericValue)
	end
	local days = math.floor(numericValue / 86400)
	local hours = math.floor((numericValue % 86400) / 3600)
	local minutes = math.floor((numericValue % 3600) / 60)
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	elseif minutes > 0 then
		return `{minutes}m`
	end
	return `{numericValue}s`
end

return table.freeze(LeaderboardFormat)
