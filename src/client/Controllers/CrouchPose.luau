--!strict
-- CrouchPose: makes crouching characters actually crouch (knees bent, hips
-- low, leaning forward), for your own character and for other players.
--
-- The pose is built in code as a KeyframeSequence and registered on this
-- player's machine, so no animation asset has to be uploaded. Each player's
-- game plays it on every character whose "Crouching" attribute is true
-- (the server sets that attribute), so everyone sees everyone crouch.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")

local CrouchPose = {}

-- Joint rotations (degrees) and the hip drop, for a standard R15 body.
local HIP_DROP = 1.05
local JOINTS: { [string]: { number } } = {
	-- { pitch, yaw, roll }; positive pitch tips a part forward/up.
	UpperTorso = { 15, 0, 0 },
	Head = { -10, 0, 0 },
	LeftUpperLeg = { 75, 0, 0 },
	RightUpperLeg = { 70, 0, 0 },
	LeftLowerLeg = { -105, 0, 0 },
	RightLowerLeg = { -100, 0, 0 },
	LeftFoot = { 30, 0, 0 },
	RightFoot = { 30, 0, 0 },
	LeftUpperArm = { 20, 0, 0 },
	RightUpperArm = { 20, 0, 0 },
	LeftLowerArm = { 25, 0, 0 },
	RightLowerArm = { 25, 0, 0 },
}

-- Parent of each part in the R15 pose tree.
local PARENTS: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
}

local animationId: string? = nil
local tracks: { [Model]: AnimationTrack } = {}

local function buildPose(): string?
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "RiftfallCrouch"
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Action
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = 0
	keyframe.Parent = sequence

	local poses: { [string]: Pose } = {}
	local root = Instance.new("Pose")
	root.Name = "HumanoidRootPart"
	root.Weight = 0
	root.Parent = keyframe
	poses.HumanoidRootPart = root
	-- Create poses parent-first (LowerTorso before its children, and so on).
	local order = {
		"LowerTorso",
		"UpperTorso",
		"Head",
		"LeftUpperArm",
		"LeftLowerArm",
		"LeftHand",
		"RightUpperArm",
		"RightLowerArm",
		"RightHand",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"LeftFoot",
		"RightUpperLeg",
		"RightLowerLeg",
		"RightFoot",
	}
	for _, name in order do
		local pose = Instance.new("Pose")
		pose.Name = name
		local angles = JOINTS[name]
		local cframe = CFrame.identity
		if name == "LowerTorso" then
			cframe = CFrame.new(0, -HIP_DROP, 0)
		elseif angles then
			cframe = CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
		end
		pose.CFrame = cframe
		pose.EasingStyle = Enum.PoseEasingStyle.Linear
		pose.Parent = poses[PARENTS[name]]
		poses[name] = pose
	end
	-- A second identical keyframe so the looping pose holds still.
	local hold = keyframe:Clone()
	hold.Time = 1
	hold.Parent = sequence

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn("[CrouchPose] Could not build the crouch pose:", id)
		return nil
	end
	return id
end

local function setCrouching(character: Model, crouching: boolean)
	local track = tracks[character]
	if crouching then
		if track and track.IsPlaying then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not (animator and animationId) then
			return
		end
		if not track then
			local animation = Instance.new("Animation")
			animation.AnimationId = animationId
			local ok, loaded = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if not ok or not loaded then
				return
			end
			track = loaded
			tracks[character] = loaded
			character.Destroying:Once(function()
				tracks[character] = nil
			end)
		end
		(track :: AnimationTrack):Play(0.2)
	elseif track then
		track:Stop(0.2)
	end
end

local function watchPlayer(player: Player)
	local function refresh()
		local character = player.Character
		if character then
			setCrouching(character, player:GetAttribute("Crouching") == true)
		end
	end
	player:GetAttributeChangedSignal("Crouching"):Connect(refresh)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		refresh()
	end)
	refresh()
end

-- The local player calls this directly so their own crouch shows at once,
-- without waiting for the server's attribute to come back.
function CrouchPose.SetLocal(crouching: boolean)
	local character = Players.LocalPlayer.Character
	if character then
		setCrouching(character, crouching)
	end
end

function CrouchPose.Init()
	animationId = buildPose()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return CrouchPose
