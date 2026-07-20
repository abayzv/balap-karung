local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoundController = require(script.Parent.SoundController)

local SkillNotificationController = {}

local function offsetPosition(position, offsetY)
	return UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale,
		position.Y.Offset + offsetY
	)
end

function SkillNotificationController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:WaitForChild("SkillNotification")
	local container = screenGui:WaitForChild("Frame")
	local config = GameConfig.ui.skillNotification
	local restingPosition = container.Position
	local cards = {}
	local cardTokens = {}
	local rootTween = nil
	local rootGeneration = 0

	for skillId, skillConfig in config.skills do
		local card = container:WaitForChild(skillConfig.frameName)
		local scale = card:FindFirstChild("SkillNotificationScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "SkillNotificationScale"
			scale.Parent = card
		end
		scale.Scale = 1
		card.Visible = false
		cards[skillId] = {
			frame = card,
			scale = scale,
		}
	end
	screenGui.Enabled = false

	local function hasVisibleCard()
		for _, card in cards do
			if card.frame.Visible then
				return true
			end
		end
		return false
	end

	local function slideContainerIn()
		rootGeneration += 1
		if rootTween then
			rootTween:Cancel()
		end
		screenGui.Enabled = true
		container.Position = offsetPosition(restingPosition, config.entryOffsetY)
		rootTween = TweenService:Create(
			container,
			TweenInfo.new(config.entrySeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = restingPosition }
		)
		rootTween:Play()
	end

	local function slideContainerOut()
		rootGeneration += 1
		local generation = rootGeneration
		if rootTween then
			rootTween:Cancel()
		end
		rootTween = TweenService:Create(
			container,
			TweenInfo.new(config.exitSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = offsetPosition(restingPosition, config.exitOffsetY) }
		)
		rootTween:Play()
		rootTween.Completed:Once(function()
			if generation == rootGeneration and not hasVisibleCard() then
				screenGui.Enabled = false
				container.Position = restingPosition
			end
		end)
	end

	local function show(skillId)
		local skillConfig = config.skills[skillId]
		local card = cards[skillId]
		if not skillConfig or not card then
			return
		end

		cardTokens[skillId] = (cardTokens[skillId] or 0) + 1
		local token = cardTokens[skillId]
		local wasVisible = hasVisibleCard()
		card.frame.Visible = true
		card.scale.Scale = 0.72
		if not wasVisible then
			slideContainerIn()
		end

		if skillConfig.soundName and not skillConfig.soundHandledExternally then
			SoundController.Play(skillConfig.soundName)
		end

		local popTween = TweenService:Create(
			card.scale,
			TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.06 }
		)
		popTween:Play()
		popTween.Completed:Once(function()
			if cardTokens[skillId] ~= token then
				return
			end
			TweenService:Create(
				card.scale,
				TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)

		task.delay(config.displaySeconds, function()
			if cardTokens[skillId] ~= token then
				return
			end
			local dismissTween = TweenService:Create(
				card.scale,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.82 }
			)
			dismissTween:Play()
			dismissTween.Completed:Once(function()
				if cardTokens[skillId] ~= token then
					return
				end
				card.frame.Visible = false
				card.scale.Scale = 1
				if not hasVisibleCard() then
					slideContainerOut()
				end
			end)
		end)
	end

	for skillId, skillConfig in config.skills do
		player:GetAttributeChangedSignal(skillConfig.triggerAttribute):Connect(function()
			if player:GetAttribute(skillConfig.triggerAttribute) == true then
				show(skillId)
			end
		end)
	end
end

return SkillNotificationController
