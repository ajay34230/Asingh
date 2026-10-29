# The Lost Kingdom

Cinematic 3D archaeological adventure for Android, built with **Godot 4.4.1** (GDScript, Mobile renderer).

## Status: Phase 1 - 3D environment prototype only

Phase 1 contains a walkable, procedurally generated desert valley and the ancient entrance. There is **no story, dialogue, NPC, combat, inventory, puzzle or save system yet** (those come in later approved phases).

What is in the scene:

- About 400 x 400 m of noise-generated terrain with dunes, a winding dry riverbed, an enclosing rim and a north cliff, plus a flat outer plain and a ring of distant mountain silhouettes.
- A ruined caravan station (walls, well, lean-to, cart, jars), sandstone mesas and hoodoos, boulders, riverbed gravel, dry shrubs and dead trees.
- The ancient entrance: partly buried 14-step staircase, raised platform, a 34 m wide / ~30 m tall facade with a sealed door, a bronze disc ringed by seven decorative symbols, two guardian statues, broken columns, rubble and sand drifts.
- Sky, directional sunlight with shadows, distance fog and light dust particles.
- An orange capsule (1.8 m) as a scale reference with a third-person camera. The symbols and disc are decorative placeholders: no puzzle logic exists.

**All geometry is primitive, code-built placeholder art.** It is not realistic final art. See `ASSETS.md`.

## Controls

| Input | Action |
| --- | --- |
| Touch: left side of screen | Floating joystick to move |
| Touch: right side of screen | Drag to look around |
| RUN button | Toggle fast movement (for crossing the valley) |
| JUMP button | Jump |
| PC (testing only): W A S D, mouse drag, Shift, Space, arrow keys | Move, look, run, jump |

A small FPS counter is shown top-left.

## Get the Android APK (no PC needed)

1. On GitHub (browser or GitHub app) open this repo -> **Actions** -> **Validate and build Android debug APK**.
2. Open the latest run on branch `phase-1-environment` (or tap **Run workflow** to start one).
3. When the run finishes, scroll to **Artifacts** and download **TheLostKingdom-debug-apk** (a zip). Artifacts need you to be signed in to GitHub and are kept 14 days.
4. Unzip it on the phone (Files app) and open `TheLostKingdom-debug.apk`. Allow "Install unknown apps" for your browser/Files app when Android asks.

The APK is a **debug build** signed with a throwaway debug key, for personal testing only. If the mobile (Vulkan) renderer misbehaves on your device, run the workflow manually and set **renderer** to `gl_compatibility`.

Other artifacts from each run: **validation-logs** (import, self-test, export logs) and **screenshots** (see below).

## What the automated workflow checks

`.github/workflows/build.yml` (runs only on `phase-*` pushes that touch game files, or manually):

1. Downloads Godot 4.4.1 and its export templates from the official release and verifies SHA-512 checksums.
2. Imports the project headless and fails on any script error.
3. Runs `--selftest`: terrain height grid sanity, triangle winding, terrain collision vs. height grid, player settling on the ground, and a scripted run that must climb the staircase and be stopped by the sealed door.
4. Captures five screenshots with a **software OpenGL renderer** (Compatibility renderer under Xvfb). These show composition and layout only. They are not what the Mobile renderer looks like on a Galaxy S10 and do not prove performance.
5. Builds the Android debug APK (arm64-v8a).

A passing build proves the project imports and exports. It does **not** prove the game looks right or runs smoothly on a phone: that needs a real-device check.

## Run locally (optional, PC)

```
godot --path .                                   # run the game
godot --headless --fixed-fps 60 --path . -- --selftest
```

## Layout

```
project.godot, export_presets.cfg   Godot project + Android debug preset
scenes/main.tscn                    single scene; builds the world in code
scripts/main.gd                     entry point, self-test, screenshot mode
scripts/terrain_builder.gd          terrain, skirt, mountains, collision
scripts/entrance_builder.gd         staircase, facade, disc, symbols, statues
scripts/ruins_builder.gd            caravan station, formations, scatter
scripts/prop_factory.gd             primitive building blocks
scripts/atmosphere.gd               sky, sun, fog, dust
scripts/player.gd, touch_controls.gd   placeholder player + touch UI
ci/                                 Godot / export-template install scripts
```

## Known limitations (Phase 1)

- Placeholder, primitive art; not realistic.
- Not yet tested on a physical Galaxy S10: performance and Mobile-renderer appearance are unverified.
- Android export is built by CI only; it has not been confirmed to succeed until a workflow run finishes.
- Statues, columns and rocks are simple shapes; no imported or photo-based assets.


## Added after the first baseline (still Phase 1, environment only)

- **Hamlet of five enterable houses** west of the riverbed (`scripts/house_builder.gd`, `scripts/house_interiors.gd`): real doorways and windows, a partition wall with its own doorway, timber ceiling beams, furniture, a lantern, exterior stairs to a walkable flat roof.
- **Goods line ("maal gaadi")** across the south of the valley (`scripts/railway_builder.gd`): broad-gauge track, a parked goods train (steam locomotive, tender, boxcar, gondola, flatcar, covered wagon, tank wagon), a loading dock you can walk onto and into the boxcar, goods shed, water tower, signal, telegraph poles and cargo carts. The train is static scenery; it does not move.
- Everything is still generated in code; no external assets. All shapes are primitive-built and procedurally textured, so this is stylised, not photo-real.
- Verified: headless import, automated self-test (walk into a house, climb its roof stairs, walk up the dock into the boxcar) and software-GL screenshots. Not tested on a real Galaxy S10; frame rate on the phone is unknown.


## Phase 2: player controller (branch `phase-2-player-controller`)

- **Movement:** real-scale walking (2.4 m/s) and running (6.5 m/s), acceleration and braking, jump with coyote time and jump buffering, automatic step-up over ledges up to 0.45 m, steep slopes slide.
- **Collision:** terrain, houses, walls, train, props and NPCs are solid. A startup pass (`collision_fixer.gd`) adds a collider to any large visible object that had none (196 added); only the stairs are walk-through-by-design because they use a ramp collider.
- **Camera:** third-person orbit with wall collision, pinch / mouse-wheel zoom, small run field-of-view kick.
- **Interaction range:** `Interactable` nodes with a reach; the nearest one in front of the camera is focused, a prompt and a USE button appear. Test interactions: house doors (open/close), sealed entrance door, statues, well (placeholder messages only, no story).
- **Touch controls:** floating joystick with dead zone, look drag, two-finger pinch zoom, RUN, JUMP, USE.
- **Characters:** the player and six ambient NPCs (blacksmith, elder, villager, weaver, rail worker, trader) are jointed procedural humans with faces, hair, clothes and walk / run / idle / hammer animation. NPCs only stand and work; no dialogue, AI or story role. They are stylised low-poly, not photo-real.
- **Tests:** `--selftest` now also checks step-up, wall blocking, jump, camera collision, door interaction, NPC solidity, plus everything from Phase 1. `--audit` lists visible meshes that have no collision.
