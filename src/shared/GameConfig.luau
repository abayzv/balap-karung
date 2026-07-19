local GameConfig = {
	projectName = "BalapKarung",
	race = {
		minimumPlayers = 1,
		intermissionSeconds = 30,
		countdownSeconds = 10,
		startSignalSeconds = 0.75,
		resultsSeconds = 5,
		maximumDurationSeconds = 75,
		trackLengthStuds = 700,
		laneWidthStuds = 6,
		maximumLanes = 10,
	},
	track = {
		templatesFolderName = "Tracks",
		activeFolderName = "ActiveTrack",
		characterSpawnHeight = 3,
		tags = {
			track = "BalapKarungTrack",
			spawn = "BalapKarungSpawn",
			moveTarget = "MoveTarget",
			finish = "BalapKarungFinish",
		},
	},
	movement = {
		missRecoverySeconds = 0.65,
	},
	speed = {
		startingTier = 1,
		perfectsPerTier = 3,
		boostDurationSeconds = 3,
		verdictMultiplier = {
			Perfect = 2,
			Good = 1.5,
			Miss = 1,
		},
		tiers = {
			{
				name = "Normal",
				value = 32,
				reactionDurationSeconds = 1.2,
			},
			{
				name = "Fast",
				value = 36,
				reactionDurationSeconds = 0.95,
			},
			{
				name = "Rush",
				value = 40,
				reactionDurationSeconds = 0.75,
			},
			{
				name = "On Fire",
				value = 44,
				reactionDurationSeconds = 0.6,
			},
		},
	},
	reactionWindow = {
		perfectThresholdSeconds = 0.4,
		minimumIntervalSeconds = 2.5,
		maximumIntervalSeconds = 4,
		scheduleLeadSeconds = 0.25,
		maximumClockDifferenceSeconds = 1,
		minimumChainLength = 1,
		maximumChainLength = 3,
		chainGapSeconds = 0.35,
		minimumScreenX = 0.28,
		maximumScreenX = 0.72,
		minimumScreenY = 0.28,
		maximumScreenY = 0.82,
	},
	animations = {
		idle = "rbxassetid://92750155061995",
		walk = "rbxassetid://73682520851433",
		fall = "rbxassetid://105372185107291",
		walkPlaybackSpeedAtBase = 2,
		fallPlaybackSpeed = 1,
		hopMarkerName = "OnHop",
	},
	sounds = {
		hop = {
			soundId = "rbxassetid://132773207880485",
			volume = 0.65,
		},
		good = {
			soundId = "rbxassetid://74756140439068",
			volume = 0.75,
		},
		perfect = {
			soundId = "rbxassetid://8363346672",
			volume = 0.9,
		},
		miss = {
			soundId = "rbxassetid://112094436418581",
			volume = 0.8,
		},
	},
	ui = {
		reactionIcon = "rbxassetid://98789776453615",
	},
}

return table.freeze(GameConfig)
