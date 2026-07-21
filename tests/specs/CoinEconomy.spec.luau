return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CoinEconomy = require(ReplicatedStorage.Shared.CoinEconomy)

	describe("CoinEconomy", function()
		it("rewards every valid finishing position", function()
			expect(CoinEconomy.rewardForResult(1, 3)).to.equal(15)
			expect(CoinEconomy.rewardForResult(2, 3)).to.equal(10)
			expect(CoinEconomy.rewardForResult(3, 3)).to.equal(7)
			expect(CoinEconomy.rewardForResult(4, 3)).to.equal(3)
			expect(CoinEconomy.rewardForResult(10, 8)).to.equal(3)
		end)

		it("blocks coin rewards for inactive racers", function()
			expect(CoinEconomy.rewardForResult(1, 2)).to.equal(0)
			expect(CoinEconomy.rewardForResult(1, 0)).to.equal(0)
		end)
	end)
end
