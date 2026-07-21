return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LeaderboardFormat = require(ReplicatedStorage.Shared.LeaderboardFormat)

	describe("LeaderboardFormat", function()
		it("resolves profile and leaderstat aliases", function()
			expect(LeaderboardFormat.resolveField("win")).to.equal("Win")
			expect(LeaderboardFormat.resolveField("PLAYTIME")).to.equal("Playtime")
			expect(LeaderboardFormat.resolveField("best_win_streak")).to.equal("BestWinStreak")
		end)

		it("formats counters with separators", function()
			expect(LeaderboardFormat.formatNumber(0)).to.equal("0")
			expect(LeaderboardFormat.formatNumber(1234567)).to.equal("1,234,567")
		end)

		it("formats playtime compactly", function()
			expect(LeaderboardFormat.formatValue("playtime", 45)).to.equal("45s")
			expect(LeaderboardFormat.formatValue("playtime", 3660)).to.equal("1h 1m")
			expect(LeaderboardFormat.formatValue("playtime", 90000)).to.equal("1d 1h")
		end)
	end)
end
