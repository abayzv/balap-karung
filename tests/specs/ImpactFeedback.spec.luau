return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ImpactFeedback = require(ReplicatedStorage.Shared.ImpactFeedback)

	describe("ImpactFeedback", function()
		it("plays impact audio only for the owning client", function()
			expect(ImpactFeedback.shouldPlaySound(10, 10, false)).to.equal(true)
			expect(ImpactFeedback.shouldPlaySound(11, 10, false)).to.equal(false)
		end)

		it("does not replay audio after local prediction", function()
			expect(ImpactFeedback.shouldPlaySound(10, 10, true)).to.equal(false)
		end)
	end)
end
