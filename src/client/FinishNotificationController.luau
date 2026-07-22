local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoundController = require(script.Parent.SoundController)

local FinishNotificationController = {}

local function getStyle(rank)
	local styles = GameConfig.ui.finishNotification.styles
	if rank == 1 then
		return styles.First
	elseif rank == 2 then
		return styles.Second
	elseif rank == 3 then
		return styles.Third
	end
	return styles.Default
end

local function textForStyle(style, rank)
	return string.gsub(style.text, "#{rank}", tostring(rank))
end

local function setGradient(gradient, startColor, endColor)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, startColor),
		ColorSequenceKeypoint.new(1, endColor),
	})
end

local function createConfetti(screenGui, count, generation, isCurrentGeneration)
	local camera = Workspace.CurrentCamera
	if not camera or count <= 0 then
		return
	end

	local config = GameConfig.ui.finishNotification
	local viewport = camera.ViewportSize
	local random = Random.new(math.floor(Workspace:GetServerTimeNow() * 1000) % 2147483647)
	local layer = Instance.new("Frame")
	layer.Name = "ConfettiLayer"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 20
	layer.Parent = screenGui

	local particles = {}
	for index = 1, count do
		local fromLeft = index % 2 == 0
		local size = random:NextInteger(6, 11)
		local particle = Instance.new("Frame")
		particle.Name = "Confetti"
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundColor3 =
			config.confettiColors[random:NextInteger(1, #config.confettiColors)]
		particle.BorderSizePixel = 0
		particle.Size = UDim2.fromOffset(size, random:NextInteger(10, 19))
		particle.ZIndex = 20
		particle.Parent = layer

		local startX = if fromLeft
			then viewport.X * random:NextNumber(0.06, 0.17)
			else viewport.X * random:NextNumber(0.83, 0.94)
		local startY = viewport.Y * random:NextNumber(0.55, 0.76)
		table.insert(particles, {
			frame = particle,
			position = Vector2.new(startX, startY),
			velocity = Vector2.new(
				(if fromLeft then 1 else -1) * random:NextNumber(170, 430),
				-random:NextNumber(430, 760)
			),
			rotation = random:NextNumber(0, 360),
			angularVelocity = random:NextNumber(-520, 520),
			drag = random:NextNumber(0.91, 0.98),
		})
	end

	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not isCurrentGeneration(generation) then
			connection:Disconnect()
			layer:Destroy()
			return
		end

		elapsed += deltaTime
		for _, particle in particles do
			particle.velocity = Vector2.new(
				particle.velocity.X * math.pow(particle.drag, deltaTime * 60),
				particle.velocity.Y + 900 * deltaTime
			)
			particle.position += particle.velocity * deltaTime
			particle.rotation += particle.angularVelocity * deltaTime
			particle.frame.Position = UDim2.fromOffset(particle.position.X, particle.position.Y)
			particle.frame.Rotation = particle.rotation
		end

		if elapsed >= config.confettiLifetimeSeconds then
			connection:Disconnect()
			layer:Destroy()
		end
	end)
end

function FinishNotificationController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:WaitForChild("FinishNotification")
	local main = screenGui:WaitForChild("Main")
	local inside = main:WaitForChild("Inside")
	local scale = inside:WaitForChild("UIScale")
	local label = inside:WaitForChild("Top"):WaitForChild("EnchantLabel")
	local gradient = label:WaitForChild("UIGradient")
	local vignette = screenGui:WaitForChild("Vignette")
	local config = GameConfig.ui.finishNotification
	local baseScale = scale.Scale
	local baseVignetteTransparency = vignette.ImageTransparency
	local generation = 0
	local activeTweens = {}

	local function cancelTweens()
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end

	local function tween(instance, info, goal)
		local result = TweenService:Create(instance, info, goal)
		table.insert(activeTweens, result)
		result:Play()
		return result
	end

	local function hide()
		generation += 1
		cancelTweens()
		screenGui.Enabled = false
		scale.Scale = baseScale
		label.TextTransparency = 0
		vignette.ImageTransparency = baseVignetteTransparency
		local confetti = screenGui:FindFirstChild("ConfettiLayer")
		if confetti then
			confetti:Destroy()
		end
	end

	local function show()
		local rank = player:GetAttribute("Rank") or 0
		if rank <= 0 then
			return
		end

		generation += 1
		local currentGeneration = generation
		cancelTweens()
		screenGui.Enabled = true
		label.Text = config.impactText
		label.TextTransparency = 0
		setGradient(gradient, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 222, 63))
		gradient.Offset = Vector2.new(-1, 0)
		scale.Scale = baseScale * 0.28
		vignette.ImageTransparency = 1
		SoundController.Play("finish")

		tween(
			scale,
			TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = baseScale * 1.08 }
		)
		tween(
			vignette,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = baseVignetteTransparency }
		)

		task.delay(config.revealDelaySeconds, function()
			if currentGeneration ~= generation then
				return
			end
			local style = getStyle(rank)
			label.Text = textForStyle(style, rank)
			setGradient(gradient, style.gradientStart, style.gradientEnd)
			gradient.Offset = Vector2.new(-1, 0)
			scale.Scale = baseScale * 0.62
			tween(
				scale,
				TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = baseScale }
			)
			tween(
				gradient,
				TweenInfo.new(0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Offset = Vector2.new(1, 0) }
			)
			createConfetti(screenGui, style.confettiCount, currentGeneration, function(value)
				return value == generation
			end)
		end)

		task.delay(config.displaySeconds, function()
			if currentGeneration ~= generation then
				return
			end
			tween(
				scale,
				TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Scale = baseScale * 0.35 }
			)
			tween(
				label,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			)
			local vignetteTween = tween(
				vignette,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ ImageTransparency = 1 }
			)
			vignetteTween.Completed:Once(function()
				if currentGeneration == generation then
					screenGui.Enabled = false
				end
			end)
		end)
	end

	screenGui.Enabled = false
	player:GetAttributeChangedSignal("RaceStatus"):Connect(function()
		if player:GetAttribute("RaceStatus") == "Finished" then
			show()
		elseif player:GetAttribute("IsRace") ~= true then
			hide()
		end
	end)
end

return FinishNotificationController
