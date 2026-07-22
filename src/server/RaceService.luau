local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LavaWaveMechanic = require(ReplicatedStorage.Shared.LavaWaveMechanic)
local MovementPrediction = require(ReplicatedStorage.Shared.MovementPrediction)
local NetworkTiming = require(ReplicatedStorage.Shared.NetworkTiming)
local ObstacleMechanic = require(ReplicatedStorage.Shared.ObstacleMechanic)
local Reaction = require(ReplicatedStorage.Shared.Reaction)
local Speed = require(ReplicatedStorage.Shared.Speed)
local SackService = require(script.Parent.SackService)
local TrackService = require(script.Parent.TrackService)

local RACER_COLLISION_GROUP = "BalapKarungRacers"
local GUARD_DEBRIS_COLLISION_GROUP = "BalapKarungGuardDebris"
local ON_FIRE_AURA_ATTRIBUTE = "BalapKarungOnfireAura"

local RaceService = {}
RaceService.__index = RaceService

local function setPlayerDefaults(player)
	player:SetAttribute("Speed", GameConfig.speed.normalValue)
	player:SetAttribute("NoMissStreak", 0)
	player:SetAttribute("OnFireProgress", 0)
	player:SetAttribute("TempoStage", 1)
	player:SetAttribute("OnFire", false)
	player:SetAttribute("OnFireEndsAt", 0)
	player:SetAttribute("SpeedMultiplier", 1)
	player:SetAttribute("EffectiveSpeed", GameConfig.speed.normalValue)
	player:SetAttribute("BoostEndsAt", 0)
	player:SetAttribute("IsRecovering", false)
	player:SetAttribute("DistanceRemaining", GameConfig.race.trackLengthStuds)
	player:SetAttribute("RaceProgress", 0)
	player:SetAttribute("RaceStatus", "Waiting")
	player:SetAttribute("FinishTime", 0)
	player:SetAttribute("Rank", 0)
	player:SetAttribute("LaneIndex", 0)
	player:SetAttribute("LastVerdict", "")
	player:SetAttribute("IsRace", false)
	player:SetAttribute("InStartArea", false)
	player:SetAttribute("GuardReady", false)
	player:SetAttribute("LastGuardImpact", "")
	player:SetAttribute("LastObstacleCombo", "")
	player:SetAttribute("ObstaclePerfectCount", 0)
	player:SetAttribute("ObstacleGoodCount", 0)
	player:SetAttribute("BreakerActive", false)
	player:SetAttribute("BreakerChain", 0)
	player:SetAttribute("LastBreakerVerdict", "")
	player:SetAttribute("LastLavaVerdict", "")
	player:SetAttribute("LavaWavesDodged", 0)
	player:SetAttribute("LavaWavesHit", 0)
	player:SetAttribute("RaceValidInputs", 0)
	player:SetAttribute("LastCoinReward", 0)
	player:SetAttribute("NetworkPingMs", 0)
	player:SetAttribute("LastPromptSentAt", 0)
	player:SetAttribute("LastPromptOpensAt", 0)
	player:SetAttribute("LastPromptId", 0)
	player:SetAttribute("LastPromptType", "")
	player:SetAttribute("LastReactionReceivedAt", 0)
	player:SetAttribute("LastReactionPressedAt", 0)
	player:SetAttribute("LastReactionEventId", 0)
	player:SetAttribute("LastImpactReceivedAt", 0)
	player:SetAttribute("LastImpactDetectedAt", 0)
	player:SetAttribute("LastImpactValidationDistance", 0)
	player:SetAttribute("RaceId", 0)
	player:SetAttribute("RaceForward", Vector3.zero)
	player:SetAttribute("RaceStartOrigin", Vector3.zero)
	player:SetAttribute("TrackLength", 0)
	player:SetAttribute("AuthoritativeDistance", 0)
	player:SetAttribute("AuthoritativeUpdatedAt", 0)
end

local function isPointInsidePart(part, point)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	return math.abs(localPoint.X) <= halfSize.X
		and math.abs(localPoint.Y) <= halfSize.Y
		and math.abs(localPoint.Z) <= halfSize.Z
end

local function getPlayersInStartArea()
	local startParts = {}
	for _, instance in CollectionService:GetTagged(GameConfig.queue.startPartTag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
			table.insert(startParts, instance)
		end
	end

	local queuedPlayers = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local isInside = false
		if root then
			for _, startPart in startParts do
				if isPointInsidePart(startPart, root.Position) then
					isInside = true
					break
				end
			end
		end
		player:SetAttribute("InStartArea", isInside)
		if isInside then
			table.insert(queuedPlayers, player)
		end
	end

	Workspace:SetAttribute("PlayersInStartArea", #queuedPlayers)
	return queuedPlayers
end

local function getLaneObstacles(trackModel, lane)
	local obstacles = {}
	for _, instance in CollectionService:GetTagged(GameConfig.obstacle.tag) do
		if
			instance:IsDescendantOf(trackModel)
			and instance:GetAttribute("LaneIndex") == lane.index
		then
			local trigger = instance:FindFirstChild(GameConfig.obstacle.triggerPartName, true)
			local barrier = instance:FindFirstChild(GameConfig.obstacle.barrierPartName, true)
			if trigger and trigger:IsA("BasePart") and barrier and barrier:IsA("BasePart") then
				local triggerProgress = (trigger.Position - lane.spawn.Position):Dot(lane.forward)
				local barrierProgress = (barrier.Position - lane.spawn.Position):Dot(lane.forward)
				local impactLeadStuds = instance:GetAttribute("ImpactLeadStuds")
					or GameConfig.obstacle.guardRaycastDistanceStuds
				local impactProgress = barrierProgress - impactLeadStuds
				local crashProgress = barrierProgress - GameConfig.obstacle.guardCrashLeadStuds
				if
					triggerProgress >= 0
					and impactProgress > triggerProgress
					and barrierProgress <= lane.length
				then
					for _, descendant in instance:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.CanCollide = false
						end
					end
					barrier.CanQuery = true
					table.insert(obstacles, {
						id = instance:GetAttribute("BarrierIndex") or instance.Name,
						triggerProgress = triggerProgress,
						barrierProgress = barrierProgress,
						impactProgress = impactProgress,
						crashProgress = crashProgress,
						tapCount = instance:GetAttribute("TapCount")
							or GameConfig.obstacle.tapCount,
						skillId = instance:GetAttribute("TapSkillId")
							or GameConfig.obstacle.skillId,
						barrier = barrier,
						throwDirection = Vector3.yAxis:Cross(lane.forward)
							* (instance:GetAttribute("ThrowSide") or 1),
						started = false,
						resolved = false,
						guardArmed = false,
						guardUsed = false,
						failed = false,
						crashed = false,
					})
				end
			else
				warn(
					`[BalapKarung] {instance:GetFullName()} membutuhkan {GameConfig.obstacle.triggerPartName} dan {GameConfig.obstacle.barrierPartName}`
				)
			end
		end
	end
	table.sort(obstacles, function(left, right)
		return left.triggerProgress < right.triggerProgress
	end)
	return obstacles
end

local function breakerPartProgress(part, lane)
	return (part.Position - lane.spawn.Position):Dot(lane.forward)
end

local function setObstaclePartsNonCollidable(obstacleRoot)
	if obstacleRoot:IsA("BasePart") then
		obstacleRoot.CanCollide = false
		obstacleRoot.CanTouch = false
	end
	for _, descendant in obstacleRoot:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
end

local function getLaneBreakerZones(trackModel, lane)
	local zones = {}
	for _, zoneModel in CollectionService:GetTagged(GameConfig.breaker.zoneTag) do
		if
			not zoneModel:IsA("Model")
			or not zoneModel:IsDescendantOf(trackModel)
			or zoneModel:GetAttribute("LaneIndex") ~= lane.index
		then
			continue
		end

		local activationPart = zoneModel:FindFirstChild(GameConfig.breaker.activationPartName, true)
		local endPart = zoneModel:FindFirstChild(GameConfig.breaker.endPartName, true)
		local obstaclesFolder =
			zoneModel:FindFirstChild(GameConfig.breaker.obstaclesFolderName, true)
		if
			not activationPart
			or not activationPart:IsA("BasePart")
			or not endPart
			or not endPart:IsA("BasePart")
			or not obstaclesFolder
		then
			warn(
				`[BalapKarung] {zoneModel:GetFullName()} membutuhkan {GameConfig.breaker.activationPartName}, {GameConfig.breaker.endPartName}, dan folder {GameConfig.breaker.obstaclesFolderName}`
			)
			continue
		end

		local activationProgress = breakerPartProgress(activationPart, lane)
		local endProgress = breakerPartProgress(endPart, lane)
		if
			activationProgress < 0
			or endProgress <= activationProgress
			or endProgress > lane.length
		then
			warn(`[BalapKarung] Urutan marker {zoneModel:GetFullName()} tidak valid`)
			continue
		end
		activationPart.CanCollide = false
		activationPart.CanTouch = false
		endPart.CanCollide = false
		endPart.CanTouch = false

		local obstacles = {}
		local usedIndices = {}
		for _, obstacleRoot in CollectionService:GetTagged(GameConfig.breaker.obstacleTag) do
			if not obstacleRoot:IsDescendantOf(obstaclesFolder) then
				continue
			end
			local impactPart = obstacleRoot:FindFirstChild(GameConfig.breaker.impactPartName, true)
			local obstacleIndex = obstacleRoot:GetAttribute("ObstacleIndex")
			if
				not impactPart
				or not impactPart:IsA("BasePart")
				or type(obstacleIndex) ~= "number"
				or obstacleIndex % 1 ~= 0
				or obstacleIndex < 1
			then
				warn(
					`[BalapKarung] {obstacleRoot:GetFullName()} membutuhkan ImpactPart dan ObstacleIndex integer positif`
				)
				continue
			end
			if usedIndices[obstacleIndex] then
				warn(
					`[BalapKarung] ObstacleIndex {obstacleIndex} duplikat pada {zoneModel:GetFullName()}`
				)
				continue
			end

			local progress = breakerPartProgress(impactPart, lane)
			if progress <= activationProgress or progress >= endProgress then
				warn(
					`[BalapKarung] {impactPart:GetFullName()} harus berada di antara ActivationPart dan EndPart`
				)
				continue
			end

			usedIndices[obstacleIndex] = true
			setObstaclePartsNonCollidable(obstacleRoot)
			impactPart.CanQuery = true
			local throwSide = obstacleRoot:GetAttribute("ThrowSide")
			if type(throwSide) ~= "number" or throwSide == 0 then
				throwSide = if obstacleIndex % 2 == 0 then -1 else 1
			end
			table.insert(obstacles, {
				id = obstacleRoot:GetAttribute("ObstacleId") or obstacleRoot.Name,
				index = obstacleIndex,
				root = obstacleRoot,
				impactPart = impactPart,
				progress = progress,
				throwDirection = Vector3.yAxis:Cross(lane.forward) * throwSide,
				promptStarted = false,
				verdict = nil,
				impacted = false,
			})
		end

		table.sort(obstacles, function(left, right)
			return left.index < right.index
		end)
		if #obstacles == 0 then
			warn(`[BalapKarung] {zoneModel:GetFullName()} tidak memiliki BreakerObstacle valid`)
			continue
		end
		for index, obstacle in obstacles do
			if obstacle.index ~= index then
				warn(
					`[BalapKarung] ObstacleIndex {zoneModel:GetFullName()} harus berurutan mulai dari 1`
				)
				break
			end
			if index > 1 then
				local spacing = obstacle.progress - obstacles[index - 1].progress
				if
					spacing < GameConfig.breaker.minimumObstacleSpacingStuds
					or spacing > GameConfig.breaker.maximumObstacleSpacingStuds
				then
					warn(
						`[BalapKarung] Jarak obstacle {index - 1}->{index} pada {zoneModel:GetFullName()} adalah {math.round(
							spacing
						)} studs; rekomendasi {GameConfig.breaker.minimumObstacleSpacingStuds}-{GameConfig.breaker.maximumObstacleSpacingStuds}`
					)
				end
			end
		end
		local firstObstacle = obstacles[1]
		local recommendedFirstGap = GameConfig.speed.onFireValue
			* GameConfig.breaker.promptLeadSeconds
		local actualFirstGap = firstObstacle.progress - activationProgress
		if actualFirstGap < recommendedFirstGap then
			warn(
				`[BalapKarung] Jarak ActivationPart ke obstacle pertama {zoneModel:GetFullName()} hanya {math.round(
					actualFirstGap
				)} studs; membutuhkan sekitar {math.ceil(recommendedFirstGap)} studs saat OnFire`
			)
		end

		table.insert(zones, {
			id = zoneModel:GetAttribute("ZoneId") or zoneModel.Name,
			encounterId = zoneModel:GetAttribute("EncounterId") or zoneModel.Name,
			order = zoneModel:GetAttribute("ZoneOrder") or 1,
			model = zoneModel,
			activationProgress = activationProgress,
			endProgress = endProgress,
			obstacles = obstacles,
			started = false,
			completed = false,
		})
	end

	table.sort(zones, function(left, right)
		return left.activationProgress < right.activationProgress
	end)
	return zones
end

local function validateBreakerFairness(lanes, zonesByLane)
	local encounters = {}
	for _, lane in lanes do
		for _, zone in zonesByLane[lane.index] or {} do
			local encounter = encounters[zone.encounterId]
			if not encounter then
				encounter = {}
				encounters[zone.encounterId] = encounter
			end
			encounter[lane.index] = zone
		end
	end

	for encounterId, encounter in encounters do
		local reference = nil
		for _, lane in lanes do
			local zone = encounter[lane.index]
			if not zone then
				warn(
					`[BalapKarung] Breaker encounter {encounterId} tidak tersedia pada LaneIndex {lane.index}`
				)
				continue
			end
			if not reference then
				reference = zone
				continue
			end
			if #zone.obstacles ~= #reference.obstacles then
				warn(
					`[BalapKarung] Breaker encounter {encounterId} memiliki jumlah obstacle berbeda antar-lane`
				)
				continue
			end
			for index = 2, #zone.obstacles do
				local spacing = zone.obstacles[index].progress - zone.obstacles[index - 1].progress
				local referenceSpacing = reference.obstacles[index].progress
					- reference.obstacles[index - 1].progress
				if
					math.abs(spacing - referenceSpacing)
					> GameConfig.breaker.spacingToleranceStuds
				then
					warn(
						`[BalapKarung] Pola jarak Breaker encounter {encounterId} LaneIndex {lane.index} berbeda lebih dari {GameConfig.breaker.spacingToleranceStuds} studs`
					)
					break
				end
			end
		end
	end
end

local function updateJumpState(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local isRace = player:GetAttribute("IsRace") == true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not isRace)
	if isRace then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
	else
		humanoid.UseJumpPower = StarterPlayer.CharacterUseJumpPower
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	end
end

local function restoreLobbyCharacter(player, character)
	SackService.Detach(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.PlatformStand = false
	end
	updateJumpState(player, character)
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		pcall(function()
			root:SetNetworkOwnershipAuto()
		end)
	end
end

local function moveCharacterToLobby(character)
	local lobbySpawn = Workspace:FindFirstChild("SpawnLocation")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not lobbySpawn or not lobbySpawn:IsA("BasePart") or not root then
		return false
	end

	local lobbyPosition = (lobbySpawn.CFrame * CFrame.new(
		0,
		lobbySpawn.Size.Y / 2 + GameConfig.track.characterSpawnHeight,
		0
	)).Position
	character:PivotTo(CFrame.lookAt(lobbyPosition, lobbyPosition + lobbySpawn.CFrame.LookVector))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function updateOnFireAura(player, character)
	if not character then
		return
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso or not upperTorso:IsA("BasePart") then
		return
	end

	for _, child in upperTorso:GetChildren() do
		if child:GetAttribute(ON_FIRE_AURA_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	if player:GetAttribute("OnFire") ~= true then
		return
	end

	local template = ReplicatedStorage:FindFirstChild("OnfireAura")
	local sourcePart = template and template:FindFirstChild("Torso", true)
	if not sourcePart or not sourcePart:IsA("BasePart") then
		warn("[BalapKarung] ReplicatedStorage.OnfireAura.Torso tidak ditemukan")
		return
	end

	for _, child in sourcePart:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local particle = child:Clone()
			particle:SetAttribute(ON_FIRE_AURA_ATTRIBUTE, true)
			particle.Parent = upperTorso
		end
	end
end

local function updateGuardShield(player, character)
	if not character then
		return
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if not upperTorso or not upperTorso:IsA("BasePart") then
		return
	end

	for _, child in upperTorso:GetChildren() do
		if child:GetAttribute(GameConfig.effects.guardShieldAttribute) == true then
			child:Destroy()
		end
	end

	if player:GetAttribute("GuardReady") ~= true then
		return
	end

	local template = ReplicatedStorage:FindFirstChild(GameConfig.effects.guardShieldTemplateName)
	if not template or not template:IsA("BasePart") then
		warn(
			`[BalapKarung] ReplicatedStorage.{GameConfig.effects.guardShieldTemplateName} tidak ditemukan`
		)
		return
	end

	for _, child in template:GetChildren() do
		if child:IsA("Attachment") then
			local attachment = child:Clone()
			attachment:SetAttribute(GameConfig.effects.guardShieldAttribute, true)
			attachment.Parent = upperTorso
			for _, descendant in attachment:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant:Emit(GameConfig.effects.guardShieldActivationEmitCount)
				end
			end
		end
	end
end

function RaceService.new(dataService)
	local self = setmetatable({}, RaceService)
	self._dataService = dataService
	self._raceId = 0
	self._eventId = 0
	self._finishCount = 0
	self._racers = {}
	self._raceStartedAt = 0
	self._state = "Waiting"
	self._trackService = TrackService.new()
	self._activeTrack = nil
	self._lavaEnabled = false
	self._lavaGeometry = nil
	self._lavaWaves = {}
	self._lavaWaveId = 0
	self._nextLavaWaveAt = 0
	self._lavaRandom = Random.new()
	self:_createRemotes()
	return self
end

function RaceService:_createRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local reactionWindow = folder:FindFirstChild("ReactionWindow")
	if not reactionWindow then
		reactionWindow = Instance.new("RemoteEvent")
		reactionWindow.Name = "ReactionWindow"
		reactionWindow.Parent = folder
	end

	local submitReaction = folder:FindFirstChild("SubmitReaction")
	if not submitReaction then
		submitReaction = Instance.new("RemoteEvent")
		submitReaction.Name = "SubmitReaction"
		submitReaction.Parent = folder
	end
	local submitGuardImpact = folder:FindFirstChild("SubmitGuardImpact")
	if not submitGuardImpact then
		submitGuardImpact = Instance.new("RemoteEvent")
		submitGuardImpact.Name = "SubmitGuardImpact"
		submitGuardImpact.Parent = folder
	end
	local guardImpact = folder:FindFirstChild("GuardImpact")
	if not guardImpact then
		guardImpact = Instance.new("RemoteEvent")
		guardImpact.Name = "GuardImpact"
		guardImpact.Parent = folder
	end
	local submitObstacleCrash = folder:FindFirstChild("SubmitObstacleCrash")
	if not submitObstacleCrash then
		submitObstacleCrash = Instance.new("RemoteEvent")
		submitObstacleCrash.Name = "SubmitObstacleCrash"
		submitObstacleCrash.Parent = folder
	end
	local podiumResults = folder:FindFirstChild("PodiumResults")
	if not podiumResults then
		podiumResults = Instance.new("RemoteEvent")
		podiumResults.Name = "PodiumResults"
		podiumResults.Parent = folder
	end
	local breakerState = folder:FindFirstChild("BreakerState")
	if not breakerState then
		breakerState = Instance.new("RemoteEvent")
		breakerState.Name = "BreakerState"
		breakerState.Parent = folder
	end
	local submitBreakerImpact = folder:FindFirstChild("SubmitBreakerImpact")
	if not submitBreakerImpact then
		submitBreakerImpact = Instance.new("RemoteEvent")
		submitBreakerImpact.Name = "SubmitBreakerImpact"
		submitBreakerImpact.Parent = folder
	end
	local breakerImpact = folder:FindFirstChild("BreakerImpact")
	if not breakerImpact then
		breakerImpact = Instance.new("RemoteEvent")
		breakerImpact.Name = "BreakerImpact"
		breakerImpact.Parent = folder
	end
	self._reactionWindowRemote = reactionWindow
	self._submitReactionRemote = submitReaction
	self._submitGuardImpactRemote = submitGuardImpact
	self._guardImpactRemote = guardImpact
	self._submitObstacleCrashRemote = submitObstacleCrash
	self._podiumResultsRemote = podiumResults
	self._breakerStateRemote = breakerState
	self._submitBreakerImpactRemote = submitBreakerImpact
	self._breakerImpactRemote = breakerImpact
end

function RaceService:_setState(state, countdown)
	self._state = state
	Workspace:SetAttribute("RaceState", state)
	Workspace:SetAttribute("Countdown", countdown or 0)
end

function RaceService:_refreshNetworkTiming(racer, now, force)
	if not force and now - racer.lastPingSampleAt < GameConfig.networking.pingIntervalSeconds then
		return
	end
	racer.lastPingSampleAt = now
	local success, sample = pcall(function()
		return racer.player:GetNetworkPing()
	end)
	if
		not success
		or type(sample) ~= "number"
		or sample ~= sample
		or sample < 0
		or sample == math.huge
	then
		return
	end
	racer.smoothOneWayLatency = NetworkTiming.smoothLatency(
		racer.smoothOneWayLatency,
		sample,
		GameConfig.networking.pingSmoothingAlpha,
		GameConfig.networking.maximumOneWayLatencySeconds
	)
	racer.player:SetAttribute("NetworkPingMs", math.round(racer.smoothOneWayLatency * 1000))
end

function RaceService:_playerLeadSeconds(racer, baseLeadSeconds)
	return NetworkTiming.leadSeconds(
		racer.smoothOneWayLatency,
		baseLeadSeconds,
		GameConfig.networking
	)
end

function RaceService:_playerGraceSeconds(racer)
	return NetworkTiming.graceSeconds(racer.smoothOneWayLatency, GameConfig.networking)
end

function RaceService:_validationDistance(racer, baseDistance, maximumDistance)
	local latency = math.min(
		racer.smoothOneWayLatency or GameConfig.networking.initialOneWayLatencySeconds,
		GameConfig.networking.maximumOneWayLatencySeconds
	)
	return NetworkTiming.validationDistance(
		latency,
		racer.speed * racer.speedMultiplier,
		baseDistance,
		maximumDistance
	)
end

function RaceService:_stampPrompt(racer, event, promptType, sentAt)
	event.promptType = promptType
	event.sentAt = sentAt
	event.graceSeconds = self:_playerGraceSeconds(racer)
	event.resolveAt = NetworkTiming.resolveAt(event.closesAt, event.graceSeconds)
	racer.player:SetAttribute("LastPromptSentAt", sentAt)
	racer.player:SetAttribute("LastPromptOpensAt", event.opensAt)
	racer.player:SetAttribute("LastPromptId", event.id)
	racer.player:SetAttribute("LastPromptType", promptType)
end

function RaceService:_isClientTimestampPlausible(racer, serverNow, clientTimestamp)
	return NetworkTiming.isTimestampPlausible(
		serverNow,
		clientTimestamp,
		GameConfig.reactionWindow.maximumClockDifferenceSeconds + self:_playerGraceSeconds(racer)
	)
end

function RaceService:_configureCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil, nil
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.PlatformStand = false
	updateJumpState(player, character)

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = RACER_COLLISION_GROUP
		end
	end

	pcall(function()
		root:SetNetworkOwner(player)
	end)

	return humanoid, root
end

function RaceService:_getCharacter(player)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		return character
	end

	player:LoadCharacter()
	local deadline = os.clock() + 5
	repeat
		task.wait()
		character = player.Character
	until (character and character:FindFirstChild("HumanoidRootPart")) or os.clock() >= deadline

	return character
end

function RaceService:_prepareRace(eligiblePlayers)
	local activeTrack = self._activeTrack
	if not activeTrack or not activeTrack.model.Parent then
		warn("[BalapKarung] Race dimulai tanpa active track")
		return false
	end

	self._raceId += 1
	self._finishCount = 0
	table.clear(self._racers)
	self:_clearLavaWaves()
	self._lavaEnabled = activeTrack.id == GameConfig.lavaWave.trackId
		or activeTrack.model:GetAttribute("LavaWavesEnabled") == true
	self._lavaGeometry = nil
	if self._lavaEnabled then
		self._lavaGeometry = LavaWaveMechanic.geometryForLanes(
			activeTrack.lanes,
			activeTrack.finish,
			GameConfig.lavaWave.lateralPaddingStuds,
			GameConfig.lavaWave.cleanupPaddingStuds
		)
		if not self._lavaGeometry then
			warn("[BalapKarung] Geometri Lava wave tidak dapat dihitung")
			self._lavaEnabled = false
		end
	end
	Workspace:SetAttribute("LavaWaveActive", self._lavaEnabled)

	local currentPlayers = {}
	for _, player in eligiblePlayers do
		if player.Parent == Players and player:GetAttribute("InStartArea") == true then
			table.insert(currentPlayers, player)
		end
	end
	local minimumPlayers = if GameConfig.TEST_MODE then 1 else GameConfig.race.minimumPlayers
	if #currentPlayers < minimumPlayers then
		return false
	end
	local random = Random.new(self._raceId * 7919)
	for index = #currentPlayers, 2, -1 do
		local otherIndex = random:NextInteger(1, index)
		currentPlayers[index], currentPlayers[otherIndex] =
			currentPlayers[otherIndex], currentPlayers[index]
	end

	local racerCount = math.min(#currentPlayers, #activeTrack.lanes, GameConfig.race.maximumLanes)
	local firstLaneIndex = math.floor((#activeTrack.lanes - racerCount) / 2) + 1
	local breakerZonesByLane = {}
	for _, lane in activeTrack.lanes do
		breakerZonesByLane[lane.index] = getLaneBreakerZones(activeTrack.model, lane)
	end
	validateBreakerFairness(activeTrack.lanes, breakerZonesByLane)

	for playerIndex, player in currentPlayers do
		if playerIndex > racerCount then
			break
		end

		local character = self:_getCharacter(player)
		if not character then
			continue
		end

		setPlayerDefaults(player)
		player:SetAttribute("IsRace", true)
		local humanoid, root = self:_configureCharacter(player, character)
		if not humanoid or not root then
			continue
		end
		SackService.Attach(character)

		local lane = activeTrack.lanes[firstLaneIndex + playerIndex - 1]
		local spawn = lane.spawn
		local spawnPosition = (spawn.CFrame * CFrame.new(
			0,
			spawn.Size.Y / 2 + GameConfig.track.characterSpawnHeight,
			0
		)).Position
		local spawnCFrame = CFrame.lookAt(spawnPosition, spawnPosition + lane.forward)
		character:PivotTo(spawnCFrame)
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		player:SetAttribute("DistanceRemaining", lane.length)
		player:SetAttribute("RaceProgress", 0)
		player:SetAttribute("RaceStatus", "Countdown")
		player:SetAttribute("LaneIndex", lane.index)
		player:SetAttribute("RaceId", self._raceId)
		player:SetAttribute("RaceForward", lane.forward)
		player:SetAttribute("RaceStartOrigin", spawn.Position)
		player:SetAttribute("TrackLength", lane.length)
		player:SetAttribute("AuthoritativeDistance", 0)
		player:SetAttribute("AuthoritativeUpdatedAt", 0)

		self._racers[player] = {
			player = player,
			character = character,
			humanoid = humanoid,
			root = root,
			forward = lane.forward,
			startOrigin = spawn.Position,
			trackLength = lane.length,
			speed = GameConfig.speed.normalValue,
			noMissStreak = 0,
			tempoStage = 1,
			onFire = false,
			onFireEndsAt = 0,
			speedMultiplier = 1,
			boostEndsAt = 0,
			lastReplicationAt = 0,
			authoritativeDistance = 0,
			lastTickAt = 0,
			lastPingSampleAt = -math.huge,
			smoothOneWayLatency = GameConfig.networking.initialOneWayLatencySeconds,
			finished = false,
			recoveringUntil = 0,
			nextNormalPromptAt = 0,
			reaction = nil,
			obstacleReactions = {},
			obstacleSequence = nil,
			activeObstacle = nil,
			obstacles = getLaneObstacles(activeTrack.model, lane),
			breakerZones = breakerZonesByLane[lane.index],
			activeBreakerZone = nil,
			breakerReactions = {},
			pausedOnFireRemaining = 0,
			lavaReaction = nil,
			lavaThreat = nil,
			validInputCount = 0,
			raceId = self._raceId,
		}
	end

	return next(self._racers) ~= nil
end

function RaceService:_clearLavaWaves()
	for _, wave in self._lavaWaves do
		if wave.instance and wave.instance.Parent then
			wave.instance:Destroy()
		end
	end
	table.clear(self._lavaWaves)
	self._nextLavaWaveAt = 0
	Workspace:SetAttribute("LavaWaveActive", false)
end

function RaceService:_setLavaWaveCFrame(wave, distance)
	local geometry = self._lavaGeometry
	if not geometry or not wave.instance or not wave.instance.Parent then
		return
	end
	local position = geometry.origin
		+ geometry.direction * distance
		+ Vector3.yAxis * GameConfig.lavaWave.visualYOffsetStuds
	local cframe = CFrame.lookAt(position, position + geometry.direction)
	if wave.instance:IsA("Model") then
		wave.instance:PivotTo(cframe)
	elseif wave.instance:IsA("BasePart") then
		wave.instance.CFrame = cframe
	end
end

function RaceService:_createLavaWaveVisual(waveId, variant)
	local activeTrack = self._activeTrack
	if not activeTrack or not activeTrack.model.Parent then
		return nil
	end

	local folder = activeTrack.model:FindFirstChild(GameConfig.lavaWave.runtimeFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = GameConfig.lavaWave.runtimeFolderName
		folder.Parent = activeTrack.model
	end

	local template = ReplicatedStorage:FindFirstChild(GameConfig.lavaWave.templateName)
	local visual = nil
	if template and (template:IsA("BasePart") or template:IsA("Model")) then
		visual = template:Clone()
	else
		local part = Instance.new("Part")
		part.Size = Vector3.new(
			self._lavaGeometry.width,
			GameConfig.lavaWave.visualHeightStuds,
			GameConfig.lavaWave.visualDepthStuds
		)
		part.Material = Enum.Material.Neon
		part.Color = variant.color
		part.Transparency = 0.12
		visual = part
	end

	visual.Name = `LavaWave{waveId}`
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Color = variant.color
		end
	end
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		visual.Color = variant.color
	end
	visual:SetAttribute("BalapKarungLavaWave", true)
	visual:SetAttribute("WaveVariant", variant.id)
	visual.Parent = folder
	return visual
end

function RaceService:_spawnSingleLavaWave(now, variant, initialDistance)
	self._lavaWaveId += 1
	local speed = GameConfig.lavaWave.speedStudsPerSecond * variant.speedMultiplier
	local wave = {
		id = self._lavaWaveId,
		spawnedAt = now,
		instance = self:_createLavaWaveVisual(self._lavaWaveId, variant),
		racers = {},
		variantId = variant.id,
		speed = speed,
		initialDistance = initialDistance,
		reactionDuration = GameConfig.lavaWave.reactionDurationSeconds
			* variant.reactionDurationMultiplier,
		promptLeadSeconds = GameConfig.lavaWave.promptLeadSeconds
			* variant.reactionDurationMultiplier,
	}
	if not wave.instance then
		return
	end
	wave.instance:SetAttribute("WaveSpeed", speed)
	self:_setLavaWaveCFrame(wave, initialDistance)
	table.insert(self._lavaWaves, wave)
end

function RaceService:_spawnLavaWave(now)
	local variant =
		LavaWaveMechanic.variantForRoll(GameConfig.lavaWave.variants, self._lavaRandom:NextNumber())
	local speed = GameConfig.lavaWave.speedStudsPerSecond * variant.speedMultiplier
	for waveIndex = 1, variant.waveCount do
		local gapSeconds = variant.waveGapSeconds or 0
		local initialDistance = -(waveIndex - 1) * speed * gapSeconds
		self:_spawnSingleLavaWave(now, variant, initialDistance)
	end
	self._nextLavaWaveAt = now
		+ self._lavaRandom:NextNumber(
			GameConfig.lavaWave.minimumIntervalSeconds,
			GameConfig.lavaWave.maximumIntervalSeconds
		)
end

function RaceService:_startLavaPrompt(racer, wave, waveState, now)
	local normalEvent = racer.reaction
	if normalEvent and not normalEvent.resolved then
		normalEvent.lavaFused = true
		normalEvent.waveState = waveState
		normalEvent.waveId = wave.id
		waveState.prompted = true
		waveState.event = normalEvent
		racer.lavaReaction = normalEvent
		racer.lavaThreat = waveState
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "morph",
			id = normalEvent.id,
			skillId = GameConfig.lavaWave.skillId,
			obstacle = true,
			waveVariant = wave.variantId,
		})
		return
	end

	self._eventId += 1
	local networkLead = self:_playerLeadSeconds(racer, 0)
	local event = {
		id = self._eventId,
		opensAt = now + networkLead,
		closesAt = now + networkLead + wave.reactionDuration,
		duration = wave.reactionDuration,
		resolved = false,
		waveState = waveState,
		waveId = wave.id,
	}
	self:_stampPrompt(racer, event, "Lava", now)
	waveState.prompted = true
	waveState.event = event
	racer.lavaReaction = event
	racer.lavaThreat = waveState

	local random = Random.new(racer.player.UserId + wave.id * 3571)
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "show",
		id = event.id,
		opensAt = event.opensAt,
		duration = event.duration,
		chainIndex = 1,
		chainLength = 1,
		skillId = GameConfig.lavaWave.skillId,
		obstacle = true,
		waveVariant = wave.variantId,
		screenX = random:NextNumber(
			GameConfig.reactionWindow.minimumScreenX,
			GameConfig.reactionWindow.maximumScreenX
		),
		screenY = random:NextNumber(
			GameConfig.reactionWindow.minimumScreenY,
			GameConfig.reactionWindow.maximumScreenY
		),
	})
end

function RaceService:_resolveLavaImpact(racer, waveState)
	if waveState.impacted then
		return
	end
	waveState.impacted = true
	if racer.lavaThreat == waveState then
		racer.lavaThreat = nil
	end
	local event = waveState.event
	if event and not event.resolved then
		event.resolved = true
		if racer.lavaReaction == event then
			racer.lavaReaction = nil
		end
		if racer.reaction == event then
			racer.reaction = nil
		end
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "remove",
			id = event.id,
		})
	end
	if waveState.success then
		racer.player:SetAttribute(
			"LavaWavesDodged",
			(racer.player:GetAttribute("LavaWavesDodged") or 0) + 1
		)
	else
		racer.player:SetAttribute(
			"LavaWavesHit",
			(racer.player:GetAttribute("LavaWavesHit") or 0) + 1
		)
		if not waveState.failureResolved then
			racer.player:SetAttribute("LastLavaVerdict", "Miss")
			self:_resolveReaction(racer, "Miss", nil)
		end
	end
end

function RaceService:_updateLavaWaves(now)
	if not self._lavaEnabled or not self._lavaGeometry then
		return
	end
	if self._nextLavaWaveAt > 0 and now >= self._nextLavaWaveAt then
		self:_spawnLavaWave(now)
	end

	for index = #self._lavaWaves, 1, -1 do
		local wave = self._lavaWaves[index]
		local waveDistance = wave.initialDistance + (now - wave.spawnedAt) * wave.speed
		self:_setLavaWaveCFrame(wave, waveDistance)

		for _, racer in self._racers do
			if racer.finished then
				continue
			end
			local waveState = wave.racers[racer.player]
			if not waveState then
				waveState = {
					prompted = false,
					success = false,
					impacted = false,
					event = nil,
				}
				wave.racers[racer.player] = waveState
			end

			local racerPosition = racer.startOrigin
				+ racer.forward * (racer.authoritativeDistance or 0)
			local racerDistance = (racerPosition - self._lavaGeometry.origin):Dot(
				self._lavaGeometry.direction
			)
			if
				not waveState.prompted
				and not waveState.impacted
				and racerDistance > waveDistance
			then
				local timeToImpact = LavaWaveMechanic.timeToImpact(
					waveDistance,
					racerDistance,
					wave.speed,
					racer.speed * racer.speedMultiplier
				)
				local networkBuffer = self:_playerLeadSeconds(racer, 0)
					+ self:_playerGraceSeconds(racer)
				if timeToImpact <= wave.promptLeadSeconds + networkBuffer then
					self:_startLavaPrompt(racer, wave, waveState, now)
				end
			end

			local event = waveState.event
			if event and not event.resolved and now >= (event.resolveAt or event.closesAt) then
				event.resolved = true
				if racer.lavaReaction == event then
					racer.lavaReaction = nil
				end
			end
			if
				not waveState.impacted
				and waveDistance >= racerDistance - GameConfig.lavaWave.impactToleranceStuds
			then
				self:_resolveLavaImpact(racer, waveState)
			end
		end

		if waveDistance >= self._lavaGeometry.travelDistance then
			if wave.instance and wave.instance.Parent then
				wave.instance:Destroy()
			end
			table.remove(self._lavaWaves, index)
		end
	end
end

function RaceService:_returnPlayersToLobby()
	local lobbySpawn = Workspace:FindFirstChild("SpawnLocation")
	if not lobbySpawn or not lobbySpawn:IsA("BasePart") then
		warn("[BalapKarung] Workspace.SpawnLocation tidak ditemukan")
		return
	end

	for player in self._racers do
		if player.Parent ~= Players then
			continue
		end

		local character = player.Character
		if character then
			SackService.Detach(character)
			moveCharacterToLobby(character)
		end
		setPlayerDefaults(player)
		if character then
			restoreLobbyCharacter(player, character)
		end
	end
end

function RaceService:_startMissRecovery(racer)
	racer.recoveringUntil = Workspace:GetServerTimeNow() + GameConfig.movement.missRecoverySeconds
	racer.speedMultiplier = 1
	racer.boostEndsAt = 0
	racer.player:SetAttribute("SpeedMultiplier", 1)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed)
	racer.player:SetAttribute("BoostEndsAt", 0)
	racer.player:SetAttribute("IsRecovering", true)
	racer.humanoid.PlatformStand = false
	racer.root.Anchored = false
	racer.root.AssemblyLinearVelocity = Vector3.zero
	racer.root.AssemblyAngularVelocity = Vector3.zero
end

function RaceService:_expireOnFire(racer)
	racer.noMissStreak = 0
	racer.tempoStage = 1
	racer.onFire = false
	racer.onFireEndsAt = 0
	racer.speed = GameConfig.speed.normalValue
	racer.player:SetAttribute("Speed", racer.speed)
	racer.player:SetAttribute("NoMissStreak", 0)
	racer.player:SetAttribute("OnFireProgress", 0)
	racer.player:SetAttribute("TempoStage", 1)
	racer.player:SetAttribute("OnFire", false)
	racer.player:SetAttribute("OnFireEndsAt", 0)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed * racer.speedMultiplier)
end

function RaceService:_resolveReaction(racer, verdict, eventId, suppressFeedback)
	if racer.finished then
		return
	end
	-- A normal prompt can expire in the same frame that an obstacle sequence starts.
	-- Once the obstacle owns the input, that stale result must not punish the racer.
	if eventId ~= nil and (racer.activeObstacle or racer.activeBreakerZone) then
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "remove",
			id = eventId,
		})
		return
	end

	local now = Workspace:GetServerTimeNow()
	local wasOnFire = racer.onFire
	racer.noMissStreak, racer.tempoStage, racer.onFire =
		Speed.applyVerdict(racer.noMissStreak, verdict)
	if verdict == "Early" or verdict == "Miss" then
		racer.onFireEndsAt = 0
	elseif racer.onFire and not wasOnFire then
		racer.onFireEndsAt = now + GameConfig.speed.onFireDurationSeconds
	elseif wasOnFire then
		racer.onFire = true
		racer.tempoStage = 3
		racer.noMissStreak = GameConfig.speed.onFireRequiredHits
	end
	racer.speed = Speed.valueForOnFire(racer.onFire)
	racer.player:SetAttribute("Speed", racer.speed)
	racer.player:SetAttribute("NoMissStreak", racer.noMissStreak)
	racer.player:SetAttribute("OnFireProgress", racer.noMissStreak)
	racer.player:SetAttribute("TempoStage", racer.tempoStage)
	racer.player:SetAttribute("OnFireEndsAt", racer.onFireEndsAt)
	racer.player:SetAttribute("OnFire", racer.onFire)
	racer.player:SetAttribute("LastVerdict", verdict)
	if verdict == "Early" or verdict == "Miss" then
		self:_startMissRecovery(racer)
	else
		racer.speedMultiplier = GameConfig.speed.verdictMultiplier[verdict]
		racer.boostEndsAt = now + GameConfig.speed.verdictBoostDurationSeconds[verdict]
		racer.player:SetAttribute("SpeedMultiplier", racer.speedMultiplier)
		racer.player:SetAttribute("EffectiveSpeed", racer.speed * racer.speedMultiplier)
		racer.player:SetAttribute("BoostEndsAt", racer.boostEndsAt)
	end
	if not suppressFeedback then
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "result",
			id = eventId,
			verdict = verdict,
			onFireTriggered = not wasOnFire and racer.onFire,
			onFireEnded = wasOnFire and not racer.onFire,
			progress = racer.noMissStreak,
			multiplier = racer.speedMultiplier,
		})
	end
end

function RaceService:_applyObstacleSuccess(racer, sequence, comboVerdict)
	local now = Workspace:GetServerTimeNow()
	local wasOnFire = racer.onFire
	for _, verdict in sequence.results do
		racer.noMissStreak, racer.tempoStage, racer.onFire =
			Speed.applyVerdict(racer.noMissStreak, verdict)
	end
	if racer.onFire and not wasOnFire then
		racer.onFireEndsAt = now + GameConfig.speed.onFireDurationSeconds
	elseif wasOnFire then
		racer.onFire = true
		racer.tempoStage = 3
		racer.noMissStreak = GameConfig.speed.onFireRequiredHits
	end

	racer.speed = Speed.valueForOnFire(racer.onFire)
	racer.speedMultiplier = GameConfig.obstacle.comboMultiplier[comboVerdict]
	racer.boostEndsAt = now + GameConfig.obstacle.comboBoostDurationSeconds
	racer.player:SetAttribute("Speed", racer.speed)
	racer.player:SetAttribute("NoMissStreak", racer.noMissStreak)
	racer.player:SetAttribute("OnFireProgress", racer.noMissStreak)
	racer.player:SetAttribute("TempoStage", racer.tempoStage)
	racer.player:SetAttribute("OnFireEndsAt", racer.onFireEndsAt)
	racer.player:SetAttribute("OnFire", racer.onFire)
	racer.player:SetAttribute("LastVerdict", comboVerdict)
	racer.player:SetAttribute("SpeedMultiplier", racer.speedMultiplier)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed * racer.speedMultiplier)
	racer.player:SetAttribute("BoostEndsAt", racer.boostEndsAt)

	sequence.obstacle.guardArmed = true
	sequence.obstacle.resolved = true
	racer.player:SetAttribute("GuardReady", true)
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "comboResult",
		verdict = comboVerdict,
		progress = racer.noMissStreak,
		multiplier = racer.speedMultiplier,
	})
end

function RaceService:_finalizeObstacleSequence(racer, sequence)
	if racer.obstacleSequence ~= sequence then
		return
	end

	local comboVerdict =
		ObstacleMechanic.classifyVerdicts(sequence.results, sequence.obstacle.tapCount)
	local perfectCount = 0
	local goodCount = 0
	for _, verdict in sequence.results do
		if verdict == "Perfect" then
			perfectCount += 1
		elseif verdict == "Good" then
			goodCount += 1
		end
	end
	racer.player:SetAttribute("ObstaclePerfectCount", perfectCount)
	racer.player:SetAttribute("ObstacleGoodCount", goodCount)
	racer.player:SetAttribute("LastObstacleCombo", comboVerdict or "Failed")
	if comboVerdict then
		self:_applyObstacleSuccess(racer, sequence, comboVerdict)
	else
		sequence.obstacle.resolved = true
		sequence.obstacle.guardArmed = false
		sequence.obstacle.failed = true
		racer.player:SetAttribute("GuardReady", false)
	end
	racer.obstacleSequence = nil
end

function RaceService:_triggerObstacleCrash(racer, obstacle, initiatorUserId)
	if obstacle.crashed then
		return
	end

	obstacle.crashed = true
	racer.activeObstacle = nil
	local barrier = obstacle.barrier
	if barrier and barrier.Parent then
		barrier.CanCollide = false
		self._guardImpactRemote:FireAllClients({
			barrier = barrier,
			obstacleId = obstacle.id,
			initiatorUserId = initiatorUserId or 0,
			soundUserId = racer.player.UserId,
			throwDirection = obstacle.throwDirection,
			forward = racer.forward,
		})
		task.delay(GameConfig.obstacle.guardReplicationHideDelaySeconds, function()
			if barrier.Parent then
				barrier.Transparency = 1
				barrier.CanQuery = false
			end
		end)
	end
	self:_resolveReaction(racer, "Miss", nil)
	racer.nextNormalPromptAt = Workspace:GetServerTimeNow()
		+ GameConfig.obstacle.failedGuardPromptResumeSeconds
end

function RaceService:_submitObstacleCrash(player, barrier, clientDetectedAt)
	local racer = self._racers[player]
	if
		self._state ~= "Racing"
		or not racer
		or racer.finished
		or type(clientDetectedAt) ~= "number"
		or typeof(barrier) ~= "Instance"
		or not barrier:IsA("BasePart")
	then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	if not self:_isClientTimestampPlausible(racer, serverNow, clientDetectedAt) then
		return
	end
	racer.player:SetAttribute("LastImpactReceivedAt", serverNow)
	racer.player:SetAttribute("LastImpactDetectedAt", clientDetectedAt)

	local obstacle = racer.activeObstacle
	if not obstacle or not obstacle.failed or obstacle.crashed or obstacle.barrier ~= barrier then
		return
	end

	local progress = racer.authoritativeDistance or 0
	local distanceToBarrier = obstacle.barrierProgress - progress
	local validationDistance = self:_validationDistance(
		racer,
		GameConfig.obstacle.guardBaseValidationDistanceStuds,
		GameConfig.obstacle.guardMaxValidationDistanceStuds
	)
	racer.player:SetAttribute("LastImpactValidationDistance", validationDistance)
	if
		distanceToBarrier > validationDistance
		or distanceToBarrier < -GameConfig.obstacle.guardServerFallbackStuds
	then
		return
	end

	self:_triggerObstacleCrash(racer, obstacle, player.UserId)
end

function RaceService:_resolveObstacleReaction(racer, event, verdict)
	if event.resolved then
		return
	end
	event.resolved = true
	racer.obstacleReactions[event.id] = nil
	local sequence = event.sequence
	sequence.results[event.sequenceIndex] = verdict
	sequence.resolvedCount += 1
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "obstacleVerdict",
		id = event.id,
		verdict = verdict,
	})
	if sequence.resolvedCount >= sequence.obstacle.tapCount then
		self:_finalizeObstacleSequence(racer, sequence)
	end
end

function RaceService:_startObstacleSequence(racer, obstacle)
	if racer.finished or racer.activeObstacle or racer.activeBreakerZone or obstacle.started then
		return
	end
	obstacle.started = true
	racer.activeObstacle = obstacle
	racer.player:SetAttribute("LastObstacleCombo", "")

	if racer.reaction and not racer.reaction.resolved then
		racer.reaction.resolved = true
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "remove",
			id = racer.reaction.id,
		})
		racer.reaction = nil
	end

	local sequence = {
		obstacle = obstacle,
		results = {},
		resolvedCount = 0,
	}
	racer.obstacleSequence = sequence
	local sentAt = Workspace:GetServerTimeNow()
	local startsAt = sentAt + self:_playerLeadSeconds(racer, 0)
	local random = Random.new(racer.player.UserId + self._raceId * 1009 + self._eventId)
	local positions = ObstacleMechanic.generatePromptPositions(random, obstacle.tapCount, {
		minimumX = GameConfig.reactionWindow.minimumScreenX,
		maximumX = GameConfig.reactionWindow.maximumScreenX,
		minimumY = GameConfig.reactionWindow.minimumScreenY,
		maximumY = GameConfig.reactionWindow.maximumScreenY,
	}, GameConfig.obstacle.promptMinimumDistance, GameConfig.obstacle.promptPositionAttempts)

	for sequenceIndex = 1, obstacle.tapCount do
		self._eventId += 1
		local opensAt = startsAt + (sequenceIndex - 1) * GameConfig.obstacle.promptSpawnGapSeconds
		local event = {
			id = self._eventId,
			opensAt = opensAt,
			closesAt = opensAt + GameConfig.obstacle.reactionDurationSeconds,
			duration = GameConfig.obstacle.reactionDurationSeconds,
			resolved = false,
			sequence = sequence,
			sequenceIndex = sequenceIndex,
		}
		self:_stampPrompt(racer, event, "Obstacle", sentAt)
		racer.obstacleReactions[event.id] = event
		local position = positions[sequenceIndex]
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "show",
			id = event.id,
			opensAt = event.opensAt,
			duration = event.duration,
			screenX = position.x,
			screenY = position.y,
			obstacle = true,
			sequenceIndex = sequenceIndex,
			sequenceLength = obstacle.tapCount,
			skillId = obstacle.skillId,
		})

		task.spawn(function()
			while
				self._state == "Racing"
				and not racer.finished
				and not event.resolved
				and Workspace:GetServerTimeNow() <= event.resolveAt
			do
				task.wait()
			end
			if not event.resolved and not racer.finished then
				self:_resolveObstacleReaction(racer, event, "Miss")
			end
		end)
	end
end

function RaceService:_triggerGuardImpact(racer, obstacle, initiatorUserId)
	if obstacle.guardUsed then
		return
	end

	obstacle.guardUsed = true
	obstacle.guardArmed = false
	racer.activeObstacle = nil
	racer.player:SetAttribute("GuardReady", false)
	racer.player:SetAttribute("LastGuardImpact", obstacle.id)

	local barrier = obstacle.barrier
	if barrier and barrier.Parent then
		barrier.CanCollide = false
		self._guardImpactRemote:FireAllClients({
			barrier = barrier,
			obstacleId = obstacle.id,
			initiatorUserId = initiatorUserId,
			soundUserId = racer.player.UserId,
			throwDirection = obstacle.throwDirection,
			forward = racer.forward,
		})
		task.delay(GameConfig.obstacle.guardReplicationHideDelaySeconds, function()
			if barrier.Parent then
				barrier.Transparency = 1
				barrier.CanQuery = false
			end
		end)
	end
end

function RaceService:_submitGuardImpact(player, barrier, clientDetectedAt)
	local racer = self._racers[player]
	if
		self._state ~= "Racing"
		or not racer
		or racer.finished
		or type(clientDetectedAt) ~= "number"
		or typeof(barrier) ~= "Instance"
		or not barrier:IsA("BasePart")
	then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	if not self:_isClientTimestampPlausible(racer, serverNow, clientDetectedAt) then
		return
	end
	racer.player:SetAttribute("LastImpactReceivedAt", serverNow)
	racer.player:SetAttribute("LastImpactDetectedAt", clientDetectedAt)

	local obstacle = racer.activeObstacle
	if
		not obstacle
		or not obstacle.guardArmed
		or obstacle.guardUsed
		or obstacle.barrier ~= barrier
	then
		return
	end

	local progress = racer.authoritativeDistance or 0
	local distanceToBarrier = obstacle.barrierProgress - progress
	local validationDistance = self:_validationDistance(
		racer,
		GameConfig.obstacle.guardBaseValidationDistanceStuds,
		GameConfig.obstacle.guardMaxValidationDistanceStuds
	)
	racer.player:SetAttribute("LastImpactValidationDistance", validationDistance)
	if
		distanceToBarrier > validationDistance
		or distanceToBarrier < -GameConfig.obstacle.guardServerFallbackStuds
	then
		return
	end

	self:_triggerGuardImpact(racer, obstacle, player.UserId)
end

function RaceService:_startBreakerZone(racer, zone)
	if racer.finished or racer.activeObstacle or racer.activeBreakerZone or zone.started then
		return
	end

	zone.started = true
	racer.activeBreakerZone = zone
	racer.player:SetAttribute("BreakerActive", true)
	racer.player:SetAttribute("BreakerChain", 0)
	racer.player:SetAttribute("LastBreakerVerdict", "")
	if racer.onFire and racer.onFireEndsAt > 0 then
		racer.pausedOnFireRemaining = math.max(0, racer.onFireEndsAt - Workspace:GetServerTimeNow())
		racer.onFireEndsAt = 0
		racer.player:SetAttribute("OnFireEndsAt", 0)
	end

	if racer.reaction and not racer.reaction.resolved then
		racer.reaction.resolved = true
		self._reactionWindowRemote:FireClient(racer.player, {
			action = "remove",
			id = racer.reaction.id,
		})
		racer.reaction = nil
	end

	-- Temporary normal boosts would make the same physical spacing produce wildly
	-- different Breaker timings. Breaker keeps Normal/OnFire speed, but owns its tempo.
	racer.speedMultiplier = 1
	racer.boostEndsAt = 0
	racer.player:SetAttribute("SpeedMultiplier", 1)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed)
	racer.player:SetAttribute("BoostEndsAt", 0)
end

function RaceService:_endBreakerZone(racer, zone)
	if racer.activeBreakerZone ~= zone then
		return
	end

	zone.completed = true
	racer.activeBreakerZone = nil
	for eventId, event in racer.breakerReactions do
		if event.zone == zone then
			event.resolved = true
			racer.breakerReactions[eventId] = nil
			self._reactionWindowRemote:FireClient(racer.player, {
				action = "remove",
				id = eventId,
			})
		end
	end
	racer.player:SetAttribute("BreakerActive", false)
	if racer.onFire and racer.pausedOnFireRemaining > 0 then
		racer.onFireEndsAt = Workspace:GetServerTimeNow() + racer.pausedOnFireRemaining
		racer.player:SetAttribute("OnFireEndsAt", racer.onFireEndsAt)
	end
	racer.pausedOnFireRemaining = 0
	racer.nextNormalPromptAt = Workspace:GetServerTimeNow()
	self._breakerStateRemote:FireClient(racer.player, { action = "clear" })
end

function RaceService:_resolveBreakerReaction(racer, event, verdict)
	if event.resolved then
		return
	end
	event.resolved = true
	racer.breakerReactions[event.id] = nil
	local obstacle = event.obstacle
	obstacle.verdict = verdict
	local success = verdict == "Good" or verdict == "Perfect"
	if success then
		local chain = (racer.player:GetAttribute("BreakerChain") or 0) + 1
		racer.player:SetAttribute("BreakerChain", chain)
	else
		racer.player:SetAttribute("BreakerChain", 0)
	end
	racer.player:SetAttribute("LastBreakerVerdict", verdict)
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "breakerResult",
		id = event.id,
		verdict = verdict,
	})
	self._breakerStateRemote:FireClient(racer.player, {
		action = "resolved",
		obstacle = obstacle.root,
		impactPart = obstacle.impactPart,
		success = success,
		throwDirection = obstacle.throwDirection,
		forward = racer.forward,
	})
end

function RaceService:_startBreakerPrompt(racer, zone, obstacle)
	if obstacle.promptStarted or obstacle.impacted then
		return
	end

	obstacle.promptStarted = true
	self._eventId += 1
	local now = Workspace:GetServerTimeNow()
	local networkLead = self:_playerLeadSeconds(racer, 0)
	local random =
		Random.new(racer.player.UserId + self._raceId * 2027 + math.floor(obstacle.progress * 10))
	local positions = ObstacleMechanic.generatePromptPositions(random, 1, {
		minimumX = GameConfig.reactionWindow.minimumScreenX,
		maximumX = GameConfig.reactionWindow.maximumScreenX,
		minimumY = GameConfig.reactionWindow.minimumScreenY,
		maximumY = GameConfig.reactionWindow.maximumScreenY,
	}, GameConfig.breaker.promptMinimumDistance, GameConfig.breaker.promptPositionAttempts)
	local event = {
		id = self._eventId,
		opensAt = now + networkLead,
		closesAt = now + networkLead + GameConfig.breaker.reactionDurationSeconds,
		duration = GameConfig.breaker.reactionDurationSeconds,
		resolved = false,
		zone = zone,
		obstacle = obstacle,
	}
	self:_stampPrompt(racer, event, "Breaker", now)
	obstacle.event = event
	racer.breakerReactions[event.id] = event
	local position = positions[1]
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "show",
		id = event.id,
		opensAt = event.opensAt,
		duration = event.duration,
		screenX = position.x,
		screenY = position.y,
		obstacle = true,
		breaker = true,
		sequenceIndex = obstacle.index,
		sequenceLength = #zone.obstacles,
		skillId = GameConfig.breaker.skillId,
	})

	task.spawn(function()
		while
			self._state == "Racing"
			and not racer.finished
			and racer.activeBreakerZone == zone
			and not event.resolved
			and Workspace:GetServerTimeNow() <= event.resolveAt
		do
			task.wait()
		end
		if not event.resolved and not racer.finished and racer.activeBreakerZone == zone then
			self:_resolveBreakerReaction(racer, event, "Miss")
		end
	end)
end

function RaceService:_triggerBreakerImpact(racer, obstacle, initiatorUserId)
	if obstacle.impacted then
		return
	end
	if obstacle.event and not obstacle.event.resolved then
		self:_resolveBreakerReaction(racer, obstacle.event, "Miss")
	end

	obstacle.impacted = true
	local success = obstacle.verdict == "Good" or obstacle.verdict == "Perfect"
	self._breakerImpactRemote:FireAllClients({
		obstacle = obstacle.root,
		impactPart = obstacle.impactPart,
		obstacleId = obstacle.id,
		initiatorUserId = initiatorUserId or 0,
		soundUserId = racer.player.UserId,
		success = success,
		throwDirection = obstacle.throwDirection,
		forward = racer.forward,
	})
	if not success then
		racer.pausedOnFireRemaining = 0
		self:_resolveReaction(racer, "Miss", nil, true)
	end
end

function RaceService:_submitBreakerImpact(player, impactPart, clientDetectedAt)
	local racer = self._racers[player]
	if
		self._state ~= "Racing"
		or not racer
		or racer.finished
		or not racer.activeBreakerZone
		or type(clientDetectedAt) ~= "number"
		or typeof(impactPart) ~= "Instance"
		or not impactPart:IsA("BasePart")
	then
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	if not self:_isClientTimestampPlausible(racer, serverNow, clientDetectedAt) then
		return
	end
	racer.player:SetAttribute("LastImpactReceivedAt", serverNow)
	racer.player:SetAttribute("LastImpactDetectedAt", clientDetectedAt)

	local obstacle = nil
	for _, candidate in racer.activeBreakerZone.obstacles do
		if candidate.impactPart == impactPart then
			obstacle = candidate
			break
		end
	end
	if not obstacle or obstacle.impacted or not obstacle.verdict then
		return
	end

	local progress = racer.authoritativeDistance or 0
	local distanceToImpact = obstacle.progress - progress
	local validationDistance = self:_validationDistance(
		racer,
		GameConfig.breaker.baseValidationDistanceStuds,
		GameConfig.breaker.maxValidationDistanceStuds
	)
	racer.player:SetAttribute("LastImpactValidationDistance", validationDistance)
	if
		distanceToImpact > validationDistance
		or distanceToImpact < -GameConfig.breaker.serverFallbackStuds
	then
		return
	end
	self:_triggerBreakerImpact(racer, obstacle, player.UserId)
end

function RaceService:_updateBreakerZone(racer, progress)
	local zone = racer.activeBreakerZone
	if not zone then
		for _, candidate in racer.breakerZones do
			if
				not candidate.started
				and progress >= candidate.activationProgress
				and progress < candidate.endProgress
			then
				self:_startBreakerZone(racer, candidate)
				zone = racer.activeBreakerZone
				break
			end
		end
	end
	if not zone then
		return
	end

	if progress >= zone.endProgress then
		self:_endBreakerZone(racer, zone)
		return
	end
	if racer.recoveringUntil > 0 then
		return
	end

	local effectiveSpeed = math.max(racer.speed * racer.speedMultiplier, 0.001)
	local promptLeadSeconds = GameConfig.breaker.promptLeadSeconds
		+ self:_playerLeadSeconds(racer, 0)
		+ self:_playerGraceSeconds(racer)
	for _, obstacle in zone.obstacles do
		local distanceToImpact = obstacle.progress - progress
		if
			not obstacle.promptStarted
			and distanceToImpact >= 0
			and distanceToImpact / effectiveSpeed <= promptLeadSeconds
		then
			self:_startBreakerPrompt(racer, zone, obstacle)
		end
		if
			not obstacle.impacted
			and progress >= obstacle.progress - GameConfig.breaker.serverFallbackStuds
		then
			self:_triggerBreakerImpact(racer, obstacle, 0)
		end
	end
end

function RaceService:_isNormalPromptTooCloseToObstacle(racer, promptDuration)
	local progress = racer.authoritativeDistance or 0
	local nextTriggerProgress = nil
	for _, obstacle in racer.obstacles do
		if not obstacle.started and obstacle.triggerProgress >= progress then
			nextTriggerProgress = obstacle.triggerProgress
			break
		end
	end
	for _, zone in racer.breakerZones do
		if
			not zone.started
			and zone.activationProgress >= progress
			and (not nextTriggerProgress or zone.activationProgress < nextTriggerProgress)
		then
			nextTriggerProgress = zone.activationProgress
			break
		end
	end
	if not nextTriggerProgress then
		return false
	end

	local effectiveSpeed = math.max(racer.speed * racer.speedMultiplier, 0.001)
	local secondsUntilTrigger = (nextTriggerProgress - progress) / effectiveSpeed
	return secondsUntilTrigger
		<= promptDuration
			+ self:_playerLeadSeconds(racer, GameConfig.reactionWindow.scheduleLeadSeconds)
			+ self:_playerGraceSeconds(racer)
			+ GameConfig.obstacle.normalPromptBufferSeconds
end

function RaceService:_runReactionLoop(racer)
	local random = Random.new(racer.player.UserId + self._raceId * 1000)

	while self._state == "Racing" and not racer.finished and racer.raceId == self._raceId do
		if racer.activeObstacle or racer.activeBreakerZone or racer.lavaThreat then
			task.wait(0.05)
			continue
		end
		local tempo = Speed.tempoForProgress(racer.noMissStreak)
		if racer.nextNormalPromptAt > 0 then
			task.wait(math.max(0, racer.nextNormalPromptAt - Workspace:GetServerTimeNow()))
			racer.nextNormalPromptAt = 0
		elseif racer.tempoStage == 1 then
			task.wait(random:NextNumber(tempo.minimumIntervalSeconds, tempo.maximumIntervalSeconds))
		end

		if self._state ~= "Racing" or racer.finished or racer.raceId ~= self._raceId then
			break
		end
		if racer.activeObstacle or racer.activeBreakerZone or racer.lavaThreat then
			continue
		end

		local chainLength = if racer.tempoStage >= 2
			then 1
			else random:NextInteger(
				GameConfig.reactionWindow.minimumChainLength,
				GameConfig.reactionWindow.maximumChainLength
			)

		for chainIndex = 1, chainLength do
			if
				self._state ~= "Racing"
				or racer.finished
				or racer.raceId ~= self._raceId
				or racer.activeObstacle
				or racer.activeBreakerZone
				or racer.lavaThreat
			then
				break
			end

			self._eventId += 1
			local currentTempo = Speed.tempoForProgress(racer.noMissStreak)
			local duration = currentTempo.reactionDurationSeconds
			if self:_isNormalPromptTooCloseToObstacle(racer, duration) then
				-- Faster tempo stages skip the interval above. Yield here so prompt
				-- suppression near an obstacle cannot spin until the script times out.
				task.wait(GameConfig.obstacle.promptSuppressionPollSeconds)
				break
			end
			local sentAt = Workspace:GetServerTimeNow()
			local baseLead = if racer.tempoStage >= 2
				then 0
				else GameConfig.reactionWindow.scheduleLeadSeconds
			local scheduleLead = self:_playerLeadSeconds(racer, baseLead)
			local opensAt = sentAt + scheduleLead
			local event = {
				id = self._eventId,
				opensAt = opensAt,
				closesAt = opensAt + duration,
				duration = duration,
				resolved = false,
			}
			self:_stampPrompt(racer, event, "Normal", sentAt)
			racer.reaction = event

			self._reactionWindowRemote:FireClient(racer.player, {
				action = "show",
				id = event.id,
				opensAt = event.opensAt,
				duration = duration,
				chainIndex = chainIndex,
				chainLength = chainLength,
				skillId = GameConfig.reactionWindow.skillId,
				screenX = random:NextNumber(
					GameConfig.reactionWindow.minimumScreenX,
					GameConfig.reactionWindow.maximumScreenX
				),
				screenY = random:NextNumber(
					GameConfig.reactionWindow.minimumScreenY,
					GameConfig.reactionWindow.maximumScreenY
				),
			})

			while
				self._state == "Racing"
				and not racer.finished
				and not event.resolved
				and Workspace:GetServerTimeNow() <= event.resolveAt
			do
				task.wait()
			end

			if self._state ~= "Racing" or racer.finished or racer.raceId ~= self._raceId then
				break
			end

			if not event.resolved then
				event.resolved = true
				racer.reaction = nil
				if event.lavaFused and event.waveState then
					event.waveState.failureResolved = true
					if racer.lavaReaction == event then
						racer.lavaReaction = nil
					end
					racer.player:SetAttribute("LastLavaVerdict", "Miss")
				end
				self:_resolveReaction(racer, "Miss", event.id)
				break
			end

			if racer.activeObstacle or racer.activeBreakerZone or racer.lavaThreat then
				break
			elseif chainIndex < chainLength then
				task.wait(Speed.tempoForProgress(racer.noMissStreak).chainGapSeconds)
			end
		end
	end
end

function RaceService:_submitReaction(player, eventId, clientPressedAt)
	local racer = self._racers[player]
	if self._state ~= "Racing" or not racer or racer.finished then
		return
	end
	if type(clientPressedAt) ~= "number" then
		return
	end

	local serverNow = Workspace:GetServerTimeNow()
	if not self:_isClientTimestampPlausible(racer, serverNow, clientPressedAt) then
		return
	end
	racer.player:SetAttribute("LastReactionReceivedAt", serverNow)
	racer.player:SetAttribute("LastReactionPressedAt", clientPressedAt)
	racer.player:SetAttribute("LastReactionEventId", eventId)

	local lavaEvent = racer.lavaReaction
	if lavaEvent and not lavaEvent.resolved and lavaEvent.id == eventId then
		local reactionSeconds = NetworkTiming.reactionSeconds(lavaEvent, clientPressedAt)
		if reactionSeconds == nil then
			return
		end
		local verdict = Reaction.verdictFor(reactionSeconds, lavaEvent.duration)
		if verdict then
			lavaEvent.resolved = true
			racer.lavaReaction = nil
			racer.validInputCount += 1
			racer.player:SetAttribute("RaceValidInputs", racer.validInputCount)
			lavaEvent.waveState.success = verdict == "Good" or verdict == "Perfect"
			racer.player:SetAttribute("LastLavaVerdict", verdict)
			if lavaEvent.lavaFused then
				if racer.reaction == lavaEvent then
					racer.reaction = nil
				end
				if not lavaEvent.waveState.success then
					lavaEvent.waveState.failureResolved = true
				end
				self:_resolveReaction(racer, verdict, lavaEvent.id)
			else
				self._reactionWindowRemote:FireClient(racer.player, {
					action = "result",
					id = lavaEvent.id,
					verdict = verdict,
				})
			end
		end
		return
	end

	local breakerEvent = racer.breakerReactions[eventId]
	if breakerEvent and not breakerEvent.resolved then
		local reactionSeconds = NetworkTiming.reactionSeconds(breakerEvent, clientPressedAt)
		if reactionSeconds == nil then
			return
		end
		local verdict = Reaction.verdictFor(reactionSeconds, breakerEvent.duration)
		if verdict then
			racer.validInputCount += 1
			racer.player:SetAttribute("RaceValidInputs", racer.validInputCount)
			self:_resolveBreakerReaction(racer, breakerEvent, verdict)
		end
		return
	end

	local obstacleEvent = racer.obstacleReactions[eventId]
	if obstacleEvent and not obstacleEvent.resolved then
		local reactionSeconds = NetworkTiming.reactionSeconds(obstacleEvent, clientPressedAt)
		if reactionSeconds == nil then
			return
		end
		local verdict = Reaction.verdictFor(reactionSeconds, obstacleEvent.duration)
		if verdict then
			racer.validInputCount += 1
			racer.player:SetAttribute("RaceValidInputs", racer.validInputCount)
			self:_resolveObstacleReaction(racer, obstacleEvent, verdict)
		end
		return
	end

	local event = racer.reaction
	if not event or event.resolved or event.id ~= eventId then
		return
	end

	local reactionSeconds = NetworkTiming.reactionSeconds(event, clientPressedAt)
	if reactionSeconds == nil then
		return
	end
	local verdict = Reaction.verdictFor(reactionSeconds, event.duration)
	if not verdict then
		return
	end

	event.resolved = true
	racer.reaction = nil
	racer.validInputCount += 1
	racer.player:SetAttribute("RaceValidInputs", racer.validInputCount)
	self:_resolveReaction(racer, verdict, event.id)
end

function RaceService:_finishRacer(racer)
	if racer.finished then
		return
	end

	racer.finished = true
	racer.reaction = nil
	racer.lavaReaction = nil
	racer.lavaThreat = nil
	table.clear(racer.obstacleReactions)
	racer.obstacleSequence = nil
	racer.activeObstacle = nil
	table.clear(racer.breakerReactions)
	racer.activeBreakerZone = nil
	self._finishCount += 1

	local finishTime = Workspace:GetServerTimeNow() - self._raceStartedAt
	racer.player:SetAttribute("DistanceRemaining", 0)
	racer.player:SetAttribute("RaceProgress", 1)
	racer.player:SetAttribute("AuthoritativeDistance", racer.trackLength)
	racer.player:SetAttribute("FinishTime", finishTime)
	racer.player:SetAttribute("Rank", self._finishCount)
	if self._dataService then
		self._dataService:RecordRaceResult(
			racer.player,
			self._finishCount == 1,
			self._finishCount,
			racer.validInputCount
		)
	end
	racer.player:SetAttribute("RaceStatus", "Finished")
	racer.player:SetAttribute("IsRecovering", false)
	racer.player:SetAttribute("GuardReady", false)
	racer.player:SetAttribute("BreakerActive", false)
	self:_expireOnFire(racer)
	racer.speedMultiplier = 1
	racer.boostEndsAt = 0
	racer.player:SetAttribute("SpeedMultiplier", 1)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed)
	racer.player:SetAttribute("BoostEndsAt", 0)
	racer.humanoid.PlatformStand = false
	racer.root.Anchored = false
	racer.root.AssemblyLinearVelocity = Vector3.zero
	racer.root.AssemblyAngularVelocity = Vector3.zero
	pcall(function()
		racer.root:SetNetworkOwner(nil)
	end)
	self._reactionWindowRemote:FireClient(racer.player, { action = "hide" })
	self._breakerStateRemote:FireClient(racer.player, { action = "clear" })
end

function RaceService:_updateRacers()
	local now = Workspace:GetServerTimeNow()

	for player, racer in self._racers do
		if racer.finished then
			continue
		end

		if player.Parent ~= Players or not racer.root.Parent or racer.humanoid.Health <= 0 then
			racer.finished = true
			racer.withdrawn = true
			player:SetAttribute("RaceStatus", "Waiting")
			continue
		end

		if racer.onFire and racer.onFireEndsAt > 0 and now >= racer.onFireEndsAt then
			self:_expireOnFire(racer)
		end

		if racer.recoveringUntil > 0 and now >= racer.recoveringUntil then
			racer.recoveringUntil = 0
			racer.humanoid.PlatformStand = false
			racer.root.Anchored = false
			racer.root.AssemblyLinearVelocity = Vector3.zero
			racer.root.AssemblyAngularVelocity = Vector3.zero
			player:SetAttribute("IsRecovering", false)
		end

		if racer.boostEndsAt > 0 and now >= racer.boostEndsAt then
			racer.speedMultiplier = 1
			racer.boostEndsAt = 0
			player:SetAttribute("SpeedMultiplier", 1)
			player:SetAttribute("EffectiveSpeed", racer.speed)
			player:SetAttribute("BoostEndsAt", 0)
		end

		local speed = racer.speed
		local effectiveSpeed = speed * racer.speedMultiplier
		local forwardSpeed = if racer.recoveringUntil > 0 then 0 else effectiveSpeed
		local deltaTime = math.max(0, now - racer.lastTickAt)
		racer.lastTickAt = now
		racer.authoritativeDistance = MovementPrediction.advanceDistance(
			racer.authoritativeDistance,
			forwardSpeed,
			deltaTime,
			racer.trackLength
		)
		local progress = racer.authoritativeDistance
		self:_updateBreakerZone(racer, progress)
		local obstacleTriggerLeadStuds = effectiveSpeed
			* (self:_playerLeadSeconds(racer, 0) + self:_playerGraceSeconds(racer))

		for _, obstacle in racer.obstacles do
			if
				not obstacle.started
				and progress >= obstacle.triggerProgress - obstacleTriggerLeadStuds
			then
				self:_startObstacleSequence(racer, obstacle)
				break
			end

			if
				obstacle.started
				and not obstacle.resolved
				and progress >= obstacle.impactProgress
			then
				local unresolvedEvents = {}
				for _, event in racer.obstacleReactions do
					if event.sequence == racer.obstacleSequence and not event.resolved then
						table.insert(unresolvedEvents, event)
					end
				end
				for _, event in unresolvedEvents do
					self:_resolveObstacleReaction(racer, event, "Miss")
				end
			end

			if obstacle.failed and not obstacle.crashed and progress >= obstacle.crashProgress then
				self:_triggerObstacleCrash(racer, obstacle)
			end

			if
				obstacle.guardArmed
				and not obstacle.guardUsed
				and progress
					>= obstacle.barrierProgress - GameConfig.obstacle.guardServerFallbackStuds
			then
				self:_triggerGuardImpact(racer, obstacle, 0)
			end
		end
		if now - racer.lastReplicationAt >= 0.1 then
			racer.lastReplicationAt = now
			self:_refreshNetworkTiming(racer, now, false)
			player:SetAttribute("Speed", speed)
			player:SetAttribute("EffectiveSpeed", effectiveSpeed)
			player:SetAttribute("DistanceRemaining", math.max(0, racer.trackLength - progress))
			player:SetAttribute("RaceProgress", progress / racer.trackLength)
			player:SetAttribute("AuthoritativeUpdatedAt", now)
			player:SetAttribute("AuthoritativeDistance", progress)
		end

		if progress >= racer.trackLength then
			self:_finishRacer(racer)
		end
	end
end

function RaceService:_hasActiveRacers()
	for _, racer in self._racers do
		if not racer.finished then
			return true
		end
	end
	return false
end

function RaceService:_buildPodiumResults()
	local results = {}
	for player, racer in self._racers do
		if player.Parent == Players and not racer.withdrawn then
			table.insert(results, {
				userId = player.UserId,
				name = player.Name,
				displayName = player.DisplayName,
				rank = player:GetAttribute("Rank") or 0,
				finishTime = player:GetAttribute("FinishTime") or 0,
				status = player:GetAttribute("RaceStatus") or "Finished",
			})
		end
	end
	table.sort(results, function(left, right)
		if left.rank <= 0 then
			return false
		elseif right.rank <= 0 then
			return true
		end
		return left.rank < right.rank
	end)
	return {
		raceId = self._raceId,
		results = results,
	}
end

function RaceService:_runRace(eligiblePlayers)
	if not self:_prepareRace(eligiblePlayers) then
		return
	end

	for countdown = GameConfig.race.countdownSeconds, 1, -1 do
		self:_setState("Countdown", countdown)
		task.wait(1)
	end
	self:_setState("Countdown", 0)
	task.wait(GameConfig.race.startSignalSeconds)

	self:_setState("Racing")
	self._raceStartedAt = Workspace:GetServerTimeNow()
	if self._lavaEnabled then
		self._nextLavaWaveAt = self._raceStartedAt + GameConfig.lavaWave.firstWaveDelaySeconds
	end
	for _, racer in self._racers do
		racer.authoritativeDistance = 0
		racer.lastTickAt = self._raceStartedAt
		racer.player:SetAttribute("AuthoritativeDistance", 0)
		racer.player:SetAttribute("AuthoritativeUpdatedAt", self._raceStartedAt)
		racer.root.Anchored = false
		pcall(function()
			racer.root:SetNetworkOwner(racer.player)
		end)
		racer.player:SetAttribute("RaceStatus", "Racing")
		task.spawn(function()
			self:_runReactionLoop(racer)
		end)
	end

	while self:_hasActiveRacers() do
		task.wait(0.1)
	end
	self:_clearLavaWaves()

	local participants = {}
	for player, racer in self._racers do
		if player.Parent == Players and not racer.withdrawn then
			table.insert(participants, player)
		end
	end
	local podiumPayload = self:_buildPodiumResults()
	self:_setState("Results")
	task.wait(GameConfig.race.finishCelebrationSeconds)
	self:_returnPlayersToLobby()
	task.wait()
	for _, player in participants do
		if player.Parent == Players then
			self._podiumResultsRemote:FireClient(player, podiumPayload)
		end
	end
	task.wait(GameConfig.race.resultsSeconds)
end

function RaceService:Start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RACER_COLLISION_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GUARD_DEBRIS_COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(RACER_COLLISION_GROUP, RACER_COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(
		RACER_COLLISION_GROUP,
		GUARD_DEBRIS_COLLISION_GROUP,
		false
	)

	local function registerPlayer(player)
		setPlayerDefaults(player)
		player:GetAttributeChangedSignal("OnFire"):Connect(function()
			updateOnFireAura(player, player.Character)
		end)
		player:GetAttributeChangedSignal("GuardReady"):Connect(function()
			updateGuardShield(player, player.Character)
		end)
		player:GetAttributeChangedSignal("IsRace"):Connect(function()
			if player.Character then
				updateJumpState(player, player.Character)
				if player:GetAttribute("IsRace") == true then
					SackService.Attach(player.Character)
				else
					SackService.Detach(player.Character)
				end
			end
		end)

		local function handleCharacter(character)
			task.spawn(function()
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if not root or player.Character ~= character then
					return
				end
				if player:GetAttribute("IsRace") == true then
					updateJumpState(player, character)
					SackService.Attach(character)
				else
					SackService.Detach(character)
					restoreLobbyCharacter(player, character)
					moveCharacterToLobby(character)
				end
				updateOnFireAura(player, character)
				updateGuardShield(player, character)
			end)
		end

		player.CharacterAdded:Connect(handleCharacter)
		if player.Character then
			handleCharacter(player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)

	self._submitReactionRemote.OnServerEvent:Connect(function(player, eventId, clientPressedAt)
		self:_submitReaction(player, eventId, clientPressedAt)
	end)
	self._submitGuardImpactRemote.OnServerEvent:Connect(function(player, barrier, clientDetectedAt)
		self:_submitGuardImpact(player, barrier, clientDetectedAt)
	end)
	self._submitBreakerImpactRemote.OnServerEvent:Connect(
		function(player, impactPart, clientDetectedAt)
			self:_submitBreakerImpact(player, impactPart, clientDetectedAt)
		end
	)
	self._submitObstacleCrashRemote.OnServerEvent:Connect(
		function(player, barrier, clientDetectedAt)
			self:_submitObstacleCrash(player, barrier, clientDetectedAt)
		end
	)

	RunService.Heartbeat:Connect(function()
		if self._state == "Racing" then
			self:_updateRacers()
			self:_updateLavaWaves(Workspace:GetServerTimeNow())
		end
	end)

	task.spawn(function()
		while true do
			if GameConfig.TEST_MODE then
				self:_setState("Waiting")
				while #Players:GetPlayers() < 1 do
					task.wait(0.1)
				end

				local activeTrack, trackProblem =
					self._trackService:ActivateTrackById(GameConfig.TEST_TRACK_ID)
				if not activeTrack then
					Workspace:SetAttribute("TrackSetupError", trackProblem)
					warn(`[BalapKarung] Test track setup error: {trackProblem}`)
					task.wait(1)
					continue
				end

				self._activeTrack = activeTrack
				Workspace:SetAttribute("TrackSetupError", "")
				local testPlayers = Players:GetPlayers()
				for _, player in testPlayers do
					player:SetAttribute("InStartArea", true)
				end
				Workspace:SetAttribute("PlayersInStartArea", #testPlayers)
				self:_setState("Intermission", GameConfig.TEST_COUNTDOWN)
				for remaining = GameConfig.TEST_COUNTDOWN, 1, -1 do
					Workspace:SetAttribute("Countdown", remaining)
					task.wait(1)
				end
				self:_runRace(Players:GetPlayers())
				continue
			end

			self:_setState("Waiting")
			local queuedPlayers = getPlayersInStartArea()
			while #queuedPlayers < GameConfig.race.minimumPlayers do
				task.wait(GameConfig.queue.scanIntervalSeconds)
				queuedPlayers = getPlayersInStartArea()
			end

			local activeTrack, trackProblem = self._trackService:ActivateNextTrack()
			if not activeTrack then
				Workspace:SetAttribute("TrackSetupError", trackProblem)
				warn(`[BalapKarung] Track setup error: {trackProblem}`)
				task.wait(1)
				continue
			end

			self._activeTrack = activeTrack
			Workspace:SetAttribute("TrackSetupError", "")

			local countdownCompleted = false
			while not countdownCompleted do
				self:_setState("Intermission", GameConfig.race.intermissionSeconds)
				local cancelled = false
				for remaining = GameConfig.race.intermissionSeconds, 1, -1 do
					Workspace:SetAttribute("Countdown", remaining)
					local secondEndsAt = Workspace:GetServerTimeNow() + 1
					repeat
						queuedPlayers = getPlayersInStartArea()
						if #queuedPlayers < GameConfig.race.minimumPlayers then
							cancelled = true
							break
						end
						task.wait(GameConfig.queue.scanIntervalSeconds)
					until Workspace:GetServerTimeNow() >= secondEndsAt
					if cancelled then
						break
					end
				end

				if cancelled then
					self:_setState("Waiting")
					repeat
						task.wait(GameConfig.queue.scanIntervalSeconds)
						queuedPlayers = getPlayersInStartArea()
					until #queuedPlayers >= GameConfig.race.minimumPlayers
				else
					queuedPlayers = getPlayersInStartArea()
					countdownCompleted = #queuedPlayers >= GameConfig.race.minimumPlayers
				end
			end

			self:_runRace(queuedPlayers)
		end
	end)
end

return RaceService
