local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CoinEconomy = {}

function CoinEconomy.rewardForResult(rank, validInputCount)
	if
		type(rank) ~= "number"
		or rank < 1
		or type(validInputCount) ~= "number"
		or validInputCount < GameConfig.economy.minimumValidInputsForReward
	then
		return 0
	end
	return GameConfig.economy.coinRewards[rank] or GameConfig.economy.coinRewards.default
end

return table.freeze(CoinEconomy)
