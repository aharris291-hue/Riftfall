# Playtest notes

Feedback from play sessions, and what was done about each point. Newest first.

## Round 3 — Adam, 2026-10-26: Chapter 1 environment concept

**Hotfix:** Adam reported falling forever on load. Cause: the terrain code
set `Terrain.Decoration`, which scripts are not allowed to change, so the
level build stopped before any ground existed. Fixed: that setting now lives
in the place file; a failed terrain fill falls back to a part floor; scenery
errors can no longer stop the level from loading; a new
`tools/smoke/terrain_smoke.luau` checks every terrain call.

Adam: "Use the following image to design the environment for the first
world", then: the environment and characters "should not look like Roblox
games but should instead be more polished like a modern, polished 3d
rendered game".

| Concept art | In game |
|---|---|
| Storm, rain, lightning | Existing rain; lightning now draws a visible bolt; heavy cloud cover, no moon or stars, greener colour grade |
| Jungle floor | Smooth terrain with swaying grass, darker undergrowth patches and a mud trail (replaces the flat green slab); ferns everywhere |
| Trees | Taller trees with buttress roots, moss bands, layered canopy and hanging vines |
| Moss-covered arches wrapped in roots | Four carved stone arches (two broken), mossy and root-wrapped, at the ruins gate, the temple approach and the courtyard sides; roots and moss on every pillar |
| Stone stairs toward the cliffs | Torch-lit stairs climbing out of the ruins on both sides |
| Temple | Stepped ziggurat tiers, moss, roots pouring over the front |
| Crashed helicopter | Rebuilt: tipped on its side, snapped rotor blades, bent tail boom, moss and vines, still smouldering |
| Muddy camp with tents, crates, overgrown 4x4s with headlights on, torches | Mud ground with puddles, A-frame tents (one torn), equipment cases, two rusted 4x4s with working headlights, four torches; a third 4x4 lights the trail from the crash site |
| Cliffs and mountain | Mossy terrain cliffs on both sides and a mountain to the north |
| Modern look | Future lighting (torches and headlights cast real light and shadow), bloom, light depth of field |

**Adam's Chapter 1 lighting script** (command-bar script, merged in rather
than run as-is, because it would replace the level):

| From the script | Result |
|---|---|
| Contrast 0.15, saturation -0.3, cold blue tint | Kept (saturation -0.28); values in `Config.Lighting` |
| Atmosphere offset 0.25 | Kept: cliffs and mountain show as silhouettes against the sky |
| Bloom (size 24, lower threshold) | Kept, slightly stronger (intensity 0.5, threshold 1.0) so torches and headlights glow |
| Lights with shadows | Kept for torches, the camp lantern (now range 25, brightness 2.5) and campfire |
| Blue light at the ruin archway | Added as a cold blue Rift glow inside the temple arch |
| Brightness 0.4, dark ambient, colour brightness -0.05, atmosphere density 0.55 / haze 2 | Not used: it would bring back the "too dark" problem from round 1 |
| FogStart / FogEnd | Not used: Roblox ignores them when an Atmosphere exists |
| Ground, camp platform, wreck, tent, arch blocks, spawn | Already covered by the redesigned level (terrain, 4x4s, tents, arches) |

Honest limit: shapes built in code can't reach a "modern AAA" look on their
own. Every placeholder now has a slot so a real 3D model can replace it with
no code changes (README, "Swapping in real 3D models").

## Round 2 — Adam, 2026-10-26: character concept sheet

Adam: "Use this to redesign the characters for the game" (sheet: *Riftfall
Character Design and Roblox Guide*). Preview: `docs/images/character-preview.png`.

| Sheet | In game |
|---|---|
| Jax Mercer, protagonist | Every player is Jax. Five outfits from the sheet (Default, Stealth, Survival, Wanderer, Heavy Armor), switched with the **Outfit** button; co-op partners start in different ones |
| Serra, AI companion | Lives in Jax's wrist unit and speaks all objectives (replaces the radio operator). Appears as a cyan hologram at the crash site |
| Kade, the veteran | NPC at the camp; his brother Daniel was on the lost expedition. Waits at the rescue flare at the end |
| Lira, the scientist | NPC in the temple; comments on the mural. Waits at the rescue flare at the end |
| Rift Stalker | Replaces the Hollow: violet alien with crystal spines and claws; flickers as it phases between dimensions. Same AI |
| Corrupted Soldier | Dormant in the ruins with a note; its AI is planned for later |

Not used from the sheet: the example asset IDs (they are not real assets),
and the "alien powers" backstory, which the master prompt does not include.

## Round 1 — Adam, 2026-10-26

| # | Note | Change made |
|---|---|---|
| 1 | "The characters still look like basic Roblox characters; I'd like them to look like unique characters." | Players no longer load their Roblox avatar. Everyone is dressed as an expedition member: one of four outfits (Scout, Surveyor, Medic, Climber, picked from the player's account so it stays the same and co-op partners look different) with a field hat, scarf, harness, backpack with bedroll, belt pouches, field radio and boots. The name tag shows the role. The Hollow also got a more distinctive silhouette (bone spines, pale ribs, ragged coat strips). All still placeholder geometry: real meshes can replace it later. |
| 2 | "It is too dark." | Night lighting brightened (higher brightness, ambient light, exposure; thinner fog). All values are in `Config.Lighting`. A **Brightness** button under the objective panel cycles Normal / Bright / Brightest for your own screen. |
| 3 | "The flashlight doesn't seem to matter because there is no light path." | Flashlight rebuilt: a much stronger, longer spotlight aimed exactly where your camera looks, plus a visible beam of light in front of you that fades with distance, and a glow at the lens. Other players see your beam too. Beam size and strength are in `Config.Flashlight`. |
