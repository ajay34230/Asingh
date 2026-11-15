# HANDOFF: The Lost Kingdom (read this first)

Single-file brief for any new Claude Code (or other) session. Read this, then `docs/phase1/PHASE_1_REPORT.md` only for the section you need. Keep sessions short: point at files, don't re-explore the whole repo.

## 1. Project in one paragraph
Android 3D adventure in **Godot 4.5.1 (GDScript, Mobile renderer)**. Owner develops from a phone; Android APKs are built by GitHub Actions. Repo `ajay34230/Asingh`. Working branch: `phase-1b-environment-demo` (CI runs on `phase-*` pushes or manual dispatch). Nearly all art is procedural code; characters are Mixamo / CC0 models baked into `assets/anims/mocap.res`.

## 2. Quick start (PC with Claude Code)
1. Install Git, Godot 4.5.1 (https://godotengine.org/download/archive/4.5.1-stable/).
2. `git clone -b phase-1b-environment-demo https://github.com/ajay34230/Asingh.git && cd Asingh`
3. `godot --headless --path . --import` (required after adding any new `class_name`, and after new assets).
4. Self-test: `GODOT=godot tools/dev/run_selftest.sh` → expect `[selftest] PASS`.
5. Screenshots (Linux): `GODOT=godot tools/dev/run_capture.sh <mode>`.

## 3. Repo map
| Path | What it is |
| --- | --- |
| `scripts/main.gd` | World setup, selftests (`_selftest_*`), wiring of systems |
| `scripts/player.gd` | Movement, JOG_SPEED 4.3 / RUN_SPEED 7.4, sprint, jump (`jump_air`, `land`), auto-mantle, combat, wanted level |
| `scripts/real_human.gd` | Procedural rig for every human/creature; `play_clip`, `play_move`, `_loco_set()`, clip sets `brute`/`zombie`/`zombie_runner`/`caster` |
| `scripts/mocap_library.gd` | Loader for `assets/anims/mocap.res` (215 clips) |
| `scripts/npc.gd` | Villagers: knock-out (`ko`, `KO_GRACE` 3 s), brave fight-back, `_guard_attack`, `_rally()` |
| `scripts/rescue_team.gd`, `scripts/vaidya_clinic.gd` | Stretcher rescue after 30 s (`RESCUE_DELAY`), clinic at Vector2(-45, 7) |
| `scripts/police_force.gd` | Constables (`PoliceForce`): wanted → chase → arrest to chowki (-30, -32), fine |
| `scripts/fail_screen.gd` | Fail screen, restart from checkpoint / last mission |
| `scripts/monster.gd` | Monster KINDS table, HP (`float(hp) * 2.6`, bosses 2.0), health bar, `_special()` moves, `_rise_again()` |
| `scripts/enemy.gd` | Enemy roles: grunt, shield, archer, brute, ambusher, zombie, zombie_runner, caster, warrok; `SPELLS`, `_clip_attack`, `_cast`, zombie crawl |
| `scripts/boss_orb.gd` | Projectile (`launch(from,to,dmg,tgt,col,size,slow_s,spd)`), applies `slow_t` |
| `scripts/monster_missions.gd` | Monster missions, `DL_BOSSES`, checkpoints (`<id>_cp` flag), `_spawn_undead` |
| `scripts/hero_store.gd` | Downloadable characters: `CATALOG`, base URL, `HERO_URL` env override for local tests, cache in `user://dlc/` |
| `scripts/dlc_dialog.gd`, `scripts/character_menu.gd` | Download prompt, character menu (Download all, Remove, monsters grid) |
| `scripts/game_menu.gd` | Menu incl. "Start from last mission" |
| `scripts/hit_fx.gd`, `scripts/atmosphere.gd`, `scripts/water_builder.gd`, `scripts/forest_builder.gd`, `scripts/terrain_builder.gd` | Effects, sky globals, palms, forest (ring out to 95 m) |
| `scripts/hindi.json` → `data/hindi.json` | Hindi strings (`Loc.t`) |
| `tools/bake_mixamo.gd` | Bakes `mixamo_src/*.fbx` and `UAL*.glb` → `assets/anims/mocap.res`. Run `--headless --path . --script res://tools/bake_mixamo.gd` after `--import`. LOOPS list controls looping clips |
| `tools/convert_heroes.gd` | FBX → GLB for downloadable characters (renames `mixamorig\d+_` to `mixamorig_` in nodes and skin bind names) |
| `tools/render_portraits.gd` | Makes `assets/heroes/*.png` portraits |
| `tools/dev/` | `run_selftest.sh`, `run_capture.sh` (added with this handoff) |
| `.github/workflows/build.yml` | Import, selftest, screenshots, debug APK. Manual or `phase-*` push |
| `.github/workflows/release.yml` | Release build |
| `docs/phase1/PHASE_1_REPORT.md` | Feature history and addenda per phase |
| `ASSETS.md` | Licences and credits (Mixamo section: not CC0, hosted by owner's choice) |

## 4. Content and licence rules
- `mixamo_src/` is **gitignored** (Adobe Mixamo licence, not CC0). Keep raw FBX out of git. Only converted outputs (`assets/anims/mocap.res`, `dlc` branch GLB/PNG) are committed.
- Quaternius Universal Animation Library = CC0 (`UAL*.glb`).
- Downloadable characters live on the orphan branch `dlc` under `heroes/` (`*.glb`, `*.png`, `index.json`, `README.md`). Raw URL base: `https://raw.githubusercontent.com/ajay34230/Asingh/dlc/heroes/`.
- Monster missions ask to download heavy monster models first.

## 5. Current state (as of 2026-11-15)
- Last commit on branch: `115e289` (graveyard trap fixed, shader restart errors fixed, clinic check steadier).
- **Uncommitted, untested work** (monster upgrades): `scripts/monster.gd`, `scripts/enemy.gd`, `scripts/boss_orb.gd`, `scripts/real_human.gd`, `scripts/player.gd`, `tools/bake_mixamo.gd` (LOOPS adds `zb_crawl`, `zb_stumbling`, `zb_agonizing`), `assets/anims/mocap.res` (rebaked, 11 MB; previous 7.8 MB). These have **not** been compiled or self-tested. Run the selftest before committing.
- **Not applied:** `scripts/monster_missions.gd` has NOT been changed yet for the monster upgrade. Still needed: `m_warrok` mission, `_spawn_undead` call site, Warrok in `DL_BOSSES`, zombie waves using `undead` / `undead_runner` tokens.
- Raw uploaded zombie/spell FBX are in the owner's working copy only (`mixamo_src/zombie/`, `mixamo_src/spell_zip/`, `mixamo_src/zombie_zip/`, `mixamo_src/heroes/warrok.fbx`, `beta.fbx`). They are gitignored and must be re-supplied on a new machine, or the owner copies them from the old working folder.

## 6. Open requests from owner (priority order)
1. Monsters: each behaves differently; zombie, spell, death animations placed at suitable spots; uploaded monster models added; monsters must NOT die to a single arrow; health bars; longer stamina.
2. Warrok (`Falling_Back_Death_3`) and Beta zombie as downloadable characters: `convert_heroes.gd` → portrait → `CATALOG` entry in `hero_store.gd` → upload to `dlc` branch.
3. Verify zb_* and sp_* clips in `mocap.res` visually (captures).
4. Add selftest for new roles and zombie crawl.
5. Update `ASSETS.md` and the report addendum for zombie/spell packs (Mixamo licence).
6. Commit, push, and give the owner the APK link (Actions artifact `TheLostKingdom-debug-apk`).

## 7. Known gotchas
- New `class_name` needs `--import` before scripts compile.
- Editor-only warnings: use `_gparams` tracking in `atmosphere.gd`, not `global_shader_parameter_get_list`.
- Medea-sized characters: the size guard in `real_human.gd` is 0.05 m (was 0.17).
- Horse archery selftest can flake when a passer-by blocks the arrow.
- Clinic selftest waits up to 120 iterations; treatment has a time cap.
- Animated loops: `bake_mixamo` removes root travel and keeps speed in `speed`.
- `HeroStore` must be in the tree before `download` (await `tree_entered`).
- Mocap backup from before the monster edit was kept at `scratchpad/mocap_backup.res`. If it is lost, `git checkout -- assets/anims/mocap.res` restores the committed version.

## 8. Owner preferences
- Develops on a phone: keep instructions short, give direct links (Actions run, artifact name).
- Wants finished features, not explanations of effort. Check features in-game before saying done.
- Mixamo output files come as FBX; never commit them.
- Language: game text in English and Hindi (`data/hindi.json`).

## 9. Links
- Repo: https://github.com/ajay34230/Asingh
- Actions: https://github.com/ajay34230/Asingh/actions
- Godot 4.5.1 archive: https://godotengine.org/download/archive/4.5.1-stable/
- Claude Code docs: https://code.claude.com/docs/en/overview
