--!strict
-- DistractionService: thrown flares. Using a Flare from the inventory tosses
-- it in front of the player; it lands, burns bright red, and makes a noise
-- the Rift Stalker can hear from far away (Config.Flare), so the creature
-- goes to investigate the flare instead of the player.
--
-- The server decides where the flare lands (from the character's facing),
-- so a modified client cannot throw one across the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local StalkerService = require(script.Parent.StalkerService)

local F = Config.Flare
local FLARE_COLOR = Color3.fromRGB(255, 70, 50)

local DistractionService = {}

local activeFlares: { BasePart } = {}

-- Where a flare thrown from `root` comes to rest: forward until it hits
-- something, then down onto the ground.
local function landingPoint(root: BasePart): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = root.Parent
	params.FilterDescendantsInstances = if character then { character } else {}
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local hit = workspace:Raycast(origin, forward * F.ThrowDistance, params)
	local flightEnd = if hit then hit.Position - forward * 1 else origin + forward * F.ThrowDistance
	local down = workspace:Raycast(flightEnd, Vector3.new(0, -40, 0), params)
	return if down then down.Position + Vector3.new(0, 0.2, 0) else flightEnd
end

local function makeFlare(position: Vector3): BasePart
	local flare = Instance.new("Part")
	flare.Name = "ThrownFlare"
	flare.Anchored = true
	flare.CanCollide = false
	flare.CanQuery = false
	flare.CanTouch = false
	flare.Size = Vector3.new(0.35, 0.35, 1.2)
	flare.Material = Enum.Material.Neon
	flare.Color = FLARE_COLOR
	flare.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, math.rad(90))
	local light = Instance.new("PointLight")
	light.Color = FLARE_COLOR
	light.Range = 26
	light.Brightness = 3
	light.Shadows = true
	light.Parent = flare
	local sparks = Instance.new("Fire")
	sparks.Size = 2
	sparks.Heat = 6
	sparks.Color = FLARE_COLOR
	sparks.SecondaryColor = Color3.fromRGB(255, 200, 120)
	sparks.Parent = flare
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(150, 60, 60)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = flare
	return flare
end

-- Throws a flare from the player's character. Returns false if it could not
-- be thrown (no living character), so the item is not used up.
function DistractionService.Throw(root: BasePart): boolean
	if not root.Parent then
		return false
	end
	local target = landingPoint(root)
	local flare = makeFlare(root.Position + Vector3.new(0, 1.5, 0))
	flare.Parent = workspace
	table.insert(activeFlares, flare)

	-- A short arc through the air, then it burns where it lands.
	local start = flare.Position
	local steps = 12
	for i = 1, steps do
		local t = i / steps
		local arc = math.sin(t * math.pi) * 4
		flare.CFrame = CFrame.new(start:Lerp(target, t) + Vector3.new(0, arc, 0)) * flare.CFrame.Rotation
		task.wait(0.03)
	end
	StalkerService.ReportNoise(target, F.NoiseRadius, F.BurnTime)

	task.delay(F.BurnTime, function()
		local index = table.find(activeFlares, flare)
		if index then
			table.remove(activeFlares, index)
		end
		flare:Destroy()
	end)
	return true
end

-- Removes every burning flare (used when the level resets).
function DistractionService.Reset()
	for _, flare in activeFlares do
		flare:Destroy()
	end
	table.clear(activeFlares)
end

return DistractionService
