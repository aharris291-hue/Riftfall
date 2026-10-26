--!strict
-- LevelBuilder: builds the whole Chapter 1 demo map out of simple parts.
--
-- Why build the map in code? It keeps the entire game in plain text files
-- (easy to review, version, and rebuild), and it lets "Play Again" reset the
-- world by rebuilding it. Gameplay services never hold direct references to
-- map parts; they find them through CollectionService tags, so a rebuilt map
-- is picked up automatically.
--
-- Layout (the player travels toward +Z, "north"):
--   Z  -20 ..  60  Crash site (spawn)
--   Z   60 .. 160  Jungle trail (claw marks + survivor note)
--   Z  160 .. 210  Abandoned camp (checkpoint, journal with puzzle clue)
--   Z  210 .. 300  Ruins courtyard (the Stalker patrols, tall grass to hide in)
--   Z  300 .. 360  Temple interior (dial puzzle, sealed door)
--   Z  360 .. 430  Collapsing tunnel (escape sequence)
--   Z  430 .. 460  Cliff (ladder truss up to Y 24)
--   Z  460 .. 510  Rope bridge over a chasm
--   Z  510 .. 545  Flare landing zone (end of demo)
--
-- Set dressing follows the "Chapter 1 environment" concept art (storm
-- jungle, root-wrapped stone arches, muddy camp with overgrown 4x4s, the
-- crashed helicopter, torches, cliffs and a mountain). The visual pieces are
-- built by Util/SceneryKit; this file decides where they go.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SceneryKit = require(script.Parent.Parent.Util.SceneryKit)

local LevelBuilder = {}

local LEVEL_NAME = "RiftfallLevel"

type PartProps = { [string]: any }

local currentLevel: Folder? = nil
-- Smooth terrain is static, so it is filled on the first build only.
local terrainFilled = false

-- Creates an anchored part with sensible defaults, applying any overrides.
local function makePart(parent: Instance, props: PartProps): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Invisible, non-colliding box used as a trigger zone or marker.
local function makeZone(parent: Instance, name: string, cframe: CFrame, size: Vector3, tag: string): Part
	local zone = makePart(parent, {
		Name = name,
		CFrame = cframe,
		Size = size,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	CollectionService:AddTag(zone, tag)
	return zone
end

local function makePrompt(
	parent: Instance,
	actionText: string,
	objectText: string,
	holdDuration: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Shadows are only worth it on the big warm light sources (they cost
-- performance), so they are opt-in.
local function addLight(
	parent: Instance,
	color: Color3,
	range: number,
	brightness: number,
	shadows: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

-- A big text label painted on one face of a part (signs, dial symbols, mural).
local function addSurfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	return label
end

------------------------------------------------------------------------------
-- Scenery helpers
------------------------------------------------------------------------------

local function makeTree(parent: Instance, position: Vector3, rng: Random)
	SceneryKit.Tree(parent, position, rng)
end

local function makeRock(parent: Instance, position: Vector3, size: Vector3, rng: Random)
	makePart(parent, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(70, 72, 74),
	})
end

-- Tall grass: purely visual blades plus an invisible "HidingSpot" zone.
local function makeGrassPatch(parent: Instance, center: Vector3, size: Vector2, rng: Random)
	local model = Instance.new("Model")
	model.Name = "TallGrass"
	makeZone(
		model,
		"HidingZone",
		CFrame.new(center + Vector3.new(0, 3, 0)),
		Vector3.new(size.X, 6, size.Y),
		"HidingSpot"
	)
	local bladeCount = math.floor(size.X * size.Y / 6)
	for _ = 1, bladeCount do
		local h = rng:NextNumber(3.5, 5.5)
		local offset =
			Vector3.new(rng:NextNumber(-size.X / 2, size.X / 2), h / 2, rng:NextNumber(-size.Y / 2, size.Y / 2))
		makePart(model, {
			Name = "Blade",
			Size = Vector3.new(0.4, h, 0.4),
			CFrame = CFrame.new(center + offset)
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(64, 92 + rng:NextInteger(0, 25), 44),
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
	end
	model.Parent = parent
end

local function makePickup(parent: Instance, itemId: string, displayName: string, position: Vector3, color: Color3)
	local part = makePart(parent, {
		Name = itemId .. "Pickup",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Position = position,
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CastShadow = false,
	})
	part:SetAttribute("ItemId", itemId)
	part:SetAttribute("Count", 1)
	-- A faint glow keeps pickups findable on low graphics settings (fairness).
	addLight(part, color, 8, 0.8)
	makePrompt(part, "Pick up", displayName)
	CollectionService:AddTag(part, "Pickup")
end

local function makeNote(parent: Instance, noteId: string, label: string, position: Vector3)
	local part = makePart(parent, {
		Name = noteId .. "Note",
		Size = Vector3.new(1.4, 0.1, 1.8),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(15), 0),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(225, 215, 180),
		CanCollide = false,
	})
	part:SetAttribute("NoteId", noteId)
	addLight(part, Color3.fromRGB(255, 240, 200), 6, 0.6)
	makePrompt(part, "Read", label)
	CollectionService:AddTag(part, "Note")
end

local function makeCheckpoint(parent: Instance, name: string, order: number, position: Vector3)
	local pad = makePart(parent, {
		Name = "Checkpoint_" .. name,
		Size = Vector3.new(6, 0.4, 6),
		Position = position + Vector3.new(0, 0.2, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(60, 60, 64),
	})
	local flare = makePart(parent, {
		Name = "CheckpointFlare",
		Size = Vector3.new(0.4, 2.5, 0.4),
		Position = position + Vector3.new(2.5, 1.65, 2.5),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(80, 255, 140),
		CanCollide = false,
	})
	addLight(flare, Color3.fromRGB(80, 255, 140), 14, 1)
	local zone = makeZone(
		parent,
		"CheckpointZone_" .. name,
		CFrame.new(position + Vector3.new(0, 4, 0)),
		Vector3.new(14, 8, 14),
		"Checkpoint"
	)
	zone:SetAttribute("CheckpointName", name)
	zone:SetAttribute("Order", order)
	zone:SetAttribute("SpawnPosition", pad.Position + Vector3.new(0, 3.5, 0))
end

-- Where a story character stands. CharacterService spawns the character on
-- it; Phase limits it to "Explore" (before the door opens) or "Escape"
-- (after), or "Any".
local function makeCharacterSpot(
	parent: Instance,
	characterId: string,
	position: Vector3,
	lookAt: Vector3,
	phase: string
)
	local flatTarget = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	local spot = makeZone(
		parent,
		"Spot_" .. characterId .. "_" .. phase,
		CFrame.lookAt(position, flatTarget),
		Vector3.new(1, 1, 1),
		"CharacterSpot"
	)
	spot:SetAttribute("CharacterId", characterId)
	spot:SetAttribute("Phase", phase)
end

local function makeStoryTrigger(parent: Instance, triggerId: string, cframe: CFrame, size: Vector3)
	local zone = makeZone(parent, "Trigger_" .. triggerId, cframe, size, "StoryTrigger")
	zone:SetAttribute("TriggerId", triggerId)
end

local function makeWall(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	height: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	transparency: number?
)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	makePart(parent, {
		Name = "Wall",
		Size = Vector3.new(thickness, height, length),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, height / 2, 0), to + Vector3.new(0, height / 2, 0)),
		Material = material,
		Color = color,
		Transparency = transparency or 0,
	})
end

------------------------------------------------------------------------------
-- Sections
------------------------------------------------------------------------------

-- Returns the X position of the trail's center line at a given Z, so trees
-- can avoid it. The trail gently winds instead of being a straight corridor.
local function trailCenterX(z: number): number
	return math.sin(z / 28) * 9
end

-- Invisible boundary walls so players cannot walk off the map.
local function buildBounds(ground: Folder)
	local boundary = Color3.new(0, 0, 0)
	makeWall(
		ground,
		Vector3.new(-65, 0, -20),
		Vector3.new(-65, 0, 445),
		60,
		2,
		Enum.Material.SmoothPlastic,
		boundary,
		1
	)
	makeWall(ground, Vector3.new(65, 0, -20), Vector3.new(65, 0, 445), 60, 2, Enum.Material.SmoothPlastic, boundary, 1)
	makeWall(ground, Vector3.new(-65, 0, -20), Vector3.new(65, 0, -20), 60, 2, Enum.Material.SmoothPlastic, boundary, 1)
	-- The temple is the only way forward: block the gaps beside it.
	makeWall(
		ground,
		Vector3.new(-65, 0, 300),
		Vector3.new(-27, 0, 300),
		60,
		2,
		Enum.Material.SmoothPlastic,
		boundary,
		1
	)
	makeWall(ground, Vector3.new(27, 0, 300), Vector3.new(65, 0, 300), 60, 2, Enum.Material.SmoothPlastic, boundary, 1)
end

local function buildGroundAndBounds(level: Folder)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = level

	-- In Roblox the ground is smooth terrain (see buildTerrain); the flat
	-- floor and trail parts are only the fallback for the offline tests.
	if SceneryKit.Terrain then
		buildBounds(ground)
		return
	end
	makePart(ground, {
		Name = "JungleFloor",
		Size = Vector3.new(130, 2, 465),
		Position = Vector3.new(0, -1, 212.5),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(46, 66, 38),
	})
	-- Dirt trail segments that follow trailCenterX.
	for z = -10, 205, 10 do
		makePart(ground, {
			Name = "Trail",
			Size = Vector3.new(9, 0.2, 11),
			CFrame = CFrame.new(trailCenterX(z), 0.05, z) * CFrame.Angles(0, math.atan(math.cos(z / 28) * 9 / 28), 0),
			Material = Enum.Material.Mud,
			Color = Color3.fromRGB(78, 62, 46),
			CanCollide = false,
		})
	end
	buildBounds(ground)
end

local function buildJungle(level: Folder, rng: Random)
	local jungle = Instance.new("Folder")
	jungle.Name = "Jungle"
	jungle.Parent = level

	-- Clearings where trees must not grow (center X, center Z, radius).
	local clearings = {
		{ 0, 15, 26 }, -- crash site
		{ 0, 185, 26 }, -- camp
	}
	local function isClear(x: number, z: number): boolean
		if z < 150 or z > 205 then
			if math.abs(x - trailCenterX(z)) < 9 then
				return true
			end
		end
		for _, c in clearings do
			if (Vector2.new(x, z) - Vector2.new(c[1], c[2])).Magnitude < c[3] then
				return true
			end
		end
		return false
	end

	local placed = 0
	local attempts = 0
	while placed < 170 and attempts < 2000 do
		attempts += 1
		local x = rng:NextNumber(-62, 62)
		local z = rng:NextNumber(-18, 212)
		if not isClear(x, z) then
			makeTree(jungle, Vector3.new(x, 0, z), rng)
			placed += 1
		end
	end
	-- A thinner tree line framing the ruins courtyard.
	for z = 215, 295, 12 do
		makeTree(jungle, Vector3.new(-58 + rng:NextNumber(-2, 2), 0, z), rng)
		makeTree(jungle, Vector3.new(58 + rng:NextNumber(-2, 2), 0, z), rng)
	end
	-- Ferns carpet the jungle floor, thickest along the trail edges.
	local ferns = 0
	attempts = 0
	while ferns < 110 and attempts < 1500 do
		attempts += 1
		local z = rng:NextNumber(-15, 210)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = trailCenterX(z) + side * rng:NextNumber(6, 40)
		if math.abs(x) < 62 and not ((Vector2.new(x, z) - Vector2.new(0, 185)).Magnitude < 22) then
			SceneryKit.Fern(jungle, Vector3.new(x, 0, z), rng)
			ferns += 1
		end
	end
	-- Scattered bushes of tall grass along the trail edges (also hideable).
	makeGrassPatch(jungle, Vector3.new(trailCenterX(120) + 8, 0, 120), Vector2.new(6, 8), rng)
	makeGrassPatch(jungle, Vector3.new(trailCenterX(80) - 8, 0, 80), Vector2.new(6, 8), rng)
end

local function buildCrashSite(level: Folder, rng: Random)
	local site = Instance.new("Folder")
	site.Name = "CrashSite"
	site.Parent = level

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StartSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- No force-field: there is nothing to protect against here.
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = Vector3.new(0, 0.2, 2)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(60, 60, 64)
	spawn.Parent = site

	-- The crashed helicopter, still smouldering.
	local firePoint = SceneryKit.Helicopter(site, CFrame.new(-15, 0, 18) * CFrame.Angles(0, math.rad(25), 0), rng)
	local fireSource = makePart(site, {
		Name = "FireSource",
		Size = Vector3.new(2, 1, 2),
		Position = firePoint + Vector3.new(1, 0, -2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Parent = fireSource
	local smoke = Instance.new("Smoke")
	smoke.RiseVelocity = 6
	smoke.Size = 6
	smoke.Opacity = 0.15
	smoke.Color = Color3.fromRGB(40, 40, 40)
	smoke.Parent = fireSource
	addLight(fireSource, Color3.fromRGB(255, 140, 60), 30, 2)

	-- An abandoned expedition 4x4, headlights still on, lighting the way
	-- into the jungle.
	SceneryKit.Truck(site, CFrame.lookAt(Vector3.new(17, 0, 24), Vector3.new(9, 0, 56)), rng)
	SceneryKit.MudPatch(site, Vector3.new(4, 0, 18), Vector2.new(26, 22), rng)
	SceneryKit.Torch(site, Vector3.new(-3, 0, 30))

	-- Supply crates.
	for i, pos in { Vector3.new(8, 1.5, 14), Vector3.new(11, 1.5, 18), Vector3.new(9, 4.5, 15) } do
		makePart(site, {
			Name = "Crate" .. i,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(110, 84, 56),
		})
	end
	makePickup(site, "Battery", "Battery", Vector3.new(6, 1, 19), Color3.fromRGB(120, 200, 255))

	-- Serra's hologram projects from a crashed comms drone near the spawn.
	local projector = makePart(site, {
		Name = "HoloProjector",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3.2, 3.2),
		CFrame = CFrame.new(6, 0.15, 8) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(70, 220, 255),
		CanCollide = false,
	})
	addLight(projector, Color3.fromRGB(70, 220, 255), 12, 1.2)
	makeCharacterSpot(site, "Serra", Vector3.new(6, 0.3, 8), Vector3.new(0, 0, 2), "Any")

	-- A rusted sign pointing the way.
	local post = makePart(site, {
		Name = "SignPost",
		Size = Vector3.new(0.6, 6, 0.6),
		Position = Vector3.new(6, 3, 34),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 52, 38),
	})
	local board = makePart(site, {
		Name = "SignBoard",
		Size = Vector3.new(6, 2, 0.3),
		Position = post.Position + Vector3.new(0, 2, -0.45),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(96, 74, 52),
	})
	addSurfaceText(board, Enum.NormalId.Front, "RIFT ZONE - KEEP OUT", Color3.fromRGB(200, 60, 50))
end

local function buildTrail(level: Folder)
	local trail = Instance.new("Folder")
	trail.Name = "Trail"
	trail.Parent = level

	-- Claw marks on a tree beside the trail: the creature is introduced
	-- through clues before the player ever sees it.
	local z = 110
	local treePos = Vector3.new(trailCenterX(z) - 7, 0, z)
	makePart(trail, {
		Name = "MarkedTree",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 5, 5),
		CFrame = CFrame.new(treePos + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(58, 44, 34),
	})
	for i = 1, 4 do
		makePart(trail, {
			Name = "ClawMark",
			Size = Vector3.new(0.3, 4, 0.3),
			CFrame = CFrame.new(treePos + Vector3.new(2.45, 6 + i * 0.2, -1.5 + i * 0.7))
				* CFrame.Angles(math.rad(25), 0, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(120, 30, 40),
			CanCollide = false,
		})
	end
	makePart(trail, {
		Name = "BrokenCrate",
		Size = Vector3.new(3, 2, 3),
		CFrame = CFrame.new(treePos + Vector3.new(4, 1, 3)) * CFrame.Angles(0, 0.4, 0.15),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(96, 74, 52),
	})
	makeNote(trail, "Scrawl", "Scratched message", treePos + Vector3.new(4, 2.1, 3))
	makeStoryTrigger(trail, "ClawMarks", CFrame.new(trailCenterX(z), 4, z), Vector3.new(24, 8, 14))
end

local function buildCamp(level: Folder, rng: Random)
	local camp = Instance.new("Folder")
	camp.Name = "Camp"
	camp.Parent = level

	-- Muddy ground churned up by boots and tyres.
	SceneryKit.MudPatch(camp, Vector3.new(0, 0, 186), Vector2.new(44, 38), rng)

	-- A-frame tents (one torn open), facing the campfire.
	local fireSpot = Vector3.new(2, 0, 186)
	for i, t in { { -12, 178 }, { 12, 194 }, { -9, 199 } } do
		local pos = Vector3.new(t[1], 0, t[2])
		SceneryKit.Tent(camp, CFrame.lookAt(pos, fireSpot), SceneryKit.Colors.Canvas, i == 2)
	end

	-- Two overgrown 4x4s parked at the edges, headlights on.
	SceneryKit.Truck(camp, CFrame.lookAt(Vector3.new(-22, 0, 201), Vector3.new(-2, 0, 184)), rng)
	SceneryKit.Truck(camp, CFrame.lookAt(Vector3.new(21, 0, 176), Vector3.new(2, 0, 190)), rng)

	-- Equipment cases and crates.
	SceneryKit.Cases(camp, CFrame.new(-16, 0, 172) * CFrame.Angles(0, 0.4, 0), rng)
	SceneryKit.Cases(camp, CFrame.new(14, 0, 203) * CFrame.Angles(0, -0.3, 0), rng)
	SceneryKit.Cases(camp, CFrame.new(-2, 0, 204) * CFrame.Angles(0, 0.1, 0), rng)

	-- Torches around the camp keep it readable at night.
	for _, pos in
		{ Vector3.new(-7, 0, 168), Vector3.new(10, 0, 168), Vector3.new(-18, 0, 190), Vector3.new(17, 0, 196) }
	do
		SceneryKit.Torch(camp, pos)
	end

	-- Campfire (cold ashes with a dim ember glow).
	local fire = makePart(camp, {
		Name = "Campfire",
		Size = Vector3.new(4, 0.5, 4),
		Position = Vector3.new(2, 0.25, 186),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(40, 36, 34),
	})
	addLight(fire, Color3.fromRGB(255, 90, 40), 14, 1.2, true)

	local tableTop = makePart(camp, {
		Name = "FieldTable",
		Size = Vector3.new(6, 0.4, 3),
		Position = Vector3.new(-4, 3, 194),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(110, 84, 56),
	})
	for _, off in
		{
			Vector3.new(-2.6, -1.5, -1.2),
			Vector3.new(2.6, -1.5, -1.2),
			Vector3.new(-2.6, -1.5, 1.2),
			Vector3.new(2.6, -1.5, 1.2),
		}
	do
		makePart(camp, {
			Name = "TableLeg",
			Size = Vector3.new(0.4, 2.8, 0.4),
			Position = tableTop.Position + off,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 52, 38),
		})
	end
	local lantern = makePart(camp, {
		Name = "Lantern",
		Size = Vector3.new(0.8, 1.2, 0.8),
		Position = tableTop.Position + Vector3.new(2, 0.8, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 120),
	})
	addLight(lantern, Color3.fromRGB(255, 170, 80), 25, 2.5, true)

	makeNote(camp, "Journal", "Rourke's journal", tableTop.Position + Vector3.new(-1, 0.25, 0))
	makePickup(camp, "Bandage", "Bandage", Vector3.new(12, 1, 184), Color3.fromRGB(230, 225, 210))
	makePickup(camp, "Battery", "Battery", Vector3.new(-14, 1, 186), Color3.fromRGB(120, 200, 255))
	makeCheckpoint(camp, "Camp", 1, Vector3.new(6, 0, 174))
	makeCharacterSpot(camp, "Kade", Vector3.new(-3, 0, 181), Vector3.new(0, 0, 168), "Explore")
	makeStoryTrigger(camp, "Camp", CFrame.new(0, 4, 172), Vector3.new(40, 8, 10))

	-- Scattered gear.
	for _ = 1, 6 do
		makePart(camp, {
			Name = "Debris",
			Size = Vector3.new(rng:NextNumber(1, 2.5), rng:NextNumber(0.5, 1.5), rng:NextNumber(1, 2.5)),
			CFrame = CFrame.new(rng:NextNumber(-18, 18), 0.5, rng:NextNumber(170, 205))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(80, 70, 60),
		})
	end
end

local function buildRuins(level: Folder, rng: Random)
	local ruins = Instance.new("Folder")
	ruins.Name = "Ruins"
	ruins.Parent = level

	local stone = Color3.fromRGB(96, 98, 92)
	makePart(ruins, {
		Name = "CourtyardFloor",
		Size = Vector3.new(90, 0.4, 85),
		Position = Vector3.new(0, 0.2, 257),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(80, 82, 76),
	})

	-- Broken pillars (good cover for breaking line of sight).
	local pillarSpots = {
		Vector3.new(-30, 0, 228),
		Vector3.new(30, 0, 228),
		Vector3.new(-30, 0, 255),
		Vector3.new(30, 0, 255),
		Vector3.new(-30, 0, 282),
		Vector3.new(30, 0, 282),
		Vector3.new(-12, 0, 240),
		Vector3.new(14, 0, 268),
	}
	for _, pos in pillarSpots do
		local h = rng:NextNumber(6, 16)
		local pillar = makePart(ruins, {
			Name = "Pillar",
			Size = Vector3.new(4, h, 4),
			Position = pos + Vector3.new(0, h / 2, 0),
			Material = Enum.Material.Slate,
			Color = stone,
		})
		SceneryKit.MossCap(ruins, pillar)
		SceneryKit.DrapeRoots(ruins, pos + Vector3.new(0, h, 0), 0.4, rng:NextInteger(1, 3), rng)
	end

	-- Moss-covered stone archways strangled by roots: a great gate where the
	-- trail enters the ruins, one framing the temple doorway, and broken
	-- arches along the sides.
	SceneryKit.Arch(ruins, CFrame.new(4, 0.4, 214), { Width = 18, Height = 12, Rng = rng })
	SceneryKit.Arch(ruins, CFrame.new(0, 0.4, 294), { Width = 14, Height = 11, Rng = rng })
	SceneryKit.Arch(
		ruins,
		CFrame.new(-46, 0.4, 262) * CFrame.Angles(0, math.rad(90), 0),
		{ Width = 13, Height = 10, Broken = true, Rng = rng }
	)
	SceneryKit.Arch(
		ruins,
		CFrame.new(46, 0.4, 245) * CFrame.Angles(0, math.rad(90), 0),
		{ Width = 13, Height = 9, Broken = true, Rng = rng }
	)
	-- A cold blue Rift glow hanging in the temple arch (from Adam's lighting
	-- script): the first hint that something unnatural waits inside.
	local riftGlow = makePart(ruins, {
		Name = "RiftGlow",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 8, 296),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(100, 200, 255),
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	addLight(riftGlow, Color3.fromRGB(80, 180, 255), 30, 1.5, true)
	for _, pos in
		{ Vector3.new(-9, 0.4, 211), Vector3.new(17, 0.4, 211), Vector3.new(-12, 0.4, 291), Vector3.new(12, 0.4, 291) }
	do
		SceneryKit.Torch(ruins, pos)
	end
	for _ = 1, 18 do
		SceneryKit.Fern(ruins, Vector3.new(rng:NextNumber(-44, 44), 0.4, rng:NextNumber(216, 296)), rng)
	end

	-- Ancient stairs climbing out of the valley toward the cliffs (scenery,
	-- beyond the boundary).
	for _, side in { -1, 1 } do
		local foot = Vector3.new(side * 68, 0, 262)
		SceneryKit.Stairs(ruins, CFrame.lookAt(foot, foot + Vector3.new(side, 0, 0)), 18, 9, rng)
		-- Torches stand on the stair edge, on top of the step below them.
		for i = 0, 2 do
			local along = 2 + i * 12
			local stepTop = math.floor(along / 1.8) + 1
			SceneryKit.Torch(ruins, foot + Vector3.new(side * along, stepTop, 3.8), 4)
		end
	end
	-- Low crumbling walls.
	makeWall(ruins, Vector3.new(-22, 0, 246), Vector3.new(-8, 0, 250), 4, 2, Enum.Material.Slate, stone)
	makeWall(ruins, Vector3.new(6, 0, 236), Vector3.new(20, 0, 240), 5, 2, Enum.Material.Slate, stone)
	makeWall(ruins, Vector3.new(-6, 0, 274), Vector3.new(8, 0, 276), 3.5, 2, Enum.Material.Slate, stone)
	for _ = 1, 10 do
		local s = rng:NextNumber(2, 5)
		makeRock(
			ruins,
			Vector3.new(rng:NextNumber(-40, 40), s / 3, rng:NextNumber(220, 295)),
			Vector3.new(s, s * 0.7, s),
			rng
		)
	end

	-- Tall grass patches to hide in.
	makeGrassPatch(ruins, Vector3.new(-20, 0.4, 232), Vector2.new(10, 10), rng)
	makeGrassPatch(ruins, Vector3.new(22, 0.4, 250), Vector2.new(10, 12), rng)
	makeGrassPatch(ruins, Vector3.new(-18, 0.4, 266), Vector2.new(12, 10), rng)
	makeGrassPatch(ruins, Vector3.new(4, 0.4, 286), Vector2.new(14, 8), rng)
	makeGrassPatch(ruins, Vector3.new(-38, 0.4, 290), Vector2.new(8, 8), rng)

	makePickup(ruins, "Bandage", "Bandage", Vector3.new(-38, 1, 222), Color3.fromRGB(230, 225, 210))

	-- A dormant Corrupted Soldier slumped against a pillar (a warning of
	-- what the Rift does to people; it wakes up in a later milestone).
	makeCharacterSpot(ruins, "CorruptedSoldier", Vector3.new(-27.2, 0.4, 258), Vector3.new(0, 0.4, 262), "Any")
	local soldierReader = makePart(ruins, {
		Name = "SoldierReader",
		Size = Vector3.new(4, 5, 4),
		Position = Vector3.new(-25.5, 2.5, 258),
		Transparency = 1,
		CanCollide = false,
	})
	soldierReader:SetAttribute("NoteId", "Soldier")
	makePrompt(soldierReader, "Examine", "Fallen soldier")
	CollectionService:AddTag(soldierReader, "Note")

	-- Stalker patrol route (invisible markers, visited in order).
	local patrol = {
		Vector3.new(0, 3, 230),
		Vector3.new(-25, 3, 240),
		Vector3.new(-25, 3, 275),
		Vector3.new(0, 3, 292),
		Vector3.new(25, 3, 275),
		Vector3.new(25, 3, 240),
	}
	for i, pos in patrol do
		local marker = makeZone(ruins, "PatrolPoint" .. i, CFrame.new(pos), Vector3.new(1, 1, 1), "StalkerPatrol")
		marker:SetAttribute("Order", i)
	end
	makeZone(ruins, "StalkerSpawn", CFrame.new(0, 4, 292), Vector3.new(1, 1, 1), "StalkerSpawn")
	makeStoryTrigger(ruins, "Ruins", CFrame.new(0, 4, 214), Vector3.new(100, 8, 8))
end

local function buildTemple(level: Folder)
	local temple = Instance.new("Folder")
	temple.Name = "Temple"
	temple.Parent = level

	local stone = Color3.fromRGB(84, 82, 76)
	local mat = Enum.Material.Slate
	local height = 22

	makePart(temple, {
		Name = "TempleFloor",
		Size = Vector3.new(50, 0.4, 60),
		Position = Vector3.new(0, 0.2, 330),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(64, 62, 58),
	})
	makePart(temple, {
		Name = "Roof",
		Size = Vector3.new(54, 3, 64),
		Position = Vector3.new(0, height + 1.5, 330),
		Material = mat,
		Color = stone,
	})
	-- Stepped upper tiers make the temple read as an ancient ziggurat, with
	-- roots and moss pouring over it.
	for i, size in { Vector3.new(46, 6, 52), Vector3.new(34, 6, 40), Vector3.new(20, 5, 26) } do
		local tier = makePart(temple, {
			Name = "Tier" .. i,
			Size = size,
			Position = Vector3.new(0, height + 3 + (i - 0.5) * 6 - (if i == 3 then 0.5 else 0), 332),
			Material = mat,
			Color = stone,
		})
		SceneryKit.MossCap(temple, tier)
	end
	local rootRng = Random.new(42)
	for _, x in { -22, -12, 12, 22 } do
		SceneryKit.DrapeRoots(temple, Vector3.new(x, height + 2, 299), 0.4, 2, rootRng)
	end

	-- Side walls.
	makePart(temple, {
		Name = "WallWest",
		Size = Vector3.new(3, height, 60),
		Position = Vector3.new(-26.5, height / 2, 330),
		Material = mat,
		Color = stone,
	})
	makePart(temple, {
		Name = "WallEast",
		Size = Vector3.new(3, height, 60),
		Position = Vector3.new(26.5, height / 2, 330),
		Material = mat,
		Color = stone,
	})
	-- Front wall with an 8-wide doorway at X = 0.
	makePart(temple, {
		Name = "FrontLeft",
		Size = Vector3.new(24, height, 3),
		Position = Vector3.new(-16, height / 2, 300),
		Material = mat,
		Color = stone,
	})
	makePart(temple, {
		Name = "FrontRight",
		Size = Vector3.new(24, height, 3),
		Position = Vector3.new(16, height / 2, 300),
		Material = mat,
		Color = stone,
	})
	makePart(temple, {
		Name = "FrontLintel",
		Size = Vector3.new(8, height - 12, 3),
		Position = Vector3.new(0, 12 + (height - 12) / 2, 300),
		Material = mat,
		Color = stone,
	})
	-- Back wall with a 10-wide sealed door at X = 0.
	makePart(temple, {
		Name = "BackLeft",
		Size = Vector3.new(23, height, 3),
		Position = Vector3.new(-16.5, height / 2, 360),
		Material = mat,
		Color = stone,
	})
	makePart(temple, {
		Name = "BackRight",
		Size = Vector3.new(23, height, 3),
		Position = Vector3.new(16.5, height / 2, 360),
		Material = mat,
		Color = stone,
	})
	makePart(temple, {
		Name = "BackLintel",
		Size = Vector3.new(10, height - 14, 3),
		Position = Vector3.new(0, 14 + (height - 14) / 2, 360),
		Material = mat,
		Color = stone,
	})

	local gate = makePart(temple, {
		Name = "SealedDoor",
		Size = Vector3.new(10, 14, 2),
		Position = Vector3.new(0, 7, 359.5),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(50, 46, 60),
	})
	gate:SetAttribute("ClosedPosition", gate.Position)
	CollectionService:AddTag(gate, "PuzzleGate")
	addSurfaceText(gate, Enum.NormalId.Front, "◆", Color3.fromRGB(150, 90, 220))

	-- The mural above the door: shows EYE ? SUN (the journal fills the gap).
	local mural = makePart(temple, {
		Name = "Mural",
		Size = Vector3.new(18, 5, 0.4),
		Position = Vector3.new(0, 17, 358.3),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(110, 104, 92),
	})
	addSurfaceText(mural, Enum.NormalId.Front, "EYE     ?     SUN", Color3.fromRGB(230, 200, 140))
	local muralReader = makePart(temple, {
		Name = "MuralReader",
		Size = Vector3.new(4, 4, 1),
		Position = Vector3.new(-9, 3, 357),
		Transparency = 1,
		CanCollide = false,
	})
	muralReader:SetAttribute("NoteId", "Mural")
	makePrompt(muralReader, "Examine", "Temple mural")
	CollectionService:AddTag(muralReader, "Note")

	-- Three dials in front of the door.
	for i, x in { -8, 0, 8 } do
		local dial = makePart(temple, {
			Name = "Dial" .. i,
			Size = Vector3.new(4, 6, 4),
			Position = Vector3.new(x, 3, 346),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(100, 96, 88),
		})
		dial:SetAttribute("DialIndex", i)
		local face = makePart(temple, {
			Name = "DialFace" .. i,
			Size = Vector3.new(3.4, 2.4, 0.2),
			Position = Vector3.new(x, 4.4, 343.9),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(40, 38, 36),
			CanCollide = false,
		})
		local label = addSurfaceText(face, Enum.NormalId.Front, "?", Color3.new(1, 1, 1))
		label.Name = "SymbolLabel"
		face:SetAttribute("DialIndex", i)
		CollectionService:AddTag(face, "PuzzleDialFace")
		addLight(face, Color3.fromRGB(200, 170, 120), 6, 0.5)
		makePrompt(dial, "Turn", "Stone dial " .. i)
		CollectionService:AddTag(dial, "PuzzleDial")
	end

	-- Torches flanking the door give just enough light to read the dials.
	for _, x in { -11, 11 } do
		local torch = makePart(temple, {
			Name = "Torch",
			Size = Vector3.new(0.6, 1.4, 0.6),
			Position = Vector3.new(x, 8, 357.8),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 150, 70),
			CanCollide = false,
		})
		addLight(torch, Color3.fromRGB(255, 140, 60), 18, 1.4)
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = torch
	end

	-- Side altar with optional evidence (the Rift Shard) and a torn page.
	local altar = makePart(temple, {
		Name = "Altar",
		Size = Vector3.new(5, 3, 3),
		Position = Vector3.new(-20, 1.5, 330),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(70, 66, 80),
	})
	makePickup(
		temple,
		"RiftShard",
		"Rift Shard",
		altar.Position + Vector3.new(0.8, 2.2, 0),
		Color3.fromRGB(190, 110, 255)
	)
	makeNote(temple, "Recording", "Torn page", altar.Position + Vector3.new(-1.2, 1.6, 0))
	makePickup(temple, "Battery", "Battery", Vector3.new(20, 1, 318), Color3.fromRGB(120, 200, 255))

	makeStoryTrigger(temple, "Temple", CFrame.new(0, 4, 308), Vector3.new(46, 8, 8))
	makeCharacterSpot(temple, "Lira", Vector3.new(-14, 0.4, 322), Vector3.new(0, 0.4, 308), "Explore")
	-- Gate checkpoint is only unlocked once the puzzle is solved (see PuzzleService).
	makeCheckpoint(temple, "Temple", 2, Vector3.new(0, 0.4, 306))
	local escapeCheckpoint =
		makeZone(temple, "EscapeCheckpointSpawn", CFrame.new(0, 3.5, 352), Vector3.new(1, 1, 1), "EscapeSpawn")
	escapeCheckpoint:SetAttribute("SpawnPosition", Vector3.new(0, 3.5, 352))
	makeZone(temple, "StalkerHuntSpawn", CFrame.new(0, 4, 296), Vector3.new(1, 1, 1), "StalkerHuntSpawn")
end

local function buildEscape(level: Folder, rng: Random)
	local escape = Instance.new("Folder")
	escape.Name = "Escape"
	escape.Parent = level

	local rock = Color3.fromRGB(62, 58, 56)
	local mat = Enum.Material.Rock
	-- Tunnel from Z 361 to Z 430, 14 wide, 16 tall.
	makePart(escape, {
		Name = "TunnelFloor",
		Size = Vector3.new(16, 1, 70),
		Position = Vector3.new(0, -0.3, 396),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(60, 52, 44),
	})
	makePart(escape, {
		Name = "TunnelWestWall",
		Size = Vector3.new(4, 16, 70),
		Position = Vector3.new(-9, 8, 396),
		Material = mat,
		Color = rock,
	})
	makePart(escape, {
		Name = "TunnelEastWall",
		Size = Vector3.new(4, 16, 70),
		Position = Vector3.new(9, 8, 396),
		Material = mat,
		Color = rock,
	})
	makePart(escape, {
		Name = "TunnelRoof",
		Size = Vector3.new(22, 4, 70),
		Position = Vector3.new(0, 18, 396),
		Material = mat,
		Color = rock,
	})
	-- A few support beams and fallen stones to weave around.
	for z = 372, 424, 13 do
		makePart(escape, {
			Name = "Beam",
			Size = Vector3.new(14, 1, 1),
			Position = Vector3.new(0, 14, z),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 52, 38),
		})
	end
	makeRock(escape, Vector3.new(-4, 1, 385), Vector3.new(4, 3, 5), rng)
	makeRock(escape, Vector3.new(4, 1, 405), Vector3.new(4, 3, 5), rng)
	makeRock(escape, Vector3.new(-3, 1, 420), Vector3.new(3, 2.5, 4), rng)
	-- Emergency glow strips so the route stays readable at full sprint.
	for z = 366, 428, 8 do
		local strip = makePart(escape, {
			Name = "GuideLight",
			Size = Vector3.new(0.4, 0.4, 2),
			Position = Vector3.new(-6.8, 0.4, z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 120, 60),
			CanCollide = false,
		})
		addLight(strip, Color3.fromRGB(255, 110, 50), 10, 0.8)
	end

	makeZone(escape, "EscapeZone", CFrame.new(0, 8, 400), Vector3.new(18, 16, 80), "EscapeZone")

	-- Cliff area beyond the tunnel.
	local cliffColor = Color3.fromRGB(78, 74, 70)
	makePart(escape, {
		Name = "CliffBaseFloor",
		Size = Vector3.new(30, 1, 16),
		Position = Vector3.new(0, -0.3, 438),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(60, 52, 44),
	})
	makePart(escape, {
		Name = "CliffSideWest",
		Size = Vector3.new(4, 40, 38),
		Position = Vector3.new(-15, 20, 442),
		Material = mat,
		Color = cliffColor,
	})
	makePart(escape, {
		Name = "CliffSideEast",
		Size = Vector3.new(4, 40, 38),
		Position = Vector3.new(15, 20, 442),
		Material = mat,
		Color = cliffColor,
	})
	makePart(escape, {
		Name = "Cliff",
		Size = Vector3.new(26, 24, 15),
		Position = Vector3.new(0, 12, 453.5),
		Material = mat,
		Color = cliffColor,
	})
	-- Seal the slots between the tunnel mouth and the cliff sides.
	makeWall(
		escape,
		Vector3.new(-17, 0, 430),
		Vector3.new(-9, 0, 430),
		30,
		2,
		Enum.Material.SmoothPlastic,
		Color3.new(),
		1
	)
	makeWall(
		escape,
		Vector3.new(9, 0, 430),
		Vector3.new(17, 0, 430),
		30,
		2,
		Enum.Material.SmoothPlastic,
		Color3.new(),
		1
	)
	-- Climbable truss ladder up the cliff face (Roblox characters climb trusses natively).
	local truss = Instance.new("TrussPart")
	truss.Name = "ClimbTruss"
	truss.Anchored = true
	truss.Size = Vector3.new(2, 26, 2)
	truss.Position = Vector3.new(0, 13, 445)
	truss.Material = Enum.Material.Wood
	truss.Color = Color3.fromRGB(96, 74, 52)
	truss.Parent = escape
	addLight(truss, Color3.fromRGB(255, 200, 140), 10, 0.6)

	makeStoryTrigger(escape, "Bridge", CFrame.new(0, 28, 456), Vector3.new(22, 8, 6))

	-- Rope bridge over the chasm (Z 461 to 510) at the cliff top height.
	local deckY = 24
	local plankCount = 0
	for z = 462, 509, 2 do
		plankCount += 1
		local plank = makePart(escape, {
			Name = "Plank" .. plankCount,
			Size = Vector3.new(7, 0.6, 1.8),
			CFrame = CFrame.new(0, deckY - 0.3, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-2, 2))),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(110, 84, 56),
		})
		plank:SetAttribute("HomeCFrame", plank.CFrame)
		CollectionService:AddTag(plank, "BridgePlank")
	end
	for _, x in { -3.6, 3.6 } do
		makePart(escape, {
			Name = "Rope",
			Size = Vector3.new(0.3, 0.3, 50),
			Position = Vector3.new(x, deckY + 2.5, 485.5),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(150, 130, 90),
		})
		-- Invisible rails stop accidental side falls (fairness over realism).
		makePart(escape, {
			Name = "SafetyRail",
			Size = Vector3.new(0.5, 6, 50),
			Position = Vector3.new(x * 1.05, deckY + 3, 485.5),
			Transparency = 1,
		})
	end

	-- Far landing with the rescue flare.
	makePart(escape, {
		Name = "FarLedge",
		Size = Vector3.new(30, 24, 37),
		Position = Vector3.new(0, 12, 527.5),
		Material = mat,
		Color = cliffColor,
	})
	local flare = makePart(escape, {
		Name = "RescueFlare",
		Size = Vector3.new(0.6, 3, 0.6),
		Position = Vector3.new(0, deckY + 1.5, 532),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 60, 60),
		CanCollide = false,
	})
	addLight(flare, Color3.fromRGB(255, 60, 60), 40, 3)
	local sparks = Instance.new("Fire")
	sparks.Color = Color3.fromRGB(255, 80, 60)
	sparks.SecondaryColor = Color3.fromRGB(255, 200, 120)
	sparks.Size = 3
	sparks.Parent = flare
	makeZone(escape, "EndZone", CFrame.new(0, deckY + 4, 528), Vector3.new(26, 8, 24), "EndZone")
	-- Kade and Lira wait at the flare once the escape begins.
	makeCharacterSpot(escape, "Kade", Vector3.new(-5, deckY, 524), Vector3.new(0, deckY, 505), "Escape")
	makeCharacterSpot(escape, "Lira", Vector3.new(5, deckY, 524), Vector3.new(0, deckY, 505), "Escape")

	-- Invisible walls around the cliff top and far ledge.
	local clear = Color3.new(0, 0, 0)
	makeWall(
		escape,
		Vector3.new(-14, deckY, 446),
		Vector3.new(-14, deckY, 461),
		20,
		1,
		Enum.Material.SmoothPlastic,
		clear,
		1
	)
	makeWall(
		escape,
		Vector3.new(14, deckY, 446),
		Vector3.new(14, deckY, 461),
		20,
		1,
		Enum.Material.SmoothPlastic,
		clear,
		1
	)
	makeWall(
		escape,
		Vector3.new(-15, deckY, 510),
		Vector3.new(-15, deckY, 546),
		20,
		1,
		Enum.Material.SmoothPlastic,
		clear,
		1
	)
	makeWall(
		escape,
		Vector3.new(15, deckY, 510),
		Vector3.new(15, deckY, 546),
		20,
		1,
		Enum.Material.SmoothPlastic,
		clear,
		1
	)
	makeWall(
		escape,
		Vector3.new(-15, deckY, 546),
		Vector3.new(15, deckY, 546),
		20,
		1,
		Enum.Material.SmoothPlastic,
		clear,
		1
	)

	-- Dark mist far below the bridge (falling in is fatal; see KillHeight).
	makePart(escape, {
		Name = "ChasmMist",
		Size = Vector3.new(80, 1, 60),
		Position = Vector3.new(0, -30, 486),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(10, 6, 14),
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Smooth terrain for the valley floor: real grass that sways, mud on the
-- trail and in the camp, plain ground under the paved and indoor areas.
-- Returns the terrain only on the build that should fill static shapes.
local function buildTerrain(): Terrain?
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	SceneryKit.Terrain = terrain
	if not terrain or terrainFilled then
		return nil
	end
	terrainFilled = true
	SceneryKit.FillValley(terrain, Random.new(7))
	for z = -10, 205, 6 do
		SceneryKit.PaintGround(terrain, Vector3.new(trailCenterX(z), 0, z), Vector2.new(8, 6), Enum.Material.Mud)
	end
	-- No grass blades poking through the courtyard, temple or tunnel floors.
	for _, area in { { 0, 257, 92, 88 }, { 0, 330, 54, 64 }, { 0, 400, 32, 92 } } do
		SceneryKit.PaintGround(
			terrain,
			Vector3.new(area[1], 0, area[2]),
			Vector2.new(area[3], area[4]),
			Enum.Material.Ground
		)
	end
	return terrain
end

-- Cliffs on both sides of the valley and the mountain to the north. All of
-- it is outside the playable area. Uses its own random seed so cliff-top
-- trees match the rock on every rebuild.
local function buildBackdrop(level: Folder, terrain: Terrain?)
	local rng = Random.new(99)
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	backdrop.Parent = level
	SceneryKit.CliffLine(backdrop, Vector3.new(-88, 0, -70), Vector3.new(-80, 0, 600), rng, terrain)
	SceneryKit.CliffLine(backdrop, Vector3.new(84, 0, -70), Vector3.new(92, 0, 600), rng, terrain)
	SceneryKit.CliffLine(backdrop, Vector3.new(-90, 0, -48), Vector3.new(90, 0, -48), rng, terrain)
	SceneryKit.Mountain(backdrop, Vector3.new(10, 0, 680), terrain)
end

------------------------------------------------------------------------------
-- Lighting
------------------------------------------------------------------------------

function LevelBuilder.SetupLighting()
	local L = Config.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = L.FogDensity
	atmosphere.Offset = L.AtmosphereOffset
	atmosphere.Color = Color3.fromRGB(80, 94, 96)
	atmosphere.Decay = Color3.fromRGB(46, 54, 62)
	atmosphere.Glare = 0
	atmosphere.Haze = L.FogHaze
	atmosphere.Parent = Lighting

	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.Saturation = L.Saturation
	grade.Contrast = L.Contrast
	grade.Brightness = 0.03
	grade.TintColor = L.Tint
	grade.Parent = Lighting

	-- Modern post-processing: soft glow on torches, headlights and neon,
	-- and a gentle depth haze on far scenery.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold
	bloom.Parent = Lighting
	local depth = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.18
	depth.FocusDistance = 30
	depth.InFocusRadius = 60
	depth.NearIntensity = 0
	depth.Parent = Lighting

	-- Storm sky: no moon or stars behind the clouds.
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.85
		clouds.Density = 0.7
		clouds.Color = Color3.fromRGB(70, 78, 84)
		clouds.Parent = terrain
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Builds (or rebuilds) the level. The fixed random seed means every build
-- produces the same jungle layout.
function LevelBuilder.Build(): Folder
	if currentLevel then
		currentLevel:Destroy()
		currentLevel = nil
	end
	local rng = Random.new(1337)
	local level = Instance.new("Folder")
	level.Name = LEVEL_NAME
	local freshTerrain = buildTerrain()

	buildGroundAndBounds(level)
	buildJungle(level, rng)
	buildCrashSite(level, rng)
	buildTrail(level)
	buildCamp(level, rng)
	buildRuins(level, rng)
	buildTemple(level)
	buildEscape(level, rng)
	buildBackdrop(level, freshTerrain)

	-- Parent last: one replication burst instead of thousands of small ones.
	level.Parent = workspace
	currentLevel = level
	return level
end

-- Spawns a loose item pickup in the current level (used for dropped items).
function LevelBuilder.SpawnPickup(itemId: string, displayName: string, position: Vector3, color: Color3)
	local level = currentLevel
	if not level then
		return
	end
	local folder = level:FindFirstChild("Dropped")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Dropped"
		folder.Parent = level
	end
	makePickup(folder :: Instance, itemId, displayName, position, color)
end

function LevelBuilder.GetStartPosition(): Vector3
	return Vector3.new(0, 3.5, 2)
end

return LevelBuilder
