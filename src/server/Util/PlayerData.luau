--!strict
-- PlayerData: the server's record of each player's run. The client never
-- writes to this directly; it can only ask (through RemoteEvents) and the
-- server decides.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Slot = { Id: string, Count: number }

export type Data = {
	Inventory: { Slot? },
	Battery: number,
	CheckpointOrder: number,
	CheckpointSpawn: Vector3?,
	Deaths: number,
	NotesRead: { [string]: boolean },
	Evidence: { [string]: boolean }, -- Expedition ID tags found (optional).
	StartTime: number,
	Finished: boolean,
	Busy: boolean, -- True while an item use is in progress.
	LastUse: number,
	LastRequest: { [string]: number }, -- Per-remote rate limiting.
}

local PlayerData = {}

local records: { [Player]: Data } = {}

local function newData(): Data
	return {
		Inventory = {},
		Battery = Config.Flashlight.StartingBattery,
		CheckpointOrder = 0,
		CheckpointSpawn = nil,
		Deaths = 0,
		NotesRead = {},
		Evidence = {},
		StartTime = os.clock(),
		Finished = false,
		Busy = false,
		LastUse = 0,
		LastRequest = {},
	}
end

local reset: (Player) -> Data

-- Returns the player's record, creating it on first use (so services do not
-- depend on the order their PlayerAdded handlers run in). Nil once the
-- player has left.
function PlayerData.Get(player: Player): Data?
	local data = records[player]
	if not data and player.Parent == Players then
		data = reset(player)
	end
	return data
end

function PlayerData.Reset(player: Player): Data
	return reset(player)
end

function reset(player: Player): Data
	local data = newData()
	records[player] = data
	player:SetAttribute("Battery", data.Battery)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("Crouching", false)
	return data
end

-- Returns true if the player may use `action` now; false if too soon.
-- Cheap protection against remote spam from modified clients.
function PlayerData.RateLimit(player: Player, action: string, interval: number): boolean
	local data = records[player]
	if not data then
		return false
	end
	local now = os.clock()
	local last = data.LastRequest[action]
	if last and now - last < interval then
		return false
	end
	data.LastRequest[action] = now
	return true
end

-- Returns the player's living character parts, or nil if not alive.
function PlayerData.GetAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(function(player)
		PlayerData.Get(player)
	end)
	for _, player in Players:GetPlayers() do
		PlayerData.Get(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
	end)
end

return PlayerData
