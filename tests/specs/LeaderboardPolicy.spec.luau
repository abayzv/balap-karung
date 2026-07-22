return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LeaderboardPolicy = require(ReplicatedStorage.Shared.LeaderboardPolicy)

	describe("LeaderboardPolicy", function()
		it("excludes explicitly configured owners", function()
			expect(LeaderboardPolicy.isExcludedUserId(9154250170, { 9154250170 }, false, 0)).to.equal(
				true
			)
			expect(LeaderboardPolicy.isExcludedUserId(123, { 9154250170 }, false, 0)).to.equal(
				false
			)
		end)

		it("automatically excludes the creator of user-owned experiences", function()
			expect(LeaderboardPolicy.isExcludedUserId(55, {}, true, 55)).to.equal(true)
			expect(LeaderboardPolicy.isExcludedUserId(56, {}, true, 55)).to.equal(false)
		end)
	end)
end
