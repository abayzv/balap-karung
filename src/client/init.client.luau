local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.App)
local CharacterAnimationController = require(script.CharacterAnimationController)
local DynamicScaleController = require(script.DynamicScaleController)
local FinishNotificationController = require(script.FinishNotificationController)
local GuardController = require(script.GuardController)
local LobbyTimerController = require(script.LobbyTimerController)
local OnFireController = require(script.OnFireController)
local PodiumCinematicController = require(script.PodiumCinematicController)
local RaceTimerController = require(script.RaceTimerController)
local RaceJumpController = require(script.RaceJumpController)
local RaceTrackerController = require(script.RaceTrackerController)
local SkillNotificationController = require(script.SkillNotificationController)
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
FinishNotificationController.Start()
LobbyTimerController.Start()
OnFireController.Start()
PodiumCinematicController.Start(remotes:WaitForChild("PodiumResults"), SoundController)
RaceTimerController.Start(SoundController)
RaceJumpController.Start()
RaceTrackerController.Start()
SkillNotificationController.Start()

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
