# Status report — Chapter 1 demo (Milestone 2)

Honest status, as the master prompt asks. **"Implemented" means the code is
written, formats cleanly, passes the selene linter with the Roblox standard
library, and builds into `Riftfall.rbxlx` with Rojo. The map builder, HUD, creature
model and inventory rules were also run under Lune's Roblox instance model
(`tools/smoke/`), which confirms every property name and value type used to
build them is valid. None of it has been run
inside a real Roblox engine yet**, because that is not possible from the
cloud development environment. Treat everything as untested until it passes
[`TEST_PLAN.md`](TEST_PLAN.md) in Studio.

## Implemented (needs Studio play-testing)

- Third-person movement with sprint, crouch and stamina; touch buttons
- Interaction with ProximityPrompts (keyboard, gamepad, touch)
- Server-owned 4-slot inventory: pickup, use, drop, full-inventory feedback,
  key items can't be dropped, rate-limited and validated requests
- Health with no passive regen; bandages heal over a short use time
- Flashlight with server-owned battery and drain; batteries recharge it
- Two checkpoints plus a door checkpoint after the puzzle; respawn at the
  furthest one; items kept on death; falling into the chasm is fatal
- The Rift Stalker: patrol, investigate (hearing), chase (sight cone + line of
  sight), telegraphed attack, search, return; hiding in tall grass while
  crouched; flashlight increases how far it sees; pathfinding with fallback
  and stuck recovery; AI tick every 0.2 s
- Temple dial puzzle with clues split across a mural and a journal; shared
  server state; debounced; can't re-lock or soft-lock
- Escape set-piece: telegraphed falling rocks, the Rift Stalker released behind the
  players, climbable cliff, bridge collapsing behind players with safeguards
  so nobody is stranded
- Story: objectives (late-join safe), radio subtitles (skippable), four
  readable notes, story trigger zones
- HUD: objective, toasts, health/battery/stamina, inventory, subtitles,
  note reader, damage and danger edge effects, death screen, results screen
  with Play Again
- Atmosphere: night lighting, fog, colour grade, rain, lightning, camera shake

- Expedition outfits for players (four role variants) instead of Roblox avatars
- Flashlight with a visible beam aimed by the camera; per-player brightness option

### Chapter 1 expansion (Milestone 4, part 1)

- First sighting: the Rift Stalker crosses the trail far ahead, flickers and
  vanishes (it cannot hurt you here), with Serra's reaction
- Locked route: the ruins are walled off behind a chained metal gate; Kade
  at the camp gives bolt cutters (a key item he re-gives if needed) and a flare
- Throwable flares (use from the inventory): land ahead of you, burn red for
  14 s and make a noise the creature hears from 70 studs away, pulling it
  away from you
- Four hidden expedition ID tags (optional evidence); the results screen
  counts them, and returning Daniel's tag adds an extra ending scene with Kade

## Partially implemented

- **Multiplayer**: server-authoritative and designed to be co-op-safe, but no
  co-op mechanics and not tested with multiple players.
- **Audio**: hooks exist (rain, thunder, heartbeat, rumble, pickup) but no
  sound IDs are set, so the demo is silent.
- **Accessibility**: readable UI, subtitles, safe-area insets, touch support;
  no settings menu yet (volume sliders, subtitle size, brightness).

## Planned (later milestones)

- Saving progress with DataStoreService (Milestone 5)
- Weapons/combat, Crawler and Guardian enemies
- Real models, animations, and licensed audio
- Settings/pause menu
- Chapters 2 to 5

## Not verified

- Anything at runtime: frame rate, pathfinding quality, lighting brightness
  on different devices, mobile button layout, multiplayer behaviour.

## Assets and placeholders

| Asset | Current | To replace |
|---|---|---|
| Ground, cliffs, mountain | Smooth terrain (swaying grass, mud, rock) filled by `LevelBuilder`/`SceneryKit` | Can stay; optionally hand-sculpt in Studio |
| Trees, ferns, arches, torches, tents, cases, 4x4s, helicopter | Part-built placeholders in `src/server/Util/SceneryKit.luau` | Real meshes dropped into `ServerStorage > RiftfallAssets` (see README, "Swapping in real 3D models") |
| Other environment pieces (temple, tunnel, bridge, pillars) | Basic parts in `LevelBuilder.luau` | Real meshes; needs a small code change per piece |
| Characters (Jax, Serra, Kade, Lira, Corrupted Soldier) | Story characters can use a finished model from `ServerStorage > RiftfallAssets > Characters`; otherwise part-built outfits: data in `src/shared/CharacterDesigns.luau`, built by `src/server/Util/Outfitter.luau` | Layered clothing or mesh accessories you own |
| The Rift Stalker | Part-built stand-in (crystal spines, plates, claws) in `StalkerService.buildModel` | Any model with a `Humanoid` and `HumanoidRootPart` |
| Sounds | Empty IDs in `Config.Sounds` | Paste `rbxassetid://...` IDs you are allowed to use |
| Animations | None (default Roblox avatar animations only) | Upload animations you own and play them from the client |
| Rain particles | Default particle texture | Optional custom texture |

No third-party code, plugins, paid APIs, or external services are used.
