# Prompt for the next session: the realistic graphics upgrade

Paste everything below the line into a new session that has this repository attached.

---

You are continuing work on **Royal India Ludo**, a 3D Ludo game for Android built in Godot 4.3
(GDScript), in the repository `ajay34230/Asingh` on branch `ccr-1a31b667-aqu8jk`. The game
project is the `godot/` folder.

**Start by reading `README.md` at the repository root, all of it.** It is the handover
document: what exists, how to run every test, how to build, what was measured, and what is
not done. Then read `dlc/README.md` and `docs/RELEASE.md`. Do not start from zero and do not
replace the project; everything below is an upgrade of what is there.

## Links

Project
- Repository: https://github.com/ajay34230/Asingh
- Work branch (all the work is here, not merged to `main`): https://github.com/ajay34230/Asingh/tree/ccr-1a31b667-aqu8jk
- README, the handover document: https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/README.md
- This prompt: https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/docs/NEXT_PROMPT.md
- Release and signing guide: https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/docs/RELEASE.md
- Asset credits and licences: https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/docs/CREDITS.md
- Graphics-pack guide: https://github.com/ajay34230/Asingh/blob/ccr-1a31b667-aqu8jk/dlc/README.md
- Graphics-pack list the game reads: https://raw.githubusercontent.com/ajay34230/asingh/ccr-1a31b667-aqu8jk/dlc/manifest.json
- Download the branch as a zip: https://github.com/ajay34230/Asingh/archive/refs/heads/ccr-1a31b667-aqu8jk.zip
- Open a pull request to `main`: https://github.com/ajay34230/Asingh/compare/main...ccr-1a31b667-aqu8jk
- The previous session: https://claude.ai/code/session_01KiJHJo8en5g322hA8p4ypj

Tools
- Godot 4.3, editor and export templates: https://godotengine.org/download/archive/4.3-stable/
- JDK 17, for Android builds: https://adoptium.net/temurin/releases/?version=17
- Android Studio and SDK: https://developer.android.com/studio
- Blender, for 3D models: https://www.blender.org/download/
- Kokoro TTS, used for the Hindi voice lines: https://huggingface.co/hexgrad/Kokoro-82M

Free assets (check each licence and record it in docs/CREDITS.md)
- Poly Haven, CC0 textures, HDRIs and models: https://polyhaven.com
- ambientCG, CC0 PBR materials: https://ambientcg.com
- Kenney, CC0 game assets: https://kenney.nl/assets
- Quaternius, CC0 low-poly models: https://quaternius.com

Publishing
- Google Play Console: https://play.google.com/console
- AdMob, for real rewarded videos: https://admob.google.com

## What I want

The game plays well and has a lot in it, but it still looks like a toy. I want it to look
like a premium modern mobile game: realistic mechanical warriors in the spirit of
Transformers, heavy cinematic combat, and a believable Indian royal palace around the board.
It must still run smoothly on cheap Android phones. Think of how PUBG Mobile scales: a low
phone gets a simple version that holds its frame rate, a flagship gets the full show.

I play it on a real phone, and 4-player games felt unplayable there before the last round
of optimisation. Smoothness matters more to me than any single effect.

## Where things stand (details are in the README)

- Tokens are built in code from primitives. The default is a chibi robot knight
  (`godot/scripts/render/knight_pawn.gd`) with one identity per colour, four warrior types
  per colour, and 32 design editions. They are clean and distinct, but they are not
  sculpted models: no mechanical skeleton, no pistons that move, no surface detail from
  textures or normal maps.
- The palace (board, monuments, garden, statues) is partly code-built and partly the GLB
  models I supplied. Statues and plants are heavy and unoptimised.
- Fights are choreographed by tweening the token's shoulder, elbow, wrist, hip, knee and
  ankle pivots (`godot/scripts/animation/transformer_token.gd` and `fight_choreography.gd`).
  There is no skeleton and no imported animation.
- A graphics-pack system exists and is tested (`godot/scripts/app/dlc_manager.gd`, the
  Resource Centre screen, `tools/build_dlc.py`), but no pack has been made.
- Settings already have Graphics style (Classic / Enhanced / Ultra Realistic), quality
  (Low / High / Ultra), a 30/60 fps cap, device detection, a performance guard and dynamic
  resolution. Mesh merging and a far LOD exist for the knight only.
- Nothing has been tested on a real phone. The last measurement on a development machine
  was about 5,600 draw calls and 4.9 million triangles per frame in a 4-player game, and
  the palace is now the biggest cost.

## The hard part, stated plainly

Realistic robots and a realistic palace need real 3D assets: models with proper topology,
UVs, normal maps and PBR textures. A language model cannot sculpt those by writing code,
and the previous session was honest about that. So before building, decide with me how the
assets will be made. The options I can see:

1. Free CC0 assets (Poly Haven, Kenney, Quaternius, ambientCG) for materials, props and
   architecture pieces, checked for licence and recorded in `docs/CREDITS.md`.
2. Models I buy, commission or generate elsewhere and upload as GLB; you import, rig,
   optimise and integrate them.
3. Pushing the code-built approach much further: procedural normal maps and detail
   textures, bevelled hard-surface panels, real moving pistons and gears, layered
   materials, better lighting and post-processing. This can look far better than today
   without any external art, but it will not look hand-sculpted.

Tell me which of these you can do in this environment (check what the network allows), what
each would cost in APK size and frame rate, and recommend one. If option 3 is the only one
available, say so and do it as well as it can be done. Do not present code-built shapes as
"AAA sculpted models".

## Work, in this order

1. **Measure first.** Run the tests in the README to confirm the starting state. Run
   `--perf-test --perf-breakdown` and write down the numbers. Ask me for my phone model
   and what exactly happens in a 4-player game (lag, a freeze at a moment, a crash).
2. **Make the palace cheap.** Merge the board, monuments, statues and garden with
   `MeshMerge` (or better), add LODs, and turn off shadows where nobody sees them. Report
   draw calls and triangles before and after. Also optimise the "Robot" token model, which
   is still about 400 meshes per token.
3. **Lighting and materials.** One good key light with tuned shadows, sky and reflection
   probe on Ultra, ambient occlusion and glow where the phone can afford it, tone mapping
   that keeps colours rich. Marble, sandstone, gold, water and flame that read as those
   materials. Each must have a Low version.
4. **The warriors.** Four masters first, one per colour, with these names: Blue Thunder
   Titan, Green Venom Striker, Red Inferno Destroyer, Yellow Solar Guardian. Then three
   more types per colour, 16 in all. Each needs layered armour with panel gaps, visible
   joints, pistons and gears that actually move when the limbs move, an energy core,
   battle wear, and a silhouette that reads from the normal board camera. They must fill the
   same `TransformerToken` pivots so every existing fight, pose and design keeps working.
   Show me the four masters and get my approval before making the other twelve.
5. **Animation with weight.** Anticipation before a strike, follow-through after, a
   stagger when hit, footfalls that land, a transformation sequence, distinct victory and
   defeat for each colour. Camera shake, sparks, smoke and debris timed to the contact frame.
6. **Packs.** Keep the core APK near its current 68 MB. Put heavy optional content in
   packs built with `tools/build_dlc.py`: an Ultra Realistic Robot Pack, a Royal Palace
   Environment Pack, a Cinematic Effects Pack and an Ultra HD Texture Pack. A pack only
   overrides or adds; with no packs the game must look and work exactly as it does today.
   Publish them where the game reads them (see `dlc/README.md`; files over 100 MB need a
   GitHub Release or a CDN) and test a real download in the Resource Centre.
7. **Three graphics choices that are truly different.** Classic must be the original look
   exactly, Enhanced the optimised upgrade, Ultra Realistic the full version. Switching
   must not need a reinstall, and removing a pack must fall back cleanly.

## Rules

- Upgrade, never replace. Keep every original model, texture and script. New versions sit
  beside the old ones and the player can switch back.
- Do not break what works. After each step, run the full test list in the README; all of
  it passes today. Add a test for anything new that can be tested.
- Low-end phones come first. Every new effect has an off switch tied to the quality level,
  and the performance guard must still be able to rescue a slow game.
- Measure, do not guess. Give me draw calls, triangles and APK size before and after each
  step, and say clearly when a number comes from a development machine and not a phone.
- Never commit the signing key or its password. They live in `build/release/`, outside git.
- New interface text goes through `tr()` with all five Indian languages in
  `godot/scripts/app/i18n.gd`.
- Commit and push to `ccr-1a31b667-aqu8jk` after each working step, with messages that
  say what changed and why. Bump the version in all three export presets and in
  `project.godot` for each build, and build the release-signed APK and the AAB.
- Update `README.md` as you go so it stays the single place that describes the project.

## How to report to me

After each step: what you did, screenshots or a short video of the result, the numbers, what
you could not do and why, and what you need from me. Never say a feature is finished unless
it is built and you have seen it work. If something in this prompt cannot be done here, tell
me at the start, not at the end.
