# Riftfall: The Last Ascent — Design summary and plan

Source of truth: the **Riftfall Master Prompt** (PDF in the project files).
This document covers what the master prompt asks for in its "First response"
section: a game summary, the first vertical slice, the folder structure, a
milestone plan, required setup, and the assumptions made along the way.

## 1. One-page game summary

**Pitch.** A third-person horror-survival adventure. Twelve years ago the
Rourke expedition vanished in a sealed region called the Rift. Now its
distress signal is broadcasting again. You are **Jax Mercer**, an ordinary
person sent in as the new expedition's scout, guided by **Serra**, the AI in
your wrist unit. Something beneath the mountain has woken up.

**Pillars** (from the master prompt): fear through uncertainty, survival
choices, cinematic exploration, readable and fair threats, original
worldbuilding, accessible controls, incremental development.

**Core loop.** Enter an area and get an objective over the radio → explore,
gather supplies, read evidence → solve a traversal or puzzle obstacle →
avoid or escape a threat → reach a checkpoint → unlock the next area and a
piece of the mystery.

**Chapters (planned).**
1. The Forgotten Expedition: storm-hit jungle, abandoned camp, ruins *(demo)*
2. Blackstone Research Facility: power puzzle, stalker sequence
3. The Sunken Temple: flooded ruins, pressure puzzles, climbing
4. The Ascent: mountain escape, collapsing bridges, storms
5. The Rift: final descent, Guardian boss, ending shaped by evidence found

**Original cast and lore introduced in the demo.**
Character looks follow Adam's character concept sheet (round 2 of
`docs/PLAYTEST_NOTES.md`); story roles follow the master prompt.
- *Jax Mercer* (player): determined, resourceful, haunted. Five outfits.
- *Serra*: AI companion in Jax's wrist unit, shown as a cyan hologram at the
  crash site. Calm, analytical, quietly protective. Speaks all objectives.
- *Kade*: veteran soldier waiting at the abandoned camp. His brother Daniel
  was on the Rourke expedition; that is his vendetta.
- *Lira*: scientist studying the temple; helps read the mural.
- *Corrupted Soldier*: a dormant human enhanced with alien tech, slumped in
  the ruins (with a note). Active AI is planned for a later chapter.
- *Dr. Elias Rourke*: lead of the lost expedition; known through his journal.
- *The Vael*: the ancient civilisation whose temple door "keeps something in".
- *The Rift Stalker*: tall, violet, crystal-spined alien that flickers
  between dimensions. Hunts by sound and only sees what moves in the open.
- *Rift Shards*: humming stone fragments; optional evidence.

## 2. The demo vertical slice

The master prompt's Milestone 2 asks for: third-person movement,
interaction, an inventory item, health/healing, one enemy with working AI,
one puzzle, one escape event, one checkpoint, and a beginning/end objective.
The demo contains all of these:

| Section | What happens | Systems exercised |
|---|---|---|
| Crash site | Intro radio call, first battery, warning sign | Dialogue, pickups, flashlight |
| Jungle trail | Claw marks on a tree, survivor's scratched warning | Environmental storytelling, notes |
| Abandoned camp | **Checkpoint 1**, Rourke's journal (puzzle clue), bandage, battery | Checkpoints, notes, inventory |
| Ruins courtyard | The Rift Stalker patrols; a dormant Corrupted Soldier. Tall grass, pillars and walls for stealth | Enemy AI, crouch, hiding, sprint noise |
| Temple interior | **Checkpoint 2**, mural, three stone dials, optional Rift Shard | Puzzle, optional evidence |
| Collapse tunnel | Door opens, mountain shakes, telegraphed falling rocks, the Rift Stalker is released behind you | Escape set-piece, damage, fair warnings |
| Cliff and bridge | Climb the ladder, cross the bridge as planks fall behind you | Climbing (truss), cinematic beat |
| Rescue flare | Results screen (time, deaths, notes, shard), Play Again | End objective, replay |

**Puzzle.** The door is opened by setting three dials, left to right, to
EYE, MOON, SUN. The mural shows `EYE ? SUN`; Rourke's journal says "between
them the MOON is held". Without the journal the puzzle is still solvable by
trying the four symbols on the middle dial.

## 3. Folder structure

See the folder tree in the [README](../README.md#folder-tree). It follows the
master prompt's suggested service layout:

- `ReplicatedStorage`: shared config, item definitions, story text, remotes.
- `ServerScriptService`: every game rule (inventory, damage, AI, puzzle,
  checkpoints, escape). Nothing important is decided on the client.
- `StarterPlayerScripts`: UI, input, camera effects, local atmosphere.
- `StarterCharacterScripts`: only the empty `Health` script that disables
  passive regeneration.
- `Workspace`: filled at runtime by `LevelBuilder` (see README for why).
- `ServerStorage` / `SoundService`: unused so far (no protected templates or
  audio yet).

## 4. Milestone plan

| # | Milestone (from the master prompt) | Status |
|---|---|---|
| 1 | Design and technical plan | This document |
| 2 | Playable vertical slice | **This demo** (code complete, needs Studio play-testing) |
| 3 | Stabilisation: test in Studio, fix bugs, exploits, UI, performance | Next: needs Adam's test results |
| 4 | Expand Chapter 1: more jungle, second enemy type (Crawler), real models, authored audio | Planned |
| 5 | Saving (DataStoreService) and co-op hardening | Planned |
| 6 | Polish and release readiness | Planned |

## 5. Tools and setup you need

- **Roblox Studio** (free). That is all you need to play the demo.
- Optional, for developers: **Rojo 7.x** for syncing files into Studio,
  **StyLua** and **selene** for formatting/linting. No paid services, no
  third-party runtime dependencies.

## 6. Assumptions and defaults chosen

The master prompt says to use sensible defaults and list them rather than
block on questions. These are the ones made for the demo:

1. **Solo-first, co-op-safe.** All state is server-authoritative and the demo
   works with several players (shared puzzle, per-player checkpoints and
   inventory), but co-op was not specially designed or tested yet.
2. **No saving between sessions yet.** Checkpoints last for the session.
   DataStore persistence is Milestone 5, so the demo never claims to save.
3. **The enemy can't be killed.** No weapons in the slice: the master prompt
   says combat should come only after movement, health and enemy damage are
   stable. The demo is about stealth and escape.
4. **Movement speed is client-applied** (the Roblox norm). Speed hacks are a
   known limitation; the server still owns damage, items and progress.
5. **Placeholder art.** Everything is built from basic parts, including the
   character outfits (welded parts on R15 bodies). No asset IDs are used; the
   IDs on the concept sheet are examples. Real meshes can replace the parts.
11. **Concept sheet vs master prompt.** Where they differ the master prompt
    wins: the sheet's "catastrophic experiment / alien powers" backstory is
    not in the demo (no powers for Jax); it is noted as a possible later hook.
6. **No audio yet.** No sound IDs were invented. `Config.Sounds` has empty
   slots that are skipped until real, licensed IDs are pasted in.
7. **Map built in code** so the whole game is text and resettable.
8. **Items kept on death**, so dying never soft-locks progress. Key items
   (the Rift Shard) can't be dropped.
9. **Difficulty**: one tuning, aimed at "tense but fair". All numbers live in
   `src/shared/Config.luau`.
10. **Name**: the repository is "Riftfall"; the game title follows the master
    prompt, *Riftfall: The Last Ascent*.

## 7. Risks

- **Untested in Studio.** The code was written and statically checked
  (formatter, linter, a build of the place file, and Lune smoke tests of
  the map, HUD, creature model and inventory rules) but could not be run in a
  real Roblox engine from the development environment. First Studio run may
  reveal bugs; that is what Milestone 3 is for.
- **Pathfinding around generated geometry** may need tuning (agent size,
  patrol points) once observed.
- **Lighting on low-end/mobile** devices: may be too dark; brightness and
  fog are in `LevelBuilder.SetupLighting`.
- **Character rigs**: assumes the default R15 avatar with a `Head` part.
