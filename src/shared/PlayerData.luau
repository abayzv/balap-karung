local PlayerData = {}

PlayerData.template = {
	Playtime = 0,
	Win = 0,
	BestWinStreak = 0,
	WinStreak = 0,
	Coins = 0,
	OwnedTrails = {
		None = true,
	},
	EquippedTrail = "None",
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
	data.Coins = sanitizeCounter(data.Coins)
	data.BestWinStreak = math.max(data.BestWinStreak, data.WinStreak)
	if type(data.OwnedTrails) ~= "table" then
		data.OwnedTrails = {}
	end
	for trailId, owned in data.OwnedTrails do
		if type(trailId) ~= "string" or owned ~= true then
			data.OwnedTrails[trailId] = nil
		end
	end
	data.OwnedTrails.None = true
	if type(data.EquippedTrail) ~= "string" or data.OwnedTrails[data.EquippedTrail] ~= true then
		data.EquippedTrail = "None"
	end
	return data
end

function PlayerData.applyRaceResult(data, won, coinReward)
	PlayerData.sanitize(data)
	if won then
		data.Win += 1
		data.WinStreak += 1
		data.BestWinStreak = math.max(data.BestWinStreak, data.WinStreak)
	else
		data.WinStreak = 0
	end
	data.Coins += sanitizeCounter(coinReward)
	return data
end

function PlayerData.purchaseTrail(data, trailId, price)
	PlayerData.sanitize(data)
	if data.OwnedTrails[trailId] == true then
		return false, "AlreadyOwned"
	end
	price = sanitizeCounter(price)
	if data.Coins < price then
		return false, "NotEnoughCoins"
	end
	data.Coins -= price
	data.OwnedTrails[trailId] = true
	data.EquippedTrail = trailId
	return true, "Purchased"
end

function PlayerData.equipTrail(data, trailId)
	PlayerData.sanitize(data)
	if data.OwnedTrails[trailId] ~= true then
		return false, "NotOwned"
	end
	data.EquippedTrail = trailId
	return true, "Equipped"
end

return PlayerData
