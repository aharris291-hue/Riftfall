--!strict
-- Chapter2Service: the gameplay of Chapter 2, the Blackstone Research
-- Facility (built by Chapter2Builder).
--
--   1. Entering: after finishing Chapter 1, "Continue to Chapter 2" on the
--      results screen brings the player to the facility airlock.
--   2. Power puzzle: find two fuses, put them in the generator panel, set
--      breakers A/B/C to the pattern on the engineering whiteboard (ON, OFF,
--      ON) and pull the master lever. Wrong settings make a loud bang the
--      creature can hear; nothing is ever lost, so it cannot soft-lock.
--   3. Power on: lights come on, the security door opens... and so does the
--      containment cell. The Rift Stalker breaks out of Lab 2.
--   4. Escape: hold the elevator call button (it takes a few seconds) and
--      step inside to finish the chapter.
--
-- Puzzle state is shared by everyone in the server and lives here, on the
-- server. Clients can only press prompts; every press is validated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Story = require(ReplicatedStorage.Shared.Story)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)
local InventoryService = require(script.Parent.InventoryService)
local CheckpointService = require(script.Parent.CheckpointService)
local StalkerService = require(script.Parent.StalkerService)
local Chapter2Builder = require(script.Parent.Chapter2Builder)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Chapter2Service = {}

-- Set by Main: called with (player, seconds) when a player finishes Chapter 2.
Chapter2Service.OnFinished = nil :: ((Player, number) -> ())?

local SOLUTION = { true, false, true } -- Breakers A, B, C.
local PROMPT_RANGE = 12
local ELEVATOR_STAY_OPEN = 25

local fusesIn = { false, false }
local breakers = { false, false, false }
local powered = false
local elevatorOpen = false
local started = false -- Has anyone entered Chapter 2 this run?
local chapterStart: { [Player]: number } = {}
local finished: { [Player]: boolean } = {}

local function closeEnough(player: Player, part: BasePart): boolean
	local _, _, root = PlayerData.GetAliveCharacter(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= PROMPT_RANGE
end

local function refreshPanel()
	for _, socket in CollectionService:GetTagged("FuseSocket") do
		local index = socket:GetAttribute("SocketIndex")
		if socket:IsA("BasePart") and type(index) == "number" then
			socket.Color = if fusesIn[index] then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(25, 25, 25)
			socket.Material = if fusesIn[index] then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local prompt = socket:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = not fusesIn[index]
			end
		end
	end
	for _, breaker in CollectionService:GetTagged("Breaker") do
		local index = breaker:GetAttribute("BreakerIndex")
		if breaker:IsA("BasePart") and type(index) == "number" then
			local on = breakers[index]
			breaker.Color = if on then Color3.fromRGB(60, 170, 70) else Color3.fromRGB(150, 40, 40)
			local gui = breaker:FindFirstChildOfClass("SurfaceGui")
			local label = gui and gui:FindFirstChild("State")
			if label and label:IsA("TextLabel") then
				label.Text = string.char(64 + index) .. "\n" .. (if on then "ON" else "OFF")
			end
			local prompt = breaker:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = not powered
				prompt.ActionText = if on then "Switch off" else "Switch on"
			end
		end
	end
	for _, lever in CollectionService:GetTagged("MasterLever") do
		local prompt = lever:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not powered
		end
	end
end

local function setPowerVisuals(on: boolean)
	for _, panel in CollectionService:GetTagged("FacilityLight") do
		local light = panel:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = on
		end
		if panel:IsA("BasePart") then
			panel.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			panel.Color = if on then Color3.fromRGB(220, 235, 255) else Color3.fromRGB(60, 64, 70)
		end
	end
	for _, lamp in CollectionService:GetTagged("PowerLamp") do
		if lamp:IsA("BasePart") then
			lamp.Color = if on then Color3.fromRGB(80, 255, 140) else Color3.fromRGB(255, 40, 30)
		end
	end
	for _, call in CollectionService:GetTagged("ElevatorCall") do
		if call:IsA("BasePart") then
			call.Color = if on then Color3.fromRGB(80, 255, 140) else Color3.fromRGB(255, 40, 30)
		end
	end
end

-- Slides a door by its OpenOffset attribute (or back when closing).
local function moveDoor(door: Instance, open: boolean)
	if not door:IsA("BasePart") then
		return
	end
	local offset = door:GetAttribute("OpenOffset")
	if typeof(offset) ~= "Vector3" then
		return
	end
	local closed = door:GetAttribute("ClosedPosition")
	if typeof(closed) ~= "Vector3" then
		closed = door.Position
		door:SetAttribute("ClosedPosition", closed)
	end
	local goal = if open then (closed :: Vector3) + offset else closed :: Vector3
	TweenService:Create(door, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Position = goal }):Play()
	door.CanCollide = not open
end

-- The creature breaks out of Lab 2 when the power returns.
local function breakout()
	local marker = Zones.FirstTagged("C2StalkerSpawn")
	local at = if marker then marker.Position else Vector3.new(-24, 4, 1516)
	StalkerService.Despawn()
	StalkerService.SpawnPatrol("Chapter2", at)
	-- It heard the generator: it heads toward the corridor first.
	StalkerService.ReportNoise(Vector3.new(0, 3, 1470), 200, 8)
	Remotes.CameraShake:FireAllClients(1.2, 1.5)
	StoryService.PlayDialogue("C2Breakout")
end

local function restorePower()
	powered = true
	refreshPanel()
	setPowerVisuals(true)
	for _, door in CollectionService:GetTagged("PoweredDoor") do
		moveDoor(door, true)
	end
	StoryService.SetObjective("C2Escape")
	StoryService.PlayDialogue("C2Power")
	task.delay(6, breakout)
end

local function onSocket(socket: BasePart, player: Player)
	local index = socket:GetAttribute("SocketIndex")
	if type(index) ~= "number" or fusesIn[index] or not closeEnough(player, socket) then
		return
	end
	if InventoryService.Count(player, "Fuse") < 1 then
		StoryService.Toast(player, "You need a fuse", "warning")
		return
	end
	if InventoryService.Remove(player, "Fuse", 1) then
		fusesIn[index] = true
		StoryService.Toast(player, "Fuse inserted", "good")
		refreshPanel()
	end
end

local function onBreaker(breaker: BasePart, player: Player)
	local index = breaker:GetAttribute("BreakerIndex")
	if powered or type(index) ~= "number" or not closeEnough(player, breaker) then
		return
	end
	if not PlayerData.RateLimit(player, "Breaker", 0.25) then
		return
	end
	breakers[index] = not breakers[index]
	refreshPanel()
end

local function onLever(lever: BasePart, player: Player)
	if powered or not closeEnough(player, lever) or not PlayerData.RateLimit(player, "Lever", 2) then
		return
	end
	if not (fusesIn[1] and fusesIn[2]) then
		StoryService.Toast(player, "The panel needs two fuses", "warning")
		return
	end
	for i, want in SOLUTION do
		if breakers[i] ~= want then
			-- A loud failure: fair feedback, plus a noise the creature hears
			-- (if it is already loose) so mistakes have weight.
			Remotes.CameraShake:FireAllClients(0.5, 0.6)
			StalkerService.ReportNoise(lever.Position, 90, 6)
			StoryService.PlayDialogue("C2WrongBreakers", player)
			return
		end
	end
	restorePower()
end

local function onElevatorCall(call: BasePart, player: Player)
	if not closeEnough(player, call) then
		return
	end
	if not powered then
		StoryService.PlayDialogue("C2ElevatorNoPower", player)
		return
	end
	if elevatorOpen then
		return
	end
	elevatorOpen = true
	for _, door in CollectionService:GetTagged("ElevatorDoor") do
		moveDoor(door, true)
	end
	-- Close again later so the elevator is a safe spot only briefly.
	task.delay(ELEVATOR_STAY_OPEN, function()
		elevatorOpen = false
		for _, door in CollectionService:GetTagged("ElevatorDoor") do
			moveDoor(door, false)
		end
	end)
end

local function onLockedPanel(player: Player)
	if not powered then
		StoryService.PlayDialogue("C2DoorLocked", player)
		StoryService.SetObjective("C2Power")
	end
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
	StoryService.SetObjective("C2Done")
	StoryService.PlayDialogue("C2Done", player)
	if Chapter2Service.OnFinished then
		Chapter2Service.OnFinished(player, seconds)
	end
	local notesRead, notesTotal = 0, 0
	for id in Story.Notes do
		if string.sub(id, 1, 2) == "C2" then
			notesTotal += 1
			if data and data.NotesRead[id] then
				notesRead += 1
			end
		end
	end
	Remotes.RunComplete:FireClient(player, {
		Chapter = 2,
		Time = seconds,
		Deaths = if data then data.Deaths else 0,
		NotesRead = notesRead,
		NotesTotal = notesTotal,
	})
	-- Once everyone in Chapter 2 is out, the creature goes quiet.
	for other in chapterStart do
		if not finished[other] then
			return
		end
	end
	StalkerService.Despawn()
end

-- Brings a player who finished Chapter 1 into the facility.
function Chapter2Service.Enter(player: Player)
	local data = PlayerData.Get(player)
	local _, _, root = PlayerData.GetAliveCharacter(player)
	if not data or not root or chapterStart[player] then
		return
	end
	data.Finished = false
	data.Deaths = 0
	chapterStart[player] = os.clock()
	finished[player] = nil
	CheckpointService.Set(player, 10, Chapter2Builder.StartPosition, nil)
	;(player.Character :: Model):PivotTo(CFrame.new(Chapter2Builder.StartPosition) * CFrame.Angles(0, math.pi, 0))
	if not started then
		started = true
		-- The Chapter 1 creature stays behind in the jungle.
		StalkerService.Despawn()
	end
	StoryService.SetPhase("Facility")
	StoryService.SetObjective("C2Start")
	StoryService.PlayDialogue("C2Intro", player)
end

function Chapter2Service.HasFinished(player: Player): boolean
	return finished[player] == true
end

function Chapter2Service.IsIn(player: Player): boolean
	return chapterStart[player] ~= nil and not finished[player]
end

-- Resets the puzzle and doors (Play Again rebuilds the whole level).
function Chapter2Service.Reset()
	fusesIn = { false, false }
	breakers = { false, false, false }
	powered = false
	elevatorOpen = false
	started = false
	table.clear(chapterStart)
	table.clear(finished)
	setPowerVisuals(false)
	refreshPanel()
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
		refreshPanel()
	end)
end

function Chapter2Service.Init()
	bindPrompt("FuseSocket", onSocket)
	bindPrompt("Breaker", onBreaker)
	bindPrompt("MasterLever", onLever)
	bindPrompt("ElevatorCall", onElevatorCall)
	bindPrompt("LockedDoorPanel", function(_, player)
		onLockedPanel(player)
	end)

	StoryService.OnTrigger("C2Lobby", function()
		StoryService.PlayDialogue("C2Lobby")
	end)
	StoryService.OnTrigger("C2Tunnel", function()
		StoryService.PlayDialogue("C2Tunnel")
	end)
	StoryService.OnTrigger("C2Generator", function()
		StoryService.SetObjective("C2Fuses")
		StoryService.PlayDialogue("C2Generator")
	end)
	StoryService.OnTrigger("C2Corridor", function()
		if powered then
			StoryService.PlayDialogue("C2Corridor")
		end
	end)

	Remotes.ContinueChapter.OnServerEvent:Connect(function(player, nextChapter)
		if (nextChapter ~= nil and nextChapter ~= 2) or not PlayerData.RateLimit(player, "Continue", 2) then
			return
		end
		local data = PlayerData.Get(player)
		-- Only players who really finished Chapter 1 may continue.
		if data and data.Finished and not chapterStart[player] then
			Chapter2Service.Enter(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		chapterStart[player] = nil
		finished[player] = nil
	end)

	-- Reaching the inside of the open elevator finishes the chapter.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if not elevatorOpen then
				continue
			end
			local zone = Zones.FirstTagged("C2EndZone")
			if not zone then
				continue
			end
			for player in chapterStart do
				local _, _, root = PlayerData.GetAliveCharacter(player)
				if root and not finished[player] and Zones.Contains(zone, root.Position) then
					finish(player)
				end
			end
		end
	end)
end

return Chapter2Service
