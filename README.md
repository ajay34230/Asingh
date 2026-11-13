# Royal India Ludo

A 3D Ludo game for Android phones (landscape), built in **Godot 4.3** with GDScript. Four
palace courtyards, armoured robot-knight tokens that fight when one captures another, Hindi
voice lines, a shop of collectible token designs, a story campaign, and Wi-Fi multiplayer.

This file is the handover document: what exists, where it is, how to run, test and build it,
what has been measured, what is not done, and the prompt for the next piece of work.

- **Current version:** 1.11.1 (version code 16), debug build only (see "Known problems"). Release 1.10.1 (code 14) is the last signed build. Old note: the branch was one commit
  ahead of that build (token LOD, warrior types, metal-hit effects); the next build should be 1.11.0.
- **Work branch:** `ccr-1a31b667-aqu8jk` (default branch is `main`; the work is not merged).
- **Package name:** `com.royalindia.ludo`
- **Size:** release APK about 68 MB, Play Store bundle (AAB) about 68 MB.

## Links

| What | Link |
|---|---|
| Repository | https://github.com/ajay34230/Asingh |
| Work branch | https://github.com/ajay34230/Asingh/tree/ccr-1a31b667-aqu8jk |
| This README on the branch | https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/README.md |
| Download the branch as a zip | https://github.com/ajay34230/Asingh/archive/refs/heads/ccr-1a31b667-aqu8jk.zip |
| Open a pull request to `main` | https://github.com/ajay34230/Asingh/compare/main...ccr-1a31b667-aqu8jk |
| Graphics-pack list the game reads | https://raw.githubusercontent.com/ajay34230/asingh/ccr-1a31b667-aqu8jk/dlc/manifest.json |
| Graphics-pack guide | [dlc/README.md](dlc/README.md) |
| Release and signing guide | [docs/RELEASE.md](docs/RELEASE.md) |
| Asset credits and licences | [docs/CREDITS.md](docs/CREDITS.md) |
| Prompt for the next work | [docs/NEXT_PROMPT.md](docs/NEXT_PROMPT.md) |
| Godot 4.3 (editor and export templates) | https://godotengine.org/download/archive/4.3-stable/ |
| JDK 17 (needed for Android builds) | https://adoptium.net/temurin/releases/?version=17 |
| Android Studio / SDK | https://developer.android.com/studio |
| Google Play Console | https://play.google.com/console |
| AdMob (for real rewarded videos) | https://admob.google.com |
| Blender (for sculpted 3D models) | https://www.blender.org/download/ |
| Poly Haven (CC0 textures and models) | https://polyhaven.com |
| Kokoro TTS (the Hindi voice lines) | https://huggingface.co/hexgrad/Kokoro-82M |

## Repository layout

```
godot/                     THE GAME (Godot 4.3 project). Open this folder in Godot.
  project.godot            project settings; config/version must match export_presets.cfg
  export_presets.cfg       three presets: "Android Debug", "Android Release" (AAB),
                           "Android Release APK"
  scenes/main.tscn         the one scene; everything else is built in code by main.gd
  scripts/main.gd          orchestrator: builds the world, routes game events to sound,
                           effects and voice, applies settings, and holds every test mode
  scripts/game/            rules_engine.gd, board_path.gd, ai_controller.gd, game_controller.gd
  scripts/render/          board, monuments, garden, dice, tokens (see "Token models"),
                           token_designs.gd, mesh_merge.gd, camera_director.gd
  scripts/animation/       transformer_token.gd (token rig), fight_choreography.gd,
                           fight_replay.gd, token_life.gd
  scripts/app/             progress.gd (coins, shop, rentals, shards, mastery, sets),
                           game_settings.gd, i18n.gd, festivals.gd, campaign.gd,
                           dlc_manager.gd, rewarded_ads.gd
  scripts/net/net_play.gd  Wi-Fi multiplayer (host-authoritative ENet + UDP discovery)
  scripts/ui/              menu.gd, hud.gd, royal_theme.gd, tutorial.gd, loading_screen.gd
  scripts/audio/           audio_manager.gd, voice_manager.gd
  scripts/effects/         effects_manager.gd
  assets/                  models, textures, fonts, audio (127 MB of sources)
  tests/                   headless tests (see "Tests")
dlc/                       manifest.json and packs/ for downloadable graphics packs
tools/                     build_dlc.py, make_voice.py, make_music.py, import_sfx.py
docs/                      RELEASE.md, CREDITS.md, ARCHITECTURE.md, NEXT_PROMPT.md, older notes
build/                     NOT IN GIT: built APK/AAB, videos, and the signing key
index.html, src/, vendor/  the first web prototype (Three.js). Superseded by godot/; kept as is.
```

About 16,000 lines of GDScript. Nearly all 3D content except the palace decorations and
plants is generated in code, which is why the APK stays small.

## What is in the game

**Play**
- Ludo for 2 to 4 seats: play against the computer, pass-and-play, team battle (2 v 2),
  Snakes & Ludo, Blitz (8-second turns), power-ups (shield, extra roll), quick play.
- House rules: six to start, three-sixes penalty, capture bonus, home bonus, quick end.
- Royal Journey: a 5-chapter campaign across palaces (Jaipur, Mysore, Kerala, Delhi, Diwali).
- Wi-Fi multiplayer: one phone hosts, friends on the same Wi-Fi join; empty seats are
  computer players. Host and joiner end with identical boards in the test.
- Tutorial, turn timer, tap-to-skip fights, instant replay of a fight.

**Computer players (`scripts/game/ai_controller.gd`)**
- Four named personalities with attack, safety and race weights.
- Each legal move is simulated: the AI compares what all its tokens stand to lose before
  and after (a token within one throw of an enemy is at risk), captures with whichever
  token can, knocks out an enemy that threatens another of its tokens, and keeps tokens
  near enemies it can hunt. Three tests cover this at every difficulty level.

**Fights (`scripts/animation/fight_choreography.gd`)**
- Face-off, exchange (counter or dodge), two jabs, a finisher, dazed, grab-and-throw home.
- Normal finishers: uppercut, spinning kick, flying kick, overhead slam.
- Signature finishers for seven Legendary designs: Garuda Dive, Tandava, Gada Prahaar,
  Surya Blast, Shadow Strike, Laser Beam, Possessed.
- Slow motion, hit-stop, camera cuts, impact frame, smoke, metal debris and sparks.

**Token models (Settings > Token model)**
| Setting | Script | What it is |
|---|---|---|
| Robot knight (default) | `render/knight_pawn.gd` | A chibi armoured robot knight on a round base. One identity per colour: Blue Frost Knight (cat ears, kite shield), Red Peacock Knight (feather fan, buckler, talwar), Green Guardian Knight (round sensor ears, tower shield), Yellow Sun Knight (halo of rays, sun-disc shield). Colour stripes on every armour piece. |
| Robot | `render/robo_pawn.gd` | The earlier pawn-shaped robots with reactor, optics and crests. Heavy: about 400 meshes per token, not yet merged. |
| Royal pawn | `render/royal_pawn.gd` | A smooth metallic pawn with gold trims and gem eyes. |
| Original | supplied GLB models | The first token models, kept unchanged. |

- **Warrior type (Settings):** Master, Heavy (back cannons), Striker (fins and forearm
  blades), Commander (cape and gold crown ring). 4 colours x 4 types = 16 warriors. The
  player picks theirs; other seats get one at random.
- **Token designs (`render/token_designs.gd`):** 33 collectible designs in five rarities
  (Common, Rare, Epic, Legendary, Festival). On the knight each design is a full edition:
  armour finish, stripe colour, glow colour and head gear. The Ghost is see-through with
  drifting wisps. Epic and above have an aura ring; Legendary and Festival leave a trail.

**Shop and progression (`scripts/app/progress.gd`)**
- Coins from games, daily rewards (7-day streak), 19 achievements, weekly challenges.
- Royal Bazaar: board themes, dice skins, token skins, victory effects, dice trails, designs.
- Designs can be bought, rented by watching videos (Rare 1 video = 24 h, Epic 2 = 24 h,
  Legendary 3 = 12 h, 8 videos a day), rented with a Royal Ticket (24 h), or tried free once
  for 15 minutes. Rentals count down and fall back to Classic.
- Shards (3 for a win, 1 otherwise, towards a design the player picks), mastery stars
  (10, 25, 50 games in a design), six collection sets that pay coins and unlock titles.
- Customising: metal finish (gold, silver, rose gold, onyx) and aura colour.
- Profile: name, XP levels, frames, titles. Festivals by calendar date double coins.

**Sound and language**
- Recorded sound effects (CC0), two music tracks, Hindi announcer and token voices made
  with Kokoro, with captions and speech bubbles. 25 designs have their own victory line.
- Interface in English, Hindi, Marathi, Bengali, Tamil and Telugu (`scripts/app/i18n.gd`).

**Graphics settings**
- Graphics style: Classic (forces the original token models), Enhanced, Ultra Realistic
  (always full effects).
- Graphics quality: Low, High, Ultra (stored as `low`, `medium`, `high`).
- Frame rate: 30 or 60 fps. Larger text, colour-blind symbols, relaxed AI pace.
- First launch picks a quality from the processor count and graphics chip name.
- Performance guard: under about 26 fps for 3 seconds, resolution drops first
  (to 70 %), then quality, with a message.

**Graphics packs (DLC)**
- `scripts/app/dlc_manager.gd`: manifest, cached list for offline, resumable downloads with
  retry, SHA-256 check, PCK mounting and remount at start, updates, removal, minimum game
  version. `Settings > Resource Centre` is the screen.
- `tools/build_dlc.py` builds a pack and updates `dlc/manifest.json`. See `dlc/README.md`.
- **No packs exist yet.** The manifest is empty and the Resource Centre says so.

## Running it

1. Install Godot 4.3 (standard build, not .NET).
2. Open the `godot` folder as a project. Press F5.
3. A fresh clone must import once before any headless command:
   `godot --headless --import --path godot`. Do this again after adding a script with a new
   `class_name`, or the class is not found.

## Tests

Run from the repository root with `godot` on the path. Tests that open a window need a
display (on a server: `xvfb-run -a -s "-screen 0 1560x720x24"` before the command and
`--rendering-driver opengl3`).

| Test | Command | Passing result |
|---|---|---|
| Rules, modes, AI tactics, full AI games | `godot --headless --path godot --script tests/run_tests.gd` | `N checks, 0 failures` (about 20,000) |
| Coins, shop, rentals, shards, mastery, sets | `godot --headless --path godot --script tests/progress_test.gd` | `PROGRESS TEST PASS` |
| A whole 4-player game, fast | `godot --headless --path godot -- --demo --players=4 --seed=7` | `DEMO RESULT: [...]` |
| Menus scroll, close, resume, video rental | `godot --path godot -- --ui-test` | `UI TEST PASS` |
| Real taps on dice and token | `godot --path godot -- --click-test --seed=3` | `CLICK TEST PASS` |
| One capture fight at normal speed | `godot --path godot -- --capture-test` (add `--finisher=slam`, `--finisher=garuda_dive`, `--replay`) | `CAPTURE TEST PASS` |
| Royal Journey starts from the menu | `godot --path godot -- --journey-test` | `JOURNEY TEST PASS` |
| Wi-Fi game, two instances | `-- --net-host-test --seats=4 --rules=snakes,powerups` then `-- --net-join-test` (both `--headless`) | two identical `NET RESULT` lines |
| Draw calls and triangles in a 4-player game | `godot --path godot -- --perf-test --seats-n=4 --token-style=knight --perf-breakdown` | a `PERF:` line |
| Scenery merging (needs a display, not `--headless`) | `godot --rendering-driver opengl3 --path godot --script tests/merge_test.gd` | `MERGE TEST PASS` |
| Graphics packs | `python3 godot/tests/dlc/server.py <pck> <port> <log>` then `DLC_PORT=<port> godot --headless --path godot --script tests/dlc/dlc_test.gd` | `DLC TEST PASS` |

Measuring flags: `--quality=low|medium|high` and `--gfx-style=classic|enhanced|ultra` force a
level for one run; `--no-bake` turns scenery and Robot merging off, to compare numbers or to
rule the merge out when something looks wrong.

All of these passed at the last commit. The progress and DLC tests use their own save
data; set `XDG_DATA_HOME` to a scratch folder to keep test runs away from a real save.

Screenshot helpers (all take `--screenshot=<file.png>`, `--no-ui`, `--cam=x,y,z,tx,ty,tz`,
`--shot-delay=<s>`): `--lineup` (four tokens facing the camera; `--token-style=`,
`--variant=`, `--lineup-designs=a,b,c,d`, `--celebrate`), `--design-gallery` (every design
on the board), `--menu-screenshot=<file> --menu-page=<page>`, `--result-shot=<file>`.
Add `--write-movie <file.avi> --fixed-fps 24` to record a video.

## Building for Android

Needs the Android SDK, JDK 17, Godot 4.3 export templates, and the Android build template
unpacked into `godot/android/` (that folder is not in git). Full steps: `docs/RELEASE.md`.

```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=build/release/royalludo-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=royalludo
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
godot --headless --path godot --export-release "Android Release APK" ../build/release/RoyalIndiaLudo-release.apk
godot --headless --path godot --export-release "Android Release"     ../build/release/RoyalIndiaLudo.aab
godot --headless --path godot --export-debug   "Android Debug"       ../build/RoyalIndiaLudo-debug.apk
```

- Bump `version/code` and `version/name` in **all three** presets in
  `godot/export_presets.cfg`, and `config/version` in `godot/project.godot` (graphics packs
  check it).
- The Gradle build sometimes fails with a Maven "429 Too Many Requests"; run it again.
- **The signing key is not in git.** `build/release/royalludo-release.keystore` and its
  password file exist only where the builds were made. Google Play needs the same key for
  every update, so it must be copied somewhere safe. A new clone cannot sign a release
  until the key is put back at that path. Never commit it, and never write the password
  into `export_presets.cfg`.
- A phone with a debug build must uninstall it before installing a release build.

## Performance (measured on a development machine, not on a phone)

A 4-player game puts 16 tokens on the board. Counted per frame, including shadow passes,
with `--perf-test --seats-n=4 --quality=<level>` on a server with a software renderer. The
counts are exact; the frame rate of that machine means nothing for a phone.

History of the default knight model at High quality (`medium`):

| Stage | Draw calls | Triangles |
|---|---|---|
| Before optimisation (each knight about 270 meshes) | 21,500 | 9.0 million |
| Knights merged to about 24 meshes each, decoration shadows off below Ultra | 8,600 | 6.1 million |
| Plus a single far mesh per knight beyond 16 units and automatic mesh LODs | 5,582 | 4.92 million |
| Plus the palace merged (board, statues, fountain, lamp, dice, dice holder) | 2,457 | 3.49 million |

The palace merge at each quality level, knight model:

| Quality (setting name) | Draw calls before | after | Triangles before | after |
|---|---|---|---|---|
| Low (`low`) | 1,445 | 762 | 1.26 million | 0.55 million |
| High (`medium`) | 5,582 | 2,457 | 4.92 million | 3.49 million |
| Ultra (`high`) | 6,788 | 3,030 | 6.81 million | 4.54 million |

Shadow passes (version 1.11.1). The settings code used to switch shadows on for the fill
light as well as the sun, and both used four cascades, so the scene was drawn into eight
shadow maps a frame. Now only the sun casts shadows; phones use two cascades, a cheaper
shadow filter, 2x anti-aliasing on Ultra (4x before) and no plant shadows. A desktop on
Ultra keeps four cascades and 4x. `--as-phone` applies the phone rules on a desktop run.

| Quality, knight model | Draw calls before | after | Triangles before | after |
|---|---|---|---|---|
| High (`medium`) | 2,457 | 1,194 | 3.49 million | 1.65 million |
| Ultra (`high`), phone rules | 3,030 | 1,267 | 4.54 million | 1.65 million |
| Ultra (`high`), desktop | 3,030 | 1,834 | 4.54 million | 2.95 million |

Other token models at High quality (measured before the shadow change):

| Token model | Draw calls before | after | Triangles before | after |
|---|---|---|---|---|
| Robot (parts merged per moving group) | 32,320 | 15,503 | 8.84 million | 4.80 million |
| Royal pawn (palace merge only) | 9,053 | 5,894 | 7.47 million | 5.70 million |
| Original (palace merge only) | 7,023 | 3,909 | 8.67 million | 7.26 million |

How it is done:
- `render/mesh_merge.gd`, `bake`: groups of small token meshes become one mesh with a surface
  per material, built once per colour and warrior type and shared. Designs recolour a token
  with per-instance surface overrides. `KnightPawn.add_lod` adds the far mesh.
- `bake_static`: scenery that never moves becomes one mesh per object (two if some parts cast
  no shadow). Supplied models get three detail levels (full, about half, about a fifth of the
  triangles) and `MeshMerge.apply_detail` swaps them when the quality setting changes.
  Classic and Ultra Realistic styles always use full detail. The board keeps its plaques
  and lamp flames as separate nodes because they move.
- `bake_split` and `RoboPawn.optimise`: the Robot model is merged per moving group (body,
  head, each eye, each crest piece, each limb segment), with glowing parts kept in their own
  mesh so designs do not repaint them.
- Screenshots with and without the merge were compared and match.

What is still heavy:
- The garden: 112 plant meshes and about 0.7 million triangles at High and Ultra (hidden at
  Low). Every plant has its own wind material, so merging gains little; it needs lighter
  plant models or impostors.
- The tokens: 16 knights are about 1,200 surfaces and 0.8 million triangles.
- The Robot model is still about 15,500 draw calls with 16 tokens. It is much better than
  it was, but the knight is the model to use on a phone.
- The board is one merged mesh of 0.64 million triangles (round shapes built with many
  segments). It has no reduced levels yet.

**None of this has been run on a real phone.** The frame-rate numbers that matter do not
exist yet.

## Known problems and gaps

- **No phone testing.** Everything was checked with tests and screenshots on a server.
  The user reported 4-player games as "not playable" on their phone before the
  optimisation work; it has not been confirmed fixed on that phone.
- **A fight once left the game stuck.** During a video recording, a Nataraja (Tandava)
  fight finished but the turn never moved on. It did not happen again in any later run,
  and the cause is not found. Worth a stress test (run that fight in a loop).
- **Real video ads are not connected.** Debug builds play a labelled 6-second test video;
  release builds hide the "Watch video" button until a provider is set
  (`RewardedAds.provider`, see `docs/RELEASE.md`).
- **The "Robot" token model is only half optimised** (merged per moving group; see Performance).
- **The graphics-pack link points at the work branch.** After merging to `main`, change the
  branch name in `DLCManager.DEFAULT_MANIFEST_URL` and in `tools/build_dlc.py`, or the
  Resource Centre stops finding packs. GitHub also refuses files over 100 MB.
- **Removing a pack needs a restart** (Godot cannot unmount a loaded pack).
- **Classic graphics only switches the tokens** back to the original models. The board,
  palace and lighting have one version.
- **Device detection is a guess** from processor count and chip name.
- **Play Store listing** still needs a privacy policy URL, content rating and screenshots.
- `docs/PROGRESS.md`, `docs/FEATURES.md` and `docs/AUDIT.md` are from the first weeks and
  are out of date; this README replaces them.

## Not done from the "AAA graphics" request

The request asked for a console-quality look. These parts were **not** made:

- Sculpted, textured robot models. The 16 warriors are four variations of the code-built
  knight per colour, not unique Transformers-style machines with mechanical skeletons.
- A rebuilt palace, courtyard and props with new materials, water and flames.
- New walk, run, transformation, damage and defeat animations with real weight.
- The four heavy packs (robots, palace, cinematic effects, HD textures).
- Occlusion culling, memory-aware loading of large assets, thermal handling.
- A separate `RoyalIndiaLudo-DLC` repository (the session could not create repositories;
  packs are served from this repository instead).

These need real 3D models and textures. The practical routes are a 3D artist, models
bought or licensed, or CC0 sources such as Poly Haven, imported as GLB and delivered as
packs. `docs/NEXT_PROMPT.md` is written for that work.

## Conventions for whoever works on this next

- GDScript with static typing. A script with a `class_name` needs `--headless --import`
  before it can be used from the command line.
- Never name a signal or method after a built-in one (`theme_changed`, `_get`, `_set`
  caused parse errors earlier).
- The token rig is `TransformerToken`: `body_node`, `limb_root`, `arm_pivots` and
  `leg_pivots` (shoulder/elbow/wrist, hip/knee/ankle). The model's front is +Z. Every
  token model must fill those pivots so fights and poses keep working. Design gear is
  named `DesignGear*` so it can be removed.
- Fight timing uses real-time deadlines in `FightChoreography._process`, not nested timers,
  so slow motion can never leave the game stuck.
- New interface text goes through `tr()` and into the table in `scripts/app/i18n.gd`
  (English key, then Hindi, Marathi, Bengali, Tamil, Telugu). Duplicate keys are a parse error.
- `.import` files are committed on purpose; they hold the texture compression settings
  that keep the APK small.
- Commit messages say what changed and why; `build/` and `godot/android/` stay out of git.
