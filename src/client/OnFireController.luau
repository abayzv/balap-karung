local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local OnFireController = {}

local function createEdge(parent, name, size, position, transparency)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.BackgroundColor3 = Color3.fromRGB(255, 58, 12)
	edge.BackgroundTransparency = 0.45
	edge.BorderSizePixel = 0
	edge.Position = position
	edge.Size = size
	edge.Parent = parent

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 32, 8), Color3.fromRGB(255, 170, 28))
	gradient.Transparency = transparency
	gradient.Parent = edge
	return gradient
end

local function createVignette(playerGui)
	local existing = playerGui:FindFirstChild("BalapKarungOnFireEffects")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BalapKarungOnFireEffects"
	screenGui.DisplayOrder = 9000
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local group = Instance.new("CanvasGroup")
	group.Name = "FireVignette"
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Visible = false
	group.Parent = screenGui

	local transparentToFire = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	local fireToTransparent = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})

	local top = createEdge(
		group,
		"TopFire",
		UDim2.fromScale(1, 0.08),
		UDim2.fromScale(0, 0),
		fireToTransparent
	)
	top.Rotation = 90
	local bottom = createEdge(
		group,
		"BottomFire",
		UDim2.fromScale(1, 0.1),
		UDim2.fromScale(0, 0.9),
		transparentToFire
	)
	bottom.Rotation = 90
	createEdge(
		group,
		"LeftFire",
		UDim2.fromScale(0.05, 1),
		UDim2.fromScale(0, 0),
		fireToTransparent
	)
	createEdge(
		group,
		"RightFire",
		UDim2.fromScale(0.05, 1),
		UDim2.fromScale(0.95, 0),
		transparentToFire
	)

	return group
end

local function transparencyForProgress(progressRatio)
	if progressRatio <= 0 then
		return NumberSequence.new(0)
	elseif progressRatio >= 1 then
		return NumberSequence.new(1)
	end

	local edge = math.min(0.015, (1 - progressRatio) / 2)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(progressRatio, 1),
		NumberSequenceKeypoint.new(progressRatio + edge, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
end

function OnFireController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local fillValue = Instance.new("NumberValue")
	local fillTween = nil
	local onFireDrainTween = nil
	local fillGradient = nil
	local displayGui = nil
	local displayFrame = nil
	local displayScale = nil
	local baseDisplayScale = 1
	local displayPulse = nil
	local cameraTween = nil
	local vignettePulse = nil
	local effectWasOnFire = false

	local vignette = createVignette(playerGui)

	local function renderFill()
		if not fillGradient then
			return
		end
		local ratio = math.clamp(fillValue.Value / GameConfig.speed.onFireRequiredHits, 0, 1)
		fillGradient.Transparency = transparencyForProgress(ratio)
	end

	fillValue.Changed:Connect(renderFill)

	local function tweenProgress()
		if player:GetAttribute("OnFire") == true then
			return
		end
		if fillTween then
			fillTween:Cancel()
		end
		local progress = player:GetAttribute("OnFireProgress") or 0
		fillTween = TweenService:Create(
			fillValue,
			TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Value = progress }
		)
		fillTween:Play()
	end

	local function attachDisplay(gui)
		displayGui = gui
		local frame = gui:WaitForChild("Frame")
		displayFrame = frame
		local overlay = frame:WaitForChild("OnfireOverlay")
		displayScale = frame:FindFirstChildOfClass("UIScale")
		if displayScale then
			baseDisplayScale = displayScale.Scale
		end
		fillGradient = overlay:FindFirstChild("OnFireFillGradient")
		if not fillGradient then
			fillGradient = Instance.new("UIGradient")
			fillGradient.Name = "OnFireFillGradient"
			fillGradient.Rotation = 0
			fillGradient.Parent = overlay
		end
		local isRace = player:GetAttribute("IsRace") == true
		displayGui.Enabled = isRace
		displayFrame.Visible = isRace
		renderFill()
	end

	local function applyOnFire()
		local onFire = player:GetAttribute("OnFire") == true
		local camera = Workspace.CurrentCamera
		local cameraConfig = GameConfig.speed.onFireCamera
		if onFire and not effectWasOnFire and displayScale then
			baseDisplayScale = displayScale.Scale
		end
		effectWasOnFire = onFire

		if cameraTween then
			cameraTween:Cancel()
		end
		if camera then
			cameraTween = TweenService:Create(
				camera,
				TweenInfo.new(
					cameraConfig.transitionSeconds,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				),
				{
					FieldOfView = if onFire
						then cameraConfig.fieldOfView
						else cameraConfig.normalFieldOfView,
				}
			)
			cameraTween:Play()
		end

		if displayPulse then
			displayPulse:Cancel()
			displayPulse = nil
		end
		if vignettePulse then
			vignettePulse:Cancel()
			vignettePulse = nil
		end
		if onFireDrainTween then
			onFireDrainTween:Cancel()
			onFireDrainTween = nil
		end

		if onFire then
			if fillTween then
				fillTween:Cancel()
			end
			fillValue.Value = GameConfig.speed.onFireRequiredHits
			local remainingDuration = math.max(
				0.01,
				(player:GetAttribute("OnFireEndsAt") or 0) - Workspace:GetServerTimeNow()
			)
			onFireDrainTween = TweenService:Create(
				fillValue,
				TweenInfo.new(remainingDuration, Enum.EasingStyle.Linear),
				{ Value = 0 }
			)
			onFireDrainTween:Play()
			vignette.Visible = true
			vignette.GroupTransparency = 0.68
			vignettePulse = TweenService:Create(
				vignette,
				TweenInfo.new(0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ GroupTransparency = 0.8 }
			)
			vignettePulse:Play()
			if displayScale then
				displayScale.Scale = baseDisplayScale
				displayPulse = TweenService:Create(
					displayScale,
					TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = baseDisplayScale * 1.06 }
				)
				displayPulse:Play()
			end
		else
			tweenProgress()
			vignette.Visible = false
			vignette.GroupTransparency = 1
			if displayScale then
				displayScale.Scale = baseDisplayScale
			end
		end
	end

	local function updateVisibility()
		local isRace = player:GetAttribute("IsRace") == true
		if displayGui then
			displayGui.Enabled = isRace
		end
		if displayFrame then
			displayFrame.Visible = isRace
		end
	end

	player:GetAttributeChangedSignal("OnFireProgress"):Connect(tweenProgress)
	player:GetAttributeChangedSignal("OnFire"):Connect(applyOnFire)
	player:GetAttributeChangedSignal("IsRace"):Connect(updateVisibility)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyOnFire)
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "SpeedDisplay" then
			attachDisplay(child)
			applyOnFire()
		end
	end)

	local existingDisplay = playerGui:FindFirstChild("SpeedDisplay")
	if existingDisplay then
		attachDisplay(existingDisplay)
	end
	fillValue.Value = player:GetAttribute("OnFireProgress") or 0
	applyOnFire()
end

return OnFireController
