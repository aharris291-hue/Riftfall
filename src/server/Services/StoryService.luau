--!strict
-- StoryService: objectives, radio dialogue, on-screen messages, and the
-- one-time story trigger zones placed around the map.
--
-- The current objective is stored as an attribute on ReplicatedStorage, so
-- players who join late automatically see the right objective.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Story = require(ReplicatedStorage.Shared.Story)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local StoryService = {}

-- Objectives only ever move forward, in this order.
local OBJECTIVE_ORDER = { "Start", "Camp", "Ruins", "Puzzle", "Escape", "Bridge", "Done" }

local currentObjectiveIndex = 0
local firedTriggers: { [string]: boolean } = {}

-- Phase gates: some triggers only make sense during a particular phase.
local triggerRequiresPhase: { [string]: string } = {
	Bridge = "Escape",
}

function StoryService.GetPhase(): string
	return ReplicatedStorage:GetAttribute("Phase") or "Explore"
end

function StoryService.SetPhase(phase: string)
	ReplicatedStorage:SetAttribute("Phase", phase)
end

function StoryService.SetObjective(key: string)
	local index = table.find(OBJECTIVE_ORDER, key)
	if not index or index <= currentObjectiveIndex then
		return
	end
	currentObjectiveIndex = index
	ReplicatedStorage:SetAttribute("Objective", (Story.Objectives :: any)[key])
	Remotes.Toast:FireAllClients("New objective", "objective")
end

-- Sends a dialogue sequence to one player, or to everyone if player is nil.
function StoryService.PlayDialogue(key: string, player: Player?)
	local lines = (Story.Dialogue :: any)[key]
	if not lines then
		warn("[StoryService] Unknown dialogue key:", key)
		return
	end
	if player then
		Remotes.Dialogue:FireClient(player, lines)
	else
		Remotes.Dialogue:FireAllClients(lines)
	end
end

function StoryService.Toast(player: Player, text: string, kind: string?)
	Remotes.Toast:FireClient(player, text, kind or "info")
end

local function onTrigger(triggerId: string)
	if triggerId == "ClawMarks" then
		StoryService.PlayDialogue("ClawMarks")
	elseif triggerId == "Camp" then
		StoryService.SetObjective("Camp")
		StoryService.PlayDialogue("Camp")
	elseif triggerId == "Ruins" then
		StoryService.SetObjective("Ruins")
		StoryService.PlayDialogue("Ruins")
	elseif triggerId == "Temple" then
		StoryService.SetObjective("Puzzle")
		StoryService.PlayDialogue("Temple")
	elseif triggerId == "Bridge" then
		StoryService.SetObjective("Bridge")
		StoryService.PlayDialogue("Bridge")
	end
end

-- Resets story progress for a fresh run (Play Again).
function StoryService.Reset()
	currentObjectiveIndex = 0
	table.clear(firedTriggers)
	StoryService.SetPhase("Explore")
	StoryService.SetObjective("Start")
end

function StoryService.Init()
	StoryService.Reset()

	-- Each new player hears the intro on their first spawn.
	local function onPlayerAdded(player: Player)
		local function playIntro()
			task.wait(2)
			if player.Parent then
				StoryService.PlayDialogue("Intro", player)
			end
		end
		if player.Character then
			task.spawn(playIntro)
		else
			player.CharacterAdded:Once(playIntro)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Poll story trigger zones a few times per second (cheap with few zones).
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, zone in CollectionService:GetTagged("StoryTrigger") do
				if not zone:IsA("BasePart") then
					continue
				end
				local id = zone:GetAttribute("TriggerId")
				if type(id) ~= "string" or firedTriggers[id] then
					continue
				end
				local phase = triggerRequiresPhase[id]
				if phase and StoryService.GetPhase() ~= phase then
					continue
				end
				for _, player in Players:GetPlayers() do
					local _, _, root = PlayerData.GetAliveCharacter(player)
					if root and Zones.Contains(zone, root.Position) then
						firedTriggers[id] = true
						onTrigger(id)
						break
					end
				end
			end
		end
	end)
end

return StoryService
