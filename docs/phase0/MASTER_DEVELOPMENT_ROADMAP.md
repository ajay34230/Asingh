# Master Development Roadmap (Phase 0)

Order follows your phase table, with two changes justified by dependencies (marked **change**). Each phase ends with a Phase Report and **waits for your approval**.

## Ground rules applied to every phase
- Work on a branch named `phase-N-<name>` (CI builds only `phase-*`); never reset or force-push; the unreleased pond/sky work stays on `wip/pond-sky-flora` until Phase 1 reuses it.
- Gate before a phase is called done: automated self-test PASS, project import with no script errors, CI debug APK built, release `debug-latest` updated, commit ID reported. Anything I cannot do (real phone frame rate, touch feel, TTS voices, thermals) is reported as **not tested on a device** and left for your feedback.
- Honest reporting: desktop/software-render screenshots are labelled as such.

## Phase 0.5 (change): foundation, small and invisible to players
Needed before Phase 2 because inventory and everything after it must save.
1. Save v2: versioned JSON, atomic write (temp file + rename), `.bak` of the previous save, migration from the current v1 format, corruption fallback, load feedback. Old saves keep working.
2. One `GameState` owner for flags, with namespaced IDs and a documented API; the existing `Story.flags` keep working through it.
3. Data folder for item/quest/shop definitions (JSON), so content is data, not code.
Acceptance: all current self-test checks pass; an old v1 save loads; a truncated save falls back to the `.bak`; no behaviour change in play.
Risk: low. Test: corrupt/old/mid-write save tests.

## Phase 1: environment demonstration (desert + village only)
Sub-phases:
- 1a Water (new requirement: **GTA IV-style water**). Target look: dark green-grey body colour, strong sky/sun reflection by Fresnel, large soft rolling normal-map waves plus fine ripples, bright sun glints, depth-based colour (shallow lighter), white foam along the shore and around rocks, slight shoreline wetness on the ground. Mobile approach: shader with two scrolling normals, Fresnel sky reflection, screen-depth fade (depth texture is available on Mobile), optional planar reflection on High only. True GTA IV screen-space reflections are not available on the Mobile renderer; I will say so rather than fake it in the report.
- 1b Terrain: erosion look, path painting between village/goods yard/caravan/dig site/gate, footprints (pooled), proper ground-material blending, rocks.
- 1c Vegetation kit: palms, bushes, grass, flowers, dead trees, with wind sway, MultiMesh and visibility ranges (reuse the WIP flora code).
- 1d Sky/lighting: 8 lighting conditions, cloud layer, haze, mountain fog, night that is not just darkened day.
- 1e Weather polish: wind, rain with splashes and wetness (see matrix rows W, R).
- 1f Real Low/Medium/High tiers (shadow distance, foliage density, view distance, effects) and in-engine screenshots at all three.
Acceptance: screenshots from the real engine for Low/Med/High; no floating objects; collisions intact; self-test PASS. **Wait for your approval before applying the standard to the whole world.**
Risks: foliage and water cost on a phone; no device FPS available to me.

## Phase 1.5 (change): controls and locomotion
Moved early because every combat, mount and exploration feel depends on it, and you asked for it directly.
- BGMI-style floating joystick, tuned look sensitivity, sprint lock, crouch, auto-run, customisable layout/size, left-hand mode.
- Walk/run/sprint blend with acceleration, landing and jump poses, stride-matched footsteps, camera FOV kick.
Acceptance: multi-touch stress test, no stuck touches, jump/step/wall tests still PASS. Feel can only be confirmed by you on the phone.

## Phase 2: inventory and equipment
Item definitions (JSON), inventory grid UI, equipment slots, weapon held in hand (bone attachment), armour stats, loot into inventory, shops using the existing `cost`/`give` dialogue keys, full persistence. Acceptance: a dropped item can be picked up, equipped, changes damage, survives save/load.

## Phase 3: advanced combat
Stamina, light/heavy attack, combo, block, parry, dodge/roll (new procedural poses), enemy archetypes with telegraphs, Karan unchanged in outcome. Acceptance: damage tables tested, no soft-locks, boss still beatable.

## Phase 4: mounts (horse, camel, donkey, others)
One generic `Mount` component using the animals already in `assets/animals`. Acceptance: mount, ride (walk/trot/gallop), slopes, stamina, dismount on safe ground, call, save/load.

## Phases 5-13: companion, expanded world, dungeons, NPC schedules, village rebuilding, crafting/hunting/fishing/cooking, world events, treasure/bounty/achievements, relationships/world memory
As in your table. **Phase 6 (expanded world) is the largest technical risk** because it needs chunk streaming, LOD and a memory budget that the project does not have today; it should begin with a small second area (forest or river valley) to prove streaming before anything larger.

## Phases 14-16: Acts 3, 4, 5 and endings
Story is fully planned first (see `STORY_EXPANSION_PLAN.md`) and approved before any content is written.

## Phases 17-18: polish and Android optimisation
Cinematic and UI polish, audio pass, then profiling. Device measurement requires you to run an in-game FPS overlay (already present) and report numbers, or to provide a performance log from the phone.

## Suggested size
This is a multi-month, studio-scale plan. Realistically I can complete one sub-phase per working session. Phases 0.5 to 4 are achievable and valuable; Phases 5-16 are achievable in sequence but only if each is kept small and approved.
