local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local RaceTrackerController = {
	_started = false,
}

local AVATAR_SIZE = 38
local VERTICAL_OFFSETS = { 0, -13, 13, -25, 25 }

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = parent
end

local function createTracker(playerGui)
	local existing = playerGui:FindFirstChild("RaceTracker")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RaceTracker"
	screenGui.DisplayOrder = 10010
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 1
	root.Position = UDim2.new(0.5, 0, 0, 20)
	root.Size = UDim2.new(0.56, 0, 0, 54)
	root.Visible = false
	root.Parent = screenGui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(270, 54)
	sizeConstraint.MaxSize = Vector2.new(620, 54)
	sizeConstraint.Parent = root

	local scale = Instance.new("UIScale")
	scale.Name = "DynamicScale"
	scale:SetAttribute("Desktop", 1)
	scale:SetAttribute("Mobile", 0.6)
	scale.Parent = root
	CollectionService:AddTag(scale, GameConfig.ui.dynamicScaleTag)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bar.BackgroundTransparency = 0.34
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(1, 0, 0, 15)
	bar.Parent = root
	addCorner(bar, 1)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(104, 111, 122)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.48
	stroke.Parent = bar

	local highlight = Instance.new("UIGradient")
	highlight.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	highlight.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.52),
		NumberSequenceKeypoint.new(0.5, 0.16),
		NumberSequenceKeypoint.new(1, 0.52),
	})
	highlight.Parent = bar

	return root, bar
end

local function createAvatar(bar, player, localPlayer)
	local holder = Instance.new("Frame")
	holder.Name = `Racer_{player.UserId}`
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	holder.BorderSizePixel = 0
	holder.Position = UDim2.fromScale(0, 0.5)
	holder.Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE)
	holder.ZIndex = if player == localPlayer then 5 else 3
	holder.Parent = bar
	addCorner(holder, 1)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.Size = UDim2.fromScale(1, 1)
	avatar.ZIndex = holder.ZIndex
	avatar.Parent = holder
	addCorner(avatar, 1)

	local outline = Instance.new("UIStroke")
	outline.Color = if player == localPlayer
		then Color3.fromRGB(255, 216, 61)
		else Color3.fromRGB(235, 238, 242)
	outline.Thickness = if player == localPlayer then 3 else 2
	outline.Transparency = if player == localPlayer then 0 else 0.25
	outline.Parent = holder

	task.spawn(function()
		local success, thumbnail = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if success and holder.Parent then
			avatar.Image = thumbnail
		end
	end)

	return holder
end

function RaceTrackerController.Start()
	if RaceTrackerController._started then
		return
	end
	RaceTrackerController._started = true

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local root, bar = createTracker(playerGui)
	local entries = {}
	local connections = {}
	local placementTween = nil

	local function updatePlacement()
		if placementTween then
			placementTween:Cancel()
		end
		local targetY = if Workspace:GetAttribute("RaceState") == "Countdown" then 150 else 20
		placementTween = TweenService:Create(
			root,
			TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, targetY) }
		)
		placementTween:Play()
	end

	local function removePlayer(player)
		local entry = entries[player]
		if entry then
			entry.holder:Destroy()
			entries[player] = nil
		end
		local playerConnections = connections[player]
		if playerConnections then
			for _, connection in playerConnections do
				connection:Disconnect()
			end
			connections[player] = nil
		end
	end

	local function updateEntry(player)
		local shouldShow = player:GetAttribute("IsRace") == true
		local entry = entries[player]
		if shouldShow and not entry then
			entry = {
				holder = createAvatar(bar, player, localPlayer),
				displayedProgress = player:GetAttribute("RaceProgress") or 0,
				targetProgress = player:GetAttribute("RaceProgress") or 0,
			}
			entries[player] = entry
		elseif not shouldShow and entry then
			entry.holder:Destroy()
			entries[player] = nil
			return
		end

		if entry then
			entry.targetProgress = math.clamp(player:GetAttribute("RaceProgress") or 0, 0, 1)
		end
	end

	local function registerPlayer(player)
		if connections[player] then
			return
		end
		connections[player] = {
			player:GetAttributeChangedSignal("IsRace"):Connect(function()
				updateEntry(player)
			end),
			player:GetAttributeChangedSignal("RaceProgress"):Connect(function()
				updateEntry(player)
			end),
			player:GetAttributeChangedSignal("LaneIndex"):Connect(function()
				updateEntry(player)
			end),
		}
		updateEntry(player)
	end

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	Workspace:GetAttributeChangedSignal("RaceState"):Connect(updatePlacement)
	updatePlacement()

	RunService.RenderStepped:Connect(function(deltaTime)
		local visibleCount = 0
		for player, entry in entries do
			visibleCount += 1
			local alpha = 1 - math.exp(-12 * deltaTime)
			entry.displayedProgress += (entry.targetProgress - entry.displayedProgress) * alpha
			local laneIndex = player:GetAttribute("LaneIndex") or 1
			local verticalOffset = VERTICAL_OFFSETS[(laneIndex - 1) % #VERTICAL_OFFSETS + 1]
			entry.holder.Position = UDim2.new(entry.displayedProgress, 0, 0.5, verticalOffset)
		end
		root.Visible = Workspace:GetAttribute("RaceState") == "Racing"
			and localPlayer:GetAttribute("IsRace") == true
			and visibleCount > 0
	end)
end

return RaceTrackerController
