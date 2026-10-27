--!strict
-- CrouchPose: makes crouching characters actually crouch (knees bent, hips
-- low, leaning forward), for your own character and for other players.
--
-- The pose is applied straight to the body's joints every frame, on top of
-- whatever animation is playing (so walking still moves the legs). This
-- needs no animation asset, so it works the same in Studio and in the
-- published game. Each player's game poses every character whose
-- "Crouching" attribute is true (the server sets it), so everyone sees
-- everyone crouch.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CrouchPose = {}

local BLEND_SPEED = 6 -- How fast the body sinks into / rises out of the crouch.
local HIP_DROP = 1.6 -- Studs the hips drop (keeps the feet on the ground).

-- Extra rotation per joint (degrees: pitch, yaw, roll) at full crouch.
-- Joint names are the standard R15 ones (Motor6D or AnimationConstraint).
local JOINT_ANGLES: { [string]: { number } } = {
	Waist = { 15, 0, 0 },
	Neck = { -10, 0, 0 },
	LeftHip = { 75, 0, 0 },
	RightHip = { 70, 0, 0 },
	LeftKnee = { -105, 0, 0 },
	RightKnee = { -100, 0, 0 },
	LeftAnkle = { 30, 0, 0 },
	RightAnkle = { 30, 0, 0 },
	LeftShoulder = { 20, 0, 0 },
	RightShoulder = { 20, 0, 0 },
	LeftElbow = { 25, 0, 0 },
	RightElbow = { 25, 0, 0 },
}

-- `written` remembers what we set last frame, so a joint no animation is
-- driving does not keep sinking further every frame.
type Rig = { joints: { [string]: Instance }, amount: number, written: { [string]: { CFrame } } }

local rigs: { [Model]: Rig } = {}
local localCrouching = false

local function findJoints(character: Model): { [string]: Instance }
	local joints = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and (JOINT_ANGLES[d.Name] or d.Name == "Root") then
			joints[d.Name] = d
		end
	end
	return joints
end

local function wantsCrouch(player: Player): boolean
	if player == Players.LocalPlayer then
		return localCrouching
	end
	return player:GetAttribute("Crouching") == true
end

local function offsetFor(name: string, amount: number): CFrame
	if name == "Root" then
		return CFrame.new(0, -HIP_DROP * amount, 0)
	end
	local a = JOINT_ANGLES[name]
	return CFrame.Angles(math.rad(a[1] * amount), math.rad(a[2] * amount), math.rad(a[3] * amount))
end

local function update(dt: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local rig = rigs[character]
		local target = if wantsCrouch(player) then 1 else 0
		if not rig then
			if target == 0 then
				continue
			end
			rig = { joints = findJoints(character), amount = 0, written = {} }
			rigs[character] = rig
			character.Destroying:Once(function()
				rigs[character] = nil
			end)
		end
		local r = rig :: Rig
		r.amount += math.clamp(target - r.amount, -BLEND_SPEED * dt, BLEND_SPEED * dt)
		-- Runs after the animations for this frame, so the crouch is layered
		-- on top of them.
		for name, joint in r.joints do
			if not joint.Parent then
				continue
			end
			local current: CFrame = (joint :: any).Transform
			local last = r.written[name]
			local base = current
			if last and current:FuzzyEq(last[1], 1e-4) then
				-- Nothing animated this joint since last frame: undo our offset.
				base = last[1] * last[2]:Inverse()
			end
			local offset = offsetFor(name, r.amount)
			local result = base * offset
			;(joint :: any).Transform = result
			r.written[name] = { result, offset }
		end
		if r.amount <= 0.001 then
			r.amount = 0
		end
	end
end

-- The local player calls this so their own crouch shows at once, without
-- waiting for the server's attribute to come back.
function CrouchPose.SetLocal(crouching: boolean)
	localCrouching = crouching
end

function CrouchPose.Init()
	Players.LocalPlayer.CharacterAdded:Connect(function()
		localCrouching = false
	end)
	RunService.Stepped:Connect(function(_, dt)
		update(dt)
	end)
end

return CrouchPose
