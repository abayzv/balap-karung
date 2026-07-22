local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailCatalog = {
	defaultTrailId = "None",
	list = {},
	byId = {},
}

local DEFAULT_TRAIL = {
	id = "None",
	name = "No Trail",
	description = "Tampil simpel tanpa efek trail.",
	price = 0,
	colors = { Color3.fromRGB(150, 156, 170), Color3.fromRGB(230, 234, 242) },
	order = -math.huge,
	thumbnail = nil,
}

local function readAttribute(instance, names, fallback)
	for _, name in names do
		local value = instance:GetAttribute(name)
		if value ~= nil then
			return value
		end
	end
	return fallback
end

local function getPreviewColor(source)
	local emitter = source:FindFirstChildWhichIsA("ParticleEmitter", true)
	if emitter and #emitter.Color.Keypoints > 0 then
		return emitter.Color.Keypoints[1].Value
	end
	return source.Color
end

local function brighten(color)
	return Color3.new(
		math.min(1, color.R * 1.35 + 0.08),
		math.min(1, color.G * 1.35 + 0.08),
		math.min(1, color.B * 1.35 + 0.08)
	)
end

function TrailCatalog.normalizeThumbnail(value)
	if type(value) == "number" then
		local assetId = math.floor(value)
		return if assetId > 0 then `rbxassetid://{assetId}` else nil
	elseif type(value) ~= "string" then
		return nil
	end

	local trimmed = value:match("^%s*(.-)%s*$")
	local lower = string.lower(trimmed)
	local assetId = lower:match("^rbxassetid://(%d+)$")
		or lower:match("^rbx:id[:/]*(%d+)$")
		or lower:match("^rbx:(%d+)$")
		or lower:match("^(%d+)$")
	if not assetId or tonumber(assetId) <= 0 then
		return nil
	end
	return `rbxassetid://{assetId}`
end

local function definitionFromPart(source)
	local displayName = readAttribute(source, { "Name", "DisplayName" }, source.Name)
	if type(displayName) ~= "string" or displayName == "" then
		displayName = source.Name
	end
	local price = tonumber(readAttribute(source, { "Price", "price" }, 100)) or 100
	local description =
		readAttribute(source, { "Description", "description" }, `Trail kosmetik {displayName}.`)
	if type(description) ~= "string" then
		description = `Trail kosmetik {displayName}.`
	end
	local color = getPreviewColor(source)
	return {
		id = source.Name,
		name = displayName,
		description = description,
		price = math.max(0, math.floor(price)),
		colors = { color, brighten(color) },
		thumbnail = TrailCatalog.normalizeThumbnail(
			readAttribute(source, { "Thumbnail", "thumbnail" }, nil)
		),
		order = tonumber(readAttribute(source, { "Order", "LayoutOrder" }, 0)) or 0,
		source = source,
	}
end

function TrailCatalog.refresh()
	table.clear(TrailCatalog.list)
	table.clear(TrailCatalog.byId)
	table.insert(TrailCatalog.list, DEFAULT_TRAIL)
	TrailCatalog.byId[DEFAULT_TRAIL.id] = DEFAULT_TRAIL

	local folder = ReplicatedStorage.Shared:FindFirstChild("Trails")
	if not folder then
		return TrailCatalog.list
	end
	local definitions = {}
	for _, source in folder:GetChildren() do
		if source:IsA("BasePart") then
			if source.Name == TrailCatalog.defaultTrailId then
				warn("[BalapKarung] Part trail tidak boleh bernama 'None'")
			elseif TrailCatalog.byId[source.Name] then
				warn(`[BalapKarung] ID trail duplikat: {source.Name}`)
			else
				local definition = definitionFromPart(source)
				TrailCatalog.byId[definition.id] = definition
				table.insert(definitions, definition)
			end
		end
	end
	table.sort(definitions, function(left, right)
		if left.order ~= right.order then
			return left.order < right.order
		elseif left.price ~= right.price then
			return left.price < right.price
		end
		return left.name < right.name
	end)
	for _, definition in definitions do
		table.insert(TrailCatalog.list, definition)
	end
	return TrailCatalog.list
end

TrailCatalog.refresh()

return TrailCatalog
