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
	Ruins = "Cross the ruins and enter the temple. Stay out of sight.",
	Puzzle = "Open the sealed temple door",
	Escape = "The temple is collapsing. GET OUT!",
	Bridge = "Climb the cliff and cross the bridge to the flare",
	Done = "Signal reached. Chapter 1 demo complete.",
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
}

-- Readable notes found in the world. The camp journal holds the puzzle clue.
Story.Notes = {
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
}

return Story
