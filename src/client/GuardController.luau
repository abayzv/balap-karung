local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ImpactFeedback = require(ReplicatedStorage.Shared.ImpactFeedback)
local SoundController = require(script.Parent.SoundController)

local GuardController = {}
local DEBRIS_COLLISION_GROUP = "BalapKarungGuardDebris"

local function disableLocalShield(character)
	local upperTorso = character and character:FindFirstChild("UpperTorso")
	if not upperTorso then
		return
	end
	for _, descendant in upperTorso:GetDescendants() do
		local attachment = descendant.Parent
		if
			descendant:IsA("ParticleEmitter")
			and attachment
			and attachment:IsA("Attachment")
			and attachment:GetAttribute(GameConfig.effects.guardShieldAttribute) == true
		then
			descendant.Enabled = false
		end
	end
end

local function findBarrierModel(barrier)
	local current = barrier.Parent
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, GameConfig.obstacle.tag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function animateBarrier(barrier, throwDirection, forward)
	if not barrier or not barrier.Parent then
		return
	end

	barrier.LocalTransparencyModifier = 1
	local debris = barrier:Clone()
	debris.Name = `{barrier.Name}_GuardDebris`
	debris.LocalTransparencyModifier = 0
	debris.Anchored = false
	debris.CanCollide = true
	debris.CanTouch = false
	debris.CanQuery = false
	pcall(function()
		debris.CollisionGroup = DEBRIS_COLLISION_GROUP
	end)
	debris.Parent = Workspace
	debris.AssemblyAngularVelocity = Vector3.new(12 * throwDirection.Z, 18, -12 * throwDirection.X)
	debris.AssemblyLinearVelocity = throwDirection.Unit
			* GameConfig.obstacle.guardThrowHorizontalSpeed
		+ Vector3.yAxis * GameConfig.obstacle.guardThrowVerticalSpeed
		+ forward.Unit * GameConfig.obstacle.guardThrowForwardSpeed
	Debris:AddItem(debris, GameConfig.obstacle.guardDebrisLifetimeSeconds)
end

function GuardController.Start(submitRemote, broadcastRemote, crashRemote)
	local player = Players.LocalPlayer
	local predicted = {}
	local reportedCrashes = {}

	broadcastRemote.OnClientEvent:Connect(function(payload)
		local barrier = payload.barrier
		if typeof(barrier) ~= "Instance" or not barrier:IsA("BasePart") then
			return
		end

		barrier.LocalTransparencyModifier = 1
		local prediction = predicted[barrier]
		if prediction then
			prediction.acknowledged = true
			return
		end

		animateBarrier(barrier, payload.throwDirection, payload.forward)
		if ImpactFeedback.shouldPlaySound(player.UserId, payload.soundUserId, false) then
			SoundController.Play("guardSwing")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("IsRace") ~= true then
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local activeTrack = Workspace:FindFirstChild("ActiveTrack")
		if not root or not activeTrack then
			return
		end

		local barriers = {}
		local maximumDistance = 0
		for _, obstacleModel in CollectionService:GetTagged(GameConfig.obstacle.tag) do
			if obstacleModel:IsDescendantOf(activeTrack) then
				local barrier =
					obstacleModel:FindFirstChild(GameConfig.obstacle.barrierPartName, true)
				if barrier and barrier:IsA("BasePart") and not predicted[barrier] then
					table.insert(barriers, barrier)
					maximumDistance = math.max(
						maximumDistance,
						obstacleModel:GetAttribute("ImpactLeadStuds")
							or GameConfig.obstacle.guardRaycastDistanceStuds
					)
				end
			end
		end
		if #barriers == 0 then
			return
		end
		if player:GetAttribute("GuardReady") ~= true then
			if player:GetAttribute("LastObstacleCombo") ~= "Failed" then
				return
			end

			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			overlapParams.FilterDescendantsInstances = barriers
			overlapParams.MaxParts = 1
			local hitboxCFrame = root.CFrame
				* CFrame.new(0, 0, -GameConfig.obstacle.characterCrashHitboxForwardOffsetStuds)
			local hitBarriers = Workspace:GetPartBoundsInBox(
				hitboxCFrame,
				GameConfig.obstacle.characterCrashHitboxSize,
				overlapParams
			)
			local barrier = hitBarriers[1]
			if barrier and not reportedCrashes[barrier] then
				reportedCrashes[barrier] = true
				local obstacleModel = findBarrierModel(barrier)
				local throwSide = if obstacleModel
					then obstacleModel:GetAttribute("ThrowSide") or 1
					else 1
				local forward = root.CFrame.LookVector
				local throwDirection = Vector3.yAxis:Cross(forward) * throwSide
				predicted[barrier] = { acknowledged = false }
				animateBarrier(barrier, throwDirection, forward)
				SoundController.Play("guardSwing")
				crashRemote:FireServer(barrier, Workspace:GetServerTimeNow())

				task.delay(GameConfig.obstacle.guardReplicationHideDelaySeconds + 0.85, function()
					local prediction = predicted[barrier]
					if prediction and not prediction.acknowledged then
						predicted[barrier] = nil
						if barrier.Parent and barrier.Transparency < 1 then
							barrier.LocalTransparencyModifier = 0
						end
					end
				end)
			end
			return
		end
		if maximumDistance <= 0 then
			return
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = barriers
		raycastParams.IgnoreWater = true
		local result = Workspace:Raycast(
			root.Position,
			root.CFrame.LookVector * maximumDistance,
			raycastParams
		)
		if not result then
			return
		end

		local barrier = result.Instance
		local obstacleModel = findBarrierModel(barrier)
		if not obstacleModel then
			return
		end
		local guardDistance = obstacleModel:GetAttribute("ImpactLeadStuds")
			or GameConfig.obstacle.guardRaycastDistanceStuds
		if result.Distance > guardDistance then
			return
		end
		local throwSide = obstacleModel:GetAttribute("ThrowSide") or 1
		local forward = root.CFrame.LookVector
		local throwDirection = Vector3.yAxis:Cross(forward) * throwSide
		predicted[barrier] = { acknowledged = false }
		animateBarrier(barrier, throwDirection, forward)
		disableLocalShield(character)
		SoundController.Play("guardSwing")
		submitRemote:FireServer(barrier, Workspace:GetServerTimeNow())

		task.delay(GameConfig.obstacle.guardReplicationHideDelaySeconds + 0.85, function()
			local prediction = predicted[barrier]
			if prediction and not prediction.acknowledged then
				predicted[barrier] = nil
				if barrier.Parent and barrier.Transparency < 1 then
					barrier.LocalTransparencyModifier = 0
				end
			end
		end)
	end)
end

return GuardController
