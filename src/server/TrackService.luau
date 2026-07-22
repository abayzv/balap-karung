local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local TrackService = {}
TrackService.__index = TrackService

local function horizontalUnit(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 0.001 then
		return nil
	end
	return horizontal.Unit
end

local function taggedParts(root, tag)
	local results = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, tag) then
			table.insert(results, descendant)
		end
	end
	return results
end

local function getTrackId(model)
	local trackId = model:GetAttribute("TrackId")
	if type(trackId) == "string" and trackId ~= "" then
		return trackId
	end
	return model.Name
end

function TrackService.new()
	local self = setmetatable({}, TrackService)
	self._templates = ServerStorage:WaitForChild(GameConfig.track.templatesFolderName)
	self._activeContainer = Workspace:WaitForChild(GameConfig.track.activeFolderName)
	self._random = Random.new()
	self._templateBag = {}
	self._lastTrackId = nil
	return self
end

function TrackService:_getTemplates()
	local templates = {}
	for _, child in self._templates:GetChildren() do
		if child:IsA("Model") and CollectionService:HasTag(child, GameConfig.track.tags.track) then
			table.insert(templates, child)
		end
	end

	table.sort(templates, function(left, right)
		return getTrackId(left) < getTrackId(right)
	end)

	return templates
end

function TrackService:_chooseNextTemplate()
	local templates = self:_getTemplates()
	if #templates == 0 then
		return nil
	end

	if #self._templateBag == 0 then
		self._templateBag = table.clone(templates)
	end

	local choiceIndex = self._random:NextInteger(1, #self._templateBag)
	if #templates > 1 and getTrackId(self._templateBag[choiceIndex]) == self._lastTrackId then
		for index, template in self._templateBag do
			if getTrackId(template) ~= self._lastTrackId then
				choiceIndex = index
				break
			end
		end
	end

	local template = table.remove(self._templateBag, choiceIndex)
	self._lastTrackId = getTrackId(template)
	return template
end

function TrackService:_readTrack(model)
	local spawns = taggedParts(model, GameConfig.track.tags.spawn)
	local moveTargets = taggedParts(model, GameConfig.track.tags.moveTarget)
	local finishes = taggedParts(model, GameConfig.track.tags.finish)

	if #spawns == 0 then
		return nil, `Track {model.Name} tidak punya tag {GameConfig.track.tags.spawn}`
	end
	if #spawns > GameConfig.race.maximumLanes then
		return nil,
			`Track {model.Name} maksimal memiliki {GameConfig.race.maximumLanes} spawn, ditemukan {#spawns}`
	end
	if #moveTargets ~= #spawns then
		return nil, `Track {model.Name} punya {#spawns} spawn tetapi {#moveTargets} MoveTarget`
	end
	if #finishes ~= 1 then
		return nil,
			`Track {model.Name} harus punya tepat 1 tag {GameConfig.track.tags.finish}, ditemukan {#finishes}`
	end

	local function readLaneIndex(part, tagName)
		local laneIndex = part:GetAttribute("LaneIndex")
		if
			type(laneIndex) ~= "number"
			or laneIndex % 1 ~= 0
			or laneIndex < 1
			or laneIndex > GameConfig.race.maximumLanes
		then
			return nil,
				`{part:GetFullName()} bertag {tagName} membutuhkan LaneIndex integer 1-{GameConfig.race.maximumLanes}`
		end
		return laneIndex
	end

	local spawnsByLane = {}
	for _, spawn in spawns do
		local laneIndex, problem = readLaneIndex(spawn, GameConfig.track.tags.spawn)
		if not laneIndex then
			return nil, problem
		end
		if spawnsByLane[laneIndex] then
			return nil, `LaneIndex {laneIndex} dipakai lebih dari satu spawn pada {model.Name}`
		end
		spawnsByLane[laneIndex] = spawn
	end

	local targetsByLane = {}
	for _, moveTarget in moveTargets do
		local laneIndex, problem = readLaneIndex(moveTarget, GameConfig.track.tags.moveTarget)
		if not laneIndex then
			return nil, problem
		end
		if targetsByLane[laneIndex] then
			return nil, `LaneIndex {laneIndex} dipakai lebih dari satu MoveTarget pada {model.Name}`
		end
		targetsByLane[laneIndex] = moveTarget
	end

	local lanes = {}
	local totalLength = 0
	for laneIndex, spawn in spawnsByLane do
		local moveTarget = targetsByLane[laneIndex]
		if not moveTarget then
			return nil, `Spawn LaneIndex {laneIndex} tidak memiliki pasangan MoveTarget`
		end

		local directionToTarget = moveTarget.Position - spawn.Position
		local forward = horizontalUnit(directionToTarget)
		if not forward then
			return nil, `MoveTarget LaneIndex {laneIndex} terlalu dekat dengan spawn pasangannya`
		end

		local length = Vector3.new(directionToTarget.X, 0, directionToTarget.Z).Magnitude
		totalLength += length
		table.insert(lanes, {
			index = laneIndex,
			spawn = spawn,
			moveTarget = moveTarget,
			forward = forward,
			length = length,
		})
	end

	table.sort(lanes, function(left, right)
		return left.index < right.index
	end)

	local finish = finishes[1]
	local averageLength = totalLength / #lanes

	model:SetAttribute("ResolvedTrackLength", averageLength)
	return {
		model = model,
		id = getTrackId(model),
		displayName = model:GetAttribute("DisplayName") or model.Name,
		lanes = lanes,
		finish = finish,
		length = averageLength,
	}
end

function TrackService:_activateTemplate(template)
	if not template then
		return nil,
			`Masukkan Model bertag {GameConfig.track.tags.track} ke ServerStorage/{GameConfig.track.templatesFolderName}`
	end

	self._activeContainer:ClearAllChildren()
	local activeModel = template:Clone()
	activeModel.Name = getTrackId(template)
	activeModel.Parent = self._activeContainer

	local track, problem = self:_readTrack(activeModel)
	if not track then
		activeModel:Destroy()
		return nil, problem
	end

	Workspace:SetAttribute("ActiveTrackId", track.id)
	Workspace:SetAttribute("ActiveTrackName", track.displayName)
	Workspace:SetAttribute("ActiveTrackLength", track.length)
	return track
end

function TrackService:ActivateNextTrack()
	return self:_activateTemplate(self:_chooseNextTemplate())
end

function TrackService:ActivateTrackById(trackId)
	for _, template in self:_getTemplates() do
		if getTrackId(template) == trackId then
			return self:_activateTemplate(template)
		end
	end
	return nil,
		`Track dengan TrackId {trackId} tidak ditemukan di ServerStorage/{GameConfig.track.templatesFolderName}`
end

return TrackService
