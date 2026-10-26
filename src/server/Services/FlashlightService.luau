--!strict
-- FlashlightService: the server owns the battery level and whether the light
-- is on. The light itself is a SpotLight on the character's head, so other
-- players see it too. (Each client additionally aims its own light along its
-- camera for a better feel; see client FlashlightController.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)
local StoryService = require(script.Parent.StoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local FlashlightService = {}

local function getLight(player: Player): SpotLight?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local attachment = head and head:FindFirstChild("FlashlightAttachment")
	local light = attachment and attachment:FindFirstChild("Flashlight")
	if light and light:IsA("SpotLight") then
		return light
	end
	return nil
end

local function createLight(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlashlightAttachment"
	attachment.Position = Vector3.new(0, 0, -0.9)
	attachment.Parent = head
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = Config.Flashlight.Range
	light.Brightness = Config.Flashlight.Brightness
	light.Angle = Config.Flashlight.Angle
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Shadows = true
	light.Enabled = false
	light.Parent = attachment
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
	local light = getLight(player)
	if light then
		light.Enabled = on
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
			createLight(character)
		end)
		if player.Character then
			createLight(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

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
