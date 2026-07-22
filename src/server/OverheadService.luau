local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverheadService = {}

local function updateOverhead(player, overhead)
	local nameLabel = overhead:FindFirstChild("NameLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.DisplayName
	end

	local streak = overhead:FindFirstChild("Streak")
	if streak and streak:IsA("GuiObject") then
		streak.Visible = (player:GetAttribute("WinStreak") or 0) > 0
	end
	local streakLabel = streak and streak:FindFirstChild("TextLabel", true)
	if streakLabel and streakLabel:IsA("TextLabel") then
		streakLabel.Text = tostring(player:GetAttribute("WinStreak") or 0)
	end
end

local function attachOverhead(player, character, template)
	local head = character:WaitForChild("Head", 5)
	if not head or not head:IsA("BasePart") or player.Character ~= character then
		return
	end

	local existing = head:FindFirstChild(template.Name)
	if existing then
		existing:Destroy()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local overhead = template:Clone()
	overhead.Adornee = head
	overhead.ResetOnSpawn = false
	overhead.Parent = head
	updateOverhead(player, overhead)
end

function OverheadService.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local template = shared:FindFirstChild("OverheadUI")
	if not template or not template:IsA("BillboardGui") then
		warn("[BalapKarung] ReplicatedStorage.Shared.OverheadUI tidak ditemukan")
		return
	end

	local function registerPlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(attachOverhead, player, character, template)
		end)
		player:GetAttributeChangedSignal("WinStreak"):Connect(function()
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local overhead = head and head:FindFirstChild(template.Name)
			if overhead and overhead:IsA("BillboardGui") then
				updateOverhead(player, overhead)
			end
		end)
		if player.Character then
			task.spawn(attachOverhead, player, player.Character, template)
		end
	end

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)
end

return OverheadService
