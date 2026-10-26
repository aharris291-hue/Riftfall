--!strict
-- CheckpointService: remembers each player's furthest checkpoint, respawns
-- them there after death, and handles falling off the map.
--
-- Checkpoints only move forward, so walking back past an old checkpoint
-- never sends you further back on your next death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)

local CheckpointService = {}

-- Listeners notified when a player dies / spawns (set up by other services).
local diedListeners: { (Player) -> () } = {}
local spawnedListeners: { (Player, Model) -> () } = {}

function CheckpointService.OnPlayerDied(callback: (Player) -> ())
	table.insert(diedListeners, callback)
end

function CheckpointService.OnPlayerSpawned(callback: (Player, Model) -> ())
	table.insert(spawnedListeners, callback)
end

-- Sets a checkpoint if it is further along than the player's current one.
function CheckpointService.Set(player: Player, order: number, spawnPosition: Vector3, name: string?)
	local data = PlayerData.Get(player)
	if not data or order <= data.CheckpointOrder then
		return
	end
	data.CheckpointOrder = order
	data.CheckpointSpawn = spawnPosition
	if name then
		StoryService.Toast(player, "Checkpoint reached: " .. name, "checkpoint")
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root then
		return
	end
	local data = PlayerData.Get(player)
	if data and data.CheckpointSpawn then
		-- Wait one frame so the default spawn placement finishes first.
		task.defer(function()
			if character.Parent then
				character:PivotTo(CFrame.new(data.CheckpointSpawn :: Vector3) * CFrame.Angles(0, math.pi, 0))
			end
		end)
	end
	humanoid.Died:Connect(function()
		local d = PlayerData.Get(player)
		if d then
			d.Deaths += 1
		end
		for _, callback in diedListeners do
			task.spawn(callback, player)
		end
	end)
	for _, callback in spawnedListeners do
		task.spawn(callback, player, character)
	end
end

function CheckpointService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local _, humanoid, root = PlayerData.GetAliveCharacter(player)
				if not humanoid or not root then
					continue
				end
				-- Falling into the chasm (or out of the world) is fatal.
				if root.Position.Y < Config.World.KillHeight then
					humanoid.Health = 0
					continue
				end
				for _, zone in CollectionService:GetTagged("Checkpoint") do
					if zone:IsA("BasePart") and Zones.Contains(zone, root.Position) then
						local order = zone:GetAttribute("Order")
						local spawnPos = zone:GetAttribute("SpawnPosition")
						local name = zone:GetAttribute("CheckpointName")
						if type(order) == "number" and typeof(spawnPos) == "Vector3" then
							CheckpointService.Set(player, order, spawnPos, if type(name) == "string" then name else nil)
						end
					end
				end
			end
		end
	end)
end

return CheckpointService
