--!strict
-- LevelDresser: swaps the level's plain building blocks for real 3D meshes
-- and realistic materials, without touching gameplay.
--
-- How it works: LevelBuilder still creates every block (so collisions,
-- prompts, tags and puzzle logic are unchanged). For each block that has a
-- matching mesh in ServerStorage > RiftfallAssets > Dressing, the dresser
-- places a copy of that mesh over the block, stretched to the block's size,
-- and makes the block itself invisible (it keeps colliding). Blocks of
-- certain materials also get a custom MaterialVariant (stone, rock, wood).
--
-- Nothing breaks if a mesh or material is missing: the block simply stays
-- as it was.

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local LevelDresser = {}

type MeshRule = { area: string, names: { [string]: boolean }, key: string, grow: number? }

-- Which blocks get which mesh (looked up by area folder and block name).
local MESH_RULES: { MeshRule } = {
	{ area = "Ruins", names = { Pillar = true }, key = "RuinPillar", grow = 1.1 },
	{ area = "Ruins", names = { RuinWall = true, Wall = true }, key = "RuinWall", grow = 1.1 },
	{ area = "Ruins", names = { Rock = true }, key = "Boulder", grow = 1.25 },
	{ area = "Escape", names = { Rock = true }, key = "Boulder", grow = 1.2 },
	{ area = "CrashSite", names = { Crate1 = true, Crate2 = true, Crate3 = true }, key = "Crate" },
	{ area = "Trail", names = { BrokenCrate = true }, key = "Crate" },
	{ area = "Temple", names = { Altar = true }, key = "Altar", grow = 1.05 },
}

-- Base material -> MaterialVariant name (made in MaterialService).
local MATERIAL_VARIANTS: { [Enum.Material]: string } = {
	[Enum.Material.Slate] = "RiftTempleStone",
	[Enum.Material.Cobblestone] = "RiftFlagstone",
	[Enum.Material.Rock] = "RiftWetRock",
	[Enum.Material.WoodPlanks] = "RiftOldPlanks",
}

-- Extra set pieces placed from the Dressing folder: { mesh, area, ground
-- position, facing (radians), height in studs }.
local EXTRA_PROPS = {
	-- Serpent guardians in front of the arch that frames the temple door.
	{ key = "Serpent", area = "Temple", at = Vector3.new(-9.5, 0, 284), yaw = math.pi, height = 9 },
	{ key = "Serpent", area = "Temple", at = Vector3.new(9.5, 0, 284), yaw = math.pi, height = 9 },
}

-- Flat "moss" and "root" bars were drawn on top of the old blocks; the
-- meshes have their own moss and roots, so those bars are removed.
local CLUTTER = { Moss = true, Root = true }

local function hasVariant(name: string, base: Enum.Material): boolean
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and v.Name == name and v.BaseMaterial == base then
			return true
		end
	end
	return false
end

local function isInside(point: Vector3, part: BasePart, margin: number): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function overlay(block: BasePart, template: BasePart, grow: number)
	local mesh = template:Clone()
	mesh.Name = block.Name .. "Mesh"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = math.max(block.Size.X, block.Size.Y, block.Size.Z) >= 4
	-- Turn the mesh a quarter turn when its long side runs the other way
	-- (a wall mesh built along X placed on a block that runs along Z).
	local turn = (template.Size.X > template.Size.Z) ~= (block.Size.X > block.Size.Z)
	local size = if turn then Vector3.new(block.Size.Z, block.Size.Y, block.Size.X) else block.Size
	mesh.Size = size * grow
	-- Sit the mesh on the same ground as the block when it grows.
	mesh.CFrame = block.CFrame
		* CFrame.new(0, (mesh.Size.Y - block.Size.Y) / 2, 0)
		* CFrame.Angles(0, if turn then math.pi / 2 else 0, 0)
	mesh.Parent = block.Parent
	block.Transparency = 1
	block.CastShadow = false
end

-- Dresses a freshly built (not yet parented) level folder.
function LevelDresser.Dress(level: Folder)
	local library = ServerStorage:FindFirstChild("RiftfallAssets")
	local dressing = library and library:FindFirstChild("Dressing")

	local dressed: { BasePart } = {}
	if dressing then
		for _, rule in MESH_RULES do
			local area = level:FindFirstChild(rule.area)
			local template = dressing:FindFirstChild(rule.key)
			if area and template and template:IsA("BasePart") then
				for _, child in area:GetChildren() do
					if child:IsA("BasePart") and rule.names[child.Name] and child.Transparency == 0 then
						overlay(child, template, rule.grow or 1)
						table.insert(dressed, child)
					end
				end
			end
		end
	end

	if dressing then
		for _, prop in EXTRA_PROPS do
			local area = level:FindFirstChild(prop.area)
			local template = dressing:FindFirstChild(prop.key)
			if area and template and template:IsA("BasePart") then
				local mesh = template:Clone()
				mesh.Size = mesh.Size * (prop.height / mesh.Size.Y)
				mesh.CFrame = CFrame.new(prop.at + Vector3.new(0, mesh.Size.Y / 2, 0)) * CFrame.Angles(0, prop.yaw, 0)
				mesh.Anchored = true
				mesh.CanCollide = true
				mesh.CanTouch = false
				mesh.Parent = area
			end
		end
	end

	-- Remove moss/root bars that belonged to a dressed block.
	if #dressed > 0 then
		for _, area in level:GetChildren() do
			for _, child in area:GetChildren() do
				if child:IsA("BasePart") and CLUTTER[child.Name] then
					for _, block in dressed do
						if isInside(child.Position, block, 1.5) then
							child:Destroy()
							break
						end
					end
				end
			end
		end
	end

	local available: { [Enum.Material]: string } = {}
	for base, name in MATERIAL_VARIANTS do
		if hasVariant(name, base) then
			available[base] = name
		end
	end
	for _, d in level:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("MeshPart") and d.Transparency < 1 then
			local variant = available[d.Material]
			if variant and d.MaterialVariant == "" then
				d.MaterialVariant = variant
			end
		end
	end
end

return LevelDresser
