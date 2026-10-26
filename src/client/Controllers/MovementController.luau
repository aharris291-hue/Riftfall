--!strict
-- MovementController: sprint (hold Shift), crouch (press C), and stamina.
-- On touch screens, on-screen buttons are added for both.
--
-- Movement speed is applied on the client because Roblox characters are
-- physically simulated by their own player. The server listens for noise
-- (how fast you move) when deciding if the Hollow hears you.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local P = Config.Player

local MovementController = {}

local sprintHeld = false
local exhausted = false
local humanoid: Humanoid? = nil

local function setCrouch(on: boolean)
	if ClientState.Crouching == on then
		return
	end
	ClientState.Crouching = on
	Remotes.SetCrouch:FireServer(on)
	if humanoid then
		TweenService:Create(humanoid, TweenInfo.new(0.25), {
			CameraOffset = if on then Vector3.new(0, -1.6, 0) else Vector3.zero,
		}):Play()
	end
end

local function onSprint(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		sprintHeld = true
		setCrouch(false)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Sink
end

local function onCrouch(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		setCrouch(not ClientState.Crouching)
	end
	return Enum.ContextActionResult.Sink
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	ClientState.Stamina = P.MaxStamina
	ClientState.Crouching = false
	exhausted = false
	Remotes.SetCrouch:FireServer(false)
end

function MovementController.Init()
	ContextActionService:BindAction("RiftfallSprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("RiftfallSprint", "Sprint")
	ContextActionService:SetPosition("RiftfallSprint", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("RiftfallCrouch", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("RiftfallCrouch", "Crouch")
	ContextActionService:SetPosition("RiftfallCrouch", UDim2.new(1, -230, 1, -90))

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.Heartbeat:Connect(function(dt)
		local hum = humanoid
		if not hum or hum.Health <= 0 then
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		local sprinting = sprintHeld and moving and not exhausted and not ClientState.Crouching

		if sprinting then
			ClientState.Stamina = math.max(0, ClientState.Stamina - P.StaminaDrainPerSecond * dt)
			if ClientState.Stamina <= 0 then
				exhausted = true
			end
		else
			ClientState.Stamina = math.min(P.MaxStamina, ClientState.Stamina + P.StaminaRegenPerSecond * dt)
			if exhausted and ClientState.Stamina >= P.StaminaRecoverThreshold then
				exhausted = false
			end
		end

		if ClientState.Crouching then
			hum.WalkSpeed = P.CrouchSpeed
		elseif sprinting then
			hum.WalkSpeed = P.SprintSpeed
		else
			hum.WalkSpeed = P.WalkSpeed
		end
	end)
end

return MovementController
