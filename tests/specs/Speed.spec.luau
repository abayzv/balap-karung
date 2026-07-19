return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
	local Speed = require(ReplicatedStorage.Shared.Speed)

	describe("Speed", function()
		it("clamps tiers to the configured range", function()
			expect(Speed.clampTier(0)).to.equal(1)
			expect(Speed.clampTier(100)).to.equal(#GameConfig.speed.tiers)
		end)

		it("raises a tier after three consecutive Perfects", function()
			local tier, streak = Speed.applyVerdict(1, 2, "Perfect")
			expect(tier).to.equal(2)
			expect(streak).to.equal(0)
		end)

		it("resets the streak on Good without changing tier", function()
			local tier, streak = Speed.applyVerdict(2, 2, "Good")
			expect(tier).to.equal(2)
			expect(streak).to.equal(0)
		end)

		it("drops one tier and resets the streak on Miss", function()
			local tier, streak = Speed.applyVerdict(3, 2, "Miss")
			expect(tier).to.equal(2)
			expect(streak).to.equal(0)
		end)

		it("uses shorter reaction windows at higher tiers", function()
			expect(Speed.reactionDurationForTier(4) < Speed.reactionDurationForTier(1)).to.equal(
				true
			)
		end)
	end)
end
