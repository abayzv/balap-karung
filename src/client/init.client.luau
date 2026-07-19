local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.App)
local CharacterAnimationController = require(script.CharacterAnimationController)
local DynamicScaleController = require(script.DynamicScaleController)
local GuardController = require(script.GuardController)
local LobbyTimerController = require(script.LobbyTimerController)
local OnFireController = require(script.OnFireController)
local RaceTimerController = require(script.RaceTimerController)
local RaceJumpController = require(script.RaceJumpController)
local RaceTrackerController = require(script.RaceTrackerController)
local SoundController = require(script.SoundController)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local reactionRemote = remotes:WaitForChild("ReactionWindow")

print(`[{GameConfig.projectName}] Client initialized`)

SoundController.Start(reactionRemote)
GuardController.Start(
	remotes:WaitForChild("SubmitGuardImpact"),
	remotes:WaitForChild("GuardImpact"),
	remotes:WaitForChild("SubmitObstacleCrash")
)
CharacterAnimationController.Start()
DynamicScaleController.Start()
LobbyTimerController.Start()
OnFireController.Start()
RaceTimerController.Start()
RaceJumpController.Start()
RaceTrackerController.Start()

local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BalapKarungUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)
root:render(React.createElement(App, {
	reactionRemote = reactionRemote,
	submitRemote = remotes:WaitForChild("SubmitReaction"),
}))
