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
	local buttonScaleRef = React.useRef(nil)
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
				if payload.verdict == "Good" or payload.verdict == "Perfect" then
					feedbackToken.current += 1
					setFeedback({
						id = feedbackToken.current,
						text = string.upper(payload.verdict),
						startX = lastReactionPosition.current.x,
						startY = lastReactionPosition.current.y,
					})
				end
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
		if not label or not targetFrame then
			setFeedback(nil)
			return
		end

		local targetPosition = targetFrame.AbsolutePosition + targetFrame.AbsoluteSize / 2
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromOffset(targetPosition.X, targetPosition.Y),
				Rotation = -12,
				TextTransparency = 0.15,
			}
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

		local scale = buttonScaleRef.current
		local popTween
		local pulseTween
		local popConnection

		if scale then
			scale.Scale = 0.72
			popTween = TweenService:Create(
				scale,
				TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			popTween:Play()
			popConnection = popTween.Completed:Connect(function(playbackState)
				if playbackState ~= Enum.PlaybackState.Completed then
					return
				end
				pulseTween = TweenService:Create(
					scale,
					TweenInfo.new(0.46, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.055 }
				)
				pulseTween:Play()
			end)
		end

		return function()
			if popConnection then
				popConnection:Disconnect()
			end
			if popTween then
				popTween:Cancel()
			end
			if pulseTween then
				pulseTween:Cancel()
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
				else Color3.fromRGB(255, 255, 255),
			TextSize = 36,
			TextStrokeTransparency = 0.4,
			ref = feedbackLabelRef,
		}) or nil,
		Reaction = reaction and e("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Interactable = true,
			Position = UDim2.fromScale(reaction.screenX, reaction.screenY),
			Rotation = 0,
			Size = UDim2.fromOffset(112, 112),
			Text = "",
			key = tostring(reaction.id),
			[React.Event.Activated] = submitReaction,
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
				Scale = 0.72,
				ref = buttonScaleRef,
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 182, 182),
				Thickness = 5,
			}),
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = GameConfig.ui.reactionIcon,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ImageTransparency = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.56, 0.56),
				ZIndex = 2,
			}),
		}) or nil,
	})
end

return App
