--!strict
-- CharacterService: every character in the game, styled from the Riftfall
-- character concept sheet (see Shared/CharacterDesigns and Util/Outfitter).
--
--  * Players are Jax Mercer. Each player wears one of Jax's outfits
--    (Default, Stealth, Survival, Wanderer, Heavy Armor) and can switch with
--    the Outfit button. The choice is cosmetic only; the server validates it.
--    (StarterPlayer.LoadCharacterAppearance is off, so Roblox avatars never
--    load.)
--  * Story characters (Serra, Kade, Lira, and a dormant Corrupted Soldier)
--    are spawned on "CharacterSpot" markers placed by LevelBuilder. A spot's
--    Phase decides when it is used: Kade and Lira move from the camp and
--    temple to the rescue flare once the escape begins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterDesigns = require(ReplicatedStorage.Shared.CharacterDesigns)
local Outfitter = require(script.Parent.Parent.Util.Outfitter)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Designs = CharacterDesigns.Designs

local CharacterService = {}

-- Talk prompt dialogue per character and phase.
local TALK_DIALOGUE: { [string]: { [string]: string } } = {
	Serra = { Explore = "TalkSerra", Escape = "TalkSerra" },
	Kade = { Explore = "TalkKade", Escape = "TalkKadeEnd" },
	Lira = { Explore = "TalkLira", Escape = "TalkLiraEnd" },
}

------------------------------------------------------------------------------
-- Players
------------------------------------------------------------------------------

local joinCount = 0

local function outfitFor(player: Player): string
	local chosen = player:GetAttribute("OutfitId")
	if type(chosen) == "string" and table.find(CharacterDesigns.PlayerOutfits, chosen) then
		return chosen
	end
	-- First player is classic Jax; co-op partners get different outfits.
	local outfits = CharacterDesigns.PlayerOutfits
	local pick = outfits[(joinCount % #outfits) + 1]
	joinCount += 1
	player:SetAttribute("OutfitId", pick)
	return pick
end

local function dressPlayer(player: Player, character: Model)
	-- Wait briefly for the body parts to exist.
	for _, name in { "Head", "UpperTorso", "LowerTorso" } do
		if not character:FindFirstChild(name) then
			character:WaitForChild(name, 5)
		end
	end
	if character.Parent == nil then
		return
	end
	local design = Designs[outfitFor(player)]
	if Outfitter.Apply(character, design) then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = player.DisplayName
		end
	end
end

local function onChangeOutfit(player: Player)
	if not PlayerData.RateLimit(player, "Outfit", 1) then
		return
	end
	local outfits = CharacterDesigns.PlayerOutfits
	local current = table.find(outfits, outfitFor(player)) or 1
	local nextId = outfits[current % #outfits + 1]
	player:SetAttribute("OutfitId", nextId)
	local character = PlayerData.GetAliveCharacter(player)
	if character then
		Outfitter.Apply(character, Designs[nextId])
	end
	StoryService.Toast(player, "Outfit: " .. Designs[nextId].Title, "info")
end

------------------------------------------------------------------------------
-- Story characters
------------------------------------------------------------------------------

type SpotRecord = { Spot: BasePart, Model: Model?, Phase: string }
local spots: { SpotRecord } = {}

-- A finished model for a story character, if one has been added in Studio
-- at ServerStorage > RiftfallAssets > Characters > <design id>.
local function libraryModel(design: CharacterDesigns.Design): Model?
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	local characters = library and library:FindFirstChild("Characters")
	local model = characters and characters:FindFirstChild(design.Id)
	if model and model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
		local copy = model:Clone()
		copy:SetAttribute("CustomModel", true)
		return copy
	end
	return nil
end

-- Builds a standing, posed R15 character for a design (or uses the
-- finished model from the asset library).
local function buildNPC(design: CharacterDesigns.Design): Model?
	local custom = libraryModel(design)
	if custom then
		custom.Name = design.DisplayName
		local humanoid = custom:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = design.DisplayName .. " - " .. design.Title
		end
		return custom
	end
	local description = Instance.new("HumanoidDescription")
	description.WidthScale = design.Width or 1
	description.DepthScale = design.Width or 1
	description.HeightScale = design.Height or 1
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[CharacterService] Could not build", design.Id, model)
		return nil
	end
	model.Name = design.DisplayName
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = design.DisplayName .. " - " .. design.Title
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 30
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
	end
	-- Remove the default animation script: these characters hold a pose.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	Outfitter.Apply(model, design)
	return model
end

-- Places a model so it stands on the spot's position, facing its direction.
local function standOn(model: Model, spot: BasePart, slump: boolean)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	root.Anchored = true
	model.PrimaryPart = root
	-- Work out how far the root sits above the feet, then stand on the spot.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local rootAboveFeet = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	local target = spot.CFrame + Vector3.new(0, rootAboveFeet - spot.Size.Y / 2 + 0.5, 0)
	if slump then
		-- Leaning back against the pillar, head hanging.
		target = target * CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-22), 0, 0)
	end
	model:PivotTo(target)
end

local function addTalkPrompt(model: Model, characterId: string, phase: string)
	local dialogue = TALK_DIALOGUE[characterId]
	local root = model:FindFirstChild("HumanoidRootPart")
	if not dialogue or not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = model.Name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if PlayerData.RateLimit(player, "Talk", 2) then
			StoryService.PlayDialogue(dialogue[phase] or dialogue.Explore, player)
		end
	end)
end

local function spawnOnSpot(record: SpotRecord)
	local id = record.Spot:GetAttribute("CharacterId")
	if type(id) ~= "string" or not Designs[id] then
		return
	end
	local model = buildNPC(Designs[id])
	if not model then
		return
	end
	standOn(model, record.Spot, id == "CorruptedSoldier")
	addTalkPrompt(model, id, record.Phase)
	record.Model = model
end

-- Shows the characters whose spot matches the current story phase.
local function refreshVisibility()
	local phase = StoryService.GetPhase()
	for _, record in spots do
		local model = record.Model
		local spot = record.Spot
		if model and spot.Parent then
			local visible = record.Phase == "Any" or record.Phase == phase
			model.Parent = if visible then spot.Parent else nil
		end
	end
end

local function bindSpot(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local phase = inst:GetAttribute("Phase")
	local record: SpotRecord = { Spot = inst, Model = nil, Phase = if type(phase) == "string" then phase else "Any" }
	table.insert(spots, record)
	spawnOnSpot(record)
	refreshVisibility()
	-- Forget spots (and their characters) when the level is rebuilt.
	inst.AncestryChanged:Connect(function()
		if inst:IsDescendantOf(workspace) then
			return
		end
		local index = table.find(spots, record)
		if index then
			table.remove(spots, index)
		end
		if record.Model then
			record.Model:Destroy()
		end
	end)
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function CharacterService.Init()
	Remotes.ChangeOutfit.OnServerEvent:Connect(onChangeOutfit)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			dressPlayer(player, character)
		end)
		if player.Character then
			task.spawn(dressPlayer, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(refreshVisibility)
	Zones.BindTag("CharacterSpot", bindSpot)
end

-- Exposed for tests: dress any R15 model as a design id.
function CharacterService.DressModel(model: Model, designId: string): boolean
	local design = Designs[designId]
	return design ~= nil and Outfitter.Apply(model, design)
end

return CharacterService
