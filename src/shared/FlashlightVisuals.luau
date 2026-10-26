--!strict
-- FlashlightVisuals: builds the flashlight's light and its visible beam (the
-- "light path") on a part. The light shines out of the part's Front face,
-- and the beam runs straight ahead of it, widening like a real torch beam.
--
-- The server puts one on each character's head so everyone sees each other's
-- lights. The local player's own copy is a separate client-side part aimed
-- exactly where the camera looks (see client FlashlightController).

local Config = require(script.Parent.Config)

local FlashlightVisuals = {}

export type Rig = {
	Light: SpotLight,
	Beam: Beam,
	Glow: PointLight,
}

local LIGHT_COLOR = Color3.fromRGB(255, 240, 210)

function FlashlightVisuals.Create(part: BasePart, forwardOffset: number): Rig
	local F = Config.Flashlight

	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = F.Range
	light.Brightness = F.Brightness
	light.Angle = F.Angle
	light.Color = LIGHT_COLOR
	light.Shadows = true
	light.Enabled = false
	light.Parent = part

	-- A soft glow at the lens so the torch itself reads as "on".
	local glow = Instance.new("PointLight")
	glow.Name = "FlashlightGlow"
	glow.Range = 6
	glow.Brightness = 1
	glow.Color = LIGHT_COLOR
	glow.Enabled = false
	glow.Parent = part

	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "BeamStart"
	startAttachment.Position = Vector3.new(0, 0, -forwardOffset)
	startAttachment.Parent = part
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "BeamEnd"
	endAttachment.Position = Vector3.new(0, 0, -(forwardOffset + F.BeamLength))
	endAttachment.Parent = part

	local beam = Instance.new("Beam")
	beam.Name = "FlashlightBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Width0 = F.BeamStartWidth
	beam.Width1 = F.BeamEndWidth
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(LIGHT_COLOR)
	-- Brightest at the lens, fading out toward the far end.
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - F.BeamOpacity),
		NumberSequenceKeypoint.new(0.6, 1 - F.BeamOpacity * 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Enabled = false
	beam.Parent = part

	return { Light = light, Beam = beam, Glow = glow }
end

function FlashlightVisuals.SetEnabled(rig: Rig, on: boolean)
	rig.Light.Enabled = on
	rig.Beam.Enabled = on
	rig.Glow.Enabled = on
end

return FlashlightVisuals
