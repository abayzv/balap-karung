return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

	describe("GameConfig", function()
		it("configures the track test-mode bypass", function()
			expect(type(GameConfig.TEST_MODE)).to.equal("boolean")
			expect(type(GameConfig.TEST_TRACK_ID)).to.equal("string")
			expect(GameConfig.TEST_TRACK_ID ~= "").to.equal(true)
			expect(GameConfig.TEST_COUNTDOWN).to.equal(5)
		end)

		it("uses the BalapKarung project name", function()
			expect(GameConfig.projectName).to.equal("BalapKarung")
		end)

		it("configures grind-friendly placement coin rewards", function()
			expect(GameConfig.economy.minimumValidInputsForReward).to.equal(3)
			expect(GameConfig.economy.coinRewards[1]).to.equal(15)
			expect(GameConfig.economy.coinRewards[2]).to.equal(10)
			expect(GameConfig.economy.coinRewards[3]).to.equal(7)
			expect(GameConfig.economy.coinRewards.default).to.equal(3)
		end)

		it("configures cached world leaderboards", function()
			expect(GameConfig.leaderboard.modelTag).to.equal("Leaderboard")
			expect(GameConfig.leaderboard.viewTag).to.equal("LeaderboardView")
			expect(GameConfig.leaderboard.avatarTag).to.equal("LeaderboardAvatar")
			expect(GameConfig.leaderboard.avatarAnimationId).to.be.ok()
			expect(GameConfig.leaderboard.minimumRefreshGapSeconds > 0).to.equal(true)
			expect(GameConfig.leaderboard.refreshIntervalSeconds >= 30).to.equal(true)
			expect(GameConfig.leaderboard.writeIntervalSeconds >= 60).to.equal(true)
			expect(GameConfig.leaderboard.initialWriteDelaySeconds >= 10).to.equal(true)
			expect(GameConfig.leaderboard.minimumValue).to.equal(1)
		end)

		it("configures lightweight client leaf ambience", function()
			expect(GameConfig.environmentVfx.leaf.enabled).to.equal(true)
			expect(GameConfig.environmentVfx.leaf.templateName).to.equal("Leaf Particle ")
			expect(GameConfig.environmentVfx.leaf.spawnRate <= 10).to.equal(true)
			expect(GameConfig.environmentVfx.leaf.maximumDistance).to.equal(60)
			expect(GameConfig.environmentVfx.leaf.windSpeed).to.equal(20)
			expect(GameConfig.environmentVfx.leaf.windPower).to.equal(0.5)
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
			expect(GameConfig.race.finishCelebrationSeconds).to.equal(5)
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
			expect(GameConfig.speed.tempos[1].maximumIntervalSeconds <= 1.05).to.equal(true)
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

		it("gives On Fire a finite duration", function()
			expect(GameConfig.speed.onFireDurationSeconds).to.equal(2)
		end)

		it("configures a staggered triple-tap obstacle combo", function()
			expect(GameConfig.obstacle.tag).to.equal("TapBarrier")
			expect(GameConfig.obstacle.tapCount).to.equal(3)
			expect(GameConfig.obstacle.promptSpawnGapSeconds > 0).to.equal(true)
			expect(
				GameConfig.obstacle.promptSpawnGapSeconds
					< GameConfig.obstacle.reactionDurationSeconds
			).to.equal(true)
			expect(
				GameConfig.obstacle.comboMultiplier.TriplePerfect
					> GameConfig.obstacle.comboMultiplier.Mixed
			).to.equal(true)
			expect(
				GameConfig.obstacle.comboMultiplier.Mixed
					> GameConfig.obstacle.comboMultiplier.TripleGood
			).to.equal(true)
		end)

		it("leaves a quiet window before an obstacle prompt", function()
			expect(GameConfig.obstacle.normalPromptBufferSeconds).to.equal(0.25)
			expect(GameConfig.obstacle.promptSuppressionPollSeconds > 0).to.equal(true)
		end)

		it("configures a physical guard impact", function()
			expect(GameConfig.obstacle.guardRaycastDistanceStuds > 0).to.equal(true)
			expect(GameConfig.obstacle.guardServerValidationDistanceStuds > 0).to.equal(true)
			expect(GameConfig.obstacle.guardCrashLeadStuds > 0).to.equal(true)
			expect(GameConfig.obstacle.characterCrashHitboxSize.Magnitude > 0).to.equal(true)
			expect(GameConfig.obstacle.guardThrowHorizontalSpeed > 0).to.equal(true)
			expect(GameConfig.obstacle.guardThrowVerticalSpeed > 0).to.equal(true)
			expect(GameConfig.sounds.guardSwing.soundId ~= "").to.equal(true)
		end)

		it("configures lane-specific chained Breaker zones", function()
			expect(GameConfig.breaker.zoneTag).to.equal("BreakerZone")
			expect(GameConfig.breaker.obstacleTag).to.equal("BreakerObstacle")
			expect(GameConfig.breaker.skillId).to.equal("Breaker")
			expect(GameConfig.breaker.reactionDurationSeconds > 0).to.equal(true)
			expect(GameConfig.breaker.promptLeadSeconds > 0).to.equal(true)
			expect(
				GameConfig.breaker.minimumObstacleSpacingStuds
					< GameConfig.breaker.maximumObstacleSpacingStuds
			).to.equal(true)
			expect(GameConfig.breaker.serverValidationDistanceStuds > 0).to.equal(true)
			expect(GameConfig.breaker.debrisSpreadRandomness > 0).to.equal(true)
			expect(GameConfig.sounds.breakerImpact.soundId ~= "").to.equal(true)
		end)

		it("configures recurring Lava track waves", function()
			expect(GameConfig.lavaWave.trackId).to.equal("Lava")
			expect(GameConfig.lavaWave.speedStudsPerSecond > GameConfig.speed.normalValue).to.equal(
				true
			)
			expect(GameConfig.lavaWave.minimumIntervalSeconds > 0).to.equal(true)
			expect(
				GameConfig.lavaWave.maximumIntervalSeconds
					>= GameConfig.lavaWave.minimumIntervalSeconds
			).to.equal(true)
			expect(GameConfig.ui.tapSkills.LavaJump.label).to.equal("Jump")
			expect(#GameConfig.lavaWave.variants).to.equal(3)
			expect(GameConfig.lavaWave.variants[3].waveCount).to.equal(2)
		end)

		it("keeps the temporary Good and Perfect speed boosts", function()
			expect(GameConfig.speed.verdictMultiplier.Good).to.equal(1.5)
			expect(GameConfig.speed.verdictMultiplier.Perfect).to.equal(2)
			expect(GameConfig.speed.verdictBoostDurationSeconds.Good).to.equal(1.2)
			expect(GameConfig.speed.verdictBoostDurationSeconds.Perfect).to.equal(1.7)
			expect(
				GameConfig.speed.verdictBoostDurationSeconds.Perfect
					> GameConfig.speed.verdictBoostDurationSeconds.Good
			).to.equal(true)
		end)

		it("quickly resumes normal prompts after a failed Guard", function()
			expect(GameConfig.obstacle.failedGuardPromptResumeSeconds).to.equal(0.75)
			expect(
				GameConfig.obstacle.failedGuardPromptResumeSeconds
					> GameConfig.movement.missRecoverySeconds
			).to.equal(true)
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

		it("configures the hop debris and Guard shield templates", function()
			expect(GameConfig.effects.hopDebrisTemplateName).to.equal("Debris")
			expect(GameConfig.effects.guardShieldTemplateName).to.equal("Shield")
			expect(GameConfig.effects.hopDebrisDefaultEmitCount > 0).to.equal(true)
			expect(GameConfig.effects.guardShieldActivationEmitCount > 0).to.equal(true)
			expect(GameConfig.effects.breakerExplosionTemplateName).to.equal("Explosion")
			expect(GameConfig.effects.breakerExplosionDefaultEmitCount > 0).to.equal(true)
			expect(GameConfig.effects.breakerExplosionCleanupPaddingSeconds > 0).to.equal(true)
		end)

		it("configures three exact R15 sack sizes", function()
			expect(GameConfig.sack.templateName).to.equal("KarungModel")
			expect(GameConfig.sack.partName).to.equal("Karung")
			expect(#GameConfig.sack.sizeClasses).to.equal(3)
			expect(GameConfig.sack.sizeClasses[1].name).to.equal("Short")
			expect(GameConfig.sack.sizeClasses[2].name).to.equal("Standard")
			expect(GameConfig.sack.sizeClasses[3].name).to.equal("Tall")
			expect(GameConfig.sack.sizeClasses[1].maximumHipHeight).to.equal(1.81)
			expect(GameConfig.sack.sizeClasses[2].maximumHipHeight).to.equal(3.4)
			for _, sizeClass in GameConfig.sack.sizeClasses do
				expect(sizeClass.size.Magnitude > 0).to.equal(true)
				expect(typeof(sizeClass.mountOffset)).to.equal("Vector3")
			end
			expect(type(GameConfig.sack.originalTransparencyAttribute)).to.equal("string")
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

		it("configures placement-aware finish feedback", function()
			expect(GameConfig.sounds.finish.soundId).to.equal("rbxassetid://6370660283")
			expect(GameConfig.sounds.raceCountdown.soundId).to.equal("rbxassetid://100324658979992")
			expect(
				string.find(GameConfig.sounds.resultsCinematic.soundId, "rbxassetid://", 1, true)
			).to.equal(1)
			local finish = GameConfig.ui.finishNotification
			expect(finish.styles.First.confettiCount > finish.styles.Second.confettiCount).to.equal(
				true
			)
			expect(finish.styles.Second.confettiCount > finish.styles.Third.confettiCount).to.equal(
				true
			)
			expect(finish.styles.Third.confettiCount > finish.styles.Default.confettiCount).to.equal(
				true
			)
		end)

		it("configures the static podium cinematic", function()
			local podium = GameConfig.ui.podiumCinematic
			expect(podium.templateName).to.equal("Cinematics")
			expect(podium.localSceneName).to.equal("LocalPodiumCinematic")
			expect(podium.cameraTag).to.equal("PodiumCamera")
			expect(podium.titles.First).to.equal("JUARA!")
			expect(podium.avatarHeightScale > 0).to.equal(true)
			expect(podium.avatarStrokeThickness > 0).to.equal(true)
		end)

		it("configures attribute-driven skill notifications", function()
			local notification = GameConfig.ui.skillNotification
			expect(notification.displaySeconds > 0).to.equal(true)
			expect(notification.skills.OnFire.triggerAttribute).to.equal("OnFire")
			expect(notification.skills.OnFire.soundName).to.equal("onFireReady")
			expect(notification.skills.Guard.triggerAttribute).to.equal("GuardReady")
			expect(notification.skills.Breaker.triggerAttribute).to.equal("BreakerActive")
			expect(notification.skills.Breaker.frameName).to.equal("Breaker")
			for _, skillId in { "OnFire", "Guard", "Breaker" } do
				local skill = notification.skills[skillId]
				expect(type(skill.frameName)).to.equal("string")
				expect(GameConfig.sounds[skill.soundName] ~= nil).to.equal(true)
			end
		end)

		it("configures scalable Jump, Guard, and Breaker tap skills", function()
			expect(GameConfig.reactionWindow.skillId).to.equal("Jump")
			expect(GameConfig.obstacle.skillId).to.equal("Guard")
			expect(GameConfig.breaker.skillId).to.equal("Breaker")
			for _, skillId in { "Jump", "Guard", "Breaker" } do
				local skill = GameConfig.ui.tapSkills[skillId]
				expect(skill ~= nil).to.equal(true)
				expect(type(skill.label)).to.equal("string")
				expect(string.find(skill.icon, "rbxassetid://", 1, true) == 1).to.equal(true)
				expect(typeof(skill.gradientStart)).to.equal("Color3")
				expect(typeof(skill.gradientEnd)).to.equal("Color3")
			end
		end)

		it("uses the shared DynamicScale UI tag", function()
			expect(GameConfig.ui.dynamicScaleTag).to.equal("DynamicScale")
		end)

		it("disables verdict feedback strokes", function()
			expect(GameConfig.ui.feedback.strokeEnabled).to.equal(false)
		end)

		it("keeps random prompt positions inside the screen", function()
			expect(GameConfig.reactionWindow.minimumScreenX > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenX < 1).to.equal(true)
			expect(GameConfig.reactionWindow.minimumScreenY > 0).to.equal(true)
			expect(GameConfig.reactionWindow.maximumScreenY < 1).to.equal(true)
		end)
	end)
end
