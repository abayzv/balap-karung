return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local NetworkTiming = require(ReplicatedStorage.Shared.NetworkTiming)

	local config = {
		initialOneWayLatencySeconds = 0.1,
		maximumOneWayLatencySeconds = 0.5,
		minimumLeadSeconds = 0.05,
		graceMultiplier = 0.6,
		maximumGraceSeconds = 0.3,
	}

	describe("NetworkTiming", function()
		it("uses latency as lead without lowering a gameplay lead", function()
			expect(NetworkTiming.leadSeconds(0.2, 0, config)).to.equal(0.2)
			expect(NetworkTiming.leadSeconds(0.1, 0.25, config)).to.equal(0.25)
		end)

		it("caps smoothed latency and grace", function()
			expect(NetworkTiming.smoothLatency(0.1, 2, 1, 0.5)).to.equal(0.5)
			expect(NetworkTiming.graceSeconds(1, config)).to.equal(0.3)
		end)

		it("expands physical validation by speed and latency with a hard cap", function()
			expect(NetworkTiming.validationDistance(0.1, 40, 16, 32)).to.equal(20)
			expect(NetworkTiming.validationDistance(1, 100, 16, 32)).to.equal(32)
		end)

		it("accepts an on-time press that arrives during server grace", function()
			local event = {
				opensAt = 10,
				closesAt = 11,
				graceSeconds = 0.2,
			}
			expect(NetworkTiming.resolveAt(event.closesAt, event.graceSeconds)).to.equal(11.2)
			expect(NetworkTiming.reactionSeconds(event, 10.75)).to.equal(0.75)
			expect(NetworkTiming.reactionSeconds(event, 11.01)).to.equal(nil)
		end)

		it("clamps a slightly early synchronized timestamp", function()
			local event = {
				opensAt = 10,
				closesAt = 11,
				graceSeconds = 0.1,
			}
			expect(NetworkTiming.reactionSeconds(event, 9.95)).to.equal(0)
			expect(NetworkTiming.reactionSeconds(event, 9.8)).to.equal(nil)
		end)

		it("rejects implausible client clocks", function()
			expect(NetworkTiming.isTimestampPlausible(20, 19.5, 1.5)).to.equal(true)
			expect(NetworkTiming.isTimestampPlausible(20, 18, 1.5)).to.equal(false)
			expect(NetworkTiming.isTimestampPlausible(20, "20", 1.5)).to.equal(false)
		end)

		it("does not display a prompt that arrived too late", function()
			expect(NetworkTiming.shouldDisplayPrompt(10.85, 10, 1, 0.15)).to.equal(true)
			expect(NetworkTiming.shouldDisplayPrompt(10.86, 10, 1, 0.15)).to.equal(false)
		end)
	end)
end
