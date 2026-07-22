return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ObstacleMechanic = require(ReplicatedStorage.Shared.ObstacleMechanic)

	describe("ObstacleMechanic", function()
		it("generates naturally random prompt positions with safe spacing", function()
			local bounds = {
				minimumX = 0.28,
				maximumX = 0.72,
				minimumY = 0.28,
				maximumY = 0.82,
			}
			local positions =
				ObstacleMechanic.generatePromptPositions(Random.new(8128), 3, bounds, 0.2, 40)
			expect(#positions).to.equal(3)
			for index, position in positions do
				expect(position.x >= bounds.minimumX and position.x <= bounds.maximumX).to.equal(
					true
				)
				expect(position.y >= bounds.minimumY and position.y <= bounds.maximumY).to.equal(
					true
				)
				for otherIndex = 1, index - 1 do
					local other = positions[otherIndex]
					local deltaX = position.x - other.x
					local deltaY = position.y - other.y
					expect(math.sqrt(deltaX * deltaX + deltaY * deltaY) >= 0.2).to.equal(true)
				end
			end
		end)

		it("classifies three Perfect verdicts", function()
			expect(ObstacleMechanic.classifyVerdicts({ "Perfect", "Perfect", "Perfect" }, 3)).to.equal(
				"TriplePerfect"
			)
		end)

		it("classifies three Good verdicts", function()
			expect(ObstacleMechanic.classifyVerdicts({ "Good", "Good", "Good" }, 3)).to.equal(
				"TripleGood"
			)
		end)

		it("classifies a successful mixed combo", function()
			expect(ObstacleMechanic.classifyVerdicts({ "Perfect", "Good", "Perfect" }, 3)).to.equal(
				"Mixed"
			)
		end)

		it("rejects incomplete or failed combos", function()
			expect(ObstacleMechanic.classifyVerdicts({ "Perfect", "Good" }, 3)).to.equal(nil)
			expect(ObstacleMechanic.classifyVerdicts({ "Perfect", "Early", "Good" }, 3)).to.equal(
				nil
			)
		end)
	end)
end
