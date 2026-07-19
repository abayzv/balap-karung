local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local React = require(Packages.React)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local e = React.createElement

local function App(props)
	local reaction, setReaction = React.useState(nil)
	local feedback, setFeedback = React.useState(nil)
	local reactionToken = React.useRef(0)
	local feedbackToken = React.useRef(0)
	local lastReactionPosition = React.useRef({ x = 0.5, y = 0.5 })
	local timingScaleRef = React.useRef(nil)
	local feedbackLabelRef = React.useRef(nil)

	React.useEffect(function()
		local connection = props.reactionRemote.OnClientEvent:Connect(function(payload)
			reactionToken.current += 1
			local token = reactionToken.current

			if payload.action == "show" then
				lastReactionPosition.current = {
					x = payload.screenX,
					y = payload.screenY,
				}
				local delaySeconds = math.max(0, payload.opensAt - Workspace:GetServerTimeNow())
				task.delay(delaySeconds, function()
					if reactionToken.current ~= token then
						return
					end

					setReaction({
						id = payload.id,
						opensAt = payload.opensAt,
						duration = payload.duration,
						expiresAt = payload.opensAt + payload.duration,
						chainIndex = payload.chainIndex,
						chainLength = payload.chainLength,
						screenX = payload.screenX,
						screenY = payload.screenY,
					})

					local remainingDuration = math.max(
						0,
						payload.opensAt + payload.duration - Workspace:GetServerTimeNow()
					)
					task.delay(remainingDuration, function()
						if reactionToken.current == token then
							setReaction(function()
								return nil
							end)
						end
					end)
				end)
			elseif payload.action == "result" then
				setReaction(nil)
				feedbackToken.current += 1
				setFeedback({
					id = feedbackToken.current,
					text = string.upper(payload.verdict),
					startX = lastReactionPosition.current.x,
					startY = lastReactionPosition.current.y,
					fallsToSpeedDisplay = payload.verdict == "Good" or payload.verdict == "Perfect",
				})
			else
				setReaction(function()
					return nil
				end)
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
				if feedback.fallsToSpeedDisplay then 0.62 else 0.45,
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

	React.useEffect(function()
		if not reaction then
			return
		end

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

	local function submitReaction()
		if not reaction or Workspace:GetServerTimeNow() > reaction.expiresAt then
			return
		end

		reactionToken.current += 1
		props.submitRemote:FireServer(reaction.id, Workspace:GetServerTimeNow())
		setReaction(nil)
	end

	React.useEffect(function()
		if not reaction then
			ContextActionService:UnbindAction("BalapKarungSubmitReaction")
			return
		end

		ContextActionService:BindAction("BalapKarungSubmitReaction", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				submitReaction()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

		return function()
			ContextActionService:UnbindAction("BalapKarungSubmitReaction")
		end
	end, { reaction })

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Feedback = feedback and e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(feedback.startX, feedback.startY),
			Size = UDim2.fromOffset(220, 64),
			Text = feedback.text,
			TextColor3 = if feedback.text == "PERFECT"
				then Color3.fromRGB(255, 221, 61)
				elseif feedback.text == "EARLY" then Color3.fromRGB(255, 151, 54)
				elseif feedback.text == "MISS" then Color3.fromRGB(255, 72, 72)
				else Color3.fromRGB(255, 255, 255),
			TextSize = 36,
			TextStrokeTransparency = 0.4,
			ref = feedbackLabelRef,
		}) or nil,
		Reaction = reaction and e("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Interactable = true,
			Position = UDim2.fromScale(reaction.screenX, reaction.screenY),
			Rotation = 0,
			Size = UDim2.fromOffset(132, 132),
			Text = "",
			key = tostring(reaction.id),
			[React.Event.Activated] = submitReaction,
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
		}) or nil,
	})
end

return App
