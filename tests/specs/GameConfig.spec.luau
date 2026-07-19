return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

	describe("GameConfig", function()
		it("uses the BalapKarung project name", function()
			expect(GameConfig.projectName).to.equal("BalapKarung")
		end)

		it("starts momentum inside its configured range", function()
			expect(GameConfig.momentum.starting >= GameConfig.momentum.minimum).to.equal(true)
			expect(GameConfig.momentum.starting <= GameConfig.momentum.maximum).to.equal(true)
		end)

		it("keeps the perfect threshold inside the reaction window", function()
			expect(
				GameConfig.reactionWindow.perfectThresholdSeconds
					< GameConfig.reactionWindow.durationSeconds
			).to.equal(true)
		end)
	end)
end
