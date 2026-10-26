--!strict
-- PuzzleService: the three stone dials in the temple.
--
-- Each dial cycles through four symbols. Setting them, left to right, to
-- EYE, MOON, SUN opens the sealed door. The clue is split between the mural
-- above the door (EYE ? SUN) and Rourke's journal in the camp.
--
-- The puzzle state lives on the server and is shared by all players. Once
-- solved it stays solved (dying cannot re-lock it), so it can never soft-lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)
local CheckpointService = require(script.Parent.CheckpointService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PuzzleService = {}

local SYMBOLS = {
	{ Name = "SUN", Color = Color3.fromRGB(255, 200, 80) },
	{ Name = "MOON", Color = Color3.fromRGB(170, 200, 255) },
	{ Name = "EYE", Color = Color3.fromRGB(255, 90, 90) },
	{ Name = "SPIRAL", Color = Color3.fromRGB(120, 230, 150) },
}
local SOLUTION = { 3, 2, 1 } -- EYE, MOON, SUN
local START_STATE = { 1, 4, 2 } -- SUN, SPIRAL, MOON (deliberately wrong)

local dialState: { number } = table.clone(START_STATE)
local solved = false
local lastTurn: { [number]: number } = {}

-- Called by Main when the puzzle is solved (starts the escape).
PuzzleService.OnSolved = nil :: (() -> ())?

local function refreshFaces()
	for _, face in CollectionService:GetTagged("PuzzleDialFace") do
		local index = face:GetAttribute("DialIndex")
		local label = face:FindFirstChild("SymbolLabel", true)
		if type(index) == "number" and label and label:IsA("TextLabel") then
			local symbol = SYMBOLS[dialState[index]]
			label.Text = symbol.Name
			label.TextColor3 = if solved then Color3.fromRGB(190, 110, 255) else symbol.Color
		end
	end
end

local function openGate()
	for _, gate in CollectionService:GetTagged("PuzzleGate") do
		if gate:IsA("BasePart") then
			local closed = gate:GetAttribute("ClosedPosition")
			if typeof(closed) == "Vector3" then
				local tween = TweenService:Create(
					gate,
					TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = closed - Vector3.new(0, 14.5, 0) }
				)
				tween:Play()
			end
		end
	end
end

local function isSolved(): boolean
	for i, value in SOLUTION do
		if dialState[i] ~= value then
			return false
		end
	end
	return true
end

local function solve()
	solved = true
	refreshFaces()
	for _, dial in CollectionService:GetTagged("PuzzleDial") do
		local prompt = dial:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
	openGate()
	Remotes.CameraShake:FireAllClients(2.5, 0.6)
	StoryService.SetPhase("Escape")
	StoryService.SetObjective("Escape")
	StoryService.PlayDialogue("Solved")

	-- Everyone gets a checkpoint right by the door, so dying during the
	-- escape never means redoing the ruins.
	local marker = Zones.FirstTagged("EscapeSpawn")
	local spawnPos = marker and marker:GetAttribute("SpawnPosition")
	if typeof(spawnPos) == "Vector3" then
		for _, player in Players:GetPlayers() do
			CheckpointService.Set(player, 3, spawnPos, "Temple Door")
		end
	end
	if PuzzleService.OnSolved then
		PuzzleService.OnSolved()
	end
end

local function bindDial(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local dial = inst
	local prompt = dial:FindFirstChildOfClass("ProximityPrompt")
	local index = dial:GetAttribute("DialIndex")
	if not prompt or type(index) ~= "number" then
		return
	end
	prompt.Enabled = not solved
	prompt.Triggered:Connect(function(player)
		if solved then
			return
		end
		local _, _, root = PlayerData.GetAliveCharacter(player)
		if not root or (root.Position - dial.Position).Magnitude > 14 then
			return
		end
		-- Small per-dial debounce so simultaneous presses do not double-turn.
		local now = os.clock()
		if lastTurn[index] and now - lastTurn[index] < 0.3 then
			return
		end
		lastTurn[index] = now
		dialState[index] = dialState[index] % #SYMBOLS + 1
		refreshFaces()
		if isSolved() then
			solve()
		end
	end)
	refreshFaces()
end

function PuzzleService.IsSolved(): boolean
	return solved
end

function PuzzleService.Reset()
	dialState = table.clone(START_STATE)
	solved = false
	table.clear(lastTurn)
	for _, dial in CollectionService:GetTagged("PuzzleDial") do
		local prompt = dial:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
	refreshFaces()
end

function PuzzleService.Init()
	Zones.BindTag("PuzzleDial", bindDial)
	Zones.BindTag("PuzzleDialFace", function()
		refreshFaces()
	end)
end

return PuzzleService
