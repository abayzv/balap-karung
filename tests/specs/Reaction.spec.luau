return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Reaction = require(ReplicatedStorage.Shared.Reaction)

	describe("Reaction", function()
		it("returns Early before the timing ring is close", function()
			expect(Reaction.verdictFor(0, 1)).to.equal("Early")
			expect(Reaction.verdictFor(0.549, 1)).to.equal("Early")
		end)

		it("returns Good while approaching or passing the target", function()
			expect(Reaction.verdictFor(0.55, 1)).to.equal("Good")
			expect(Reaction.verdictFor(0.699, 1)).to.equal("Good")
			expect(Reaction.verdictFor(0.851, 1)).to.equal("Good")
			expect(Reaction.verdictFor(1, 1)).to.equal("Good")
		end)

		it("returns Perfect while aligned with the target outline", function()
			expect(Reaction.verdictFor(0.7, 1)).to.equal("Perfect")
			expect(Reaction.verdictFor(0.775, 1)).to.equal("Perfect")
			expect(Reaction.verdictFor(0.85, 1)).to.equal("Perfect")
		end)

		it("rejects input outside the active window", function()
			expect(Reaction.verdictFor(-0.01, 1.2)).to.equal(nil)
			expect(Reaction.verdictFor(0.601, 0.6)).to.equal(nil)
		end)
	end)
end
