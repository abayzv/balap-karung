local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LeaderboardFormat = require(ReplicatedStorage.Shared.LeaderboardFormat)

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local AVATAR_MODEL_PREFIX = "LeaderboardCharacter_"

local function getTaggedDescendant(root, tag)
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(root) then
			return instance
		end
	end
	return nil
end

local function getAvatarSpots(board)
	local spots = {}
	for _, instance in CollectionService:GetTagged(GameConfig.leaderboard.avatarTag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(board) then
			local index = tonumber(instance:GetAttribute("Index"))
			if index and index >= 1 and index <= 3 then
				spots[math.floor(index)] = instance
			end
		end
	end
	return spots
end

local function getSurfaceFace(board, view)
	local direction = Vector3.zero
	local count = 0
	for _, spot in getAvatarSpots(board) do
		direction += spot.Position - view.Position
		count += 1
	end
	if count == 0 then
		return Enum.NormalId.Right
	end
	return if direction:Dot(view.CFrame.RightVector) >= 0
		then Enum.NormalId.Right
		else Enum.NormalId.Left
end

local function createSurface(board, view)
	local old = view:FindFirstChild(GameConfig.leaderboard.surfaceGuiName)
	if old then
		old:Destroy()
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = GameConfig.leaderboard.surfaceGuiName
	surface.Active = true
	surface.Adornee = view
	surface.AlwaysOnTop = true
	surface.CanvasSize = Vector2.new(1000, 1464)
	surface.Face = getSurfaceFace(board, view)
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.ZOffset = 0.02
	surface.Parent = view

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Active = true
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.Position = UDim2.fromOffset(24, 24)
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 55)
	scroll.ScrollBarThickness = 8
	scroll.Size = UDim2.new(1, -48, 1, -48)
	scroll.Parent = surface

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	return surface, scroll
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent, text, position, size, alignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(247, 249, 255)
	label.TextScaled = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = alignment
	label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 38
	constraint.MinTextSize = 18
	constraint.Parent = label
	return label
end

local function cardColor(position)
	return ({
		[1] = Color3.fromRGB(191, 137, 22),
		[2] = Color3.fromRGB(99, 111, 131),
		[3] = Color3.fromRGB(142, 79, 43),
	})[position] or Color3.fromRGB(26, 33, 50)
end

local function renderEntries(boardState, entries)
	local scroll = boardState.scroll
	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for position, entry in entries do
		local card = Instance.new("Frame")
		card.Name = `Position{position}`
		card.BackgroundColor3 = cardColor(position)
		card.BackgroundTransparency = if position <= 3 then 0.08 else 0.18
		card.BorderSizePixel = 0
		card.LayoutOrder = position
		card.Size = UDim2.new(1, -4, 0, 92)
		card.Parent = scroll
		addCorner(card, 18)

		local stroke = Instance.new("UIStroke")
		stroke.Color = if position <= 3
			then Color3.fromRGB(255, 225, 119)
			else Color3.fromRGB(255, 255, 255)
		stroke.Thickness = if position <= 3 then 2 else 1
		stroke.Transparency = if position <= 3 then 0.25 else 0.82
		stroke.Parent = card

		makeLabel(
			card,
			`#{position}`,
			UDim2.fromOffset(18, 12),
			UDim2.fromOffset(105, 68),
			Enum.TextXAlignment.Center
		)
		makeLabel(
			card,
			entry.username,
			UDim2.fromOffset(142, 12),
			UDim2.new(1, -410, 0, 68),
			Enum.TextXAlignment.Left
		)
		local value = makeLabel(
			card,
			LeaderboardFormat.formatValue(boardState.dataKey, entry.value),
			UDim2.new(1, -260, 0, 12),
			UDim2.fromOffset(238, 68),
			Enum.TextXAlignment.Right
		)
		value.TextColor3 = if position <= 3
			then Color3.fromRGB(255, 239, 148)
			else Color3.fromRGB(198, 208, 229)
	end
end

local function clearAvatar(board, index)
	local avatar = board:FindFirstChild(`{AVATAR_MODEL_PREFIX}{index}`)
	if avatar then
		avatar:Destroy()
	end
end

local function playAvatarAnimation(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = GameConfig.leaderboard.avatarAnimationId
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not success or not track then
		warn(`[BalapKarung] Animasi avatar leaderboard gagal dimuat: {tostring(track)}`)
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.2)
end

local function placeAvatar(board, spot, index, userId)
	local existing = board:FindFirstChild(`{AVATAR_MODEL_PREFIX}{index}`)
	if existing and existing:GetAttribute("UserId") == userId then
		return
	end
	clearAvatar(board, index)

	local success, avatar = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not success or not avatar then
		return
	end
	avatar.Name = `{AVATAR_MODEL_PREFIX}{index}`
	avatar:SetAttribute("UserId", userId)
	local root = avatar:FindFirstChild("HumanoidRootPart")
	for _, descendant in avatar:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = descendant ~= root
		end
	end
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	avatar.Parent = board
	if humanoid then
		playAvatarAnimation(humanoid)
	end
	local view = getTaggedDescendant(board, GameConfig.leaderboard.viewTag)
	local face = if view and view:IsA("BasePart") then getSurfaceFace(board, view) else nil
	local outward = if face == Enum.NormalId.Left
		then -view.CFrame.RightVector
		elseif face == Enum.NormalId.Right then view.CFrame.RightVector
		else spot.CFrame.LookVector
	local facing = CFrame.lookAt(spot.Position, spot.Position + outward)
	avatar:PivotTo(facing)
	RunService.Heartbeat:Wait()
	avatar:PivotTo(facing)
	local bottomY = math.huge
	for _, child in avatar:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			bottomY = math.min(bottomY, child.Position.Y - child.Size.Y / 2)
		end
	end
	if bottomY == math.huge and root then
		bottomY = root.Position.Y - root.Size.Y / 2
	end
	local targetBottomY = spot.Position.Y + spot.Size.Y / 2
	if bottomY < math.huge then
		avatar:PivotTo(avatar:GetPivot() + Vector3.new(0, targetBottomY - bottomY, 0))
	end
end

local function renderAvatars(boardState, entries)
	local spots = getAvatarSpots(boardState.model)
	for index = 1, 3 do
		local entry = entries[index]
		local spot = spots[index]
		if entry and spot then
			placeAvatar(boardState.model, spot, index, entry.userId)
		else
			clearAvatar(boardState.model, index)
		end
	end
end

function LeaderboardService.new()
	return setmetatable({
		_boards = {},
		_nameCache = {},
		_storeCache = {},
		_lastWritten = {},
		_warnedStores = {},
		_persistenceEnabled = not (RunService:IsStudio() and GameConfig.data.useMockStoreInStudio),
	}, LeaderboardService)
end

function LeaderboardService:_getBoardDefinition(model)
	local dataKey = LeaderboardFormat.normalizeDataKey(model:GetAttribute("Data"))
	local field = LeaderboardFormat.resolveField(dataKey)
	local version = math.max(0, math.floor(tonumber(model:GetAttribute("Version")) or 0))
	local itemCount = math.clamp(
		math.floor(tonumber(model:GetAttribute("ItemCount")) or 10),
		1,
		GameConfig.leaderboard.maximumItems
	)
	local source = string.lower(tostring(model:GetAttribute("Source") or "Auto"))
	local storeKey = `{dataKey}_v{version}`
	return dataKey, field, version, itemCount, source, storeKey
end

function LeaderboardService:_getStore(storeKey)
	local cached = self._storeCache[storeKey]
	if cached then
		return cached
	end
	local storeName = `{GameConfig.leaderboard.orderedStorePrefix}_{storeKey}`
	local store = DataStoreService:GetOrderedDataStore(storeName)
	self._storeCache[storeKey] = store
	return store
end

function LeaderboardService:_getPlayerValue(player, field, source)
	local attributeValue = tonumber(player:GetAttribute(field))
	local leaderstats = player:FindFirstChild("leaderstats")
	local leaderstat = leaderstats and leaderstats:FindFirstChild(field)
	local leaderstatValue = leaderstat and tonumber(leaderstat.Value)
	if source == "leaderstats" then
		return leaderstatValue
	elseif source == "profile" or source == "profilestore" then
		return attributeValue
	end
	return attributeValue or leaderstatValue
end

function LeaderboardService:_syncPlayer(player, force)
	if not self._persistenceEnabled then
		return
	end
	local syncedStores = {}
	self._lastWritten[player] = self._lastWritten[player] or {}
	for _, boardState in self._boards do
		if not syncedStores[boardState.storeKey] then
			syncedStores[boardState.storeKey] = true
			local value = self:_getPlayerValue(player, boardState.field, boardState.source)
			if value then
				value = math.max(0, math.floor(value))
				if force or self._lastWritten[player][boardState.storeKey] ~= value then
					local success, message = pcall(function()
						self:_getStore(boardState.storeKey):SetAsync(tostring(player.UserId), value)
					end)
					if success then
						self._lastWritten[player][boardState.storeKey] = value
					elseif not self._warnedStores[boardState.storeKey] then
						self._warnedStores[boardState.storeKey] = true
						warn(`[BalapKarung] Leaderboard write gagal: {message}`)
					end
				end
			end
		end
	end
end

function LeaderboardService:_readPersistent(boardState)
	if not self._persistenceEnabled then
		return {}
	end
	local success, pages = pcall(function()
		return self:_getStore(boardState.storeKey):GetSortedAsync(false, boardState.itemCount)
	end)
	if not success then
		if not self._warnedStores[boardState.storeKey] then
			self._warnedStores[boardState.storeKey] = true
			warn(`[BalapKarung] Leaderboard read gagal: {pages}`)
		end
		return {}
	end
	local entries = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if
			userId
			and type(entry.value) == "number"
			and entry.value >= GameConfig.leaderboard.minimumValue
		then
			entries[userId] = math.floor(entry.value)
		end
	end
	return entries
end

function LeaderboardService:_resolveNames(entries)
	local missingIds = {}
	for userId in entries do
		if not self._nameCache[userId] then
			local onlinePlayer = Players:GetPlayerByUserId(userId)
			if onlinePlayer then
				self._nameCache[userId] = onlinePlayer.Name
			else
				table.insert(missingIds, userId)
			end
		end
	end
	if #missingIds > 0 then
		local success, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missingIds)
		end)
		if success then
			for _, info in infos do
				self._nameCache[info.Id] = info.Username
			end
		end
	end
end

function LeaderboardService:_getEntries(boardState)
	local values = self:_readPersistent(boardState)
	for _, player in Players:GetPlayers() do
		local value = self:_getPlayerValue(player, boardState.field, boardState.source)
		if value and value >= GameConfig.leaderboard.minimumValue then
			values[player.UserId] = math.floor(value)
		else
			values[player.UserId] = nil
		end
	end
	self:_resolveNames(values)
	local entries = {}
	for userId, value in values do
		table.insert(entries, {
			userId = userId,
			username = self._nameCache[userId] or `User{userId}`,
			value = value,
		})
	end
	table.sort(entries, function(left, right)
		if left.value ~= right.value then
			return left.value > right.value
		end
		return left.userId < right.userId
	end)
	while #entries > boardState.itemCount do
		table.remove(entries)
	end
	return entries
end

function LeaderboardService:_refreshBoard(boardState)
	if not boardState.model.Parent or not boardState.view.Parent then
		return
	end
	local now = os.clock()
	if
		boardState.lastFetchAt
		and now - boardState.lastFetchAt < GameConfig.leaderboard.minimumRefreshGapSeconds
	then
		return
	end
	boardState.lastFetchAt = now
	local dataKey, field, version, itemCount, source, storeKey =
		self:_getBoardDefinition(boardState.model)
	boardState.dataKey = dataKey
	boardState.field = field
	boardState.version = version
	boardState.itemCount = itemCount
	boardState.source = source
	boardState.storeKey = storeKey
	local entries = self:_getEntries(boardState)
	local signatureParts = { storeKey }
	for _, entry in entries do
		table.insert(signatureParts, `{entry.userId}:{entry.username}:{entry.value}`)
	end
	local signature = table.concat(signatureParts, "|")
	if signature == boardState.lastSignature then
		return
	end
	boardState.lastSignature = signature
	renderEntries(boardState, entries)
	renderAvatars(boardState, entries)
end

function LeaderboardService:_refreshAllBoards()
	for _, boardState in self._boards do
		task.spawn(function()
			self:_refreshBoard(boardState)
		end)
	end
end

function LeaderboardService:_addBoard(model)
	if self._boards[model] or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
		return
	end
	local view = getTaggedDescendant(model, GameConfig.leaderboard.viewTag)
	if not view or not view:IsA("BasePart") then
		warn(
			`[BalapKarung] Leaderboard {model:GetFullName()} membutuhkan View bertag LeaderboardView`
		)
		return
	end
	local _, scroll = createSurface(model, view)
	local boardState = {
		model = model,
		view = view,
		scroll = scroll,
	}
	self._boards[model] = boardState
	task.delay(GameConfig.leaderboard.initialRefreshDelaySeconds, function()
		self:_refreshBoard(boardState)
	end)
end

function LeaderboardService:Start()
	for _, model in CollectionService:GetTagged(GameConfig.leaderboard.modelTag) do
		self:_addBoard(model)
	end
	CollectionService:GetInstanceAddedSignal(GameConfig.leaderboard.modelTag)
		:Connect(function(model)
			self:_addBoard(model)
		end)
	CollectionService:GetInstanceRemovedSignal(GameConfig.leaderboard.modelTag)
		:Connect(function(model)
			self._boards[model] = nil
		end)
	local function watchPlayer(player)
		local function onDataLoaded()
			if player:GetAttribute("DataLoaded") == true then
				task.delay(0.1, function()
					self:_refreshAllBoards()
				end)
			end
		end
		player:GetAttributeChangedSignal("DataLoaded"):Connect(onDataLoaded)
		if player:GetAttribute("DataLoaded") == true then
			onDataLoaded()
		end
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		self:_syncPlayer(player, true)
		self._lastWritten[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.leaderboard.refreshIntervalSeconds)
			self:_refreshAllBoards()
		end
	end)
	task.spawn(function()
		task.wait(GameConfig.leaderboard.initialWriteDelaySeconds)
		while true do
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					self:_syncPlayer(player, false)
				end)
			end
			task.wait(GameConfig.leaderboard.writeIntervalSeconds)
		end
	end)
end

return LeaderboardService
