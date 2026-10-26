--!strict
-- FlashlightController: press F (or the on-screen button) to ask the server
-- to toggle your flashlight. Locally, the light is aimed where your camera
-- looks, which feels much better than it pointing wherever your head faces.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local FlashlightController = {}

local function onToggle(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		Remotes.ToggleFlashlight:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

function FlashlightController.Init()
	ContextActionService:BindAction("RiftfallFlashlight", onToggle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("RiftfallFlashlight", "Light")
	ContextActionService:SetPosition("RiftfallFlashlight", UDim2.new(1, -110, 1, -210))

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local attachment = head and head:FindFirstChild("FlashlightAttachment")
		local camera = workspace.CurrentCamera
		if attachment and attachment:IsA("Attachment") and camera then
			local origin = attachment.WorldPosition
			attachment.WorldCFrame = CFrame.lookAt(origin, origin + camera.CFrame.LookVector)
		end
	end)
end

return FlashlightController
