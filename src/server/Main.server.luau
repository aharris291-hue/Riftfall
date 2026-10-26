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
local InventoryService = require(Services.InventoryService)
local InteractionService = require(Services.InteractionService)
local FlashlightService = require(Services.FlashlightService)
local CheckpointService = require(Services.CheckpointService)
local PuzzleService = require(Services.PuzzleService)
local StalkerService = require(Services.StalkerService)
local EscapeService = require(Services.EscapeService)
local GameService = require(Services.GameService)

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

-- 3. Services
PlayerData.Init()
StoryService.Init()
InventoryService.Init()
InteractionService.Init()
FlashlightService.Init()
CheckpointService.Init()
PuzzleService.Init()
StalkerService.Init()
EscapeService.Init()
GameService.Init()

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
