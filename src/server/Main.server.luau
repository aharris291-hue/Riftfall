--!strict
-- Main (server): the single entry point for all server code. It builds the
-- world, starts each service in order, and wires services together.
--
-- Where things live:
--   ServerScriptService/Server/Main            this script
--   ServerScriptService/Server/Services/*      one module per game system
--   ServerScriptService/Server/Util/*          shared helpers
--   ReplicatedStorage/Shared/*                 config, items, story text
--   ReplicatedStorage/Remotes/*                client <-> server messages

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Services = script.Parent.Services
local PlayerData = require(script.Parent.Util.PlayerData)
local LevelBuilder = require(Services.LevelBuilder)
local StoryService = require(Services.StoryService)
local CharacterService = require(Services.CharacterService)
local InventoryService = require(Services.InventoryService)
local InteractionService = require(Services.InteractionService)
local FlashlightService = require(Services.FlashlightService)
local CheckpointService = require(Services.CheckpointService)
local PuzzleService = require(Services.PuzzleService)
local StalkerService = require(Services.StalkerService)
local EscapeService = require(Services.EscapeService)
local GameService = require(Services.GameService)
local GateService = require(Services.GateService)
local DistractionService = require(Services.DistractionService)
local SaveService = require(Services.SaveService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- 1. World
LevelBuilder.SetupLighting()
LevelBuilder.Build()

-- 2. Wiring between services
InventoryService.SpawnDroppedItem = function(itemId, position)
	local def = Items[itemId]
	if def then
		LevelBuilder.SpawnPickup(itemId, def.DisplayName, position, def.Color)
	end
end
PuzzleService.OnSolved = function()
	EscapeService.Begin()
end
CheckpointService.OnPlayerSpawned(function(player)
	InventoryService.Sync(player)
end)
InventoryService.ThrowItem = function(itemId, root)
	if itemId == "Flare" then
		DistractionService.Throw(root)
	end
end
CharacterService.OnTalk = GateService.OnTalk
CheckpointService.OnCheckpointReached(SaveService.OnCheckpoint)
InteractionService.OnEvidenceFound = SaveService.OnEvidence
GameService.OnFinished = SaveService.OnFinished
-- The creature's first appearance: it crosses the trail far ahead, then
-- vanishes. Players meet it properly in the ruins.
StoryService.OnTrigger("Sighting", function()
	task.spawn(StalkerService.PlaySighting, Vector3.new(34, 4, 156), Vector3.new(-26, 4, 150), 3.5)
	task.wait(1.5)
	StoryService.PlayDialogue("Sighting")
end)

-- 3. Services
PlayerData.Init()
StoryService.Init()
CharacterService.Init()
InventoryService.Init()
InteractionService.Init()
FlashlightService.Init()
CheckpointService.Init()
PuzzleService.Init()
StalkerService.Init()
EscapeService.Init()
GateService.Init()
GameService.Init()
SaveService.Init()

StalkerService.SpawnPatrol()

-- Crouch state is reported by the client and only used for stealth checks.
Remotes.SetCrouch.OnServerEvent:Connect(function(player, crouching)
	if type(crouching) == "boolean" then
		player:SetAttribute("Crouching", crouching)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		player:SetAttribute("Crouching", false)
	end)
end)

print("[Riftfall] Server ready.")
