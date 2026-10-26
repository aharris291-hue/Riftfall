--!strict
-- FlashlightController: press F (or the on-screen button) to ask the server
-- to toggle your flashlight. The server decides whether it is on (battery).
--
-- What you see yourself is a local light and beam aimed exactly where your
-- camera looks, which makes the flashlight easy to point. The server's copy on
-- your head (which other players see) is hidden on your own screen so the
-- two don't double up.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashlightVisuals = require(ReplicatedStorage.Shared.FlashlightVisuals)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local FlashlightController = {}

local function onToggle(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		Remotes.ToggleFlashlight:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function createLocalTorch(): (BasePart, FlashlightVisuals.Rig)
	local torch = Instance.new("Part")
	torch.Name = "LocalFlashlight"
	torch.Size = Vector3.new(0.2, 0.2, 0.2)
	torch.Transparency = 1
	torch.Anchored = true
	torch.CanCollide = false
	torch.CanQuery = false
	torch.CanTouch = false
	torch.CastShadow = false
	torch.Parent = workspace.CurrentCamera
	return torch, FlashlightVisuals.Create(torch, 0.3)
end

-- Keeps the replicated head light switched off on this screen only.
local function hideOwnHeadLight(head: Instance)
	for _, name in { "Flashlight", "FlashlightBeam", "FlashlightGlow" } do
		local inst = head:FindFirstChild(name)
		if inst and (inst:IsA("Light") or inst:IsA("Beam")) and inst.Enabled then
			inst.Enabled = false
		end
	end
end

function FlashlightController.Init()
	ContextActionService:BindAction("RiftfallFlashlight", onToggle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("RiftfallFlashlight", "Light")
	ContextActionService:SetPosition("RiftfallFlashlight", UDim2.new(1, -110, 1, -210))

	local torch, rig = createLocalTorch()
	local wasOn = false

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = workspace.CurrentCamera
		if torch.Parent ~= camera and camera then
			torch.Parent = camera -- The camera can be replaced on respawn.
		end
		local on = player:GetAttribute("FlashlightOn") == true
			and head ~= nil
			and head:IsA("BasePart")
			and humanoid ~= nil
			and humanoid.Health > 0
		if on ~= wasOn then
			FlashlightVisuals.SetEnabled(rig, on)
			wasOn = on
		end
		if head and head:IsA("BasePart") then
			hideOwnHeadLight(head)
			if on and camera then
				local look = camera.CFrame.LookVector
				-- Held slightly in front of and below the eyes.
				local origin = head.Position + look * 0.8 - Vector3.new(0, 0.3, 0)
				torch.CFrame = CFrame.lookAt(origin, origin + look)
			end
		end
	end)
end

return FlashlightController
