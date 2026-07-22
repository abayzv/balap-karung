local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MovementPrediction = require(ReplicatedStorage.Shared.MovementPrediction)

local MovementController = {}

local player = Players.LocalPlayer

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function moveToExpectedPosition(root, expectedPosition, forward, alpha)
	local currentPosition = root.Position
	local targetPosition = Vector3.new(expectedPosition.X, currentPosition.Y, expectedPosition.Z)
	local position = currentPosition:Lerp(targetPosition, alpha)
	root.CFrame = CFrame.lookAt(position, position + forward)
end

function MovementController.Start()
	RunService.RenderStepped:Connect(function(deltaTime)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or root.Anchored then
			return
		end
		local raceStatus = player:GetAttribute("RaceStatus")
		if raceStatus ~= "Racing" then
			if raceStatus == "Finished" then
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			end
			return
		end

		local forwardAttribute = player:GetAttribute("RaceForward")
		local startOrigin = player:GetAttribute("RaceStartOrigin")
		local trackLength = player:GetAttribute("TrackLength")
		local authoritativeDistance = player:GetAttribute("AuthoritativeDistance")
		local authoritativeUpdatedAt = player:GetAttribute("AuthoritativeUpdatedAt")
		if
			typeof(forwardAttribute) ~= "Vector3"
			or typeof(startOrigin) ~= "Vector3"
			or type(trackLength) ~= "number"
			or type(authoritativeDistance) ~= "number"
			or type(authoritativeUpdatedAt) ~= "number"
		then
			return
		end

		local forward = horizontal(forwardAttribute)
		if forward.Magnitude < 0.001 or trackLength <= 0 then
			return
		end
		forward = forward.Unit

		local isRecovering = player:GetAttribute("IsRecovering") == true
		local effectiveSpeed = player:GetAttribute("EffectiveSpeed") or 0
		local forwardSpeed = if isRecovering then 0 else math.max(0, effectiveSpeed)
		local velocity = root.AssemblyLinearVelocity
		local forwardVelocity = forward * forwardSpeed
		root.AssemblyLinearVelocity = Vector3.new(forwardVelocity.X, velocity.Y, forwardVelocity.Z)

		if isRecovering then
			return
		end
		local predictedAuthoritativeDistance = MovementPrediction.extrapolateDistance(
			authoritativeDistance,
			forwardSpeed,
			authoritativeUpdatedAt,
			Workspace:GetServerTimeNow(),
			GameConfig.movement.maximumExtrapolationSeconds,
			trackLength
		)

		local localDistance =
			MovementPrediction.progressAt(root.Position, startOrigin, forward, trackLength)
		local mode = MovementPrediction.reconciliationMode(
			localDistance,
			predictedAuthoritativeDistance,
			GameConfig.movement.smoothCorrectionThresholdStuds,
			GameConfig.movement.snapCorrectionThresholdStuds
		)
		if mode == "None" then
			return
		end

		local expectedPosition = startOrigin + forward * predictedAuthoritativeDistance
		local alpha = if mode == "Snap"
			then 1
			else MovementPrediction.smoothingAlpha(
				deltaTime,
				GameConfig.movement.smoothCorrectionRate
			)
		moveToExpectedPosition(root, expectedPosition, forward, alpha)
	end)
end

return MovementController
