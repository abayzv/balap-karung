local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local SoundController = {
	_sounds = {},
	_started = false,
}

local function createSound(name, config)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.soundId
	sound.Volume = config.volume
	sound.Parent = SoundService
	return sound
end

function SoundController.Play(name)
	local sound = SoundController._sounds[name]
	if not sound or sound.SoundId == "" then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

function SoundController.Start(reactionRemote)
	if SoundController._started then
		return
	end
	SoundController._started = true

	for name, config in GameConfig.sounds do
		SoundController._sounds[name] = createSound(name, config)
	end

	reactionRemote.OnClientEvent:Connect(function(payload)
		if payload.action ~= "result" then
			return
		end

		SoundController.Play(string.lower(payload.verdict))
	end)
end

return SoundController
