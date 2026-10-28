--!strict
-- Chapter2Builder: builds Chapter 2, the Blackstone Research Facility, far
-- north of the jungle (around Z 1400 to 1545). It is all indoors: a
-- partially powered research complex lit by red emergency lights.
--
-- Layout (top-down, players move toward +Z):
--   Airlock      x -8..8,    z 1400..1414   start, checkpoint
--   Lobby        x -22..22,  z 1414..1446   reception, security log
--     east  ->   Storage     x 22..36,   z 1420..1442   fuse #1, whiteboard clue
--     west  ->   Maintenance tunnel x -60..-22, z 1419..1427  fuse #2 (low, pipes)
--                Generator room     x -80..-60, z 1412..1450  power puzzle
--     north ->   Security door (opens when the power is back)
--   Corridor     x -6..6,    z 1446..1530
--     east  ->   Lab 1       x 6..32,    z 1462..1488   supplies, research log
--     west  ->   Lab 2       x -32..-6,  z 1494..1520   cryo tubes, where it breaks out
--   Elevator     x -6..6,    z 1530..1542   call it (needs power) to finish
--
-- Gameplay pieces are tagged so Chapter2Service can find them after any
-- rebuild. Props come from ServerStorage > RiftfallAssets > Facility when
-- a model exists there; otherwise a plain stand-in block is used.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Chapter2Builder = {}

Chapter2Builder.Origin = Vector3.new(0, 0, 1400)
Chapter2Builder.StartPosition = Vector3.new(0, 3.5, 1404)

export type Kit = {
	makePart: (Instance, { [string]: any }) -> Part,
	makeZone: (Instance, string, CFrame, Vector3, string) -> Part,
	makePrompt: (Instance, string, string, number?) -> ProximityPrompt,
	addLight: (Instance, Color3, number, number, boolean?) -> PointLight,
	addSurfaceText: (BasePart, Enum.NormalId, string, Color3) -> TextLabel,
	makePickup: (Instance, string, string, Vector3, Color3) -> (),
	makeNote: (Instance, string, string, Vector3) -> (),
	makeCheckpoint: (Instance, string, number, Vector3) -> (),
	makeStoryTrigger: (Instance, string, CFrame, Vector3) -> (),
}

local WALL = Color3.fromRGB(92, 96, 100)
local WALL_DARK = Color3.fromRGB(58, 62, 66)
local FLOOR = Color3.fromRGB(70, 72, 74)
local TRIM = Color3.fromRGB(150, 120, 40)
local EMERGENCY = Color3.fromRGB(255, 40, 30)
local MAIN_LIGHT = Color3.fromRGB(220, 235, 255)

local HEIGHT = 12

local kit: Kit
local folder: Folder

local function part(props: { [string]: any }): Part
	return kit.makePart(folder, props)
end

-- A straight wall from (x1, z1) to (x2, z2) with optional door gaps, each
-- gap given as { from, to } along the wall's length.
local function wall(x1: number, z1: number, x2: number, z2: number, height: number?, gaps: { { number } }?)
	local h = height or HEIGHT
	local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local cuts = { { 0, 0 } }
	for _, gap in gaps or {} do
		table.insert(cuts, gap)
	end
	table.insert(cuts, { length, length })
	table.sort(cuts, function(p, q)
		return p[1] < q[1]
	end)
	for i = 1, #cuts - 1 do
		local from, to = cuts[i][2], cuts[i + 1][1]
		if to - from > 0.05 then
			local mid = a + dir * ((from + to) / 2)
			part({
				Name = "Wall",
				Size = Vector3.new(1, h, to - from),
				CFrame = CFrame.lookAt(mid + Vector3.new(0, h / 2, 0), mid + dir + Vector3.new(0, h / 2, 0)),
				Material = Enum.Material.Concrete,
				Color = WALL,
			})
		end
	end
	-- Lintel over each door gap.
	for _, gap in gaps or {} do
		local mid = a + dir * ((gap[1] + gap[2]) / 2)
		local doorTop = 9
		if h > doorTop then
			part({
				Name = "Lintel",
				Size = Vector3.new(1, h - doorTop, gap[2] - gap[1]),
				CFrame = CFrame.lookAt(
					mid + Vector3.new(0, doorTop + (h - doorTop) / 2, 0),
					mid + dir + Vector3.new(0, doorTop + (h - doorTop) / 2, 0)
				),
				Material = Enum.Material.Concrete,
				Color = WALL_DARK,
			})
		end
	end
end

local function floorAndCeiling(name: string, x1: number, z1: number, x2: number, z2: number, height: number?)
	local h = height or HEIGHT
	local size = Vector3.new(x2 - x1, 1, z2 - z1)
	local center = Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	part({
		Name = name .. "Floor",
		Size = size,
		Position = center - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.DiamondPlate,
		Color = FLOOR,
	})
	part({
		Name = name .. "Ceiling",
		Size = size,
		Position = center + Vector3.new(0, h + 0.5, 0),
		Material = Enum.Material.Metal,
		Color = WALL_DARK,
	})
end

-- Red emergency light (always on) and a white main light (off until the
-- power is restored; tagged "FacilityLight").
local function lights(x: number, z: number, height: number?)
	local h = height or HEIGHT
	local emergency = part({
		Name = "EmergencyLight",
		Size = Vector3.new(0.8, 0.4, 0.8),
		Position = Vector3.new(x, h - 0.3, z),
		Material = Enum.Material.Neon,
		Color = EMERGENCY,
		CanCollide = false,
		CastShadow = false,
	})
	kit.addLight(emergency, EMERGENCY, 16, 0.9)
	CollectionService:AddTag(emergency, "EmergencyLight")
	local panel = part({
		Name = "CeilingLight",
		Size = Vector3.new(4, 0.25, 1.2),
		Position = Vector3.new(x + 3, h - 0.15, z),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(60, 64, 70),
		CanCollide = false,
		CastShadow = false,
	})
	local light = kit.addLight(panel, MAIN_LIGHT, 26, 1.4)
	light.Enabled = false
	CollectionService:AddTag(panel, "FacilityLight")
end

-- Places a prop from the Facility library (scaled evenly to fit inside
-- `size`), or a stand-in block of `size`.
local function prop(name: string, cframe: CFrame, size: Vector3, color: Color3?): Instance
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	local facility = library and library:FindFirstChild("Facility")
	local template = facility and facility:FindFirstChild(name)
	if template and template:IsA("BasePart") then
		local copy = template:Clone()
		copy.Name = name
		local t = copy.Size
		copy.Size = t * math.min(size.X / t.X, size.Y / t.Y, size.Z / t.Z)
		copy.Anchored = true
		copy.CanTouch = false
		copy.CFrame = cframe * CFrame.new(0, copy.Size.Y / 2, 0)
		copy.Parent = folder
		return copy
	end
	return part({
		Name = name,
		Size = size,
		CFrame = cframe * CFrame.new(0, size.Y / 2, 0),
		Material = Enum.Material.Metal,
		Color = color or Color3.fromRGB(70, 74, 80),
	})
end

local function hidingLocker(x: number, z: number, facing: number)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(facing), 0)
	prop("Locker", cf, Vector3.new(3, 7, 2.5), Color3.fromRGB(60, 80, 70))
	-- Crouch right in front of the locker to hide (same rule as tall grass).
	kit.makeZone(folder, "HidingZone", cf * CFrame.new(0, 3, -2.5), Vector3.new(5, 6, 4), "HidingSpot")
end

-- A sign whose front faces `facing` degrees (0 = toward -Z).
local function sign(position: Vector3, facing: number, text: string)
	local plate = part({
		Name = "Sign",
		Size = Vector3.new(8, 1.4, 0.2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 32, 36),
		CanCollide = false,
	})
	local label = kit.addSurfaceText(plate, Enum.NormalId.Front, text, TRIM)
	label.Font = Enum.Font.GothamBold
end

------------------------------------------------------------------------------
-- Rooms
------------------------------------------------------------------------------

local function buildAirlockAndLobby()
	-- Airlock
	floorAndCeiling("Airlock", -8, 1400, 8, 1414)
	wall(-8, 1400, 8, 1400)
	wall(-8, 1400, -8, 1414)
	wall(8, 1400, 8, 1414)
	part({
		Name = "OuterDoor",
		Size = Vector3.new(8, 9, 0.6),
		Position = Vector3.new(0, 4.5, 1400.6),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(90, 70, 40),
	})
	lights(-2, 1407)
	kit.makeCheckpoint(folder, "Facility Entrance", 10, Vector3.new(0, 0, 1407))
	sign(Vector3.new(0, 10, 1413.4), 0, "BLACKSTONE RESEARCH FACILITY")

	-- Lobby
	floorAndCeiling("Lobby", -22, 1414, 22, 1446)
	wall(-22, 1414, 22, 1414, nil, { { 18, 26 } }) -- door from the airlock
	wall(-22, 1414, -22, 1446, nil, { { 6, 12 } }) -- west: maintenance tunnel
	wall(22, 1414, 22, 1446, nil, { { 14, 20 } }) -- east: storage
	wall(-22, 1446, 22, 1446, nil, { { 18, 26 } }) -- north: security door
	lights(-12, 1424)
	lights(10, 1436)
	prop("ReceptionDesk", CFrame.new(0, 0, 1426) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(12, 3.5, 3))
	prop("BrokenMonitor", CFrame.new(-3, 3.5, 1426) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(2, 1.6, 0.4))
	kit.makeNote(folder, "C2SecurityLog", "Security log", Vector3.new(2, 3.6, 1426))
	prop("Bench", CFrame.new(-16, 0, 1440), Vector3.new(6, 2, 2))
	prop("FallenCeilingPanel", CFrame.new(12, 0, 1420) * CFrame.Angles(0, math.rad(25), math.rad(8)), Vector3.new(6, 0.6, 3))
	sign(Vector3.new(0, 10, 1445.4), 0, "LABS / ELEVATOR")
	sign(Vector3.new(-21.4, 10, 1423), -90, "MAINTENANCE")
	sign(Vector3.new(21.4, 10, 1431), 90, "STORAGE")
	kit.makeStoryTrigger(folder, "C2Lobby", CFrame.new(0, 4, 1420), Vector3.new(40, 8, 6))

	-- The security door (raised when the power comes back).
	local door = part({
		Name = "SecurityDoor",
		Size = Vector3.new(8, 9, 0.8),
		Position = Vector3.new(0, 4.5, 1446),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(110, 90, 40),
	})
	door:SetAttribute("OpenOffset", Vector3.new(0, 8.6, 0))
	CollectionService:AddTag(door, "PoweredDoor")
	local lamp = part({
		Name = "DoorLamp",
		Size = Vector3.new(0.6, 0.6, 0.3),
		Position = Vector3.new(5, 7, 1445.4),
		Material = Enum.Material.Neon,
		Color = EMERGENCY,
		CanCollide = false,
	})
	CollectionService:AddTag(lamp, "PowerLamp")
	local panel = part({
		Name = "DoorPanel",
		Size = Vector3.new(1.2, 1.6, 0.3),
		Position = Vector3.new(5, 4.5, 1445.4),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 44, 50),
	})
	CollectionService:AddTag(panel, "LockedDoorPanel")
	kit.makePrompt(panel, "Open", "Security door")
end

local function buildStorage()
	floorAndCeiling("Storage", 22, 1420, 36, 1442)
	wall(22, 1420, 36, 1420)
	wall(36, 1420, 36, 1442)
	wall(22, 1442, 36, 1442)
	lights(29, 1431)
	for i, z in { 1424, 1430, 1436 } do
		prop("ShelfUnit", CFrame.new(34.5, 0, z) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(5, 8, 2))
		if i == 2 then
			kit.makePickup(folder, "Fuse", "Fuse", Vector3.new(33.8, 4.6, z), Color3.fromRGB(255, 200, 60))
		end
	end
	prop("SupplyCrate", CFrame.new(26, 0, 1438), Vector3.new(3, 2.4, 3))
	kit.makePickup(folder, "Battery", "Battery", Vector3.new(26, 3.1, 1438), Color3.fromRGB(120, 200, 255))
	-- The whiteboard with the breaker clue.
	local board = part({
		Name = "Whiteboard",
		Size = Vector3.new(6, 3.5, 0.2),
		Position = Vector3.new(29, 5.5, 1441.4),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(225, 228, 230),
	})
	local text = kit.addSurfaceText(board, Enum.NormalId.Front, "LOAD TEST\nA: ON   B: OFF   C: ON\nB shorts the corridor!", Color3.fromRGB(30, 60, 160))
	text.Font = Enum.Font.PermanentMarker
	text.TextStrokeTransparency = 1
	-- Turn the board so its front face (with the writing) faces into the room.
	board.CFrame = CFrame.lookAt(board.Position, board.Position + Vector3.new(0, 0, -1))
	kit.makeNote(folder, "C2Whiteboard", "Whiteboard", Vector3.new(29, 3.2, 1440))
end

local function buildTunnelAndGenerator()
	-- Maintenance tunnel: low, cramped, pipes overhead.
	local h = 8
	floorAndCeiling("Tunnel", -60, 1419, -22, 1427, h)
	wall(-60, 1419, -22, 1419, h)
	wall(-60, 1427, -22, 1427, h)
	for x = -56, -26, 6 do
		part({
			Name = "Pipe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6.2, 0.8, 0.8),
			Position = Vector3.new(x, h - 1.2, 1420.4),
			Material = Enum.Material.CorrodedMetal,
			Color = Color3.fromRGB(110, 80, 60),
			CanCollide = false,
		})
		local drip = part({
			Name = "TunnelLight",
			Size = Vector3.new(0.5, 0.5, 0.5),
			Position = Vector3.new(x, h - 0.4, 1426.2),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 150, 60),
			CanCollide = false,
			CastShadow = false,
		})
		if x % 12 == 4 then
			kit.addLight(drip, Color3.fromRGB(255, 140, 60), 10, 0.6)
		end
	end
	prop("SupplyCrate", CFrame.new(-48, 0, 1425) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(2.6, 2.2, 2.6))
	kit.makePickup(folder, "Fuse", "Fuse", Vector3.new(-48, 2.9, 1425), Color3.fromRGB(255, 200, 60))
	kit.makeStoryTrigger(folder, "C2Tunnel", CFrame.new(-30, 4, 1423), Vector3.new(6, 8, 8))

	-- Generator room
	floorAndCeiling("Generator", -80, 1412, -60, 1450)
	wall(-80, 1412, -60, 1412)
	wall(-80, 1412, -80, 1450)
	wall(-80, 1450, -60, 1450)
	wall(-60, 1412, -60, 1450, nil, { { 7, 15 } })
	-- The tunnel is lower than the rooms: fill the wall above its opening.
	part({
		Name = "TunnelHeader",
		Size = Vector3.new(1, HEIGHT - 8, 8),
		Position = Vector3.new(-60, 8 + (HEIGHT - 8) / 2, 1423),
		Material = Enum.Material.Concrete,
		Color = WALL_DARK,
	})
	part({
		Name = "TunnelHeader",
		Size = Vector3.new(1, HEIGHT - 8, 8),
		Position = Vector3.new(-22, 8 + (HEIGHT - 8) / 2, 1423),
		Material = Enum.Material.Concrete,
		Color = WALL_DARK,
	})
	lights(-74, 1420)
	lights(-74, 1442)
	prop("Generator", CFrame.new(-68, 0, 1442) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(10, 6, 6))
	kit.makeCheckpoint(folder, "Generator Room", 11, Vector3.new(-66, 0, 1418))
	kit.makeStoryTrigger(folder, "C2Generator", CFrame.new(-70, 4, 1420), Vector3.new(18, 8, 8))

	-- The power panel on the west wall: two fuse sockets, three breakers
	-- and the master lever. Players face west (-X), so higher Z is on
	-- their left: the parts run fuses, A, B, C, lever from left to right.
	local panelX = -79.2
	local back = part({
		Name = "PowerPanel",
		Size = Vector3.new(0.4, 6, 17.5),
		Position = Vector3.new(panelX, 4.5, 1429.75),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 56, 60),
	})
	back.CanCollide = true
	for i, z in { 1437, 1434.5 } do
		local socket = part({
			Name = "FuseSocket" .. i,
			Size = Vector3.new(0.4, 1.2, 1),
			Position = Vector3.new(panelX + 0.4, 6, z),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(25, 25, 25),
		})
		socket:SetAttribute("SocketIndex", i)
		CollectionService:AddTag(socket, "FuseSocket")
		kit.makePrompt(socket, "Insert fuse", "Fuse socket " .. i)
	end
	for i, z in { 1431.5, 1429, 1426.5 } do
		local breaker = part({
			Name = "Breaker" .. i,
			Size = Vector3.new(0.5, 1.4, 1),
			Position = Vector3.new(panelX + 0.45, 4.2, z),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(150, 40, 40),
		})
		breaker:SetAttribute("BreakerIndex", i)
		CollectionService:AddTag(breaker, "Breaker")
		local label = kit.addSurfaceText(breaker, Enum.NormalId.Right, "", Color3.new(1, 1, 1))
		label.Name = "State"
		label.Font = Enum.Font.GothamBold
		kit.makePrompt(breaker, "Flip", "Breaker " .. string.char(64 + i))
	end
	local lever = part({
		Name = "MasterLever",
		Size = Vector3.new(0.6, 2.4, 0.6),
		Position = Vector3.new(panelX + 0.6, 4.5, 1422.5),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(200, 60, 40),
	})
	CollectionService:AddTag(lever, "MasterLever")
	kit.makePrompt(lever, "Pull", "Master power lever", 1)
	local panelSign = part({
		Name = "PanelSign",
		Size = Vector3.new(0.1, 1.2, 17.5),
		Position = Vector3.new(panelX + 0.3, 8.1, 1429.75),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 32, 36),
		CanCollide = false,
	})
	kit.addSurfaceText(panelSign, Enum.NormalId.Right, "FUSE 1   FUSE 2   |   A   B   C   |   MASTER", TRIM).Font =
		Enum.Font.GothamBold
end

local function buildCorridorLabsElevator()
	-- Corridor
	floorAndCeiling("Corridor", -6, 1446, 6, 1530)
	wall(-6, 1446, -6, 1530, nil, { { 48, 54 } }) -- west: Lab 2
	wall(6, 1446, 6, 1530, nil, { { 24, 30 } }) -- east: Lab 1
	for z = 1452, 1524, 12 do
		lights(-3, z)
	end
	hidingLocker(4.6, 1458, -90)
	hidingLocker(-4.6, 1486, 90)
	hidingLocker(4.6, 1512, -90)
	prop("FallenCeilingPanel", CFrame.new(-2, 0, 1496) * CFrame.Angles(0, math.rad(-30), math.rad(10)), Vector3.new(5, 0.6, 3))
	kit.makeStoryTrigger(folder, "C2Corridor", CFrame.new(0, 4, 1452), Vector3.new(12, 8, 6))

	-- Lab 1 (east): supplies and the research log.
	floorAndCeiling("Lab1", 6, 1462, 32, 1488)
	wall(6, 1462, 32, 1462)
	wall(32, 1462, 32, 1488)
	wall(6, 1488, 32, 1488)
	lights(14, 1468)
	lights(24, 1480)
	for i, z in { 1466, 1474, 1482 } do
		prop("LabDesk", CFrame.new(22, 0, z), Vector3.new(8, 3.2, 3))
		if i == 2 then
			kit.makeNote(folder, "C2LabLog", "Research log", Vector3.new(21, 3.3, z))
		end
	end
	prop("ServerRack", CFrame.new(30.5, 0, 1470) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(3, 8, 2.5))
	prop("ServerRack", CFrame.new(30.5, 0, 1476) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(3, 8, 2.5))
	kit.makePickup(folder, "Bandage", "Bandage", Vector3.new(26, 3.4, 1482), Color3.fromRGB(230, 225, 210))

	-- Lab 2 (west): cryo tubes; the creature breaks out of here.
	floorAndCeiling("Lab2", -32, 1494, -6, 1520)
	wall(-32, 1494, -6, 1494)
	wall(-32, 1494, -32, 1520)
	wall(-32, 1520, -6, 1520)
	lights(-14, 1500)
	lights(-24, 1514)
	for _, z in { 1499, 1507, 1515 } do
		local tube = prop("CryoTube", CFrame.new(-29, 0, z) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(4, 8, 4))
		if tube:IsA("BasePart") then
			kit.addLight(tube, Color3.fromRGB(120, 220, 255), 10, 0.8)
		end
	end
	kit.makeNote(folder, "C2CryoLog", "Containment report", Vector3.new(-16, 3.3, 1510))
	prop("LabDesk", CFrame.new(-16, 0, 1510), Vector3.new(8, 3.2, 3))
	kit.makePickup(folder, "Flare", "Flare", Vector3.new(-12, 1, 1498), Color3.fromRGB(255, 70, 50))
	local burst = kit.makeZone(folder, "StalkerBurst", CFrame.new(-24, 4, 1516), Vector3.new(1, 1, 1), "C2StalkerSpawn")
	burst:SetAttribute("Zone", "Chapter2")

	-- Elevator
	floorAndCeiling("Elevator", -6, 1530, 6, 1542)
	wall(-6, 1530, 6, 1530, nil, { { 2, 10 } })
	wall(-6, 1530, -6, 1542)
	wall(6, 1530, 6, 1542)
	wall(-6, 1542, 6, 1542)
	local elevatorDoor = part({
		Name = "ElevatorDoor",
		Size = Vector3.new(8, 9, 0.6),
		Position = Vector3.new(0, 4.5, 1530),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 155, 160),
		Reflectance = 0.1,
	})
	elevatorDoor:SetAttribute("OpenOffset", Vector3.new(8.2, 0, 0))
	CollectionService:AddTag(elevatorDoor, "ElevatorDoor")
	local callPanel = part({
		Name = "ElevatorCall",
		Size = Vector3.new(1, 1.4, 0.3),
		Position = Vector3.new(4.8, 4.5, 1529.4),
		Material = Enum.Material.Neon,
		Color = EMERGENCY,
	})
	CollectionService:AddTag(callPanel, "ElevatorCall")
	kit.makePrompt(callPanel, "Call elevator", "Elevator", 4)
	sign(Vector3.new(0, 10, 1529.4), 0, "ELEVATOR - SURFACE ACCESS")
	lights(-2, 1536)
	kit.makeZone(folder, "C2EndZone", CFrame.new(0, 4, 1537), Vector3.new(10, 8, 8), "C2EndZone")

	-- Patrol points for the creature (Zone = Chapter2).
	for i, point in
		{
			Vector3.new(0, 3, 1458),
			Vector3.new(0, 3, 1490),
			Vector3.new(0, 3, 1522),
			Vector3.new(18, 3, 1470),
			Vector3.new(24, 3, 1484),
			Vector3.new(-18, 3, 1500),
			Vector3.new(-14, 3, 1516),
		}
	do
		local marker = kit.makeZone(folder, "C2Patrol" .. i, CFrame.new(point), Vector3.new(1, 1, 1), "StalkerPatrol")
		marker:SetAttribute("Order", i)
		marker:SetAttribute("Zone", "Chapter2")
	end
end

function Chapter2Builder.Build(level: Folder, buildKit: Kit)
	kit = buildKit
	folder = Instance.new("Folder")
	folder.Name = "Facility"
	folder.Parent = level
	buildAirlockAndLobby()
	buildStorage()
	buildTunnelAndGenerator()
	buildCorridorLabsElevator()
end

return Chapter2Builder
