local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local SackArmPoseController = {}

local ARM_JOINT_NAMES = {
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
}

local function isAnimationJoint(instance)
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function createCharacterState(character)
	local joints = {}
	for _, name in ARM_JOINT_NAMES do
		local joint = character:FindFirstChild(name, true)
		if joint and isAnimationJoint(joint) then
			joints[name] = joint
		end
	end

	return {
		joints = joints,
		idlePose = {},
	}
end

function SackArmPoseController.Start()
	local characterStates = setmetatable({}, { __mode = "k" })

	RunService.PreSimulation:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end

			local sack = character:FindFirstChild(GameConfig.sack.mountedPartName)
			if not sack then
				characterStates[character] = nil
				continue
			end

			local state = characterStates[character]
			if not state then
				state = createCharacterState(character)
				characterStates[character] = state
			end

			local raceStatus = player:GetAttribute("RaceStatus")
			local isRecovering = player:GetAttribute("IsRecovering") == true
			if raceStatus == "Countdown" or raceStatus == "Finished" then
				for name, joint in state.joints do
					if joint.Parent then
						state.idlePose[name] = joint.Transform
					end
				end
			elseif raceStatus == "Racing" and not isRecovering then
				for name, transform in state.idlePose do
					local joint = state.joints[name]
					if joint and joint.Parent then
						joint.Transform = transform
					end
				end
			end
		end
	end)
end

return SackArmPoseController
