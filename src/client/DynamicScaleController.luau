local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local DynamicScaleController = {}

local MOBILE_PLATFORMS = {
	[Enum.Platform.IOS] = true,
	[Enum.Platform.Android] = true,
}

local function getScaleAttributeName()
	local success, platform = pcall(function()
		return UserInputService:GetPlatform()
	end)
	if success and MOBILE_PLATFORMS[platform] then
		return "Mobile"
	end
	if not success and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	end
	return "Desktop"
end

function DynamicScaleController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local tag = GameConfig.ui.dynamicScaleTag
	local attributeName = getScaleAttributeName()
	local connections = {}

	local function apply(instance)
		if not instance:IsA("UIScale") or not instance:IsDescendantOf(playerGui) then
			return
		end
		local configuredScale = instance:GetAttribute(attributeName)
		if type(configuredScale) == "number" then
			instance.Scale = configuredScale
		end
	end

	local function monitor(instance)
		if connections[instance] or not instance:IsA("UIScale") then
			return
		end
		connections[instance] = {
			instance:GetAttributeChangedSignal("Mobile"):Connect(function()
				apply(instance)
			end),
			instance:GetAttributeChangedSignal("Desktop"):Connect(function()
				apply(instance)
			end),
			instance.Destroying:Connect(function()
				local instanceConnections = connections[instance]
				connections[instance] = nil
				for _, connection in instanceConnections do
					connection:Disconnect()
				end
			end),
		}
		apply(instance)
	end

	for _, instance in CollectionService:GetTagged(tag) do
		monitor(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		task.defer(monitor, instance)
	end)
	playerGui.DescendantAdded:Connect(function(instance)
		if CollectionService:HasTag(instance, tag) then
			task.defer(monitor, instance)
		end
	end)
end

return DynamicScaleController
