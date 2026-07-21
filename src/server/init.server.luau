local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataService = require(script.DataService)
local LeaderboardService = require(script.LeaderboardService)
local OverheadService = require(script.OverheadService)
local RaceService = require(script.RaceService)
local TrailService = require(script.TrailService)

print(`[{GameConfig.projectName}] Server initialized`)

local dataService = DataService.new()
dataService:Start()
TrailService.new(dataService):Start()
OverheadService.Start()
LeaderboardService.new():Start()

local raceService = RaceService.new(dataService)
raceService:Start()
