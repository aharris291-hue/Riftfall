--!strict
-- HUDController: builds and updates all on-screen UI in code.
--
--   top-left       current objective
--   top-center     short messages ("Picked up Battery", "Checkpoint reached")
--   bottom-left    health, flashlight battery, stamina
--   bottom-center  inventory (click/tap a slot or press 1-4 to use it; the
--                  small X drops it) and radio subtitles above it
--   screen edges   red flash when hurt, dark pulse when the Rift Stalker is near
--   full screen    note reader, death screen, end-of-demo results

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Story = require(ReplicatedStorage.Shared.Story)
local CharacterDesigns = require(ReplicatedStorage.Shared.CharacterDesigns)
local ClientState = require(script.Parent.Parent.ClientState)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local HUDController = {}

local COLORS = {
	Panel = Color3.fromRGB(12, 14, 16),
	Text = Color3.fromRGB(232, 226, 212),
	Muted = Color3.fromRGB(160, 156, 146),
	Accent = Color3.fromRGB(190, 110, 255),
	Health = Color3.fromRGB(200, 60, 60),
	Battery = Color3.fromRGB(110, 190, 255),
	Stamina = Color3.fromRGB(220, 220, 210),
	Good = Color3.fromRGB(110, 230, 150),
	Warning = Color3.fromRGB(255, 190, 80),
}
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

type Props = { [string]: any }

-- Tiny UI helper: create an instance, set properties, add children.
local function new(className: string, props: Props, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function panel(props: Props): Frame
	local frame = new("Frame", props)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = props.BackgroundTransparency or 0.3
	frame.BorderSizePixel = 0
	corner(8).Parent = frame
	return frame
end

local function label(props: Props): TextLabel
	local base: Props = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = COLORS.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return new("TextLabel", base)
end

local gui: ScreenGui
local objectiveText: TextLabel
local toastList: Frame
local subtitleButton: TextButton
local usingLabel: TextLabel
local descLabel: TextLabel
local slotButtons: { TextButton } = {}
local inventoryCopy: { any } = {}
local bars: { [string]: Frame } = {}
local batteryLabel: TextLabel
local edges: { Frame } = {}
local noteFrame: Frame
local noteTitle: TextLabel
local noteBody: TextLabel
local deathFrame: Frame
local endFrame: Frame
local endStats: TextLabel

local dialogueQueue: { any } = {}
local skipCurrentLine = false
local damageFlash = 0

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

-- Brightness option: brightens only this player's screen (exposure), so
-- anyone who finds the night too dark can fix it without code changes.
local BRIGHTNESS_LEVELS = {
	{ Name = "Normal", Exposure = 0 },
	{ Name = "Bright", Exposure = 0.6 },
	{ Name = "Brightest", Exposure = 1.2 },
}

local function buildBrightnessButton()
	local index = 1
	local button = new("TextButton", {
		Name = "Brightness",
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.fromOffset(180, 28),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		Text = "Brightness: Normal",
		Parent = gui,
	}, { corner(6) })
	button.Activated:Connect(function()
		index = index % #BRIGHTNESS_LEVELS + 1
		local level = BRIGHTNESS_LEVELS[index]
		Lighting.ExposureCompensation = Config.Lighting.ExposureCompensation + level.Exposure
		button.Text = "Brightness: " .. level.Name
	end)
end

-- Outfit option: cycles Jax's outfits (cosmetic; the server applies it).
local function buildOutfitButton()
	local button = new("TextButton", {
		Name = "Outfit",
		Position = UDim2.fromOffset(202, 86),
		Size = UDim2.fromOffset(154, 28),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		Text = "Outfit",
		Parent = gui,
	}, { corner(6) })
	local function refresh()
		local id = player:GetAttribute("OutfitId")
		local design = if type(id) == "string" then CharacterDesigns.Designs[id] else nil
		button.Text = "Outfit: " .. (if design then design.Title else "Default Outfit")
	end
	player:GetAttributeChangedSignal("OutfitId"):Connect(refresh)
	refresh()
	button.Activated:Connect(function()
		Remotes.ChangeOutfit:FireServer()
	end)
end

local function buildObjective()
	local frame = panel({
		Name = "Objective",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(340, 64),
		Parent = gui,
	})
	label({
		Text = "OBJECTIVE",
		TextSize = 12,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Accent,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 14),
		Parent = frame,
	})
	objectiveText = label({
		Text = "",
		TextSize = 16,
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -24, 1, -30),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
end

local function buildToasts()
	toastList = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function makeBar(parent: Instance, name: string, color: Color3, y: number, height: number)
	local back = new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, height),
		BackgroundColor3 = Color3.fromRGB(40, 40, 44),
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(4) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, { corner(4) })
	bars[name] = fill
end

local function buildBars()
	local frame = panel({
		Name = "Vitals",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 96),
		Parent = gui,
	})
	label({
		Text = "HEALTH",
		TextSize = 11,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 12),
		Parent = frame,
	})
	makeBar(frame, "Health", COLORS.Health, 20, 10)
	batteryLabel = label({
		Text = "FLASHLIGHT (F)",
		TextSize = 11,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 12),
		Parent = frame,
	})
	makeBar(frame, "Battery", COLORS.Battery, 50, 10)
	label({
		Text = "STAMINA",
		TextSize = 11,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 0, 12),
		Parent = frame,
	})
	makeBar(frame, "Stamina", COLORS.Stamina, 80, 6)
end

local function refreshInventory()
	for i, button in slotButtons do
		local slot = inventoryCopy[i]
		local nameLabel = button:FindFirstChild("ItemName") :: TextLabel
		local countLabel = button:FindFirstChild("Count") :: TextLabel
		local dropButton = button:FindFirstChild("Drop") :: TextButton
		local swatch = button:FindFirstChild("Swatch") :: Frame
		if slot and Items[slot.Id] then
			local def = Items[slot.Id]
			nameLabel.Text = def.DisplayName
			countLabel.Text = if slot.Count > 1 then "x" .. slot.Count else ""
			dropButton.Visible = not def.KeyItem
			swatch.Visible = true
			swatch.BackgroundColor3 = def.Color
		else
			nameLabel.Text = ""
			countLabel.Text = ""
			dropButton.Visible = false
			swatch.Visible = false
		end
	end
end

local function buildInventory()
	local bar = new("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(Config.Inventory.SlotCount * 78, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, Config.Inventory.SlotCount do
		local button = new("TextButton", {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = COLORS.Panel,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = true,
			Parent = bar,
		}, { corner(8) })
		label({
			Name = "Key",
			Text = tostring(i),
			TextSize = 12,
			Font = FONT_BOLD,
			TextColor3 = COLORS.Muted,
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(14, 14),
			Parent = button,
		})
		new("Frame", {
			Name = "Swatch",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = COLORS.Text,
			BorderSizePixel = 0,
			Visible = false,
			Parent = button,
		}, { corner(9) })
		label({
			Name = "ItemName",
			Text = "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 36),
			Size = UDim2.new(1, -4, 0, 16),
			Parent = button,
		})
		label({
			Name = "Count",
			Text = "",
			TextSize = 12,
			Font = FONT_BOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0, 0, 1, -18),
			Size = UDim2.new(1, -6, 0, 14),
			Parent = button,
		})
		local drop = new("TextButton", {
			Name = "Drop",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromRGB(70, 40, 40),
			Text = "X",
			Font = FONT_BOLD,
			TextSize = 11,
			TextColor3 = COLORS.Text,
			Visible = false,
			Parent = button,
		}, { corner(9) })
		button.Activated:Connect(function()
			Remotes.UseItem:FireServer(i)
		end)
		drop.Activated:Connect(function()
			Remotes.DropItem:FireServer(i)
		end)
		button.MouseEnter:Connect(function()
			local slot = inventoryCopy[i]
			descLabel.Text = if slot and Items[slot.Id] then Items[slot.Id].Description else ""
		end)
		button.MouseLeave:Connect(function()
			descLabel.Text = ""
		end)
		slotButtons[i] = button
	end
	descLabel = label({
		Name = "Description",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(360, 18),
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = gui,
	})
	usingLabel = label({
		Name = "Using",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(360, 20),
		TextSize = 15,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = gui,
	})
end

local function buildSubtitles()
	subtitleButton = new("TextButton", {
		Name = "Subtitles",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromScale(0.6, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT,
		TextSize = 18,
		TextColor3 = COLORS.Text,
		TextWrapped = true,
		RichText = true,
		Text = "",
		Visible = false,
		Parent = gui,
	}, {
		corner(8),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		new("UISizeConstraint", { MaxSize = Vector2.new(720, math.huge) }),
	})
	-- Click/tap the subtitle (or press Enter) to skip the current line.
	subtitleButton.Activated:Connect(function()
		skipCurrentLine = true
	end)
end

local function makeEdge(name: string, anchor: Vector2, position: UDim2, size: UDim2, rotation: number)
	local edge = new("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = COLORS.Health,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		-- Solid at the screen edge, fading to nothing toward the middle.
		new("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(0, 1) }),
	})
	edge.Visible = false
	table.insert(edges, edge)
end

local function buildEdges()
	makeEdge("EdgeTop", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90)
	makeEdge("EdgeBottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.22), -90)
	makeEdge("EdgeLeft", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.18, 1), 0)
	makeEdge("EdgeRight", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.18, 1), 180)
end

local function buildNoteReader()
	noteFrame = panel({
		Name = "NoteReader",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	noteFrame.BackgroundColor3 = Color3.fromRGB(34, 30, 24)
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 460), Parent = noteFrame })
	noteTitle = label({
		Text = "",
		TextSize = 20,
		Font = FONT_BOLD,
		TextColor3 = Color3.fromRGB(240, 220, 170),
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 26),
		ZIndex = 11,
		Parent = noteFrame,
	})
	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 1, -110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = noteFrame,
	})
	noteBody = label({
		Text = "",
		TextSize = 17,
		Font = Enum.Font.Merriweather,
		TextColor3 = Color3.fromRGB(230, 220, 200),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 11,
		Parent = scroll,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 38),
		BackgroundColor3 = Color3.fromRGB(70, 60, 48),
		Font = FONT_BOLD,
		TextSize = 16,
		TextColor3 = COLORS.Text,
		Text = "Close (Enter)",
		ZIndex = 11,
		Parent = noteFrame,
	}, { corner(6) })
	close.Activated:Connect(function()
		noteFrame.Visible = false
		ClientState.ModalOpen = false
	end)
end

local function buildDeathScreen()
	deathFrame = new("Frame", {
		Name = "Death",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	label({
		Text = "YOU DIDN'T MAKE IT",
		TextSize = 34,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Health,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(600, 44),
		ZIndex = 21,
		Parent = deathFrame,
	})
	label({
		Text = "Returning to your last checkpoint...",
		TextSize = 18,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(600, 24),
		ZIndex = 21,
		Parent = deathFrame,
	})
end

local function buildEndScreen()
	endFrame = new("Frame", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 6, 10),
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	label({
		Text = "CHAPTER 1: THE FORGOTTEN EXPEDITION",
		TextSize = 16,
		Font = FONT_BOLD,
		TextColor3 = COLORS.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(0.9, 0, 0, 22),
		ZIndex = 31,
		Parent = endFrame,
	})
	label({
		Text = "DEMO COMPLETE",
		TextSize = 42,
		Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 28),
		Size = UDim2.new(0.9, 0, 0, 50),
		ZIndex = 31,
		Parent = endFrame,
	})
	endStats = label({
		Text = "",
		TextSize = 18,
		TextColor3 = COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 100),
		Size = UDim2.new(0.9, 0, 0, 140),
		ZIndex = 31,
		Parent = endFrame,
	})
	label({
		Text = "Riftfall: The Last Ascent continues in Chapter 2 - Blackstone Research Facility.",
		TextSize = 14,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 240),
		Size = UDim2.new(0.9, 0, 0, 40),
		ZIndex = 31,
		Parent = endFrame,
	})
	local again = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 290),
		Size = UDim2.fromOffset(200, 46),
		BackgroundColor3 = COLORS.Accent,
		Font = FONT_BOLD,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Play Again",
		ZIndex = 31,
		Parent = endFrame,
	}, { corner(8) })
	again.Activated:Connect(function()
		Remotes.RequestReplay:FireServer()
	end)
end

local function buildControlsHint()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return -- Touch players get on-screen buttons instead.
	end
	label({
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(260, 100),
		TextSize = 13,
		TextColor3 = COLORS.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "WASD  move\nShift  sprint (loud)\nC  crouch (quiet)\nF  flashlight\nE  interact     1-4  use item",
		Parent = gui,
	})
end

------------------------------------------------------------------------------
-- Behaviour
------------------------------------------------------------------------------

local TOAST_COLORS: { [string]: Color3 } = {
	info = COLORS.Text,
	good = COLORS.Good,
	warning = COLORS.Warning,
	objective = COLORS.Accent,
	checkpoint = COLORS.Good,
}

local function showToast(text: string, kind: string)
	local toast = label({
		Text = text,
		TextSize = 16,
		Font = FONT_BOLD,
		TextColor3 = TOAST_COLORS[kind] or COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromOffset(400, 32),
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastList,
	})
	corner(6).Parent = toast
	task.delay(3, function()
		local tween =
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

local function escapeRichText(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function runDialogue()
	while true do
		local line = table.remove(dialogueQueue, 1)
		if not line then
			subtitleButton.Visible = false
			return
		end
		if type(line) == "table" and type(line.Text) == "string" then
			subtitleButton.Text = string.format(
				'<font color="#be6eff"><b>%s</b></font>   %s',
				escapeRichText(tostring(line.Speaker or "")),
				escapeRichText(line.Text)
			)
			subtitleButton.Visible = true
			skipCurrentLine = false
			local endTime = os.clock() + (tonumber(line.Duration) or 4)
			while os.clock() < endTime and not skipCurrentLine do
				task.wait(0.05)
			end
		end
	end
end

local dialogueRunning = false
local function queueDialogue(lines: any)
	if type(lines) ~= "table" then
		return
	end
	for _, line in lines do
		table.insert(dialogueQueue, line)
	end
	if not dialogueRunning then
		dialogueRunning = true
		task.spawn(function()
			runDialogue()
			dialogueRunning = false
		end)
	end
end

local function showNote(noteId: string)
	local note = (Story.Notes :: any)[noteId]
	if not note then
		return
	end
	noteTitle.Text = note.Title
	noteBody.Text = note.Body
	noteFrame.Visible = true
	ClientState.ModalOpen = true
end

local function formatTime(seconds: number): string
	local s = math.floor(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

local function showEnd(stats: any)
	if type(stats) ~= "table" then
		return
	end
	endStats.Text = string.format(
		"Time: %s\nDeaths: %d\nNotes found: %d / %d\nRift Shard recovered: %s",
		formatTime(tonumber(stats.Time) or 0),
		tonumber(stats.Deaths) or 0,
		tonumber(stats.NotesRead) or 0,
		tonumber(stats.NotesTotal) or 0,
		if stats.FoundShard then "Yes" else "No (it's in the temple...)"
	)
	endFrame.Visible = true
	ClientState.ModalOpen = true
end

local function bindCharacter(character: Model)
	deathFrame.Visible = false
	deathFrame.BackgroundTransparency = 1
	endFrame.Visible = false
	ClientState.ModalOpen = noteFrame.Visible
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 then
			damageFlash = 1
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		deathFrame.Visible = true
		TweenService:Create(deathFrame, TweenInfo.new(1.2), { BackgroundTransparency = 0.2 }):Play()
	end)
end

function HUDController.Init()
	gui = new("ScreenGui", {
		Name = "RiftfallHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildEdges()
	buildObjective()
	buildBrightnessButton()
	buildOutfitButton()
	buildToasts()
	buildBars()
	buildInventory()
	buildSubtitles()
	buildControlsHint()
	buildNoteReader()
	buildDeathScreen()
	buildEndScreen()
	refreshInventory()

	-- Objective (stored on ReplicatedStorage so late joiners see it too).
	local function updateObjective()
		local text = ReplicatedStorage:GetAttribute("Objective")
		objectiveText.Text = if type(text) == "string" then text else ""
	end
	ReplicatedStorage:GetAttributeChangedSignal("Objective"):Connect(updateObjective)
	updateObjective()

	-- Item-use progress text.
	player:GetAttributeChangedSignal("UsingItem"):Connect(function()
		local using = player:GetAttribute("UsingItem")
		usingLabel.Text = if type(using) == "string" then "Using " .. using .. "..." else ""
	end)

	Remotes.Toast.OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			showToast(text, if type(kind) == "string" then kind else "info")
		end
	end)
	Remotes.Dialogue.OnClientEvent:Connect(queueDialogue)
	Remotes.ShowNote.OnClientEvent:Connect(function(noteId)
		if type(noteId) == "string" then
			showNote(noteId)
		end
	end)
	Remotes.InventoryChanged.OnClientEvent:Connect(function(slots)
		if type(slots) == "table" then
			inventoryCopy = {}
			for i = 1, Config.Inventory.SlotCount do
				local slot = slots[i]
				inventoryCopy[i] = if type(slot) == "table" then slot else nil
			end
			refreshInventory()
		end
	end)
	Remotes.RunComplete.OnClientEvent:Connect(showEnd)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
		local index = table.find(slotKeys, input.KeyCode)
		if index and index <= Config.Inventory.SlotCount then
			Remotes.UseItem:FireServer(index)
		elseif input.KeyCode == Enum.KeyCode.Return then
			if noteFrame.Visible then
				noteFrame.Visible = false
				ClientState.ModalOpen = endFrame.Visible
			else
				skipCurrentLine = true
			end
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	-- Per-frame bar and edge-effect updates (cheap property sets only).
	local pulse = 0
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local healthFraction = 0
		if humanoid and humanoid.MaxHealth > 0 then
			healthFraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		end
		bars.Health.Size = UDim2.fromScale(healthFraction, 1)

		local battery = player:GetAttribute("Battery")
		local batteryFraction = if type(battery) == "number" then battery / Config.Flashlight.MaxBattery else 0
		bars.Battery.Size = UDim2.fromScale(math.clamp(batteryFraction, 0, 1), 1)
		local lightOn = player:GetAttribute("FlashlightOn") == true
		bars.Battery.BackgroundColor3 = if batteryFraction < 0.2 then COLORS.Warning else COLORS.Battery
		batteryLabel.Text = if lightOn then "FLASHLIGHT (F) - ON" else "FLASHLIGHT (F) - OFF"

		bars.Stamina.Size = UDim2.fromScale(math.clamp(ClientState.Stamina / Config.Player.MaxStamina, 0, 1), 1)

		-- Edge glow: damage flash (red) beats danger pulse (dark violet).
		damageFlash = math.max(0, damageFlash - dt * 1.6)
		pulse += dt * (2 + ClientState.Danger * 4)
		local danger = ClientState.Danger * (0.6 + 0.4 * math.sin(pulse))
		local lowHealth = if healthFraction > 0 and healthFraction < 0.35 then 0.35 else 0
		local strength = math.max(damageFlash, danger * 0.7, lowHealth)
		local color = if damageFlash > danger * 0.7 or lowHealth > danger * 0.7
			then COLORS.Health
			else Color3.fromRGB(70, 20, 90)
		for _, edge in edges do
			edge.Visible = strength > 0.02
			edge.BackgroundColor3 = color
			edge.BackgroundTransparency = 1 - strength * 0.8
		end
	end)
end

return HUDController
