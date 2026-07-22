return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlayerData = require(ReplicatedStorage.Shared.PlayerData)

	local function newData(coins)
		return {
			Playtime = 0,
			Win = 0,
			BestWinStreak = 0,
			WinStreak = 0,
			Coins = coins or 0,
			OwnedTrails = { None = true },
			EquippedTrail = "None",
		}
	end

	describe("PlayerData", function()
		it("defines every persistent race stat", function()
			expect(PlayerData.template.Playtime).to.equal(0)
			expect(PlayerData.template.Win).to.equal(0)
			expect(PlayerData.template.BestWinStreak).to.equal(0)
			expect(PlayerData.template.WinStreak).to.equal(0)
			expect(PlayerData.template.Coins).to.equal(0)
			expect(PlayerData.template.OwnedTrails.None).to.equal(true)
			expect(PlayerData.template.EquippedTrail).to.equal("None")
		end)

		it("increments wins and preserves the best streak", function()
			local data = newData()
			PlayerData.applyRaceResult(data, true, 15)
			PlayerData.applyRaceResult(data, true, 10)

			expect(data.Win).to.equal(2)
			expect(data.WinStreak).to.equal(2)
			expect(data.BestWinStreak).to.equal(2)
			expect(data.Coins).to.equal(25)
		end)

		it("resets only the current streak after losing", function()
			local data = {
				Playtime = 60,
				Win = 4,
				BestWinStreak = 3,
				WinStreak = 2,
				Coins = 9,
				OwnedTrails = { None = true },
				EquippedTrail = "None",
			}
			PlayerData.applyRaceResult(data, false)

			expect(data.Playtime).to.equal(60)
			expect(data.Win).to.equal(4)
			expect(data.WinStreak).to.equal(0)
			expect(data.BestWinStreak).to.equal(3)
			expect(data.Coins).to.equal(9)
		end)

		it("buys and auto-equips an affordable trail", function()
			local data = newData(200)
			local success, code = PlayerData.purchaseTrail(data, "RedFire", 150)

			expect(success).to.equal(true)
			expect(code).to.equal("Purchased")
			expect(data.Coins).to.equal(50)
			expect(data.OwnedTrails.RedFire).to.equal(true)
			expect(data.EquippedTrail).to.equal("RedFire")
		end)

		it("rejects purchases without enough coins", function()
			local data = newData(149)
			local success, code = PlayerData.purchaseTrail(data, "RedFire", 150)

			expect(success).to.equal(false)
			expect(code).to.equal("NotEnoughCoins")
			expect(data.Coins).to.equal(149)
		end)

		it("only equips owned trails", function()
			local data = newData()
			local success, code = PlayerData.equipTrail(data, "Rainbow")
			expect(success).to.equal(false)
			expect(code).to.equal("NotOwned")

			data.OwnedTrails.Rainbow = true
			success, code = PlayerData.equipTrail(data, "Rainbow")
			expect(success).to.equal(true)
			expect(code).to.equal("Equipped")
			expect(data.EquippedTrail).to.equal("Rainbow")
		end)
	end)
end
