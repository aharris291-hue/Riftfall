--!strict
-- SceneryKit: builders for the Chapter 1 set dressing, styled after the
-- "Chapter 1 environment" concept art: a storm-soaked jungle, moss-covered
-- stone arches strangled by roots, a muddy expedition camp with rusted,
-- overgrown 4x4s (headlights still on), a crashed helicopter, torches, and
-- cliffs climbing toward a mountain.
--
-- Everything is built from plain parts (no asset IDs), so it can be swapped
-- for real meshes later. Builders only create visuals; gameplay pieces
-- (zones, prompts, tags) stay in LevelBuilder.
--
-- Orientation: a CFrame passed to a builder is the object's ground point;
-- its LookVector (-Z) is the object's "front".
--
-- Real 3D models: put a Model (or a Folder of variant Models) named after a
-- library slot (see SceneryKit.Slots) inside ServerStorage > RiftfallAssets,
-- and every builder for that slot uses a copy of it instead of the parts.
-- The model's pivot is placed on the ground point, facing the same way.

local ServerStorage = game:GetService("ServerStorage")

local SceneryKit = {}

-- Library slot names, one per kind of placeholder.
SceneryKit.Slots = {
	Tree = "JungleTree",
	Fern = "Fern",
	Arch = "StoneArch",
	BrokenArch = "BrokenStoneArch",
	Torch = "Torch",
	Tent = "Tent",
	Cases = "SupplyCases",
	Truck = "Expedition4x4",
	Helicopter = "CrashedHelicopter",
}

type Props = { [string]: any }

-- Shared palette (kept muted but not black, so the night stays readable).
SceneryKit.Colors = {
	Bark = Color3.fromRGB(62, 50, 40),
	Root = Color3.fromRGB(70, 56, 42),
	Leaf = Color3.fromRGB(34, 62, 36),
	Fern = Color3.fromRGB(52, 92, 50),
	Moss = Color3.fromRGB(70, 104, 48),
	Stone = Color3.fromRGB(104, 106, 98),
	StoneDark = Color3.fromRGB(76, 78, 72),
	Cliff = Color3.fromRGB(72, 78, 76),
	Mud = Color3.fromRGB(70, 54, 40),
	Rust = Color3.fromRGB(116, 74, 44),
	Canvas = Color3.fromRGB(88, 96, 70),
	TorchFlame = Color3.fromRGB(255, 150, 60),
	Headlight = Color3.fromRGB(255, 214, 150),
}
local C = SceneryKit.Colors

local function part(parent: Instance, props: Props): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Decoration that players walk through and the AI ignores.
local function decor(parent: Instance, props: Props): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(parent, props)
end

-- A round rod stretched from one point to another (roots, vines, poles).
local function strut(parent: Instance, from: Vector3, to: Vector3, thickness: number, props: Props): BasePart
	local direction = to - from
	-- lookAt needs an "up" that is not parallel to the rod.
	local up = if math.abs(direction.Unit.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(direction.Magnitude, thickness, thickness)
	-- Cylinders run along X; turn X onto the rod's direction.
	props.CFrame = CFrame.lookAt((from + to) / 2, to, up) * CFrame.Angles(0, math.rad(90), 0)
	return decor(parent, props)
end

-- Places a copy of a real model from ServerStorage.RiftfallAssets, if the
-- slot has one. Returns the copy, or nil to build the placeholder instead.
local function fromLibrary(slot: string, parent: Instance, at: CFrame, rng: Random?): Model?
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	local entry = library and library:FindFirstChild(slot)
	if entry and entry:IsA("Folder") then
		local variants = entry:GetChildren()
		entry = if #variants > 0 then variants[if rng then rng:NextInteger(1, #variants) else 1] else nil
	end
	if not entry or not entry:IsA("Model") then
		return nil
	end
	local copy = entry:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	copy:PivotTo(if rng then at * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0) else at)
	copy.Parent = parent
	return copy
end
SceneryKit.FromLibrary = fromLibrary

local function addPointLight(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

------------------------------------------------------------------------------
-- Plants
------------------------------------------------------------------------------

-- A low fern: fronds fanning out from the ground.
function SceneryKit.Fern(parent: Instance, position: Vector3, rng: Random, scale: number?)
	local facing = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if fromLibrary(SceneryKit.Slots.Fern, parent, CFrame.new(position) * facing, rng) then
		return
	end
	local s = scale or rng:NextNumber(0.8, 1.4)
	local tint = rng:NextInteger(-8, 10)
	local count = rng:NextInteger(5, 7)
	for i = 1, count do
		local yaw = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local length = 3.6 * s
		decor(parent, {
			Name = "Frond",
			Size = Vector3.new(1.1 * s, 0.12, length),
			CFrame = CFrame.new(position)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(rng:NextNumber(18, 34)), 0, 0)
				* CFrame.new(0, 0, -length / 2),
			Material = Enum.Material.LeafyGrass,
			Color = Color3.fromRGB(52 + tint, 92 + tint, 50 + tint),
			CastShadow = false,
		})
	end
end

-- Hanging vine from a point straight down, slightly swaying.
function SceneryKit.Vine(parent: Instance, top: Vector3, length: number, rng: Random)
	local bottom = top + Vector3.new(rng:NextNumber(-0.8, 0.8), -length, rng:NextNumber(-0.8, 0.8))
	strut(parent, top, bottom, 0.25, {
		Name = "Vine",
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(46, 78, 40),
		CastShadow = false,
	})
end

-- Jungle tree: buttress roots, an optional moss band, a layered canopy, and
-- sometimes hanging vines.
function SceneryKit.Tree(parent: Instance, position: Vector3, rng: Random)
	local facing = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if fromLibrary(SceneryKit.Slots.Tree, parent, CFrame.new(position) * facing, rng) then
		return
	end
	local height = rng:NextNumber(22, 36)
	local radius = rng:NextNumber(1.4, 2.6)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	local base = CFrame.new(position) * lean
	part(model, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = C.Bark,
	})
	if rng:NextNumber() < 0.45 then
		decor(model, {
			Name = "Moss",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(rng:NextNumber(3, 7), radius * 2 + 0.3, radius * 2 + 0.3),
			CFrame = base * CFrame.new(0, rng:NextNumber(2, 8), 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Grass,
			Color = C.Moss,
			CastShadow = false,
		})
	end
	-- Buttress roots flaring out at the base.
	for i = 1, rng:NextInteger(3, 4) do
		local yaw = (i / 4) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		strut(model, position + Vector3.new(0, 3.5, 0) + dir * radius * 0.6, position + dir * (radius + 3.2), 0.9, {
			Name = "Root",
			Material = Enum.Material.Wood,
			Color = C.Root,
		})
	end
	-- Canopy.
	local top = (base * CFrame.new(0, height, 0)).Position
	for i = 1, 3 do
		local size = rng:NextNumber(9, 15)
		decor(model, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = top + Vector3.new(rng:NextNumber(-4, 4), (i - 2) * 2.5, rng:NextNumber(-4, 4)),
			Material = Enum.Material.LeafyGrass,
			Color = Color3.fromRGB(30 + rng:NextInteger(0, 10), 56 + rng:NextInteger(0, 22), 34),
			CastShadow = false,
		})
	end
	if rng:NextNumber() < 0.4 then
		for _ = 1, rng:NextInteger(2, 3) do
			SceneryKit.Vine(
				model,
				top + Vector3.new(rng:NextNumber(-4, 4), -4, rng:NextNumber(-4, 4)),
				rng:NextNumber(8, 16),
				rng
			)
		end
	end
	model.Parent = parent
end

-- Thick roots draped over something: from a high point down to the ground,
-- bending outward. Used on arches, pillars and the temple.
function SceneryKit.DrapeRoots(parent: Instance, top: Vector3, groundY: number, count: number, rng: Random)
	for _ = 1, count do
		local yaw = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local mid = Vector3.new(top.X, (top.Y + groundY) / 2, top.Z) + out * rng:NextNumber(1.2, 2.2)
		local foot = Vector3.new(top.X, groundY, top.Z) + out * rng:NextNumber(2.5, 4.5)
		local thickness = rng:NextNumber(0.5, 0.9)
		strut(parent, top, mid, thickness, { Name = "Root", Material = Enum.Material.Wood, Color = C.Root })
		strut(parent, mid, foot, thickness * 1.4, { Name = "Root", Material = Enum.Material.Wood, Color = C.Root })
	end
end

-- A moss cap sitting on top of a block-shaped part.
function SceneryKit.MossCap(parent: Instance, block: BasePart)
	local size = block.Size
	decor(parent, {
		Name = "Moss",
		Size = Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
		CFrame = block.CFrame * CFrame.new(0, size.Y / 2 + 0.1, 0),
		Material = Enum.Material.Grass,
		Color = C.Moss,
		CastShadow = false,
	})
end

------------------------------------------------------------------------------
-- Ruins
------------------------------------------------------------------------------

export type ArchOptions = {
	Width: number, -- Clear gap between the legs.
	Height: number, -- Height of the legs (the arch curve sits on top).
	Broken: boolean?, -- Missing stones on one side of the curve.
	Rng: Random,
}

-- A carved stone archway, mossy and wrapped in roots. The opening faces
-- along the CFrame's LookVector.
function SceneryKit.Arch(parent: Instance, at: CFrame, options: ArchOptions)
	local rng = options.Rng
	local slot = if options.Broken then SceneryKit.Slots.BrokenArch else SceneryKit.Slots.Arch
	if fromLibrary(slot, parent, at, nil) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "StoneArch"
	local legW = 3.2
	local half = options.Width / 2 + legW / 2
	for _, side in { -1, 1 } do
		local legCF = at * CFrame.new(side * half, options.Height / 2, 0)
		local leg = part(model, {
			Name = "Leg",
			Size = Vector3.new(legW, options.Height, legW),
			CFrame = legCF,
			Material = Enum.Material.Slate,
			Color = C.Stone,
		})
		-- Plinth and carved bands.
		part(model, {
			Name = "Plinth",
			Size = Vector3.new(legW + 1, 1.6, legW + 1),
			CFrame = at * CFrame.new(side * half, 0.8, 0),
			Material = Enum.Material.Slate,
			Color = C.StoneDark,
		})
		for _, y in { options.Height * 0.45, options.Height - 0.6 } do
			decor(model, {
				Name = "Carving",
				Size = Vector3.new(legW + 0.4, 0.7, legW + 0.4),
				CFrame = at * CFrame.new(side * half, y, 0),
				Material = Enum.Material.Slate,
				Color = C.StoneDark,
			})
		end
		SceneryKit.DrapeRoots(model, leg.CFrame.Position + Vector3.new(0, options.Height / 2, 0), 0, 2, rng)
	end
	-- The curve: stones around a half circle.
	local radius = half
	local segments = 9
	local skipFrom = if options.Broken then rng:NextInteger(6, 8) else segments + 1
	for i = 1, segments do
		if i < skipFrom then
			local a = math.pi * (i - 0.5) / segments
			local stone = part(model, {
				Name = "ArchStone",
				Size = Vector3.new(legW, radius * math.pi / segments + 0.3, legW),
				-- Turn each stone so its long side follows the curve.
				CFrame = at
					* CFrame.new(-math.cos(a) * radius, options.Height + math.sin(a) * radius, 0)
					* CFrame.Angles(0, 0, -a),
				Material = Enum.Material.Slate,
				Color = if i % 3 == 0 then C.StoneDark else C.Stone,
			})
			if i % 2 == 1 then
				-- Moss on the outer (upper) face of the curve.
				decor(model, {
					Name = "Moss",
					Size = Vector3.new(0.4, stone.Size.Y, legW + 0.2),
					CFrame = stone.CFrame * CFrame.new(-legW / 2 - 0.1, 0, 0),
					Material = Enum.Material.Grass,
					Color = C.Moss,
					CastShadow = false,
				})
			end
		end
	end
	-- A curtain of vines hanging from the top.
	for _ = 1, 4 do
		local x = rng:NextNumber(-radius * 0.7, radius * 0.7)
		local y = options.Height + math.sqrt(math.max(radius * radius - x * x, 0)) - 1
		SceneryKit.Vine(model, (at * CFrame.new(x, y, rng:NextNumber(-1, 1))).Position, rng:NextNumber(3, 7), rng)
	end
	model.Parent = parent
end

-- Wide stone stairs climbing along the CFrame's LookVector.
function SceneryKit.Stairs(parent: Instance, at: CFrame, steps: number, width: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "StoneStairs"
	local rise, run = 1, 1.8
	for i = 0, steps - 1 do
		local step = part(model, {
			Name = "Step",
			Size = Vector3.new(width, rise * (i + 1), run),
			CFrame = at * CFrame.new(0, rise * (i + 1) / 2, -run * (i + 0.5)),
			Material = Enum.Material.Slate,
			Color = if i % 2 == 0 then C.Stone else C.StoneDark,
		})
		if rng:NextNumber() < 0.35 then
			decor(model, {
				Name = "Moss",
				Size = Vector3.new(rng:NextNumber(2, width * 0.6), 0.3, run),
				CFrame = step.CFrame * CFrame.new(rng:NextNumber(-width / 4, width / 4), step.Size.Y / 2 + 0.1, 0),
				Material = Enum.Material.Grass,
				Color = C.Moss,
				CastShadow = false,
			})
		end
	end
	model.Parent = parent
end

-- A torch on a post with a living flame. Returns the flame part.
function SceneryKit.Torch(parent: Instance, position: Vector3, height: number?)
	if fromLibrary(SceneryKit.Slots.Torch, parent, CFrame.new(position), nil) then
		return
	end
	local h = height or 5
	local model = Instance.new("Model")
	model.Name = "Torch"
	part(model, {
		Name = "Post",
		Size = Vector3.new(0.5, h, 0.5),
		Position = position + Vector3.new(0, h / 2, 0),
		Material = Enum.Material.Wood,
		Color = C.Bark,
	})
	decor(model, {
		Name = "Bowl",
		Size = Vector3.new(1.2, 0.6, 1.2),
		Position = position + Vector3.new(0, h + 0.3, 0),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(60, 50, 44),
	})
	local flame = decor(model, {
		Name = "Flame",
		Size = Vector3.new(0.7, 1, 0.7),
		Position = position + Vector3.new(0, h + 1, 0),
		Material = Enum.Material.Neon,
		Color = C.TorchFlame,
		CastShadow = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 5
	fire.Color = Color3.fromRGB(255, 130, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 80)
	fire.Parent = flame
	addPointLight(flame, C.TorchFlame, 22, 1.6)
	model.Parent = parent
end

------------------------------------------------------------------------------
-- Expedition gear and vehicles
------------------------------------------------------------------------------

-- An A-frame canvas tent. Torn tents are missing part of one side.
function SceneryKit.Tent(parent: Instance, at: CFrame, color: Color3, torn: boolean?)
	if fromLibrary(SceneryKit.Slots.Tent, parent, at, nil) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Tent"
	local w, h, d = 7, 4.6, 8
	local slant = math.sqrt((w / 2) ^ 2 + h ^ 2)
	local angle = math.atan2(w / 2, h)
	for _, side in { -1, 1 } do
		local length = if torn and side == 1 then d * 0.55 else d
		part(model, {
			Name = "Canvas",
			Size = Vector3.new(0.2, slant, length),
			CFrame = at * CFrame.new(side * w / 4, h / 2, (d - length) / 2) * CFrame.Angles(0, 0, side * angle),
			Material = Enum.Material.Fabric,
			Color = if side == 1 then color else color:Lerp(Color3.new(0, 0, 0), 0.15),
		})
	end
	strut(model, (at * CFrame.new(0, h, -d / 2 - 0.3)).Position, (at * CFrame.new(0, h, d / 2 + 0.3)).Position, 0.3, {
		Name = "Ridge",
		Material = Enum.Material.Wood,
		Color = C.Bark,
	})
	for _, z in { -d / 2, d / 2 } do
		strut(model, (at * CFrame.new(0, 0, z)).Position, (at * CFrame.new(0, h, z)).Position, 0.25, {
			Name = "Pole",
			Material = Enum.Material.Wood,
			Color = C.Bark,
		})
	end
	decor(model, {
		Name = "GroundSheet",
		Size = Vector3.new(w + 0.6, 0.1, d + 0.6),
		CFrame = at * CFrame.new(0, 0.06, 0),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(46, 52, 58),
	})
	model.Parent = parent
end

-- A stack of equipment: grey hard cases with a coloured stripe, or crates.
function SceneryKit.Cases(parent: Instance, at: CFrame, rng: Random)
	if fromLibrary(SceneryKit.Slots.Cases, parent, at, rng) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cases"
	local stripe = if rng:NextNumber() < 0.5 then Color3.fromRGB(200, 170, 60) else Color3.fromRGB(90, 150, 90)
	for i = 1, rng:NextInteger(2, 4) do
		local wooden = rng:NextNumber() < 0.35
		local size = if wooden then Vector3.new(2.6, 2.2, 2.6) else Vector3.new(3, 1.5, 2)
		local y = if i == 4 then size.Y * 1.5 else size.Y / 2
		local box = part(model, {
			Name = if wooden then "Crate" else "Case",
			Size = size,
			CFrame = at
				* CFrame.new(((i - 1) % 3) * 3.2 - 3, y, rng:NextNumber(-0.5, 0.5))
				* CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			Material = if wooden then Enum.Material.WoodPlanks else Enum.Material.DiamondPlate,
			Color = if wooden then Color3.fromRGB(112, 86, 58) else Color3.fromRGB(112, 116, 118),
		})
		if not wooden then
			decor(model, {
				Name = "Stripe",
				Size = Vector3.new(size.X + 0.05, 0.25, size.Z + 0.05),
				CFrame = box.CFrame * CFrame.new(0, 0.2, 0),
				Material = Enum.Material.SmoothPlastic,
				Color = stripe,
			})
		end
	end
	model.Parent = parent
end

-- A rusted, overgrown expedition 4x4. Headlights (still on) shine along
-- the LookVector and light the ground in front of it.
function SceneryKit.Truck(parent: Instance, at: CFrame, rng: Random)
	if fromLibrary(SceneryKit.Slots.Truck, parent, at, nil) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Expedition4x4"
	local body = C.Rust:Lerp(Color3.fromRGB(80, 70, 56), rng:NextNumber(0, 0.5))
	local function piece(name: string, size: Vector3, offset: CFrame, props: Props?): BasePart
		local p: Props = props or {}
		p.Name = name
		p.Size = size
		p.CFrame = at * offset
		p.Material = p.Material or Enum.Material.CorrodedMetal
		p.Color = p.Color or body
		return part(model, p)
	end
	piece("Chassis", Vector3.new(6.2, 1.8, 11), CFrame.new(0, 2.1, 0))
	piece("Cabin", Vector3.new(5.8, 2.8, 6), CFrame.new(0, 4.4, 1.6))
	piece("Hood", Vector3.new(6, 0.8, 4), CFrame.new(0, 3.3, -3.4))
	piece("Bumper", Vector3.new(6.8, 0.8, 0.8), CFrame.new(0, 1.6, -5.7), { Color = Color3.fromRGB(40, 40, 42) })
	piece("Windscreen", Vector3.new(5.2, 2, 0.2), CFrame.new(0, 4.6, -1.45), {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(40, 54, 60),
		Transparency = 0.35,
	})
	piece("RoofRack", Vector3.new(6, 0.3, 5.6), CFrame.new(0, 6, 1.6), { Color = Color3.fromRGB(46, 46, 48) })
	piece("RoofCrate", Vector3.new(2.4, 1.4, 2), CFrame.new(-1.2, 6.9, 2.4), {
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(100, 78, 52),
	})
	piece("Snorkel", Vector3.new(0.4, 3, 0.4), CFrame.new(3.1, 4.6, -1.6), { Color = Color3.fromRGB(36, 36, 38) })
	for _, x in { -3.1, 3.1 } do
		for _, z in { -3.4, 3.6 } do
			piece("Wheel", Vector3.new(1.2, 3, 3), CFrame.new(x, 1.5, z), {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Rubber,
				Color = Color3.fromRGB(28, 28, 30),
			})
		end
		-- Headlight with a forward-facing spotlight.
		local lamp = piece("Headlight", Vector3.new(0.9, 0.9, 0.3), CFrame.new(x * 0.75, 2.7, -5.55), {
			Material = Enum.Material.Neon,
			Color = C.Headlight,
			CanCollide = false,
			CastShadow = false,
		})
		local beam = Instance.new("SpotLight")
		beam.Face = Enum.NormalId.Front
		beam.Angle = 55
		beam.Range = 42
		beam.Brightness = 3
		beam.Color = C.Headlight
		beam.Shadows = false
		beam.Parent = lamp
	end
	-- Light bar on the roof rack.
	for i = -1, 1 do
		piece("RoofLamp", Vector3.new(0.7, 0.5, 0.3), CFrame.new(i * 1.6, 6.4, -1.15), {
			Material = Enum.Material.Neon,
			Color = C.Headlight,
			CanCollide = false,
		})
	end
	-- Moss and vines reclaiming it.
	for _, spec in { { 0, 3.75, -3.4, 4.5, 2.4 }, { 1, 6.2, 1, 3, 3 } } do
		decor(model, {
			Name = "Moss",
			Size = Vector3.new(spec[4], 0.3, spec[5]),
			CFrame = at * CFrame.new(spec[1], spec[2], spec[3]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			Material = Enum.Material.Grass,
			Color = C.Moss,
			CastShadow = false,
		})
	end
	for _ = 1, 3 do
		SceneryKit.Vine(
			model,
			(at * CFrame.new(rng:NextNumber(-3, 3), 6, rng:NextNumber(-1, 4))).Position,
			rng:NextNumber(2, 4),
			rng
		)
	end
	model.Parent = parent
end

-- The crashed expedition helicopter: tipped on its side, rotor snapped,
-- moss growing over the hull. Returns the point where fire and smoke go.
function SceneryKit.Helicopter(parent: Instance, at: CFrame, rng: Random): Vector3
	local real = fromLibrary(SceneryKit.Slots.Helicopter, parent, at, nil)
	if real then
		return real:GetPivot().Position + Vector3.new(0, 4, 0)
	end
	local model = Instance.new("Model")
	model.Name = "HelicopterWreck"
	local hullColor = Color3.fromRGB(78, 86, 72)
	-- Tipped onto its right side.
	local tilt = at * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(-24))
	local hull = part(model, {
		Name = "Hull",
		Size = Vector3.new(7, 6.5, 13),
		CFrame = tilt,
		Material = Enum.Material.CorrodedMetal,
		Color = hullColor,
	})
	part(model, {
		Name = "Nose",
		Size = Vector3.new(6, 5, 4),
		CFrame = tilt * CFrame.new(0, -0.4, -8),
		Material = Enum.Material.CorrodedMetal,
		Color = hullColor,
	})
	part(model, {
		Name = "Cockpit",
		Size = Vector3.new(5.6, 3, 2.4),
		CFrame = tilt * CFrame.new(0, 1, -10.2) * CFrame.Angles(math.rad(-25), 0, 0),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(46, 60, 66),
		Transparency = 0.4,
	})
	-- Dark open doorway on the left side.
	decor(model, {
		Name = "Doorway",
		Size = Vector3.new(0.2, 4, 4),
		CFrame = tilt * CFrame.new(-3.55, -0.2, 0),
		Color = Color3.fromRGB(16, 18, 18),
	})
	-- Tail boom, bent where it hit the ground.
	part(model, {
		Name = "TailBoom",
		Size = Vector3.new(2, 2, 12),
		CFrame = tilt * CFrame.new(0, 1.2, 12),
		Material = Enum.Material.CorrodedMetal,
		Color = hullColor,
	})
	local tailEnd = part(model, {
		Name = "TailBoomEnd",
		Size = Vector3.new(1.4, 1.4, 7),
		CFrame = tilt * CFrame.new(0, 1.2, 18) * CFrame.Angles(math.rad(14), math.rad(18), 0) * CFrame.new(0, 0, 3.4),
		Material = Enum.Material.CorrodedMetal,
		Color = hullColor,
	})
	decor(model, {
		Name = "TailFin",
		Size = Vector3.new(0.3, 3.4, 2),
		CFrame = tailEnd.CFrame * CFrame.new(0, 1.6, 2.6),
		Material = Enum.Material.CorrodedMetal,
		Color = hullColor,
	})
	-- Rotor mast and blades: one still attached and sagging, the others
	-- snapped off and lying in the mud.
	local mastTop = (tilt * CFrame.new(0, 4.6, -1)).Position
	strut(model, (tilt * CFrame.new(0, 3.2, -1)).Position, mastTop, 0.8, {
		Name = "Mast",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 46, 48),
	})
	strut(model, mastTop, mastTop + (at.RightVector * -14) + Vector3.new(0, -3.5, 2), 0.25, {
		Name = "Blade",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 40, 42),
	})
	strut(model, mastTop, mastTop + (at.LookVector * 9) + Vector3.new(0, 1.8, 0), 0.25, {
		Name = "Blade",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 40, 42),
	})
	for _, offset in { CFrame.new(10, 0.2, -6), CFrame.new(-9, 0.2, 8) } do
		part(model, {
			Name = "SnappedBlade",
			Size = Vector3.new(1.1, 0.25, 11),
			CFrame = at * offset * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(4)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 40, 42),
		})
	end
	-- Skids.
	for _, x in { -2.4, 2.4 } do
		strut(model, (tilt * CFrame.new(x, -3.6, -5)).Position, (tilt * CFrame.new(x, -3.6, 5)).Position, 0.35, {
			Name = "Skid",
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(46, 46, 48),
		})
	end
	-- Moss on the upturned side and vines hanging off it.
	decor(model, {
		Name = "Moss",
		Size = Vector3.new(0.4, 5, 9),
		CFrame = tilt * CFrame.new(-3.6, 1.2, 1) * CFrame.Angles(0, 0, 0),
		Material = Enum.Material.Grass,
		Color = C.Moss,
		CastShadow = false,
	})
	decor(model, {
		Name = "Moss",
		Size = Vector3.new(6, 0.4, 7),
		CFrame = tilt * CFrame.new(0, 3.35, 2),
		Material = Enum.Material.Grass,
		Color = C.Moss,
		CastShadow = false,
	})
	for _ = 1, 4 do
		SceneryKit.Vine(
			model,
			(tilt * CFrame.new(rng:NextNumber(-3, 1), 3, rng:NextNumber(-5, 6))).Position,
			rng:NextNumber(2, 4),
			rng
		)
	end
	model.Parent = parent
	return hull.CFrame.Position + Vector3.new(0, 3, 0)
end

-- A muddy patch with a few rain puddles that catch the light. With smooth
-- terrain, the mud is painted into the ground itself.
function SceneryKit.MudPatch(parent: Instance, center: Vector3, size: Vector2, rng: Random)
	local terrain = SceneryKit.Terrain
	if terrain then
		SceneryKit.PaintGround(terrain, center, size, Enum.Material.Mud)
	end
	for _ = 1, 4 do
		local mud = {
			Name = "Mud",
			Size = Vector3.new(size.X * rng:NextNumber(0.5, 0.8), 0.1, size.Y * rng:NextNumber(0.5, 0.8)),
			CFrame = CFrame.new(
				center
					+ Vector3.new(
						rng:NextNumber(-size.X / 5, size.X / 5),
						0.06,
						rng:NextNumber(-size.Y / 5, size.Y / 5)
					)
			) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Mud,
			Color = C.Mud,
			CastShadow = false,
		}
		if not terrain then
			decor(parent, mud)
		end
	end
	for _ = 1, 5 do
		decor(parent, {
			Name = "Puddle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, rng:NextNumber(2, 5), rng:NextNumber(2, 5)),
			CFrame = CFrame.new(
				center
					+ Vector3.new(
						rng:NextNumber(-size.X / 3, size.X / 3),
						if terrain then 0.25 else 0.13,
						rng:NextNumber(-size.Y / 3, size.Y / 3)
					)
			) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(70, 82, 92),
			Reflectance = 0.25,
			Transparency = 0.25,
			CastShadow = false,
		})
	end
end

------------------------------------------------------------------------------
-- Smooth terrain
------------------------------------------------------------------------------

-- Set by LevelBuilder when the valley floor is Roblox smooth terrain (in
-- Roblox) rather than parts (in the offline tests).
SceneryKit.Terrain = nil :: Terrain?

-- Repaints the top of the ground in a rectangle (centre, X/Z size).
function SceneryKit.PaintGround(terrain: Terrain, center: Vector3, size: Vector2, material: Enum.Material)
	local half = Vector3.new(size.X / 2, 4, size.Y / 2)
	local region = Region3.new(center - half - Vector3.new(0, 4, 0), center + half):ExpandToGrid(4)
	for _, from in { Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground } do
		terrain:ReplaceMaterial(region, 4, from, material)
	end
end

-- Fills the valley floor (top surface at Y = 0) and gives the materials
-- their storm-soaked colours. Swaying grass decoration is turned on.
function SceneryKit.FillValley(terrain: Terrain, rng: Random)
	terrain.Decoration = true
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(58, 82, 44))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(50, 74, 40))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(74, 58, 42))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(80, 66, 50))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(78, 82, 80))
	-- Playable valley (Z -80 to 445; the chasm beyond stays open), then the
	-- ground under the cliffs on both sides of the chasm.
	terrain:FillBlock(CFrame.new(0, -6, 182), Vector3.new(360, 12, 524), Enum.Material.Grass)
	for _, x in { -122, 122 } do
		terrain:FillBlock(CFrame.new(x, -6, 560), Vector3.new(116, 12, 232), Enum.Material.Grass)
	end
	terrain:FillBlock(CFrame.new(0, -6, 650), Vector3.new(360, 12, 140), Enum.Material.Grass)
	-- Patches of darker leafy undergrowth.
	for _ = 1, 40 do
		local center = Vector3.new(rng:NextNumber(-62, 62), 0, rng:NextNumber(-15, 210))
		local size = Vector2.new(rng:NextNumber(8, 20), rng:NextNumber(8, 20))
		local half = Vector3.new(size.X / 2, 4, size.Y / 2)
		terrain:ReplaceMaterial(
			Region3.new(center - half - Vector3.new(0, 4, 0), center + half):ExpandToGrid(4),
			4,
			Enum.Material.Grass,
			Enum.Material.LeafyGrass
		)
	end
end

------------------------------------------------------------------------------
-- Backdrop
------------------------------------------------------------------------------

-- A line of tall, mossy rock faces from one point to another, outside the
-- playable area (players never reach them; they frame the valley). The rock
-- itself is smooth terrain when `terrain` is given, parts when there is no
-- terrain at all, and skipped when terrain was already filled by an earlier
-- build. The random draws are the same in every case, so cliff-top trees
-- always land on the same rock.
function SceneryKit.CliffLine(parent: Instance, from: Vector3, to: Vector3, rng: Random, terrain: Terrain?)
	local direction = (to - from).Unit
	local length = (to - from).Magnitude
	local d = 0
	while d < length do
		local width = rng:NextNumber(18, 30)
		local h = rng:NextNumber(55, 120)
		local depth = rng:NextNumber(22, 34)
		local yaw = math.rad(90 + rng:NextNumber(-8, 8))
		local shade = rng:NextNumber(0, 1)
		local ledges = { rng:NextNumber(-h / 3, h / 3), rng:NextNumber(-h / 3, h / 3) }
		local hasTree = rng:NextNumber() < 0.5
		local pos = from + direction * (d + width / 2)
		local cf = CFrame.lookAt(pos, pos + direction) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, h / 2 - 6, 0)
		local size = Vector3.new(width + 4, h, depth)
		if terrain then
			terrain:FillBlock(cf, size, Enum.Material.Rock)
			-- Rounded, weathered top and mossy ledges.
			terrain:FillBall((cf * CFrame.new(0, h / 2, 0)).Position, math.min(width, depth) / 2, Enum.Material.Rock)
			for _, y in ledges do
				terrain:FillBlock(
					cf * CFrame.new(0, y, 0),
					size + Vector3.new(2, -size.Y + 4, 2),
					Enum.Material.LeafyGrass
				)
			end
		elseif not SceneryKit.Terrain then
			local slab = decor(parent, {
				Name = "Cliff",
				Size = size,
				CFrame = cf,
				Material = Enum.Material.Rock,
				Color = C.Cliff:Lerp(Color3.fromRGB(56, 64, 58), shade),
				CastShadow = false,
			})
			for _, y in ledges do
				decor(parent, {
					Name = "MossLedge",
					Size = size + Vector3.new(0.6, -size.Y + 2.5, 0.6),
					CFrame = slab.CFrame * CFrame.new(0, y, 0),
					Material = Enum.Material.Grass,
					Color = C.Moss:Lerp(Color3.fromRGB(40, 60, 36), 0.4),
					CastShadow = false,
				})
			end
		end
		if hasTree then
			local topY = if terrain or SceneryKit.Terrain then h / 2 + math.min(width, depth) / 2 - 2 else h / 2
			SceneryKit.Tree(parent, (cf * CFrame.new(0, topY, 0)).Position, rng)
		end
		d += width
	end
end

-- The mountain the expedition has to climb, looming far to the north.
function SceneryKit.Mountain(parent: Instance, base: Vector3, terrain: Terrain?)
	local tiers = {
		{ Vector3.new(300, 90, 140), 45, 0 },
		{ Vector3.new(210, 90, 120), 120, 8 },
		{ Vector3.new(130, 80, 100), 190, -6 },
	}
	if terrain then
		for _, tier in tiers do
			local cf = CFrame.new(base + Vector3.new(tier[3], tier[2], 0)) * CFrame.Angles(0, math.rad(tier[3]), 0)
			terrain:FillBlock(cf, tier[1], Enum.Material.Rock)
			terrain:FillBall(cf.Position + Vector3.new(0, tier[1].Y / 2, 0), tier[1].Z / 2, Enum.Material.Rock)
		end
		terrain:FillBall(base + Vector3.new(-6, 245, 0), 45, Enum.Material.Slate)
		return
	end
	if SceneryKit.Terrain then
		return
	end
	local rock = C.Cliff:Lerp(Color3.fromRGB(50, 56, 60), 0.5)
	for _, tier in tiers do
		decor(parent, {
			Name = "Mountain",
			Size = tier[1],
			CFrame = CFrame.new(base + Vector3.new(tier[3], tier[2], 0)) * CFrame.Angles(0, math.rad(tier[3]), 0),
			Material = Enum.Material.Rock,
			Color = rock,
			CastShadow = false,
		})
	end
	decor(parent, {
		Name = "Peak",
		Size = Vector3.new(100, 100, 80),
		CFrame = CFrame.new(base + Vector3.new(-6, 230, 0)) * CFrame.Angles(0, 0, math.rad(45)),
		Material = Enum.Material.Rock,
		Color = rock,
		CastShadow = false,
	})
end

return SceneryKit
