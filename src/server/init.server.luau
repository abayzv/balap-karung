local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataService = require(script.DataService)
local OverheadService = require(script.OverheadService)
local RaceService = require(script.RaceService)

print(`[{GameConfig.projectName}] Server initialized`)

local dataService = DataService.new()
dataService:Start()
OverheadService.Start()

local raceService = RaceService.new(dataService)
raceService:Start()
