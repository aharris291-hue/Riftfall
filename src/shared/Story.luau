--!strict
-- Story: all player-facing writing for the Chapter 1 demo in one place:
-- objectives, radio dialogue, and readable notes. Edit text here freely.

export type Line = {
	Speaker: string,
	Text: string,
	Duration: number,
}

local Story = {}

Story.Objectives = {
	Start = "Follow the trail north toward the distress signal",
	Camp = "Search the abandoned expedition camp",
	Gate = "Get through the chained ruins gate. Kade has bolt cutters",
	Ruins = "Cross the ruins and enter the temple. Stay out of sight.",
	Puzzle = "Open the sealed temple door",
	Escape = "The temple is collapsing. GET OUT!",
	Bridge = "Climb the cliff and cross the bridge to the flare",
	Done = "Signal reached. Chapter 1 demo complete.",
	-- Chapter 2: Blackstone Research Facility
	C2Start = "Get inside Blackstone. Find out what happened here",
	C2Power = "The security door has no power. Find the generator room",
	C2Fuses = "Restore power: put 2 fuses in the panel, set the breakers, pull the lever",
	C2Escape = "Something got out. Reach the elevator at the end of the corridor",
	C2Done = "Elevator reached. Chapter 2 complete.",
	-- Chapter 3: The Sunken Temple
	C3Start = "Go deeper into the Sunken Temple",
	C3Plates = "Open the sanctum: step on the symbol plates in the right order",
	C3Heart = "Enter the sanctum and find the source of the Rift",
	C3Escape = "The temple is flooding! Climb the vines to the ledge and get out",
	C3Done = "You escaped the Sunken Temple. Chapter 3 complete.",
}

-- Cast (from the character concept sheet):
--   Jax Mercer  the player. An ordinary survivor of the helicopter crash.
--   Serra       the AI companion who lives in Jax's wrist unit (comms).
--   Kade        the veteran. His brother Daniel was on the Rourke expedition.
--   Lira        the expedition scientist, studying the Vael ruins.
Story.Dialogue = {
	Intro = {
		{
			Speaker = "SERRA (AI)",
			Text = "Jax. Wake up. Your vitals are stable. The helicopter's are not.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "The distress signal is still broadcasting, north of the crash, past the old trail.",
			Duration = 4.5,
		},
		{ Speaker = "SERRA (AI)", Text = "Same frequency the Rourke expedition used. Twelve years ago.", Duration = 4 },
		{
			Speaker = "SERRA (AI)",
			Text = "Press F for your flashlight. Batteries are limited. I did the maths.",
			Duration = 4,
		},
	},
	ClawMarks = {
		{
			Speaker = "SERRA (AI)",
			Text = "Scanning those marks... No animal on record makes cuts like that. I would like to leave now.",
			Duration = 4.5,
		},
	},
	Camp = {
		{
			Speaker = "KADE",
			Text = "Easy! Hands where I can see them... You're from the chopper. Name's Kade.",
			Duration = 4.5,
		},
		{
			Speaker = "KADE",
			Text = "This was Rourke's camp. My brother Daniel came out here with him. Never came back.",
			Duration = 5,
		},
		{
			Speaker = "KADE",
			Text = "Leg's busted, so I'm holding this camp. Grab what you need. Read the journal on the table.",
			Duration = 5,
		},
		{
			Speaker = "KADE",
			Text = "Heading for the ruins? Gate's chained. Come talk to me first.",
			Duration = 4,
		},
	},
	Sighting = {
		{
			Speaker = "SERRA (AI)",
			Text = "Jax. Stop. Something just crossed the trail ahead. It flickered... like it wasn't fully here.",
			Duration = 5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "It's gone. Not dead, not hiding. Gone. I hate this place.",
			Duration = 4,
		},
	},
	Gate = {
		{
			Speaker = "SERRA (AI)",
			Text = "Heavy chain, new padlock. Someone sealed the ruins after Rourke's team went in.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Kade's camp is right behind us. He might have something to cut it.",
			Duration = 4,
		},
	},
	KadeCutters = {
		{
			Speaker = "KADE",
			Text = "The gate? Here, take my bolt cutters. I sealed it myself after I heard that thing.",
			Duration = 4.5,
		},
		{
			Speaker = "KADE",
			Text = "Take a flare too. Throw one and that thing goes to see what's burning. Buys you time.",
			Duration = 4.5,
		},
	},
	GateOpen = {
		{
			Speaker = "SERRA (AI)",
			Text = "Chain's off. Ruins ahead. From here on, we move quietly.",
			Duration = 3.5,
		},
	},
	Ruins = {
		{
			Speaker = "SERRA (AI)",
			Text = "Movement in the ruins ahead. Large. Bipedal. Its energy signature is... not from here.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "It hunts by sound. Press C to crouch and stay in the tall grass.",
			Duration = 4.5,
		},
	},
	Temple = {
		{ Speaker = "LIRA", Text = "Shh! Over here. Lira, expedition science team. You must be Jax.", Duration = 4.5 },
		{
			Speaker = "LIRA",
			Text = "That door is Vael. Three dials. The mural shows the first and last symbols.",
			Duration = 4.5,
		},
		{
			Speaker = "LIRA",
			Text = "Rourke's journal had the middle one. Did you find it? I'll keep watch.",
			Duration = 4,
		},
	},
	Solved = {
		{
			Speaker = "SERRA (AI)",
			Text = "Door's opening. Jax, energy readings just went off the scale. The mountain is moving.",
			Duration = 4,
		},
		{
			Speaker = "LIRA",
			Text = "It's coming for the door! Run! Kade and I will meet you at the flare!",
			Duration = 4,
		},
	},
	Bridge = {
		{
			Speaker = "SERRA (AI)",
			Text = "Climb. That bridge has a structural rating of 'please hurry'.",
			Duration = 3.5,
		},
	},
	Done = {
		{
			Speaker = "KADE",
			Text = "Got you! Lira, help me pull Jax up. Welcome to the worst expedition on Earth.",
			Duration = 4.5,
		},
		{
			Speaker = "LIRA",
			Text = "That thing wasn't hunting us. It was guarding something. We need to go back down.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Recording everything. Chapter one, Jax. I don't think it's the last.",
			Duration = 4,
		},
	},
	TalkSerra = {
		{
			Speaker = "SERRA (AI)",
			Text = "I'm the AI in your wrist unit. Think of me as your very honest co-pilot.",
			Duration = 4,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Head north up the trail. Stay off the open ground if you hear anything big.",
			Duration = 4,
		},
	},
	TalkKade = {
		{
			Speaker = "KADE",
			Text = "Use the bandages when it counts, not before. And never let that thing see you run.",
			Duration = 4.5,
		},
		{
			Speaker = "KADE",
			Text = "If you find anything of Daniel's out there... bring it back. Please.",
			Duration = 4,
		},
	},
	TalkLira = {
		{
			Speaker = "LIRA",
			Text = "The shards hum near the Rift. Rourke thought the Vael sealed something in.",
			Duration = 4.5,
		},
		{
			Speaker = "LIRA",
			Text = "Mural first, journal second. Left to right. Eye... and Sun, I think.",
			Duration = 4,
		},
	},
	DoneDaniel = {
		{
			Speaker = "KADE",
			Text = "That tag... Daniel Kade. That's my brother's. Where did you...",
			Duration = 4.5,
		},
		{
			Speaker = "KADE",
			Text = "Twelve years I've been looking. Thank you, Jax. Whatever's down there, I'm going with you.",
			Duration = 5,
		},
	},
	TalkKadeEnd = {
		{
			Speaker = "KADE",
			Text = "We hold here until the rescue team spots the flare. You did good, kid.",
			Duration = 4,
		},
	},
	TalkLiraEnd = {
		{
			Speaker = "LIRA",
			Text = "If you found a Rift Shard, keep it safe. It might tell us what's down there.",
			Duration = 4,
		},
	},
	-- Chapter 2: Blackstone Research Facility
	C2Intro = {
		{
			Speaker = "SERRA (AI)",
			Text = "The signal came from here. Blackstone Research. Officially, this place does not exist.",
			Duration = 4.5,
		},
		{
			Speaker = "KADE",
			Text = "Lira and I will hold the entrance. Get the doors working and find us a way up.",
			Duration = 4.5,
		},
	},
	C2Lobby = {
		{
			Speaker = "SERRA (AI)",
			Text = "Main power is down. Only emergency lights. The security door won't move without power.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Maintenance is to the west. Storage to the east. Look for fuses.",
			Duration = 4,
		},
	},
	C2DoorLocked = {
		{ Speaker = "SERRA (AI)", Text = "No power to the door. We need the generator running.", Duration = 3.5 },
	},
	C2Tunnel = {
		{
			Speaker = "SERRA (AI)",
			Text = "Scratches on the pipes. Fresh ones. I am choosing to believe they are from rats.",
			Duration = 4,
		},
	},
	C2Generator = {
		{
			Speaker = "LIRA",
			Text = "(radio) Jax, that panel needs two fuses. And check the breakers before you pull the lever.",
			Duration = 4.5,
		},
		{
			Speaker = "LIRA",
			Text = "(radio) Wrong settings will short something out. Look for an engineer's note.",
			Duration = 4,
		},
	},
	C2WrongBreakers = {
		{
			Speaker = "SERRA (AI)",
			Text = "The generator coughed and died. Wrong breaker settings. Something in the dark heard that.",
			Duration = 4.5,
		},
	},
	C2Power = {
		{ Speaker = "SERRA (AI)", Text = "Power's back! Security door is open.", Duration = 3 },
		{
			Speaker = "SERRA (AI)",
			Text = "Wait. The power surge just opened every door in the building. Including the containment cells.",
			Duration = 4.5,
		},
	},
	C2Breakout = {
		{ Speaker = "LIRA", Text = "(radio) Jax, something just tore through Lab 2! Get to the elevator. NOW!", Duration = 4 },
		{
			Speaker = "SERRA (AI)",
			Text = "Lockers in the corridor. Crouch in front of one and it can't see you.",
			Duration = 4,
		},
	},
	C2Corridor = {
		{
			Speaker = "SERRA (AI)",
			Text = "Elevator at the far end. Hold the call button. It will take a few seconds. Make them count.",
			Duration = 4.5,
		},
	},
	C2ElevatorNoPower = {
		{ Speaker = "SERRA (AI)", Text = "The elevator's dead. No power.", Duration = 3 },
	},
	C2Done = {
		{
			Speaker = "KADE",
			Text = "(radio) We see the elevator lights. Ride it up, kid. We'll meet you at the top.",
			Duration = 4.5,
		},
		{
			Speaker = "LIRA",
			Text = "(radio) Those cells... Blackstone didn't find that creature. They were growing it.",
			Duration = 4.5,
		},
	},
	-- Chapter 3: The Sunken Temple
	C3Intro = {
		{
			Speaker = "LIRA",
			Text = "(radio) The elevator shaft goes past the labs, Jax. Down into the old Vael temple.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Blackstone built on top of it. They were digging toward the same thing the Vael buried.",
			Duration = 4.5,
		},
	},
	C3Entrance = {
		{ Speaker = "SERRA (AI)", Text = "Water ahead. Mind the stones. I am not waterproof. Well, I am. You are not.", Duration = 4.5 },
	},
	C3Gallery = {
		{
			Speaker = "LIRA",
			Text = "(radio) The Vael always hid their keys. Look for a wall that doesn't belong.",
			Duration = 4,
		},
	},
	C3Hidden = {
		{
			Speaker = "LIRA",
			Text = "(radio) A secret chamber! Read the tablet. Those plates out there need an order.",
			Duration = 4,
		},
	},
	C3Creature = {
		{
			Speaker = "SERRA (AI)",
			Text = "It followed us down. Every plate you step on will grind. It will hear that.",
			Duration = 4.5,
		},
		{
			Speaker = "SERRA (AI)",
			Text = "Hide in the alcoves by the statues if it gets close. Crouch.",
			Duration = 4,
		},
	},
	C3GateOpen = {
		{ Speaker = "SERRA (AI)", Text = "The sanctum is open. That energy reading is... the same as the creature's.", Duration = 4.5 },
	},
	C3Sanctum = {
		{
			Speaker = "LIRA",
			Text = "(radio) Jax, describe what you see. Slowly. I want to remember every word of this.",
			Duration = 4.5,
		},
	},
	C3Heart = {
		{ Speaker = "SERRA (AI)", Text = "It's warm. It's... beating. Jax, this isn't a rock. It's an organ.", Duration = 4.5 },
	},
	C3Flood = {
		{
			Speaker = "SERRA (AI)",
			Text = "The seals are breaking! Water is coming in. Climb the vines to the ledge. Go!",
			Duration = 4,
		},
	},
	C3Done = {
		{
			Speaker = "LIRA",
			Text = "(radio) The Vael didn't worship the Rift. They fed it, to keep it asleep. And we woke it up.",
			Duration = 5,
		},
		{
			Speaker = "KADE",
			Text = "(radio) Then we finish this at the top. The mountain path is open. We go up together.",
			Duration = 4.5,
		},
	},
}

-- Optional evidence: ID tags from the lost Rourke expedition, hidden around
-- the level. They are shown like notes but counted separately on the
-- results screen, and finding Daniel's tag changes the ending.
Story.Evidence = { "TagOkafor", "TagHale", "TagReyes", "TagDaniel" }

-- Readable notes found in the world. The camp journal holds the puzzle clue.
Story.Notes = {
	TagOkafor = {
		Title = "ID tag: Dr. Amara Okafor",
		Body = 'ROURKE EXPEDITION - GEOLOGY\nDr. Amara Okafor\n\nScratched on the back, very small:\n"The ground here is warm at night. Rock shouldn\'t be warm."',
	},
	TagHale = {
		Title = "ID tag: Tomas Hale",
		Body = "ROURKE EXPEDITION - PILOT\nTomas Hale\n\nThe chain has been snapped, not unclasped. Something pulled it off.",
	},
	TagReyes = {
		Title = "ID tag: Inez Reyes",
		Body = 'ROURKE EXPEDITION - RADIO\nInez Reyes\n\nThe tag is bent, as if someone gripped it very hard. On the back:\n"Signal isn\'t ours. It answers."',
	},
	TagDaniel = {
		Title = "ID tag: Daniel Kade",
		Body = "ROURKE EXPEDITION - SECURITY\nDaniel Kade\n\nKade's brother. The tag lies half-buried in moss beneath the broken arch, as if it was dropped while running.\n\nKade will want this.",
	},
	Soldier = {
		Title = "A soldier in the ruins",
		Body = "Heavy military armour. Not Rourke's team, and not ours.\n\nViolet crystal has grown straight through the chest plate. The red visor is still flickering, and the core in its chest is warm to the touch.\n\nIt isn't breathing. You're almost sure it isn't breathing.",
	},
	Scrawl = {
		Title = "Scratched into a crate",
		Body = "IT HUNTS BY SOUND\n\nIt hears you run. It hears you breathe.\nStay low. Stay in the grass.\nIt only sees what moves in the open.\n\nDON'T LET IT SEE YOUR LIGHT",
	},
	Journal = {
		Title = "Dr. Elias Rourke - Field Journal",
		Body = 'Day 19.\nThe Vael built their door to answer only those who knew the old sky.\n\nThe carving above the door is worn, but the verse survives:\n"First the EYE that watches. Last the SUN that sleeps.\nBetween them the MOON is held."\n\nThree dials. Left to right. I am certain of it now.\n\nSomething answers when we work at night. Daniel says it is the wind.\nIt is not the wind.',
	},
	Mural = {
		Title = "Temple mural",
		Body = "A faded carving shows three symbols in a row above a great door.\n\nThe first is an EYE.\nThe middle symbol has crumbled away.\nThe last is a SUN.\n\nBeneath it, figures flee from a crack in the mountain.",
	},
	Recording = {
		Title = "Torn page near the shard",
		Body = "...the shards hum louder near the crack. Twelve of us came. Four are left.\nThe door was never meant to keep us out.\nIt was meant to keep something IN.\n\n- E.R.",
	},
	-- Chapter 2
	C2SecurityLog = {
		Title = "Security log - Blackstone lobby",
		Body = "02:14  Power fluctuation, west wing.\n02:16  Containment Lab 2 reports 'movement in Cell 3'. Told them it's the pumps.\n02:31  Generator tripped. Emergency lights only.\n02:33  Something is in the maintenance tunnel.\n02:34  Sealing the security door. If you're reading this, don't restore the power until you have a way out.",
	},
	C2Whiteboard = {
		Title = "Whiteboard - Engineering",
		Body = "GENERATOR LOAD TEST\n\nBreaker A: ON\nBreaker B: OFF   (B shorts the corridor! DO NOT RUN)\nBreaker C: ON\n\nSpare fuses: one on the shelf here, one in the maintenance crate.\n- M.",
	},
	C2LabLog = {
		Title = "Research log - Dr. Mira Sato",
		Body = "Sample R-7 came out of the Rift fracture under the mountain, the same stone the Vael carved.\n\nWhen we feed it current, it grows. When the power drops, it wakes.\n\nDirector Hale says the Rourke expedition 'found the door'. He says we only need to open it wider.",
	},
	C2CryoLog = {
		Title = "Containment report - Lab 2",
		Body = "Cell 1: empty.\nCell 2: empty.\nCell 3: SUBJECT ACTIVE. Hunts by sound. Ignores light unless it is pointed at it.\n\nRecommendation: never cut main power while Cell 3 is occupied. The lock fails OPEN.",
	},
	-- Chapter 3
	C3Mural = {
		Title = "Vael mural",
		Body = "Rows of tiny figures kneel before a crack in the sky.\nOut of the crack reaches something with long arms and a crown of crystal.\n\nBelow, the figures carry a glowing stone down into the earth, and seal the door behind them.",
	},
	C3Tablet = {
		Title = "Tablet in the hidden chamber",
		Body = "The words are worn but readable:\n\nFIRST the EYE that watches.\nTHEN the SERPENT that waits.\nThe MOON that hides.\nLAST the SUN that sleeps.\n\nSomeone has scratched underneath: 'Wrong step = darts. Listen for the click. - E.R.'",
	},
	C3Rourke = {
		Title = "Rourke's last page",
		Body = "Day 31.\nThe heart is under the temple, exactly as the songs said.\nThe Vael fed it light so it would sleep.\nBlackstone's people want to wake it, to 'study' it.\n\nIf anyone finds this: do not touch the heart. Or if you must, run.\n- Elias Rourke",
	},
	C3Vael = {
		Title = "Inscription on the altar",
		Body = "WE OPENED THE SKY TO SEE THE STARS.\nSOMETHING SAW US BACK.\nWE GAVE IT OUR LIGHT SO IT WOULD DREAM.\nKEEP IT DREAMING.",
	},
}

return Story
