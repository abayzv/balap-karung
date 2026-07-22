return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local MovementPrediction = require(ReplicatedStorage.Shared.MovementPrediction)

	describe("MovementPrediction", function()
		it("advances and clamps authoritative distance", function()
			expect(MovementPrediction.advanceDistance(10, 32, 0.5, 100)).to.equal(26)
			expect(MovementPrediction.advanceDistance(90, 32, 0.5, 100)).to.equal(100)
		end)

		it("does not advance while movement is paused", function()
			expect(MovementPrediction.advanceDistance(25, 0, 3, 100)).to.equal(25)
		end)

		it("extrapolates a stale server snapshot with a hard time cap", function()
			expect(MovementPrediction.extrapolateDistance(10, 32, 5, 5.25, 0.5, 100)).to.equal(18)
			expect(MovementPrediction.extrapolateDistance(10, 32, 5, 7, 0.5, 100)).to.equal(26)
		end)

		it("projects physical position onto the lane", function()
			local progress = MovementPrediction.progressAt(
				Vector3.new(8, 20, -30),
				Vector3.new(8, 0, 10),
				Vector3.new(0, 0, -1),
				100
			)
			expect(progress).to.equal(40)
		end)

		it("selects bounded reconciliation modes", function()
			expect(MovementPrediction.reconciliationMode(10, 10.5, 1, 10)).to.equal("None")
			expect(MovementPrediction.reconciliationMode(10, 12, 1, 10)).to.equal("Smooth")
			expect(MovementPrediction.reconciliationMode(10, 21, 1, 10)).to.equal("Snap")
		end)

		it("caps smoothing alpha", function()
			local alpha = MovementPrediction.smoothingAlpha(0.1, 3)
			expect(alpha > 0.29 and alpha < 0.31).to.equal(true)
			expect(MovementPrediction.smoothingAlpha(1, 3)).to.equal(1)
		end)
	end)
end
