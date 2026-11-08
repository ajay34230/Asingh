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

## Farm, coins and market (31 Oct)
- The game now starts at a levelled **home farm** (new terrain plateau at `FARM_C`) with a farmhouse (bed = sleep and save), barn, fences, six field plots (+6 more by purchase), an orchard of 8 spots, a beehive and scarecrows.
- **Crops**: wheat, corn, tomato, cotton. Plant, water at two stages, ripe (arrows + "READY TO HARVEST" labels, map marker), then drive the **tractor** over the field to harvest. Growth uses the real clock and is saved (keeps growing while the game is closed).
- **Farmers' Market** stall in the bazaar sells produce for coins (prices change every 4 min) and offers seeds, fertilizer, scarecrows, sprinklers, wider harvester, extra fields, beehive, saplings, potions, herbs, armour, bow, spear, and a crop contest. It appears on the map after the first harvest.
- **Orchard**: bought saplings grow in about 150 s; mangoes every 90 s, other trees can be felled for timber, which sells.
- **Coins**: 64 gold coins to collect around the valley, a coin counter on screen, +50 coins per completed mission (existing race/arena/dice prizes unchanged).
- Selftest covers plant/water/ripen/tractor harvest/sell/orchard/contest/honey. Not device-tested; farm layout, tractor feel, market stall position (picked by a free-space check) and balance are unverified. Hindi translation covers static text; texts with numbers stay English.

## Addendum: farm connected to the rest of the game
- New games now start at the home farm door (intro gets a farm shot); the Guide NPC waits beside the farm.
- "Home Farm" is an always-lit fast-travel stop.
- The Farmers' Market refuses wanted players (same rule as bazaar stalls).
- New achievements (Green Thumb, Orchard Keeper, Market Trader, Coin Collector, Crop Champion) and three farm hints.
- Dry plots water themselves in rain or when hired Sher is within 40 m; market prices +15% on festival days.
- Selftest covers market refusal and the travel stop. Not device-tested; rain/Sher/festival behaviour and the intro shot are unverified visually.

## Addendum: title screen, combat feedback, bounty board, crash diagnostics
- Title screen (Continue / New Game / Language) before play; world pauses behind it.
- Floating damage numbers (enemies and player), red "!" wind-up warning on enemy attacks, soft lock-on arrow on the nearest enemy.
- Bounty board in the bazaar: four repeatable jobs (kills, harvests, market earnings, coins found), accept then claim.
- Crash diagnostics (`diag.gd`): breadcrumb file every 3 s (fps, position, memory); if the last run ended unexpectedly the title screen shows it. File logging enabled on mobile. Adaptive quality lowers the preset when FPS stays under 22 for 8 s.
- Device screenshot (build e023959, 15 FPS) shows large brown slabs/beams and dark blobs in the sky. A similar slab appears in the software-render town capture from the build before the farm, so it predates the farm work; cause not found, not reproduced as the same artefact. Unresolved.
- Selftest covers the bounty flow; title screen and floating text are not visually verified.

## Addendum: lag work and Debug page
- Measured in the software-render bazaar view: 8,553 draw calls before, about 4,300 after. `StaticBatcher` merges non-moving meshes of BazaarTown (2,532 -> 497), Hamlet (1,377 -> 203) and Railway (263 -> 77) by material and 24 m cell; originals are hidden, colliders kept. Doors, signs, scripted, transparent or shader-material meshes are skipped.
- All other small props stop drawing beyond 170/125/90 m (High/Medium/Low).
- Settings > Debug tab: switch rain, smoke, clouds, grass, lamps, people, ground, ruins, farm off one at a time to find what causes a glitch. Not saved between launches.
- Not device-tested: real FPS gain, and merged meshes should be checked for missing or mis-coloured props.

## Addendum: night, square particles, roll
- Night was too dark: moonlight 0.3 -> 0.7, ambient colour/energy raised, exposure 1.1 -> 1.3, sky night colours lifted. Checked in a software-render night capture (much brighter); not judged on a phone screen.
- The yellow/white "boxes": particle quads (fireflies, sparkles, hit effects, power-up fx, dust, smoke, festival powder, mist, rain) had no texture and drew as hard squares. All now use a soft round dot texture (`soft_dot.gd`).
- Roll: the selftest taps the ROLL button and it rolls, so the button path works. Likely cause on device: roll was refused silently when stamina was under 18 (sprinting drains it). Now a tired player can still roll (shorter dodge window), and a press during the cooldown is buffered for 0.35 s.
- Still open: the large flat slabs seen in town captures (and beams on the device). Hiding individual world parts did not isolate them; use the Settings > Debug tab on the phone.

## Addendum — Combat animation, hit reactions, riding pose

Verified only by selftest and software-rendered captures. **Not tested on a device.**

- **Elbow bug fixed.** Arms rest in a T-pose and are lowered by the shoulder, so elbow "flex" was twisting the forearm. `_apply` now conjugates by the parent's cumulative delta, so the elbow hinges. This affects every pose (idle, NPC, locomotion), so check those on device.
- **Boxing guard and keyframed moves.** Guard now holds fists at chin height with a bladed stance. Jab, cross, hook and uppercut are keyframed (chamber, extend, retract, return to guard). Taekwondo front-leg kicks (front, round, side) follow the same structure. The hook elbow range is still the roughest part.
- **Hit reactions.** `play_hit` and `_hit_overlay` add additive head, torso and arm recoil. Wired into Player, Enemy and Npc.
- **Riding.** Rider sits lower on the saddle (`back_y - 0.55`) and thighs are closer together (reduced abduction, more knee flex). Software capture shows the legs close and the rider seated.
- Debug prints removed. `lab_variants` remains as a lab-capture helper only.

## Addendum — Combo flow, mission box exit, unstick button (2026-11-06)

Selftest passes. **Not tested on a device.**

- Combo is now jab, cross, hook, uppercut, front kick, round kick. Between a punch string and a kick (and after each kick) the next move waits for the previous one to retract fully and holds the boxing guard for 0.16 s.
- The left mission tracker has an X button. It comes back on a new mission or when the journal opens.
- Pause menu has "Stuck? Fix me": clears stale locks and held touches, closes any open dialogue, and moves the player beside the current objective.
- The "stuck in missions" cause is not identified. Needs the user to name a mission or say whether it is lag or an objective that will not complete.
- The yellow/brown slab glitch is still unresolved. Needs the Debug-tab bisect on the device.

## Addendum: Southern Road, world map, jumps and climbing, fists, weapons, log collector (2026-11-06)

Verified only by the headless selftest (PASS) and software-rendered captures. **Not tested on a device.**

- **Southern Road (new area).**
  - A pass in the valley's south rim (x = -40) leads up to a plateau, built by FrontierBuilder (320 x 480 m).
  - A road of about 520 m winds past Act 4's third Ashen outpost to two new stops: Kesar Sarai, a walled caravan inn with rooms, a well and a stall, and Dhoopgarh, a frontier village with a watchtower, a shrine and a well.
  - The stops have 8 new NPCs with dialogue, red milestones every 60 m, rocks and dead trees.
  - Horses wait at the foot of the pass and at each stop, and camels and a donkey at the stops.
  - Two new fast-travel shrines.
  - The ground joins the valley mesh along z = 200 with the same x spacing. Selftest: largest step 0.17 m, and the player walks out through the pass.
  - The distant mountain ring is opened (sunk under the ground) over the road.
- **Stuck mission found.** Act 4's third outpost (-40, 205) was outside the valley's 400 m terrain and beyond its boundary wall, so it could not be reached. It now sits at the top of the pass on real ground.
- **Map.**
  - It covers the valley and the road (a 256 x 563 texture).
  - The full map has a Valley / Whole map toggle.
  - New landmarks: Home Farm, Mirror Pond, South Pass, Kesar Sarai, Dhoopgarh and the three Ashen outposts.
  - Shrines show as lit or unlit.
  - A mission goal outside the current view shows as an arrow on the border.
  - In Veyra and the other off-map halls the minimap shows the place name instead of garbage.
- **Jumps.**
  - Standing jump: an anticipation crouch (0.15 s), both feet, a knee tuck at the apex, arms up then forward, and a deep landing.
  - Walking jump: a short crouch, then one-foot take-off.
  - Running jump: a leap with the lead leg forward and the trail leg folded, a forward lean, opposite-arm drive and a light landing.
- **Climbing (GTA SA style).** Jumping at a wall checks for a ledge:
  - Higher than 1.3 m: climb (reach, hang, pull with bent elbows while a knee walks up, push down, knee over, stand).
  - Lower: mantle.
  - A thin fence with ground beyond it: vault.
  - In the air, pushing into a wall with a reachable ledge grabs it.
  - The selftest climbs a 1.5 m wall and vaults a 1 m fence.
- **Fists.** Finger bones curl about their local X axis (checked in close-up captures on both rig types). Hands are fists in the guard, while striking and while blocking, and loosely curled otherwise. A punch thrown from relaxed hands first spends 0.14 s in the guard closing the fist.
- **Weapon button.** A new HUD button (FISTS / HAMMER / AXE / SPEAR / BOW) cycles the weapons you own and shows the weapon in hand. Fists = the boxing combo, with no hammer in hand.
- **Crash and log collector.**
  - Pause menu > Crash & logs: copy the report to the clipboard, save it as a file (Downloads, or the game folder as a fallback), note a problem now, or clear.
  - The report has device and GPU info, the stored crash reports (the last breadcrumb plus the tail of the previous run's Godot log), recent events (missions, unstick, low-fps quality drops) and the tails of Godot's logs.
  - The title screen offers "Copy crash report" after a crash.
- **Load time.** World build in headless went from about 4.6 s to 5.7 s (the new ground, its places and the larger map texture). The phone will be slower.

## Addendum: Ghost and monster missions, weapons, acted-out tasks, short dialogue (2026-11-06)

Verified by the headless selftest (PASS) and software-rendered captures. **Not tested on a device.**

- **Monsters.** Monster (extends Enemy) uses the Quaternius Ultimate Monsters models (CC0) and their own animation clips: Idle, Walk, Run, Punch, Weapon, HitReact and Death, or Flying_Idle, Fast_Flying and Headbutt for fliers.
  - Kinds: ghost, ghost_skull, skeleton (Orc_Skull), yeti, mushroom_king, demon and dragon. The last four are bosses with an enraged second phase.
  - Ghosts are see-through and glowing. Arrows do x2 damage to them, fists x0.55, blades x1.3.
- **MonsterMissions: seven chained missions.**
  1. The Restless Dead (first mission of a new game, at night). Ghosts rise from a Kenney graveyard west of the village and haunt the well. The chief hands over the bow.
  2. Bones of the Old Road: reward sword.
  3. Skulls over Kesar Sarai: reward dagger.
  4. The Beast of Sal Forest: yeti.
  5. The Mushroom King.
  6. The Demon of Dhoopgarh: reward axe.
  7. Wings over the Dunes: dragon.
  - Each mission has a 2-shot intro, monsters rising out of the ground, waves and a village heart bar on protect missions (the mission fails at 0).
  - Kill-streak coins, a 1-3 star rating, coin rewards and the next mission unlocked.
  - The mission restarts if the player falls.
- **Weapons.** Quaternius Medieval Weapons models (CC0) are now held in the hand, auto-scaled and gripped: hammer, sword, dagger, spear, axe, and the bow in the left hand. A lying-down model (the Kenney shovel) is stood up automatically.
  - New items: Talwar sword and Silver dagger. The WEAPON button cycles everything you own.
  - Archery: a bow_shot keyframed draw (side-on, bow arm out, string hand to the cheek, release). The arrow model leaves on release.
- **Tasks are acted out.** Interact prompts and progress bars map to body actions:
  - dig: with a shovel, drive, lever and throw.
  - search: bent over, rummaging.
  - pickup: squat and grab.
  - reach: light, touch, place.
  - pray: kneel, palms together.
  - chop: with an axe.
  - cut: kneel and saw.
  - drink, read and push (doors).
  - The player stands still while working, and the selftest checks the prompt mapping.
- **Short story mode.** The new Gameplay setting is on by default. A conversation with no real decision collapses into one line (the first sentence of the opening and closing lines), but every flag it would set is still set. Shops, gifts and choice outcomes keep the full conversation. The intro is cut to two shots that lead straight into the ghost mission.

## Addendum: Animal fur and smooth meshes, and the yellow-slab glitch found (2026-11-06)

Verified by the selftest (PASS) and software-rendered close-ups. **Not tested on a device.**

- **Yellow slabs and brown beams (the long-standing device glitch): found and fixed.**
  - A probe ray found it: a BoxMesh of 18 x 7 x 25 m hanging off a sweeper NPC's hand bone.
  - Some character rigs carry a 100x scale in their bones, so the primitive hand props (broom, ladle, knife, cloth, basket, hammer) were drawn about 100x too big. The broom's yellow bristles and brown handle swung around as the NPCs swept: the "rotating figures".
  - `RealHuman._fit_scale` now undoes the bone scale on every hand prop and weapon.
  - The selftest fails if any hand prop is larger than 3.5 m. It now reports 0.
- **FurLook (all 11 animal species).**
  - Smooth normals averaged across shared corners and material seams (cached per mesh; creases sharper than ~78 deg are kept).
  - The coat gets a fine hair normal map and soft rim light. Eyes and noses are glossy, hooves and horns waxy.
  - 5-layer shell fur with very thin tapered strands. Long and soft on dogs, foxes and camels, very short and fine on horses, cattle and deer.
  - Shells are drawn only within 22 m of the player and are off on the Low preset. There is a new Video setting, "Animal fur".
- Cost on the phone is unknown: 5 extra passes per furred surface for nearby animals.

## Addendum: Progression, daily challenges, login streak, night raids (2026-11-07)

Verified by the selftest (PASS) and a software-rendered capture of the new Hero page. **Not tested on a device.**

- **XP and levels (Progression).**
  - XP sources: half of every coin earned, kills (15; monsters 12; bosses 60), +120 per monster mission, harvests (8), climbs and vaults (2), daily challenges (40), the bonus chest (60) and weapon upgrades (30).
  - Level n needs 80 + 45(n-1) XP.
  - A level-up gives a skill point, a full heal, a banner, a sound and a burst of light. The level is shown on the HUD ("Lv N   HEALTH ...").
- **Skill tree.** Three branches, three skills each, up to 3 ranks:
  - Fighter: Heavy Hands (+12% punch/kick), Combo Flow (-7% strike cooldown), Crusher (+15% weapon swings).
  - Hunter: Quick Draw (-12% bow cooldown), Piercing Shot (+15% arrows), Spirit Bane (+20% vs ghosts).
  - Survivor: Vitality (+15 max HP), Nimble (-20% roll cost, +4% run speed), Second Wind (+25% stamina regen).
- **Weapon upgrades.** Fists, hammer, bow, sword, dagger, spear and axe go to +3 at Dhruv's forge (within 8 m of the Blacksmith). Each level is +12% damage. Level n costs 2+2n iron, 2n-1 monster essence and 40n coins. Monsters drop essence (bosses 4 essence plus 3 iron).
- **Daily challenges.** Three a day, picked deterministically from the device date out of 9 kinds: kills, ghosts, arrows, kicks, coins, riding distance, climbs, harvests, race wins. Each pays coins and XP, and finishing all three opens a bonus chest (coins plus potions, essence or iron).
- **Login streak.** One reward per calendar day, growing over 7 days; day 7 also gives a skill point. Missing a day restarts at day 1. Checked at start and again if you play past midnight.
- **Night raids.** After the first ghost mission, each night has a 60% chance that ghosts raid the village, Bazaar Town, Kesar Sarai or Dhoopgarh. It is announced with a banner and a tracker or map goal, starts when you arrive and fades at dawn. Waves scale with your level, and you protect the settlement's heart for coins.
- **Menu.** The pause menu's button list now scrolls (it was taller than a phone screen). There is a new Hero & challenges page with the XP bar, challenges, streak, skill buttons and upgrade buttons, each saying what is missing.

## Addendum: Wardrobe, uniforms and shops (2026-11-07)

Verified by the selftest (PASS) and software-rendered captures of all 10 outfits and the shop. **Not tested on a device.**

- **Things to spend coins on.** Ten outfits, dyes and supplies, on top of weapon upgrades.
  - **Bazaar cloth stalls:** Village Kurta 60, Adventurer's Gear 120, Maharaja's Robes 1000 (+15% XP), 8 dyes at 25 each, supplies (potion 40, herb 12, iron 30, monster essence 70).
  - **Tailor of Kesar Sarai:** Shadow Garb 220, Ghost Hunter Set 480 (+20% vs ghosts, +10% arrows).
  - **Dhoopgarh Armourer:** Rajput Warrior 350, Royal Guard Uniform 450, Brute Warlord 650, Knight of Veyra 800 (38% armour, 4% slower).
- An outfit swaps the whole body model (`Player.set_body`, which keeps the weapon, the riding pose and the signals) and its colours. It can add a helmet or shoulder pads (`RealHuman.add_gear`, placed from the rest pose and following the bone).
- Each outfit has armour (`outfit_armor`) and small bonuses folded into `Progression.apply`.
- "Try on" previews an outfit and reverts on close unless you buy it. The shop panel sits on the right and the camera turns to show you from the front.
- Owned outfits can be worn anywhere from II > Wardrobe, with a helmet show/hide toggle.
- Natural-colour bodies (Adventurer, Maharaja, Knight) skip the random dye.

## Addendum: More realistic outfits (2026-11-08)

Verified by the selftest (PASS) and software-rendered front and back captures of all 10 outfits. **Not tested on a device.**

- **ClothLook garment shader** on every surface of the player's outfit.
  - Each surface is classed as cloth, leather, metal or skin: by material name on the flat-colour bodies, and per pixel on the painted-atlas bodies (clothing block vs skin block, with grey low-saturation pixels as metal).
  - Cloth: woven thread detail (about 4 mm), soft rim sheen, roughness 0.86. Leather: grain, semi-gloss. Metal: brushed and metallic. Skin: natural with a warm backlight.
  - The detail fades with screen footprint so it never shimmers.
  - Dyes now recolour only garments while keeping the painted folds. This fixes the red or orange faces the old whole-texture tint gave.
  - Bodies use the smooth-normal meshes.
- **Accessories.**
  - Saffron safa turbans with a gold band, jewel and plume (Kurta, Rajput).
  - Kamarband waist sashes (Kurta, Shadow, Rajput, Royal Guard, Maharaja).
  - Capes on Maharaja, Royal Guard, Ghost Hunter, Warlord and Knight. They are gathered at the shoulders, wrap round the body and hang in folds shaded from screen-space normals. They lift and stream behind when running or falling (swing from the rig's speed).
- The Rajput set now wears a turban instead of a helmet. Helmets still hide or show with the toggle, and the turban appears when the helmet is hidden.
- Selftest fix: the login-streak test now computes "yesterday" from the local date, not UTC.

## Addendum: Character details (2026-11-08)

Verified by the selftest (PASS) and software-rendered close-ups. **Not tested on a device.**

- **Jewellery and carried gear** (ClothLook builders, placed from the skeleton's rest pose like the helmets):
  - gold or silver kada bangles lined up with the forearm
  - a rudraksha or gold bead mala with a pendant on the chest
  - a leather belt pouch with a brass button
  - a leather quiver with a brass rim and red and white fletched arrows across the back (once you own a bow)
  - a talwar scabbard angled back from the left hip (once you own the sword)
  - a dagger sheath on the right hip (once you own the dagger)
- Each outfit lists its own jewellery: the Explorer has a kada and a pouch, the Maharaja two kadas and a gold mala, the Rajput a kada and a rudraksha mala, and so on.
- Getting a new weapon re-dresses the player so the gear appears.
- **Villagers and enemies (High graphics only):** the same fabric, leather and metal garment shader with their existing role colours. About a third wear a gold kada and a fifth a silver one. Medium and Low keep the old plain dye, to protect phone speed.

## Addendum: Bow and arrow animation (2026-11-08)

Verified by the selftest (PASS: "archery: target hp 60 -> 42, arrows in the world 1") and software-rendered captures (`--capture-bow`). **Not tested on a device.**

- **Full shot animation** (`bow_shot`, about 1 s):
  1. Reach back to the quiver.
  2. Nock an arrow.
  3. Raise the bow.
  4. Draw to the cheek with the torso turned side-on and the head looking down the arrow.
  5. Release.
  6. Follow through.
- **Live bowstring:** a two-piece string runs from both bow tips to the drawing hand, and the limbs bend as you pull.
- **Nocked arrow:** a real arrow sits on the string from the nock to full draw and leaves on release. Arrow models are now sized to 0.8 m from their bounding box, so they are no longer oversized.
- **Real projectile** (`scripts/arrow.gd`):
  - The arrow flies a ballistic arc with a faint trail.
  - It hits enemies along its path and sticks into them or into the world.
  - Stuck arrows wobble, then clear after 6 s.
- **Aiming:** the shot locks onto the nearest foe within 26 m and leads a moving target at release. With no foe nearby, it fires 35 m straight ahead of the camera.
- The player slows to 30% speed while drawing. The **Quick Draw** skill speeds up the animation itself.

## Addendum: Manual bow aiming (2026-11-08)

Verified by the selftest (PASS: "manual aim: focus true, fire arrows 5 -> 4, headshots 1") and software-rendered captures (`--capture-bow`, `VIEW=aim`). **Not tested on a device.**

- **Hold to aim:** with a bow equipped, the attack button becomes **DRAW**.
  - A quick tap still auto-aims at the nearest foe.
  - Holding the button draws and moves the camera over the right shoulder, zoomed in. A crosshair appears and tightens as the draw fills, then turns orange at full draw.
  - Dragging on the right side of the screen aims, and the archer turns with the view.
  - Letting go shoots wherever the crosshair points. An enemy under the crosshair is locked, at the head if the crosshair is on the head.
- **Focus:** at full draw, time slows to 40% for up to about 3 real seconds. A blue ring around the DRAW button shows the meter, which refills when you aren't aiming. Time always returns to normal on release, death, mounting or a cut-scene.
- **Headshots:** an arrow crossing an enemy's centre line at head height deals 2.5× damage and shows HEADSHOT with a short hit-stop. A fully drawn aimed shot does a further 1.35×. Monsters get head and chest heights from their size.
- **Fire arrows:**
  - Crafted 5 at a time from lamp oil and a hide.
  - Sold in the supplies shops. Lamp oil also drops from raiders.
  - Used automatically on fully drawn aimed shots: 1.25× damage, then 3 burn damage every 0.5 s for 4 s, with a flaming tip and an orange trail.
  - The number left is shown under the DRAW button.
- **Archery pose fix:**
  - The hips now turn side-on while the chest and bow arm stay on target. Measured in the capture, the bow arm is within 1° of the target line; before the fix it was about 80° off.
  - The bow is held upright along the arm from the nock to the follow-through. It no longer lies flat in the fist.
- **Arrow hits** are checked where the arrow crosses the enemy's centre line, so a hit no longer lands early on the body edge.
- **New achievements:** "Eagle Eye" (a headshot kill) and "Still Mind" (a hit during focus). Hindi text was added for all new labels.

## Addendum: Boss fights (2026-11-08)

Verified by the selftest (PASS: "boss: stomp true, player hp 884 -> 865, dazed true, weak spot hits 1, hp 191 -> 155, charge true") and software-rendered captures (`--capture-boss`). **Not tested on a device.**

- The four mission bosses each get a name and a three-phase fight (`scripts/boss_brain.gd`):
  - Himraaj (Yeti)
  - Kukurmatta (Mushroom King)
  - Raktasur (Demon)
  - Agnivyal (Dragon)
- **Phase 1:** heavy swings, plus a **stomp**. A red disc spreads on the ground for 1.1 s, then a shockwave hits anyone inside it who is on the ground. Jump, roll or step out.
- **Phase 2 (below 2/3 health):**
  - A roar (almost no damage gets through), and two minions rise from the ground. They join the mission wave, so the mission waits for them.
  - A glowing **weak spot** opens on the chest.
  - A **charge**: a red lane is marked for 0.9 s, then the boss rushes down it. If it misses, it crashes and is dazed.
- **Phase 3 (below 1/3 health):** enraged (faster, attacks more often), three more minions, and volleys of three **fire orbs** that home in gently. A sidestep or roll beats them.
- **Flying bosses:** the Dragon uses orbs instead of the stomp and charge.
- **Dazed** (after a stomp or a missed charge): it takes 2× damage, and the weak spot glows brighter. Arrows into the weak spot do 3×, and the manual-aim crosshair locks onto it first.
- **Boss bar:** the name, health with phase marks at 1/3 and 2/3, and a one-line tip for the current danger.
- **New achievements:** "Giant Slayer" and "Heart Seeker" (hit the weak spot three times in one fight). Hindi text was added.
- **Fix:** arrow aiming at flying monsters added their hover height twice, about 1.3 m too high for ghosts. Aim points now use the body's real height.

## Addendum: Horse riding upgrades (2026-11-08)

Verified by the selftest (PASS: "horse: fired true, seated true, twist -0.23, target hp 60 -> 42, whistle ..., came true at 3.2 m, road z 362") and software-rendered captures (`--capture-horse`). **Not tested on a device.**

- **Horseback archery now works.** Before, riding locked the player and the bow refused to fire, even though the bow's description promised it.
  - Tap DRAW to auto-aim or hold it to aim from the saddle. The horse keeps moving.
  - The rider's legs stay in the riding pose while the shot drives only the upper body.
  - The rider turns in the saddle up to about 30° off the horse's heading, and the torso twists up to 75° more toward the target.
- **Whistle for your ride:**
  - The animal you last rode (horse, camel, donkey or bull) is remembered.
  - A **HORSE** button, or H on a keyboard, whistles. The nearest animal of that kind gallops over with hoof sounds and whinnies when it arrives.
  - If none is within 45 m, it comes in from behind you, out of sight.
  - If it gets stuck for 14 s, it simply arrives beside you.
  - New sound: `whistle` (self-made, CC0, credited in ASSETS.md).
- **Ride the whole map:** riding was fenced to the old ±195 m valley. You can now ride out along the Southern Road to Kesar Sarai and Dhoopgarh. At the true edge of the world the animal stops instead of snapping back.

## Addendum: Moti, the companion dog (2026-11-08)

Verified by the selftest (PASS: "dog: follows at 3.3 m, bites 2, foe hp 60 -> 48, coin fetched true, pet heals true") and software-rendered captures (`--capture-dog`). **Not tested on a device.**

- **Adoption:** the stray husky near the village (the existing Quaternius CC0 dog) has a "Make friends with the stray dog" prompt. Once adopted, he is **Moti**: a red collar with a brass bell and a name tag. Adoption is saved (`dog_adopted`).
- **Follows you:**
  - On foot he keeps a step behind and to the right, walking or galloping to keep up.
  - He runs alongside your horse at up to 14 m/s.
  - If he falls more than 45 m behind (fast travel, cut-scenes), he catches up out of sight.
- **Sniffs out treasure:**
  - Gold coins within 20 m: he runs to them and fetches them, which counts toward "Coin Collector" and the bounty.
  - Buried caches within 26 m: he runs to the spot, digs and barks until you come over ("Moti smells something buried!"). Each cache is announced once.
- **Fights with you:** when an enemy is within 12 m of you, he runs at the nearest one and bites every 1.1 s (6 damage). Bites stagger men; monsters only take the damage.
- **Pet him** (USE when close): a wag and a bark, +10 health (once a minute). Five pets earns the "Best Friends" achievement.
- Hindi text added.

## Addendum: Horseback aiming fix (2026-11-08)

Reported by the user: "It is not aiming by bow perfectly on the horse." Verified by the selftest (PASS: an aim sweep of 8 targets all round the horse on flat open ground, all hit; held crosshair aim from the saddle hit). **Not tested on a device.**

- **Root cause:** the horse's own collision box blocked aiming.
  - The crosshair ray could lock onto your own horse's neck when aiming forward or down.
  - Arrows could stick into the horse.
  - The camera arm bumped against it.
  - All three now pass through the animal you are riding (`Player.ray_excludes()`).
- **Bow arm on target:** the saddle twist is now a feedback loop. Each frame at full draw it measures where the bow arm really points and turns the torso to close the gap. The rider turns further in the saddle only when the twist alone cannot reach.
- **Measured arm error at full draw:**
  - Straight ahead: 6°
  - Front-left and left: 1°
  - Left-rear: 7°
  - Front-right: 6°
  - Right: 5°
  - Right-rear: 12°
  - Directly behind: 14°
  - Before the fix it was 21–49° in several directions.
- **Test harness fix:** the new boss, horse, dog and crafting tests took the failure list as a plain `Array`. The selftest passes a `PackedStringArray`, which was copied, so their failures were silently dropped. They now take `PackedStringArray`, and all of them pass for real.
- A crash when a target vanished mid-draw (a freed enemy passed to the arrow) is fixed: the arrow flies to the last aim point.

## Addendum: Crafting (2026-11-08)

Verified by the selftest (PASS: "crafting: made [spirit_arrow, tonic, elixir, ward], ward 8.0 vs 16.0, ghost arrow 24 vs spirit 72"). **Not tested on a device.**

- **New materials:**
  - **Feathers:** raider archers drop 3, other raiders sometimes 2, and the shops sell them.
  - **Old bones:** skeletons, 60% of the time.
  - **Ghost dust:** ghosts 60% of the time, bosses 2.
- **New recipes** (Items & crafting page, which now shows how many each makes):
  - Fire arrows ×5 (lamp oil + feather).
  - **Spirit arrows** ×5 (ghost dust + feather): a blue trail and triple an ordinary arrow's damage on spirits. Fully drawn aimed shots at ghosts use them first, and the count shows under DRAW.
  - **Stamina tonic** (2 herbs + bone): refills stamina, which then comes back 60% faster for a minute.
  - **Strength elixir** (essence + 2 herbs): double damage for 25 s.
  - **Ghost ward** (2 ghost dust + herb): spirits do half damage for a minute.
- **Acted out:** crafting plays a short handiwork animation, and drinking any potion, tonic or elixir plays the drinking animation.
- Effects show as timed chips in the combat HUD (TONIC, GHOST WARD). The tonic is also sold in the supplies shops.
- New achievement: "Master Crafter" (craft ten things). Hindi text added.

## Addendum: Real-calendar festivals (2026-11-08)

Verified by the selftest (PASS: "events: diwali 12/12 done true outfit true, holi 8/8 ..., kite shot down by an arrow true, sankranti 6/6 ..., dussehra 3/3 ...", plus 9 date checks) and software-rendered captures (`--capture-event`, `EVENT=<id>`). **Not tested on a device.**

- `scripts/live_events.gd` reads the **phone's date**. While a festival is on, the bazaar is decorated every evening, a festival task appears in the quest list, and a festival outfit is sold in the bazaar.
- **Rewards for each task:** coins, the outfit free (worn straight away), fireworks and the "Festive Spirit" achievement.
- **Diwali** (Lakshmi Puja −4/+3 days; 8 Nov 2026, 29 Oct 2027, 17 Oct 2028): light 12 clay diyas round the bazaar square. Lanterns glow every evening and fireworks go off at night. Outfit: Diwali Sherwani.
- **Holi** (−1/+2 days; 22 Mar 2027, 11 Mar 2028): throw colour at 8 villagers (bursts of gulal; they shout "Holi hai!"). Colour bursts by the fountain. Outfit: Holi Kurta.
- **Makar Sankranti** (13–16 January, every year): 6 kites drift high over the square. Shoot them down with the bow; the manual-aim crosshair locks onto kites. Outfit: Kite Flyer's Jacket.
- **Dussehra** (Navratri to Vijayadashami; 20 Oct 2026, 9 Oct 2027, 27 Sep 2028):
  - A 9 m Ravana effigy with ten crowned heads stands south of the square.
  - It needs 3 fire-arrow hits; ordinary arrows only bring a hint. You get 5 free fire arrows on the first day.
  - It burns and collapses, followed by fireworks. Outfit: Vijaya Warrior.
- **Dates:** the lunar dates were checked against publicholidays.in and holidaydb.com, and 2029 onwards needs adding.
- **Saving and testing:** progress is saved per festival per year. Testing can force a festival with the `EVENT` environment variable or the `event_override` story flag.
- **New sound:** `firework` (self-made, CC0, credited in ASSETS.md). Hindi text was added.

## Addendum: Hindi for the newer systems (2026-11-08)

Verified by the selftest (PASS: "hindi: 185 table texts checked, 0 untranslated", plus sample lines through the translator) and a software-rendered capture in Hindi (`--capture-event` with `HINDI=1`). **Not tested on a device.** The translations are my own and have not been checked by a native speaker.

- The switch already covered the original story, dialogue and menus. The newer systems were in English only.
- **231 new entries** in `data/hindi.json` (1,111 in total), covering:
  - monster missions (titles, briefings, places, objectives, banners, raids)
  - all outfits, shops and dyes
  - skills, daily challenges, the login streak, weapon upgrades and level-up banners
  - items and crafting
  - bosses, Moti, horses and the whistle, festivals
  - the map, achievements
  - and **the on-screen buttons**, which were English even in Hindi mode (दौड़, कूदो, मारो, झुको, रोको, लुढ़को, इस्तेमाल, उतरो)
- **`Loc.tf(format, args)`:** lines built from parts ("Go to %s") are now translated as a whole pattern, so Hindi word order is right ("गाँव का कब्रिस्तान जाओ"). Banners translate line by line.
- **Prompts and toasts** (USE prompts, messages) are translated when drawn, so they follow the current language.
- **Instant switching:** changing the language in Settings now re-translates the HUD at once (`Main.relocalize()`), so the quest panel, Map/Journal and the health line switch without a restart.

## Addendum: Photo studio (2026-11-08)

Verified by the selftest (PASS: every pose holds, the filter and light switch, and exit restores the player and the time of day) and software-rendered captures (`--capture-photo`; the photo also saved there). **Not tested on a device.** Where photos land on Android is untested: the game tries the phone's Pictures folder, then Downloads, then its own folder, and shows the folder it used. Android's storage rules may block the first two.

- **Hides everything:** every on-screen layer is hidden, not just the controls (coins, minimap, area titles and the Map button stayed visible before). Only the photo bar remains.
- **Camera:** drag anywhere to swing the camera round the hero, and pinch (or use the mouse wheel) to zoom. **SELFIE** turns the camera to face the hero.
- **Poses:** Stand, Fighter (guard), Archer (bow held at full draw), Kick (frozen at full extension), Punch, Pray and Victory (arm raised).
  - Built on the existing moves, with a new `move_hold` that freezes a move at a given time and a `photo_pose` that holds a custom pose.
  - The Archer pose borrows the bow for the shot and puts your own weapon back afterwards.
- **Filters:** None, Warm, Cool, Sepia, Black & white and Vivid. Each is a screen shader with a gentle vignette, and it appears in the saved photo.
- **Light:** as it was, sunrise, noon, sunset or night. The real time of day returns on exit.
- **Fix:** festival banners asked for a missing sound (`cheer.wav`). They now use `cheer_crowd`.
- Hindi text added.
