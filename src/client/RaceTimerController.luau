local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RaceTimerController = {}

function RaceTimerController.Start(soundController)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local timerGui = playerGui:WaitForChild("RaceTimer", 10)
	if not timerGui then
		warn("[BalapKarung] StarterGui.RaceTimer tidak ditemukan")
		return
	end

	local locationTile = timerGui:WaitForChild("Frame"):WaitForChild("LocationTile")
	local title = locationTile:WaitForChild("Title")
	local countdownLabel = locationTile:WaitForChild("Bottom"):WaitForChild("Countdown")
	local localPlayer = Players.LocalPlayer
	local countdownSoundPlayed = false

	local function render()
		local state = Workspace:GetAttribute("RaceState") or "Waiting"
		local countdown = Workspace:GetAttribute("Countdown") or 0
		local isCountdown = state == "Countdown" and localPlayer:GetAttribute("IsRace") == true
		timerGui.Enabled = isCountdown

		if not isCountdown then
			countdownSoundPlayed = false
			return
		end

		if countdown == 4 and not countdownSoundPlayed then
			countdownSoundPlayed = true
			if soundController then
				soundController.Play("raceCountdown")
			end
		end

		if countdown <= 0 then
			title.Text = "Mulai!"
			countdownLabel.Text = ""
		elseif countdown <= 5 then
			title.Text = "Siap"
			countdownLabel.Text = tostring(countdown)
		else
			title.Text = "Bersedia"
			countdownLabel.Text = tostring(countdown)
		end
	end

	Workspace:GetAttributeChangedSignal("RaceState"):Connect(render)
	Workspace:GetAttributeChangedSignal("Countdown"):Connect(render)
	localPlayer:GetAttributeChangedSignal("IsRace"):Connect(render)
	render()
end

return RaceTimerController
