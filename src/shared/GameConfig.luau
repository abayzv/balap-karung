local GameConfig = {
	projectName = "BalapKarung",
	momentum = {
		minimum = 0,
		maximum = 100,
		starting = 30,
	},
	reactionWindow = {
		durationSeconds = 1.5,
		perfectThresholdSeconds = 0.4,
	},
}

return table.freeze(GameConfig)
