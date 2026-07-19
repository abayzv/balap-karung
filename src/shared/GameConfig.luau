local GameConfig = {
	projectName = "BalapKarung",
	race = {
		minimumPlayers = 2,
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
	queue = {
		startPartTag = "StartPart",
		scanIntervalSeconds = 0.1,
	},
	movement = {
		missRecoverySeconds = 0.65,
	},
	speed = {
		normalValue = 32,
		onFireValue = 44,
		boostDurationSeconds = 3,
		verdictMultiplier = {
			Perfect = 2,
			Good = 1.5,
			Early = 1,
			Miss = 1,
		},
		fastTempoRequiredHits = 3,
		onFireRequiredHits = 5,
		tempos = {
			{
				reactionDurationSeconds = 1.2,
				minimumIntervalSeconds = 2.5,
				maximumIntervalSeconds = 4,
				chainGapSeconds = 0.35,
			},
			{
				reactionDurationSeconds = 1.05,
				minimumIntervalSeconds = 1.8,
				maximumIntervalSeconds = 2.8,
				chainGapSeconds = 0,
			},
			{
				reactionDurationSeconds = 0.95,
				minimumIntervalSeconds = 1.1,
				maximumIntervalSeconds = 1.8,
				chainGapSeconds = 0,
			},
		},
		onFireCamera = {
			normalFieldOfView = 70,
			fieldOfView = 88,
			transitionSeconds = 0.85,
		},
	},
	reactionWindow = {
		earlyEndRatio = 0.55,
		perfectStartRatio = 0.7,
		perfectEndRatio = 0.85,
		scheduleLeadSeconds = 0.25,
		maximumClockDifferenceSeconds = 1,
		minimumChainLength = 1,
		maximumChainLength = 3,
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
		backgroundMusic = {
			soundId = "rbxassetid://108881053322600",
			volume = 0.35,
		},
		hop = {
			soundId = "rbxassetid://129472345262950",
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
		onFireEnter = {
			soundId = "rbxassetid://130422645188028",
			volume = 0.9,
		},
		onFireLoop = {
			soundId = "rbxassetid://82555625627924",
			volume = 0.65,
		},
	},
	ui = {
		reactionIcon = "rbxassetid://98789776453615",
		dynamicScaleTag = "DynamicScale",
	},
}

return table.freeze(GameConfig)
