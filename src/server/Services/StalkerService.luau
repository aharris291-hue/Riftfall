--!strict
-- StalkerService: the Rift Stalker, the demo's one active enemy.
--
-- It runs a simple state machine on the server, a few times per second:
--
--   Patrol      walks a loop of patrol points in the ruins
--   Investigate heard a noise: walks to where it came from and looks around
--   Chase       sees a player: runs at them
--   Attack      close enough: winds up (a visible tell) and then swings
--   Search      lost sight: checks the last known position, then wanders
--   Return      gives up and walks back to its patrol route
--   Hunt        scripted escape sequence: pursues the nearest escaping player
--   Idle        waits (before being released during the escape)
--
-- Fair-horror rules: it only knows where you are if it SEES you (in front of
-- it, within range, with nothing blocking the view) or HEARS you (sprinting
-- is loud, walking is quiet, crouching is nearly silent). Crouching inside
-- tall grass hides you unless it is right next to you. A lit flashlight lets
-- it see you from further away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(script.Parent.Parent.Util.Zones)
local PlayerData = require(script.Parent.Parent.Util.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Config.Stalker

local StalkerService = {}

type State = "Patrol" | "Investigate" | "Chase" | "Attack" | "Search" | "Return" | "Hunt" | "Idle"

local model: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local eyes: { BasePart } = {}

local state: State = "Patrol"
local stateStarted = 0
local mode: "Explore" | "Hunt" = "Explore"
local huntReleaseTime = 0

local target: Player? = nil
local lastSeenTime = 0
local lastKnownPosition: Vector3? = nil
local investigatePosition: Vector3? = nil
local searchPoint: Vector3? = nil
local lastAttackTime = 0
local attackStarted = 0

-- Loud noises from the world (distraction flares). Each one can be heard
-- within its radius until it expires.
type Noise = { Position: Vector3, Radius: number, Expires: number }
local noises: { Noise } = {}

local patrolPoints: { Vector3 } = {}
local patrolIndex = 1

-- Pathfinding bookkeeping.
local path = PathfindingService:CreatePath({
	AgentRadius = 2.5,
	AgentHeight = 9,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 6,
})
local waypoints: { PathWaypoint } = {}
local waypointIndex = 1
local pathGoal: Vector3? = nil
local lastPathTime = 0
local pathFailures = 0
local lastProgressPosition = Vector3.zero
local lastProgressTime = 0

local rng = Random.new()

local MODEL_NAME = "RiftStalker"
local EYE_COLOR = Color3.fromRGB(255, 90, 230)
local ATTACK_EYE_COLOR = Color3.fromRGB(255, 30, 30)

------------------------------------------------------------------------------
-- Model
------------------------------------------------------------------------------

-- Builds a tall, thin placeholder creature from parts. Replace with a real
-- model later (keep a Humanoid and a HumanoidRootPart).
local function buildModel(position: Vector3): Model
	local m = Instance.new("Model")
	m.Name = MODEL_NAME
	local body = Color3.fromRGB(34, 24, 46)

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CFrame = CFrame.new(position)
	hrp.Parent = m

	local function limb(name: string, size: Vector3, offset: CFrame, color: Color3?, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = hrp.CFrame * offset
		p.Color = color or body
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = true
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- The Rift Stalker (concept sheet): a tall alien hunter with a dark
	-- violet exoskeleton, glowing crystal spines, long clawed arms and
	-- back-bent legs. Fast, aggressive, and able to phase between dimensions.
	local shell = Color3.fromRGB(34, 24, 46)
	local plate = Color3.fromRGB(58, 40, 78)
	local crystal = Color3.fromRGB(190, 90, 255)

	local torso =
		limb("Torso", Vector3.new(2.0, 3.0, 1.1), CFrame.new(0, 1.9, 0) * CFrame.Angles(math.rad(-14), 0, 0), shell)
	-- The torso is the one part that collides, so players cannot walk through it.
	torso.CanCollide = true
	limb(
		"Chest",
		Vector3.new(2.3, 1.3, 1.3),
		CFrame.new(0, 2.8, -0.25) * CFrame.Angles(math.rad(-14), 0, 0),
		plate,
		Enum.Material.Slate
	)
	limb("Waist", Vector3.new(1.3, 0.9, 0.9), CFrame.new(0, 0.2, 0), shell)
	limb("Neck", Vector3.new(0.6, 0.9, 0.6), CFrame.new(0, 3.9, -0.55) * CFrame.Angles(math.rad(-30), 0, 0), shell)
	limb(
		"Head",
		Vector3.new(1.1, 1.0, 1.7),
		CFrame.new(0, 4.5, -0.95) * CFrame.Angles(math.rad(-8), 0, 0),
		plate,
		Enum.Material.Slate
	)
	limb("Jaw", Vector3.new(0.9, 0.35, 1.2), CFrame.new(0, 4.05, -1.15) * CFrame.Angles(math.rad(10), 0, 0), shell)

	-- Long arms: upper arm, forearm, and three claws each.
	for _, side in { -1, 1 } do
		limb(
			"UpperArm",
			Vector3.new(0.5, 2.6, 0.5),
			CFrame.new(side * 1.4, 2.3, -0.2) * CFrame.Angles(math.rad(-15), 0, math.rad(side * 12)),
			shell
		)
		limb(
			"Forearm",
			Vector3.new(0.42, 2.8, 0.42),
			CFrame.new(side * 1.75, 0.0, -0.75) * CFrame.Angles(math.rad(-30), 0, math.rad(side * 4)),
			plate
		)
		for c = -1, 1 do
			local claw = limb(
				"Claw",
				Vector3.new(0.12, 1.1, 0.12),
				CFrame.new(side * 1.85 + c * 0.14, -1.55, -1.45) * CFrame.Angles(math.rad(-40), 0, math.rad(c * 10)),
				Color3.fromRGB(220, 200, 240),
				Enum.Material.Marble
			)
			claw.CanQuery = false
		end
		-- Back-bent legs: thigh forward, shin back, foot.
		limb(
			"Thigh",
			Vector3.new(0.7, 2.0, 0.7),
			CFrame.new(side * 0.6, -0.9, -0.35) * CFrame.Angles(math.rad(25), 0, 0),
			shell
		)
		limb(
			"Shin",
			Vector3.new(0.5, 2.2, 0.5),
			CFrame.new(side * 0.6, -2.7, 0.15) * CFrame.Angles(math.rad(-20), 0, 0),
			plate
		)
		limb("Foot", Vector3.new(0.6, 0.3, 1.2), CFrame.new(side * 0.6, -3.85, -0.2), shell)
	end

	-- Glowing crystal spines along the back, shoulders and head crest.
	local spines = {
		{ Vector3.new(0, 3.3, 0.7), -35, 0, 1.6 },
		{ Vector3.new(0, 2.5, 0.75), -45, 0, 1.3 },
		{ Vector3.new(0, 1.7, 0.7), -55, 0, 1.0 },
		{ Vector3.new(-1.1, 3.3, 0.2), -20, -35, 1.2 },
		{ Vector3.new(1.1, 3.3, 0.2), -20, 35, 1.2 },
		{ Vector3.new(0, 5.0, -0.6), -60, 0, 1.0 },
		{ Vector3.new(-0.3, 4.9, -0.4), -55, -20, 0.8 },
		{ Vector3.new(0.3, 4.9, -0.4), -55, 20, 0.8 },
	}
	for i, spine in spines do
		local length = spine[4] :: number
		local part = limb(
			"Crystal" .. i,
			Vector3.new(0.22, length, 0.22),
			CFrame.new(spine[1] :: Vector3)
				* CFrame.Angles(math.rad(spine[2] :: number), 0, math.rad(spine[3] :: number))
				* CFrame.new(0, length / 2, 0),
			crystal,
			Enum.Material.Neon
		)
		part.CanQuery = false
	end
	-- Glowing seams down the chest.
	for _, x in { -0.45, 0.45 } do
		local seam = limb(
			"Seam",
			Vector3.new(0.08, 1.6, 0.08),
			CFrame.new(x, 2.2, -0.95) * CFrame.Angles(math.rad(-14), 0, 0),
			crystal,
			Enum.Material.Neon
		)
		seam.CanQuery = false
	end
	local core = limb("Core", Vector3.new(0.4, 0.4, 0.2), CFrame.new(0, 2.9, -0.95), crystal, Enum.Material.Neon)
	core.CanQuery = false
	local aura = Instance.new("PointLight")
	aura.Color = crystal
	aura.Range = 12
	aura.Brightness = 1.4
	aura.Parent = core

	table.clear(eyes)
	for _, x in { -0.3, 0.3 } do
		local eye = limb("Eye", Vector3.new(0.25, 0.14, 0.1), CFrame.new(x, 4.6, -1.8), EYE_COLOR, Enum.Material.Neon)
		eye.CanQuery = false
		table.insert(eyes, eye)
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE_COLOR
	glow.Range = 8
	glow.Brightness = 1.2
	glow.Parent = eyes[1]

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 3 -- Root bottom (Y -1) to feet (Y -4).
	hum.MaxHealth = C.MaxHealth
	hum.Health = C.MaxHealth
	hum.WalkSpeed = C.PatrolSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = m

	m.PrimaryPart = hrp
	return m
end

------------------------------------------------------------------------------
-- Movement
------------------------------------------------------------------------------

local function clearPath()
	table.clear(waypoints)
	waypointIndex = 1
	pathGoal = nil
end

local function stopMoving()
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
	clearPath()
end

local function setSpeed(speed: number)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function lineOfSightClear(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return workspace:Raycast(from, to - from, params) == nil
end

local function characterList(): { Instance }
	local list: { Instance } = {}
	if model then
		table.insert(list, model)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Moves toward `goal` using pathfinding, re-planning when the goal moves or
-- the current plan goes stale. Returns false if it could not make progress.
local function moveToward(goal: Vector3): boolean
	if not humanoid or not root then
		return false
	end
	local now = os.clock()
	local needsPath = pathGoal == nil
		or (goal - (pathGoal :: Vector3)).Magnitude > 4
		or now - lastPathTime > C.RepathInterval * 3
		or waypointIndex > #waypoints

	if needsPath and now - lastPathTime >= C.RepathInterval then
		lastPathTime = now
		local ok = pcall(function()
			path:ComputeAsync(root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			waypointIndex = math.min(2, #waypoints)
			pathGoal = goal
			pathFailures = 0
		else
			pathFailures += 1
			clearPath()
			-- Fallback: if nothing blocks the way, walk straight there.
			if lineOfSightClear(root.Position, goal, characterList()) then
				humanoid:MoveTo(goal)
				return true
			end
			return pathFailures < 4
		end
	end

	local waypoint = waypoints[waypointIndex]
	if waypoint then
		local flat = Vector3.new(waypoint.Position.X - root.Position.X, 0, waypoint.Position.Z - root.Position.Z)
		if flat.Magnitude < 3 then
			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
		end
	end
	if waypoint then
		humanoid:MoveTo(waypoint.Position)
	else
		humanoid:MoveTo(goal)
	end

	-- Stuck detection: no real progress for a while means re-plan.
	if (root.Position - lastProgressPosition).Magnitude > 1.5 then
		lastProgressPosition = root.Position
		lastProgressTime = now
	elseif now - lastProgressTime > 2.5 then
		lastProgressTime = now
		clearPath()
		pathFailures += 1
		return pathFailures < 4
	end
	return true
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

------------------------------------------------------------------------------
-- Senses
------------------------------------------------------------------------------

local function isHidden(player: Player, position: Vector3): boolean
	return player:GetAttribute("Crouching") == true and Zones.InAnyTagged("HidingSpot", position)
end

local function canSee(player: Player, targetRoot: BasePart): boolean
	if not root or not model then
		return false
	end
	local eyePos = root.Position + Vector3.new(0, 4.3, 0)
	local toTarget = targetRoot.Position - root.Position
	local distance = toTarget.Magnitude
	if distance < 1 then
		return true
	end
	local range = if player:GetAttribute("FlashlightOn") then C.SightRangeFlashlightOn else C.SightRange
	if distance > range then
		return false
	end
	if isHidden(player, targetRoot.Position) and distance > C.HidingRevealDistance then
		return false
	end
	-- View cone (always notices players brushing right past it).
	local look = root.CFrame.LookVector
	local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	if distance > 6 and flatLook:Dot(flatDir) < math.cos(math.rad(C.SightHalfAngle)) then
		return false
	end
	return lineOfSightClear(eyePos, targetRoot.Position + Vector3.new(0, 1.5, 0), characterList())
end

local function noiseRadius(player: Player, targetRoot: BasePart): number
	local velocity = targetRoot.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < 2 then
		return 0
	elseif player:GetAttribute("Crouching") then
		return C.HearingCrouch
	elseif speed > Config.Player.WalkSpeed + 2 then
		return C.HearingSprint
	end
	return C.HearingWalk
end

-- Finds the closest visible player, and the closest heard noise.
local function sense(): (Player?, BasePart?, Vector3?)
	if not root then
		return nil, nil, nil
	end
	local seenPlayer: Player?, seenRoot: BasePart?, seenDistance = nil, nil, math.huge
	local heardPosition: Vector3?, heardDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		local _, _, playerRoot = PlayerData.GetAliveCharacter(player)
		if not playerRoot or (data and data.Finished) then
			continue
		end
		local distance = (playerRoot.Position - root.Position).Magnitude
		if distance < seenDistance and canSee(player, playerRoot) then
			seenPlayer, seenRoot, seenDistance = player, playerRoot, distance
		end
		if distance <= noiseRadius(player, playerRoot) and distance < heardDistance then
			heardPosition, heardDistance = playerRoot.Position, distance
		end
	end
	local now = os.clock()
	for i = #noises, 1, -1 do
		local noise = noises[i]
		if now > noise.Expires then
			table.remove(noises, i)
		else
			local distance = (noise.Position - root.Position).Magnitude
			-- A flare is louder than footsteps: it wins unless a player is
			-- much closer.
			if distance <= noise.Radius and distance * 0.5 < heardDistance then
				heardPosition, heardDistance = noise.Position, distance * 0.5
			end
		end
	end
	return seenPlayer, seenRoot, heardPosition
end

------------------------------------------------------------------------------
-- State machine
------------------------------------------------------------------------------

local function setState(newState: State)
	if state == newState then
		return
	end
	state = newState
	stateStarted = os.clock()
	clearPath()
	if model then
		model:SetAttribute("State", newState) -- Visible in Studio for debugging.
	end
	if newState == "Patrol" or newState == "Return" then
		setSpeed(C.PatrolSpeed)
	elseif newState == "Investigate" or newState == "Search" then
		setSpeed(C.InvestigateSpeed)
	elseif newState == "Chase" then
		setSpeed(C.ChaseSpeed)
	elseif newState == "Hunt" then
		setSpeed(C.HuntSpeed)
	end
end

local function setEyesBright(bright: boolean)
	for _, eye in eyes do
		eye.Color = if bright then ATTACK_EYE_COLOR else EYE_COLOR
	end
end

local function nearestPatrolIndex(): number
	if not root then
		return 1
	end
	local best, bestDistance = 1, math.huge
	for i, point in patrolPoints do
		local d = (point - root.Position).Magnitude
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

local function currentTargetRoot(): BasePart?
	if not target then
		return nil
	end
	local data = PlayerData.Get(target)
	local _, _, targetRoot = PlayerData.GetAliveCharacter(target)
	if data and data.Finished then
		return nil
	end
	return targetRoot
end

-- Starts an attack; the damage is decided when the wind-up ends.
local function beginAttack()
	setState("Attack")
	attackStarted = os.clock()
	stopMoving()
	setEyesBright(true)
end

local function updateAttack(returnState: State)
	local targetRoot = currentTargetRoot()
	if not target or not targetRoot or not root then
		setEyesBright(false)
		setState(returnState)
		return
	end
	-- Turn to face the target during the wind-up.
	root.CFrame =
		CFrame.lookAt(root.Position, Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z))
	if os.clock() - attackStarted < C.AttackWindup then
		return
	end
	-- Only hits if the player is still in reach: dodging the tell works.
	if flatDistance(targetRoot.Position, root.Position) <= C.AttackRange + 1 then
		local _, targetHumanoid = PlayerData.GetAliveCharacter(target)
		if targetHumanoid then
			targetHumanoid:TakeDamage(C.AttackDamage)
			Remotes.CameraShake:FireClient(target, 0.4, 1.2)
		end
	end
	lastAttackTime = os.clock()
	setEyesBright(false)
	setState(returnState)
end

local function tickExplore()
	if not root then
		return
	end
	local now = os.clock()
	local seenPlayer, seenRoot, heardPosition = sense()

	if state == "Attack" then
		updateAttack("Chase")
		return
	end

	if seenPlayer and seenRoot then
		target = seenPlayer
		lastSeenTime = now
		lastKnownPosition = seenRoot.Position
		if state ~= "Chase" then
			setState("Chase")
		end
	elseif
		heardPosition and (state == "Patrol" or state == "Return" or state == "Search" or state == "Investigate")
	then
		if state ~= "Investigate" or (investigatePosition and (heardPosition - investigatePosition).Magnitude > 8) then
			investigatePosition = heardPosition
			setState("Investigate")
		end
	end

	if state == "Patrol" then
		if #patrolPoints == 0 then
			return
		end
		local point = patrolPoints[patrolIndex]
		if flatDistance(point, root.Position) < 4 then
			patrolIndex = patrolIndex % #patrolPoints + 1
			point = patrolPoints[patrolIndex]
		end
		if not moveToward(point) then
			patrolIndex = patrolIndex % #patrolPoints + 1
			pathFailures = 0
		end
	elseif state == "Investigate" then
		local goal = investigatePosition
		if not goal then
			setState("Return")
			return
		end
		if flatDistance(goal, root.Position) < 5 or not moveToward(goal) then
			-- Arrived (or cannot reach): pause and "listen".
			stopMoving()
			if now - stateStarted > C.InvestigateTime then
				setState("Return")
			end
		elseif now - stateStarted > C.InvestigateTime * 3 then
			setState("Return")
		end
	elseif state == "Chase" then
		local targetRoot = currentTargetRoot()
		if not targetRoot then
			target = nil
			setState("Return")
			return
		end
		if now - lastSeenTime > C.LoseSightTime then
			searchPoint = lastKnownPosition
			setState("Search")
			return
		end
		if
			now - lastSeenTime < 0.3
			and flatDistance(targetRoot.Position, root.Position) <= C.AttackRange
			and now - lastAttackTime > C.AttackCooldown
		then
			beginAttack()
			return
		end
		-- Chase toward where it last saw the player, not where they truly are.
		if not moveToward(lastKnownPosition or targetRoot.Position) then
			searchPoint = lastKnownPosition
			setState("Search")
		end
	elseif state == "Search" then
		if now - stateStarted > C.SearchTime then
			target = nil
			setState("Return")
			return
		end
		local goal = searchPoint
		if not goal or flatDistance(goal, root.Position) < 4 then
			local base = lastKnownPosition or root.Position
			searchPoint = base + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
			return
		end
		if not moveToward(goal) then
			searchPoint = nil
		end
	elseif state == "Return" then
		patrolIndex = nearestPatrolIndex()
		setState("Patrol")
	end
end

-- During the escape the creature ignores stealth and pursues whoever is
-- still running through the collapsing temple.
local function tickHunt()
	if not root then
		return
	end
	local now = os.clock()
	if now < huntReleaseTime then
		setState("Idle")
		stopMoving()
		return
	end
	if state == "Attack" then
		updateAttack("Hunt")
		return
	end
	local best: Player?, bestRoot: BasePart?, bestDistance = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		local _, _, playerRoot = PlayerData.GetAliveCharacter(player)
		if playerRoot and not (data and data.Finished) then
			local pos = playerRoot.Position
			-- Only players still on the escape route (not up the cliff).
			if pos.Z > 285 and pos.Z < 447 and pos.Y < 18 then
				local d = (pos - root.Position).Magnitude
				if d < bestDistance then
					best, bestRoot, bestDistance = player, playerRoot, d
				end
			end
		end
	end
	if not best or not bestRoot then
		setState("Idle")
		stopMoving()
		return
	end
	target = best
	setState("Hunt")
	if flatDistance(bestRoot.Position, root.Position) <= C.AttackRange and now - lastAttackTime > C.AttackCooldown then
		beginAttack()
		return
	end
	moveToward(bestRoot.Position)
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

local function loadPatrolPoints()
	local markers = CollectionService:GetTagged("StalkerPatrol")
	table.sort(markers, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	table.clear(patrolPoints)
	for _, marker in markers do
		if marker:IsA("BasePart") and marker:IsDescendantOf(workspace) then
			table.insert(patrolPoints, marker.Position)
		end
	end
	patrolIndex = 1
end

function StalkerService.Despawn()
	table.clear(noises)
	if model then
		model:Destroy()
	end
	model, humanoid, root = nil, nil, nil
	table.clear(eyes)
	clearPath()
	target = nil
end

local function spawnAt(position: Vector3)
	StalkerService.Despawn()
	local m = buildModel(position)
	m.Parent = workspace
	model = m
	humanoid = m:FindFirstChildOfClass("Humanoid")
	local hrp = m.PrimaryPart
	root = hrp
	if hrp then
		-- The server simulates the creature, so clients cannot move it.
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end
	lastProgressPosition = position
	lastProgressTime = os.clock()
end

-- Spawns the creature on its patrol in the ruins (start of a run).
function StalkerService.SpawnPatrol()
	loadPatrolPoints()
	local marker = Zones.FirstTagged("StalkerSpawn")
	spawnAt(if marker then marker.Position else Vector3.new(0, 4, 292))
	mode = "Explore"
	state = "Idle"
	setState("Patrol")
end

-- Starts the escape chase: the creature appears at the temple entrance and
-- is released after a short delay, giving players a head start.
function StalkerService.StartHunt(delaySeconds: number)
	local marker = Zones.FirstTagged("StalkerHuntSpawn")
	spawnAt(if marker then marker.Position else Vector3.new(0, 4, 296))
	mode = "Hunt"
	huntReleaseTime = os.clock() + delaySeconds
	state = "Patrol"
	setState("Idle")
end

-- A loud sound somewhere in the world (for example a thrown flare). While it
-- lasts, the creature hears it from within `radius` and goes to investigate.
function StalkerService.ReportNoise(position: Vector3, radius: number, duration: number)
	table.insert(noises, { Position = position, Radius = radius, Expires = os.clock() + duration })
end

-- The first sighting: a harmless copy of the creature walks across the trail
-- far ahead of the player, flickers, and vanishes. It is the creature's
-- introduction ("through clues before a full confrontation").
function StalkerService.PlaySighting(from: Vector3, to: Vector3, seconds: number)
	local savedEyes = table.clone(eyes) -- buildModel refills the eye list.
	local m = buildModel(from)
	table.clear(eyes)
	for _, eye in savedEyes do
		table.insert(eyes, eye)
	end
	m.Name = MODEL_NAME .. "Sighting" -- Not the real enemy: no danger meter.
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	local facing = CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z))
	m:PivotTo(facing)
	m.Parent = workspace
	local steps = math.max(1, math.floor(seconds / 0.05))
	for i = 1, steps do
		if not m.Parent then
			return
		end
		local alpha = i / steps
		-- A slight bob so it reads as walking, not sliding.
		local bob = math.abs(math.sin(alpha * math.pi * 8)) * 0.4
		m:PivotTo(facing.Rotation + from:Lerp(to, alpha) + Vector3.new(0, bob, 0))
		task.wait(0.05)
	end
	-- Flicker out of this dimension.
	for _ = 1, 3 do
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0.8
			end
		end
		task.wait(0.1)
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0
			end
		end
		task.wait(0.08)
	end
	m:Destroy()
end

function StalkerService.GetMode(): string
	return mode
end

-- Every few seconds the creature briefly flickers, half out of this
-- dimension. Purely visual; it never happens during an attack wind-up, so
-- the attack tell stays readable.
local function phaseFlicker()
	local m = model
	if not m or state == "Attack" then
		return
	end
	for _ = 1, 2 do
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0.7
			end
		end
		task.wait(0.12)
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0
			end
		end
		task.wait(0.1)
	end
end

function StalkerService.Init()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(5, 9))
			if model and model.Parent then
				phaseFlicker()
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(C.TickInterval)
			if model and root and humanoid and model.Parent then
				local ok, err = pcall(if mode == "Hunt" then tickHunt else tickExplore)
				if not ok then
					warn("[StalkerService] AI tick failed:", err)
				end
			end
		end
	end)
end

return StalkerService
