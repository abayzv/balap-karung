local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TrailCatalog = require(ReplicatedStorage.Shared.TrailCatalog)

local TrailShopController = {}

local player = Players.LocalPlayer
local screenGui
local overlay
local panel
local shopTrigger
local coinLabel
local statusLabel
local list
local equippedTemplate
local unequippedTemplate
local previousCoins = 0
local canShowCoinToast = false

local function getDirectChild(parent, className, predicate)
	for _, child in parent:GetChildren() do
		if child.ClassName == className and (not predicate or predicate(child)) then
			return child
		end
	end
	return nil
end

local function makeColorSequence(colors)
	local keypoints = {}
	for index, color in colors do
		table.insert(
			keypoints,
			ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color)
		)
	end
	return ColorSequence.new(keypoints)
end

local function showStatus(message, isError)
	statusLabel.Text = message
	statusLabel.TextColor3 = if isError
		then Color3.fromRGB(255, 125, 125)
		else Color3.fromRGB(255, 226, 74)
	statusLabel.TextTransparency = 0
	task.delay(2.2, function()
		if statusLabel.Text == message then
			TweenService:Create(statusLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		end
	end)
end

local function responseMessage(code)
	return ({
		Purchased = "Trail berhasil dibeli dan langsung dipakai!",
		Equipped = "Trail berhasil dipakai!",
		AlreadyOwned = "Trail ini sudah kamu punya.",
		NotEnoughCoins = "Coin kamu belum cukup, bro!",
		NotOwned = "Beli trail ini dulu.",
		DataNotLoaded = "Data masih dimuat. Coba sebentar lagi.",
		InvalidTrail = "Trail tidak valid.",
	})[code] or "Transaksi gagal. Coba lagi."
end

local refreshCards

local function request(remoteName, trailId)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	if not remote then
		showStatus("Shop belum siap. Coba lagi.", true)
		return
	end
	local ok, success, code = pcall(function()
		return remote:InvokeServer(trailId)
	end)
	if not ok then
		showStatus("Koneksi shop bermasalah.", true)
		return
	end
	showStatus(responseMessage(code), not success)
	refreshCards()
end

local function getCardParts(card)
	local preview = getDirectChild(card, "Frame")
	local action = getDirectChild(card, "TextButton")
	local title
	local description
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			if not title or child.Position.Y.Offset < title.Position.Y.Offset then
				description = title
				title = child
			else
				description = child
			end
		end
	end
	return preview, title, description, action
end

local function applyThumbnail(preview, thumbnail)
	local oldThumbnail = preview:FindFirstChild("RuntimeThumbnail")
	if oldThumbnail then
		oldThumbnail:Destroy()
	end
	if not thumbnail then
		return
	end

	local image = Instance.new("ImageLabel")
	image.Name = "RuntimeThumbnail"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = thumbnail
	image.ScaleType = Enum.ScaleType.Crop
	image.ZIndex = preview.ZIndex + 1
	image.Parent = preview

	local previewCorner = preview:FindFirstChildOfClass("UICorner")
	if previewCorner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = previewCorner.CornerRadius
		corner.Parent = image
	end
end

local function createCard(trail, layoutOrder)
	local owned = player:GetAttribute(`OwnsTrail_{trail.id}`) == true
	local equipped = player:GetAttribute("EquippedTrail") == trail.id
	local card = (if equipped then equippedTemplate else unequippedTemplate):Clone()
	card.Name = trail.id
	card.LayoutOrder = layoutOrder
	card.Visible = true
	card.Parent = list

	local preview, title, description, action = getCardParts(card)
	if not preview or not title or not description or not action then
		warn(`[BalapKarung] Trail card template tidak lengkap: {card:GetFullName()}`)
		card:Destroy()
		return
	end

	title.Text = trail.name
	description.Text = trail.description
	preview.BackgroundColor3 = trail.colors[1]
	local previewGradient = preview:FindFirstChildOfClass("UIGradient")
	if previewGradient then
		previewGradient.Color = makeColorSequence(trail.colors)
	end
	applyThumbnail(preview, trail.thumbnail)

	action.Active = not equipped
	action.AutoButtonColor = not equipped
	if equipped then
		action.Text = "EQUIPPED"
	elseif owned then
		action.Text = "EQUIP"
	else
		action.Text = `BUY  {trail.price}`
	end

	if not equipped then
		action.Activated:Connect(function()
			action.Active = false
			action.Text = "..."
			request(if owned then "EquipTrail" else "PurchaseTrail", trail.id)
		end)
	end
end

refreshCards = function()
	coinLabel.Text = tostring(player:GetAttribute("Coins") or 0)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") and child ~= equippedTemplate and child ~= unequippedTemplate then
			child:Destroy()
		end
	end
	for index, trail in TrailCatalog.list do
		createCard(trail, index)
	end
end

local function showCoinToast(amount)
	if amount <= 0 then
		return
	end
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -70)
	toast.Size = UDim2.fromOffset(180, 44)
	toast.BackgroundColor3 = Color3.fromRGB(31, 35, 51)
	toast.BackgroundTransparency = 0.08
	toast.Font = Enum.Font.LuckiestGuy
	toast.Text = `+{amount} COINS!`
	toast.TextColor3 = Color3.fromRGB(255, 220, 49)
	toast.TextSize = 29
	toast.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.75
	stroke.Thickness = 2
	stroke.Parent = toast
	TweenService:Create(toast, TweenInfo.new(0.32, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(230, 58),
	}):Play()
	task.delay(2.4, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, 0, 1, -105),
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

local function updateAvailability()
	local inRace = player:GetAttribute("IsRace") == true
	shopTrigger.Visible = not inRace
	if inRace then
		overlay.Visible = false
	end
end

function TrailShopController.Start()
	TrailCatalog.refresh()
	local playerGui = player:WaitForChild("PlayerGui")
	screenGui = playerGui:WaitForChild("TrailShop")
	screenGui.Enabled = true
	overlay = screenGui:WaitForChild("Overlay")
	panel = overlay:WaitForChild("Frame")
	list = panel:WaitForChild("TrailList")
	list.ScrollBarThickness = 0
	local listLayout = list:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	equippedTemplate = list:WaitForChild("Equiped")
	unequippedTemplate = list:WaitForChild("Template")
	equippedTemplate.Visible = false
	unequippedTemplate.Visible = false

	local currencyCounter = panel:WaitForChild("CurrencyCounter")
	coinLabel = currencyCounter:WaitForChild("Counter")
	statusLabel = getDirectChild(panel, "TextLabel", function(label)
		return label.Text == ""
	end)
	local close = getDirectChild(panel, "TextButton")
	if not statusLabel or not close then
		warn("[BalapKarung] TrailShop membutuhkan status TextLabel dan close TextButton")
		return
	end

	local interface = playerGui:WaitForChild("Interface")
	shopTrigger = interface:WaitForChild("HUD"):WaitForChild("LeftButtons"):WaitForChild("Shop")
	local openButton = shopTrigger:WaitForChild("Button")
	overlay.Visible = false

	openButton.Activated:Connect(function()
		overlay.Visible = true
		refreshCards()
	end)
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local position = input.Position
			local absolute = panel.AbsolutePosition
			local size = panel.AbsoluteSize
			if
				position.X < absolute.X
				or position.X > absolute.X + size.X
				or position.Y < absolute.Y
				or position.Y > absolute.Y + size.Y
			then
				overlay.Visible = false
			end
		end
	end)

	previousCoins = player:GetAttribute("Coins") or 0
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local coins = player:GetAttribute("Coins") or 0
		if canShowCoinToast and coins > previousCoins then
			showCoinToast(coins - previousCoins)
		end
		previousCoins = coins
		refreshCards()
	end)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			previousCoins = player:GetAttribute("Coins") or 0
			canShowCoinToast = true
		end
	end)
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(refreshCards)
	for _, trail in TrailCatalog.list do
		player:GetAttributeChangedSignal(`OwnsTrail_{trail.id}`):Connect(refreshCards)
	end
	player:GetAttributeChangedSignal("IsRace"):Connect(updateAvailability)
	refreshCards()
	updateAvailability()
	canShowCoinToast = player:GetAttribute("DataLoaded") == true
end

return TrailShopController
