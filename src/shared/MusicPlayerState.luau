local MusicPlayerState = {}

local function findTrackIndex(tracks, trackId)
	for index, track in tracks do
		if track.id == trackId then
			return index
		end
	end
	return nil
end

function MusicPlayerState.create(tracks, volume)
	return {
		tracks = tracks,
		selectedTrackId = tracks[1] and tracks[1].id or nil,
		isPlaying = true,
		volume = math.clamp(tonumber(volume) or 0.35, 0, 1),
		musicEnabled = true,
		sfxEnabled = true,
	}
end

function MusicPlayerState.getSelectedTrack(state)
	local index = findTrackIndex(state.tracks, state.selectedTrackId)
	return index and state.tracks[index] or nil
end

function MusicPlayerState.selectTrack(state, trackId)
	if not findTrackIndex(state.tracks, trackId) then
		return state
	end
	local nextState = table.clone(state)
	nextState.selectedTrackId = trackId
	nextState.isPlaying = true
	return nextState
end

function MusicPlayerState.stepTrack(state, direction)
	if #state.tracks == 0 then
		return state
	end
	local index = findTrackIndex(state.tracks, state.selectedTrackId) or 1
	index = ((index - 1 + direction) % #state.tracks) + 1
	return MusicPlayerState.selectTrack(state, state.tracks[index].id)
end

function MusicPlayerState.nextTrack(state)
	return MusicPlayerState.stepTrack(state, 1)
end

function MusicPlayerState.previousTrack(state)
	return MusicPlayerState.stepTrack(state, -1)
end

function MusicPlayerState.togglePlaying(state)
	local nextState = table.clone(state)
	nextState.isPlaying = not state.isPlaying
	return nextState
end

function MusicPlayerState.setVolume(state, volume)
	local nextState = table.clone(state)
	nextState.volume = math.clamp(tonumber(volume) or state.volume, 0, 1)
	return nextState
end

function MusicPlayerState.setMusicEnabled(state, enabled)
	local nextState = table.clone(state)
	nextState.musicEnabled = enabled == true
	return nextState
end

function MusicPlayerState.setSfxEnabled(state, enabled)
	local nextState = table.clone(state)
	nextState.sfxEnabled = enabled == true
	return nextState
end

return table.freeze(MusicPlayerState)
