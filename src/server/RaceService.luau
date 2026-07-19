local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Reaction = require(ReplicatedStorage.Shared.Reaction)
local Speed = require(ReplicatedStorage.Shared.Speed)
local TrackService = require(script.Parent.TrackService)

local RACER_COLLISION_GROUP = "BalapKarungRacers"

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
	local startingTier = GameConfig.speed.startingTier
	player:SetAttribute("Speed", Speed.valueForTier(startingTier))
	player:SetAttribute("SpeedTier", startingTier)
	player:SetAttribute("SpeedTierName", Speed.getTier(startingTier).name)
	player:SetAttribute("PerfectStreak", 0)
	player:SetAttribute("SpeedMultiplier", 1)
	player:SetAttribute("EffectiveSpeed", Speed.valueForTier(startingTier))
	player:SetAttribute("BoostEndsAt", 0)
	player:SetAttribute("IsRecovering", false)
	player:SetAttribute("DistanceRemaining", GameConfig.race.trackLengthStuds)
	player:SetAttribute("RaceStatus", "Waiting")
	player:SetAttribute("FinishTime", 0)
	player:SetAttribute("Rank", 0)
	player:SetAttribute("LaneIndex", 0)
	player:SetAttribute("LastVerdict", "")
	player:SetAttribute("IsRace", false)
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
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	local reactionWindow = Instance.new("RemoteEvent")
	reactionWindow.Name = "ReactionWindow"
	reactionWindow.Parent = folder

	local submitReaction = Instance.new("RemoteEvent")
	submitReaction.Name = "SubmitReaction"
	submitReaction.Parent = folder

	self._reactionWindowRemote = reactionWindow
	self._submitReactionRemote = submitReaction
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

function RaceService:_prepareRace()
	local activeTrack = self._activeTrack
	if not activeTrack or not activeTrack.model.Parent then
		warn("[BalapKarung] Race dimulai tanpa active track")
		return false
	end

	self._raceId += 1
	self._finishCount = 0
	table.clear(self._racers)

	local currentPlayers = Players:GetPlayers()
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
			speedTier = GameConfig.speed.startingTier,
			speed = Speed.valueForTier(GameConfig.speed.startingTier),
			perfectStreak = 0,
			speedMultiplier = 1,
			boostEndsAt = 0,
			lastReplicationAt = 0,
			finished = false,
			recoveringUntil = 0,
			reaction = nil,
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
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root then
			local lobbyPosition = (lobbySpawn.CFrame * CFrame.new(
				0,
				lobbySpawn.Size.Y / 2 + GameConfig.track.characterSpawnHeight,
				0
			)).Position
			character:PivotTo(
				CFrame.lookAt(lobbyPosition, lobbyPosition + lobbySpawn.CFrame.LookVector)
			)
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

function RaceService:_resolveReaction(racer, verdict)
	if racer.finished then
		return
	end

	local previousTier = racer.speedTier
	racer.speedTier, racer.perfectStreak =
		Speed.applyVerdict(racer.speedTier, racer.perfectStreak, verdict)
	racer.speed = Speed.valueForTier(racer.speedTier)
	racer.player:SetAttribute("Speed", racer.speed)
	racer.player:SetAttribute("SpeedTier", racer.speedTier)
	racer.player:SetAttribute("SpeedTierName", Speed.getTier(racer.speedTier).name)
	racer.player:SetAttribute("PerfectStreak", racer.perfectStreak)
	racer.player:SetAttribute("LastVerdict", verdict)
	if verdict == "Miss" then
		self:_startMissRecovery(racer)
	else
		racer.speedMultiplier = GameConfig.speed.verdictMultiplier[verdict]
		racer.boostEndsAt = Workspace:GetServerTimeNow() + GameConfig.speed.boostDurationSeconds
		racer.player:SetAttribute("SpeedMultiplier", racer.speedMultiplier)
		racer.player:SetAttribute("EffectiveSpeed", racer.speed * racer.speedMultiplier)
		racer.player:SetAttribute("BoostEndsAt", racer.boostEndsAt)
	end
	self._reactionWindowRemote:FireClient(racer.player, {
		action = "result",
		verdict = verdict,
		tierUp = racer.speedTier > previousTier,
		tierDown = racer.speedTier < previousTier,
		multiplier = racer.speedMultiplier,
	})
end

function RaceService:_runReactionLoop(racer)
	local random = Random.new(racer.player.UserId + self._raceId * 1000)

	while self._state == "Racing" and not racer.finished and racer.raceId == self._raceId do
		task.wait(
			random:NextNumber(
				GameConfig.reactionWindow.minimumIntervalSeconds,
				GameConfig.reactionWindow.maximumIntervalSeconds
			)
		)

		if self._state ~= "Racing" or racer.finished or racer.raceId ~= self._raceId then
			break
		end

		local chainLength = random:NextInteger(
			GameConfig.reactionWindow.minimumChainLength,
			GameConfig.reactionWindow.maximumChainLength
		)

		for chainIndex = 1, chainLength do
			if self._state ~= "Racing" or racer.finished or racer.raceId ~= self._raceId then
				break
			end

			self._eventId += 1
			local duration = Speed.reactionDurationForTier(racer.speedTier)
			local opensAt = Workspace:GetServerTimeNow()
				+ GameConfig.reactionWindow.scheduleLeadSeconds
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
				self:_resolveReaction(racer, "Miss")
				break
			end

			if chainIndex < chainLength then
				task.wait(GameConfig.reactionWindow.chainGapSeconds)
			end
		end
	end
end

function RaceService:_submitReaction(player, eventId, clientPressedAt)
	local racer = self._racers[player]
	if self._state ~= "Racing" or not racer or racer.finished then
		return
	end

	local event = racer.reaction
	if not event or event.resolved or event.id ~= eventId or type(clientPressedAt) ~= "number" then
		return
	end

	local serverNow = Workspace:GetServerTimeNow()
	if
		math.abs(serverNow - clientPressedAt)
		> GameConfig.reactionWindow.maximumClockDifferenceSeconds
	then
		return
	end

	local reactionSeconds = clientPressedAt - event.opensAt
	local verdict = Reaction.verdictFor(reactionSeconds, event.duration)
	if not verdict then
		return
	end

	event.resolved = true
	racer.reaction = nil
	self:_resolveReaction(racer, verdict)
end

function RaceService:_finishRacer(racer)
	if racer.finished then
		return
	end

	racer.finished = true
	racer.reaction = nil
	self._finishCount += 1

	local finishTime = Workspace:GetServerTimeNow() - self._raceStartedAt
	racer.player:SetAttribute("DistanceRemaining", 0)
	racer.player:SetAttribute("FinishTime", finishTime)
	racer.player:SetAttribute("Rank", self._finishCount)
	racer.player:SetAttribute("RaceStatus", "Finished")
	racer.player:SetAttribute("IsRecovering", false)
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
			player:SetAttribute("RaceStatus", "DNF")
			continue
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
		if now - racer.lastReplicationAt >= 0.1 then
			racer.lastReplicationAt = now
			player:SetAttribute("Speed", speed)
			player:SetAttribute("EffectiveSpeed", effectiveSpeed)
			player:SetAttribute("DistanceRemaining", math.max(0, racer.trackLength - progress))
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

function RaceService:_runRace()
	if not self:_prepareRace() then
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
	for _, racer in self._racers do
		racer.root.Anchored = false
		racer.player:SetAttribute("RaceStatus", "Racing")
		task.spawn(function()
			self:_runReactionLoop(racer)
		end)
	end

	local raceDeadline = self._raceStartedAt + GameConfig.race.maximumDurationSeconds
	while self:_hasActiveRacers() and Workspace:GetServerTimeNow() < raceDeadline do
		task.wait(0.1)
	end

	for player, racer in self._racers do
		if not racer.finished then
			racer.finished = true
			racer.reaction = nil
			racer.humanoid.PlatformStand = false
			racer.root.Anchored = false
			racer.root.AssemblyLinearVelocity = Vector3.zero
			racer.root.AssemblyAngularVelocity = Vector3.zero
			player:SetAttribute("RaceStatus", "DNF")
			player:SetAttribute("IsRecovering", false)
			player:SetAttribute("SpeedMultiplier", 1)
			player:SetAttribute("EffectiveSpeed", racer.speed)
			player:SetAttribute("BoostEndsAt", 0)
			self._reactionWindowRemote:FireClient(player, { action = "hide" })
		end
	end

	self:_setState("Results")
	task.wait(GameConfig.race.resultsSeconds)
	self:_returnPlayersToLobby()
end

function RaceService:Start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RACER_COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(RACER_COLLISION_GROUP, RACER_COLLISION_GROUP, false)

	local function registerPlayer(player)
		setPlayerDefaults(player)
		player:GetAttributeChangedSignal("IsRace"):Connect(function()
			if player.Character then
				updateJumpState(player, player.Character)
			end
		end)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if player:GetAttribute("IsRace") == true then
					updateJumpState(player, character)
				else
					restoreLobbyCharacter(player, character)
				end
			end)
		end)
		if player.Character then
			restoreLobbyCharacter(player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)

	self._submitReactionRemote.OnServerEvent:Connect(function(player, eventId, clientPressedAt)
		self:_submitReaction(player, eventId, clientPressedAt)
	end)

	RunService.Heartbeat:Connect(function()
		if self._state == "Racing" then
			self:_updateRacers()
		end
	end)

	task.spawn(function()
		while true do
			self:_setState("Waiting")
			while #Players:GetPlayers() < GameConfig.race.minimumPlayers do
				task.wait(1)
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
			self:_setState("Intermission", GameConfig.race.intermissionSeconds)
			for remaining = GameConfig.race.intermissionSeconds, 1, -1 do
				Workspace:SetAttribute("Countdown", remaining)
				task.wait(1)
			end

			self:_runRace()
		end
	end)
end

return RaceService
