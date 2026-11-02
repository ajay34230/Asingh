# Royal India Ludo: architecture

A 3D Ludo game for the web (and Android via the browser or a WebView wrapper),
designed for landscape phones. It runs fully offline: the only third-party code
is a vendored copy of Three.js r160 in `vendor/three/`.

## Why Three.js

The repository started with only a README, so there was no existing engine to
inherit. Three.js was chosen because it runs directly in a browser with no build
step, works offline, and can be exercised in headless Chromium for screenshots
and end-to-end tests. Godot or Unity would also be reasonable for a native
Android build; porting the pure-logic layer in `src/game/` is straightforward if
that is wanted later.

## Layout

```
index.html                 page shell, HUD markup, manifest and styles
style.css                  HUD styling, safe-area and landscape rules
manifest.webmanifest       PWA manifest (landscape, fullscreen)
vendor/three/              vendored Three.js r160 (MIT)
src/
  main.js                  boot: scene, views, input, frame loop, debug hook
  game/                    pure logic, no DOM or three.js imports
    layout.js              board topology: ring, lanes, starts, safe cells
    rules.js               Ludo state machine (roll, move, capture, finish)
    ai.js                  heuristic bot; only chooses among legal moves
  app/
    game-controller.js     turn flow, animation sequencing, human input
    hud.js                 DOM overlay: turn banner, toasts, menu, result
  render/
    scene.js               renderer, lights, environment, camera fit, quality
    materials.js           palette, procedural marble/gold textures, PBR materials
    geometry.js            shape and mesh helpers (rounded, chamfered, extrude)
    board.js               foundation, instanced track tiles, courtyard floors,
                           centre triangles, lotus medallion, stars, arrows
    palace.js              pavilions, columns, domes, arches, plants, flags
    tokens.js              pawns, pick proxies, highlight marker
    dice.js                3D dice, pips, tumble and settle animation
    effects.js             tween scheduler, capture sparks, victory confetti
tests/
  layout.test.js           board topology invariants
  rules.test.js            rules, AI, seeded determinism
  e2e/play.mjs             headless browser play-through (Playwright)
  e2e/screenshot.mjs       captures reference screenshots
```

## Single source of truth

`src/game/layout.js` owns every cell coordinate. The rules engine, the AI, the
token animation path and the board tiles all derive their positions from it, so
the visuals can't drift from gameplay. Coordinates are continuous grid values
(`gx`, `gy`, with cell `(c, r)` covering `[c, c+1]`), converted to world space
with `toWorld()` (board centred on the origin, top surface at `y = 0`).

Progress per token:

| progress | meaning                                  |
|----------|------------------------------------------|
| 0        | in the courtyard (base)                  |
| 1 .. 51  | common ring, starting at the start cell  |
| 52 .. 56 | the five cells of the home lane          |
| 57       | finished (centre pad)                    |

Start cells are `entry + 2`, where `entry` is the ring cell at the outer end of
each colour's arm. Stars are placed eight cells after each start. The four inner
corners of the plus-shaped cross are diagonal steps, which is the standard
52-cell topology; the test suite checks that they are the only non-orthogonal
steps.

## Turn flow

`GameController.loop()` is an async loop that awaits each stage:

1. **Roll.** Humans tap the dice (raycast on the dice mesh). `rules.rollDice()`
   draws the value from the seeded or random RNG first. Only then does the dice
   animate to that face. The animation never decides the result.
2. **Move.** With one legal move it is auto-played. With several, the human taps a
   highlighted token. The AI uses `chooseMove()`.
3. **Animate.** `rules.applyMove()` runs first, so logic is never behind the view.
   The token hops square by square, captured tokens arc back to their courtyard,
   and home entry sends sparks from the centre. Then the turn passes or a bonus
   roll is granted.

Input is blocked while the dice is busy or a token is being animated, which
prevents double rolls.

## Rendering

- **Board.** The track is one `InstancedMesh` (72 tiles) with per-instance tints
  for start cells and lanes. Courtyard floors are chamfered, gold-framed extrusions
  with a procedural marble and diamond-inlay texture.
- **Palace.** Each courtyard holds one pavilion (domed chhatri, four columns,
  arches, steps, lantern), two potted plants and a flag. Everything sits inside
  the courtyard, and tokens' spots are offset so nothing overlaps the track.
  Flags and foliage animate on the CPU; all four flags share one geometry.
- **Lotus.** Two rings of gold petals, a ruby centre and a halo sprite that
  breathes.
- **Lighting.** One shadow-casting key light, a hemisphere light and a fill. A
  procedural studio environment map gives the gold and clearcoat something to
  reflect. There is no bloom; glow comes from emissive pulses and additive
  sprites.
- **Camera.** Perspective, with the distance found by bisection so every corner
  of the board volume fits the viewport (`fitCamera`). Phone landscape keeps the
  whole board visible.

## Quality

`QUALITY_PRESETS` in `src/render/scene.js` sets pixel ratio, shadow map size, and
whether shadows are on. Quality can be switched in the menu at runtime. Texture
resolution is chosen at boot (512 px, or 256 px on Low), so changing it to or
from Low needs a reload.

## Testing

- `npm test` runs `node --test`: 22 tests covering board topology (52 ring cells,
  closed loop, lanes, coverage of every cross cell, start and safe-cell spacing)
  and rules (exact finish, captures, safe squares, bonus rolls, three-sixes
  forfeit, rankings, seeded determinism, and 20 full AI-vs-AI games).
- `tests/e2e/play.mjs` drives the real page in headless Chromium: it clicks the
  dice on screen, taps highlighted tokens, and checks that play advances without
  runtime errors. Serve the repo first with `npm run serve`.
- `tests/e2e/screenshot.mjs` writes reference screenshots.

## Known limits

- Android: the app is a web page with a PWA manifest. A native APK (Capacitor or a
  TWA) was not built here, and no Android device or SDK is available in this
  environment.
- Textures are procedural canvas art, not photographic scans. The look is
  stylised rather than an exact copy of the reference image.
- The reference image puts red on both top and left lanes. Each colour here owns
  one arm, in front of its courtyard, so the lanes read consistently: red left,
  green top, yellow right, blue bottom.
