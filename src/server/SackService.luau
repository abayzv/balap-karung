local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local SackService = {}

local LEG_PART_NAMES = {
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local HIDDEN_ACCESSORY_TYPES = {
	Pants = true,
	Shorts = true,
	DressSkirt = true,
	LeftShoe = true,
	RightShoe = true,
}

local function projectedHalfHeight(part, referenceCFrame)
	local relative = referenceCFrame:ToObjectSpace(part.CFrame)
	local halfSize = part.Size / 2
	return math.abs(relative.RightVector.Y) * halfSize.X
		+ math.abs(relative.UpVector.Y) * halfSize.Y
		+ math.abs(relative.LookVector.Y) * halfSize.Z
end

local function getLegBottom(character, lowerTorso)
	local bottom = math.huge
	local foundLeg = false
	for _, name in LEG_PART_NAMES do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local localPosition = lowerTorso.CFrame:PointToObjectSpace(part.Position)
			bottom =
				math.min(bottom, localPosition.Y - projectedHalfHeight(part, lowerTorso.CFrame))
			foundLeg = true
		end
	end
	return if foundLeg then bottom else nil
end

local function getTargetHeight(character, humanoid, lowerTorso)
	local config = GameConfig.sack
	local legBottom = getLegBottom(character, lowerTorso)
	if not legBottom then
		legBottom = -humanoid.HipHeight - lowerTorso.Size.Y / 2
	end
	local sackTop = lowerTorso.Size.Y * config.topHeightRatio
	return math.max(config.minimumHeightStuds, sackTop - legBottom + config.bottomPaddingStuds),
		sackTop
end

local function getSackPartTemplate()
	local config = GameConfig.sack
	local template = ReplicatedStorage:FindFirstChild(config.templateName)
	if not template then
		return nil
	end
	local sackPart = template:FindFirstChild(config.partName, true)
	return if sackPart and sackPart:IsA("BasePart") then sackPart else nil
end

local function hideLegs(character)
	local config = GameConfig.sack
	for _, name in LEG_PART_NAMES do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if part:GetAttribute(config.originalTransparencyAttribute) == nil then
				part:SetAttribute(config.originalTransparencyAttribute, part.Transparency)
			end
			part.Transparency = 1
		end
	end

	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and HIDDEN_ACCESSORY_TYPES[child.AccessoryType.Name] then
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					if descendant:GetAttribute(config.originalTransparencyAttribute) == nil then
						descendant:SetAttribute(
							config.originalTransparencyAttribute,
							descendant.Transparency
						)
					end
					descendant.Transparency = 1
				end
			end
		end
	end
end

local function restoreLegs(character)
	local config = GameConfig.sack
	for _, name in LEG_PART_NAMES do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local originalTransparency = part:GetAttribute(config.originalTransparencyAttribute)
			if type(originalTransparency) == "number" then
				part.Transparency = originalTransparency
				part:SetAttribute(config.originalTransparencyAttribute, nil)
			end
		end
	end

	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and HIDDEN_ACCESSORY_TYPES[child.AccessoryType.Name] then
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					local originalTransparency =
						descendant:GetAttribute(config.originalTransparencyAttribute)
					if type(originalTransparency) == "number" then
						descendant.Transparency = originalTransparency
						descendant:SetAttribute(config.originalTransparencyAttribute, nil)
					end
				end
			end
		end
	end
end

function SackService.Detach(character)
	if not character then
		return
	end

	local config = GameConfig.sack
	for _, descendant in character:GetDescendants() do
		if descendant:GetAttribute(config.mountedAttribute) == true then
			descendant:Destroy()
		end
	end
	restoreLegs(character)
end

function SackService.Attach(character)
	if not character then
		return false
	end

	local config = GameConfig.sack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lowerTorso = character:FindFirstChild("LowerTorso")
	if
		not humanoid
		or humanoid.RigType ~= Enum.HumanoidRigType.R15
		or not lowerTorso
		or not lowerTorso:IsA("BasePart")
	then
		return false
	end

	SackService.Detach(character)
	local sourcePart = getSackPartTemplate()
	if not sourcePart then
		warn(
			`[BalapKarung] ReplicatedStorage.{config.templateName}.{config.partName} tidak ditemukan`
		)
		return false
	end

	local targetHeight, sackTop = getTargetHeight(character, humanoid, lowerTorso)
	local verticalScale = math.clamp(
		targetHeight / sourcePart.Size.Y,
		config.minimumVerticalScale,
		config.maximumVerticalScale
	)
	local targetWidth = math.max(
		config.minimumWidthStuds,
		lowerTorso.Size.X * config.widthMultiplier + config.widthPaddingStuds,
		math.min(config.maximumWidthStuds, targetHeight * config.widthToHeightRatio)
	)
	local targetDepth = math.max(
		config.minimumDepthStuds,
		lowerTorso.Size.Z * config.depthMultiplier + config.depthPaddingStuds,
		math.min(config.maximumDepthStuds, targetHeight * config.depthToHeightRatio)
	)

	local sack = sourcePart:Clone()
	sack.Name = config.mountedPartName
	sack:SetAttribute(config.mountedAttribute, true)
	sack.PivotOffset = CFrame.identity
	-- Leg length should only affect sack height. Uniform scaling made tall,
	-- slim avatars wear an absurdly wide sack.
	sack.Size = Vector3.new(targetWidth, sourcePart.Size.Y * verticalScale, targetDepth)
	sack.Anchored = false
	sack.CanCollide = false
	sack.CanTouch = false
	sack.CanQuery = false
	sack.Massless = true
	sack.CastShadow = true
	sack.Parent = character

	local centerY = sackTop - sack.Size.Y / 2
	local localMount = CFrame.new(0, centerY, config.forwardOffsetStuds)
		* CFrame.Angles(
			math.rad(config.rotationDegrees.X),
			math.rad(config.rotationDegrees.Y),
			math.rad(config.rotationDegrees.Z)
		)
	sack.CFrame = lowerTorso.CFrame * localMount

	local motor = Instance.new("Motor6D")
	motor.Name = config.motorName
	motor:SetAttribute(config.mountedAttribute, true)
	motor.Part0 = lowerTorso
	motor.Part1 = sack
	motor.C0 = localMount
	motor.C1 = CFrame.identity
	motor.Parent = lowerTorso

	hideLegs(character)
	return true
end

return SackService
