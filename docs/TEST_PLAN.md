# Test plan — Chapter 1 demo

Run each test in Roblox Studio with the **Output** window open
(*View > Output*). Note anything that does not match "Expected", plus any red
text in Output, and send it over.

**Puzzle answer (spoiler):** left to right, EYE, MOON, SUN.

## A. Start-up

| # | Do this | Expected |
|---|---|---|
| A1 | Press Play | Output shows `[Riftfall] Server ready.` and `[Riftfall] Client ready.`, no red errors |
| A2 | Look around | Night, fog, rain, burning helicopter wreck. Objective panel top-left says "Follow the trail north..." |
| A3 | Wait 2 seconds | Serra's subtitles appear above the inventory bar, four lines |
| A4 | Click a subtitle | It skips to the next line |

## B. Movement and flashlight

| # | Do this | Expected |
|---|---|---|
| B1 | Walk with WASD | Normal speed (a little slower than default Roblox) |
| B2 | Hold Shift while moving | Faster; stamina bar drains; when empty you slow down until it refills to about a third |
| B3 | Press C | Camera lowers, you move slowly. Press C again to stand |
| B4 | Press F | Flashlight on, label says ON, battery bar slowly drains. Light follows where the camera looks |
| B4b | With the light on, look around | A visible cone of light (the beam) comes out in front of you, follows the camera, and lights up the ground and trees |
| B4c | Click **Brightness** under the objective panel | Screen gets brighter at each step: Normal, Bright, Brightest, then back to Normal |
| B4d | Look at your character | Not your Roblox avatar: an expedition outfit with a hat, scarf, backpack and bedroll, belt and radio. Your name tag shows a role such as "Scout" |
| B5 | Leave the light on until empty (or set `StartingBattery` low in Config) | Light turns off with a "Battery is dead" message; F won't turn it back on |

## C. Inventory and healing

| # | Do this | Expected |
|---|---|---|
| C1 | Walk to the blue glowing cube by the crates, press E | "Picked up Battery", it appears in slot 1 |
| C2 | Press 1 with the battery bar not full | "Using Battery..." then "Flashlight recharged"; battery bar jumps up; slot empties |
| C3 | Press 1 rapidly many times | Only one use happens; nothing duplicates |
| C4 | Pick up a Bandage at the camp, press its number at full health | "Already at full health", the bandage is kept |
| C5 | Get hurt (by the creature or a rock), then use the bandage | Health goes up by 35 |
| C6 | Click the small X on a slot | Item drops in front of you as a glowing cube and can be picked up again |
| C7 | Try to drop the Rift Shard | "You can't drop that" |
| C8 | Fill all 4 slots (drop and re-pick if needed), try another pickup | "Inventory full", the item stays in the world |

## D. Story and checkpoints

| # | Do this | Expected |
|---|---|---|
| D1 | Walk up to the tree with red claw marks | Serra comments on them |
| D2 | Read the note on the broken crate by that tree | A paper panel opens with the survivor's warning. Close with the button or Enter |
| D3 | Reach the camp | Objective changes, "Checkpoint reached: Camp" message near the green flare |
| D4 | Read Rourke's journal on the camp table | Journal text with the dial clue |
| D5 | Reset your character (Esc > Reset Character) | You respawn at the camp checkpoint with your items |

## E. The Rift Stalker (enemy AI)

Tip: select `Workspace > RiftStalker` in the Explorer while playing; its `State`
attribute shows what it is doing.

| # | Do this | Expected |
|---|---|---|
| E1 | Enter the ruins and watch from a distance, crouched | It walks a loop around the courtyard (State = Patrol) |
| E2 | Sprint somewhere it can hear you (within ~45 studs) but not see you | It turns and walks to where the noise was (Investigate), looks around, then returns |
| E3 | Walk in front of it in the open | It runs at you (Chase). Screen edges pulse purple as it gets close |
| E4 | Let it reach you | Eyes flare red for about half a second before the swing; you take 25 damage, screen flashes red |
| E5 | During the red eyes, run away | The swing misses |
| E6 | Break line of sight behind a pillar or wall and keep moving | After about 4 seconds it searches near your last position (Search), then gives up (Return → Patrol) |
| E7 | Crouch inside a tall grass patch while it walks past more than ~7 studs away | It does not notice you |
| E8 | Turn your flashlight on in its view at long range (55 to 80 studs) | It can spot you from further away than with the light off |
| E9 | Die to it | Death screen, respawn at the last checkpoint; it returns to patrolling |

## F. Puzzle

| # | Do this | Expected |
|---|---|---|
| F1 | Enter the temple | "Checkpoint reached: Temple", new objective, Serra mentions the order of the sky |
| F2 | Examine the mural (bottom-left of the door) | Text describes EYE ? SUN |
| F3 | Press E on each dial | Each turn cycles SUN → MOON → EYE → SPIRAL |
| F4 | Set EYE, MOON, SUN | Dials turn purple and lock; camera shakes; the door sinks into the floor; "Checkpoint reached: Temple Door" |
| F5 | Two players turn the same dial at once (if testing multiplayer) | It turns once, not twice |

## G. Escape

| # | Do this | Expected |
|---|---|---|
| G1 | Run through the opened door | Red circles appear on the floor ~1.3 s before rocks fall on them; rocks never block the path |
| G2 | Stand in a red circle when the rock lands | 30 damage |
| G3 | Look back a few seconds after the door opened | The Rift Stalker is chasing from the temple entrance |
| G4 | Die during the escape | Respawn just inside the door; the Rift Stalker is moved back and released again after a head start |
| G5 | Climb the wooden ladder at the end of the tunnel | You climb to the cliff top; the Rift Stalker stops at the bottom |
| G6 | Cross the rope bridge | Planks fall away behind you; invisible rails stop you falling off the sides |
| G7 | Jump off the bridge into the chasm | You die and respawn at the temple door; the bridge is whole again |
| G8 | Reach the red flare | Results screen: time, deaths, notes found (out of 4), Rift Shard yes/no |
| G9 | Click Play Again | World rebuilds, you start at the crash site with an empty inventory, the intro plays again |

## H. Multiplayer (Studio *Test* tab > *Clients and Servers*, 2 players)

| # | Do this | Expected |
|---|---|---|
| H1 | Both players pick up different items | Each sees only their own inventory |
| H2 | Both try to grab the same pickup at once | Only one gets it |
| H3 | One player solves the puzzle | Both get the door checkpoint; the door is open for both |
| H4 | One player finishes, the other hasn't | The finished player's Play Again restarts only them; the world is not reset under the other player |
| H5 | A player leaves mid-escape | No errors; the remaining player can still finish |

## I. Mobile (Studio *Test* tab > *Device* emulator, pick a phone)

| # | Do this | Expected |
|---|---|---|
| I1 | Start the game on a phone emulator | Sprint, Crouch and Light buttons appear near the jump button; keyboard hint is hidden |
| I2 | Tap prompts and inventory slots | Pickups, notes, dials and item use all work by tapping |
| I3 | Check the HUD | Nothing important hidden under the notch or the Roblox menu buttons |

## J. Performance

| # | Do this | Expected |
|---|---|---|
| J1 | *View > Performance stats* (or Ctrl+Shift+F1 in play) | Smooth frame rate on your machine; report the FPS if it feels choppy |
| J2 | Run around the jungle with the flashlight on | No big frame drops |

## H. Characters (concept sheet redesign)

| # | Do this | Expected |
|---|---|---|
| H1 | Spawn | You are Jax: messy brown hair, charcoal jacket, brown harness, knee pads, backpack, glowing cyan wrist unit. No Roblox avatar items |
| H2 | Click **Outfit** several times | Cycles Default, Stealth, Survival, Wanderer, Heavy Armor; a toast names each. Works again after respawn |
| H3 | Look next to the crash site | Serra stands on a glowing disc as a see-through cyan hologram; **Talk** plays her lines |
| H4 | Reach the camp | Kade (bearded, brown armour) is there; **Talk** mentions his brother Daniel |
| H5 | In the ruins, find the slumped soldier with red visor and chest core | It does not move; the note next to it can be read |
| H6 | Enter the temple | Lira (white lab coat, glasses, bun) is there; **Talk** helps with the mural |
| H7 | Reach the rescue flare | Kade and Lira are waiting there; their camp/temple copies are gone |
| H8 | Watch the creature for 10 seconds | Violet with glowing crystal spines; it briefly flickers (phases) every few seconds |
