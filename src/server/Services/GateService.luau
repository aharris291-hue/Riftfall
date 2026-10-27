--!strict
-- GateService: the chained gate into the ruins, Chapter 1's locked route.
--
-- The ruins are walled off; the only way in is a gate that Kade chained
-- shut. Talking to Kade at the camp gives you his bolt cutters (and a
-- flare). Holding E on the chain with the cutters opens the gate for
-- everyone. Bolt cutters are a key item, so they can't be dropped, and Kade
-- hands a pair to anyone who still needs one: the route can never be
-- soft-locked. Rebuilding the level (Play Again) brings back a closed gate.

local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local StoryService = require(script.Parent.StoryService)

local MAX_INTERACT_DISTANCE = 14
local SWING_TIME = 1.2

local GateService = {}

local function currentGate(): Instance?
	local chain = Zones.FirstTagged("ChainedGate")
	return chain and chain.Parent
end

function GateService.IsOpen(): boolean
	local gate = currentGate()
	return gate == nil or gate:GetAttribute("Open") == true
end

-- Swings both doors inward around their hinges (each door Model's pivot).
local function swingOpen(gate: Instance)
	local doors = {}
	for _, child in gate:GetChildren() do
		if child:IsA("Model") and type(child:GetAttribute("SwingAngle")) == "number" then
			table.insert(doors, { Model = child, Hinge = child:GetPivot(), Angle = child:GetAttribute("SwingAngle") })
		end
	end
	local steps = 24
	for i = 1, steps do
		local t = i / steps
		local eased = 1 - (1 - t) ^ 3
		for _, door in doors do
			door.Model:PivotTo(door.Hinge * CFrame.Angles(0, math.rad(door.Angle * eased), 0))
		end
		task.wait(SWING_TIME / steps)
	end
end

local function openGate(chain: BasePart, player: Player)
	local gate = chain.Parent
	if not gate or gate:GetAttribute("Open") then
		return
	end
	gate:SetAttribute("Open", true)
	for _, part in gate:GetDescendants() do
		if part:GetAttribute("ChainPiece") then
			part:Destroy()
		end
	end
	chain:Destroy()
	StoryService.Toast(player, "Chain cut", "good")
	StoryService.PlayDialogue("GateOpen")
	task.spawn(swingOpen, gate)
end

local function bindChain(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local chain = inst
	local prompt = chain:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local _, _, root = PlayerData.GetAliveCharacter(player)
		if not root or (root.Position - chain.Position).Magnitude > MAX_INTERACT_DISTANCE then
			return
		end
		if GateService.IsOpen() then
			return
		end
		if InventoryService.Remove(player, "BoltCutters", 1) then
			openGate(chain, player)
		else
			StoryService.Toast(player, "Chained shut. Kade might have something to cut it.", "warning")
		end
	end)
end

-- Kade gives his bolt cutters (and a flare) to anyone who still needs them.
function GateService.OnTalk(player: Player, characterId: string, phase: string)
	if characterId ~= "Kade" or phase ~= "Explore" or GateService.IsOpen() then
		return
	end
	if InventoryService.Count(player, "BoltCutters") > 0 then
		return
	end
	if not InventoryService.Add(player, "BoltCutters", 1) then
		StoryService.Toast(player, "Your pack is full. Use or drop something, then talk to Kade again.", "warning")
		return
	end
	StoryService.PlayDialogue("KadeCutters", player)
	StoryService.Toast(player, "Received Bolt Cutters", "good")
	if InventoryService.Add(player, "Flare", 1) then
		StoryService.Toast(player, "Received a Flare", "good")
	end
	StoryService.SetObjective("Gate")
end

function GateService.Init()
	Zones.BindTag("ChainedGate", bindChain)
	-- Reaching the gate while it is still locked tells you what to do.
	StoryService.OnTrigger("Gate", function()
		if not GateService.IsOpen() then
			StoryService.SetObjective("Gate")
			StoryService.PlayDialogue("Gate")
		end
	end)
end

return GateService
