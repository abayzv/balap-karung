local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ObstacleMechanic = require(ReplicatedStorage.Shared.ObstacleMechanic)
local Reaction = require(ReplicatedStorage.Shared.Reaction)
local Speed = require(ReplicatedStorage.Shared.Speed)
local TrackService = require(script.Parent.TrackService)

local RACER_COLLISION_GROUP = "BalapKarungRacers"
local GUARD_DEBRIS_COLLISION_GROUP = "BalapKarungGuardDebris"
local ON_FIRE_AURA_ATTRIBUTE = "BalapKarungOnfireAura"

local RaceService = {}
RaceService.__index = RaceService

local function isCharacterInsideFinish(character, finish)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 1

	local forgivingSize = finish.Size + Vector3.new(1, 6, 1)
	return #Workspace:GetPartBoundsInBox(finish.CFrame, forgivingSize, overlapParams) > 0
end

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

function RaceService.new()
	local self = setmetatable({}, RaceService)
	self._raceId = 0
	self._eventId = 0
	self._finishCount = 0
	self._racers = {}
	self._raceStartedAt = 0
	self._state = "Waiting"
	self._trackService = TrackService.new()
	self._activeTrack = nil
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

	self._reactionWindowRemote = reactionWindow
	self._submitReactionRemote = submitReaction
	self._submitGuardImpactRemote = submitGuardImpact
	self._guardImpactRemote = guardImpact
	self._submitObstacleCrashRemote = submitObstacleCrash
	self._podiumResultsRemote = podiumResults
end

function RaceService:_setState(state, countdown)
	self._state = state
	Workspace:SetAttribute("RaceState", state)
	Workspace:SetAttribute("Countdown", countdown or 0)
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
		root:SetNetworkOwner(nil)
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
			finished = false,
			recoveringUntil = 0,
			nextNormalPromptAt = 0,
			reaction = nil,
			obstacleReactions = {},
			obstacleSequence = nil,
			activeObstacle = nil,
			obstacles = getLaneObstacles(activeTrack.model, lane),
			raceId = self._raceId,
		}
	end

	return next(self._racers) ~= nil
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

function RaceService:_resolveReaction(racer, verdict, eventId)
	if racer.finished then
		return
	end
	-- A normal prompt can expire in the same frame that an obstacle sequence starts.
	-- Once the obstacle owns the input, that stale result must not punish the racer.
	if eventId ~= nil and racer.activeObstacle then
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
	if
		math.abs(Workspace:GetServerTimeNow() - clientDetectedAt)
		> GameConfig.reactionWindow.maximumClockDifferenceSeconds
	then
		return
	end

	local obstacle = racer.activeObstacle
	if not obstacle or not obstacle.failed or obstacle.crashed or obstacle.barrier ~= barrier then
		return
	end

	local progress = (racer.root.Position - racer.startOrigin):Dot(racer.forward)
	local distanceToBarrier = obstacle.barrierProgress - progress
	if
		distanceToBarrier > GameConfig.obstacle.guardServerValidationDistanceStuds
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
	if racer.finished or racer.activeObstacle or obstacle.started then
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
	local startsAt = Workspace:GetServerTimeNow()
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
				and Workspace:GetServerTimeNow() <= event.closesAt
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
	if
		math.abs(Workspace:GetServerTimeNow() - clientDetectedAt)
		> GameConfig.reactionWindow.maximumClockDifferenceSeconds
	then
		return
	end

	local obstacle = racer.activeObstacle
	if
		not obstacle
		or not obstacle.guardArmed
		or obstacle.guardUsed
		or obstacle.barrier ~= barrier
	then
		return
	end

	local progress = (racer.root.Position - racer.startOrigin):Dot(racer.forward)
	local distanceToBarrier = obstacle.barrierProgress - progress
	if
		distanceToBarrier > GameConfig.obstacle.guardServerValidationDistanceStuds
		or distanceToBarrier < -GameConfig.obstacle.guardServerFallbackStuds
	then
		return
	end

	self:_triggerGuardImpact(racer, obstacle, player.UserId)
end

function RaceService:_isNormalPromptTooCloseToObstacle(racer, promptDuration)
	local progress = math.clamp(
		(racer.root.Position - racer.startOrigin):Dot(racer.forward),
		0,
		racer.trackLength
	)
	local nextTriggerProgress = nil
	for _, obstacle in racer.obstacles do
		if not obstacle.started and obstacle.triggerProgress >= progress then
			nextTriggerProgress = obstacle.triggerProgress
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
			+ GameConfig.reactionWindow.scheduleLeadSeconds
			+ GameConfig.obstacle.normalPromptBufferSeconds
end

function RaceService:_runReactionLoop(racer)
	local random = Random.new(racer.player.UserId + self._raceId * 1000)

	while self._state == "Racing" and not racer.finished and racer.raceId == self._raceId do
		if racer.activeObstacle then
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
		if racer.activeObstacle then
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
			local scheduleLead = if racer.tempoStage >= 2
				then 0
				else GameConfig.reactionWindow.scheduleLeadSeconds
			local opensAt = Workspace:GetServerTimeNow() + scheduleLead
			local event = {
				id = self._eventId,
				opensAt = opensAt,
				closesAt = opensAt + duration,
				duration = duration,
				resolved = false,
			}
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
				and Workspace:GetServerTimeNow() <= event.closesAt
			do
				task.wait()
			end

			if self._state ~= "Racing" or racer.finished or racer.raceId ~= self._raceId then
				break
			end

			if not event.resolved then
				event.resolved = true
				racer.reaction = nil
				self:_resolveReaction(racer, "Miss", event.id)
				break
			end

			if racer.activeObstacle then
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
	if
		math.abs(serverNow - clientPressedAt)
		> GameConfig.reactionWindow.maximumClockDifferenceSeconds
	then
		return
	end

	local obstacleEvent = racer.obstacleReactions[eventId]
	if obstacleEvent and not obstacleEvent.resolved then
		local reactionSeconds = clientPressedAt - obstacleEvent.opensAt
		local verdict = Reaction.verdictFor(reactionSeconds, obstacleEvent.duration)
		if verdict then
			self:_resolveObstacleReaction(racer, obstacleEvent, verdict)
		end
		return
	end

	local event = racer.reaction
	if not event or event.resolved or event.id ~= eventId then
		return
	end

	local reactionSeconds = clientPressedAt - event.opensAt
	local verdict = Reaction.verdictFor(reactionSeconds, event.duration)
	if not verdict then
		return
	end

	event.resolved = true
	racer.reaction = nil
	self:_resolveReaction(racer, verdict, event.id)
end

function RaceService:_finishRacer(racer)
	if racer.finished then
		return
	end

	racer.finished = true
	racer.reaction = nil
	table.clear(racer.obstacleReactions)
	racer.obstacleSequence = nil
	racer.activeObstacle = nil
	self._finishCount += 1

	local finishTime = Workspace:GetServerTimeNow() - self._raceStartedAt
	racer.player:SetAttribute("DistanceRemaining", 0)
	racer.player:SetAttribute("RaceProgress", 1)
	racer.player:SetAttribute("FinishTime", finishTime)
	racer.player:SetAttribute("Rank", self._finishCount)
	racer.player:SetAttribute("RaceStatus", "Finished")
	racer.player:SetAttribute("IsRecovering", false)
	racer.player:SetAttribute("GuardReady", false)
	racer.speedMultiplier = 1
	racer.boostEndsAt = 0
	racer.player:SetAttribute("SpeedMultiplier", 1)
	racer.player:SetAttribute("EffectiveSpeed", racer.speed)
	racer.player:SetAttribute("BoostEndsAt", 0)
	racer.humanoid.PlatformStand = false
	racer.root.Anchored = false
	racer.root.AssemblyLinearVelocity = Vector3.zero
	racer.root.AssemblyAngularVelocity = Vector3.zero
	self._reactionWindowRemote:FireClient(racer.player, { action = "hide" })
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
		local velocity = racer.root.AssemblyLinearVelocity
		local forwardSpeed = if racer.recoveringUntil > 0 then 0 else effectiveSpeed
		local forwardVelocity = racer.forward * forwardSpeed
		racer.root.AssemblyLinearVelocity =
			Vector3.new(forwardVelocity.X, velocity.Y, forwardVelocity.Z)

		local progress = math.clamp(
			(racer.root.Position - racer.startOrigin):Dot(racer.forward),
			0,
			racer.trackLength
		)

		for _, obstacle in racer.obstacles do
			if not obstacle.started and progress >= obstacle.triggerProgress then
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
			player:SetAttribute("Speed", speed)
			player:SetAttribute("EffectiveSpeed", effectiveSpeed)
			player:SetAttribute("DistanceRemaining", math.max(0, racer.trackLength - progress))
			player:SetAttribute("RaceProgress", progress / racer.trackLength)
		end

		local crossedLaneTarget = progress >= racer.trackLength
		if
			isCharacterInsideFinish(racer.character, self._activeTrack.finish)
			or crossedLaneTarget
		then
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

function RaceService:_runRace(eligiblePlayers, skipRaceCountdown)
	if not self:_prepareRace(eligiblePlayers) then
		return
	end

	if not skipRaceCountdown then
		for countdown = GameConfig.race.countdownSeconds, 1, -1 do
			self:_setState("Countdown", countdown)
			task.wait(1)
		end
		self:_setState("Countdown", 0)
		task.wait(GameConfig.race.startSignalSeconds)
	end

	self:_setState("Racing")
	self._raceStartedAt = Workspace:GetServerTimeNow()
	for _, racer in self._racers do
		racer.root.Anchored = false
		racer.player:SetAttribute("RaceStatus", "Racing")
		task.spawn(function()
			self:_runReactionLoop(racer)
		end)
	end

	while self:_hasActiveRacers() do
		task.wait(0.1)
	end

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
				else
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
	self._submitObstacleCrashRemote.OnServerEvent:Connect(
		function(player, barrier, clientDetectedAt)
			self:_submitObstacleCrash(player, barrier, clientDetectedAt)
		end
	)

	RunService.Heartbeat:Connect(function()
		if self._state == "Racing" then
			self:_updateRacers()
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
				self:_runRace(Players:GetPlayers(), true)
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
