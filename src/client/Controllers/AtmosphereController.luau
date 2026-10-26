--!strict
-- AtmosphereController: local-only mood effects. Rain around the camera,
-- lightning flashes, camera shake, and a "danger" value that rises as the
-- Rift Stalker gets close (the HUD turns it into a pulsing edge glow so the threat
-- is readable, not a cheap surprise).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local AtmosphereController = {}

local shakeUntil = 0
local shakeIntensity = 0
local rng = Random.new()

-- Plays a configured sound if an ID has been set (see Config.Sounds).
local function makeSound(id: string, looped: boolean, volume: number): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

-- Inside the temple and tunnel there is a roof, so no rain or lightning.
local function isIndoors(position: Vector3): boolean
	return position.Z > 298 and position.Z < 432 and position.Y < 24
end

local function createRain(): ParticleEmitter
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "RainEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 1, 90)
	emitterPart.Parent = workspace.CurrentCamera

	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Rate = 700
	rain.Lifetime = NumberRange.new(0.8, 1.1)
	rain.Speed = NumberRange.new(70, 85)
	rain.Size = NumberSequence.new(0.07)
	rain.Squash = NumberSequence.new(3) -- Stretch drops into streaks.
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Transparency = NumberSequence.new(0.55)
	rain.Color = ColorSequence.new(Color3.fromRGB(170, 190, 210))
	rain.LightInfluence = 0.6
	rain.Parent = emitterPart
	return rain
end

-- A jagged bolt in the sky, briefly visible during a flash.
local function drawBolt()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local point = camera.CFrame.Position + flat * 170 + side * rng:NextNumber(-90, 90) + Vector3.new(0, 150, 0)
	local folder = Instance.new("Folder")
	folder.Name = "LightningBolt"
	while point.Y > 30 do
		local nextPoint = point + Vector3.new(rng:NextNumber(-10, 10), -rng:NextNumber(14, 24), rng:NextNumber(-10, 10))
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(210, 220, 255)
		segment.Size = Vector3.new(0.9, 0.9, (nextPoint - point).Magnitude)
		segment.CFrame = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
		segment.Parent = folder
		point = nextPoint
	end
	folder.Parent = camera
	task.delay(0.22, function()
		folder:Destroy()
	end)
end

local function flashLightning()
	drawBolt()
	local original = Lighting.OutdoorAmbient
	local originalBrightness = Lighting.Brightness
	for _ = 1, rng:NextInteger(1, 2) do
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 190)
		Lighting.Brightness = 2.5
		task.wait(0.07)
		Lighting.OutdoorAmbient = original
		Lighting.Brightness = originalBrightness
		task.wait(0.1)
	end
end

function AtmosphereController.Init()
	local rain = createRain()
	local rainSound = makeSound(Config.Sounds.Rain, true, 0.4)
	if rainSound then
		rainSound:Play()
	end
	local heartbeat = makeSound(Config.Sounds.Heartbeat, true, 0)
	if heartbeat then
		heartbeat:Play()
	end
	local thunder = makeSound(Config.Sounds.Thunder, false, 0.6)
	local rumble = makeSound(Config.Sounds.Rumble, false, 0.7)

	Remotes.CameraShake.OnClientEvent:Connect(function(duration: number, intensity: number)
		if type(duration) ~= "number" or type(intensity) ~= "number" then
			return
		end
		shakeUntil = math.max(shakeUntil, os.clock() + duration)
		shakeIntensity = math.max(intensity, if os.clock() < shakeUntil then shakeIntensity else 0)
		if rumble and duration > 1 then
			rumble:Play()
		end
	end)

	-- Rain follows the camera.
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local emitterPart = rain.Parent
		if not camera or not emitterPart or not emitterPart:IsA("BasePart") then
			return
		end
		local pos = camera.CFrame.Position
		emitterPart.CFrame = CFrame.new(pos + Vector3.new(0, 35, 0))
		rain.Enabled = not isIndoors(pos)
		if rainSound then
			rainSound.Volume = if isIndoors(pos) then 0.1 else 0.4
		end
	end)

	-- Camera shake runs after the default camera has moved this frame.
	RunService:BindToRenderStep("RiftfallShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now >= shakeUntil then
			return
		end
		local camera = workspace.CurrentCamera
		local strength = shakeIntensity * math.clamp((shakeUntil - now) / 0.5, 0, 1)
		camera.CFrame *= CFrame.Angles(
			math.rad(rng:NextNumber(-1, 1) * strength),
			math.rad(rng:NextNumber(-1, 1) * strength),
			0
		)
	end)

	-- Danger meter: how close is the Rift Stalker?
	task.spawn(function()
		while true do
			task.wait(0.15)
			local stalker = workspace:FindFirstChild("RiftStalker")
			local character = player.Character
			local myRoot = character and character:FindFirstChild("HumanoidRootPart")
			local stalkerRoot = stalker and stalker:FindFirstChild("HumanoidRootPart")
			if myRoot and myRoot:IsA("BasePart") and stalkerRoot and stalkerRoot:IsA("BasePart") then
				local distance = (myRoot.Position - stalkerRoot.Position).Magnitude
				ClientState.Danger = math.clamp(1 - (distance - 8) / 32, 0, 1)
			else
				ClientState.Danger = 0
			end
			if heartbeat then
				heartbeat.Volume = ClientState.Danger * 0.8
			end
		end
	end)

	-- Lightning every so often while outdoors.
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(14, 30))
			local camera = workspace.CurrentCamera
			if camera and not isIndoors(camera.CFrame.Position) then
				flashLightning()
				if thunder then
					task.wait(rng:NextNumber(0.4, 1.5))
					thunder:Play()
				end
			end
		end
	end)
end

return AtmosphereController
