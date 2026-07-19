return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

	describe("GameConfig", function()
		it("uses the BalapKarung project name", function()
			expect(GameConfig.projectName).to.equal("BalapKarung")
		end)

		it("configures Normal and On Fire movement speed", function()
			expect(GameConfig.speed.normalValue).to.equal(32)
			expect(GameConfig.speed.onFireValue > GameConfig.speed.normalValue).to.equal(true)
		end)

		it("supports up to ten manual track lanes", function()
			expect(GameConfig.race.maximumLanes).to.equal(10)
			expect(GameConfig.track.tags.track).to.equal("BalapKarungTrack")
			expect(GameConfig.track.tags.spawn).to.equal("BalapKarungSpawn")
			expect(GameConfig.track.tags.moveTarget).to.equal("MoveTarget")
			expect(GameConfig.track.tags.finish).to.equal("BalapKarungFinish")
		end)

		it("waits thirty seconds in the lobby before a race", function()
			expect(GameConfig.race.minimumPlayers).to.equal(2)
			expect(GameConfig.race.intermissionSeconds).to.equal(30)
			expect(GameConfig.queue.startPartTag).to.equal("StartPart")
		end)

		it("uses the ten second race countdown", function()
			expect(GameConfig.race.countdownSeconds).to.equal(10)
			expect(GameConfig.race.startSignalSeconds > 0).to.equal(true)
		end)

		it("keeps timing verdict bands in order", function()
			expect(GameConfig.reactionWindow.earlyEndRatio > 0).to.equal(true)
			expect(
				GameConfig.reactionWindow.earlyEndRatio
					< GameConfig.reactionWindow.perfectStartRatio
			).to.equal(true)
			expect(
				GameConfig.reactionWindow.perfectStartRatio
					< GameConfig.reactionWindow.perfectEndRatio
			).to.equal(true)
			expect(GameConfig.reactionWindow.perfectEndRatio < 1).to.equal(true)
		end)

		it("makes every progress stage faster", function()
			for index = 2, #GameConfig.speed.tempos do
				local previousTempo = GameConfig.speed.tempos[index - 1]
				local currentTempo = GameConfig.speed.tempos[index]
				expect(currentTempo.reactionDurationSeconds < previousTempo.reactionDurationSeconds).to.equal(
					true
				)
				expect(currentTempo.maximumIntervalSeconds < previousTempo.maximumIntervalSeconds).to.equal(
					true
				)
			end
		end)

		it("triggers the faster stages at three and five hits", function()
			expect(GameConfig.speed.fastTempoRequiredHits).to.equal(3)
			expect(GameConfig.speed.onFireRequiredHits).to.equal(5)
		end)

		it("keeps the temporary Good and Perfect speed boosts", function()
			expect(GameConfig.speed.verdictMultiplier.Good).to.equal(1.5)
			expect(GameConfig.speed.verdictMultiplier.Perfect).to.equal(2)
			expect(GameConfig.speed.boostDurationSeconds).to.equal(3)
		end)

		it("configures the one-shot and looping On Fire sounds", function()
			expect(GameConfig.sounds.onFireEnter.soundId).to.equal("rbxassetid://130422645188028")
			expect(GameConfig.sounds.onFireLoop.soundId).to.equal("rbxassetid://82555625627924")
		end)

		it("configures client background music", function()
			expect(GameConfig.sounds.backgroundMusic.soundId).to.equal(
				"rbxassetid://108881053322600"
			)
		end)

		it("removes the tap-to-tap gap from faster stages", function()
			expect(GameConfig.speed.tempos[2].chainGapSeconds).to.equal(0)
			expect(GameConfig.speed.tempos[3].chainGapSeconds).to.equal(0)
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

		it("uses the shared DynamicScale UI tag", function()
			expect(GameConfig.ui.dynamicScaleTag).to.equal("DynamicScale")
		end)

		it("keeps random prompt positions inside the screen", function()
			expect(GameConfig.reactionWindow.minimumScreenX > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenX < 1).to.equal(true)
			expect(GameConfig.reactionWindow.minimumScreenY > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenY < 1).to.equal(true)
		end)
	end)
end
