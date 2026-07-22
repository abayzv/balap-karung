local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SackSizing = require(ReplicatedStorage.Shared.SackSizing)

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

	local sizeClass = SackSizing.getSizeClass(config.sizeClasses, humanoid.HipHeight)

	local sack = sourcePart:Clone()
	sack.Name = config.mountedPartName
	sack:SetAttribute(config.mountedAttribute, true)
	sack:SetAttribute(config.sizeClassAttribute, sizeClass.name)
	sack:SetAttribute(config.classificationValueAttribute, humanoid.HipHeight)
	sack.PivotOffset = CFrame.identity
	sack.Size = sizeClass.size
	sack.Anchored = false
	sack.CanCollide = false
	sack.CanTouch = false
	sack.CanQuery = false
	sack.Massless = true
	sack.CastShadow = true
	sack.Parent = character

	local localMount = CFrame.new(sizeClass.mountOffset)
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
