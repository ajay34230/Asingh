# The Lost Kingdom: full build plan (small phases)

Rules for every phase (unchanged): CC0 or self-made assets only (log in ASSETS.md); debug APK only; no secrets/keystores in git; reuse existing systems; preserve Acts 1-2; every new feature must be wired into play ("use everything you add"); each phase ends with selftest PASS (software GL, 60 fps fixed), CI build, short report. Anything about phone feel or FPS is "not tested on a device" until the player reports it.

Size key: S = one session part, M = one session, L = several. Order is the build order.

## DONE (Phases 0 to 1.9)
Save v2 and GameState; desert, village, town bazaar, forest, pond, river and waterfall; day/night, 8 lighting presets, weather, stars, moon, clouds; water; trees, bushes, rocks, grain, painted walls; BGMI-style touch controls and settings menu; resume/restart mission/new game; mounts with jump and Get Off; combat (combos, lunge, block, roll, throw); stampede event; traffic and NPC routines; place-dependent sound and long music; Acts 1-2 (11 quests).

## ACT 2.5: finish what is half-built
- **A1 (S) Whispers in the Bazaar.** Quest after the ledger: talk to Raju (chai) and Lal (spices), search the crate behind the Musafir Inn guarded by Reaver thugs, return the receipt to Pandit Rishi. ~200 coins. Uses bazaar NPCs, combat, journal.
- **A2 (S) Weather and night polish.** Thunder delay after flash, wet-ground splashes, night lamps and windows lit, fireflies, stars check.
- **A3 (S) Controls and combat feel pass.** Device feedback fixes; on-screen layout presets; aim-assist tuning; damage numbers.
- **A4 (S) Audit pass.** Whole-code bug sweep, perf (draw calls, texture memory), selftest additions.

## ACT 3: The Kingdom Beneath (underground)
- **B1 (M) Hidden stair and descent.** Gate opens after the Sun Gate quest; loading-free cave transition; underground lighting kit (lamps, god-rays, dust).
- **B2 (M) City of Veyra, streets.** Modular stone street/house kit, restore-the-lights puzzle (3 braziers), ambient audio.
- **B3 (M) Archive Hall.** Three royal tablets (readable UI), reveal Queen Ila's choice; journal entries.
- **B4 (S) Companion Ilan.** Follows, fights, comments; trust tracker.
- **B5 (M) Guardian trials.** Pressure plates, mirror/light-beam puzzle, moving blocks.
- **B6 (S) Karan's Oath.** Dialogue scene; choice karan_fate (spare or condemn).
- **B7 (M) Boss: Stone Warden.** Multi-phase with puzzle assist; reward.
- **B8 (S) Side quests.** Lamp-Lighter's Debt, Lost Choir, Cistern Fish.

## ACT 4: The Fallen Crown
- **C1 (S) The Burning Road.** Travel set-piece with raiders and the stampede system.
- **C2 (M) Ashen Host faction.** Enemy archetypes (archer, shield, brute), outposts, banners.
- **C3 (S) Betrayal scene.** Ally hands over the seals (depends on trust flags).
- **C4 (M) Rescue missions.** Outpost and fortress; companions captured and freed.
- **C5 (S) Alliances.** Village, caravan guild, Karan's men.
- **C6 (L) Siege of the village.** Wave defence, gates, ballista, NPC defenders.
- **C7 (M) Boss: Vessa.**

## ACT 5: The Last Sun
- **D1 (S) The Final Road** and **D2 (S) Revelations**.
- **D3 (M) Solar Vault dungeon.**
- **D4 (L) Boss: Eclipse Guardian** (multi-stage).
- **D5 (S) The final choice** and three endings (Heroic, Sacrifice, Secret) with cinematics and credits.

## SYSTEMS (built alongside, in this order, each before the act that needs it)
- **S1 (M) Inventory and equipment** (needed by B/C): JSON items, grid UI, slots, weapon in hand, armour, shops, save.
- **S2 (M) Stamina, parry, enemy telegraphs** (needed by B7/C7).
- **S3 (M) Companion AI** (needed by B4).
- **S4 (M) Crafting, hunting, fishing, cooking** (hunting and knife already exist).
- **S5 (M) Village rebuilding** (needed by C6 and the Heroic ending).
- **S6 (S) Bounties, treasure maps, achievements.**
- **S7 (S) Relationship and world-memory tracking** (the choices list in STORY_EXPANSION_PLAN).
- **S8 (L) Second area / streaming** only if memory allows; otherwise keep areas as separate scenes.

## FINAL
- **F1 (M)** Cinematic and UI polish, audio mix, localisation hooks (Hindi/English).
- **F2 (M)** Android optimisation (profile on device with player-supplied FPS), texture/mesh budgets, Low/Med/High tiers.
- **F3 (S)** Full playthrough test script (selftest of every quest flag chain) and final bug sweep; release notes.

## Execution order
A1, S1, A2, B1-B3, S3, B4-B8, S2, C1-C7, S5, S4, D1-D5, S6, S7, A3, A4, F1-F3.
Each step is committed and pushed on its own so a build is always available.
