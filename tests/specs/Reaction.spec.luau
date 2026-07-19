return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Reaction = require(ReplicatedStorage.Shared.Reaction)

	describe("Reaction", function()
		it("returns Perfect for fast reactions", function()
			expect(Reaction.verdictFor(0, 1.2)).to.equal("Perfect")
			expect(Reaction.verdictFor(0.4, 1.2)).to.equal("Perfect")
		end)

		it("returns Good for valid slower reactions", function()
			expect(Reaction.verdictFor(0.401, 1.2)).to.equal("Good")
			expect(Reaction.verdictFor(0.6, 0.6)).to.equal("Good")
		end)

		it("rejects input outside the active window", function()
			expect(Reaction.verdictFor(-0.01, 1.2)).to.equal(nil)
			expect(Reaction.verdictFor(0.601, 0.6)).to.equal(nil)
		end)
	end)
end
