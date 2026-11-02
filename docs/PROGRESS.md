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

## In progress
- Waiting for the real Part 2 zip before extracting models.

## Pending
- Phase 3: import all 16 supplied GLB models (7 available now, 9 missing).
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
- Not performed: Android build, device tests, visual checks of the Godot scene (no scene yet).

## Remaining limitations
- No Godot scene or rendering yet. Only logic is ported.
- The Android export needs export templates, the Android SDK and a JDK, which are not installed.
