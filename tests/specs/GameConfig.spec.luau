return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

	describe("GameConfig", function()
		it("uses the BalapKarung project name", function()
			expect(GameConfig.projectName).to.equal("BalapKarung")
		end)

		it("starts on a configured speed tier", function()
			expect(GameConfig.speed.startingTier >= 1).to.equal(true)
			expect(GameConfig.speed.startingTier <= #GameConfig.speed.tiers).to.equal(true)
			expect(GameConfig.speed.tiers[GameConfig.speed.startingTier].value).to.equal(32)
		end)

		it("supports up to ten manual track lanes", function()
			expect(GameConfig.race.maximumLanes).to.equal(10)
			expect(GameConfig.track.tags.track).to.equal("BalapKarungTrack")
			expect(GameConfig.track.tags.spawn).to.equal("BalapKarungSpawn")
			expect(GameConfig.track.tags.moveTarget).to.equal("MoveTarget")
			expect(GameConfig.track.tags.finish).to.equal("BalapKarungFinish")
		end)

		it("waits thirty seconds in the lobby before a race", function()
			expect(GameConfig.race.intermissionSeconds).to.equal(30)
		end)

		it("uses the ten second race countdown", function()
			expect(GameConfig.race.countdownSeconds).to.equal(10)
			expect(GameConfig.race.startSignalSeconds > 0).to.equal(true)
		end)

		it("keeps the perfect threshold inside every reaction window", function()
			for _, tier in GameConfig.speed.tiers do
				expect(
					GameConfig.reactionWindow.perfectThresholdSeconds < tier.reactionDurationSeconds
				).to.equal(true)
			end
		end)

		it("keeps speed tiers harder and faster", function()
			for index = 2, #GameConfig.speed.tiers do
				local previousTier = GameConfig.speed.tiers[index - 1]
				local currentTier = GameConfig.speed.tiers[index]
				expect(currentTier.value > previousTier.value).to.equal(true)
				expect(currentTier.reactionDurationSeconds < previousTier.reactionDurationSeconds).to.equal(
					true
				)
			end
		end)

		it("configures significant temporary verdict boosts", function()
			expect(GameConfig.speed.verdictMultiplier.Perfect).to.equal(2)
			expect(GameConfig.speed.verdictMultiplier.Good).to.equal(1.5)
			expect(GameConfig.speed.boostDurationSeconds).to.equal(3)
		end)

		it("configures animation playback for the faster base movement", function()
			expect(GameConfig.animations.walkPlaybackSpeedAtBase).to.equal(2)
			expect(GameConfig.animations.fall).to.equal("rbxassetid://105372185107291")
			expect(GameConfig.animations.fallPlaybackSpeed).to.equal(1)
			expect(GameConfig.animations.hopMarkerName).to.equal("OnHop")
		end)

		it("configures a short Miss recovery", function()
			expect(GameConfig.movement.missRecoverySeconds).to.equal(0.65)
		end)

		it("provides all core sound config slots", function()
			for _, soundName in { "hop", "good", "perfect", "miss" } do
				expect(GameConfig.sounds[soundName] ~= nil).to.equal(true)
				expect(type(GameConfig.sounds[soundName].soundId)).to.equal("string")
				expect(GameConfig.sounds[soundName].volume > 0).to.equal(true)
			end
		end)

		it("uses an image asset for the reaction icon", function()
			expect(string.find(GameConfig.ui.reactionIcon, "rbxassetid://", 1, true) == 1).to.equal(
				true
			)
		end)

		it("keeps random prompt positions inside the screen", function()
			expect(GameConfig.reactionWindow.minimumScreenX > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenX < 1).to.equal(true)
			expect(GameConfig.reactionWindow.minimumScreenY > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenY < 1).to.equal(true)
		end)
	end)
end
