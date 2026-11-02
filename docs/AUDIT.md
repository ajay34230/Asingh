# Phase 1: repository audit

Date: 2026-11-02. Scope: the whole repository as of commit `dacd9ad`/`6a1b406`,
plus the supplied uploads.

## 1. What the repository contained at start

- A single README (`# Asingh`), one commit.
- No Godot project, no Unity project, no Ludo code, no assets, no tests.

The project since built in this repo is a **Three.js (WebGL) web game**:

| Area | Files | State |
|------|-------|-------|
| Rules engine | `src/game/rules.js`, `layout.js`, `ai.js` | Working, 22 Node tests passing |
| Board renderer | `src/render/*.js` | Working, procedural 3D board (tiles, courtyards, palaces, lotus) |
| Controller/HUD | `src/app/*.js`, `index.html`, `style.css` | Working, offline 2/4-player and pass-and-play |
| Assets | `assets/board/*` | GLB board generated from the reference image, not used by the game |
| Tests | `tests/*.test.js`, `tests/e2e/*.mjs` | Unit tests pass; e2e drives Chromium but is slow under software GL |

## 2. Decision: engine

The spec asks for Godot 4.x. The user left the choice to me ("choose whatever
makes it much better"). Decision: **build the full game in Godot 4.3**.

Reasons: native skeletal animation and AnimationTree for the characters,
Android export and mobile renderer, and a scene-based structure that fits the
spec's modular systems. The Three.js prototype stays in `src/` as a reference
and web build; its rules are ported 1:1 into `godot/`.

Godot 4.3.stable was downloaded from the official GitHub release and runs
headless on this Linux container (`--headless --version` returns 4.3.stable).

## 3. Blocked or not yet verified

| Item | Status |
|------|--------|
| Godot 4.3 editor and headless tests | Available and used |
| Android export (APK) | Blocked: needs Godot export templates (about 1 GB), Android SDK, JDK 17 and a debug keystore. Not attempted yet. |
| Part 2 model zip | Missing. The uploaded "Part 1" zip was uploaded twice (identical SHA-256). |
| 16 supplied GLB models | 7 in Part 1 only. Several spec filenames (dice, red and yellow tokens, statues, lotus fountain) are not in Part 1. |
| Backend, accounts, ads, payments | Deferred by user decision |

## 4. Part 1 model inventory (not yet imported)

Checked only by listing the archive; the archive has **not** been extracted.

| File in archive | Spec name | Status |
|-----------------|-----------|--------|
| 01_Board/Royal_India_Final_Ludo_Board.glb | A. board | Present |
| 03_Player_Tokens/Royal_Green_Token.glb | C. green token | Present |
| 03_Player_Tokens/Royal_Blue_Token.glb | C. blue token | Present |
| 04_Character_Limbs/Royal_Red_Token_Folding_Limbs.glb | D. red limbs | Present (spec lists it) |
| 05_Animals_and_Statues/Royal_India_Elephant.glb | E. elephant | Present |
| 05_Animals_and_Statues/Royal_India_Peacock_HighPoly_Textured.glb | E. peacock | Present |
| 06_Decorations/Royal_India_Deepam_Lamp_Set.glb | F. lamps | Present |
| 02_Dice/Royal_India_Royal_Jewel_Dice.glb | B. dice | Missing from Part 1 |
| 03_Player_Tokens/Royal_Red_Token.glb, Royal_Yellow_Token.glb | C. tokens | Missing from Part 1 |
| 04_Character_Limbs/ blue, green, yellow limbs | D. limbs | Missing from Part 1 |
| 05_Animals_and_Statues/ elephant statue, peacock statue | E. statues | Missing from Part 1 |
| 06_Decorations/Royal_India_Lotus_Fountain.glb | F. fountain | Missing from Part 1 |

Next step: upload the real Part 2 zip. I will check it, then extract both
archives into `godot/assets/models/` preserving folder structure.

## 5. Bugs found in the existing code (prototype)

1. Tokens and the reference-image pawns did not align in the image-textured
   board (about a quarter cell). Resolved by removing the image texture.
2. Image-textured board duplicated the painted pawns and dice under the 3D
   pieces. Resolved by the procedural board.
3. The e2e play-through only observed two token moves in its time budget, so
   captures are covered by unit tests only.

## 6. Godot port

- `godot/scripts/game/board_path.gd` - topology (`BoardPath`).
- `godot/scripts/game/rules_engine.gd` - rules (`RulesEngine`).
- `godot/scripts/game/ai_controller.gd` - heuristic AI (`AiController`).
- `godot/tests/run_tests.gd` - 9,834 headless checks, 0 failures.

Run: `godot --headless --path godot --import` then
`godot --headless --path godot --script res://tests/run_tests.gd`.
