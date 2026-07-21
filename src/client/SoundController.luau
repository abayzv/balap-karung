local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MusicCatalog = require(ReplicatedStorage.Shared.MusicCatalog)
local MusicPlayerState = require(ReplicatedStorage.Shared.MusicPlayerState)

local SoundController = {
	_sounds = {},
	_started = false,
	_onFireGeneration = 0,
	_onFireLoopStarted = false,
	_onFireTweens = {},
	_musicListeners = {},
	_musicState = MusicPlayerState.create(MusicCatalog, GameConfig.sounds.backgroundMusic.volume),
}

local ON_FIRE_CROSSFADE_SECONDS = 0.18

local function emitMusicState()
	for _, listener in table.clone(SoundController._musicListeners) do
		task.spawn(listener, SoundController._musicState)
	end
end

local function syncBackgroundMusic()
	local sound = SoundController._sounds.backgroundMusic
	if not sound then
		return
	end
	local state = SoundController._musicState
	local track = MusicPlayerState.getSelectedTrack(state)
	if not track then
		sound:Stop()
		return
	end
	local soundId = `rbxassetid://{track.soundId}`
	if sound.SoundId ~= soundId then
		sound:Stop()
		sound.SoundId = soundId
		sound.TimePosition = 0
	end
	sound.Volume = state.volume
	if state.musicEnabled and state.isPlaying then
		if not sound.IsPlaying then
			sound:Play()
		end
	elseif sound.IsPlaying then
		sound:Pause()
	end
end

local function updateMusicState(updater)
	local nextState = updater(SoundController._musicState)
	if nextState == SoundController._musicState then
		return
	end
	SoundController._musicState = nextState
	syncBackgroundMusic()
	emitMusicState()
end

local function createSound(name, config)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.soundId
	sound.Volume = config.volume
	sound.Parent = SoundService
	return sound
end

local function tweenVolume(sound, volume, duration)
	local existingTween = SoundController._onFireTweens[sound]
	if existingTween then
		existingTween:Cancel()
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = volume }
	)
	SoundController._onFireTweens[sound] = tween
	tween:Play()
	tween.Completed:Once(function()
		if SoundController._onFireTweens[sound] == tween then
			SoundController._onFireTweens[sound] = nil
		end
	end)
	return tween
end

local function startOnFireLoop(generation)
	if
		generation ~= SoundController._onFireGeneration
		or Players.LocalPlayer:GetAttribute("OnFire") ~= true
		or SoundController._onFireLoopStarted
	then
		return
	end

	local loopSound = SoundController._sounds.onFireLoop
	if not loopSound then
		return
	end

	SoundController._onFireLoopStarted = true
	loopSound:Stop()
	loopSound.TimePosition = 0
	loopSound.Volume = 0
	loopSound.Looped = true
	loopSound:Play()
	tweenVolume(loopSound, GameConfig.sounds.onFireLoop.volume, ON_FIRE_CROSSFADE_SECONDS)
end

local function stopOnFireSounds()
	SoundController._onFireGeneration += 1
	local generation = SoundController._onFireGeneration
	SoundController._onFireLoopStarted = false

	for _, name in { "onFireEnter", "onFireLoop" } do
		local sound = SoundController._sounds[name]
		if sound and sound.IsPlaying then
			tweenVolume(sound, 0, ON_FIRE_CROSSFADE_SECONDS)
			task.delay(ON_FIRE_CROSSFADE_SECONDS, function()
				if generation ~= SoundController._onFireGeneration then
					return
				end
				sound:Stop()
				sound.TimePosition = 0
			end)
		end
	end
end

local function startOnFireSounds()
	if not SoundController._musicState.sfxEnabled then
		return
	end
	SoundController._onFireGeneration += 1
	local generation = SoundController._onFireGeneration
	SoundController._onFireLoopStarted = false

	local introSound = SoundController._sounds.onFireEnter
	local loopSound = SoundController._sounds.onFireLoop
	if not introSound or not loopSound then
		return
	end

	loopSound:Stop()
	loopSound.TimePosition = 0
	loopSound.Volume = 0
	loopSound.Looped = true
	introSound:Stop()
	introSound.TimePosition = 0
	introSound.Volume = GameConfig.sounds.onFireEnter.volume
	introSound.Looped = false
	introSound:Play()

	task.spawn(function()
		while
			generation == SoundController._onFireGeneration
			and Players.LocalPlayer:GetAttribute("OnFire") == true
			and introSound.IsPlaying
		do
			if
				introSound.TimeLength > 0
				and introSound.TimeLength - introSound.TimePosition <= ON_FIRE_CROSSFADE_SECONDS
			then
				startOnFireLoop(generation)
				tweenVolume(introSound, 0, ON_FIRE_CROSSFADE_SECONDS)
				return
			end
			RunService.Heartbeat:Wait()
		end

		startOnFireLoop(generation)
	end)
end

local function updateOnFireSounds()
	if Players.LocalPlayer:GetAttribute("OnFire") == true then
		startOnFireSounds()
	else
		stopOnFireSounds()
	end
end

function SoundController.Play(name)
	local sound = SoundController._sounds[name]
	if
		not sound
		or sound.SoundId == ""
		or (name ~= "backgroundMusic" and not SoundController._musicState.sfxEnabled)
	then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

function SoundController.GetMusicState()
	return SoundController._musicState
end

function SoundController.SubscribeMusic(callback)
	table.insert(SoundController._musicListeners, callback)
	task.spawn(callback, SoundController._musicState)
	return function()
		local index = table.find(SoundController._musicListeners, callback)
		if index then
			table.remove(SoundController._musicListeners, index)
		end
	end
end

function SoundController.SelectTrack(trackId)
	updateMusicState(function(state)
		return MusicPlayerState.selectTrack(state, trackId)
	end)
end

function SoundController.NextTrack()
	updateMusicState(MusicPlayerState.nextTrack)
end

function SoundController.PreviousTrack()
	updateMusicState(MusicPlayerState.previousTrack)
end

function SoundController.ToggleMusicPlayback()
	updateMusicState(MusicPlayerState.togglePlaying)
end

function SoundController.SetMusicVolume(volume)
	updateMusicState(function(state)
		return MusicPlayerState.setVolume(state, volume)
	end)
end

function SoundController.SetMusicEnabled(enabled)
	updateMusicState(function(state)
		return MusicPlayerState.setMusicEnabled(state, enabled)
	end)
end

function SoundController.SetSfxEnabled(enabled)
	updateMusicState(function(state)
		return MusicPlayerState.setSfxEnabled(state, enabled)
	end)
	if not enabled then
		stopOnFireSounds()
		for name, sound in SoundController._sounds do
			if name ~= "backgroundMusic" then
				sound:Stop()
			end
		end
	else
		updateOnFireSounds()
	end
end

function SoundController.Stop(name)
	local sound = SoundController._sounds[name]
	if not sound then
		return
	end

	sound:Stop()
	sound.TimePosition = 0
end

function SoundController.Start(reactionRemote)
	if SoundController._started then
		return
	end
	SoundController._started = true

	for name, config in GameConfig.sounds do
		SoundController._sounds[name] = createSound(name, config)
	end
	local backgroundMusic = SoundController._sounds.backgroundMusic
	backgroundMusic.Looped = false
	backgroundMusic.Ended:Connect(SoundController.NextTrack)
	syncBackgroundMusic()
	task.spawn(function()
		local soundsToPreload = {}
		for _, sound in SoundController._sounds do
			table.insert(soundsToPreload, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(soundsToPreload)
		end)
	end)

	reactionRemote.OnClientEvent:Connect(function(payload)
		if payload.action == "comboResult" then
			SoundController.Play(if payload.verdict == "TriplePerfect" then "perfect" else "good")
			return
		end
		if payload.action ~= "result" and payload.action ~= "obstacleVerdict" then
			return
		end
		if
			payload.action == "obstacleVerdict"
			and (payload.verdict == "Early" or payload.verdict == "Miss")
		then
			return
		end

		local soundName = if payload.verdict == "Early"
			then "miss"
			else string.lower(payload.verdict)
		SoundController.Play(soundName)
	end)

	Players.LocalPlayer:GetAttributeChangedSignal("OnFire"):Connect(updateOnFireSounds)
	updateOnFireSounds()
end

return SoundController
