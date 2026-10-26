--!strict
-- InteractionService: item pickups and readable notes.
--
-- Both use Roblox ProximityPrompts, which already work with keyboard (E),
-- gamepad, and touch screens. The server double-checks distance before
-- granting anything, so a modified client cannot grab items from afar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local StoryService = require(script.Parent.StoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MAX_INTERACT_DISTANCE = 14

local InteractionService = {}

local function closeEnough(player: Player, part: BasePart): boolean
	local _, _, root = PlayerData.GetAliveCharacter(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= MAX_INTERACT_DISTANCE
end

local function bindPickup(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local part = inst
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		-- "Taken" guards against two players grabbing the same item at once.
		if part:GetAttribute("Taken") or not closeEnough(player, part) then
			return
		end
		local itemId = part:GetAttribute("ItemId")
		local count = part:GetAttribute("Count")
		if type(itemId) ~= "string" or type(count) ~= "number" or not Items[itemId] then
			return
		end
		part:SetAttribute("Taken", true)
		if InventoryService.Add(player, itemId, count) then
			StoryService.Toast(player, "Picked up " .. Items[itemId].DisplayName, "good")
			part:Destroy()
		else
			part:SetAttribute("Taken", nil)
			StoryService.Toast(player, "Inventory full. Use or drop something first.", "warning")
		end
	end)
end

local function bindNote(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local part = inst
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		if not closeEnough(player, part) then
			return
		end
		local noteId = part:GetAttribute("NoteId")
		if type(noteId) ~= "string" then
			return
		end
		local data = PlayerData.Get(player)
		if data then
			data.NotesRead[noteId] = true
		end
		Remotes.ShowNote:FireClient(player, noteId)
	end)
end

function InteractionService.Init()
	Zones.BindTag("Pickup", bindPickup)
	Zones.BindTag("Note", bindNote)
end

return InteractionService
