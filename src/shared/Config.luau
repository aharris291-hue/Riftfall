--!strict
-- Config: every tunable number for the demo lives here, so balance changes
-- never require digging through gameplay code.

local Config = {}

Config.Player = {
	WalkSpeed = 12,
	SprintSpeed = 20,
	CrouchSpeed = 6,
	MaxStamina = 100,
	StaminaDrainPerSecond = 22,
	StaminaRegenPerSecond = 14,
	-- Stamina must refill to this before sprinting is allowed again after running dry.
	StaminaRecoverThreshold = 30,
}

Config.Inventory = {
	SlotCount = 4,
	-- Seconds a player must wait between item uses (stops spam/exploit requests).
	UseCooldown = 1.0,
}

Config.Flashlight = {
	MaxBattery = 100,
	-- Battery drained per second while the light is on.
	DrainPerSecond = 1.2,
	StartingBattery = 60,
	Range = 60,
	Brightness = 6,
	Angle = 45,
	-- The visible beam ("light path") in front of the player.
	BeamLength = 32,
	BeamStartWidth = 0.6,
	BeamEndWidth = 16,
	BeamOpacity = 0.22, -- 0 = invisible beam, 1 = solid.
}

Config.Stalker = {
	MaxHealth = 1000, -- The demo enemy cannot be killed; it is avoided, not fought.
	PatrolSpeed = 7,
	InvestigateSpeed = 11,
	ChaseSpeed = 17,
	HuntSpeed = 16, -- Speed during the scripted escape sequence.
	SightRange = 55,
	SightRangeFlashlightOn = 80, -- Your light makes you easier to spot.
	SightHalfAngle = 60, -- Degrees either side of where it is facing.
	HearingSprint = 45,
	HearingWalk = 16,
	HearingCrouch = 5,
	HidingRevealDistance = 7, -- Hidden players are only noticed this close.
	AttackRange = 5.5,
	AttackWindup = 0.45, -- Telegraph before the swing lands (fair horror).
	AttackDamage = 25,
	AttackCooldown = 1.6,
	LoseSightTime = 4, -- Seconds without seeing you before it starts searching.
	SearchTime = 7,
	InvestigateTime = 5,
	TickInterval = 0.2, -- AI update rate in seconds.
	RepathInterval = 0.6,
}

Config.Escape = {
	DebrisDamage = 30,
	DebrisWarningTime = 1.3, -- Seconds the red warning circle shows before a rock lands.
	DebrisInterval = 0.7,
	HuntDelay = 4, -- Seconds after the escape starts before the Stalker is released.
}

-- Night lighting. Raise Brightness / Ambient / OutdoorAmbient to make the
-- world brighter, lower them for a darker, scarier night. FogDensity is how
-- thick the mist is (0 = none, 1 = very thick).
Config.Lighting = {
	ClockTime = 0.5,
	Brightness = 1.6,
	ExposureCompensation = 0.35,
	Ambient = Color3.fromRGB(52, 56, 66),
	OutdoorAmbient = Color3.fromRGB(96, 104, 118),
	FogDensity = 0.3,
	FogHaze = 1,
	-- Colour grade (from Adam's Chapter 1 lighting script): more contrast,
	-- less saturation and a cold blue tint give the stormy film look without
	-- making the night darker.
	Contrast = 0.15,
	Saturation = -0.28,
	Tint = Color3.fromRGB(225, 235, 255),
	-- Lifts the mist toward the horizon so cliffs and the mountain read as
	-- dark silhouettes against the storm sky.
	AtmosphereOffset = 0.25,
	BloomIntensity = 0.5,
	BloomSize = 24,
	BloomThreshold = 1.0,
}

Config.World = {
	KillHeight = -40, -- Falling below this Y position is fatal.
}

-- Sound asset IDs. These are EMPTY on purpose: no audio has been chosen yet,
-- and made-up IDs would not work. To add a sound, find one you are allowed to
-- use in the Creator Store (Toolbox > Audio), copy its number, and paste it
-- here as "rbxassetid://123456789". Empty entries are simply skipped.
Config.Sounds = {
	Rain = "",
	Thunder = "",
	Heartbeat = "",
	Rumble = "",
	Pickup = "",
}

return Config
