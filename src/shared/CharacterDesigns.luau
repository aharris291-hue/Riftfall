--!strict
-- CharacterDesigns: the look of every character, taken from the Riftfall
-- character concept sheet. Pure data (colours, hair style, which gear pieces
-- to attach); the server's Outfitter turns it into parts on an R15 body.
--
-- To restyle a character, change colours or the Gear list here. Gear names
-- must match a builder in src/server/Util/Outfitter.luau.

export type Design = {
	Id: string,
	DisplayName: string,
	Title: string,
	Skin: Color3,
	Hair: Color3,
	HairStyle: "Messy" | "Bun" | "Short" | "Bob" | "None",
	Eyes: Color3,
	-- Body part colours.
	Jacket: Color3,
	Sleeves: Color3,
	Gloves: Color3,
	Trousers: Color3,
	Boots: Color3,
	-- Detail colours used by gear pieces.
	Leather: Color3,
	Accent: Color3, -- Glowing tech accent (wrist device, visor, core).
	Secondary: Color3,
	Gear: { string },
	-- Optional body proportions (1 = default).
	Width: number?,
	Height: number?,
	Hologram: boolean?, -- Serra is projected, not physically present.
}

local CYAN = Color3.fromRGB(70, 220, 255)

local Designs: { [string]: Design } = {}

-- Protagonist: Jax Mercer. An ordinary person who survives a catastrophe;
-- determined, resourceful, haunted. Dark hooded jacket, brown leather
-- harness and belts, cargo trousers with knee pads, cyan wrist device.
Designs.Jax = {
	Id = "Jax",
	DisplayName = "Jax Mercer",
	Title = "Default Outfit",
	Skin = Color3.fromRGB(226, 182, 150),
	Hair = Color3.fromRGB(74, 50, 34),
	HairStyle = "Messy",
	Eyes = Color3.fromRGB(70, 52, 40),
	Jacket = Color3.fromRGB(46, 48, 54),
	Sleeves = Color3.fromRGB(40, 42, 48),
	Gloves = Color3.fromRGB(30, 30, 32),
	Trousers = Color3.fromRGB(52, 52, 56),
	Boots = Color3.fromRGB(78, 54, 36),
	Leather = Color3.fromRGB(96, 64, 40),
	Accent = CYAN,
	Secondary = Color3.fromRGB(70, 72, 78),
	Gear = { "HoodDown", "Collar", "Harness", "Belt", "ThighStraps", "KneePads", "Backpack", "WristDevice" },
}

-- Jax's alternate outfits (concept sheet: "Alternate Outfits" and
-- "Character Variants"). Each player picks one with the Outfit button.
Designs.JaxStealth = table.clone(Designs.Jax)
Designs.JaxStealth.Id = "JaxStealth"
Designs.JaxStealth.Title = "Stealth"
Designs.JaxStealth.Jacket = Color3.fromRGB(28, 28, 36)
Designs.JaxStealth.Sleeves = Color3.fromRGB(24, 24, 30)
Designs.JaxStealth.Trousers = Color3.fromRGB(30, 30, 38)
Designs.JaxStealth.Boots = Color3.fromRGB(26, 26, 30)
Designs.JaxStealth.Leather = Color3.fromRGB(44, 44, 54)
Designs.JaxStealth.Accent = Color3.fromRGB(150, 110, 255)
Designs.JaxStealth.Gear = { "HoodUp", "Mask", "Harness", "Belt", "ThighStraps", "KneePads", "WristDevice" }

Designs.JaxSurvival = table.clone(Designs.Jax)
Designs.JaxSurvival.Id = "JaxSurvival"
Designs.JaxSurvival.Title = "Survival"
Designs.JaxSurvival.Jacket = Color3.fromRGB(196, 150, 48)
Designs.JaxSurvival.Sleeves = Color3.fromRGB(184, 140, 44)
Designs.JaxSurvival.Trousers = Color3.fromRGB(58, 56, 52)
Designs.JaxSurvival.Accent = Color3.fromRGB(255, 170, 60)
Designs.JaxSurvival.Gear = { "HoodDown", "Collar", "Harness", "Belt", "KneePads", "Backpack", "WristDevice" }

Designs.JaxWanderer = table.clone(Designs.Jax)
Designs.JaxWanderer.Id = "JaxWanderer"
Designs.JaxWanderer.Title = "Wanderer"
Designs.JaxWanderer.Jacket = Color3.fromRGB(110, 82, 58)
Designs.JaxWanderer.Sleeves = Color3.fromRGB(98, 72, 50)
Designs.JaxWanderer.Trousers = Color3.fromRGB(70, 60, 50)
Designs.JaxWanderer.Leather = Color3.fromRGB(70, 48, 32)
Designs.JaxWanderer.Gear = { "HoodUp", "Collar", "Harness", "Belt", "ThighStraps", "Backpack", "WristDevice" }

Designs.JaxHeavy = table.clone(Designs.Jax)
Designs.JaxHeavy.Id = "JaxHeavy"
Designs.JaxHeavy.Title = "Heavy Armor"
Designs.JaxHeavy.Jacket = Color3.fromRGB(70, 72, 76)
Designs.JaxHeavy.Sleeves = Color3.fromRGB(58, 60, 64)
Designs.JaxHeavy.Secondary = Color3.fromRGB(96, 98, 104)
Designs.JaxHeavy.Gear = { "Collar", "ChestPlate", "ShoulderPads", "Belt", "KneePads", "Backpack", "WristDevice" }

-- Serra, the AI companion: projected as a cyan hologram. White and grey
-- armour with glowing lines over a dark suit, blue bob.
Designs.Serra = {
	Id = "Serra",
	DisplayName = "Serra",
	Title = "The AI Companion",
	Skin = Color3.fromRGB(200, 226, 240),
	Hair = Color3.fromRGB(40, 110, 220),
	HairStyle = "Bob",
	Eyes = CYAN,
	Jacket = Color3.fromRGB(226, 232, 238),
	Sleeves = Color3.fromRGB(30, 34, 44),
	Gloves = Color3.fromRGB(220, 226, 232),
	Trousers = Color3.fromRGB(210, 216, 224),
	Boots = Color3.fromRGB(226, 232, 238),
	Leather = Color3.fromRGB(30, 34, 44),
	Accent = CYAN,
	Secondary = Color3.fromRGB(180, 188, 200),
	Gear = { "ChestPlate", "ShoulderPads", "GlowLines", "Belt" },
	Width = 0.92,
	Hologram = true,
}

-- Kade, the veteran: a former elite soldier. Bearded, heavy brown tactical
-- armour, ammo pouches. Practical, loyal, carries a personal vendetta.
Designs.Kade = {
	Id = "Kade",
	DisplayName = "Kade",
	Title = "The Veteran",
	Skin = Color3.fromRGB(190, 140, 104),
	Hair = Color3.fromRGB(46, 34, 26),
	HairStyle = "Short",
	Eyes = Color3.fromRGB(50, 40, 32),
	Jacket = Color3.fromRGB(86, 70, 52),
	Sleeves = Color3.fromRGB(62, 58, 50),
	Gloves = Color3.fromRGB(36, 34, 30),
	Trousers = Color3.fromRGB(70, 66, 56),
	Boots = Color3.fromRGB(46, 36, 28),
	Leather = Color3.fromRGB(80, 58, 38),
	Accent = Color3.fromRGB(255, 190, 90),
	Secondary = Color3.fromRGB(104, 96, 78),
	Gear = { "Beard", "ChestPlate", "ShoulderPads", "AmmoPouches", "Belt", "ThighStraps", "KneePads", "Backpack" },
	Width = 1.12,
	Height = 1.04,
}

-- Lira, the scientist: brilliant researcher. Dark hair in a bun, glasses,
-- long white lab coat over a lavender shirt. Curious, cautious, brave.
Designs.Lira = {
	Id = "Lira",
	DisplayName = "Lira",
	Title = "The Scientist",
	Skin = Color3.fromRGB(236, 200, 172),
	Hair = Color3.fromRGB(28, 24, 30),
	HairStyle = "Bun",
	Eyes = Color3.fromRGB(60, 46, 40),
	Jacket = Color3.fromRGB(176, 150, 200),
	Sleeves = Color3.fromRGB(232, 232, 236),
	Gloves = Color3.fromRGB(70, 74, 84),
	Trousers = Color3.fromRGB(46, 48, 58),
	Boots = Color3.fromRGB(36, 36, 40),
	Leather = Color3.fromRGB(60, 60, 70),
	Accent = Color3.fromRGB(150, 210, 255),
	Secondary = Color3.fromRGB(236, 236, 240),
	Gear = { "Glasses", "LabCoat", "Belt", "Tablet" },
	Width = 0.92,
	Height = 0.97,
}

-- Corrupted Soldier: human, enhanced with alien tech. Dark grey heavy armour,
-- helmet with a red visor, glowing red chest core.
Designs.CorruptedSoldier = {
	Id = "CorruptedSoldier",
	DisplayName = "Corrupted Soldier",
	Title = "Human Faction",
	Skin = Color3.fromRGB(110, 104, 110),
	Hair = Color3.fromRGB(30, 30, 30),
	HairStyle = "None",
	Eyes = Color3.fromRGB(255, 40, 30),
	Jacket = Color3.fromRGB(52, 54, 58),
	Sleeves = Color3.fromRGB(44, 46, 50),
	Gloves = Color3.fromRGB(34, 34, 36),
	Trousers = Color3.fromRGB(46, 48, 52),
	Boots = Color3.fromRGB(30, 30, 32),
	Leather = Color3.fromRGB(70, 46, 40),
	Accent = Color3.fromRGB(255, 50, 40),
	Secondary = Color3.fromRGB(76, 78, 84),
	Gear = { "Helmet", "ChestPlate", "ChestCore", "ShoulderPads", "Belt", "AmmoPouches", "KneePads", "Crystals" },
	Width = 1.15,
	Height = 1.06,
}

return {
	Designs = Designs,
	-- The order the Outfit button cycles through.
	PlayerOutfits = { "Jax", "JaxStealth", "JaxSurvival", "JaxWanderer", "JaxHeavy" },
}
