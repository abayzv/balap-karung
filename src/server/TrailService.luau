local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailCatalog = require(ReplicatedStorage.Shared.TrailCatalog)

local TrailService = {}
TrailService.__index = TrailService

local COSMETIC_ATTRIBUTE = "BalapKarungTrailCosmetic"

local function getTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function removeEffect(character)
	local torso = getTorso(character)
	if not torso then
		return
	end
	for _, child in torso:GetChildren() do
		if child:GetAttribute(COSMETIC_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
end

local function copyTemplateContents(source, torso)
	local copied = 0
	for _, child in source:GetChildren() do
		if child:IsA("Attachment") or child:IsA("ParticleEmitter") then
			local clone = child:Clone()
			clone:SetAttribute(COSMETIC_ATTRIBUTE, true)
			clone.Parent = torso
			copied += 1
		end
	end
	if copied == 0 then
		warn(
			`[BalapKarung] Trail {source.Name} tidak memiliki Attachment atau ParticleEmitter untuk dipasang`
		)
	end
end

function TrailService.new(dataService)
	return setmetatable({
		_dataService = dataService,
		_playerConnections = {},
	}, TrailService)
end

function TrailService:_refreshPlayer(player)
	local character = player.Character
	if not character then
		return
	end
	removeEffect(character)

	if player:GetAttribute("IsRace") ~= true or player:GetAttribute("RaceStatus") ~= "Racing" then
		return
	end
	local trail = TrailCatalog.byId[player:GetAttribute("EquippedTrail")]
	if not trail or trail.id == TrailCatalog.defaultTrailId then
		return
	end
	local torso = getTorso(character)
	if not torso or not trail.source or not trail.source:IsA("BasePart") then
		return
	end
	copyTemplateContents(trail.source, torso)
end

function TrailService:_watchPlayer(player)
	local connections = {}
	self._playerConnections[player] = connections
	local function refresh()
		self:_refreshPlayer(player)
	end
	for _, attribute in { "EquippedTrail", "IsRace", "RaceStatus" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
	end
	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("UpperTorso", 10)
			refresh()
		end)
	)
	refresh()
end

function TrailService:Start()
	TrailCatalog.refresh()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	local purchase = remotes:FindFirstChild("PurchaseTrail")
	if purchase and not purchase:IsA("RemoteFunction") then
		purchase:Destroy()
		purchase = nil
	end
	purchase = purchase or Instance.new("RemoteFunction")
	purchase.Name = "PurchaseTrail"
	purchase.Parent = remotes
	purchase.OnServerInvoke = function(player, trailId)
		return self._dataService:PurchaseTrail(player, trailId)
	end

	local equip = remotes:FindFirstChild("EquipTrail")
	if equip and not equip:IsA("RemoteFunction") then
		equip:Destroy()
		equip = nil
	end
	equip = equip or Instance.new("RemoteFunction")
	equip.Name = "EquipTrail"
	equip.Parent = remotes
	equip.OnServerInvoke = function(player, trailId)
		return self._dataService:EquipTrail(player, trailId)
	end

	for _, player in Players:GetPlayers() do
		self:_watchPlayer(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:_watchPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in self._playerConnections[player] or {} do
			connection:Disconnect()
		end
		self._playerConnections[player] = nil
	end)
end

return TrailService
