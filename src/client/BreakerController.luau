local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SoundController = require(script.Parent.SoundController)

local BreakerController = {}
local DEBRIS_COLLISION_GROUP = "BalapKarungGuardDebris"

local function setLocalHidden(obstacle, hidden)
	for _, descendant in obstacle:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
	if obstacle:IsA("BasePart") then
		obstacle.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

local function animateObstacle(obstacle, impactPart, throwDirection, forward)
	if not obstacle or not obstacle.Parent then
		return
	end

	setLocalHidden(obstacle, true)
	local debris = obstacle:Clone()
	debris.Name = `{obstacle.Name}_BreakerDebris`
	debris.Parent = Workspace
	for _, descendant in debris:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end

	local parts = {}
	if debris:IsA("BasePart") then
		table.insert(parts, debris)
	end
	for _, descendant in debris:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	local random = Random.new(math.floor(Workspace:GetServerTimeNow() * 1000) % 100000)
	local right = Vector3.yAxis:Cross(forward).Unit
	for _, part in parts do
		part.LocalTransparencyModifier = 0
		part.Anchored = false
		part.CanTouch = false
		part.CanQuery = false
		if part.Name == GameConfig.breaker.impactPartName then
			part.Transparency = 1
			part.CanCollide = false
			continue
		end
		part.CanCollide = true
		pcall(function()
			part.CollisionGroup = DEBRIS_COLLISION_GROUP
		end)
		local sideVariation = random:NextNumber(0.75, 1.25)
		local verticalVariation = random:NextNumber(0.8, 1.25)
		local outward = Vector3.new(
			part.Position.X - impactPart.Position.X,
			0,
			part.Position.Z - impactPart.Position.Z
		)
		if outward.Magnitude > 0.05 then
			outward = outward.Unit
		else
			outward = Vector3.zero
		end
		local spreadDirection = throwDirection.Unit
			+ right * random:NextNumber(
				-GameConfig.breaker.debrisSpreadRandomness,
				GameConfig.breaker.debrisSpreadRandomness
			)
			+ forward.Unit * random:NextNumber(
				-GameConfig.breaker.debrisForwardRandomness,
				GameConfig.breaker.debrisForwardRandomness
			)
			+ outward * 0.5
		if spreadDirection.Magnitude < 0.05 then
			spreadDirection = throwDirection.Unit
		else
			spreadDirection = spreadDirection.Unit
		end
		part.AssemblyLinearVelocity = spreadDirection
				* GameConfig.breaker.throwHorizontalSpeed
				* sideVariation
			+ Vector3.yAxis * GameConfig.breaker.throwVerticalSpeed * verticalVariation
			+ forward.Unit
				* GameConfig.breaker.throwForwardSpeed
				* random:NextNumber(0.65, 1.25)
		part.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-16, 16),
			random:NextNumber(-20, 20),
			random:NextNumber(-16, 16)
		)
	end

	Debris:AddItem(debris, GameConfig.breaker.debrisLifetimeSeconds)
	SoundController.Play("breakerImpact")
end

function BreakerController.Start(stateRemote, submitImpactRemote, impactRemote)
	local player = Players.LocalPlayer
	local pending = {}

	stateRemote.OnClientEvent:Connect(function(payload)
		if payload.action == "clear" then
			table.clear(pending)
			return
		end
		local impactPart = payload.impactPart
		local obstacle = payload.obstacle
		if
			type(payload.success) ~= "boolean"
			or typeof(impactPart) ~= "Instance"
			or not impactPart:IsA("BasePart")
			or typeof(obstacle) ~= "Instance"
		then
			return
		end
		pending[impactPart] = {
			obstacle = obstacle,
			success = payload.success,
			throwDirection = payload.throwDirection,
			forward = payload.forward,
			reported = false,
		}
	end)

	impactRemote.OnClientEvent:Connect(function(payload)
		local impactPart = payload.impactPart
		local obstacle = payload.obstacle
		if
			typeof(impactPart) ~= "Instance"
			or typeof(obstacle) ~= "Instance"
			or not impactPart:IsA("BasePart")
		then
			return
		end

		local prediction = pending[impactPart]
		pending[impactPart] = nil
		if prediction and prediction.reported then
			return
		end
		animateObstacle(obstacle, impactPart, payload.throwDirection, payload.forward)
	end)

	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("IsRace") ~= true then
			table.clear(pending)
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		for impactPart, prediction in pending do
			if prediction.reported or not impactPart.Parent then
				continue
			end
			local offset = impactPart.Position - root.Position
			local forwardDistance = offset:Dot(root.CFrame.LookVector)
			local lateralDistance = (offset - root.CFrame.LookVector * forwardDistance).Magnitude
			local triggerDistance = if prediction.success
				then GameConfig.breaker.impactRaycastDistanceStuds
				else GameConfig.breaker.failedImpactDistanceStuds
			local allowedLateralDistance = math.max(impactPart.Size.X, impactPart.Size.Z) / 2 + 3
			if
				forwardDistance >= -GameConfig.breaker.serverFallbackStuds
				and forwardDistance <= triggerDistance
				and lateralDistance <= allowedLateralDistance
			then
				prediction.reported = true
				animateObstacle(
					prediction.obstacle,
					impactPart,
					prediction.throwDirection,
					prediction.forward
				)
				submitImpactRemote:FireServer(impactPart, Workspace:GetServerTimeNow())
			end
		end
	end)
end

return BreakerController
