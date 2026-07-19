local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local React = require(Packages.React)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local e = React.createElement

local function ReactionButton(props)
	local timingScaleRef = React.useRef(nil)
	local reaction = props.reaction

	React.useEffect(function()
		local scale = timingScaleRef.current
		local timingTween
		if scale then
			local now = Workspace:GetServerTimeNow()
			local elapsedRatio = math.clamp((now - reaction.opensAt) / reaction.duration, 0, 1)
			scale.Scale = 0.42 + 0.76 * elapsedRatio
			timingTween = TweenService:Create(
				scale,
				TweenInfo.new(math.max(0.01, reaction.expiresAt - now), Enum.EasingStyle.Linear),
				{ Scale = 1.18 }
			)
			timingTween:Play()
		end

		return function()
			if timingTween then
				timingTween:Cancel()
			end
		end
	end, { reaction })

	return e("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Interactable = true,
		Position = UDim2.fromScale(reaction.screenX, reaction.screenY),
		Size = UDim2.fromOffset(132, 132),
		Text = "",
		[React.Event.Activated] = function()
			props.onSubmit(reaction.id)
		end,
	}, {
		Target = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(112, 112),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Glow = e("UIStroke", {
				Color = Color3.fromRGB(255, 225, 92),
				Thickness = 7,
				Transparency = 0.28,
			}),
		}),
		TapCore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(112, 112),
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 82, 82)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 0, 16)),
				}),
				Rotation = 90,
			}),
			Scale = e("UIScale", {
				Scale = 0.42,
				ref = timingScaleRef,
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 182, 182),
				Thickness = 3,
			}),
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = GameConfig.ui.reactionIcon,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.56, 0.56),
				ZIndex = 3,
			}),
		}),
	})
end

local function feedbackColor(text)
	if text == "PERFECT" or text == "TRIPLE PERFECT" then
		return Color3.fromRGB(255, 221, 61)
	elseif text == "EARLY" then
		return Color3.fromRGB(255, 151, 54)
	elseif text == "MISS" then
		return Color3.fromRGB(255, 72, 72)
	elseif text == "MIXED COMBO" then
		return Color3.fromRGB(255, 177, 72)
	end
	return Color3.fromRGB(255, 255, 255)
end

local function comboText(verdict)
	if verdict == "TriplePerfect" then
		return "TRIPLE PERFECT"
	elseif verdict == "TripleGood" then
		return "TRIPLE GOOD"
	end
	return "MIXED COMBO"
end

local function App(props)
	local reactions, setReactions = React.useState({})
	local reactionsRef = React.useRef({})
	local feedback, setFeedback = React.useState(nil)
	local reactionTokens = React.useRef({})
	local reactionPositions = React.useRef({})
	local feedbackToken = React.useRef(0)
	local feedbackLabelRef = React.useRef(nil)

	local function removeReaction(id)
		reactionTokens.current[id] = (reactionTokens.current[id] or 0) + 1
		if reactionsRef.current[id] then
			local nextReactions = table.clone(reactionsRef.current)
			nextReactions[id] = nil
			reactionsRef.current = nextReactions
		end
		setReactions(function(current)
			if not current[id] then
				return current
			end
			local nextReactions = table.clone(current)
			nextReactions[id] = nil
			return nextReactions
		end)
	end

	local function clearReactions()
		for id in reactionTokens.current do
			reactionTokens.current[id] = (reactionTokens.current[id] or 0) + 1
		end
		reactionsRef.current = {}
		setReactions({})
	end

	local function showFeedback(text, startX, startY, fallsToSpeedDisplay)
		feedbackToken.current += 1
		setFeedback({
			id = feedbackToken.current,
			text = text,
			startX = startX,
			startY = startY,
			fallsToSpeedDisplay = fallsToSpeedDisplay,
		})
	end

	React.useEffect(function()
		local connection = props.reactionRemote.OnClientEvent:Connect(function(payload)
			if payload.action == "show" then
				local id = payload.id
				reactionTokens.current[id] = (reactionTokens.current[id] or 0) + 1
				local token = reactionTokens.current[id]
				reactionPositions.current[id] = { x = payload.screenX, y = payload.screenY }
				local delaySeconds = math.max(0, payload.opensAt - Workspace:GetServerTimeNow())
				task.delay(delaySeconds, function()
					if reactionTokens.current[id] ~= token then
						return
					end
					local reaction = {
						id = id,
						opensAt = payload.opensAt,
						duration = payload.duration,
						expiresAt = payload.opensAt + payload.duration,
						screenX = payload.screenX,
						screenY = payload.screenY,
						obstacle = payload.obstacle == true,
					}
					local currentReactions = table.clone(reactionsRef.current)
					currentReactions[id] = reaction
					reactionsRef.current = currentReactions
					setReactions(function(current)
						local nextReactions = table.clone(current)
						nextReactions[id] = reaction
						return nextReactions
					end)
					task.delay(
						math.max(0, reaction.expiresAt - Workspace:GetServerTimeNow()),
						function()
							if reactionTokens.current[id] == token then
								removeReaction(id)
							end
						end
					)
				end)
			elseif payload.action == "remove" or payload.action == "obstacleVerdict" then
				removeReaction(payload.id)
			elseif payload.action == "result" then
				if payload.id then
					removeReaction(payload.id)
				else
					clearReactions()
				end
				local position = reactionPositions.current[payload.id] or { x = 0.5, y = 0.5 }
				showFeedback(
					string.upper(payload.verdict),
					position.x,
					position.y,
					payload.verdict == "Good" or payload.verdict == "Perfect"
				)
			elseif payload.action == "comboResult" then
				showFeedback(comboText(payload.verdict), 0.5, 0.3, false)
			else
				clearReactions()
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.reactionRemote })

	React.useEffect(function()
		if not feedback then
			return
		end

		local label = feedbackLabelRef.current
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		local speedDisplay = playerGui and playerGui:FindFirstChild("SpeedDisplay")
		local targetFrame = speedDisplay and speedDisplay:FindFirstChild("Frame")
		if not label or (feedback.fallsToSpeedDisplay and not targetFrame) then
			setFeedback(nil)
			return
		end

		local targetPosition = if targetFrame
			then targetFrame.AbsolutePosition + targetFrame.AbsoluteSize / 2
			else Vector2.zero
		local tweenGoal = if feedback.fallsToSpeedDisplay
			then {
				Position = UDim2.fromOffset(targetPosition.X, targetPosition.Y),
				Rotation = -12,
				TextTransparency = 0.15,
			}
			else {
				Position = UDim2.fromScale(feedback.startX, feedback.startY - 0.07),
				Rotation = 0,
				TextTransparency = 1,
			}
		local tween = TweenService:Create(
			label,
			TweenInfo.new(
				if feedback.fallsToSpeedDisplay then 0.62 else 0.7,
				Enum.EasingStyle.Quad,
				if feedback.fallsToSpeedDisplay
					then Enum.EasingDirection.In
					else Enum.EasingDirection.Out
			),
			tweenGoal
		)
		tween:Play()
		local connection = tween.Completed:Connect(function()
			setFeedback(function(current)
				if current and current.id == feedback.id then
					return nil
				end
				return current
			end)
		end)

		return function()
			connection:Disconnect()
			tween:Cancel()
		end
	end, { feedback })

	local function submitReaction(id)
		local reaction = reactionsRef.current[id]
		if not reaction or Workspace:GetServerTimeNow() > reaction.expiresAt then
			return
		end
		props.submitRemote:FireServer(id, Workspace:GetServerTimeNow())
		removeReaction(id)
	end

	React.useEffect(function()
		ContextActionService:BindAction("BalapKarungSubmitReaction", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				local oldestReaction = nil
				local oldestObstacleReaction = nil
				for _, reaction in reactionsRef.current do
					if not oldestReaction or reaction.opensAt < oldestReaction.opensAt then
						oldestReaction = reaction
					end
					if
						reaction.obstacle
						and (
							not oldestObstacleReaction
							or reaction.opensAt < oldestObstacleReaction.opensAt
						)
					then
						oldestObstacleReaction = reaction
					end
				end
				local targetReaction = oldestObstacleReaction or oldestReaction
				if targetReaction then
					submitReaction(targetReaction.id)
					return Enum.ContextActionResult.Sink
				end
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

		return function()
			ContextActionService:UnbindAction("BalapKarungSubmitReaction")
		end
	end, { props.submitRemote })

	local children = {
		Feedback = feedback and e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(feedback.startX, feedback.startY),
			Size = UDim2.fromOffset(300, 64),
			Text = feedback.text,
			TextColor3 = feedbackColor(feedback.text),
			TextSize = 36,
			TextStrokeTransparency = 0.4,
			ref = feedbackLabelRef,
		}) or nil,
	}
	for id, reaction in reactions do
		children[`Reaction_{id}`] = e(ReactionButton, {
			key = tostring(id),
			reaction = reaction,
			onSubmit = submitReaction,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return App
