--!strict
-- Outfitter: dresses an R15 body (a player's character or an NPC rig) to
-- match a design from Shared/CharacterDesigns: skin and clothing colours,
-- a hairstyle, a drawn face, and gear pieces built from parts.
--
-- Everything added is named "Outfit_*" (or is the "OutfitFace" gui), so
-- Outfitter.Clear can remove it before a different outfit is applied.
--
-- Orientation reminder: on every R15 body part, -Z is the front and +Z the
-- back, +Y is up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterDesigns = require(ReplicatedStorage.Shared.CharacterDesigns)

type Design = CharacterDesigns.Design

local Outfitter = {}

local PREFIX = "Outfit_"

-- Which design colour each body part takes.
local BODY_COLORS: { [string]: string } = {
	Head = "Skin",
	UpperTorso = "Jacket",
	LowerTorso = "Trousers",
	LeftUpperArm = "Sleeves",
	RightUpperArm = "Sleeves",
	LeftLowerArm = "Sleeves",
	RightLowerArm = "Sleeves",
	LeftHand = "Gloves",
	RightHand = "Gloves",
	LeftUpperLeg = "Trousers",
	RightUpperLeg = "Trousers",
	LeftLowerLeg = "Trousers",
	RightLowerLeg = "Trousers",
	LeftFoot = "Boots",
	RightFoot = "Boots",
}

type Ctx = {
	Model: Model,
	Design: Design,
	Parts: { [string]: BasePart },
}

-- Welds a part to `body` at `offset` (relative to the body part's CFrame).
local function add(ctx: Ctx, bodyName: string, name: string, props: { [string]: any }, offset: CFrame): Part?
	local body = ctx.Parts[bodyName]
	if not body then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = PREFIX .. name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Fabric
	-- Head pieces never shadow the head-mounted flashlight.
	p.CastShadow = bodyName ~= "Head"
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.Model
	return p
end

local function glow(part: Part?, color: Color3, range: number, brightness: number)
	if not part then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
end

local function size(ctx: Ctx, bodyName: string): Vector3
	local body = ctx.Parts[bodyName]
	return if body then body.Size else Vector3.one
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

------------------------------------------------------------------------------
-- Hair and face
------------------------------------------------------------------------------

local function hairPiece(ctx: Ctx, name: string, partSize: Vector3, offset: CFrame)
	add(ctx, "Head", "Hair" .. name, {
		Size = partSize,
		Color = ctx.Design.Hair,
		Material = Enum.Material.SmoothPlastic,
	}, offset)
end

local HAIR_BUILDERS: { [string]: (Ctx, Vector3) -> () } = {
	Messy = function(ctx, hs)
		hairPiece(ctx, "Cap", Vector3.new(hs.X * 1.06, hs.Y * 0.3, hs.Z * 1.06), CFrame.new(0, hs.Y * 0.4, 0.02))
		hairPiece(
			ctx,
			"Back",
			Vector3.new(hs.X * 1.04, hs.Y * 0.6, hs.Z * 0.25),
			CFrame.new(0, hs.Y * 0.1, hs.Z * 0.42)
		)
		hairPiece(
			ctx,
			"Fringe",
			Vector3.new(hs.X * 0.95, hs.Y * 0.22, hs.Z * 0.18),
			CFrame.new(-hs.X * 0.05, hs.Y * 0.28, -hs.Z * 0.48) * CFrame.Angles(0, 0, math.rad(-8))
		)
		-- Tousled tufts on top.
		local tufts = {
			{ -0.3, 0.1, -0.25, 25 },
			{ 0.05, 0.15, -0.3, -15 },
			{ 0.3, 0.08, -0.15, 30 },
			{ -0.2, 0.12, 0.15, -25 },
			{ 0.2, 0.1, 0.2, 15 },
		}
		for i, t in tufts do
			hairPiece(
				ctx,
				"Tuft" .. i,
				Vector3.new(hs.X * 0.32, hs.Y * 0.22, hs.Z * 0.32),
				CFrame.new(t[1] * hs.X, hs.Y * (0.5 + t[2]), t[3] * hs.Z)
					* CFrame.Angles(math.rad(t[4]), math.rad(t[4] * 2), math.rad(t[4]))
			)
		end
		for _, side in { -1, 1 } do
			hairPiece(
				ctx,
				"Side",
				Vector3.new(hs.X * 0.12, hs.Y * 0.4, hs.Z * 0.7),
				CFrame.new(side * hs.X * 0.5, hs.Y * 0.18, 0.05)
			)
		end
	end,
	Short = function(ctx, hs)
		hairPiece(ctx, "Cap", Vector3.new(hs.X * 1.04, hs.Y * 0.18, hs.Z * 1.04), CFrame.new(0, hs.Y * 0.44, 0.02))
		hairPiece(
			ctx,
			"Back",
			Vector3.new(hs.X * 1.03, hs.Y * 0.45, hs.Z * 0.2),
			CFrame.new(0, hs.Y * 0.18, hs.Z * 0.43)
		)
		for _, side in { -1, 1 } do
			hairPiece(
				ctx,
				"Side",
				Vector3.new(hs.X * 0.1, hs.Y * 0.35, hs.Z * 0.75),
				CFrame.new(side * hs.X * 0.5, hs.Y * 0.22, 0.05)
			)
		end
	end,
	Bob = function(ctx, hs)
		hairPiece(ctx, "Cap", Vector3.new(hs.X * 1.08, hs.Y * 0.3, hs.Z * 1.08), CFrame.new(0, hs.Y * 0.4, 0.02))
		hairPiece(
			ctx,
			"Back",
			Vector3.new(hs.X * 1.08, hs.Y * 0.95, hs.Z * 0.28),
			CFrame.new(0, -hs.Y * 0.02, hs.Z * 0.42)
		)
		for _, side in { -1, 1 } do
			hairPiece(
				ctx,
				"Side",
				Vector3.new(hs.X * 0.16, hs.Y * 0.9, hs.Z * 0.95),
				CFrame.new(side * hs.X * 0.52, -hs.Y * 0.02, 0.04)
			)
		end
		hairPiece(
			ctx,
			"Fringe",
			Vector3.new(hs.X * 1.0, hs.Y * 0.2, hs.Z * 0.16),
			CFrame.new(hs.X * 0.05, hs.Y * 0.3, -hs.Z * 0.49) * CFrame.Angles(0, 0, math.rad(6))
		)
	end,
	Bun = function(ctx, hs)
		hairPiece(ctx, "Cap", Vector3.new(hs.X * 1.05, hs.Y * 0.26, hs.Z * 1.05), CFrame.new(0, hs.Y * 0.42, 0.02))
		hairPiece(
			ctx,
			"Back",
			Vector3.new(hs.X * 1.04, hs.Y * 0.6, hs.Z * 0.22),
			CFrame.new(0, hs.Y * 0.12, hs.Z * 0.42)
		)
		hairPiece(
			ctx,
			"Fringe",
			Vector3.new(hs.X * 0.55, hs.Y * 0.2, hs.Z * 0.15),
			CFrame.new(-hs.X * 0.22, hs.Y * 0.3, -hs.Z * 0.48) * CFrame.Angles(0, 0, math.rad(-12))
		)
		add(ctx, "Head", "HairBun", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * hs.Y * 0.45,
			Color = ctx.Design.Hair,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(0, hs.Y * 0.38, hs.Z * 0.55))
	end,
	None = function() end,
}

-- Draws a simple face (brows, eyes, mouth) on the front of the head, so
-- characters don't wear the default Roblox smile.
local function drawFace(ctx: Ctx)
	local head = ctx.Parts.Head
	if not head then
		return
	end
	for _, child in head:GetChildren() do
		if child:IsA("Decal") and child.Name == "face" then
			child:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OutfitFace"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 1
	gui.Parent = head

	local function feature(name: string, x: number, y: number, w: number, h: number, color: Color3, rotation: number?)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.Parent = gui
	end
	local d = ctx.Design
	local browColor = darker(d.Hair, 0.1)
	feature("BrowL", 0.32, 0.38, 0.18, 0.04, browColor, -6)
	feature("BrowR", 0.68, 0.38, 0.18, 0.04, browColor, 6)
	feature("EyeWhiteL", 0.33, 0.47, 0.13, 0.08, Color3.fromRGB(235, 232, 226))
	feature("EyeWhiteR", 0.67, 0.47, 0.13, 0.08, Color3.fromRGB(235, 232, 226))
	feature("EyeL", 0.34, 0.47, 0.07, 0.08, d.Eyes)
	feature("EyeR", 0.66, 0.47, 0.07, 0.08, d.Eyes)
	feature("Nose", 0.5, 0.6, 0.05, 0.08, darker(d.Skin, 0.15))
	feature("Mouth", 0.5, 0.74, 0.2, 0.025, darker(d.Skin, 0.4))
end

------------------------------------------------------------------------------
-- Gear pieces (names referenced from CharacterDesigns.Gear)
------------------------------------------------------------------------------

local GEAR: { [string]: (Ctx) -> () } = {}

GEAR.HoodDown = function(ctx)
	local ts = size(ctx, "UpperTorso")
	add(ctx, "UpperTorso", "Hood", {
		Size = Vector3.new(ts.X * 0.8, ts.Y * 0.3, ts.Z * 0.55),
		Color = darker(ctx.Design.Jacket, 0.15),
	}, CFrame.new(0, ts.Y * 0.48, ts.Z * 0.45) * CFrame.Angles(math.rad(-20), 0, 0))
end

GEAR.HoodUp = function(ctx)
	local hs = size(ctx, "Head")
	local color = darker(ctx.Design.Jacket, 0.05)
	add(
		ctx,
		"Head",
		"HoodTop",
		{ Size = Vector3.new(hs.X * 1.22, hs.Y * 0.18, hs.Z * 1.25), Color = color },
		CFrame.new(0, hs.Y * 0.58, 0.05)
	)
	add(
		ctx,
		"Head",
		"HoodBack",
		{ Size = Vector3.new(hs.X * 1.22, hs.Y * 1.2, hs.Z * 0.2), Color = color },
		CFrame.new(0, 0.05, hs.Z * 0.62)
	)
	for _, side in { -1, 1 } do
		add(
			ctx,
			"Head",
			"HoodSide",
			{ Size = Vector3.new(hs.X * 0.14, hs.Y * 1.15, hs.Z * 1.2), Color = color },
			CFrame.new(side * hs.X * 0.6, 0.02, 0.05)
		)
	end
	add(ctx, "Head", "HoodPeak", {
		Size = Vector3.new(hs.X * 1.2, hs.Y * 0.12, hs.Z * 0.25),
		Color = darker(color, 0.2),
	}, CFrame.new(0, hs.Y * 0.52, -hs.Z * 0.55) * CFrame.Angles(math.rad(15), 0, 0))
end

GEAR.Mask = function(ctx)
	local hs = size(ctx, "Head")
	add(ctx, "Head", "Mask", {
		Size = Vector3.new(hs.X * 1.04, hs.Y * 0.42, hs.Z * 0.15),
		Color = darker(ctx.Design.Leather, 0.3),
	}, CFrame.new(0, -hs.Y * 0.22, -hs.Z * 0.52))
end

GEAR.Collar = function(ctx)
	local ts = size(ctx, "UpperTorso")
	add(ctx, "UpperTorso", "Collar", {
		Size = Vector3.new(ts.X * 0.62, ts.Y * 0.22, ts.Z * 1.1),
		Color = darker(ctx.Design.Jacket, 0.2),
	}, CFrame.new(0, ts.Y * 0.52, 0))
end

GEAR.Harness = function(ctx)
	local ts = size(ctx, "UpperTorso")
	local leather = ctx.Design.Leather
	for _, side in { -1, 1 } do
		add(ctx, "UpperTorso", "HarnessStrap", {
			Size = Vector3.new(0.22, ts.Y * 1.15, 0.08),
			Color = leather,
			Material = Enum.Material.Leather,
		}, CFrame.new(side * ts.X * 0.05, 0, -ts.Z * 0.53) * CFrame.Angles(0, 0, math.rad(side * 28)))
		add(ctx, "UpperTorso", "HarnessBackStrap", {
			Size = Vector3.new(0.22, ts.Y * 1.1, 0.08),
			Color = leather,
			Material = Enum.Material.Leather,
		}, CFrame.new(side * ts.X * 0.25, 0, ts.Z * 0.53))
	end
	add(ctx, "UpperTorso", "HarnessBuckle", {
		Size = Vector3.new(0.3, 0.3, 0.1),
		Color = Color3.fromRGB(150, 140, 120),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, -ts.Y * 0.05, -ts.Z * 0.58))
	add(ctx, "UpperTorso", "ChestPouch", {
		Size = Vector3.new(0.4, 0.35, 0.15),
		Color = darker(leather, 0.15),
		Material = Enum.Material.Leather,
	}, CFrame.new(ts.X * 0.28, ts.Y * 0.2, -ts.Z * 0.58))
end

GEAR.Belt = function(ctx)
	local ls = size(ctx, "LowerTorso")
	add(ctx, "LowerTorso", "Belt", {
		Size = Vector3.new(ls.X * 1.05, 0.25, ls.Z * 1.08),
		Color = ctx.Design.Leather,
		Material = Enum.Material.Leather,
	}, CFrame.new(0, ls.Y * 0.3, 0))
	add(ctx, "LowerTorso", "BeltBuckle", {
		Size = Vector3.new(0.3, 0.22, 0.08),
		Color = Color3.fromRGB(160, 150, 130),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, ls.Y * 0.3, -ls.Z * 0.56))
	for _, side in { -1, 1 } do
		add(ctx, "LowerTorso", "BeltPouch", {
			Size = Vector3.new(0.35, 0.35, 0.28),
			Color = darker(ctx.Design.Leather, 0.2),
			Material = Enum.Material.Leather,
		}, CFrame.new(side * ls.X * 0.45, ls.Y * 0.05, -ls.Z * 0.2))
	end
end

GEAR.ThighStraps = function(ctx)
	for _, legName in { "LeftUpperLeg", "RightUpperLeg" } do
		local s = size(ctx, legName)
		add(ctx, legName, "ThighStrap", {
			Size = Vector3.new(s.X * 1.08, 0.18, s.Z * 1.08),
			Color = ctx.Design.Leather,
			Material = Enum.Material.Leather,
		}, CFrame.new(0, s.Y * 0.1, 0))
	end
	local s = size(ctx, "RightUpperLeg")
	add(ctx, "RightUpperLeg", "ThighPouch", {
		Size = Vector3.new(0.18, s.Y * 0.4, s.Z * 0.6),
		Color = darker(ctx.Design.Leather, 0.2),
		Material = Enum.Material.Leather,
	}, CFrame.new(s.X * 0.55, 0, 0))
end

GEAR.KneePads = function(ctx)
	for _, legName in { "LeftLowerLeg", "RightLowerLeg" } do
		local s = size(ctx, legName)
		add(ctx, legName, "KneePad", {
			Size = Vector3.new(s.X * 0.85, s.Y * 0.3, 0.15),
			Color = ctx.Design.Secondary,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(0, s.Y * 0.32, -s.Z * 0.55))
	end
end

GEAR.Backpack = function(ctx)
	local ts = size(ctx, "UpperTorso")
	local color = darker(ctx.Design.Secondary, 0.3)
	add(ctx, "UpperTorso", "Backpack", {
		Size = Vector3.new(ts.X * 0.8, ts.Y * 1.05, 0.7),
		Color = color,
	}, CFrame.new(0, -ts.Y * 0.05, ts.Z * 0.5 + 0.35))
	add(ctx, "UpperTorso", "BackpackFlap", {
		Size = Vector3.new(ts.X * 0.82, ts.Y * 0.3, 0.75),
		Color = darker(color, 0.2),
	}, CFrame.new(0, ts.Y * 0.38, ts.Z * 0.5 + 0.37))
	add(ctx, "UpperTorso", "BackpackRoll", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(ts.X * 0.95, 0.45, 0.45),
		Color = darker(ctx.Design.Leather, 0.1),
	}, CFrame.new(0, -ts.Y * 0.62, ts.Z * 0.5 + 0.35))
end

GEAR.WristDevice = function(ctx)
	local s = size(ctx, "LeftLowerArm")
	add(ctx, "LeftLowerArm", "WristBand", {
		Size = Vector3.new(s.X * 1.15, s.Y * 0.35, s.Z * 1.15),
		Color = Color3.fromRGB(40, 42, 46),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, -s.Y * 0.2, 0))
	local screen = add(ctx, "LeftLowerArm", "WristScreen", {
		Size = Vector3.new(0.08, s.Y * 0.25, s.Z * 0.6),
		Color = ctx.Design.Accent,
		Material = Enum.Material.Neon,
	}, CFrame.new(-s.X * 0.6, -s.Y * 0.2, 0))
	glow(screen, ctx.Design.Accent, 5, 1.2)
end

GEAR.ChestPlate = function(ctx)
	local ts = size(ctx, "UpperTorso")
	local color = ctx.Design.Secondary
	add(ctx, "UpperTorso", "ChestPlate", {
		Size = Vector3.new(ts.X * 0.85, ts.Y * 0.75, 0.2),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, ts.Y * 0.08, -ts.Z * 0.55))
	add(ctx, "UpperTorso", "BackPlate", {
		Size = Vector3.new(ts.X * 0.85, ts.Y * 0.75, 0.2),
		Color = darker(color, 0.1),
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, ts.Y * 0.08, ts.Z * 0.55))
end

GEAR.ShoulderPads = function(ctx)
	for _, armName in { "LeftUpperArm", "RightUpperArm" } do
		local s = size(ctx, armName)
		add(ctx, armName, "ShoulderPad", {
			Size = Vector3.new(s.X * 1.4, s.Y * 0.35, s.Z * 1.35),
			Color = ctx.Design.Secondary,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(0, s.Y * 0.38, 0))
	end
end

GEAR.GlowLines = function(ctx)
	local ts = size(ctx, "UpperTorso")
	local accent = ctx.Design.Accent
	for _, side in { -1, 1 } do
		add(ctx, "UpperTorso", "GlowLine", {
			Size = Vector3.new(0.06, ts.Y * 0.6, 0.06),
			Color = accent,
			Material = Enum.Material.Neon,
		}, CFrame.new(side * ts.X * 0.3, ts.Y * 0.05, -ts.Z * 0.68))
	end
	for _, legName in { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } do
		local s = size(ctx, legName)
		add(ctx, legName, "GlowLine", {
			Size = Vector3.new(0.06, s.Y * 0.8, 0.06),
			Color = accent,
			Material = Enum.Material.Neon,
		}, CFrame.new(0, 0, -s.Z * 0.53))
	end
end

GEAR.AmmoPouches = function(ctx)
	local ts = size(ctx, "UpperTorso")
	for i = -1, 1 do
		add(ctx, "UpperTorso", "AmmoPouch", {
			Size = Vector3.new(ts.X * 0.22, ts.Y * 0.28, 0.25),
			Color = darker(ctx.Design.Leather, 0.1),
			Material = Enum.Material.Leather,
		}, CFrame.new(i * ts.X * 0.26, -ts.Y * 0.28, -ts.Z * 0.68))
	end
end

GEAR.Beard = function(ctx)
	local hs = size(ctx, "Head")
	local color = ctx.Design.Hair
	add(ctx, "Head", "Beard", {
		Size = Vector3.new(hs.X * 0.9, hs.Y * 0.32, hs.Z * 0.18),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, -hs.Y * 0.32, -hs.Z * 0.48))
	for _, side in { -1, 1 } do
		add(ctx, "Head", "BeardSide", {
			Size = Vector3.new(hs.X * 0.12, hs.Y * 0.45, hs.Z * 0.6),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		}, CFrame.new(side * hs.X * 0.48, -hs.Y * 0.18, -hs.Z * 0.15))
	end
	add(ctx, "Head", "Moustache", {
		Size = Vector3.new(hs.X * 0.45, hs.Y * 0.08, hs.Z * 0.1),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, -hs.Y * 0.13, -hs.Z * 0.54))
end

GEAR.Glasses = function(ctx)
	local hs = size(ctx, "Head")
	local frameColor = Color3.fromRGB(26, 26, 30)
	for _, side in { -1, 1 } do
		add(ctx, "Head", "GlassesLens", {
			Size = Vector3.new(hs.X * 0.28, hs.Y * 0.18, 0.04),
			Color = Color3.fromRGB(190, 220, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.55,
		}, CFrame.new(side * hs.X * 0.18, hs.Y * 0.03, -hs.Z * 0.56))
		add(ctx, "Head", "GlassesRim", {
			Size = Vector3.new(hs.X * 0.3, 0.04, 0.05),
			Color = frameColor,
		}, CFrame.new(side * hs.X * 0.18, hs.Y * 0.12, -hs.Z * 0.56))
		add(ctx, "Head", "GlassesArm", {
			Size = Vector3.new(0.04, 0.04, hs.Z * 0.6),
			Color = frameColor,
		}, CFrame.new(side * hs.X * 0.5, hs.Y * 0.1, -hs.Z * 0.25))
	end
	add(ctx, "Head", "GlassesBridge", {
		Size = Vector3.new(hs.X * 0.1, 0.04, 0.05),
		Color = frameColor,
	}, CFrame.new(0, hs.Y * 0.06, -hs.Z * 0.56))
end

GEAR.LabCoat = function(ctx)
	local coat = ctx.Design.Secondary
	local ts = size(ctx, "UpperTorso")
	local ls = size(ctx, "LowerTorso")
	-- Open coat front over the shirt, plus back and collar.
	for _, side in { -1, 1 } do
		add(ctx, "UpperTorso", "CoatFront", {
			Size = Vector3.new(ts.X * 0.3, ts.Y * 1.02, ts.Z * 1.08),
			Color = coat,
		}, CFrame.new(side * ts.X * 0.36, 0, 0))
		add(ctx, "UpperTorso", "CoatLapel", {
			Size = Vector3.new(ts.X * 0.12, ts.Y * 0.4, 0.06),
			Color = darker(coat, 0.08),
		}, CFrame.new(side * ts.X * 0.18, ts.Y * 0.28, -ts.Z * 0.56) * CFrame.Angles(0, 0, math.rad(side * -15)))
		-- Coat tails down to the knees.
		add(ctx, "LowerTorso", "CoatTail", {
			Size = Vector3.new(ls.X * 0.48, 2.2, 0.12),
			Color = coat,
		}, CFrame.new(side * ls.X * 0.27, -1.0, -ls.Z * 0.56))
	end
	add(ctx, "LowerTorso", "CoatTailBack", {
		Size = Vector3.new(ls.X * 1.05, 2.2, 0.12),
		Color = coat,
	}, CFrame.new(0, -1.0, ls.Z * 0.56))
	add(ctx, "UpperTorso", "CoatBack", {
		Size = Vector3.new(ts.X * 1.04, ts.Y * 1.02, 0.12),
		Color = coat,
	}, CFrame.new(0, 0, ts.Z * 0.54))
	add(ctx, "UpperTorso", "CoatCollar", {
		Size = Vector3.new(ts.X * 0.7, 0.25, ts.Z * 1.1),
		Color = coat,
	}, CFrame.new(0, ts.Y * 0.5, 0.05))
	add(ctx, "UpperTorso", "IdBadge", {
		Size = Vector3.new(0.22, 0.3, 0.04),
		Color = Color3.fromRGB(150, 200, 255),
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(-ts.X * 0.36, ts.Y * 0.15, -ts.Z * 0.6))
end

GEAR.Tablet = function(ctx)
	local s = size(ctx, "RightHand")
	add(ctx, "RightHand", "Tablet", {
		Size = Vector3.new(0.08, 1.0, 0.75),
		Color = Color3.fromRGB(30, 32, 38),
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(-s.X * 0.4, 0, -0.1))
	local screen = add(ctx, "RightHand", "TabletScreen", {
		Size = Vector3.new(0.02, 0.85, 0.62),
		Color = ctx.Design.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	}, CFrame.new(-s.X * 0.4 - 0.05, 0, -0.1))
	glow(screen, ctx.Design.Accent, 4, 0.8)
end

GEAR.Helmet = function(ctx)
	local hs = size(ctx, "Head")
	add(ctx, "Head", "Helmet", {
		Size = Vector3.new(hs.X * 1.2, hs.Y * 1.15, hs.Z * 1.2),
		Color = darker(ctx.Design.Secondary, 0.25),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, hs.Y * 0.05, 0.02))
	local visor = add(ctx, "Head", "Visor", {
		Size = Vector3.new(hs.X * 1.0, hs.Y * 0.2, 0.08),
		Color = ctx.Design.Accent,
		Material = Enum.Material.Neon,
	}, CFrame.new(0, hs.Y * 0.08, -hs.Z * 0.63))
	glow(visor, ctx.Design.Accent, 6, 1.2)
	add(ctx, "Head", "Respirator", {
		Size = Vector3.new(hs.X * 0.5, hs.Y * 0.3, 0.2),
		Color = Color3.fromRGB(30, 30, 32),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, -hs.Y * 0.3, -hs.Z * 0.65))
end

GEAR.ChestCore = function(ctx)
	local ts = size(ctx, "UpperTorso")
	local core = add(ctx, "UpperTorso", "ChestCore", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.45,
		Color = ctx.Design.Accent,
		Material = Enum.Material.Neon,
	}, CFrame.new(0, ts.Y * 0.12, -ts.Z * 0.68))
	glow(core, ctx.Design.Accent, 8, 1.5)
end

GEAR.Crystals = function(ctx)
	-- Violet alien crystal growths breaking through the armour.
	local violet = Color3.fromRGB(170, 70, 255)
	local spots = {
		{ "UpperTorso", Vector3.new(0.35, 0.4, 0.5), -25 },
		{ "UpperTorso", Vector3.new(-0.3, 0.2, 0.55), 30 },
		{ "LeftUpperArm", Vector3.new(0, 0.45, 0), -40 },
	}
	for i, spot in spots do
		local s = size(ctx, spot[1] :: string)
		local rel = spot[2] :: Vector3
		add(
			ctx,
			spot[1] :: string,
			"Crystal" .. i,
			{
				Size = Vector3.new(0.18, 0.7, 0.18),
				Color = violet,
				Material = Enum.Material.Neon,
			},
			CFrame.new(rel.X * s.X, rel.Y * s.Y, rel.Z * s.Z)
				* CFrame.Angles(math.rad(spot[3] :: number), 0, math.rad(spot[3] :: number))
		)
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Removes everything a previous Apply added.
function Outfitter.Clear(model: Model)
	-- Outfit parts are always direct children of the model.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #PREFIX) == PREFIX then
			child:Destroy()
		end
	end
	local head = model:FindFirstChild("Head")
	local face = head and head:FindFirstChild("OutfitFace")
	if face then
		face:Destroy()
	end
end

-- Makes every part look like a projected hologram (Serra).
local function hologramify(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Material = Enum.Material.ForceField
			d.Color = d.Color:Lerp(color, 0.55)
			d.CastShadow = false
		end
	end
end

-- Dresses `model` (an R15 rig) as the given design. Returns false if the rig
-- is missing the parts needed.
function Outfitter.Apply(model: Model, design: Design): boolean
	-- A real, finished character model (for example a StarterCharacter made
	-- in Blender) is marked CustomModel and is never dressed with parts.
	if model:GetAttribute("CustomModel") == true then
		return false
	end
	Outfitter.Clear(model)
	-- Avatar clothing and accessories never belong on a designed character.
	for _, child in model:GetChildren() do
		if
			child:IsA("Accessory")
			or child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("BodyColors")
		then
			child:Destroy()
		end
	end

	local parts: { [string]: BasePart } = {}
	for name in BODY_COLORS do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			parts[name] = part
		end
	end
	if not parts.Head or not parts.UpperTorso or not parts.LowerTorso then
		return false
	end

	for name, part in parts do
		part.Color = (design :: any)[BODY_COLORS[name]]
	end

	local ctx: Ctx = { Model = model, Design = design, Parts = parts }
	local hairBuilder = HAIR_BUILDERS[design.HairStyle]
	if hairBuilder then
		hairBuilder(ctx, parts.Head.Size)
	end
	drawFace(ctx)
	for _, gearName in design.Gear do
		local builder = GEAR[gearName]
		if builder then
			builder(ctx)
		else
			warn("[Outfitter] Unknown gear piece:", gearName)
		end
	end
	if design.Hologram then
		hologramify(model, design.Accent)
	end
	model:SetAttribute("Outfit", design.Id)
	return true
end

return Outfitter
