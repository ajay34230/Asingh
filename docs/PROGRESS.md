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
