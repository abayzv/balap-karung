local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local DataService = {}
DataService.__index = DataService

local LEADERSTAT_NAMES = { "Win", "WinStreak" }

local function getOrCreateIntValue(parent, name)
	local value = parent:FindFirstChild(name)
	if value and not value:IsA("IntValue") then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = parent
	end
	return value
end

function DataService.new()
	local self = setmetatable({}, DataService)
	local store = ProfileStore.New(GameConfig.data.storeName, PlayerData.template)
	if RunService:IsStudio() and GameConfig.data.useMockStoreInStudio then
		store = store.Mock
	end
	self._store = store
	self._profiles = {}
	self._releasing = {}
	return self
end

function DataService:_syncPlayer(player)
	local profile = self._profiles[player]
	if not profile then
		return
	end

	local data = PlayerData.sanitize(profile.Data)
	for field in PlayerData.template do
		player:SetAttribute(field, data[field])
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	for _, name in LEADERSTAT_NAMES do
		getOrCreateIntValue(leaderstats, name).Value = data[name]
	end
	player:SetAttribute("DataLoaded", true)
end

function DataService:_loadPlayer(player)
	player:SetAttribute("DataLoaded", false)
	local profile = self._store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("Data gagal dimuat. Silakan masuk kembali.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	PlayerData.sanitize(profile.Data)
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		player:SetAttribute("DataLoaded", false)
		if not self._releasing[player] and player.Parent == Players then
			player:Kick("Sesi data berakhir. Silakan masuk kembali.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
	self:_syncPlayer(player)
end

function DataService:RecordRaceResult(player, won)
	local profile = self._profiles[player]
	if not profile or not profile:IsActive() then
		warn(`[BalapKarung] Hasil race {player.Name} tidak tersimpan: profile belum aktif`)
		return false
	end

	PlayerData.applyRaceResult(profile.Data, won)
	self:_syncPlayer(player)
	return true
end

function DataService:Start()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_loadPlayer(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_loadPlayer(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = self._profiles[player]
		if profile then
			self._releasing[player] = true
			profile:EndSession()
		end
		self._profiles[player] = nil
		self._releasing[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.data.playtimeTickSeconds)
			for player, profile in self._profiles do
				if player.Parent == Players and profile:IsActive() then
					profile.Data.Playtime += GameConfig.data.playtimeTickSeconds
					player:SetAttribute("Playtime", profile.Data.Playtime)
				end
			end
		end
	end)
end

return DataService
