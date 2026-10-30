# Phase Zero Report

Date: 30 Oct 2026. Branch: `phase-2-player-controller`. Released commit audited: `6e830b4`. Self-test on that commit: **PASS** (headless, desktop; not an Android test). No gameplay files were changed in Phase 0.

1. **Is the complete vision technically possible in Godot 4.4.1?** Mostly yes, but not at "ultra-realistic" fidelity and not all at once. Gameplay systems (inventory, combat, mounts, companions, dungeons, crafting, saves) are all possible. Photo-realism is not: the Mobile renderer has no SDFGI, SSR or volumetric fog, and the project uses procedural low-poly assets. Realistic here means "stylised-realistic with good lighting".
2. **What integrates into the current architecture?** Dialogue, quests, combat, NPC routines, companions, weather, map and audio all extend cleanly. Dialogue already supports shop costs and item grants.
3. **What needs refactoring first?** (a) The save system (not versioned, not atomic, no backup, saves only flags and position). (b) World state (a flat string dictionary). (c) Content is hard-coded in scripts; items, quests and shops need data files. (d) `main.gd` is a god object.
4. **Biggest Android performance risks?** About 2,700 mesh nodes with little instancing, always-resident world, no LOD/visibility ranges, foliage, water reflections, rain particles, and shadows. The "quality" setting only changes render resolution. **No frame rate has ever been measured on a phone.**
5. **Can the realism be reached?** Partly. A clearly better look (water, sky, vegetation, weather, lighting, paths) is achievable. Cinematic AAA realism is not on a Galaxy S10 with free assets. GTA IV-style water is achievable in look (reflection, glints, foam, depth colour) except true screen-space reflections.
6. **Assets and tools needed?** Mostly code-generated. Would help: CC0 tree/rock/plant meshes, CC0 combat animation clips (sword, block, roll, death) for retargeting, sound effects (generated currently). All CC0 only, recorded in `ASSETS.md`.
7. **Develop first?** Save v2 + GameState (invisible but essential), then Phase 1 environment (water, sky, vegetation), then controls/locomotion, then inventory.
8. **Postpone?** Expanded streaming world, underground city, Acts 4-5, village rebuilding, relationships. They depend on everything before.
9. **Realistic scope?** Phases 0.5-4 (foundation, environment demo, controls, inventory, combat, mounts) are realistic and valuable. The whole 18-phase plan is a very large, long-running effort; it is feasible only as small, approved steps.
10. **Major uncertainties?** Real-device FPS and thermals; first-load time with procedural textures; whether the bone-driven rig can look good for combat without animation clips; phone text-to-speech quality; the unexercised release signing path.

## Feasibility by feature
- **Fully feasible:** save v2, world-state memory, relationships, footsteps, wind, cinematics/skip, controls (BGMI-style layout), audio expansion.
- **Feasible with modifications:** terrain/vegetation/water/lighting/weather realism, architecture detail, inventory/equipment, advanced combat, companions, dungeons, NPC schedules, village rebuilding, crafting/cooking/fishing, events, treasure/bounties/achievements, photo mode (gallery save needs care), mounts (horse/camel/donkey via one generic system), Acts 3-5.
- **High risk:** expanded open world with streaming (biggest), foliage density on low-end phones, real-time reflections.
- **Not recommended as specified:** true ultra-realism comparable to PC/console games; global illumination (SDFGI) on the Mobile renderer; a fully populated 10-region world before the first new area proves streaming.

## What I did with your mid-turn messages
- **"Water like GTA 4"**: written into Phase 1a as the target look; the earlier pond work is parked on `wip/pond-sky-flora`.
- **BGMI-style controls, realistic jump/walk/run, ride camel/donkey, footsteps, wind, rain**: added as matrix rows L, C2, S, W, R and to the roadmap as Phase 1.5 (controls) and Phase 4 (generic mounts). Not implemented yet, per "stop after Phase Zero".

## Approval needed
Reply "approved" to begin **Phase 0.5 (save v2 + GameState)** then **Phase 1 (environment demo)**, or tell me to reorder (for example, controls first).
