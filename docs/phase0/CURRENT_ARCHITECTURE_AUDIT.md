# Current Architecture Audit (Phase 0)

Audited against the real repository, not the status list. Repo: `ajay34230/Asingh` (renamed from `asingh`; the local `origin` URL still uses the old name and redirects). Active branch: `phase-2-player-controller`. Latest released commit at audit time: `6e830b4`. An unreleased work-in-progress checkpoint exists on branch `wip/pond-sky-flora` (see section 12).

## 1. Project shape

| Item | Fact |
|---|---|
| Engine / language | Godot 4.4.1, GDScript, 9,466 lines in 37 scripts under `scripts/` (before the WIP branch) |
| Renderer | `mobile` in `project.godot` (CI can also build `gl_compatibility`) |
| Scenes | **One**: `scenes/main.tscn`, a single `Node3D` with `scripts/main.gd`. Everything else is built in code at start-up |
| Autoloads | **None**. There is no singleton manager layer; `Sfx` is a node created by `main.gd`, `Story` is a node, statics are used for a few shared values (`Npc.atmo`) |
| Assets | 42 MB: Quaternius CC0 characters (`assets/characters`, `assets/people`), animals, one cart, 191 generated WAV files. Sources listed in `ASSETS.md` |
| Textures | Almost none imported. Sand, stone, wood, plaster and water-like surfaces are procedural noise textures generated at start-up (`PropFactory`) |
| Export | `export_presets.cfg`: Android Debug and Android Release, version code 2 |
| CI | `.github/workflows/build.yml` (import, self-test, screenshots, debug APK, publish to release `debug-latest`), `release.yml` (signed AAB, never run) |

## 2. Scene and node hierarchy (at run time)

`Main` (Node3D, `main.gd`, 824 lines) builds, in order: `Terrain` (25 chunk meshes + trimesh colliders, boundary walls, outer skirt, mountains) → `RuinsBuilder` → `EntranceBuilder` → `HouseBuilder` (6 houses with interiors, well, fences) → `RailwayBuilder` (track, train, dock, shed, water tower) → `Atmosphere` (sky, sun, fog, dust, rain) → underlay plane → `CollisionFixer` (adds colliders to un-collided meshes) → `Player` → `NpcBuilder` (28 presets, ~26 NPCs placed) → `LifeBuilder` (animals, cart, birds) → `Sfx` → interactables → UI (`TouchControls`) → story layer (`Story`, `DialogueUI`, `QuestHUD`, `Cinematic`, `StoryBuilder`, `CombatBuilder`, `CombatHUD`, `MapUI`, `GameMenu`).

`main.gd` also contains the self-test (`--selftest`), audit (`--audit`) and screenshot (`--capture=`) modes.

## 3. Major systems and who owns what

| Responsibility | Owner | Notes |
|---|---|---|
| Player, camera, health, powers | `player.gd` (477) | `CharacterBody3D`, SpringArm camera, `attack()`, `take_damage`, `apply_powerup`, respawn at checkpoint |
| Character rig and animation | `real_human.gd` (473) | Loads Quaternius GLB, drives the skeleton bones **in code** (walk/run/idle/talk/attack/hammer poses, overlays). No AnimationTree, no animation clips. `human_rig.gd` is the older primitive-mesh rig |
| NPC behaviour | `npc.gd` (~330) | Reactions to the player, bubbles, TTS speech, routines (`walk`, `play`, `carry` only on WIP), companion mode |
| NPC placement | `npc_builder.gd` | Hard-coded positions and presets |
| Quests and flags | `story.gd` (589) | **One flat dictionary** `flags` plus a quest table; `changed` signal; dialogue trees are built in code per NPC |
| Story props, cinematics | `story_builder.gd`, `cinematic.gd` | Interactables, gates, office furnishing, intro/gate shots |
| Dialogue UI | `dialogue_ui.gd` | Node graph format `{who,text,set,add,sfx,choices,go}` |
| Combat | `enemy.gd`, `combat_builder.gd`, `combat_hud.gd`, `pickup.gd` | Reavers, raid waves, boss Karan (hp 280), power-ups |
| Save / settings | `game_menu.gd` | See section 5 |
| Map | `map_ui.gd` | Terrain image rendered once (320 px) |
| Audio | `sfx.gd`, `tools/make_audio.py` | Layers by location / time of day; TTS through `DisplayServer.tts_*` |
| Weather / day-night | `atmosphere.gd` | 1200 s day, `ProceduralSkyMaterial`, rain particles, thunder, rainbow |
| World generation | `terrain_builder.gd` | Noise terrain, HALF=200 m, 2 m cells (200x200), rim and north cliff |

## 4. Data structures and communication

- State is a **string-keyed dictionary** (`Story.flags`). Any script can write any key. No schema, no typed IDs, no event log.
- Communication is mostly direct node references passed in constructors (`StoryBuilder.new(main, story, hud, dlg, cin)`), a few signals (`Story.changed`, `Enemy.died`, `Cinematic` finish), and `Main` as a god-object that holds references to everything.
- Content is **code, not data**: quests, dialogue, NPC positions, item drops and prices are literals inside GDScript. There are no `Resource` files (`.tres`) at all.

## 5. Save / load (verified by reading `game_menu.gd`)

- File: `user://save.json`. Contents: `flags` (whole dictionary), `pos`, `yaw`, `tod`.
- **Not versioned. Not atomic** (opened for WRITE directly, so a crash mid-write corrupts the file). **No backup** of the previous save. No migration path. Load silently returns false on any parse problem.
- Not saved: player health, power-ups, enemy and pickup state, NPC state, camera settings (settings do persist separately in `user://settings.cfg`).
- Autosave fires on every `Story.changed`.
- Consequence: the master prompt's save requirements (versioning, migration, corruption protection, preserved originals) need a rewrite of this one function pair. It is small and contained, so this is cheap, but it must be done before any inventory or world-state work.

## 6. Character and animation framework

- Bodies: 7 Quaternius base characters + robe overlays + 10 modular men/women, all CC0 GLB. Skeleton bone names are mapped in `real_human.gd`.
- All motion is procedural bone rotation. This is flexible and light, but there are **no imported attack, block, roll or death clips**. Advanced combat (block, parry, roll, finisher) will mean writing new procedural poses or sourcing CC0 animation clips and retargeting them.
- Weapons: the only held item is a hammer built in code. There is no attachment system for sword, shield or bow.

## 7. Terrain and world

- 400 m x 400 m. Grid 200x200 cells of 2 m, 25 chunks, triangle-mesh collision. A 400 m high ring of mountain silhouettes and a flat skirt hide the edge.
- Everything is one biome (desert). A dry riverbed, a rail strip, house sites, forecourt and start mound are carved by formulas in `height_at()`.
- There is no streaming, chunk loading/unloading, LOD, occlusion culling or visibility range. All 25 chunks and every prop are always resident.

## 8. Performance (what is measured and what is not)

Measured (headless self-test census on the released branch, commit `6e830b4`, self-test PASS): 2,689 `MeshInstance3D`, 4 `MultiMeshInstance3D`, 1,096 `StaticBody3D` (the WIP branch: 2,789 / 9 / 1,118). World build takes about 2.6 s on the build machine. These are scene-size figures, **not frame rates**.

**Not measured:** frame rate, GPU time, memory or thermals on any Android device. No profiling has ever been done on the Samsung Galaxy S10. Every FPS claim in earlier messages is unverified.

Known risks, from the code:
1. ~2,800 separate mesh nodes with weathered per-prop meshes; very few are instanced, so draw calls are likely the first bottleneck on a phone.
2. One directional light with 2 shadow splits to 260 m at 2048 px; NPC and prop shadows are all cast.
3. Procedural noise textures (256-512 px) are generated at start-up; first-load time on a phone is unknown.
4. Rain is a 1,400-particle GPU system following the player (only emitting during showers).
5. The "graphics quality" setting only changes `scaling_3d_scale`. It does **not** change shadows, view distance, foliage or effects, so Low/Medium/High are not yet real quality tiers.

## 9. Test and QA infrastructure

`--selftest` (about 80 s headless) checks: height grid, spawn, run, wall, step, jump, camera never below ground (30 samples), doors, stairs, dock/boxcar, NPC solidity, combat, story flow and dialogue graph validity, save/load, interactable counts. It prints `[selftest] PASS/FAIL`. It runs on the dummy renderer, so it cannot catch visual or GPU problems. CI additionally takes screenshots on a software renderer. There is no on-device test.

## 10. Android build configuration

- Package and icons set in `export_presets.cfg`; debug keystore cached in CI so APKs update in place.
- `emulate_mouse_from_touch=true` is required for GUI buttons to respond to touch.
- Release signing path exists but has never been exercised.
- Text-to-speech depends on the phone's engine; voices differ per device.

## 11. Integration conflicts and structural weaknesses found

1. **No authoritative world-state model.** `flags` is a bag of strings. The master prompt's "world remembers you" needs namespaced, documented state IDs and a small API (set once, query, subscribe).
2. **Content is hard-coded in GDScript.** Inventory, shops, crafting and quests at the requested scale need data-driven definitions (JSON or `Resource`), otherwise scripts will grow past maintainability.
3. **`Main` is a god object (824 lines)** that owns building, testing and screenshots.
4. **No autoloads.** Fine for now, but inventory, save and world-state need a single always-available owner. Recommendation: one `GameState` autoload (not several managers).
5. **Save format cannot carry the new data** and is unsafe (section 5).
6. **Procedural-bone animation** limits combat variety (section 6).
7. **Quality tiers are not real** (section 8).
8. **All NPC and prop positions are literals** and several were placed without checking clearance (cart routes, rail crate and dig-site placement have never been visually verified).

## 12. State of unreleased work

- `phase-2-player-controller` @ `6e830b4` (released): weather and rain, NPC routines, companion mode, cart-ride plumbing, voiced cutscene lines, shop-cost dialogue choices. Self-test passed before the last one-line edit; CI re-checks.
- `wip/pond-sky-flora` (NOT released, pushed as a checkpoint): terrain density 2.0 m to 1.6 m, village pond with a shader, stone water channel, four water-carrying NPCs, procedural palms/grass/reeds, a cloud layer, a pond on the map. Self-test: PASS. Never viewed on screen (the screenshot step was interrupted), so its visual quality is **unknown**. It will be reworked under Phase 1 to the water style requested (see the roadmap).
