local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local RaceResetController = {}

local MAX_ATTEMPTS = 20
local RETRY_SECONDS = 0.25

function RaceResetController.Start()
	local player = Players.LocalPlayer
	local generation = 0

	local function applyResetState()
		generation += 1
		local currentGeneration = generation
		local resetEnabled = player:GetAttribute("IsRace") ~= true
			and player:GetAttribute("InStartArea") ~= true

		task.spawn(function()
			for _ = 1, MAX_ATTEMPTS do
				if currentGeneration ~= generation then
					return
				end

				local success = pcall(function()
					StarterGui:SetCore("ResetButtonCallback", resetEnabled)
				end)
				if success then
					return
				end

				task.wait(RETRY_SECONDS)
			end

			warn("[BalapKarung] Gagal memperbarui tombol Reset Character")
		end)
	end

	player:GetAttributeChangedSignal("IsRace"):Connect(applyResetState)
	player:GetAttributeChangedSignal("InStartArea"):Connect(applyResetState)
	player.CharacterAdded:Connect(applyResetState)
	applyResetState()
end

return RaceResetController
