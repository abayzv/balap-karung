local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnvironmentVfxController = {}

local function prepareEmitterPart(template, config)
	local part = template:Clone()
	part.Name = config.runtimeName
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Size = Vector3.new(0.1, 0.1, 0.1)

	local emitters = {}
	local windDirection = config.windDirection.Unit
	local windVelocity = config.windSpeed * config.windPower
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant.Rate = 0
			descendant.LockedToPart = false
			descendant.EmissionDirection = Enum.NormalId.Front
			descendant.Speed = NumberRange.new(windVelocity * 0.8, windVelocity * 1.2)
			descendant.Acceleration = Vector3.new(0, -config.fallAcceleration, 0)
			table.insert(emitters, descendant)
		end
	end

	return part, emitters, windDirection
end

local function getSpawnPosition(camera, config)
	local pitch = math.rad(
		math.random(config.minimumPitchDegrees * 100, config.maximumPitchDegrees * 100) / 100
	)
	local yaw =
		math.rad(math.random(-config.maximumYawDegrees * 100, config.maximumYawDegrees * 100) / 100)
	local distance = math.random(config.minimumDistance * 100, config.maximumDistance * 100) / 100
	return (camera.CFrame * CFrame.Angles(pitch, yaw, 0) * CFrame.new(0, 0, -distance)).Position
end

function EnvironmentVfxController.Start()
	local config = GameConfig.environmentVfx.leaf
	if not config.enabled then
		return
	end

	local template = ReplicatedStorage:FindFirstChild(config.templateName)
	if not template or not template:IsA("BasePart") then
		warn(
			`[BalapKarung] Template efek daun ReplicatedStorage.{config.templateName} tidak ditemukan`
		)
		return
	end

	local oldPart = Workspace:FindFirstChild(config.runtimeName)
	if oldPart then
		oldPart:Destroy()
	end

	local part, emitters, windDirection = prepareEmitterPart(template, config)
	if #emitters == 0 then
		part:Destroy()
		warn(`[BalapKarung] Template efek daun tidak memiliki ParticleEmitter`)
		return
	end
	part.Parent = Workspace

	local interval = 1 / math.max(config.spawnRate, 0.01)
	local elapsed = interval
	RunService.Heartbeat:Connect(function(deltaTime)
		if not part.Parent then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		elapsed += deltaTime
		local emitCount = math.min(math.floor(elapsed / interval), 2)
		if emitCount == 0 then
			return
		end
		elapsed -= emitCount * interval

		for _ = 1, emitCount do
			local position = getSpawnPosition(camera, config)
			part.CFrame = CFrame.lookAt(position, position + windDirection)
			for _, emitter in emitters do
				emitter:Emit(1)
			end
		end
	end)
end

return EnvironmentVfxController
