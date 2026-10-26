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

-- Radio operator: Mara Voss, coordinating from the expedition boat.
-- The player is "Pathfinder", the expedition's scout.
Story.Dialogue = {
	Intro = {
		{
			Speaker = "MARA (radio)",
			Text = "Pathfinder, do you copy? The chopper went down hard. Are you hurt?",
			Duration = 4.5,
		},
		{
			Speaker = "MARA (radio)",
			Text = "The distress signal is still broadcasting. North of you, past the old trail.",
			Duration = 4.5,
		},
		{
			Speaker = "MARA (radio)",
			Text = "Same frequency the Rourke expedition used. Twelve years ago.",
			Duration = 4,
		},
		{
			Speaker = "MARA (radio)",
			Text = "Press F for your flashlight. Save the batteries. I mean it.",
			Duration = 4,
		},
	},
	ClawMarks = {
		{
			Speaker = "MARA (radio)",
			Text = "What are you looking at? ...Those aren't from any animal I know.",
			Duration = 4,
		},
	},
	Camp = {
		{
			Speaker = "MARA (radio)",
			Text = "That's Rourke's camp. Nobody's been here in years. Look for anything useful.",
			Duration = 4.5,
		},
	},
	Ruins = {
		{
			Speaker = "MARA (radio)",
			Text = "Signal's coming from inside those ruins. Something is moving on my thermal...",
			Duration = 4.5,
		},
		{
			Speaker = "MARA (radio)",
			Text = "Stay low in the tall grass. Press C to crouch. Don't let it see you.",
			Duration = 4.5,
		},
	},
	Temple = {
		{
			Speaker = "MARA (radio)",
			Text = "A sealed door? Rourke's notes said something about the order of the sky.",
			Duration = 4.5,
		},
	},
	Solved = {
		{
			Speaker = "MARA (radio)",
			Text = "It's opening! Wait... the readings just spiked. The whole mountain is shaking!",
			Duration = 4,
		},
		{
			Speaker = "MARA (radio)",
			Text = "Run, Pathfinder! Through the door and up the cliff! I'm dropping a flare!",
			Duration = 4,
		},
	},
	Bridge = {
		{ Speaker = "MARA (radio)", Text = "Climb! That bridge won't hold for long!", Duration = 3.5 },
	},
	Done = {
		{
			Speaker = "MARA (radio)",
			Text = "I see you! You made it. Pathfinder... what WAS that thing?",
			Duration = 4.5,
		},
	},
}

-- Readable notes found in the world. The camp journal holds the puzzle clue.
Story.Notes = {
	Scrawl = {
		Title = "Scratched into a crate",
		Body = "IT HUNTS BY SOUND\n\nIt hears you run. It hears you breathe.\nStay low. Stay in the grass.\nIt only sees what moves in the open.\n\nDON'T LET IT SEE YOUR LIGHT",
	},
	Journal = {
		Title = "Dr. Elias Rourke - Field Journal",
		Body = 'Day 19.\nThe Vael built their door to answer only those who knew the old sky.\n\nThe carving above the door is worn, but the verse survives:\n"First the EYE that watches. Last the SUN that sleeps.\nBetween them the MOON is held."\n\nThree dials. Left to right. I am certain of it now.\n\nSomething answers when we work at night. Okafor says it is the wind.\nIt is not the wind.',
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
