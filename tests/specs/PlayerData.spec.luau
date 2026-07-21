return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

	describe("PlayerData", function()
		it("defines every persistent race stat", function()
			expect(PlayerData.template.Playtime).to.equal(0)
			expect(PlayerData.template.Win).to.equal(0)
			expect(PlayerData.template.BestWinStreak).to.equal(0)
			expect(PlayerData.template.WinStreak).to.equal(0)
		end)

		it("increments wins and preserves the best streak", function()
			local data = table.clone(PlayerData.template)
			PlayerData.applyRaceResult(data, true)
			PlayerData.applyRaceResult(data, true)

			expect(data.Win).to.equal(2)
			expect(data.WinStreak).to.equal(2)
			expect(data.BestWinStreak).to.equal(2)
		end)

		it("resets only the current streak after losing", function()
			local data = {
				Playtime = 60,
				Win = 4,
				BestWinStreak = 3,
				WinStreak = 2,
			}
			PlayerData.applyRaceResult(data, false)

			expect(data.Playtime).to.equal(60)
			expect(data.Win).to.equal(4)
			expect(data.WinStreak).to.equal(0)
			expect(data.BestWinStreak).to.equal(3)
		end)
	end)
end
