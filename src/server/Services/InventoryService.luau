--!strict
-- InventoryService: a small slot-based inventory that lives only on the
-- server. Clients receive a read-only copy for the UI and can only *ask* to
-- use or drop a slot; every request is validated here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InventoryService = {}

-- Set by Main: spawns a world pickup (used when a player drops an item).
InventoryService.SpawnDroppedItem = nil :: ((itemId: string, position: Vector3) -> ())?

function InventoryService.Sync(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local copy = {}
	for i = 1, Config.Inventory.SlotCount do
		local slot = data.Inventory[i]
		copy[i] = if slot then { Id = slot.Id, Count = slot.Count } else false
	end
	Remotes.InventoryChanged:FireClient(player, copy)
end

-- Tries to add `count` of an item. Returns true only if everything fit.
function InventoryService.Add(player: Player, itemId: string, count: number): boolean
	local data = PlayerData.Get(player)
	local def = Items[itemId]
	if not data or not def then
		return false
	end
	-- Check capacity first so a partial add never happens.
	local room = 0
	for i = 1, Config.Inventory.SlotCount do
		local slot = data.Inventory[i]
		if slot == nil then
			room += def.MaxStack
		elseif slot.Id == itemId then
			room += def.MaxStack - slot.Count
		end
	end
	if room < count then
		return false
	end
	local remaining = count
	for i = 1, Config.Inventory.SlotCount do
		local slot = data.Inventory[i]
		if slot and slot.Id == itemId and slot.Count < def.MaxStack then
			local add = math.min(remaining, def.MaxStack - slot.Count)
			slot.Count += add
			remaining -= add
		end
		if remaining <= 0 then
			break
		end
	end
	for i = 1, Config.Inventory.SlotCount do
		if remaining <= 0 then
			break
		end
		if data.Inventory[i] == nil then
			local add = math.min(remaining, def.MaxStack)
			data.Inventory[i] = { Id = itemId, Count = add }
			remaining -= add
		end
	end
	InventoryService.Sync(player)
	return true
end

function InventoryService.Count(player: Player, itemId: string): number
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	local total = 0
	for i = 1, Config.Inventory.SlotCount do
		local slot = data.Inventory[i]
		if slot and slot.Id == itemId then
			total += slot.Count
		end
	end
	return total
end

local function removeFromSlot(data: PlayerData.Data, slotIndex: number)
	local slot = data.Inventory[slotIndex]
	if not slot then
		return
	end
	slot.Count -= 1
	if slot.Count <= 0 then
		data.Inventory[slotIndex] = nil
	end
end

local function validSlotIndex(value: any): boolean
	return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= Config.Inventory.SlotCount
end

local function onUseItem(player: Player, slotIndex: any)
	if not validSlotIndex(slotIndex) then
		return
	end
	local data = PlayerData.Get(player)
	if not data or data.Busy then
		return
	end
	if os.clock() - data.LastUse < Config.Inventory.UseCooldown then
		return
	end
	local slot = data.Inventory[slotIndex]
	if not slot then
		return
	end
	local def = Items[slot.Id]
	local _, humanoid = PlayerData.GetAliveCharacter(player)
	if not def or not humanoid then
		return
	end

	-- Decide whether the item would do anything before starting.
	if def.HealAmount then
		if humanoid.Health >= humanoid.MaxHealth then
			StoryService.Toast(player, "Already at full health", "warning")
			return
		end
	elseif def.BatteryAmount then
		if data.Battery >= Config.Flashlight.MaxBattery then
			StoryService.Toast(player, "Flashlight is already fully charged", "warning")
			return
		end
	else
		StoryService.Toast(player, def.DisplayName .. ": " .. def.Description, "info")
		return
	end

	data.Busy = true
	data.LastUse = os.clock()
	player:SetAttribute("UsingItem", def.DisplayName)
	task.wait(def.UseTime)
	player:SetAttribute("UsingItem", nil)
	data.Busy = false

	-- Re-validate after the delay: the player may have died or the slot changed.
	local _, humanoidAfter = PlayerData.GetAliveCharacter(player)
	local slotAfter = data.Inventory[slotIndex]
	if humanoidAfter ~= humanoid or not humanoidAfter or not slotAfter or slotAfter.Id ~= def.Id then
		return
	end
	removeFromSlot(data, slotIndex)
	if def.HealAmount then
		humanoidAfter.Health = math.min(humanoidAfter.MaxHealth, humanoidAfter.Health + def.HealAmount)
		StoryService.Toast(player, "+" .. def.HealAmount .. " health", "good")
	elseif def.BatteryAmount then
		data.Battery = math.min(Config.Flashlight.MaxBattery, data.Battery + def.BatteryAmount)
		player:SetAttribute("Battery", data.Battery)
		StoryService.Toast(player, "Flashlight recharged", "good")
	end
	InventoryService.Sync(player)
end

local function onDropItem(player: Player, slotIndex: any)
	if not validSlotIndex(slotIndex) or not PlayerData.RateLimit(player, "Drop", 0.4) then
		return
	end
	local data = PlayerData.Get(player)
	local _, _, root = PlayerData.GetAliveCharacter(player)
	if not data or not root or data.Busy then
		return
	end
	local slot = data.Inventory[slotIndex]
	if not slot then
		return
	end
	local def = Items[slot.Id]
	if not def or def.KeyItem then
		StoryService.Toast(player, "You can't drop that. You'll need it.", "warning")
		return
	end
	removeFromSlot(data, slotIndex)
	InventoryService.Sync(player)
	if InventoryService.SpawnDroppedItem then
		InventoryService.SpawnDroppedItem(def.Id, root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2, 0))
	end
	StoryService.Toast(player, "Dropped " .. def.DisplayName, "info")
end

function InventoryService.Init()
	Remotes.UseItem.OnServerEvent:Connect(onUseItem)
	Remotes.DropItem.OnServerEvent:Connect(onDropItem)
end

return InventoryService
