return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LavaWaveMechanic = require(ReplicatedStorage.Shared.LavaWaveMechanic)

	describe("LavaWaveMechanic", function()
		it("calculates time to a head-on wave", function()
			local seconds = LavaWaveMechanic.timeToImpact(100, 202, 70, 32)
			expect(math.abs(seconds - 1) < 0.001).to.equal(true)
		end)

		it("reports an already-passed impact immediately", function()
			expect(LavaWaveMechanic.timeToImpact(120, 100, 70, 32)).to.equal(0)
		end)

		it("selects weighted variants deterministically", function()
			local variants = {
				{ id = "Normal", weight = 55 },
				{ id = "Fast", weight = 30 },
				{ id = "Double", weight = 15 },
			}
			expect(LavaWaveMechanic.variantForRoll(variants, 0.1).id).to.equal("Normal")
			expect(LavaWaveMechanic.variantForRoll(variants, 0.6).id).to.equal("Fast")
			expect(LavaWaveMechanic.variantForRoll(variants, 0.9).id).to.equal("Double")
		end)
	end)
end
