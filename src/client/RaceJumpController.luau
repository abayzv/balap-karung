local Players = game:GetService("Players")

local RaceJumpController = {}

function RaceJumpController.Start()
	local player = Players.LocalPlayer
	local humanoid = nil

	local function applyJumpState()
		if not humanoid or not humanoid.Parent then
			return
		end

		local isRace = player:GetAttribute("IsRace") == true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not isRace)
		if isRace then
			humanoid.Jump = false
		end
	end

	local function attachCharacter(character)
		humanoid = character:WaitForChild("Humanoid")
		applyJumpState()
	end

	player:GetAttributeChangedSignal("IsRace"):Connect(applyJumpState)
	player.CharacterAdded:Connect(attachCharacter)
	if player.Character then
		task.spawn(attachCharacter, player.Character)
	end
end

return RaceJumpController
