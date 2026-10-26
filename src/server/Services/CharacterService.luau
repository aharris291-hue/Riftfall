--!strict
-- CharacterService: dresses every player as an expedition member instead of
-- their normal Roblox avatar. (StarterPlayer.LoadCharacterAppearance is off in
-- default.project.json, so avatar clothes and accessories never load.)
--
-- Each player gets an outfit from OUTFITS (picked from their UserId, so it is
-- the same every time they play and co-op partners look different) plus
-- expedition gear built from parts: field hat, backpack with bedroll,
-- harness, scarf, belt with pouches and radio, and boots.
--
-- Everything is placeholder geometry welded to the body. A real 3D outfit
-- (meshes or layered clothing you own) can replace it later.

local Players = game:GetService("Players")

local CharacterService = {}

type Outfit = {
	Role: string,
	Jacket: Color3,
	Sleeves: Color3,
	Trousers: Color3,
	Boots: Color3,
	Hat: Color3,
	Pack: Color3,
	Scarf: Color3,
}

local OUTFITS: { Outfit } = {
	{
		Role = "Scout",
		Jacket = Color3.fromRGB(92, 104, 64),
		Sleeves = Color3.fromRGB(78, 88, 54),
		Trousers = Color3.fromRGB(150, 128, 92),
		Boots = Color3.fromRGB(52, 38, 28),
		Hat = Color3.fromRGB(138, 112, 74),
		Pack = Color3.fromRGB(120, 60, 40),
		Scarf = Color3.fromRGB(178, 66, 48),
	},
	{
		Role = "Surveyor",
		Jacket = Color3.fromRGB(176, 92, 44),
		Sleeves = Color3.fromRGB(150, 78, 38),
		Trousers = Color3.fromRGB(70, 74, 64),
		Boots = Color3.fromRGB(40, 32, 28),
		Hat = Color3.fromRGB(62, 70, 54),
		Pack = Color3.fromRGB(64, 80, 92),
		Scarf = Color3.fromRGB(214, 190, 120),
	},
	{
		Role = "Medic",
		Jacket = Color3.fromRGB(58, 80, 110),
		Sleeves = Color3.fromRGB(48, 66, 92),
		Trousers = Color3.fromRGB(120, 112, 96),
		Boots = Color3.fromRGB(46, 36, 30),
		Hat = Color3.fromRGB(170, 160, 132),
		Pack = Color3.fromRGB(150, 150, 142),
		Scarf = Color3.fromRGB(200, 60, 60),
	},
	{
		Role = "Climber",
		Jacket = Color3.fromRGB(196, 168, 60),
		Sleeves = Color3.fromRGB(70, 70, 74),
		Trousers = Color3.fromRGB(54, 58, 66),
		Boots = Color3.fromRGB(36, 30, 26),
		Hat = Color3.fromRGB(80, 60, 44),
		Pack = Color3.fromRGB(90, 110, 70),
		Scarf = Color3.fromRGB(60, 110, 140),
	},
}

local SKIN_TONES = {
	Color3.fromRGB(234, 192, 160),
	Color3.fromRGB(198, 146, 108),
	Color3.fromRGB(156, 104, 72),
	Color3.fromRGB(112, 74, 52),
	Color3.fromRGB(76, 52, 40),
}

local LIMB_COLORS: { [string]: string } = {
	UpperTorso = "Jacket",
	LowerTorso = "Trousers",
	LeftUpperArm = "Sleeves",
	RightUpperArm = "Sleeves",
	LeftLowerArm = "Sleeves",
	RightLowerArm = "Sleeves",
	LeftUpperLeg = "Trousers",
	RightUpperLeg = "Trousers",
	LeftLowerLeg = "Trousers",
	RightLowerLeg = "Trousers",
	LeftFoot = "Boots",
	RightFoot = "Boots",
	-- R6 fallback names.
	Torso = "Jacket",
	["Left Arm"] = "Sleeves",
	["Right Arm"] = "Sleeves",
	["Left Leg"] = "Trousers",
	["Right Leg"] = "Trousers",
}
local SKIN_PARTS = { "Head", "LeftHand", "RightHand" }

function CharacterService.GetOutfit(player: Player): Outfit
	return OUTFITS[(player.UserId % #OUTFITS) + 1]
end

-- Welds a decorative part to `body` at `offset` (relative to the body part).
local function gear(body: BasePart, name: string, props: { [string]: any }, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "Gear_" .. name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Fabric
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = body.Parent
	return p
end

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name) or character:WaitForChild(name, 5)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function dress(player: Player, character: Model)
	local outfit = CharacterService.GetOutfit(player)
	local skin = SKIN_TONES[(math.floor(player.UserId / #OUTFITS) % #SKIN_TONES) + 1]

	-- Remove anything avatar-related that might still have loaded.
	for _, child in character:GetChildren() do
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

	local head = findPart(character, { "Head" })
	local torso = findPart(character, { "UpperTorso", "Torso" })
	local hips = findPart(character, { "LowerTorso", "Torso" })
	if not head or not torso or not hips or character.Parent == nil then
		return
	end

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local key = LIMB_COLORS[part.Name]
			if key then
				part.Color = (outfit :: any)[key]
			elseif table.find(SKIN_PARTS, part.Name) then
				part.Color = skin
			end
		end
	end

	local hs, ts, ls = head.Size, torso.Size, hips.Size

	-- Field hat: wide brim and a crown with a band.
	local brimY = hs.Y / 2 + 0.05
	gear(head, "HatBrim", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, hs.X * 1.9, hs.X * 1.9),
		Color = outfit.Hat,
	}, CFrame.new(0, brimY, 0) * CFrame.Angles(0, 0, math.rad(90)))
	gear(head, "HatCrown", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(hs.Y * 0.5, hs.X * 1.1, hs.X * 1.1),
		Color = outfit.Hat,
	}, CFrame.new(0, brimY + hs.Y * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)))
	gear(head, "HatBand", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, hs.X * 1.13, hs.X * 1.13),
		Color = outfit.Scarf,
	}, CFrame.new(0, brimY + 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)))

	-- Scarf around the neck.
	gear(torso, "Scarf", {
		Size = Vector3.new(ts.X * 0.75, 0.3, ts.Z * 1.15),
		Color = outfit.Scarf,
	}, CFrame.new(0, ts.Y / 2 - 0.05, 0))
	gear(torso, "ScarfTail", {
		Size = Vector3.new(0.35, 0.8, 0.1),
		Color = outfit.Scarf,
	}, CFrame.new(ts.X * 0.18, ts.Y / 2 - 0.5, -ts.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(-8)))

	-- Harness straps across the chest (front is -Z).
	for _, side in { -1, 1 } do
		gear(torso, "Strap", {
			Size = Vector3.new(0.22, ts.Y * 1.02, 0.08),
			Color = Color3.fromRGB(46, 40, 34),
			Material = Enum.Material.Leather,
		}, CFrame.new(side * ts.X * 0.28, 0, -ts.Z / 2 - 0.04))
	end
	gear(torso, "ChestPocket", {
		Size = Vector3.new(0.45, 0.4, 0.12),
		Color = outfit.Sleeves,
	}, CFrame.new(-ts.X * 0.22, ts.Y * 0.12, -ts.Z / 2 - 0.08))

	-- Backpack with a rolled bedroll on top (back is +Z).
	local packDepth = 0.75
	gear(torso, "Backpack", {
		Size = Vector3.new(ts.X * 0.85, ts.Y * 1.1, packDepth),
		Color = outfit.Pack,
		Material = Enum.Material.Fabric,
	}, CFrame.new(0, -0.05, ts.Z / 2 + packDepth / 2))
	gear(torso, "PackPocket", {
		Size = Vector3.new(ts.X * 0.6, ts.Y * 0.4, 0.2),
		Color = outfit.Pack:Lerp(Color3.new(0, 0, 0), 0.25),
	}, CFrame.new(0, -ts.Y * 0.2, ts.Z / 2 + packDepth + 0.1))
	gear(torso, "Bedroll", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(ts.X * 1.05, 0.55, 0.55),
		Color = Color3.fromRGB(96, 110, 80),
	}, CFrame.new(0, ts.Y * 0.6 + 0.2, ts.Z / 2 + packDepth / 2))

	-- Belt with pouches and a field radio.
	gear(hips, "Belt", {
		Size = Vector3.new(ls.X * 1.04, 0.22, ls.Z * 1.06),
		Color = Color3.fromRGB(58, 46, 36),
		Material = Enum.Material.Leather,
	}, CFrame.new(0, ls.Y / 2 - 0.08, 0))
	for _, side in { -1, 1 } do
		gear(hips, "Pouch", {
			Size = Vector3.new(0.35, 0.35, 0.25),
			Color = outfit.Trousers:Lerp(Color3.new(0, 0, 0), 0.35),
		}, CFrame.new(side * ls.X * 0.38, 0, -ls.Z / 2 - 0.1))
	end
	gear(hips, "Radio", {
		Size = Vector3.new(0.25, 0.5, 0.35),
		Color = Color3.fromRGB(40, 42, 40),
		Material = Enum.Material.Metal,
	}, CFrame.new(ls.X / 2 + 0.12, 0, 0))
	local antenna = gear(hips, "RadioAntenna", {
		Size = Vector3.new(0.05, 0.6, 0.05),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
	}, CFrame.new(ls.X / 2 + 0.12, 0.5, 0.08))
	gear(hips, "RadioLight", {
		Size = Vector3.new(0.08, 0.08, 0.08),
		Color = Color3.fromRGB(90, 255, 120),
		Material = Enum.Material.Neon,
	}, CFrame.new(ls.X / 2 + 0.12, 0.27, -0.1))
	antenna.CastShadow = false

	-- Boot cuffs.
	for _, footName in { "LeftFoot", "RightFoot" } do
		local foot = character:FindFirstChild(footName)
		if foot and foot:IsA("BasePart") then
			gear(foot, "BootCuff", {
				Size = foot.Size * Vector3.new(1.08, 0.5, 1.08),
				Color = outfit.Boots:Lerp(Color3.new(1, 1, 1), 0.1),
				Material = Enum.Material.Leather,
			}, CFrame.new(0, foot.Size.Y * 0.4, 0))
		end
	end

	character:SetAttribute("ExpeditionRole", outfit.Role)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = player.DisplayName .. " - " .. outfit.Role
	end
end

CharacterService.Dress = dress

function CharacterService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			dress(player, character)
		end)
		if player.Character then
			task.spawn(dress, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CharacterService
