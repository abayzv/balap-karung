local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LobbyTimerController = {}

local function formatTime(seconds)
	local safeSeconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(safeSeconds / 60), safeSeconds % 60)
end

function LobbyTimerController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local timerGui = playerGui:WaitForChild("Timer", 10)
	if not timerGui then
		warn("[BalapKarung] StarterGui.Timer tidak ditemukan")
		return
	end
	local locationTile = timerGui:WaitForChild("Frame"):WaitForChild("LocationTile")
	local title = locationTile:WaitForChild("Title")
	local countdownLabel = locationTile:WaitForChild("Bottom"):WaitForChild("Countdown")
	local localPlayer = Players.LocalPlayer

	local function render()
		local state = Workspace:GetAttribute("RaceState") or "Waiting"
		local countdown = Workspace:GetAttribute("Countdown") or 0
		local activeTrackName = Workspace:GetAttribute("ActiveTrackName") or ""

		local timerVisible = state == "Intermission"
			and localPlayer:GetAttribute("InStartArea") == true
		timerGui.Enabled = timerVisible
		if not timerVisible then
			return
		end

		title.Text = if activeTrackName ~= ""
			then `Balapan Berikutnya: {activeTrackName}`
			else "Balapan Berikutnya"
		countdownLabel.Text = formatTime(countdown)
	end

	Workspace:GetAttributeChangedSignal("RaceState"):Connect(render)
	Workspace:GetAttributeChangedSignal("Countdown"):Connect(render)
	Workspace:GetAttributeChangedSignal("ActiveTrackName"):Connect(render)
	localPlayer:GetAttributeChangedSignal("InStartArea"):Connect(render)
	render()
end

return LobbyTimerController
