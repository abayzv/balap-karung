local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoundController = require(script.Parent.SoundController)

local CharacterAnimationController = {}

local function emitHopDebris(character)
	local template = ReplicatedStorage:FindFirstChild(GameConfig.effects.hopDebrisTemplateName)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not template or not template:IsA("BasePart") or not root then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = false
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), raycastParams)
	local position = if result then result.Position + Vector3.new(0, 0.05, 0) else root.Position

	local debrisPart = template:Clone()
	debrisPart.Name = "BalapKarungHopDebris"
	debrisPart.Anchored = true
	debrisPart.CanCollide = false
	debrisPart.CanTouch = false
	debrisPart.CanQuery = false
	debrisPart.CastShadow = false
	debrisPart.Transparency = 1
	debrisPart.CFrame = CFrame.new(position) * template.CFrame.Rotation
	debrisPart.Parent = Workspace

	local maximumLifetime = 0
	for _, descendant in debrisPart:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			maximumLifetime = math.max(maximumLifetime, descendant.Lifetime.Max)
			descendant:Emit(
				descendant:GetAttribute("EmitCount") or GameConfig.effects.hopDebrisDefaultEmitCount
			)
		end
	end
	DebrisService:AddItem(debrisPart, maximumLifetime + 0.5)
end

local function loadTrack(animator, animationId, priority, looped)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success then
		warn(`[BalapKarung] Failed to load animation {animationId}: {tostring(track)}`)
		return nil
	end

	track.Looped = looped
	track.Priority = priority
	return track
end

function CharacterAnimationController.Start()
	local player = Players.LocalPlayer
	local characterConnections = {}
	local activeTracks = {}

	local function clearCharacter()
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)

		for _, track in activeTracks do
			track:Stop(0.1)
		end
		table.clear(activeTracks)
	end

	local function attachCharacter(character)
		clearCharacter()

		local humanoid = character:WaitForChild("Humanoid")
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		local defaultAnimate = character:WaitForChild("Animate", 2)

		local idleTrack =
			loadTrack(animator, GameConfig.animations.idle, Enum.AnimationPriority.Action4, true)
		local walkTrack =
			loadTrack(animator, GameConfig.animations.walk, Enum.AnimationPriority.Action4, true)
		local fallTrack =
			loadTrack(animator, GameConfig.animations.fall, Enum.AnimationPriority.Action, false)
		if idleTrack then
			table.insert(activeTracks, idleTrack)
		end
		if walkTrack then
			table.insert(activeTracks, walkTrack)
			table.insert(
				characterConnections,
				walkTrack
					:GetMarkerReachedSignal(GameConfig.animations.hopMarkerName)
					:Connect(function()
						SoundController.Play("hop")
						emitHopDebris(character)
					end)
			)
		end
		if fallTrack then
			table.insert(activeTracks, fallTrack)
		end

		local function updateTrack()
			local raceStatus = player:GetAttribute("RaceStatus")
			local isRace = player:GetAttribute("IsRace") == true
			local isOnTrack = isRace
				and (
					raceStatus == "Countdown"
					or raceStatus == "Racing"
					or raceStatus == "Finished"
				)

			if not isOnTrack then
				if idleTrack and idleTrack.IsPlaying then
					idleTrack:Stop(0.12)
				end
				if walkTrack and walkTrack.IsPlaying then
					walkTrack:Stop(0.12)
				end
				if fallTrack and fallTrack.IsPlaying then
					fallTrack:Stop(0.08)
				end
				if defaultAnimate then
					defaultAnimate.Disabled = false
				end
				return
			end

			if defaultAnimate and not defaultAnimate.Disabled then
				defaultAnimate.Disabled = true
				for _, playingTrack in animator:GetPlayingAnimationTracks() do
					if
						playingTrack ~= idleTrack
						and playingTrack ~= walkTrack
						and playingTrack ~= fallTrack
					then
						playingTrack:Stop(0.12)
					end
				end
			end

			local isRecovering = player:GetAttribute("IsRecovering")
			local humanoidState = humanoid:GetState()
			local isAirborne = humanoidState == Enum.HumanoidStateType.Jumping
				or humanoidState == Enum.HumanoidStateType.Freefall
			local shouldWalk = raceStatus == "Racing" and not isRecovering and not isAirborne

			if isRecovering then
				if idleTrack and idleTrack.IsPlaying then
					idleTrack:Stop(0.08)
				end
				if walkTrack and walkTrack.IsPlaying then
					walkTrack:Stop(0.08)
				end
				if fallTrack and not fallTrack.IsPlaying then
					fallTrack:Play(0.06)
					fallTrack:AdjustSpeed(GameConfig.animations.fallPlaybackSpeed)
				end
			elseif shouldWalk then
				if fallTrack and fallTrack.IsPlaying then
					fallTrack:Stop(0.08)
				end
				if idleTrack and idleTrack.IsPlaying then
					idleTrack:Stop(0.12)
				end
				if walkTrack and not walkTrack.IsPlaying then
					walkTrack:Play(0.12)
				end
				if walkTrack then
					local effectiveSpeed = player:GetAttribute("EffectiveSpeed")
						or GameConfig.speed.normalValue
					local baseSpeed = GameConfig.speed.normalValue
					local playbackSpeed = GameConfig.animations.walkPlaybackSpeedAtBase
						* (effectiveSpeed / baseSpeed)
					walkTrack:AdjustSpeed(math.clamp(playbackSpeed, 0.8, 4))
				end
			else
				if fallTrack and fallTrack.IsPlaying then
					fallTrack:Stop(0.08)
				end
				if walkTrack and walkTrack.IsPlaying then
					walkTrack:Stop(0.12)
				end
				if idleTrack and not idleTrack.IsPlaying then
					idleTrack:Play(0.12)
				end
			end
		end

		table.insert(
			characterConnections,
			player:GetAttributeChangedSignal("RaceStatus"):Connect(updateTrack)
		)
		table.insert(
			characterConnections,
			player:GetAttributeChangedSignal("IsRace"):Connect(updateTrack)
		)
		table.insert(
			characterConnections,
			player:GetAttributeChangedSignal("IsRecovering"):Connect(updateTrack)
		)
		table.insert(
			characterConnections,
			player:GetAttributeChangedSignal("EffectiveSpeed"):Connect(updateTrack)
		)
		table.insert(characterConnections, humanoid.StateChanged:Connect(updateTrack))
		table.insert(characterConnections, humanoid.Died:Connect(clearCharacter))
		updateTrack()
	end

	player.CharacterAdded:Connect(attachCharacter)
	if player.Character then
		task.spawn(attachCharacter, player.Character)
	end
end

return CharacterAnimationController
