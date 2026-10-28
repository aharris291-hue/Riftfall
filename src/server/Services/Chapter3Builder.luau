--!strict
-- Chapter3Builder: builds Chapter 3, the Sunken Temple, deep under the
-- mountain (around Z 1700 to 1865). An ancient Vael ruin, half flooded,
-- lit by torches and the violet glow of Rift crystal.
--
-- Layout (top-down, players move toward +Z):
--   Entrance hall    x -10..10,  z 1700..1720   start, checkpoint, mural
--   Flooded gallery  x -16..16,  z 1720..1760   stepping stones over water
--     east  ->       Hidden chamber x 16..30, z 1734..1750 (behind a cracked
--                    wall you can push): the plate order, supplies
--   Symbol chamber   x -22..22,  z 1760..1800   4 pressure plates, the
--                    creature patrols here, alcoves to hide in
--   Sanctum          x -16..16,  z 1800..1840   the Rift Heart (floor),
--                    a climbing wall up to a ledge at Y 12
--   Exit tunnel      x -4..4,    z 1840..1866   at Y 12, end of chapter
--
-- Gameplay pieces are tagged for Chapter3Service. Props come from
-- ServerStorage > RiftfallAssets > Temple when a model exists; otherwise a
-- plain stand-in block is used. Stone uses Slate, so the level dresser
-- gives it the carved temple-stone look automatically.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Chapter3Builder = {}

Chapter3Builder.StartPosition = Vector3.new(0, 3.5, 1704)

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

local STONE = Color3.fromRGB(96, 98, 90)
local STONE_DARK = Color3.fromRGB(64, 66, 60)
local MOSS = Color3.fromRGB(60, 86, 52)
local FLAME = Color3.fromRGB(255, 150, 60)
local RIFT = Color3.fromRGB(190, 90, 255)
local HEIGHT = 18

-- The four plate symbols, in the order they are laid out (west to east).
-- The correct stepping order is in Chapter3Service.
Chapter3Builder.Symbols = { "EYE", "MOON", "SERPENT", "SUN" }

local kit: Kit
local folder: Folder

local function part(props: { [string]: any }): Part
	return kit.makePart(folder, props)
end

-- Straight wall from (x1, z1) to (x2, z2) with optional door gaps along it.
local function wall(x1: number, z1: number, x2: number, z2: number, height: number?, gaps: { { number } }?, baseY: number?)
	local h = height or HEIGHT
	local y0 = baseY or 0
	local a, b = Vector3.new(x1, y0, z1), Vector3.new(x2, y0, z2)
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
				Name = "TempleWall",
				Size = Vector3.new(2, h, to - from),
				CFrame = CFrame.lookAt(mid + Vector3.new(0, h / 2, 0), mid + dir + Vector3.new(0, h / 2, 0)),
				Material = Enum.Material.Slate,
				Color = STONE,
			})
		end
	end
	for _, gap in gaps or {} do
		local mid = a + dir * ((gap[1] + gap[2]) / 2)
		local top = 10
		part({
			Name = "Lintel",
			Size = Vector3.new(2.4, h - top, gap[2] - gap[1] + 1),
			CFrame = CFrame.lookAt(
				mid + Vector3.new(0, top + (h - top) / 2, 0),
				mid + dir + Vector3.new(0, top + (h - top) / 2, 0)
			),
			Material = Enum.Material.Slate,
			Color = STONE_DARK,
		})
	end
end

local function room(name: string, x1: number, z1: number, x2: number, z2: number, floorY: number?, height: number?)
	local y = floorY or 0
	local h = height or HEIGHT
	local size = Vector3.new(x2 - x1, 1, z2 - z1)
	local center = Vector3.new((x1 + x2) / 2, y, (z1 + z2) / 2)
	part({
		Name = name .. "Floor",
		Size = size,
		Position = center - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	part({
		Name = name .. "Ceiling",
		Size = size + Vector3.new(4, 0, 4),
		Position = center + Vector3.new(0, h + 0.5, 0),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
end

local function torch(position: Vector3)
	local bracket = part({
		Name = "WallTorch",
		Size = Vector3.new(0.5, 1.6, 0.5),
		Position = position,
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 50, 36),
		CanCollide = false,
	})
	local flame = part({
		Name = "TorchFlame",
		Size = Vector3.new(0.6, 0.8, 0.6),
		Position = position + Vector3.new(0, 1.1, 0),
		Material = Enum.Material.Neon,
		Color = FLAME,
		CanCollide = false,
		CastShadow = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 130, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 80)
	fire.Parent = flame
	kit.addLight(flame, FLAME, 20, 1.3)
	return bracket
end

local function riftCrystal(position: Vector3, height: number)
	local c = part({
		Name = "RiftCrystal",
		Size = Vector3.new(height * 0.35, height, height * 0.35),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-8)),
		Material = Enum.Material.Neon,
		Color = RIFT,
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.15,
	})
	kit.addLight(c, RIFT, 12, 0.8)
end

-- A prop from the Temple library (scaled evenly to fit `size`), else a block.
local function prop(name: string, cframe: CFrame, size: Vector3, color: Color3?): Instance
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	local temple = library and library:FindFirstChild("Temple")
	local template = temple and temple:FindFirstChild(name)
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
		Material = Enum.Material.Slate,
		Color = color or STONE,
	})
end

-- A carved panel with text, readable as a note.
local function carving(position: Vector3, facing: number, noteId: string, title: string, glyphs: string)
	local slab = part({
		Name = "Carving",
		Size = Vector3.new(7, 4, 0.6),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(120, 116, 100),
	})
	local label = kit.addSurfaceText(slab, Enum.NormalId.Front, glyphs, Color3.fromRGB(210, 190, 140))
	label.Font = Enum.Font.Fantasy
	local front = slab.CFrame * CFrame.new(0, -2.6, -1.2)
	kit.makeNote(folder, noteId, title, front.Position)
end

------------------------------------------------------------------------------
-- Rooms
------------------------------------------------------------------------------

local function buildEntrance()
	room("Entrance", -10, 1700, 10, 1720)
	wall(-10, 1700, 10, 1700)
	wall(-10, 1700, -10, 1720)
	wall(10, 1700, 10, 1720)
	wall(-10, 1720, 10, 1720, nil, { { 6, 14 } })
	torch(Vector3.new(-9, 6, 1706))
	torch(Vector3.new(9, 6, 1714))
	kit.makeCheckpoint(folder, "Temple Gate", 20, Vector3.new(0, 0, 1706))
	carving(Vector3.new(-6, 5, 1700.8), 180, "C3Mural", "Vael mural", "THE SKY OPENED\nWE GAVE IT A HEART\nIT GAVE US NOTHING BACK")
	kit.makeStoryTrigger(folder, "C3Entrance", CFrame.new(0, 4, 1712), Vector3.new(18, 8, 4))
	riftCrystal(Vector3.new(7, 0, 1702), 3)
end

local function buildGallery()
	-- Pool: the floor is 6 studs down; terrain water fills it (FillTerrain).
	part({
		Name = "PoolFloor",
		Size = Vector3.new(32, 1, 40),
		Position = Vector3.new(0, -6.5, 1740),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	part({
		Name = "GalleryCeiling",
		Size = Vector3.new(36, 1, 44),
		Position = Vector3.new(0, HEIGHT + 0.5, 1740),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	wall(-16, 1720, -16, 1760, HEIGHT + 6, nil, -6)
	-- East wall, with an opening (z 1736..1742) behind the cracked slab.
	wall(16, 1720, 16, 1736, HEIGHT + 6, nil, -6)
	wall(16, 1742, 16, 1760, HEIGHT + 6, nil, -6)
	part({
		Name = "OpeningSill",
		Size = Vector3.new(2, 6, 6),
		Position = Vector3.new(16, -3, 1739),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- South wall pieces beside the narrower entrance hall.
	wall(-16, 1720, -10, 1720, HEIGHT + 6, nil, -6)
	wall(10, 1720, 16, 1720, HEIGHT + 6, nil, -6)
	-- Stepping stones (slightly zig-zag) from the entrance to the far side.
	local stones = {
		Vector3.new(0, 0, 1723),
		Vector3.new(-3, 0, 1728),
		Vector3.new(1, 0, 1733),
		Vector3.new(5, 0, 1738),
		Vector3.new(9, 0, 1742),
		Vector3.new(4, 0, 1747),
		Vector3.new(-1, 0, 1752),
		Vector3.new(0, 0, 1757),
	}
	for i, p in stones do
		part({
			Name = "SteppingStone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6.5, if i == 1 or i == #stones then 6 else 4.4, if i == 1 or i == #stones then 6 else 4.4),
			CFrame = CFrame.new(p - Vector3.new(0, 3.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(110, 112, 100),
		})
	end
	-- Ledge in front of the cracked wall (east side).
	part({
		Name = "EastLedge",
		Size = Vector3.new(6, 6.5, 8),
		Position = Vector3.new(13, -3.25, 1739),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- The cracked wall slab: push it to reveal the hidden chamber.
	local cracked = part({
		Name = "CrackedWall",
		Size = Vector3.new(2, 10, 6),
		Position = Vector3.new(16, 5, 1739),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(88, 84, 74),
	})
	cracked:SetAttribute("OpenOffset", Vector3.new(4, -10.2, 0))
	CollectionService:AddTag(cracked, "CrackedWall")
	kit.makePrompt(cracked, "Push", "Cracked wall", 1.5)
	for _, p in { Vector3.new(-14, 7, 1726), Vector3.new(-14, 7, 1752), Vector3.new(14, 7, 1730) } do
		torch(p)
	end
	riftCrystal(Vector3.new(-12, -6, 1744), 5)
	prop("Statue", CFrame.new(-12, 0, 1757) * CFrame.Angles(0, math.rad(150), 0), Vector3.new(4, 9, 4))
	kit.makeStoryTrigger(folder, "C3Gallery", CFrame.new(0, 3, 1726), Vector3.new(28, 8, 4))
end

local function buildHiddenChamber()
	room("Hidden", 16, 1734, 30, 1750, 0, 10)
	wall(16, 1734, 30, 1734, 10)
	wall(30, 1734, 30, 1750, 10)
	wall(16, 1750, 30, 1750, 10)
	-- The gallery wall above the cracked slab.
	part({
		Name = "HiddenHeader",
		Size = Vector3.new(2, HEIGHT - 10 + 6, 6),
		Position = Vector3.new(16, 10 + (HEIGHT - 10) / 2 + 3, 1739),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	torch(Vector3.new(29, 5, 1742))
	carving(Vector3.new(29.2, 5, 1745), -90, "C3Tablet", "The order of the plates", "FIRST THE EYE THAT WATCHES\nTHEN THE SERPENT THAT WAITS\nTHE MOON THAT HIDES\nLAST THE SUN THAT SLEEPS")
	kit.makePickup(folder, "Battery", "Battery", Vector3.new(20, 1, 1747), Color3.fromRGB(120, 200, 255))
	kit.makePickup(folder, "Bandage", "Bandage", Vector3.new(22, 1, 1737), Color3.fromRGB(230, 225, 210))
	kit.makeNote(folder, "C3Rourke", "Rourke's last page", Vector3.new(25, 0.6, 1736))
end

local function buildSymbolChamber()
	room("Symbol", -22, 1760, 22, 1800)
	wall(-22, 1760, -16, 1760)
	wall(16, 1760, 22, 1760)
	wall(-22, 1760, -22, 1800)
	wall(22, 1760, 22, 1800)
	wall(-22, 1800, 22, 1800, nil, { { 18, 26 } })
	-- The south wall above the gallery opening.
	part({
		Name = "GalleryArchTop",
		Size = Vector3.new(32, 4, 2),
		Position = Vector3.new(0, HEIGHT - 2, 1760),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	part({
		Name = "Landing",
		Size = Vector3.new(32, 1, 4),
		Position = Vector3.new(0, -0.5, 1758),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	-- Pressure plates in a row, each a raised slab carved with its symbol.
	for i, symbol in Chapter3Builder.Symbols do
		local x = -12 + (i - 1) * 8
		local plate = part({
			Name = "Plate" .. i,
			Size = Vector3.new(5, 0.4, 5),
			Position = Vector3.new(x, 0.2, 1782),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(130, 124, 104),
		})
		plate:SetAttribute("Symbol", symbol)
		plate:SetAttribute("PlateIndex", i)
		CollectionService:AddTag(plate, "PressurePlate")
		local label = kit.addSurfaceText(plate, Enum.NormalId.Top, symbol, Color3.fromRGB(230, 200, 120))
		label.Font = Enum.Font.Fantasy
		kit.makeZone(folder, "PlateZone" .. i, CFrame.new(x, 2.5, 1782), Vector3.new(4.6, 5, 4.6), "PlateZone"):SetAttribute(
			"PlateIndex",
			i
		)
	end
	-- Dart holes in the side walls (the trap's visible tell).
	for _, z in { 1776, 1782, 1788 } do
		for _, x in { -20.9, 20.9 } do
			local hole = part({
				Name = "DartHole",
				Size = Vector3.new(0.3, 0.6, 0.6),
				Position = Vector3.new(x, 3, z),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(40, 20, 20),
				CanCollide = false,
			})
			CollectionService:AddTag(hole, "DartHole")
		end
	end
	-- Sealed gate to the sanctum.
	local gate = part({
		Name = "SanctumGate",
		Size = Vector3.new(8, 10, 1.2),
		Position = Vector3.new(0, 5, 1800),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(80, 76, 66),
	})
	gate:SetAttribute("OpenOffset", Vector3.new(0, -10.4, 0))
	CollectionService:AddTag(gate, "SanctumGate")
	kit.addSurfaceText(gate, Enum.NormalId.Front, "EYE  .  ?  .  ?  .  SUN", Color3.fromRGB(210, 190, 140)).Font =
		Enum.Font.Fantasy
	-- Alcoves to hide in (crouch inside).
	for _, spot in { Vector3.new(-19, 0, 1768), Vector3.new(19, 0, 1768), Vector3.new(-19, 0, 1794), Vector3.new(19, 0, 1794) } do
		prop("Statue", CFrame.new(spot) * CFrame.Angles(0, math.rad(if spot.X < 0 then 90 else -90), 0), Vector3.new(3, 7, 3))
		kit.makeZone(
			folder,
			"HidingZone",
			CFrame.new(spot + Vector3.new(if spot.X < 0 then 3 else -3, 3, 0)),
			Vector3.new(4, 6, 5),
			"HidingSpot"
		)
	end
	for _, p in { Vector3.new(-21, 7, 1772), Vector3.new(21, 7, 1772), Vector3.new(-21, 7, 1792), Vector3.new(21, 7, 1792) } do
		torch(p)
	end
	riftCrystal(Vector3.new(18, 0, 1798), 4)
	kit.makeCheckpoint(folder, "Symbol Chamber", 21, Vector3.new(0, 0, 1765))
	kit.makeStoryTrigger(folder, "C3Symbols", CFrame.new(0, 4, 1766), Vector3.new(30, 8, 4))
	-- Patrol points for the creature (Zone = Chapter3).
	for i, point in
		{
			Vector3.new(-14, 3, 1770),
			Vector3.new(14, 3, 1770),
			Vector3.new(-14, 3, 1794),
			Vector3.new(14, 3, 1794),
			Vector3.new(0, 3, 1776),
			Vector3.new(0, 3, 1792),
		}
	do
		local marker = kit.makeZone(folder, "C3Patrol" .. i, CFrame.new(point), Vector3.new(1, 1, 1), "StalkerPatrol")
		marker:SetAttribute("Order", i)
		marker:SetAttribute("Zone", "Chapter3")
	end
	kit.makeZone(folder, "C3StalkerSpawn", CFrame.new(18, 4, 1796), Vector3.new(1, 1, 1), "C3StalkerSpawn")
end

local function buildSanctum()
	room("Sanctum", -16, 1800, 16, 1840, 0, 26)
	wall(-16, 1800, -6, 1800, 26)
	wall(6, 1800, 16, 1800, 26)
	part({
		Name = "SanctumArchTop",
		Size = Vector3.new(12, 26 - HEIGHT, 2),
		Position = Vector3.new(0, HEIGHT + (26 - HEIGHT) / 2, 1800),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	wall(-16, 1800, -16, 1840, 26)
	wall(16, 1800, 16, 1840, 26)
	wall(-16, 1840, -4, 1840, 26)
	wall(4, 1840, 16, 1840, 26)
	part({
		Name = "ExitHeader",
		Size = Vector3.new(8, 5, 2),
		Position = Vector3.new(0, 23.5, 1840),
		Material = Enum.Material.Slate,
		Color = STONE_DARK,
	})
	-- The exit is up on the ledge: block the bottom of the north opening.
	part({
		Name = "ExitBase",
		Size = Vector3.new(8, 12, 2),
		Position = Vector3.new(0, 6, 1840),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- Ledge along the north wall at Y 12.
	part({
		Name = "Ledge",
		Size = Vector3.new(32, 1, 6),
		Position = Vector3.new(0, 11.5, 1837),
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- Climbing wall: a vine-covered truss up to the ledge.
	local vines = Instance.new("TrussPart")
	vines.Name = "ClimbingVines"
	vines.Anchored = true
	vines.Size = Vector3.new(2, 12, 2)
	vines.Position = Vector3.new(12, 6, 1833)
	vines.Material = Enum.Material.Grass
	vines.Color = MOSS
	vines.Style = Enum.Style.NoSupports
	vines.Parent = folder
	part({
		Name = "ClimbHint",
		Size = Vector3.new(0.4, 12, 3),
		Position = Vector3.new(13.2, 6, 1833),
		Material = Enum.Material.LeafyGrass,
		Color = MOSS,
		CanCollide = false,
	})
	-- The Rift Heart on its altar.
	prop("Altar", CFrame.new(0, 0, 1824), Vector3.new(6, 3, 4), STONE)
	local heart = part({
		Name = "RiftHeart",
		Size = Vector3.new(2.4, 3.4, 2.4),
		CFrame = CFrame.new(0, 5, 1824) * CFrame.Angles(0, math.rad(45), math.rad(10)),
		Material = Enum.Material.Neon,
		Color = RIFT,
		CanCollide = false,
		CastShadow = false,
	})
	kit.addLight(heart, RIFT, 30, 2)
	CollectionService:AddTag(heart, "RiftHeart")
	kit.makePrompt(heart, "Touch", "The Rift Heart", 1.5)
	for _, p in { Vector3.new(-8, 0, 1810), Vector3.new(9, 0, 1814), Vector3.new(-10, 0, 1830) } do
		riftCrystal(p, 5)
	end
	torch(Vector3.new(-15, 7, 1812))
	torch(Vector3.new(15, 7, 1812))
	kit.makeNote(folder, "C3Vael", "Vael inscription", Vector3.new(-3, 3.1, 1824))
	-- Rising water (a sheet that climbs during the escape).
	local water = part({
		Name = "RisingWater",
		Size = Vector3.new(31, 1, 39),
		Position = Vector3.new(0, -1, 1820),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(40, 90, 110),
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
	CollectionService:AddTag(water, "RisingWater")
	kit.makeStoryTrigger(folder, "C3Sanctum", CFrame.new(0, 4, 1804), Vector3.new(12, 8, 4))

	-- Exit tunnel at the ledge level.
	room("ExitTunnel", -4, 1840, 4, 1866, 12, 9)
	wall(-4, 1840, -4, 1866, 9, nil, 12)
	wall(4, 1840, 4, 1866, 9, nil, 12)
	wall(-4, 1866, 4, 1866, 9, nil, 12)
	torch(Vector3.new(-3.5, 17, 1856))
	kit.makeZone(folder, "C3EndZone", CFrame.new(0, 16, 1860), Vector3.new(8, 8, 8), "C3EndZone")
end

-- Fills the flooded gallery with terrain water (terrain is filled once).
function Chapter3Builder.FillTerrain(terrain: Terrain)
	terrain:FillBlock(CFrame.new(0, -3.5, 1740), Vector3.new(32, 5, 40), Enum.Material.Water)
end

function Chapter3Builder.Build(level: Folder, buildKit: Kit)
	kit = buildKit
	folder = Instance.new("Folder")
	folder.Name = "SunkenTemple"
	folder.Parent = level
	buildEntrance()
	buildGallery()
	buildHiddenChamber()
	buildSymbolChamber()
	buildSanctum()
end

return Chapter3Builder
