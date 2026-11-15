# Performance plan: The Lost Kingdom

Goal: smooth play on phones like the Galaxy S10 without making the game look worse.
Rule: one small step at a time. After every step, re-check all earlier steps (self-test, profile, and that each earlier fix is still in effect) before starting the next.

## Starting point (2026-11-15)
- Galaxy S10: 7 fps on the High preset, about 19 fps on Low. CPU-bound. Same on Godot 4.4.1 and 4.5.1.
- PC headless profile at the farm (152, 161): enemies 2.7 ms, villagers 2.0 ms, player 1.0 ms per frame.
- Done already (commit 96e9055): activity manager (50 m on screen, missions 100 m), far enemies paused, phones start on Low, presets set shadows, faster adaptive quality, 20 m health bars. Activity manager saves about 5.9 ms a frame at the farm.

## Phases (no visual downgrade in any of them)
| Step | What | Status |
|---|---|---|
| 1.1 | Limit catch-up physics: at most 4 physics steps per frame, so a slow frame cannot snowball | done |
| 1.2 | Animate characters 20 to 50 m away less often (15 to 30 times a second) | done |
| 1.3 | Pre-build shaders when exporting (Godot 4.5 shader baker): no first-time stutter | set; needs a GitHub build to confirm the export still works |
| 1.4 | Cache lists that hot scripts rebuild every frame (arrows, minimap) | checked: nothing worth caching (no script other than the player costs over 0.35 ms after 1.2) |
| 2 | Physics at 30 steps a second with physics interpolation | tried and reverted: the movement code (step-up, ledge grab, jump timing) is tuned to 60 Hz; at 30 Hz the climb self-test walked through a 1.5 m wall |
| 3 | Merge repeated objects | skipped: the game already merges static meshes by material and 24 m cell; the phone is CPU-bound, not draw-bound (about 420 draws on Low) |
| 4 | Occlusion culling | done: 137 box occluders on large building and wall colliders, occlusion culling on |
| 5 | Save the generated world (37 s start on the S10) | not started: a large rewrite (builders hold references gameplay uses); needs its own project |
| 6 | Engine-run crowd animation | not started: rewrite of the 2,600-line rig; the biggest remaining CPU win (the bazaar, about 0.3 ms per active villager on the PC) |

## How each step is checked
1. Self-test: `--headless --fixed-fps 60 --path . -- --selftest` must print `[selftest] PASS` with no script errors.
2. Profile: `--headless --fixed-fps 60 --path . -- --profile` (frame time at the farm, per-script cost, activity manager on/off).
3. Earlier steps: each one's own check below is re-run.
4. On the phone when a build is installed: frame rate from Android's display system (`dumpsys SurfaceFlinger --latency`).

## Results log
- 2026-11-16, lag-fix build 96e9055 on the S10: settings migration worked on the phone (Low preset now has Low shadows, gfx_rev 2). The on-screen counter read in the 20s; a full measurement is still to do.
- 1.1 (max 4 physics steps per frame): self-test PASS, activity manager still pausing 156 characters. Effect only shows when the phone falls behind, so it is checked by setting, not by the PC profile.
- Bug fix alongside: the chosen downloaded character was lost on every mission restart, checkpoint and app launch (settings reload dropped it). Kept now, with a self-test.
- 1.2 (distance-based pose rate): self-test PASS with 1.1 and 1.2 re-verified. PC profile at the farm: 4.24 ms per frame (was about 7 ms). Top remaining cost: the player at 1.0 ms; everything else under 0.35 ms.
- 1.3 (shader baker on both Android presets): self-test checks the setting; the GitHub export will show whether baking works headless.
- 1.4: nothing worth caching after 1.2; the player's interactable search already runs 10 times a second.

## Checks that every step re-runs (the `perf steps verified` line in the self-test)
- 1.1 `Engine.max_physics_steps_per_frame == 4`
- 1.2 pose step is 0 within 20 m, 1/30 s to 35 m, 1/15 s beyond, and the player's own rig is never throttled
- 1.3 `shader_baker/enabled=true` in both Android presets
- 2026-11-16 one combined check (`tools/dev/check_all.sh`): self-test PASS with 1.1, 1.2, 1.3 and 4 verified. Running the character (PC, ms per frame): farm 4.2, clinic 5.3, police post 8.1, centre 8.0, bazaar about 18 to 24 (55 characters active). One 132 s frame at the clinic was the PC pausing; a re-run there gave 5.3 ms.
- Activity manager: off-screen safety radius cut from 12 m to 6 m; bazaar active characters 55 to 38.
- Button layout editor (Settings > Controls) and finger-swipe scrolling for all menu lists added alongside.
