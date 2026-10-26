--!strict
-- GameService: the start and end of a run. Detects players reaching the
-- rescue flare, shows them their results, and handles "Play Again".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.Shared.Story)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local LevelBuilder = require(script.Parent.LevelBuilder)
local StoryService = require(script.Parent.StoryService)
local InventoryService = require(script.Parent.InventoryService)
local PuzzleService = require(script.Parent.PuzzleService)
local StalkerService = require(script.Parent.StalkerService)
local EscapeService = require(script.Parent.EscapeService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local GameService = {}

local function countNotes(): number
	local total = 0
	for _ in Story.Notes do
		total += 1
	end
	return total
end

local function finishRun(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.Finished then
		return
	end
	data.Finished = true
	local notesRead = 0
	for _ in data.NotesRead do
		notesRead += 1
	end
	StoryService.SetObjective("Done")
	StoryService.PlayDialogue("Done", player)
	Remotes.RunComplete:FireClient(player, {
		Time = os.clock() - data.StartTime,
		Deaths = data.Deaths,
		NotesRead = notesRead,
		NotesTotal = countNotes(),
		FoundShard = InventoryService.Count(player, "RiftShard") > 0,
	})

	-- When every player has made it out, the set-piece is over.
	for _, other in Players:GetPlayers() do
		local otherData = PlayerData.Get(other)
		if otherData and not otherData.Finished then
			return
		end
	end
	EscapeService.Reset()
	StalkerService.Despawn()
end

-- Rebuilds the world and restarts every player from the beginning.
local function fullReset()
	EscapeService.Reset()
	PuzzleService.Reset()
	StoryService.Reset()
	LevelBuilder.Build()
	PuzzleService.Reset() -- Again, now that the new dials exist.
	StalkerService.SpawnPatrol()
	for _, player in Players:GetPlayers() do
		PlayerData.Reset(player)
		InventoryService.Sync(player)
		player:LoadCharacter()
		StoryService.PlayDialogue("Intro", player)
	end
end

local function onReplay(player: Player)
	if not PlayerData.RateLimit(player, "Replay", 3) then
		return
	end
	local data = PlayerData.Get(player)
	if not data or not data.Finished then
		return
	end
	for _, other in Players:GetPlayers() do
		local otherData = PlayerData.Get(other)
		if otherData and not otherData.Finished then
			-- Others are still playing: restart just this player, without
			-- resetting the world under everyone else's feet.
			PlayerData.Reset(player)
			InventoryService.Sync(player)
			player:LoadCharacter()
			return
		end
	end
	fullReset()
end

function GameService.Init()
	Remotes.RequestReplay.OnServerEvent:Connect(onReplay)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local zone = Zones.FirstTagged("EndZone")
			if not zone then
				continue
			end
			for _, player in Players:GetPlayers() do
				local _, _, root = PlayerData.GetAliveCharacter(player)
				if root and Zones.Contains(zone, root.Position) then
					finishRun(player)
				end
			end
		end
	end)
end

return GameService
