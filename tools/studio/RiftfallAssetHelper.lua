--!strict
-- Riftfall Asset Helper: a Roblox Studio plugin that turns any model you
-- insert from the Toolbox into a Riftfall scenery piece with one click.
--
-- Install: in Studio, Plugins tab > Plugins Folder, copy this file into the
-- folder that opens, then restart Studio. A "Riftfall" toolbar appears in
-- the Plugins tab.
--
-- Use: insert a model from the Toolbox (it is selected automatically), then
-- click the button for what it should replace (Tree, Arch, 4x4...). The
-- helper:
--   * deletes every script inside it (free models sometimes hide bad ones),
--   * anchors it and sets its pivot to the bottom centre,
--   * resizes it to fit the level,
--   * moves it to ServerStorage > RiftfallAssets > <slot name>.
-- Press Play to see it replace every placeholder of that kind. Adding more
-- than one model to the same slot gives random variety (trees, ferns).
-- Everything can be undone with Ctrl+Z.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

-- Slot name (must match src/server/Util/SceneryKit.luau), button label, and
-- the size to fit: Height = studs tall, Length = longest side in studs.
type Slot = { Name: string, Label: string, Height: number?, Length: number? }
local SLOTS: { Slot } = {
	{ Name = "JungleTree", Label = "Tree", Height = 30 },
	{ Name = "Fern", Label = "Fern", Height = 3 },
	{ Name = "StoneArch", Label = "Arch", Height = 23 },
	{ Name = "BrokenStoneArch", Label = "Broken Arch", Height = 19 },
	{ Name = "Torch", Label = "Torch", Height = 6.5 },
	{ Name = "Tent", Label = "Tent", Length = 9 },
	{ Name = "SupplyCases", Label = "Crates", Length = 9 },
	{ Name = "Expedition4x4", Label = "4x4", Length = 12 },
	{ Name = "CrashedHelicopter", Label = "Helicopter", Length = 34 },
}

local function say(text: string)
	print("[Riftfall Asset Helper] " .. text)
end

-- Turns whatever was selected into a single Model.
local function asModel(selected: Instance): Model?
	if selected:IsA("Model") then
		return selected
	end
	if selected:IsA("BasePart") or selected:IsA("Folder") then
		local model = Instance.new("Model")
		model.Name = selected.Name
		model.Parent = selected.Parent
		if selected:IsA("Folder") then
			for _, child in selected:GetChildren() do
				child.Parent = model
			end
			selected:Destroy()
		else
			selected.Parent = model
		end
		return model
	end
	return nil
end

local function clean(model: Model): number
	local removed = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed += 1
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return removed
end

-- A torch needs to light its surroundings: give one without a light a warm
-- glow at its highest point.
local function addFlameLight(model: Model)
	local top: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (not top or d.CFrame.Position.Y > top.CFrame.Position.Y) then
			top = d
		end
	end
	if top then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Range = 22
		light.Brightness = 1.6
		light.Shadows = true
		light.Parent = top
	end
end

local function fitSize(model: Model, slot: Slot)
	local _, size = model:GetBoundingBox()
	local current = if slot.Height then size.Y else math.max(size.X, size.Z)
	local target = slot.Height or slot.Length or current
	if current > 0.01 then
		model:ScaleTo(model:GetScale() * target / current)
	end
end

-- Pivot at the bottom centre, keeping the model's facing.
local function groundPivot(model: Model)
	if model.PrimaryPart then
		model.PrimaryPart = nil -- Otherwise the pivot follows that part.
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = box * CFrame.new(0, -size.Y / 2, 0)
end

local function slotFolder(name: string): Folder
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	if not library then
		library = Instance.new("Folder")
		library.Name = "RiftfallAssets"
		library.Parent = ServerStorage
	end
	local folder = (library :: Instance):FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = library
	end
	return folder :: Folder
end

local function assign(slot: Slot)
	local selected = Selection:Get()
	if #selected ~= 1 then
		warn("[Riftfall Asset Helper] Select exactly one model first (click it in the Explorer or the 3D view).")
		return
	end
	local recording = ChangeHistoryService:TryBeginRecording("Riftfall: use as " .. slot.Label)
	local ok, err = pcall(function()
		local model = asModel(selected[1])
		if not model then
			error("That is not a model. Select the model itself, not a script or a light.")
		end
		local removed = clean(model)
		if slot.Name == "Torch" and not model:FindFirstChildWhichIsA("Light", true) then
			addFlameLight(model)
		end
		fitSize(model, slot)
		groundPivot(model)
		local folder = slotFolder(slot.Name)
		model.Name = slot.Name .. "_" .. (#folder:GetChildren() + 1)
		model.Parent = folder
		Selection:Set({ model })
		say(
			string.format(
				"Done: added to %s (%d in this slot). Removed %d script(s). Press Play to see it in the level.",
				slot.Label,
				#folder:GetChildren(),
				removed
			)
		)
	end)
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	if not ok then
		warn("[Riftfall Asset Helper] " .. tostring(err))
	end
end

local toolbar = plugin:CreateToolbar("Riftfall")
for _, slot in SLOTS do
	local button = toolbar:CreateButton(
		"Riftfall_" .. slot.Name,
		"Use the selected model as the game's " .. slot.Label,
		"",
		slot.Label
	)
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(function()
		assign(slot)
	end)
end
