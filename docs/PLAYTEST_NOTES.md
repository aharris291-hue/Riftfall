# Playtest notes

Feedback from play sessions, and what was done about each point. Newest first.

## Round 1 — Adam, 2026-10-26

| # | Note | Change made |
|---|---|---|
| 1 | "The characters still look like basic Roblox characters; I'd like them to look like unique characters." | Players no longer load their Roblox avatar. Everyone is dressed as an expedition member: one of four outfits (Scout, Surveyor, Medic, Climber, picked from the player's account so it stays the same and co-op partners look different) with a field hat, scarf, harness, backpack with bedroll, belt pouches, field radio and boots. The name tag shows the role. The Hollow also got a more distinctive silhouette (bone spines, pale ribs, ragged coat strips). All still placeholder geometry: real meshes can replace it later. |
| 2 | "It is too dark." | Night lighting brightened (higher brightness, ambient light, exposure; thinner fog). All values are in `Config.Lighting`. A **Brightness** button under the objective panel cycles Normal / Bright / Brightest for your own screen. |
| 3 | "The flashlight doesn't seem to matter because there is no light path." | Flashlight rebuilt: a much stronger, longer spotlight aimed exactly where your camera looks, plus a visible beam of light in front of you that fades with distance, and a glow at the lens. Other players see your beam too. Beam size and strength are in `Config.Flashlight`. |
