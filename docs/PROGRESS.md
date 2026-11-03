# Development progress

## Completed
- Phase 1: repository audit, engine decision, asset inventory of Part 1 (`docs/AUDIT.md`).
- Godot 4.3 project created (`godot/project.godot`), landscape Android target set.
- Board path ported to GDScript (`BoardPath`): 52-cell ring, four lanes, start
  and star squares, home columns, base spots, finish spots, world mapping.
- Rules engine ported to GDScript (`RulesEngine`): entry, exact finish, captures,
  safe squares, bonus turns, three-sixes forfeit, rankings, game over.
- AI ported (`AiController`), same heuristic as the prototype.
- Headless test suite: 9,834 checks, 0 failures, including 20 full AI games.

- Part 2 zip received and checked: different from Part 1, 9 models, together 16/16.
- All 16 supplied GLB models extracted to `godot/assets/models/` and imported in Godot 4.3
  headless (16/16). Inventory in `docs/ASSET_INVENTORY.md`.

- Board fit: `godot/scenes/main.tscn` shows the supplied board with a straight top-down
  orthographic camera that fits any screen (checked landscape, portrait, phone landscape).
- Board alignment: the ring cells sit on the model's track, and the four token spots sit on
  the model's gold discs (`docs/screenshots/godot-board-alignment.png`).
- Board colours adopted from the model: blue top-left, yellow top-right, green bottom-right,
  red bottom-left. The logic was re-assigned to match.
- Animation script pack (9 GDScript files) installed in `godot/scripts/animation/`, paths
  remapped to the supplied models, all 9 parse without errors. Not run in a scene yet.

## In progress
- Phase 3: token placement on the board, then the animation scripts in a running scene.

## Pending
- Phase 3 (rest): board alignment, token decimation and LODs, and procedural pivot rigs for the limbs (no skeletons in the files).
- Phase 4: token movement and character animation state machine.
- Phase 5: dice presentation tied to the engine result.
- Phase 6-7: environment, lighting, UI, menus, settings, tutorial.
- Phase 8: local multiplayer (two to four humans, pass-and-play) in Godot.
- Phase 9: online multiplayer and backend. Deferred by user decision.
- Phase 10: economy, shop, ads, battle pass. Deferred by user decision.
- Phase 11: Android export, performance, and device tests.

## Bugs found
- See `docs/AUDIT.md` section 5.

## Bugs fixed
- None in the Godot project yet. Two earlier issues in the prototype are noted in the audit.

## Tests performed
- `godot --headless --version`: Godot 4.3.stable.
- Rules and topology headless suite: 9,834 checks, 0 failures.
- Godot GLB import (`tests/asset_check.gd`): 16/16 models imported with measured bounds.
- Animation scripts parse (`tests/parse_scripts.gd`): 9/9.
- Rules suite after the colour re-assignment: 9,673 checks, 0 failures.
- Rendered the board in Godot 4.3 under Xvfb (landscape, portrait, phone landscape).
- Not performed: Android build, device tests, visual checks of the Godot scene (no scene yet).

## Remaining limitations
- No Godot scene or rendering yet. Only logic is ported.
- The Android export needs export templates, the Android SDK and a JDK, which are not installed.


## Phase status (latest update)

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Audit, engine decision, asset inventory | Done |
| 2 | Rules engine + board path (GDScript) | Done. 9,673 headless checks, 0 failures. Full 4-player AI games complete headless. |
| 3 | Import 16 supplied models, place board, tokens, dice | Done for import and placement. Limb rigs are procedural (no skeletons in the files). Token geometry is not decimated yet. |
| 4 | Token movement + animation state machine | Partial. Movement hops along the logical path via the supplied animation pack (`TransformerToken.move_to_world`). Walk/jump/punch/kick/grab/throw are implemented in the pack but not yet triggered by game events. |
| 5 | Dice roll and result presentation | Done. Dice reports tap; engine decides result; dice shows it. All six faces verified numerically (`tests/dice_faces.gd`). Sparkle/glow effects not yet added. |
| 6 | Royal environment, marble, lighting | Partial. Procedural marble shader on tiles and courtyard floors. Decorations placed beside the board (elephant, peacock, statues, fountain, lamps) with their idle scripts. Decoration layout still needs a visual pass; no water shader on the fountain yet. |
| 7 | UI, menus, settings | Partial: in-game HUD (turn, message, new game, result panel). No main menu, lobby, settings, tutorial. |
| 8 | AI difficulty + local multiplayer | AI plays all seats in demo. Difficulty levels not built. Local multiplayer: human seats are configurable in code; no UI for choosing them. |
| 9 | Online multiplayer, backend | Deferred by user decision. |
| 10 | Economy, shop, ads, battle pass | Deferred by user decision. |
| 11 | Android export, performance | Blocked: export templates, Android SDK and JDK not installed. Not attempted. |
| 12 | Full QA, documentation | Partial. Tests listed below. |

### Tests run (Godot 4.3, this container)
- `tests/run_tests.gd`: 9,673 checks, 0 failures.
- `tests/parse_scripts.gd`: 9/9 animation scripts parse.
- `tests/dice_faces.gd`: all six faces, PASS.
- `tests/asset_check.gd`: 16/16 models import.
- `--demo`: a full four-player AI game runs to the end (rankings reported).
- `--click-test` under Xvfb: real mouse input clicks the dice, the engine rolls a six, and a tap on a glowing token moves it from its yard to the start square. PASS.
- Screenshots: `docs/screenshots/godot-game.png`, `godot-game-marble.png`.

### Limits, stated plainly
- Model geometry cannot be made more detailed inside this project. Only materials, lighting, shading and animation can be improved. The supplied models have no skeletons, so limb animation is procedural.
- Android APK, device tests, performance numbers and frame-rate targets have not been measured.
- The animation pack was written without being run in a scene. Its behaviour was tested only through the paths above.


## APK status (2026-11-03)

An arm64 debug APK is built and signed: `build/RoyalIndiaLudo-debug.apk` (92 MB, not committed).
See the next section for how it was produced. Installation and on-device tests are still open.

Earlier status (superseded):

- Done: Godot 4.3 export templates installed (`~/.local/share/godot/export_templates/4.3.stable`).
  Java 21 and the debug keystore are present. The Android export preset is in `godot/export_presets.cfg`
  (arm64-v8a, landscape, package `com.royalindia.ludo`, vibrate permission).
- Blocked: the Android SDK. The export stops with "A valid Android SDK path is required in Editor Settings".
  The command-line tools download from dl.google.com ran at roughly 2 MB a minute here and did not finish.
  The build also needs the platform (android-34) and build-tools (apksigner, zipalign) packages.

To build the APK on a machine with Godot 4.3 and the Android SDK:

    # set the SDK path in Godot: Editor > Editor Settings > Export > Android > Android SDK Path
    godot --headless --path godot --export-debug "Android Debug" build/RoyalIndiaLudo-debug.apk
    adb install -r build/RoyalIndiaLudo-debug.apk

Not verified: installation, launch, touch input, performance, and memory on a device.


## Sound and effects (2026-11-03)

- Sound: 11 original sounds synthesised by `tools/make_sfx.py` (dice roll and landing,
  token select, step, jump, land, capture, finish bell, victory fanfare, UI click, and a
  16 s background loop). No third-party audio. Files in `godot/assets/audio/`.
- `scripts/audio/audio_manager.gd`: separate Music and SFX buses, a 10-voice SFX pool with
  pitch variation, mute, haptics (`Input.vibrate_handheld`), settings saved to `user://settings.cfg`.
  Missing or corrupt settings fall back to defaults.
- `scripts/effects/effects_manager.gd`: spark trails on the dice, landing bursts, capture
  shockwave and burst, finish sparkle, victory fireworks, and confetti for a human win.
- The game controller emits named events (`roll_start`, `roll_land`, `select`, `hop`,
  `land`, `capture`, `finish`, `click`, `game_over`); `main.gd` maps them to sound, haptics,
  effects and a short camera shake on capture.
- Checked: the full AI demo runs with no script errors; the click test still passes;
  effects render (`docs/screenshots/godot-effects.png`).

Not yet done: a settings screen for volume and mute, a per-token walk/jump animation driven
by events, and on-device checks of audio latency and haptics.


### How the APK was built (2026-11-03)

- Android SDK: command-line tools, platform-34, build-tools 34.0.0, platform-tools, installed under `/tmp/claude-0/android/sdk`.
- Godot export templates 4.3.stable installed; Java 21; debug keystore.
- The export failed with a blank message. Reading Godot 4.3's `export_plugin.cpp` showed the cause:
  `has_valid_project_configuration` returns false when ETC2/ASTC texture import is off, and it adds no message.
  Fix: `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`.
- Export: `godot --headless --path godot --export-debug "Android Debug" build/RoyalIndiaLudo-debug.apk`.
- Checked: package `com.royalindia.ludo`, minSdk 21, targetSdk 34, arm64-v8a `libgodot_android.so`,
  APK signed (debug certificate), 239 asset entries including the imported scenes, textures and 11 sounds.
- `aapt` reports one manifest warning about an `android:required` attribute. It comes from the stock
  Godot template and does not block signing or install; check it on a device.
