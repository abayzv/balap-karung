local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RaceService = require(script.RaceService)

print(`[{GameConfig.projectName}] Server initialized`)

local raceService = RaceService.new()
raceService:Start()
