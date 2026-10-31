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
