local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PodiumCinematicController = {}

local function findTaggedDescendant(tag, ancestor)
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(ancestor) then
			return instance
		end
	end
	return nil
end

local function cloneCharacter(result)
	local sourcePlayer = Players:GetPlayerByUserId(result.userId)
	local sourceCharacter = sourcePlayer and sourcePlayer.Character
	if sourceCharacter then
		local wasArchivable = sourceCharacter.Archivable
		sourceCharacter.Archivable = true
		local clone = sourceCharacter:Clone()
		sourceCharacter.Archivable = wasArchivable
		return clone
	end

	local success, model = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(result.userId)
	end)
	return if success then model else nil
end

local function playDance(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local played = false
	pcall(function()
		played = humanoid:PlayEmote("dance")
	end)
	if played then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15
		then GameConfig.ui.podiumCinematic.danceR15AnimationId
		else GameConfig.ui.podiumCinematic.danceR6AnimationId
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.2)
	animation:Destroy()
end

local function positionCharacter(character, floorPart, cameraPosition)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return false
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	root.Anchored = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local height = floorPart.Size.Y / 2
		+ humanoid.HipHeight
		+ root.Size.Y / 2
		+ GameConfig.ui.podiumCinematic.characterHeightOffset
	local position = floorPart.Position + floorPart.CFrame.UpVector * height
	character:PivotTo(
		CFrame.lookAt(position, Vector3.new(cameraPosition.X, position.Y, cameraPosition.Z))
	)
	return true
end

local function formatFinishTime(result)
	if result.rank and result.rank > 0 and type(result.finishTime) == "number" then
		return string.format("%.2fs", result.finishTime)
	end
	return "-"
end

local function getResultTitle(result)
	local titles = GameConfig.ui.podiumCinematic.titles
	if not result or not result.rank or result.rank <= 0 then
		return titles.Default
	elseif result.rank == 1 then
		return titles.First
	elseif result.rank <= 3 then
		return titles.Podium
	end
	return titles.Default
end

local function clearResultRows(rows)
	for _, child in rows:GetChildren() do
		if child:GetAttribute("RuntimeResultRow") then
			child:Destroy()
		end
	end
end

local function createResultRow(rows, result, isLocalPlayer, layoutOrder)
	local row = Instance.new("Frame")
	row.Name = `ResultRow_{layoutOrder}`
	row:SetAttribute("RuntimeResultRow", true)
	row.BackgroundColor3 = if isLocalPlayer
		then Color3.fromRGB(255, 222, 48)
		else Color3.fromRGB(239, 244, 252)
	row.BackgroundTransparency = if isLocalPlayer then 0.02 else 0.14
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0.09, 0)
	row.ZIndex = 3
	row.Parent = rows

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = row

	local textColor = Color3.fromRGB(25, 29, 37)
	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.GothamBlack
	rank.Position = UDim2.fromScale(0.015, 0.08)
	rank.Size = UDim2.fromScale(0.1, 0.84)
	rank.Text = if result.rank and result.rank > 0 then tostring(result.rank) else "-"
	rank.TextColor3 = textColor
	rank.TextScaled = true
	rank.ZIndex = 4
	rank.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(70, 78, 94)
	avatar.Position = UDim2.fromScale(0.12, 0.1)
	avatar.Size = UDim2.fromScale(0.08, 0.8)
	avatar.ZIndex = 4
	avatar.Parent = row
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = avatar

	local displayName = Instance.new("TextLabel")
	displayName.Name = "DisplayName"
	displayName.BackgroundTransparency = 1
	displayName.Font = if isLocalPlayer then Enum.Font.GothamBlack else Enum.Font.GothamBold
	displayName.Position = UDim2.fromScale(0.225, 0.08)
	displayName.Size = UDim2.fromScale(0.53, 0.84)
	displayName.Text = result.displayName or result.name or "Player"
	displayName.TextColor3 = textColor
	displayName.TextScaled = true
	displayName.TextTruncate = Enum.TextTruncate.AtEnd
	displayName.TextXAlignment = Enum.TextXAlignment.Left
	displayName.ZIndex = 4
	displayName.Parent = row

	local time = Instance.new("TextLabel")
	time.Name = "FinishTime"
	time.BackgroundTransparency = 1
	time.Font = Enum.Font.GothamBlack
	time.Position = UDim2.fromScale(0.76, 0.08)
	time.Size = UDim2.fromScale(0.225, 0.84)
	time.Text = formatFinishTime(result)
	time.TextColor3 = textColor
	time.TextScaled = true
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.ZIndex = 4
	time.Parent = row

	task.spawn(function()
		local success, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				result.userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if success and avatar.Parent then
			avatar.Image = image
		end
	end)
end

local function populateResultsGui(gui, results, localPlayer, onSkip)
	local title = gui:WaitForChild("TopLeftDecoration"):WaitForChild("Title")
	local rows = gui:WaitForChild("LeaderboardPanel"):WaitForChild("Rows")
	local skip = gui:WaitForChild("Skip")
	clearResultRows(rows)

	local ownResult = nil
	for index, result in results do
		if index > GameConfig.race.maximumLanes then
			break
		end
		local isLocalPlayer = result.userId == localPlayer.UserId
		if isLocalPlayer then
			ownResult = result
		end
		createResultRow(rows, result, isLocalPlayer, index)
	end

	title.Text = getResultTitle(ownResult)
	skip.Visible = false
	local connection = skip.Activated:Connect(onSkip)
	task.delay(GameConfig.ui.podiumCinematic.skipDelaySeconds, function()
		if gui.Enabled then
			skip.Visible = true
		end
	end)
	return ownResult, connection
end

function PodiumCinematicController.Start(resultsRemote, soundController)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local resultsGui = playerGui:WaitForChild("ResultsNotification")
	local controls = nil
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
	end)
	local activeCleanup = nil

	resultsRemote.OnClientEvent:Connect(function(payload)
		if activeCleanup then
			activeCleanup()
		end

		local config = GameConfig.ui.podiumCinematic
		local template = ReplicatedStorage:FindFirstChild(config.templateName)
		if not template then
			warn(`[BalapKarung] ReplicatedStorage.{config.templateName} tidak ditemukan`)
			return
		end

		local localScene = template:Clone()
		localScene.Name = config.localSceneName
		localScene.Parent = Workspace
		local cameraPart = findTaggedDescendant(config.cameraTag, localScene)
		local characterSpot = findTaggedDescendant(config.characterSpotTag, localScene)
		if
			not cameraPart
			or not cameraPart:IsA("BasePart")
			or not characterSpot
			or not characterSpot:IsA("BasePart")
		then
			warn(
				"[BalapKarung] Results cinematic membutuhkan PodiumCamera dan ResultsCharacterSpot"
			)
			localScene:Destroy()
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			localScene:Destroy()
			return
		end
		local originalFieldOfView = camera.FieldOfView
		local originalGlobalShadows = Lighting.GlobalShadows
		local previousGuiStates = {}
		local characterFolder = Instance.new("Folder")
		characterFolder.Name = "LocalResultsCharacter"
		characterFolder.Parent = localScene

		for _, child in playerGui:GetChildren() do
			if child:IsA("ScreenGui") then
				previousGuiStates[child] = child.Enabled
				child.Enabled = false
			end
		end
		if controls then
			controls:Disable()
		end
		Lighting.GlobalShadows = false
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraPart.CFrame
		camera.FieldOfView = cameraPart:GetAttribute("FieldOfView") or 50

		local cleaned = false
		local skipConnection = nil
		local function cleanup()
			if cleaned then
				return
			end
			cleaned = true
			if skipConnection then
				skipConnection:Disconnect()
			end
			if soundController then
				soundController.Stop("resultsCinematic")
			end
			resultsGui.Enabled = false
			clearResultRows(resultsGui.LeaderboardPanel.Rows)
			localScene:Destroy()
			Lighting.GlobalShadows = originalGlobalShadows
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = originalFieldOfView
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
			for gui, wasEnabled in previousGuiStates do
				if gui.Parent then
					gui.Enabled = wasEnabled
				end
			end
			if controls then
				controls:Enable()
			end
			if activeCleanup == cleanup then
				activeCleanup = nil
			end
		end

		local ownResult
		ownResult, skipConnection = populateResultsGui(resultsGui, payload.results, player, cleanup)
		resultsGui.Enabled = true
		if soundController then
			soundController.Play("resultsCinematic")
		end
		if ownResult then
			local character = cloneCharacter(ownResult)
			if character then
				character.Name = `ResultsCharacter_{ownResult.name}`
				character:ScaleTo(config.characterScale)
				character.Parent = characterFolder
				if positionCharacter(character, characterSpot, cameraPart.Position) then
					playDance(character)
				else
					character:Destroy()
				end
			end
		end

		activeCleanup = cleanup
	end)
end

return PodiumCinematicController
