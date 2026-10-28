--!strict
-- Chapter3Service: the gameplay of Chapter 3, the Sunken Temple (built by
-- Chapter3Builder).
--
--   1. Entering: "Continue to Chapter 3" on the Chapter 2 results.
--   2. Hidden chamber: push the cracked wall in the flooded gallery. The
--      tablet inside gives the plate order: EYE, SERPENT, MOON, SUN.
--   3. Symbol chamber: the creature patrols here. Each plate clicks loudly
--      when stepped on (the creature hears it). A wrong plate resets the
--      sequence and fires darts from the walls after a clear warning click,
--      so a careful player can step off in time.
--   4. Sanctum: touch the Rift Heart. The temple starts to flood: climb the
--      vines to the ledge before the water rises over your head.
--   5. The exit tunnel at the top ends the chapter.
--
-- All puzzle state lives on the server; clients only press prompts and walk.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Story = require(ReplicatedStorage.Shared.Story)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)
local CheckpointService = require(script.Parent.CheckpointService)
local StalkerService = require(script.Parent.StalkerService)
local Chapter3Builder = require(script.Parent.Chapter3Builder)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Chapter3Service = {}

-- Set by Main: says whether a player has finished Chapter 2.
Chapter3Service.FinishedPrevious = nil :: ((Player) -> boolean)?
-- Set by Main: called with (player, seconds) when a player finishes Chapter 3.
Chapter3Service.OnFinished = nil :: ((Player, number) -> ())?

local ORDER = { "EYE", "SERPENT", "MOON", "SUN" }
local PROMPT_RANGE = 12
local DART_WARNING = 0.9 -- Seconds between the warning click and the darts.
local DART_DAMAGE = 20
local FLOOD_TIME = 40 -- Seconds for the water to rise from the floor to the ledge.
local FLOOD_TOP = 13.5
local DROWN_DAMAGE = 12 -- Per second while the head is under water.

local progress = 0 -- How many plates in a row are correct.
local platesDown: { [number]: boolean } = {}
local gateOpen = false
local wallOpen = false
local flooding = false
local floodStart = 0
local creatureLoose = false
local chapterStart: { [Player]: number } = {}
local finished: { [Player]: boolean } = {}

local function closeEnough(player: Player, part: BasePart): boolean
	local _, _, root = PlayerData.GetAliveCharacter(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= PROMPT_RANGE
end

local function slide(part: Instance, open: boolean, seconds: number)
	if not part:IsA("BasePart") then
		return
	end
	local offset = part:GetAttribute("OpenOffset")
	if typeof(offset) ~= "Vector3" then
		return
	end
	local closed = part:GetAttribute("ClosedPosition")
	if typeof(closed) ~= "Vector3" then
		closed = part.Position
		part:SetAttribute("ClosedPosition", closed)
	end
	local goal = if open then (closed :: Vector3) + offset else closed :: Vector3
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Position = goal }):Play()
	part.CanCollide = not open
end

local function plateByIndex(index: number): BasePart?
	for _, plate in CollectionService:GetTagged("PressurePlate") do
		if plate:GetAttribute("PlateIndex") == index and plate:IsA("BasePart") then
			return plate
		end
	end
	return nil
end

local function setPlateLit(index: number, lit: boolean)
	local plate = plateByIndex(index)
	if plate then
		plate.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
		plate.Color = if lit then Color3.fromRGB(230, 190, 90) else Color3.fromRGB(130, 124, 104)
	end
end

local function resetPlates()
	progress = 0
	for i = 1, #ORDER do
		setPlateLit(i, false)
	end
end

-- Wrong plate: a warning click, then darts sweep the chamber floor.
local function fireDarts()
	for _, hole in CollectionService:GetTagged("DartHole") do
		if hole:IsA("BasePart") then
			hole.Color = Color3.fromRGB(255, 80, 40)
		end
	end
	Remotes.CameraShake:FireAllClients(0.3, 0.3)
	task.wait(DART_WARNING)
	for _, player in Players:GetPlayers() do
		local _, humanoid, root = PlayerData.GetAliveCharacter(player)
		if humanoid and root then
			for _, zone in CollectionService:GetTagged("PlateZone") do
				if zone:IsA("BasePart") and Zones.Contains(zone, root.Position) then
					humanoid:TakeDamage(DART_DAMAGE)
					StoryService.Toast(player, "Darts! Step off the plates when you hear the click.", "warning")
					break
				end
			end
		end
	end
	for _, hole in CollectionService:GetTagged("DartHole") do
		if hole:IsA("BasePart") then
			hole.Color = Color3.fromRGB(40, 20, 20)
		end
	end
end

local function openGate()
	gateOpen = true
	for _, gate in CollectionService:GetTagged("SanctumGate") do
		slide(gate, true, 2.5)
	end
	Remotes.CameraShake:FireAllClients(1.5, 0.8)
	StoryService.SetObjective("C3Heart")
	StoryService.PlayDialogue("C3GateOpen")
end

local function onPlateStepped(index: number)
	if gateOpen then
		return
	end
	local plate = plateByIndex(index)
	if not plate then
		return
	end
	-- Stone grinding on stone: the creature hears it.
	StalkerService.ReportNoise(plate.Position, 45, 4)
	local symbol = plate:GetAttribute("Symbol")
	if symbol == ORDER[progress + 1] then
		progress += 1
		setPlateLit(index, true)
		if progress == #ORDER then
			openGate()
		end
	else
		-- Stepping back onto a plate that is already lit is harmless.
		local position = table.find(ORDER, symbol)
		if position == nil or position > progress then
			resetPlates()
			task.spawn(fireDarts)
		end
	end
end

local function releaseCreature()
	if creatureLoose then
		return
	end
	creatureLoose = true
	local marker = Zones.FirstTagged("C3StalkerSpawn")
	StalkerService.Despawn()
	StalkerService.SpawnPatrol("Chapter3", if marker then marker.Position else Vector3.new(18, 4, 1796))
	-- A few seconds to see it and get to cover before it can notice you.
	for player in chapterStart do
		StalkerService.GiveGrace(player, 6)
	end
	StoryService.PlayDialogue("C3Creature")
end

local function startFlood()
	if flooding then
		return
	end
	flooding = true
	floodStart = os.clock()
	StoryService.SetObjective("C3Escape")
	StoryService.PlayDialogue("C3Flood")
	Remotes.CameraShake:FireAllClients(2, 1.2)
	for _, water in CollectionService:GetTagged("RisingWater") do
		if water:IsA("BasePart") then
			TweenService
				:Create(water, TweenInfo.new(FLOOD_TIME, Enum.EasingStyle.Linear), {
					Position = Vector3.new(water.Position.X, FLOOD_TOP, water.Position.Z),
				})
				:Play()
		end
	end
	-- The creature is swept away by the water rushing in.
	StalkerService.Despawn()
end

-- If someone drowns, the water drains so the escape can be tried again.
local function resetFlood()
	flooding = false
	for _, water in CollectionService:GetTagged("RisingWater") do
		if water:IsA("BasePart") then
			TweenService:Create(water, TweenInfo.new(3), {
				Position = Vector3.new(water.Position.X, -1, water.Position.Z),
			}):Play()
		end
	end
end

local function onHeart(heart: BasePart, player: Player)
	if flooding or not gateOpen or not closeEnough(player, heart) then
		return
	end
	StoryService.PlayDialogue("C3Heart", player)
	startFlood()
end

local function onCrackedWall(wall: BasePart, player: Player)
	if wallOpen or not closeEnough(player, wall) then
		return
	end
	wallOpen = true
	slide(wall, true, 1.5)
	StoryService.PlayDialogue("C3Hidden", player)
end

local function finish(player: Player)
	if finished[player] then
		return
	end
	finished[player] = true
	local data = PlayerData.Get(player)
	if data then
		data.Finished = true
	end
	local seconds = os.clock() - (chapterStart[player] or os.clock())
	StoryService.SetObjective("C3Done")
	StoryService.PlayDialogue("C3Done", player)
	if Chapter3Service.OnFinished then
		Chapter3Service.OnFinished(player, seconds)
	end
	local notesRead, notesTotal = 0, 0
	for id in Story.Notes do
		if string.sub(id, 1, 2) == "C3" then
			notesTotal += 1
			if data and data.NotesRead[id] then
				notesRead += 1
			end
		end
	end
	Remotes.RunComplete:FireClient(player, {
		Chapter = 3,
		Time = seconds,
		Deaths = if data then data.Deaths else 0,
		NotesRead = notesRead,
		NotesTotal = notesTotal,
	})
end

-- Brings a player who finished Chapter 2 into the Sunken Temple.
function Chapter3Service.Enter(player: Player)
	local data = PlayerData.Get(player)
	local _, _, root = PlayerData.GetAliveCharacter(player)
	if not data or not root or chapterStart[player] then
		return
	end
	data.Finished = false
	data.Deaths = 0
	chapterStart[player] = os.clock()
	finished[player] = nil
	CheckpointService.Set(player, 20, Chapter3Builder.StartPosition, nil)
	;(player.Character :: Model):PivotTo(CFrame.new(Chapter3Builder.StartPosition) * CFrame.Angles(0, math.pi, 0))
	StalkerService.Despawn()
	StoryService.SetPhase("Temple3")
	StoryService.SetObjective("C3Start")
	StoryService.PlayDialogue("C3Intro", player)
end

function Chapter3Service.Reset()
	resetPlates()
	table.clear(platesDown)
	gateOpen = false
	wallOpen = false
	flooding = false
	creatureLoose = false
	table.clear(chapterStart)
	table.clear(finished)
end

local function bindPrompt(tag: string, handler: (BasePart, Player) -> ())
	Zones.BindTag(tag, function(inst: Instance)
		if not inst:IsA("BasePart") then
			return
		end
		local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				handler(inst, player)
			end)
		end
	end)
end

function Chapter3Service.Init()
	bindPrompt("CrackedWall", onCrackedWall)
	bindPrompt("RiftHeart", onHeart)

	StoryService.OnTrigger("C3Entrance", function()
		StoryService.PlayDialogue("C3Entrance")
	end)
	StoryService.OnTrigger("C3Gallery", function()
		StoryService.PlayDialogue("C3Gallery")
	end)
	StoryService.OnTrigger("C3Symbols", function()
		StoryService.SetObjective("C3Plates")
		releaseCreature()
	end)
	StoryService.OnTrigger("C3Sanctum", function()
		StoryService.PlayDialogue("C3Sanctum")
	end)

	Remotes.ContinueChapter.OnServerEvent:Connect(function(player, nextChapter)
		if nextChapter ~= 3 or not PlayerData.RateLimit(player, "Continue3", 2) then
			return
		end
		local done = Chapter3Service.FinishedPrevious
		if done and done(player) and not chapterStart[player] then
			Chapter3Service.Enter(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		chapterStart[player] = nil
		finished[player] = nil
	end)

	CheckpointService.OnPlayerDied(function(player)
		if chapterStart[player] and flooding then
			task.delay(2, resetFlood)
		end
	end)

	-- Plates, drowning and the end zone, checked a few times a second.
	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(0.2)
			local now = os.clock()
			local dt = now - lastTick
			lastTick = now

			-- Pressure plates: a plate goes "down" when someone stands on it.
			for _, zone in CollectionService:GetTagged("PlateZone") do
				local index = zone:GetAttribute("PlateIndex")
				if not zone:IsA("BasePart") or type(index) ~= "number" then
					continue
				end
				local occupied = false
				for player in chapterStart do
					local _, _, root = PlayerData.GetAliveCharacter(player)
					if root and Zones.Contains(zone, root.Position) then
						occupied = true
						break
					end
				end
				if occupied and not platesDown[index] then
					platesDown[index] = true
					task.spawn(onPlateStepped, index)
				elseif not occupied then
					platesDown[index] = nil
				end
			end

			-- Rising water: anyone whose head is under it starts to drown.
			if flooding then
				local level = -1 + (FLOOD_TOP + 1) * math.clamp((now - floodStart) / FLOOD_TIME, 0, 1)
				for player in chapterStart do
					local character, humanoid, root = PlayerData.GetAliveCharacter(player)
					local head = character and character:FindFirstChild("Head")
					if
						humanoid
						and root
						and head
						and head:IsA("BasePart")
						and root.Position.Z > 1800
						and root.Position.Z < 1840
						and head.Position.Y < level
					then
						humanoid:TakeDamage(DROWN_DAMAGE * dt)
					end
				end
			end

			-- End of the chapter.
			local endZone = Zones.FirstTagged("C3EndZone")
			if endZone then
				for player in chapterStart do
					local _, _, root = PlayerData.GetAliveCharacter(player)
					if root and not finished[player] and Zones.Contains(endZone, root.Position) then
						finish(player)
					end
				end
			end
		end
	end)
end

function Chapter3Service.IsIn(player: Player): boolean
	return chapterStart[player] ~= nil and not finished[player]
end

return Chapter3Service
