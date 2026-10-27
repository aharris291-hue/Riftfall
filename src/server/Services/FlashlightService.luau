--!strict
-- FlashlightService: the server owns the battery level and whether the light
-- is on. The light and its visible beam sit on the character's head, so
-- other players see them too. Each client hides its own head light and shows
-- a local copy aimed along the camera instead (see FlashlightController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FlashlightVisuals = require(ReplicatedStorage.Shared.FlashlightVisuals)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local FlashlightService = {}

local rigs: { [Player]: FlashlightVisuals.Rig } = {}

local function createLight(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or character ~= player.Character then
		return
	end
	-- The head's Front face points where the character faces.
	rigs[player] = FlashlightVisuals.Create(head, 0.7)
end

function FlashlightService.SetOn(player: Player, on: boolean)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if on and data.Battery <= 0 then
		StoryService.Toast(player, "Battery is dead. Find or use a Battery.", "warning")
		on = false
	end
	player:SetAttribute("FlashlightOn", on)
	local rig = rigs[player]
	if rig and rig.Light.Parent then
		FlashlightVisuals.SetEnabled(rig, on)
	end
end

local function onToggle(player: Player)
	if not PlayerData.RateLimit(player, "Flashlight", 0.2) then
		return
	end
	FlashlightService.SetOn(player, not player:GetAttribute("FlashlightOn"))
end

function FlashlightService.Init()
	Remotes.ToggleFlashlight.OnServerEvent:Connect(onToggle)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			player:SetAttribute("FlashlightOn", false)
			createLight(player, character)
		end)
		if player.Character then
			task.spawn(createLight, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rigs[player] = nil
	end)

	-- Drain batteries of lights that are on.
	task.spawn(function()
		local STEP = 0.5
		while true do
			task.wait(STEP)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("FlashlightOn") then
					local data = PlayerData.Get(player)
					if data then
						data.Battery = math.max(0, data.Battery - Config.Flashlight.DrainPerSecond * STEP)
						player:SetAttribute("Battery", data.Battery)
						if data.Battery <= 0 then
							FlashlightService.SetOn(player, false)
						end
					end
				end
			end
		end
	end)
end

return FlashlightService
