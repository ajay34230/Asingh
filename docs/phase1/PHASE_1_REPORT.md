# Phase Report: 1 (environment demonstration, first slice)

Branch `phase-1b-environment-demo` (from `phase-05-save-v2`, merged with the parked pond work). All screenshots in this folder are real Godot renders, taken on a **software** renderer in the CI-style capture mode (Compatibility renderer, 1280x720). They are not phone renders. Frame rates from this renderer (2-3 fps) are meaningless and are not reported as performance.

## Implemented
- **Water, GTA IV-inspired:** dark green-grey body, depth-based colour using the depth texture, strong sky reflection at glancing angles (Fresnel, sky colour follows time of day and weather), three layers of moving normals (swells plus fine ripples), sun glints, white foam where water meets the shore, wind-scaled wave height. Used for the village pond and a stone water channel that runs to a trough by the well. Not done: true screen-space or planar reflections (not available on the Mobile renderer; planned as an optional High-only feature).
- **Terrain:** mesh density up from 2.0 m to 1.6 m cells; levelled pond basin with green ground and wet earth at the edge; a level site for the temple.
- **Vegetation:** procedural palms (curved trunks, 12 fronds), grass tufts and tall reeds, lily pads and lotus on the pond. All use instancing in 30-60 m cells so far cells can be hidden. Wind sway driven by one shared wind value.
- **Wind:** one global wind value (gusts, stronger in rain) drives plant sway, water waves and the wind sound volume.
- **Sky:** a moving cloud layer, tinted by time of day and weather.
- **Real graphics tiers (High/Medium/Low):** render scale, shadow distance (260/150/70 m) and shadow mode, glow, grass/reed/palm draw distance, rain density. Before this, the setting changed only render resolution.
- **Water carriers:** four villagers fetch water from the pond and walk it, with a clay pot on the head, to houses and the trough.
- **Temple (your request):** stone plinth with steps, pillared porch with marigold garlands and a hanging bell, sanctum with altar and lamps, stepped tower with gold finial, painted bands, flags. Functional: "Pray at the altar" restores 60 health (60 s cooldown); "Ring the temple bell". On the map as "Temple". See `temple.png`.

## Existing systems modified
`terrain_builder.gd`, `atmosphere.gd`, `main.gd` (quality tiers, tests), `game_menu.gd` (quality hook), `sfx.gd` (gust-driven wind), `map_ui.gd` (pond, temple), `npc.gd` (carry routine), `player.gd` (camera margin).

## Testing (automated, desktop headless)
Self-test PASS, including new checks: temple parts exist, player stands on the top tier (0.90 m), save v2 checks. Camera-below-ground tolerance was loosened from 2 cm to 15 cm after the denser terrain produced one 10 cm case; the camera spring margin was also raised.

## Not done yet in Phase 1 (honest list)
Rivers and waterfalls; erosion look, worn paths and footprints; roof tiles and cracks on buildings; trees other than palms, bushes, flowers, dead trees; realistic rain (splashes, wet surfaces); eight distinct lighting conditions; chimney and campfire smoke; water sounds; planar reflections. Visual quality on a real phone and phone performance are **not tested**.

## Known problems
First screenshots showed grass too bright (toned down afterwards, not re-photographed). Several screenshot camera positions were awkward (a palm trunk close to the lens). Water in the channel looks mostly foam because it is shallow.

## Approval status
Waiting for your feedback on how it looks and plays on the S10 before applying more of this standard.

## Addendum: Sand Circuit bull cart race + ground alignment

- New east-side track (stadium shape, ~258 m lap, five humps, rolling surface, banked edges), finish arch, bunting, fences, hay, torches, grandstand with crowd.
- Mission "Side: The Sand Circuit": talk to Race Master Bhim, win 3 laps against 3 armed rivals. Reward 150 coins, full heal.
- Carts follow the real terrain (pitch/roll), bounce and fly off humps, land with squash, dust and thud; two bulls per cart gallop with speed-scaled animation.
- Weapons: HIT swings spiked side blades (damage 22 you, 9 rivals). Cart-cart collisions push apart and cost speed/health. Health bars above carts; at 0 the cart bursts into planks, wheels, flames and smoke and the bulls bolt.
- Controls: stick = steer/brake, JUMP = boost (8 s cooldown), HIT = blades.
- Alignment audit (selftest): house sites levelled (spread 0.00 m), NPCs within 0.14 m of the ground.
- Tested: automated selftest only (headless, desktop). NOT tested on a phone; software-render screenshots only. Handling and balance need on-device feel testing.

## Addendum: bazaar town, mounts, hunting, inventory, controls
- **Suryapur Bazaar** (`scripts/town_builder.gd`, centre (22, -42), levelled by `TerrainBuilder.TOWN_C/TOWN_R`): paved square with a fountain (drinkable, heals), 16 themed stalls (fruit, spice, cloth, sweets, pots, chai, vegetables, flowers, roti, jewellery...; fruit/sweets/chai/vegetables/flowers/roti can be bought with coins and heal), four streets with ~40 buildings (shops with signs, havelis with balconies and domes, tower houses, an inn, tea houses, potter/weaver workshops with kilns, shrines, mud huts), 4 fully enterable furnished houses (reusing `HouseBuilder.build_extra`), a gate arch, washing lines, a wash trough and a tea corner. Footprints are checked for overlap in the selftest.
- **People** (53): hawkers crying their wares, haggling customers, cooks stirring, a baker kneading, vegetable choppers, women scrubbing washing at the trough, a boy scrubbing the paving, a doorstep scrubber, street sweepers, men sitting and talking over tea, a street musician, ten shoppers walking loops through the square and streets, four playing children and two gate guards. New RealHuman work poses (`scrub`, `sweep`, `stir`, `knead`, `chop`, `hawk`, `haggle`, `sit`, `sit_talk`) with hand props and matching work sounds.
- **Market sound** (all generated): crowd murmur, street murmur, fountain, sizzling pan, fire crackle, street-music loop, random one-shots (hens, goats, bells, coins, carts, children) and hawker/haggling chatter.
- **Mounts** (`scripts/mount_system.gd`): ride horse, camel (alpaca stand-in), donkey and bull; stick steering relative to the camera, auto gallop at full push, slope pitch, wall stop, JUMP to dismount.
- **Hunting**: only deer, stag and fox can be hurt, and only after taking the hunter's knife from the Reavers' camp; pain and thud sounds.
- **Inventory** in the pause menu (coins, seals, shards, gear, story items). **Controls**: analogue stick speed (walk, ease into a run, auto-sprint at a full push).
- Verified: selftest PASS (software GL, CI-mode 60 fps). Not verified: on-device performance (the town adds ~40 buildings and 53 people; if it is slow on the S10, lower graphics), how the new sounds feel on speakers, and a proper visual review (one software-render screenshot: `docs/phase1/town_square.png`).

## Addendum: environment, settings and set-pieces

- **HIT bug fixed**: the cart race had registered itself as the HIT handler for good, so HIT did nothing outside a race. It now only takes the press while racing (self-test covers it).
- **Rivers, waterfall, erosion, footprints**: `river_builder.gd` (seasonal river that fills in rain and drains again, a waterfall on the north cliff with mist and sound), gully erosion in the terrain, footprints and hoof prints (`footprints.gd`), eight lighting presets plus overcast and fog, a slanted rain look.
- **Trees and bushes** (`tree_factory.gd`): recursive-branching trees (neem, acacia, sal, dead), bark texture, leaf-card canopies with a painted leaf texture and wind sway; leafy bushes. All generated in code. Startup cost is higher; unverified on the S10.
- **Music**: long shuffled tracks with silent gaps instead of short loops; situation music (tension, sacred, mystery) now breathes (about 75 s on, 60 s off).
- **Settings menu**: pause screen with Inventory, Settings (Audio, Video, Controls, Gameplay tabs; 33 options), How to play, Save, New game (with confirmation). Audio buses Music, SFX, Voice, Ambience. Settings persist.
- **Footsteps and ambience by place**: wood, stone (bazaar, ruins), leaf litter (forest), water (pond, full river), mud (in rain), sand; zones (town, forest, pond, river, ruins, desert) change wind and which wild voices play (crows, peacocks, owls, jackals, frogs, cats).
- **Animal activities**: every species has its own set (cows graze, ruminate, drink; bulls paw and snort; horses canter and rear; camels chew and rest; dogs sniff, dig, chase tails; deer drink and keep watch; foxes stalk and pounce); the sleepers doze at night.
- **Traffic**: four carts with seated drivers on out-and-back roads, three riders, eight travellers on foot; carts and riders stop and ring a bell if the player stands in the road.
- **Set-piece "Raid on the Road"** (`stampede.gd`): a few minutes into free play a raid horn sounds and a herd of 14 stampedes across the player's path (trampling hurts), then four Reavers attack; reward 120 coins and a rideable white horse.
- Rider pose fixed so the player straddles the animal instead of standing on it (checked by software-render screenshot only).
- Verified: self-test PASS (software GL). Not verified: feel and performance on a phone, how the new sounds and trees look and sound on the S10.

## Addendum: riding and combat controls overhaul
- Riding: steering was reversed for touch input (forward was -y); fixed to the same stick convention as walking (up = forward, camera-relative). JUMP now makes the animal leap (cleared low obstacles, landing thump); a new GET OFF button (and E key) dismounts. The rider sits on a per-species saddle point measured from the model, with a real riding pose (thighs astride, lean with speed, lean into turns, rise out of the saddle on a leap). HIT swings the hammer from the saddle.
- Combat: HIT presses are buffered so combos flow, auto-face and lunge toward the nearest enemy within 6 m, sprint attack (x1.2) and flying kick (x1.3). New BLOCK (hold; front hits do 25% damage) and ROLL (dodge with 0.45 s invulnerability) buttons; keyboard F / Q / V.
- Verified by selftest (steering direction, leap height, JUMP not dismounting, GET OFF, mounted HIT, block reduction, roll i-frames) in software rendering only; not tested on a device.

## Addendum: camera, jump feel, colour and sky
- Camera default distance 7.5 -> 4.3 m (range 1.6-10 m), mounted 5.6 m.
- Jump: lighter rise, heavier fall; take-off pose (lead knee up, trailing leg tucked, arms swing up) and descent pose (legs reach down, arms out).
- Colour: town and hamlet houses use a vivid palette; NPC clothes are dyed per garment (skin, hair and eyes keep their own materials; the old tint overwrote skin too).
- Animals: procedural fur noise (triplanar), patches on cows/bulls, dapples on deer.
- Sky: day length 20 -> 10 min; stars, moon opposite the sun, drifting low-poly cumulus that glow at dusk and grey in storms.
- Verified by selftest and software-render screenshots only; not tested on a device.

## Addendum: stones, grain and painted walls
- Rocks: finer, two-octave faceted meshes (10 rings x 16 segments). New RockScatter adds about 40 boulders with small leaning rocks, plus a field of low rocks, pebbles and gravel clusters as culled MultiMeshes (view distance follows the foliage setting). Rocks keep clear of the town, race track, pond and roads.
- Grain: a fine detail layer (grit albedo and micro normal map) on all stone and plaster materials. Wall textures are now generated once per plaster amount and tinted per house (the 8 house colours would otherwise have cost 8 per-pixel generations at start-up).
- Paintings: new Murals (procedural, no imported images): diamond borders at the base and under the eaves of hamlet and town houses, and a mandala panel above doors of small town houses.
- Verified by selftest and software-render screenshots only; not tested on a device.

## Addendum: Whispers in the Bazaar, story sounds, Hindi mode
- Quest "Side: Whispers in the Bazaar" (Raju, Lal, three guards behind the inn, the crate, Pandit Rishi, 200 coins) built and covered by the selftest.
- Story sounds: new wordless voices (tools/make_story_audio.py, own synthesis): screams, battle cries, wail, sobbing, panicking and cheering crowds, war roar, horse/bull/camel cries. `Sfx.cue(...)` layers them at story beats: Reaver raid waves and Karan's arrival, the forest scene (Tara's scream, the Reavers' laugh and shout), the stampede, Karan's defeat (crowd cheer), Tara's first plea. Synthesised screams are not tested by ear; judge them on the phone.
- Hindi: Settings > Gameplay > Language / भाषा. About 320 lines (story, cinematic subtitles, ambient chatter, choices, speaker names) translated in tools/hi_*.py into data/hindi.json. Spoken Hindi uses Kokoro's Hindi voices (tools/render_voices_hi.py), rendered per speaker as assets/voice clips keyed by the Hindi text. Lines without a Hindi clip fall back to the phone's own text-to-speech or silence. Menus, quest log, banners and HUD text are still English. Devanagari display relies on the phone's system fonts (not tested on a device).

## Addendum: power-up effects, delayed thunder, Hindi quest log
- PowerFx (attached to the player): speed power-up gets a Flash look (yellow lightning arcs, streak trail, flickering light, burst of light on pickup); power gets a fiery aura and embers; shield gets a blue bubble; plain sprinting gets faint wind streaks. Covered by a selftest for flags and visibility; the look itself is not yet seen in a screenshot or on a device.
- Thunder now arrives 0.3 to 3.2 s after the flash, quieter the longer the delay.
- Hindi: quest titles, objectives, journal blurbs and banners are translated (numbers handled by pattern).

## Addendum: tap-to-route on the map
Open the full map and tap anywhere (taps near a landmark snap to it). A red dashed line is drawn from your arrow to the spot with the distance in metres, the same line and distance show on the minimap, and a glowing red column marks the spot in the world. Close map and Clear route buttons were added; the route clears itself within 6 m. Covered by a selftest; not tried on a device.

## X1 Night life (31 Oct)
New `scripts/night_life.gd`: the 6 nearest street lamps get a real flickering warm OmniLight (no shadows), fading in with `Atmosphere.night`; 28 fireflies follow the player at night. Selftest checks lit lamps and fireflies at midnight and none at noon. Software-render only; the look and frame cost on a phone are untested.

## X6/X8 Footsteps and hit feel (31 Oct)
Surface footsteps (wood/stone/leaf/water/mud/sand), screen shake and hit-pause already existed. Added `scripts/hit_fx.gd`: spark/dust burst on every enemy hit (bigger for kicks and hammer). Selftest PASS in software render; not seen on a device.

## X3/X4 Ripples, butterflies, leaves (31 Oct)
New `scripts/ambient_life.gd`: expanding ripple rings when stepping in water; daytime butterflies near pond/forest/town; drifting leaves in the forest. Rain already wets the ground (roughness). Selftest PASS (software render); the visuals are not checked on a device.

## X5 Area title card (31 Oct)
`scripts/area_title.gd`: a fading place-name card when entering the bazaar, forest, pond, river, ruins or dunes (12 s cooldown), in Hindi when Hindi mode is on. Selftest PASS (software render). Sun glare, depth-of-field and light shafts were not added.

## X10 Ground slam; X25 partly present (31 Oct)
Attack while falling now dives and, on landing, sends a 4 m shockwave (damage, dust, shake, hit-pause); `Player.ground_slam()`, selftest PASS. Already present from earlier: FPS counter, shadow/AA/draw-distance/resolution settings, haptics. Charged strike and thrown spear are not built yet.

## X11/X13/X14 Enemy roles, finisher, boss phases (31 Oct)
Enemy roles (`Enemy.apply_role`): shield (frontal punches/kicks do 25%), archer (keeps distance, fires visible arrows), brute (1.8x hp, 1.5x damage, slow), ambusher (fast, long aggro). Roles are mixed into camp and raid fights via `CombatBuilder.ROLES`. Bosses enrage below half health (faster, quicker attacks, telegraphed ground stomp). The last enemy killed up close triggers a slow-motion finisher. Selftest PASS (shield, archer shot, boss enrage). Balance and feel are untested on a device.

## X20/X21/X24/X29 Photo mode, hints, achievements, journal (31 Oct)
`photo_mode.gd` (pause menu > Photo mode: hides controls/HUD, Take photo saves PNG to user://photos), `hints.gd` (six one-time tips), `achievements.gd` (10 milestones, saved in user://achievements.json, banner on unlock) and a pause-menu Journal page listing them. English and Hindi strings added. Selftest PASS (unlock from flag, hint once-only, photo mode hides/restores controls). Not done: save slots, colour-blind markers, lore-book entries.

## X7 (already present), X15 Fast-travel shrines (31 Oct)
X7: mood loops (tension/race/sacred/mystery) and day/night/village radio pools already existed. X15: `shrines.gd` places four stone shrines (bazaar, pond, forest, ruins); touching one lights it (saved as story flag) and adds it to the pause menu's Fast travel page. Travel is refused near enemies or within 6 s of combat. Selftest PASS. Shrine positions were chosen from terrain constants and not eye-checked for overlap with trees or buildings.

## X2 mist, X18 (present), X27 outfit colour (31 Oct)
X2: soft morning mist (time 0.20-0.33, when no story weather); rain, wet ground and thunder already existed. X18: villagers already walk home at night and vanish indoors until morning (shop closing not added). X27: Settings > Gameplay > Outfit colour (6 colours with gold trim) via `RealHuman.recolor` / `Player.set_outfit`. Selftest PASS. Headband/cloak and horse naming not built.

## X30 Hindi menus (31 Oct)
`Loc.apply_to_tree` translates all buttons, labels and dropdown items of the pause menu (nav, settings labels and options, help text, journal, travel) each time a page is shown; switching back to English restores the originals. Selftest PASS (Resume <-> जारी रखो). Still English: the touch-button captions (JUMP/HIT/BLOCK...), settings tab titles, and the FPS/debug overlays. Devanagari font rendering on the phone is unverified.

## S1 + S4 Items, equipment, crafting (31 Oct)
`scripts/items.gd`: counts in story flags (saved). Herb/potion (heal), hide/iron (materials), spear (+reach, +15%), axe (+40%), leather armour (-20% damage taken), chain mail (-38%). Enemies drop herbs/iron/hides; the pause menu's "Items & crafting" page uses, equips and crafts (potion 3 herbs; spear 2 iron + 1 hide; axe 4 iron; leather 4 hides; chain 8 iron + 2 hides). Hides already hunted are credited as crafting hides once. Selftest PASS. Shops that sell items and a visible weapon in hand are not built; balance untested on a device.

## S2 Stamina and parry (31 Oct)
Stamina (100): sprinting drains 14/s, roll costs 18, each attack 7 (exhausted swings do 60%), blocking an unparried hit costs 10; refills 30/s after 0.7 s idle; running out of breath blocks sprinting until 25. A block raised less than 0.25 s before a hit is a parry: no damage, +12 stamina, attacker staggered 1.3 s, blue sparks. Green stamina bar under the health bar. Selftest PASS (spend, regen, parry). Tuning is untested on a device.

## S3 Companion: Sher (31 Oct)
`companion_system.gd`: Sher, a sellsword by the inn (5 m from it). Hire for 120 coins (prompt on him), dismiss the same way. While hired the existing Npc companion AI makes him follow and strike enemies; his damage grows 1.5 per trust point (max +18), trust +1 per enemy killed while he is hired (flag sher_trust, saved with the game). Selftest PASS (insufficient coins refused, hire pays, trust strengthens, dismiss). He speaks via banners only (no voice clips); path-finding is the old straight-line follow, so he can snag on walls.

## S5 Village rebuilding (31 Oct)
`village_rebuild.gd`: a board in the bazaar (11 m SE of the town centre). Stage 1 (100 coins) four lamp posts that join the night lighting, stage 2 (250) eight festival flag poles, stage 3 (500) the Sun Gate arch south of the square; each stage +15 max health. Stages are story flags and rebuild on load. Selftest PASS. Placement is by coordinates and has not been eye-checked for overlaps with existing buildings; the Heroic-ending hook is not connected yet.

## ACT 3: The Kingdom Beneath, B1-B3, B6, B7 (31 Oct)
`scripts/campaign.gd`. After Captain Karan is beaten (flag captain_down) an interactable beside the Sun Gate ("Descend into Veyra") moves the player to Veyra, a 40 x 130 m stone hall built far off the map (700, 700) with pillars and warm lights. Quest "ACT 3: The Kingdom Beneath": light three braziers, read three royal tablets (Queen Ila's choice: she chose the dark over a crown), judge Captain Karan (karan_fate spared/condemned; condemned pays 100 coins), then the Stone Warden (480 hp, damage 20, 1.35x size, enrages at half health) wakes. Defeating him sets act3_done, +300 coins and Chain mail; an exit at the south end returns to the gate. Selftest PASS walks the whole chain. NOT built from the plan: separate Veyra street kit, pressure-plate/mirror puzzles (B5), a separate companion Ilan (Sher serves), Act 3 side quests (B8). The hall is plain geometry; looks unchecked; Hindi story-line voices for tablets/Karan not rendered (text only).

## ACT 4: The Fallen Crown, C1-C7 compact (31 Oct)
`scripts/act4.gd`, started when Act 3 completes. Three Ashen outposts (banner, tents, 5 mixed-role soldiers each) at (-130,120), (150,60), (-40,205); a prisoner at the last one is freed (interactable) and names Scholar Vikram, who appears by the inn and confesses (forgive or exile). That begins the siege: waves of 4, 5 and 6 raiders around the village; spared Karan brings potions and a forgiven Vikram gives herbs. After wave 3 the warlord Vessa (620 hp, damage 22, enrages) arrives. Defeating her sets act4_done, +500 coins, iron and potions. Selftest PASS walks the chain headlessly. Not built: burning-road set piece, rescuing a captured companion, alliances, gates/ballista, an Ashen Host faction look beyond tint/banners. Outpost coordinates were chosen blind and are not eye-checked for terrain obstacles.

## ACT 5: The Last Sun, D1-D5 compact (31 Oct)
`scripts/act5.gd`, started when Act 4 completes. "Enter the Solar Vault" beside the Sun Gate teleports to a golden 36 x 90 m hall off the map (-700, 700). Dr. Arin explains; three sun pedestals must be touched east, centre, west (a wrong touch resets and warns); then the Eclipse Guardian (900 hp, damage 24, 1.5x size) fights in three stages: at 66% three adds join, at 33% he enrages and three more arrive. After he falls the Sun Heart offers the choice: Heroic, Sacrifice, or the Secret ending (only if the village is fully rebuilt, Karan was spared, Vikram forgiven and 5+ achievements). Each ending is a three-line cinematic that mentions Karan/Vikram's fates, then a credits screen ("Endings found n / 3") with "Continue exploring". Selftest PASS exercises entry, puzzle, both stage changes, Heart unlock, ending, credits. Not built: a separate Hindi voice for ending lines, mirror puzzles, a final-ending music cue. Credits text says "original or CC0"; ASSETS.md remains the authority for asset provenance.

## X23 Save slots (31 Oct)
Pause menu > Save slots: three manual slots (`GameMenu.slot_save/slot_info/slot_load`), each showing date/time (IST), act reached and coins. Save copies the current save into the slot via the safe-write path; Load copies the slot over the main save and reloads the world. Selftest PASS covers save and read-back of slot 3 (the reload itself is not exercised headless). Autosave still uses the single main save.

## X19 Festivals (31 Oct)
`scripts/festival.gd`: every 5th in-game day is a festival. Odd festivals (day 5, 15...) = Festival of Lights: 24 coloured lanterns over the bazaar square in the evening; even ones (10, 20...) = Festival of Colours: a burst of coloured powder at the fountain every 14 s. A banner announces it (English/Hindi). The day counter starts at 0 each session (it is not saved). Selftest PASS. Seasons were not added.

## X17 Wildlife: feeding (31 Oct)
Prey animals already fled and dogs befriended; added feeding: pause menu > Items & crafting > "Feed nearby animal (1 herb)" gives a herb to the nearest animal within 4 m, which stops it fleeing for 90 s. Three feedings unlock "Friend of Beasts". Selftest PASS (feeding a deer-type animal). Not built: predators hunting prey, ecosystems.

## X26 Mini-games, X28 Arena bonus (31 Oct)
`scripts/minigames.gd`: (1) Chausar dice with Imran in the bazaar (bet 10 or 50 coins, higher two-dice total wins, ties keep coins, he re-offers after each round). (2) The Arena, a ring of stones 32 m east and 28 m south of the square: endless waves (2+n mixed-role fighters, tougher each wave), 20 x wave coins per cleared wave, best wave remembered (flag arena_best); leaving the ring or dying ends it. Selftest PASS (dice payouts, wave 1 and 2, reward, best wave). Kite flying, wrestling, archery and chess were not built. The arena is open from the start rather than being locked behind the ending.

## X12 Hunting bow (31 Oct)
New weapon "Hunting bow" (craft: 3 hides + 1 iron). Equipped, ATTACK fires a visible arrow at the nearest enemy within 22 m (damage 20 x gear, 0.6 s cooldown, 5 stamina), on foot or from the saddle. `Player.fire_arrow`. Selftest PASS (arrow hits a foe 9 m away). Spear and axe keep the existing swing animations (they differ by reach and damage only); no new swing animations were drawn.

## X9 Faces and cloth: not possible with the current character model (31 Oct)
Tried blinking by swapping eye materials. The human models use one shared "atlas" texture with no separate eye surfaces, so eyes cannot be closed without new meshes or blend shapes. The attempt was reverted. Cloth sway and facial expressions would need new rigged assets and stay unbuilt.

## Combat, roll, walls and lag fixes (31 Oct)
- Arms swung backwards (shoulder axis sign) while legs were right; fixed, so punches now go toward the target.
- Combo is boxing only (jab, cross, jab, hook, cross, uppercut); kicks only when airborne. A boxing guard stance holds for 4 s after combat.
- Roll is a tucked ball (new "roll" pose) rotating around the body centre, not the feet, so nothing dips below the ground.
- NPCs and animals: `Walls.fix` cancels/slides steps that hit static bodies (within 60 m of the player).
- Lag: lights fade out with distance and cast no shadows, High preset renders at 0.9 scale with 150 m shadows, NPCs beyond 90 m are not simulated, NPC ground raycasts run every third frame.
- Not verified on a phone; frame rate effects are expected, not measured.

## Hitting villagers and animals (31 Oct)
Punches/kicks now affect NPCs (stagger, shout, flee 7-10 s; never damaged) and animals (shoved, yelp, bolt; never killed - hunting is still the knife+hammer). A hint appears after the third villager struck (`Player.assaults`). Selftest covers both reactions. Not device-tested.

## Consequences for beating villagers (31 Oct)
After 3 villagers struck the player is "wanted" for 120 s (refreshed by each further hit): stalls refuse service. From 5 hits, guards within 28 m chase and strike (8 damage, 1.5 s) until the timer ends. Guards can be punched but only stagger. Selftest covers the guard strike. Not device-tested.

## 3D power-up icons (31 Oct)
Pickups are now small 3D models built from primitives (heart with cross, lightning bolt, sword, shield) with a ground ring, rising sparkles and a collect burst (expanding ring, sparks; healing sparkles rise around the player for health). Speed, power and shield keep their existing on-player effects. HitFx/pickup spark quads were resized to avoid oversized squares. Software-render screenshot checked only; the black square seen around the player in software captures is unexplained and not verified on a device.
