local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MusicPlayerState = require(ReplicatedStorage.Shared.MusicPlayerState)

local e = React.createElement
local player = Players.LocalPlayer

local COLORS = {
	background = Color3.fromRGB(15, 19, 31),
	panel = Color3.fromRGB(25, 31, 49),
	panelSoft = Color3.fromRGB(40, 48, 72),
	text = Color3.fromRGB(249, 250, 255),
	muted = Color3.fromRGB(166, 176, 201),
	yellow = Color3.fromRGB(255, 214, 42),
	red = Color3.fromRGB(231, 34, 62),
	green = Color3.fromRGB(61, 220, 121),
}

local function RoundedButton(props)
	return e("TextButton", {
		Active = props.active ~= false,
		AnchorPoint = props.anchorPoint,
		AutoButtonColor = true,
		BackgroundColor3 = props.backgroundColor or COLORS.panelSoft,
		BackgroundTransparency = props.backgroundTransparency or 0,
		Font = props.font or Enum.Font.GothamBold,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		Text = props.text,
		TextColor3 = props.textColor or COLORS.text,
		TextSize = props.textSize or 20,
		ZIndex = props.zIndex or 104,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, props.radius or 14) }),
	})
end

local function Toggle(props)
	return e(RoundedButton, {
		backgroundColor = if props.enabled then COLORS.green else Color3.fromRGB(70, 75, 91),
		layoutOrder = props.layoutOrder,
		onActivated = props.onActivated,
		size = UDim2.fromOffset(190, 54),
		text = `{props.label}  {if props.enabled then "ON" else "OFF"}`,
		textColor = if props.enabled then Color3.fromRGB(17, 48, 30) else COLORS.text,
		textSize = 16,
	})
end

local function MusicTile(props)
	local track = props.track
	local selected = props.selected
	return e("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = if selected then track.accent else COLORS.panelSoft,
		BackgroundTransparency = if selected then 0.05 else 0.18,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(218, 104),
		Text = "",
		ZIndex = 103,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Accent = e("Frame", {
			BackgroundColor3 = track.accent,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(72, 80),
			ZIndex = 104,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new(track.accent, Color3.fromRGB(28, 31, 45)),
				Rotation = 40,
			}),
			Icon = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(1, 1),
				Text = "♫",
				TextColor3 = COLORS.text,
				TextSize = 40,
				ZIndex = 105,
			}),
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(94, 17),
			Size = UDim2.new(1, -104, 0, 45),
			Text = track.title,
			TextColor3 = COLORS.text,
			TextSize = 17,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 104,
		}),
		Artist = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(94, 67),
			Size = UDim2.new(1, -104, 0, 22),
			Text = track.artist,
			TextColor3 = if selected then COLORS.text else COLORS.muted,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 104,
		}),
	})
end

local function MusicApp(props)
	local soundController = props.soundController
	local isOpen, setIsOpen = React.useState(false)
	local state, setState = React.useState(soundController.GetMusicState())
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		return soundController.SubscribeMusic(setState)
	end, { soundController })

	React.useEffect(function()
		if not isOpen then
			return
		end
		local scale = scaleRef.current
		if scale then
			scale:SetAttribute("Desktop", 1)
			scale:SetAttribute("Mobile", 0.33)
			CollectionService:AddTag(scale, GameConfig.ui.dynamicScaleTag)
		end
	end, { isOpen })

	React.useEffect(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local musicGroup = playerGui
			:WaitForChild("Interface")
			:WaitForChild("HUD")
			:WaitForChild("LeftButtons")
			:WaitForChild("Music")
		local button = musicGroup:WaitForChild("Button")
		local connections = {}
		local function updateAvailability()
			local inRace = player:GetAttribute("IsRace") == true
			musicGroup.Visible = not inRace
			if inRace then
				setIsOpen(false)
			end
		end
		table.insert(
			connections,
			button.Activated:Connect(function()
				setIsOpen(true)
			end)
		)
		table.insert(
			connections,
			player:GetAttributeChangedSignal("IsRace"):Connect(updateAvailability)
		)
		updateAvailability()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	if not isOpen then
		return nil
	end

	local activeTrack = MusicPlayerState.getSelectedTrack(state)
	local volumePercent = math.floor(state.volume * 100 + 0.5)

	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 100,
		[React.Event.Activated] = function()
			setIsOpen(false)
		end,
	}, {
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = COLORS.background,
			BackgroundTransparency = 0.1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(980, 700),
			ZIndex = 101,
		}, {
			Scale = e("UIScale", {
				Scale = 1,
				ref = scaleRef,
			}),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 24) }),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.LuckiestGuy,
				Position = UDim2.fromOffset(28, 20),
				Size = UDim2.fromOffset(380, 56),
				Text = "MUSIC PLAYER",
				TextColor3 = COLORS.yellow,
				TextSize = 38,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 102,
			}),
			Close = e(RoundedButton, {
				anchorPoint = Vector2.new(1, 0),
				backgroundColor = COLORS.red,
				onActivated = function()
					setIsOpen(false)
				end,
				position = UDim2.new(1, -20, 0, 18),
				size = UDim2.fromOffset(52, 52),
				text = "×",
				textSize = 32,
				zIndex = 104,
			}),
			NowPlaying = e("Frame", {
				BackgroundColor3 = COLORS.panel,
				Position = UDim2.fromOffset(24, 90),
				Size = UDim2.new(1, -48, 0, 138),
				ZIndex = 102,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 18) }),
				Accent = e("Frame", {
					BackgroundColor3 = activeTrack and activeTrack.accent or COLORS.red,
					Position = UDim2.fromOffset(14, 14),
					Size = UDim2.fromOffset(110, 110),
					ZIndex = 103,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
					Icon = e("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						Size = UDim2.fromScale(1, 1),
						Text = "♫",
						TextColor3 = COLORS.text,
						TextSize = 58,
						ZIndex = 104,
					}),
				}),
				Track = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromOffset(144, 22),
					Size = UDim2.new(1, -530, 0, 44),
					Text = activeTrack and activeTrack.title or "No Track",
					TextColor3 = COLORS.text,
					TextSize = 27,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 103,
				}),
				Artist = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Position = UDim2.fromOffset(144, 66),
					Size = UDim2.new(1, -530, 0, 30),
					Text = activeTrack and activeTrack.artist or "",
					TextColor3 = COLORS.muted,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 103,
				}),
				Controls = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.fromOffset(350, 62),
					ZIndex = 103,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Previous = e(RoundedButton, {
						layoutOrder = 1,
						onActivated = soundController.PreviousTrack,
						size = UDim2.fromOffset(96, 52),
						text = "PREV",
						textSize = 15,
					}),
					Play = e(RoundedButton, {
						backgroundColor = COLORS.yellow,
						layoutOrder = 2,
						onActivated = soundController.ToggleMusicPlayback,
						size = UDim2.fromOffset(118, 60),
						text = if state.isPlaying then "PAUSE" else "PLAY",
						textColor = Color3.fromRGB(38, 33, 15),
						textSize = 17,
					}),
					Next = e(RoundedButton, {
						layoutOrder = 3,
						onActivated = soundController.NextTrack,
						size = UDim2.fromOffset(96, 52),
						text = "NEXT",
						textSize = 15,
					}),
				}),
			}),
			Volume = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(28, 242),
				Size = UDim2.new(1, -56, 0, 52),
				ZIndex = 102,
			}, {
				Label = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Size = UDim2.fromOffset(150, 52),
					Text = `VOLUME  {volumePercent}%`,
					TextColor3 = COLORS.text,
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 103,
				}),
				Minus = e(RoundedButton, {
					onActivated = function()
						soundController.SetMusicVolume(state.volume - 0.1)
					end,
					position = UDim2.fromOffset(158, 4),
					size = UDim2.fromOffset(44, 44),
					text = "−",
				}),
				Bar = e("Frame", {
					BackgroundColor3 = COLORS.panelSoft,
					Position = UDim2.fromOffset(216, 17),
					Size = UDim2.new(1, -420, 0, 18),
					ZIndex = 103,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = e("Frame", {
						BackgroundColor3 = COLORS.yellow,
						Size = UDim2.fromScale(state.volume, 1),
						ZIndex = 104,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
				Plus = e(RoundedButton, {
					anchorPoint = Vector2.new(1, 0),
					onActivated = function()
						soundController.SetMusicVolume(state.volume + 0.1)
					end,
					position = UDim2.new(1, -190, 0, 4),
					size = UDim2.fromOffset(44, 44),
					text = "+",
				}),
				Mute = e(RoundedButton, {
					anchorPoint = Vector2.new(1, 0),
					backgroundColor = if state.volume > 0 then COLORS.panelSoft else COLORS.red,
					onActivated = function()
						soundController.SetMusicVolume(if state.volume > 0 then 0 else 0.35)
					end,
					position = UDim2.new(1, 0, 0, 4),
					size = UDim2.fromOffset(170, 44),
					text = if state.volume > 0 then "MUTE" else "UNMUTE",
					textSize = 15,
				}),
			}),
			PlaylistTitle = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.LuckiestGuy,
				Position = UDim2.fromOffset(28, 300),
				Size = UDim2.fromOffset(260, 42),
				Text = "PLAYLIST",
				TextColor3 = COLORS.text,
				TextSize = 27,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 102,
			}),
			Playlist = e("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromOffset(24, 344),
				ScrollBarThickness = 0,
				Size = UDim2.new(1, -48, 0, 238),
				ZIndex = 102,
			}, {
				Grid = e("UIGridLayout", {
					CellPadding = UDim2.fromOffset(14, 14),
					CellSize = UDim2.fromOffset(218, 104),
					FillDirectionMaxCells = 4,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Tracks = e(
					React.Fragment,
					nil,
					(function()
						local children = {}
						for index, track in state.tracks do
							children[track.id] = e(MusicTile, {
								layoutOrder = index,
								onActivated = function()
									soundController.SelectTrack(track.id)
								end,
								selected = track.id == state.selectedTrackId,
								track = track,
							})
						end
						return children
					end)()
				),
			}),
			Settings = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(28, 610),
				Size = UDim2.new(1, -56, 0, 58),
				ZIndex = 102,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 14),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Music = e(Toggle, {
					enabled = state.musicEnabled,
					label = "MUSIC",
					layoutOrder = 1,
					onActivated = function()
						soundController.SetMusicEnabled(not state.musicEnabled)
					end,
				}),
				Sfx = e(Toggle, {
					enabled = state.sfxEnabled,
					label = "SFX",
					layoutOrder = 2,
					onActivated = function()
						soundController.SetSfxEnabled(not state.sfxEnabled)
					end,
				}),
			}),
		}),
	})
end

return MusicApp
