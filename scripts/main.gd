extends Node3D
## Phase 1 entry point: builds the whole environment in code and drops the placeholder
## player on a raised viewpoint with the ancient entrance in view.
##
## Optional command-line user arguments (everything after `--`):
##   --selftest             run automated checks, print PASS/FAIL, exit with code 0/1
##   --capture=<dir>        render a few fixed viewpoints to PNG files in <dir>, then exit
## Normal launches (including the Android APK) ignore both.

var terrain: TerrainBuilder
var player: Player
var touch: TouchControls
var atmosphere := Atmosphere.new()
var houses: HouseBuilder
var railway: RailwayBuilder
var npcs: Array[Npc] = []
var life: Array = []
var mounts: MountSystem
var stampede: Stampede
var traffic: TrafficBuilder
var footprints: Footprints
var river: RiverBuilder
var town: TownBuilder
var night_life: NightLife
var ambient_life: AmbientLife
var sfx_node: Sfx
var area_title: AreaTitle
var achievements: Achievements
var hints: Hints
var photo_mode: PhotoMode
var shrines: Shrines
var items: Items
var coin_sys: CoinSystem
var dog_sys: DogCompanion
var live_events: LiveEvents
var farm: Farm
var rebuild: VillageRebuild
var campaign: Campaign
var festival: Festival
var bounty: BountyBoard
var monsters: MonsterMissions
var progression: Progression
var wardrobe: Wardrobe
var lock_marker: LockMarker
var diag: Diag
var minigames: MiniGames
var secrets: Secrets
var companion_sys: CompanionSystem
var bazaar: BazaarQuest
var town_houses: HouseBuilder
var water: WaterBuilder
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var cin: Cinematic
var story_b: StoryBuilder
var race: RaceBuilder
var links: StoryLinks
var forest: ForestBuilder
var menu: GameMenu
var map_ui: MapUI
var combat: CombatBuilder
var combat_hud: CombatHUD
var frontier: FrontierBuilder


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	GameSettings.load_file()          # early, so the world is built for the chosen graphics preset
	terrain = TerrainBuilder.new(1337)
	frontier = FrontierBuilder.new()
	frontier.generate()
	terrain.frontier = frontier
	terrain.generate_heights()
	terrain.build(self)
	frontier.build_ground(self, terrain)
	RuinsBuilder.new(terrain).build(self)
	EntranceBuilder.new(terrain).build(self)
	houses = HouseBuilder.new(terrain)
	houses.build(self)
	railway = RailwayBuilder.new(terrain)
	railway.build(self)
	atmosphere.build(self)
	# Safety underlay: a huge sand-coloured slab far below the terrain, so any gap or hole in the
	# world never shows the empty sky underneath.
	var under := MeshInstance3D.new()
	var um := PlaneMesh.new()
	um.size = Vector2(6000, 6000)
	under.mesh = um
	var umat := StandardMaterial3D.new()
	umat.albedo_color = Color(0.55, 0.42, 0.28)
	umat.roughness = 1.0
	umat.cull_mode = BaseMaterial3D.CULL_DISABLED
	under.material_override = umat
	under.position = Vector3(0, -6.0, 0)
	under.name = "Underlay"
	add_child(under)
	var auto_colliders := CollisionFixer.apply(self, terrain)
	print("[LostKingdom] auto colliders added: %d" % auto_colliders)
	_spawn_player()
	npcs = NpcBuilder.build(self, terrain, houses, railway, player)
	life = LifeBuilder.build(self, terrain, houses, railway, player)
	frontier.build_places(self, terrain, player)
	npcs.append_array(frontier.npcs)
	life.append_array(frontier.animals)
	water = WaterBuilder.new(terrain)
	water.build(self, houses)
	water.spawn_carriers(self, houses, player)
	RockScatter.build(self, terrain)
	TempleBuilder.new(terrain, player).build(self)
	atmosphere.terrain_mat = terrain.material
	for hi in 5:
		var hn: Node3D = houses.houses[hi].node
		var hh: Vector2 = houses.houses[hi].half
		Atmosphere.make_smoke(self, hn.global_transform * Vector3(hh.x * 0.55, 4.6, -hh.y * 0.35))
	var sfx := Sfx.new().setup(player, houses)
	sfx_node = sfx
	sfx.main_ref = self
	sfx.atmo = atmosphere
	add_child(sfx)
	_build_interactables()
	_build_ui()
	_build_story()
	print("[LostKingdom] world built in %d ms" % (Time.get_ticks_msec() - t0))

	var args := OS.get_cmdline_user_args()
	if "--audit" in args:
		_run_audit.call_deferred()
		return
	if "--selftest" in args:
		_run_selftest.call_deferred()
		return
	for a in args:
		if a.begins_with("--capture-farm="):
			_run_capture_farm.call_deferred(a.trim_prefix("--capture-farm="))
		if a.begins_with("--capture-pickups="):
			_run_capture_pickups.call_deferred(a.trim_prefix("--capture-pickups="))
		if a.begins_with("--capture-fight="):
			_run_capture_fight.call_deferred(a.trim_prefix("--capture-fight="))
		elif a.begins_with("--capture-gait="):
			_run_capture_gait.call_deferred(a.trim_prefix("--capture-gait="))
		elif a.begins_with("--capture-lab="):
			_run_capture_lab.call_deferred(a.trim_prefix("--capture-lab="))
		elif a == "--probe-perf":
			_run_probe_perf.call_deferred()
		elif a == "--probe-ghost":
			_run_probe_ghost.call_deferred()
		elif a.begins_with("--capture-look="):
			_run_capture_look.call_deferred(a.trim_prefix("--capture-look="))
		elif a.begins_with("--capture-pubg="):
			_run_capture_pubg.call_deferred(a.trim_prefix("--capture-pubg="))
		elif a.begins_with("--capture-weather="):
			_run_capture_weather.call_deferred(a.trim_prefix("--capture-weather="))
		elif a.begins_with("--capture-photo="):
			_run_capture_photo.call_deferred(a.trim_prefix("--capture-photo="))
		elif a.begins_with("--capture-event="):
			_run_capture_event.call_deferred(a.trim_prefix("--capture-event="))
		elif a.begins_with("--capture-dog="):
			_run_capture_dog.call_deferred(a.trim_prefix("--capture-dog="))
		elif a.begins_with("--capture-horse="):
			_run_capture_horse.call_deferred(a.trim_prefix("--capture-horse="))
		elif a.begins_with("--capture-boss="):
			_run_capture_boss.call_deferred(a.trim_prefix("--capture-boss="))
		elif a.begins_with("--capture-bow="):
			_run_capture_bow.call_deferred(a.trim_prefix("--capture-bow="))
		elif a.begins_with("--capture-outfits="):
			_run_capture_outfits.call_deferred(a.trim_prefix("--capture-outfits="))
		elif a.begins_with("--capture-hero="):
			_run_capture_hero.call_deferred(a.trim_prefix("--capture-hero="))
		elif a.begins_with("--capture-fur="):
			_run_capture_fur.call_deferred(a.trim_prefix("--capture-fur="))
		elif a.begins_with("--capture-mon="):
			_run_capture_mon.call_deferred(a.trim_prefix("--capture-mon="))
		elif a.begins_with("--capture-road="):
			_run_capture_road.call_deferred(a.trim_prefix("--capture-road="))
		elif a.begins_with("--capture-fist="):
			_run_capture_fist.call_deferred(a.trim_prefix("--capture-fist="))
		elif a.begins_with("--capture-veyra="):
			_run_capture_veyra.call_deferred(a.trim_prefix("--capture-veyra="))
		elif a.begins_with("--capture-trees="):
			_run_capture_trees.call_deferred(a.trim_prefix("--capture-trees="))
		elif a.begins_with("--capture-menu="):
			_run_capture_menu.call_deferred(a.trim_prefix("--capture-menu="))
		elif a.begins_with("--capture-ride="):
			_run_capture_ride.call_deferred(a.trim_prefix("--capture-ride="))
		elif a.begins_with("--capture-town="):
			_run_capture_town.call_deferred(a.trim_prefix("--capture-town="))
		elif a.begins_with("--capture-race="):
			_run_capture_race.call_deferred(a.trim_prefix("--capture-race="))
		elif a.begins_with("--capture="):
			_run_capture.call_deferred(a.trim_prefix("--capture="))
			return


## Temple: the node and its two interactions exist, and the player can stand on the top tier.
func _selftest_temple(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var altar := 0
	var bell := 0
	for it in get_tree().get_nodes_in_group("interactables"):
		if (it as Interactable).prompt == "Pray at the altar":
			altar += 1
		elif (it as Interactable).prompt == "Ring the temple bell":
			bell += 1
	if get_node_or_null("Temple") == null or altar != 1 or bell != 1:
		fails.append("temple: missing parts (altar=%d bell=%d)" % [altar, bell])
	var c := TerrainBuilder.TEMPLE_C
	_teleport(c.x, c.y + 5.5)
	player.global_position.y = terrain.sample_height(c.x, c.y) + 3.0
	for i in 40:
		await get_tree().physics_frame
	var rise := player.global_position.y - terrain.sample_height(c.x, c.y)
	if rise < 0.7 or rise > 1.3:
		fails.append("temple: player not standing on the top tier (rise %.2f)" % rise)
	notes.append("temple: altar=%d bell=%d standing height %.2f m above ground" % [altar, bell, rise])


## Buildings and people must sit on the ground, not float or sink.
func _selftest_alignment(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var worst := 0.0
	for hs in TerrainBuilder.HOUSE_SITES:
		var lo := 1e9
		var hi := -1e9
		for dx in [-5.0, 0.0, 5.0]:
			for dz in [-5.0, 0.0, 5.0]:
				var h := terrain.sample_height(hs.x + dx, hs.y + dz)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		worst = maxf(worst, hi - lo)
		if hi - lo > 0.45:
			fails.append("alignment: house site %s ground spread %.2f m" % [hs, hi - lo])
	var space := get_world_3d().direct_space_state
	var bad := 0
	var worst_gap := 0.0
	for n in npcs:
		if n.name == "Race Master" or n.get_parent() != self:
			continue
		var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3(0, 2.0, 0), n.global_position + Vector3(0, -6.0, 0))
		var ex: Array[RID] = []
		for c in n.get_children():
			if c is CollisionObject3D:
				ex.append((c as CollisionObject3D).get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var gap := n.global_position.y - float(hit["position"].y)
		worst_gap = maxf(worst_gap, absf(gap))
		if absf(gap) > 0.5:
			bad += 1
			if bad <= 3:
				fails.append("alignment: %s is %.2f m off the ground at %s" % [n.name, gap, n.global_position])
	notes.append("alignment: worst house-site spread %.2f m, worst NPC gap %.2f m" % [worst, worst_gap])


## Fighting: reactions, five death styles, surrender (mercy), grab-and-throw.
func _selftest_fight(fails: PackedStringArray, notes: PackedStringArray) -> void:
	_teleport(-60.0, 20.0)
	for i in 30:
		await get_tree().physics_frame
	var base := player.global_position + Vector3(0, 0.3, -6.0)
	var e := combat.spawn_enemy(base, false, 0.0, "test")
	var hp0 := e.hp
	e.take_hit("punch", 5.0, Vector3(0, 0, -1))
	if e.hp != hp0 - 5.0 or e._stun <= 0.0:
		fails.append("fight: punch did not hurt/stun the enemy")
	e.take_hit("round", 5.0, Vector3(0, 0, -1))
	if e._down <= 0.0:
		fails.append("fight: roundhouse did not knock the enemy down")
	var styles := {}
	var kills: Array[Enemy] = []
	for k in 8:
		var v := combat.spawn_enemy(base + Vector3(k * 1.2, 0, -2.0), false, 0.0, "test")
		v.hp = 1.0
		v.surrendered = false
		v._rng.seed = 100 + k * 7
		v.take_hit("kick", 999.0, Vector3(0, 0, -1))
		styles[v._death_style] = true
		kills.append(v)
	for i in 120:
		await get_tree().physics_frame
	var all_dead := true
	for v in kills:
		if not v.dead or is_nan(v.global_position.y):
			all_dead = false
	if not all_dead:
		fails.append("fight: killed enemies not dead / NaN")
	if styles.size() < 3:
		fails.append("fight: death styles not varied (%d)" % styles.size())
	var m := combat.spawn_enemy(base + Vector3(-3, 0, 0), false, 0.0, "test")
	m.confesses = true
	m.take_hit("kick", m.max_hp * 0.7, Vector3(0, 0, -1))
	if not m.surrendered:
		fails.append("fight: beaten ringleader did not surrender")
	var t := combat.spawn_enemy(base + Vector3(3, 0, 0), false, 0.0, "test")
	var thp := t.hp
	t.begin_held()
	t.throw_from(player, Vector3(0, 0, -1))
	for i in 150:
		await get_tree().physics_frame
	if t.hp >= thp and not t.dead:
		fails.append("fight: thrown enemy took no damage")
	notes.append("fight: reactions ok, %d death styles seen, surrender ok, throw dealt %.0f damage" % [styles.size(), thp - t.hp])
	for n in [e, m, t]:
		if is_instance_valid(n):
			n.queue_free()
	for v in kills:
		if is_instance_valid(v):
			v.queue_free()


## Forest rescue mission: activates after the temple clue, spawns Tara and four attackers, completes.
func _selftest_hunt(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var d: Animal = null
	for l in life:
		if l is Animal and (l as Animal).species == "deer":
			d = l
			break
	if d == null:
		fails.append("hunt: no deer")
		return
	player.has_knife = false
	player.global_position = d.global_position + Vector3(0, 0.5, 2.0)
	player._model.rotation.y = 0.0
	player._on_attack_hit()
	if d.dead or d.hp > 0.0 and d.hp < 40.0:
		fails.append("hunt: hurt without the knife")
	player.has_knife = true
	for i in 4:
		player._on_attack_hit()
	if not d.dead or player.hunted != 1:
		fails.append("hunt: deer not killed with knife")
	notes.append("hunt: ok")


func _selftest_town(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if town == null:
		fails.append("town: not built")
		return
	if town.buildings < 28:
		fails.append("town: only %d buildings" % town.buildings)
	if town.stalls.size() < 14:
		fails.append("town: only %d stalls" % town.stalls.size())
	if town.npcs.size() < 40:
		fails.append("town: only %d people" % town.npcs.size())
	if town.enterable.size() != 4:
		fails.append("town: %d enterable houses" % town.enterable.size())
	# every kind of work is actually being done by somebody
	var modes := {}
	for n in town.npcs:
		modes[n._base_mode] = int(modes.get(n._base_mode, 0)) + 1
	for need in ["hawk", "haggle", "scrub", "sweep", "stir", "knead", "chop", "sit_talk", "sit"]:
		if not modes.has(need):
			fails.append("town: nobody does '%s'" % need)
	# no two buildings, stalls or props overlap
	var fps: Array[PackedVector2Array] = town.footprints
	var overlaps := 0
	for i in fps.size():
		for j in range(i + 1, fps.size()):
			if not Geometry2D.intersect_polygons(fps[i], fps[j]).is_empty():
				overlaps += 1
				if overlaps <= 3:
					fails.append("town: %s and %s overlap" % [town.fp_names[i], town.fp_names[j]])
	# people stand on the ground, not inside buildings: ray down must hit terrain-level geometry
	var space := get_world_3d().direct_space_state
	var bad := 0
	for n in town.npcs:
		var ex: Array[RID] = []
		var hit := {}
		for tries in 6:
			var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3(0, 2.0, 0), n.global_position + Vector3(0, -3.0, 0))
			q.exclude = ex
			hit = space.intersect_ray(q)
			if hit.is_empty():
				break
			var col := hit["collider"] as Node
			if col != null and (col.get_parent() is Npc or col.get_parent() is Animal or col is CharacterBody3D):
				ex.append(hit["rid"])
				hit = {}
				continue
			break
		if hit.is_empty() or absf((hit["position"] as Vector3).y - n.global_position.y) > 0.6:
			bad += 1
			if bad <= 4:
				notes.append("town: off-ground %s at %s hit %s" % [n.name, str(n.global_position), str(hit.get("position", "none"))])
	if bad > 0:
		fails.append("town: %d people not on the ground" % bad)
	# sounds exist
	for s in ["market_crowd_loop", "street_murmur_loop", "water_splash_loop", "sizzle_loop", "fire_crackle_loop", "music_bazaar", "scrub", "sweep", "chop", "knead", "pot_clink", "coin_clink", "tink", "cloth_flap", "goat_bleat", "hen_cluck", "child_laugh", "cart_creak", "bicycle_bell"]:
		if not ResourceLoader.exists("res://assets/audio/%s.wav" % s):
			fails.append("town: missing sound %s" % s)
	if town.emitters.size() < 8:
		fails.append("town: only %d sound emitters" % town.emitters.size())
	# the player can buy food at a stall
	story.set_flag("coins", 10)
	var hp0 := player.hp
	player.hp = 50.0
	town._trade("fruit", 3)
	if int(story.get_flag("coins", 0)) != 7 or player.hp <= 50.0:
		fails.append("town: buying fruit failed")
	player.hp = maxf(hp0, 50.0)
	notes.append("town: %d buildings, %d stalls, %d people, %d emitters, modes %s" % [town.buildings, town.stalls.size(), town.npcs.size(), town.emitters.size(), str(modes)])


func _selftest_inventory(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if menu == null:
		fails.append("inventory: no menu")
		return
	story.set_flag("coins", 42)
	story.set_flag("hunting_knife", true)
	var t: String = menu._inventory_text()
	if not t.contains("Coins: 42") or not t.contains("Hunter's knife") or not t.contains("Sun-Seals"):
		fails.append("inventory: text incomplete: %s" % t)
	else:
		notes.append("inventory: ok")


func _selftest_weather(fails: PackedStringArray, notes: PackedStringArray) -> void:
	atmosphere.set_weather("storm", 60.0)
	if atmosphere.rain_target < 0.99 or atmosphere.story_weather != "storm":
		fails.append("weather: storm not set")
	atmosphere.rain = 1.0
	atmosphere._weather_t = -1.0
	atmosphere._update_weather(0.5)
	if atmosphere.rain_target < 0.99:
		fails.append("weather: random weather overrode the story storm")
	atmosphere.set_weather("clear", 5.0)
	if atmosphere.rain_target != 0.0:
		fails.append("weather: clear did not stop rain")
	atmosphere._update_weather(6.0)
	if atmosphere.story_weather != "":
		fails.append("weather: story hold never released")
	notes.append("weather: ok")


func _selftest_environment(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if river == null or footprints == null:
		fails.append("environment: river/footprints not built")
		return
	# the river fills in rain and drains afterwards
	river.wet = 0.0
	atmosphere.rain = 1.0
	river._process(20.0)
	var filled := river.wet
	atmosphere.rain = 0.0
	river._process(60.0)
	if filled < 0.3 or river.wet >= filled:
		fails.append("environment: river wet %.2f then %.2f" % [filled, river.wet])
	if not river.river_node.mesh.get_surface_count() > 0:
		fails.append("environment: river mesh empty")
	if river.fall_h < 20.0:
		fails.append("environment: waterfall is not high above its base")
	# footprints are placed and fade faster in rain
	var before := footprints.count_made
	footprints.put(player.global_position + Vector3(2, 0, 0), 0.0)
	footprints._on_step(false)
	if footprints.count_made < before + 1:
		fails.append("environment: footprint not placed")
	# lighting presets
	for nm in Atmosphere.LIGHTS.keys():
		atmosphere.apply_preset(nm)
	atmosphere.apply_preset("Noon")
	if absf(atmosphere.time_of_day - 0.5) > 0.01 or atmosphere.story_weather != "clear":
		fails.append("environment: preset Noon not applied")
	atmosphere.apply_preset("Fog")
	if atmosphere.mist_target < 0.99:
		fails.append("environment: fog preset did not set fog")
	atmosphere.release_weather()
	atmosphere.set_weather("clear", 0.01)
	atmosphere.rain = 0.0
	atmosphere.overcast = 0.0
	atmosphere.mist = 0.0
	var sf: Sfx = Sfx.instance
	if sf != null:
		sf._radio.stop()
		sf._radio_gap = 0.0
		sf._update_radio(0.1, 0.0, 100.0, 0.0)
		if not sf.current_track.begins_with("music_day_") or not sf._radio.playing:
			fails.append("music: playlist did not start a day track (%s)" % sf.current_track)
		var first := sf.current_track
		sf._radio.stop()
		sf._radio_gap = 0.0
		sf._update_radio(0.1, 0.0, 100.0, 0.0)
		if sf.current_track == first:
			fails.append("music: same track played twice in a row")
		sf._radio.stop()
		sf._radio_gap = 60.0
	if sf != null:
		var tc := TerrainBuilder.TOWN_C
		var fc2 := TerrainBuilder.FOREST_C
		var checks := [
			["town", Vector3(tc.x, 0, tc.y), "stone", "town"],
			["forest", Vector3(fc2.x + 5.0, 0, fc2.y), "leaf", "forest"],
			["pond", Vector3(TerrainBuilder.POND_C.x, 0, TerrainBuilder.POND_C.y), "water", "pond"],
			["open", Vector3(110, 0, 150), "sand", "desert"],
		]
		for c in checks:
			var cp: Vector3 = c[1]
			cp.y = terrain.sample_height(cp.x, cp.z)
			if sf._surface_at(cp) != c[2]:
				fails.append("footsteps: %s surface is %s, wanted %s" % [c[0], sf._surface_at(cp), c[2]])
			if sf._zone_at(cp) != c[3]:
				fails.append("ambience: %s zone is %s, wanted %s" % [c[0], sf._zone_at(cp), c[3]])
		atmosphere.rain = 1.0
		if sf._surface_at(Vector3(110, 0, 150)) != "mud":
			fails.append("footsteps: wet ground should squelch")
		atmosphere.rain = 0.0
		river.wet = 1.0
		var rp := Vector3(terrain.river_x(60.0), 0, 60.0)
		if sf._surface_at(rp) != "water":
			fails.append("footsteps: a full river should splash")
		river.wet = 0.0
		for sn in ["step_leaf_0", "step_water_1", "step_mud_1", "crow", "owl", "jackal", "frog", "peacock", "cat_meow"]:
			if not ResourceLoader.exists("res://assets/audio/%s.wav" % sn):
				fails.append("audio: %s missing" % sn)
	notes.append("environment: river fills %.2f -> %.2f, %d footprints, 8 lighting presets" % [filled, river.wet, footprints.count_made])


func _selftest_mount(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if mounts == null or int(mounts.get_meta("count", 0)) < 3:
		fails.append("mount: too few rideable animals")
		return
	var a: Animal = null
	for l in life:
		if l is Animal and (l as Animal).species == "horse":
			a = l
			break
	if a == null:
		fails.append("mount: no horse")
		return
	var start := a.global_position
	mounts.mount_animal(a)
	if mounts.mount != a or not player.locked:
		fails.append("mount: mounting failed")
		return
	# ride along whichever compass direction is clear of houses and trees for 14 m
	var best_yaw := 0.0
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5, PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		var fw := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var from := a.global_position + Vector3(0, 0.8, 0)
		if _ray(from, from + fw * 16.0).is_empty():
			best_yaw = yaw
			break
	player.set_look(best_yaw, -0.05)
	player.move_input = Vector2(0, 1)       # stick pushed up = forward
	player.sprint = true
	for i in 90:
		await get_tree().physics_frame
	var moved := a.global_position.distance_to(start)
	var along := (a.global_position - start).dot(Vector3(-sin(best_yaw), 0.0, -cos(best_yaw)))
	var gy := terrain.sample_height(a.global_position.x, a.global_position.z)
	if moved < 6.0:
		fails.append("mount: horse barely moved (%.1f m), blocked by %s" % [moved, mounts.last_block])
	if along < moved * 0.8:
		fails.append("mount: horse did not go where the stick pointed (%.1f of %.1f m)" % [along, moved])
	if absf(a.global_position.y - gy) > 0.3:
		fails.append("mount: horse off ground")
	var rd := player.global_position.y - a.global_position.y
	if rd < 0.8 or rd > 3.0:
		fails.append("mount: rider height %.2f" % rd)
	# JUMP leaps instead of dismounting
	player.jump_requested = true
	var peak := 0.0
	for i in 30:
		await get_tree().physics_frame
		peak = maxf(peak, a.global_position.y - terrain.sample_height(a.global_position.x, a.global_position.z))
	if mounts.mount != a:
		fails.append("mount: JUMP dismounted instead of leaping")
	if peak < 0.8:
		fails.append("mount: animal leap too low (%.2f m)" % peak)
	player.move_input = Vector2.ZERO
	player.sprint = false
	# mounted HIT swings the hammer
	player._attack_cd = 0.0
	player.attack()
	if player._attack_cd < 0.3:
		fails.append("mount: mounted HIT did nothing")
	# the GET OFF button callable dismounts
	touch.on_exit.call()
	await get_tree().physics_frame
	if mounts.mount != null or player.locked:
		fails.append("mount: GET OFF failed")
	notes.append("mount: rode %.1f m, rider +%.2f, leap %.2f" % [moved, rd, peak])
	# guard and roll
	player._invuln = 0.0
	player.set_block(true)
	var hp0 := player.hp
	player.take_damage(40.0, player.global_position - Vector3(-sin(player._model.rotation.y), 0.0, -cos(player._model.rotation.y)) * -3.0)
	var lost_b := hp0 - player.hp
	player.set_block(false)
	if lost_b > 40.0 * 0.3 * GameSettings.damage_scale() + 0.01:
		fails.append("combat: block did not reduce damage (%.1f)" % lost_b)
	player._invuln = 0.0
	player.roll()
	if player._invuln < 0.4:
		fails.append("combat: roll gave no i-frames")
	player._invuln = 0.0
	player._roll_cd = 0.0


func _selftest_forest(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if forest == null:
		fails.append("forest: not built")
		return
	story.set_flag("temple_blessed", true)
	if forest.state != "waiting" or forest.tara == null or forest.enemies.size() != 4:
		fails.append("forest: did not activate (state %s)" % forest.state)
		return
	var fy := terrain.sample_height(forest.tara.global_position.x, forest.tara.global_position.z)
	if absf(forest.tara.global_position.y - fy) > 0.5:
		fails.append("forest: Tara is %.2f m off the ground" % (forest.tara.global_position.y - fy))
	var trees := get_tree().get_nodes_in_group("foliage_palm").size()
	if atmosphere.story_weather != "drizzle":
		fails.append("forest: sky did not darken when the forest road opened (%s)" % atmosphere.story_weather)
	forest.state = "fight"
	story.flags["forest_down"] = 4
	story.changed.emit()
	if forest.state != "done" or not story.get_flag("tara_saved"):
		fails.append("forest: rescue did not complete")
	if atmosphere.story_weather != "clear":
		fails.append("forest: storm did not clear after the rescue (%s)" % atmosphere.story_weather)
	var d: Dictionary = story.dialogue_for("Tara")
	if d.is_empty() or d["start"] != "a":
		fails.append("forest: Tara has no thank-you dialogue")
	story.set_flag("tara_talked", true)
	var p: Dictionary = story.dialogue_for("Priest")
	if p.is_empty() or not str(p["nodes"]["a"]["text"]).begins_with("You found her"):
		fails.append("forest: Rishi ledger dialogue missing")
	notes.append("forest: activated, 4 attackers, rescue completes, dialogue chain ok (%d tree cells)" % trees)
	for e in forest.enemies:
		if is_instance_valid(e):
			e.queue_free()
	forest.enemies.clear()
	if forest.tara != null:
		npcs.erase(forest.tara)
		story.refs.erase("Tara")
		forest.tara.queue_free()
		forest.tara = null
	for k in ["temple_blessed", "forest_down", "tara_saved", "tara_talked"]:
		story.flags.erase(k)
	Sfx.set_mood("")


## Bull cart race: one lap, manual stepping.
func _selftest_race(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if race == null or race.master == null:
		fails.append("race: not built")
		return
	race.manual_step = true
	race.laps_override = 1
	race.start_race()
	if race.racers.size() != 4:
		fails.append("race: expected 4 carts, got %d" % race.racers.size())
		return
	var max_air := 0.0
	var worst_gap := 0.0
	var damaged := false
	var nan := false
	for i in 20000:
		race.step_race(1.0 / 30.0)
		if i % 60 == 0 and race.mine != null:
			print("[race-dbg] t=%d state=%s hp=%s s=%.0f lat=%.1f spd=%.1f lap=%d" % [i / 30, race.state, ",".join(race.racers.map(func(r: CartRacer) -> String: return "%d" % int(r.hp))), race.mine.s, race.mine.lat, race.mine.speed, race.mine.lap])
		if race.state == "idle":
			break
		for r in race.racers:
			var gy := terrain.sample_height(r.global_position.x, r.global_position.z)
			var h := r.global_position.y - gy
			max_air = maxf(max_air, h)
			if not r.dead:
				worst_gap = maxf(worst_gap, absf(minf(h, 0.0)))
			if is_nan(r.global_position.x) or is_nan(r.global_position.y) or is_nan(r.speed):
				nan = true
			if r.hp < 100.0:
				damaged = true
	if nan:
		fails.append("race: NaN in cart state")
	if race.state != "idle":
		fails.append("race: did not finish within the time limit (state %s)" % race.state)
	if race.result == "":
		pass
	if max_air < 0.1:
		fails.append("race: carts never left the ground on the humps (max air %.2f)" % max_air)
	if worst_gap > 0.2:
		fails.append("race: cart sank %.2f m below ground" % worst_gap)
	notes.append("race: result=%s max air %.2f m, damage seen=%s" % [race.result, max_air, str(damaged)])
	# weapons and destruction
	race.start_race()
	var a: CartRacer = race.racers[0]
	var b: CartRacer = race.racers[1]
	b.place(a.s + 0.5, a.lat + 1.0)
	var hp0 := b.hp
	a.atk_cd = 0.0
	a.attack(race.racers)
	if b.hp >= hp0:
		fails.append("race: blade attack did not damage the rival")
	for k in 6:
		b.take_hit(22.0, 1.0)
	if not b.dead:
		fails.append("race: cart was not destroyed at 0 hp")
	for r in race.racers:
		r.cleanup()
	race.racers.clear()
	race.state = "idle"
	race._layer.visible = false
	hud._tracker.visible = true
	player.locked = false
	player._model.visible = true
	race.manual_step = false
	race.laps_override = 0
	race.mine = null
	# story links: Sun-Hammer upgrade, race quest gating, clue flags
	story.flags.erase("seal_forge")
	var vis_before: bool = story.quests.filter(func(q: Dictionary) -> bool: return q["id"] == "race")[0]["show"].call()
	story.set_flag("seal_forge", true)
	var vis_after: bool = story.quests.filter(func(q: Dictionary) -> bool: return q["id"] == "race")[0]["show"].call()
	if vis_before or not vis_after:
		fails.append("story: race quest should unlock after the Hammer-Seal")
	story.set_flag("sun_hammer", true)
	if absf(player.hammer_mult - 1.4) > 0.01:
		fails.append("story: sun-hammer did not raise hammer damage (%.2f)" % player.hammer_mult)
	story.flags.erase("sun_hammer")
	story.flags.erase("seal_forge")
	player.hammer_mult = 1.0
	links._hammer = false


## Save v2 checks: version stamp, old-format migration, backup fallback, corruption handling.
func _selftest_save_v2(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var tp := "user://selftest_v2.json"
	var abs_ := ProjectSettings.globalize_path(tp)
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(abs_ + suffix)
	var ok := true
	# 1. v1 file (no version, no hp) migrates forward.
	var f := FileAccess.open(tp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"flags": {"met_chief": true}, "pos": [1, 2, 3], "yaw": 0.5, "tod": 0.4}))
	f.close()
	var m := SaveSystem.read(tp)
	if m.is_empty() or int(m.get("version", 0)) != SaveSystem.VERSION or not m["flags"].get("met_chief", false) or float(m.get("hp", 0.0)) != -1.0:
		ok = false
		fails.append("save v2: v1 migration failed")
	# 2. Write twice: stamped with the version, previous save kept as .bak.
	SaveSystem.write(tp, {"flags": {"a": 1}, "pos": [0, 0, 0], "hp": 55.0})
	SaveSystem.write(tp, {"flags": {"a": 2}, "pos": [0, 0, 0], "hp": 77.0})
	var cur := SaveSystem.read(tp)
	if int(cur.get("flags", {}).get("a", 0)) != 2 or float(cur.get("hp", 0.0)) != 77.0 or not FileAccess.file_exists(tp + ".bak"):
		ok = false
		fails.append("save v2: write/backup failed")
	# 3. Truncate the main file: the backup is used and the damaged file is kept as .corrupt.
	f = FileAccess.open(tp, FileAccess.WRITE)
	f.store_string("{\"flags\": {\"a\"")
	f.close()
	var rec := SaveSystem.read(tp)
	if int(rec.get("flags", {}).get("a", 0)) != 1 or not FileAccess.file_exists(tp + ".corrupt"):
		ok = false
		fails.append("save v2: corruption recovery failed")
	# 4. Both damaged: nothing is returned and nothing is silently deleted.
	f = FileAccess.open(tp + ".bak", FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	if not SaveSystem.read(tp).is_empty() or not FileAccess.file_exists(tp):
		ok = false
		fails.append("save v2: double corruption handling failed")
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(abs_ + suffix)
	notes.append("save v2 checks: %s" % ("ok" if ok else "FAILED"))


## Real graphics tiers: 0 High, 1 Medium, 2 Low. Controls render scale, shadows, glow, foliage
## draw distance and rain density. Called by GameMenu whenever the setting changes.
## After a language change: re-translate every on-screen label and button, and redraw the quest panel and HUD.
func relocalize() -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasLayer or n is Control:
			Loc.apply_to_tree(n)
			continue
		for c in n.get_children():
			stack.append(c)
	if story != null:
		story.changed.emit()
	if combat_hud != null and player != null:
		combat_hud.call("_on_hp", player.hp, player.max_hp)


func apply_quality(tier: int) -> void:
	atmosphere.quality = tier
	get_viewport().scaling_3d_scale = [0.9, 0.78, 0.62][tier]
	atmosphere.sun.shadow_enabled = true
	atmosphere.sun.directional_shadow_max_distance = [150.0, 110.0, 70.0][tier]
	cull_lights(tier)
	atmosphere.sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_ORTHOGONAL][tier]
	atmosphere.environment.glow_enabled = tier < 2
	var ranges := {"foliage_grass": [130.0, 75.0, 40.0], "foliage_reeds": [160.0, 100.0, 60.0], "foliage_palm": [420.0, 260.0, 150.0], "foliage_stone": [220.0, 130.0, 75.0]}
	for g in ranges:
		for n in get_tree().get_nodes_in_group(g):
			var gi := n as GeometryInstance3D
			gi.visibility_range_end = ranges[g][tier]
			gi.visibility_range_end_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Lag fix: every other small prop stops being drawn beyond a distance that shrinks with the preset.
	# Small things go sooner than big ones on the lower presets (a cup or a flag at ~40 m, a house much further).
	var far_end: float = [170.0, 125.0, 90.0][tier]
	var near_end: float = [170.0, 60.0, 38.0][tier]
	var per_m: float = [0.0, 14.0, 10.0][tier]
	for n2 in find_children("*", "GeometryInstance3D", true, false):
		var g2 := n2 as GeometryInstance3D
		if g2 is Label3D or g2 is GPUParticles3D or g2 is CPUParticles3D:
			continue
		# Low: small things (cups, pots, pebbles, tools) cast no shadow; each caster is drawn again for the shadow map.
		if g2.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and not g2.has_meta("shadow_sz"):
			g2.set_meta("shadow_sz", g2.get_aabb().size.length() * g2.global_transform.basis.get_scale().x)
		if g2.has_meta("shadow_sz") and not player.is_ancestor_of(g2) and not (g2 is MeshInstance3D and (g2 as MeshInstance3D).skin != null):
			var small := tier >= 2 and float(g2.get_meta("shadow_sz")) < 2.0
			g2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if g2.has_meta("far_set"):
			if float(g2.get_meta("far_set")) >= 9999.0:
				continue
			g2.visibility_range_end = clampf(near_end + float(g2.get_meta("far_set")) * per_m, near_end, far_end)
			continue
		var sz := g2.get_aabb().size.length() * g2.global_transform.basis.get_scale().x
		if g2.visibility_range_end > 0.0 or sz > 60.0:
			continue
		g2.visibility_range_end = clampf(near_end + sz * per_m, near_end, far_end)
		g2.visibility_range_end_margin = 6.0
		g2.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		g2.set_meta("far_set", sz)


## Lag fix: lights fade out with distance so the phone only shades the few near the player.
func cull_lights(tier: int) -> void:
	var begin: float = [38.0, 28.0, 18.0][tier]
	for n in _all_lights(self):
		var l := n as Light3D
		if l is DirectionalLight3D:
			continue
		l.distance_fade_enabled = true
		l.distance_fade_begin = begin
		l.distance_fade_length = 14.0
		l.shadow_enabled = false


func _all_lights(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Light3D:
			out.append(c)
		out.append_array(_all_lights(c))
	return out


func _process(delta: float) -> void:
	atmosphere.update(delta)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Farm.start_position(terrain)       # the game starts at the farmhouse door
	add_child(player)
	player.add_child(PowerFx.new(player))
	_look_at_point(Vector3(0.0, 22.0, -168.0), -0.07)
	atmosphere.make_dust(player)
	atmosphere.make_rain(player)
	atmosphere.make_duststorm(player)
	atmosphere.make_clouds(player)
	Npc.atmo = atmosphere


## Neutral test interactions for Phase 2 (no story text): they exist to exercise the system.
func _add_interactable(pos: Vector3, prompt: String, reach: float, text: String) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	it.prompt = prompt
	it.reach = reach
	it.on_interact = func(by: Node3D, _me: Interactable) -> void: (by as Player).say(text)
	add_child(it)
	return it


func _build_interactables() -> void:
	for sx in [-27.0, 27.0]:
		_add_interactable(Vector3(sx, terrain.sample_height(sx, -154.0) + 1.2, -154.0), "Examine statue", 5.0,
			"A weathered stone statue. (placeholder interaction)")
	var wp := Vector2(-90.0, 12.0)
	_add_interactable(Vector3(wp.x, terrain.sample_height(wp.x, wp.y) + 1.0, wp.y), "Look into well", 3.5,
		"The well is dry. (placeholder interaction)")


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	touch = TouchControls.new()
	touch.player = player
	layer.add_child(touch)


func _build_story() -> void:
	var args := OS.get_cmdline_user_args()
	var testing := false
	for a in args:
		if a == "--selftest" or a == "--audit" or a.begins_with("--capture"):
			testing = true
	story = Story.new()
	player.story_ref = story
	add_child(story)
	dlg = DialogueUI.new()
	dlg.player = player
	dlg.story = story
	dlg.touch = touch
	add_child(dlg)
	hud = QuestHUD.new()
	hud.story = story
	hud.player = player
	hud.world = self
	add_child(hud)
	cin = Cinematic.new()
	cin.player = player
	cin.touch = touch
	cin.terrain = terrain
	add_child(cin)
	story_b = StoryBuilder.new(self, story, hud, dlg, cin)
	story_b.build()
	race = RaceBuilder.new(self, story, hud, dlg, terrain, player)
	race.build()
	links = StoryLinks.new(self, story, hud, cin, player, terrain, race)
	links.build()
	combat = CombatBuilder.new(self, story, hud)
	combat.build()
	forest = ForestBuilder.new(self, story, hud, dlg, cin, terrain, player, combat)
	forest.build()
	town_houses = HouseBuilder.new(terrain, 909)
	town = TownBuilder.new(terrain, player, story)
	town.hb = town_houses
	town.build(self)
	var nl := NightLife.new()
	nl.atmo = atmosphere
	nl.player = player
	nl.points = town.lamp_points
	add_child(nl)
	night_life = nl
	ambient_life = AmbientLife.new()
	ambient_life.player = player
	ambient_life.sfx = sfx_node
	ambient_life.atmo = atmosphere
	add_child(ambient_life)
	area_title = AreaTitle.new()
	area_title.sfx = sfx_node
	add_child(area_title)
	npcs.append_array(town.npcs)
	bazaar = BazaarQuest.new(self, story, hud, dlg, terrain, player, combat, town)
	bazaar.build()
	Animal.story_ref = story
	river = RiverBuilder.new(terrain, player, atmosphere)
	river.build(self)
	footprints = Footprints.new(terrain, player, atmosphere)
	footprints.build(self)
	traffic = TrafficBuilder.new(self, terrain, player)
	traffic.build()
	stampede = Stampede.new(self, player, terrain, story)
	add_child(stampede)
	mounts = MountSystem.new(self, player, terrain)
	mounts.build()
	touch.on_exit = Callable(mounts, "dismount")
	touch.on_whistle = Callable(mounts, "whistle")
	touch.has_ride = func() -> bool: return String(story.get_flag("my_ride", "")) != ""
	combat_hud = CombatHUD.new()
	combat_hud.player = player
	add_child(combat_hud)
	map_ui = MapUI.new()
	map_ui.terrain = terrain
	map_ui.player = player
	map_ui.story = story
	map_ui.main = self
	add_child(map_ui)
	menu = GameMenu.new()
	menu.story = story
	menu.player = player
	menu.main = self
	add_child(menu)
	achievements = Achievements.new()
	achievements.story = story
	achievements.player = player
	achievements.atmo = atmosphere
	achievements.hud = hud
	add_child(achievements)
	companion_sys = CompanionSystem.new()
	companion_sys.main = self
	companion_sys.town = town
	companion_sys.story = story
	companion_sys.player = player
	companion_sys.hud = hud
	add_child(companion_sys)
	companion_sys.build()
	rebuild = VillageRebuild.new()
	rebuild.main = self
	rebuild.terrain = terrain
	rebuild.story = story
	rebuild.player = player
	rebuild.hud = hud
	rebuild.night_life = night_life
	add_child(rebuild)
	rebuild.build()
	campaign = Campaign.new()
	campaign.main = self
	campaign.story = story
	campaign.player = player
	campaign.hud = hud
	campaign.dlg = dlg
	campaign.combat = combat
	campaign.terrain = terrain
	campaign.cin = cin
	add_child(campaign)
	campaign.build()
	festival = Festival.new()
	festival.atmo = atmosphere
	festival.hud = hud
	festival.terrain = terrain
	add_child(festival)
	minigames = MiniGames.new()
	minigames.main = self
	minigames.story = story
	minigames.player = player
	minigames.hud = hud
	minigames.dlg = dlg
	minigames.combat = combat
	minigames.terrain = terrain
	minigames.town = town
	add_child(minigames)
	minigames.build()
	secrets = Secrets.new()
	secrets.story = story
	secrets.player = player
	secrets.terrain = terrain
	secrets.hud = hud
	secrets.atmo = atmosphere
	add_child(secrets)
	secrets.build()
	items = Items.new()
	items.story = story
	items.player = player
	items.hud = hud
	add_child(items)
	coin_sys = CoinSystem.new()
	coin_sys.main = self
	coin_sys.terrain = terrain
	coin_sys.story = story
	coin_sys.player = player
	coin_sys.hud = hud
	add_child(coin_sys)
	coin_sys.build()
	dog_sys = DogCompanion.new()
	dog_sys.main = self
	dog_sys.player = player
	dog_sys.story = story
	dog_sys.terrain = terrain
	dog_sys.hud = hud
	add_child(dog_sys)
	dog_sys.build.call_deferred()          # after the secrets and the animals exist
	live_events = LiveEvents.new()
	live_events.main = self
	live_events.story = story
	live_events.player = player
	live_events.terrain = terrain
	live_events.hud = hud
	live_events.festival = festival
	add_child(live_events)
	live_events.build()
	# the season follows the phone's calendar (SEASON overrides it for testing)
	var sn := OS.get_environment("SEASON")
	atmosphere.season = sn if Atmosphere.SEASONS.has(sn) else Atmosphere.season_for_month(int(Time.get_date_dict_from_system()["month"]))
	var skey := "season_seen_%s_%d" % [atmosphere.season, int(Time.get_date_dict_from_system()["year"])]
	if not bool(story.get_flag(skey, false)) and not "--selftest" in OS.get_cmdline_user_args():
		story.set_flag(skey, true)
		var lines := {"shishir": "Winter in the valley: cold, misty mornings.", "vasant": "Spring: flowers on the hills, mild days.",
			"grishma": "Summer: hot days, and dust storms blow in from the south.", "varsha": "The monsoon has come: rain most days, the land turns green.",
			"sharad": "Autumn: clear skies and festival season."}
		(func() -> void: hud.banner(Loc.t(String(lines[atmosphere.season])), "")).call_deferred()
	farm = Farm.new()
	farm.main = self
	farm.terrain = terrain
	farm.story = story
	farm.player = player
	farm.hud = hud
	farm.coins = coin_sys
	farm.items = items
	add_child(farm)
	farm.build()
	bounty = BountyBoard.new()
	bounty.terrain = terrain
	bounty.story = story
	bounty.player = player
	bounty.hud = hud
	bounty.coins = coin_sys
	bounty.shop = farm.shop
	add_child(bounty)
	bounty.build()
	wardrobe = Wardrobe.new()
	add_child(wardrobe)
	wardrobe.setup(story, player, hud)
	progression = Progression.new()
	add_child(progression)
	progression.setup(story, player, hud)
	monsters = MonsterMissions.new()
	monsters.main = self
	monsters.story = story
	monsters.player = player
	monsters.terrain = terrain
	monsters.hud = hud
	monsters.cin = cin
	monsters.combat = combat
	add_child(monsters)
	monsters.build()
	lock_marker = LockMarker.new()
	lock_marker.player = player
	add_child(lock_marker)
	diag = Diag.new()
	diag.main = self
	diag.player = player
	diag.hud = hud
	add_child(diag)
	shrines = Shrines.new()
	shrines.main = self
	shrines.terrain = terrain
	shrines.story = story
	shrines.player = player
	shrines.hud = hud
	add_child(shrines)
	shrines.build()
	hints = Hints.new()
	hints.player = player
	hints.hud = hud
	add_child(hints)
	for bn in ["BazaarTown", "Hamlet", "Railway", "Rocks", "SalForest", "Ruins", "Farm"]:
		var broot := get_node_or_null(bn) as Node3D
		if broot != null:
			var br: Dictionary = StaticBatcher.merge(broot)
			print("[LostKingdom] batched ", bn, ": ", br["merged"], " meshes -> ", br["batches"])
	photo_mode = PhotoMode.new()
	photo_mode.hide_nodes = [touch, hud, combat_hud, menu._btn]
	photo_mode.player = player
	photo_mode.atmo = atmosphere
	add_child(photo_mode)
	if testing:
		return
	player.locked = true
	var ts := TitleScreen.new()
	ts.has_save = GameMenu.has_save()
	ts.crash_info = diag.previous_crash
	ts.chosen.connect(_on_title_chosen)
	add_child(ts)


func _on_title_chosen(continue_game: bool) -> void:
	player.locked = false
	atmosphere.running = true
	if continue_game and menu.load_save():
		story_b.apply_loaded_state()
		player.set_weapon(String(story.get_flag("weapon_sel", "fists")))
		farm.reload()
		coin_sys.reload()
	else:
		story_b.intro.call_deferred()
	wardrobe.wear(wardrobe.worn())
	progression.apply()
	progression.check_login.call_deferred()


func _look_at_point(target: Vector3, pitch: float) -> void:
	var d := target - player.global_position
	player.set_look(atan2(-d.x, -d.z), pitch)


func _teleport(x: float, z: float) -> void:
	player.global_position = Vector3(x, terrain.sample_height(x, z) + 0.3, z)
	player.velocity = Vector3.ZERO


# --- automated self-test (works headless) ---------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _run_selftest() -> void:
	var fails := PackedStringArray()
	var notes := PackedStringArray()

	# 1. Height grid is finite and spans a plausible range.
	var lo := INF
	var hi := -INF
	for h in terrain.heights:
		if is_nan(h) or is_inf(h):
			fails.append("height grid contains NaN/Inf")
			break
		lo = minf(lo, h)
		hi = maxf(hi, h)
	notes.append("terrain height range %.1f .. %.1f m" % [lo, hi])
	if hi - lo < 20.0:
		fails.append("terrain is suspiciously flat")

	# 2. Terrain triangles face upward (Godot front faces are clockwise).
	var arr := terrain._chunk_arrays(2, 2)
	var v: PackedVector3Array = arr[0]
	var idx: PackedInt32Array = arr[3]
	var n := Plane(v[idx[0]], v[idx[1]], v[idx[2]]).normal
	if n.y <= 0.0:
		fails.append("terrain triangle winding faces down")

	await get_tree().physics_frame
	await get_tree().physics_frame

	# 3. Terrain collision matches the height grid at several points.
	for p in [Vector2(120, 160), Vector2(0, 0), Vector2(-60, 60), Vector2(30, -100)]:
		var hit := _ray(Vector3(p.x, 300.0, p.y), Vector3(p.x, -50.0, p.y))
		if hit.is_empty():
			fails.append("no collision under (%d, %d)" % [p.x, p.y])
		elif absf(hit.position.y - terrain.sample_height(p.x, p.y)) > 1.0:
			fails.append("collision/height mismatch at (%d, %d)" % [p.x, p.y])

	# 4. Player settles on the ground at the spawn point.
	for i in 90:
		await get_tree().physics_frame
	if not player.is_on_floor():
		fails.append("player is not on the floor at spawn")
	notes.append("spawn position %s" % [player.global_position.snappedf(0.1)])

	# 5. Walk to the entrance, climb the staircase and get stopped by the sealed door.
	_teleport(0.0, -106.0)
	for i in 30:
		await get_tree().physics_frame
	player.set_look(0.0, -0.1)
	player.move_input = Vector2(0.0, 1.0)
	player.sprint = true
	for i in 1100:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	var pp := player.global_position
	notes.append("after run towards entrance: %s" % [pp.snappedf(0.1)])
	for ci in player.get_slide_collision_count():
		var kc := player.get_slide_collision(ci)
		var cn: Node = kc.get_collider()
		notes.append("touching: %s / %s normal=%s" % [cn.name, cn.get_parent().name, kc.get_normal().snappedf(0.01)])
	var under := _ray(pp + Vector3(0, 2.0, 0), pp - Vector3(0, 2.0, 0))
	if not under.is_empty():
		var col: Node = under.collider
		notes.append("standing on: %s (surface y=%.2f)" % [col.get_parent().name, under.position.y])
	if pp.y < 6.0:
		fails.append("player did not climb the staircase (y=%.1f)" % pp.y)
	if pp.z > -160.0:
		fails.append("player did not reach the platform (z=%.1f)" % pp.z)
	if pp.z < -173.5:
		fails.append("player walked through the sealed door (z=%.1f)" % pp.z)

	# 5a. Phase 2 controller checks on a flat test slab high above the world.
	var slab := StaticBody3D.new()
	slab.name = "TestSlab"
	var slab_shape := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(80, 1, 80)
	slab_shape.shape = sbox
	slab.add_child(slab_shape)
	slab.position = Vector3(0, 500, 0)
	add_child(slab)
	var top := 500.5
	var fixtures := {"step": Vector3(0, top + 0.2, -4), "wall": Vector3(20, top + 0.75, -4)}
	for k in fixtures:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6, 0.4 if k == "step" else 1.5, 2.0)
		cs.shape = bs
		b.add_child(cs)
		b.position = fixtures[k]
		add_child(b)
	player.global_position = Vector3(0, top + 0.3, 6)
	player.velocity = Vector3.ZERO
	for i in 40:
		await get_tree().physics_frame
	player.set_look(0.0, -0.1)
	player.move_input = Vector2(0, 1)
	player.sprint = false
	var step_max_y := top
	for i in 360:
		await get_tree().physics_frame
		step_max_y = maxf(step_max_y, player.global_position.y)
	player.move_input = Vector2.ZERO
	notes.append("step test: player %s, highest point %.2f m above slab" % [player.global_position.snappedf(0.01), step_max_y - top])
	if player.global_position.z > -5.5 or step_max_y < top + 0.38:
		fails.append("player did not step up a 0.4 m ledge (%s)" % [player.global_position])
	player.global_position = Vector3(20, top + 0.3, 6)
	player.velocity = Vector3.ZERO
	for i in 30:
		await get_tree().physics_frame
	player.move_input = Vector2(0, 1)
	for i in 360:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	notes.append("wall test: player %s" % [player.global_position.snappedf(0.01)])
	if player.global_position.z < -3.0 or player.global_position.y > top + 0.3:
		fails.append("player passed or climbed a 1.5 m wall (%s)" % [player.global_position])
	# Climb: jump at the 1.5 m wall and pull up onto it.
	player.global_position = Vector3(20, top + 0.3, -1.6)
	player.velocity = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	var climbs0 := player.climbs
	player.move_input = Vector2(0, 1)
	player.jump_requested = true
	for i in 150:
		await get_tree().physics_frame
		if player.climbs > climbs0:
			player.move_input = Vector2.ZERO
	player.move_input = Vector2.ZERO
	notes.append("climb test: player %s climbs=%d" % [player.global_position.snappedf(0.01), player.climbs - climbs0])
	if player.climbs <= climbs0 or player.global_position.y < top + 1.4:
		fails.append("player did not climb onto a 1.5 m wall (%s)" % [player.global_position])
	# Vault: a thin 1 m fence with ground behind it.
	var fence := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(6, 1.0, 0.25)
	fcs.shape = fbs
	fence.add_child(fcs)
	fence.position = Vector3(-20, top + 0.5, -4)
	add_child(fence)
	player.global_position = Vector3(-20, top + 0.3, -3.1)
	player.velocity = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	climbs0 = player.climbs
	player.move_input = Vector2(0, 1)
	player.jump_requested = true
	for i in 70:
		await get_tree().physics_frame
		if player.climbs > climbs0:
			player.move_input = Vector2.ZERO
	player.move_input = Vector2.ZERO
	notes.append("vault test: player %s vaults=%d" % [player.global_position.snappedf(0.01), player.climbs - climbs0])
	if player.climbs <= climbs0 or player.global_position.z > -4.4:
		fails.append("player did not vault a 1 m fence (%s)" % [player.global_position])
	fence.queue_free()
	# Jump with coyote time: walk off the slab edge and jump just after leaving it.
	player.global_position = Vector3(0, top + 0.3, 6)
	player.velocity = Vector3.ZERO
	for i in 30:
		await get_tree().physics_frame
	player.jump_requested = true
	await get_tree().physics_frame
	var jump_y0 := player.global_position.y
	var apex := jump_y0
	for i in 60:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	notes.append("jump apex %.2f m" % (apex - top))
	if apex - top < 1.2:
		fails.append("jump too low (%.2f m)" % (apex - top))
	# Camera collision: in a corner of a box room the camera must be pulled in.
	var room := StaticBody3D.new()
	for sp in [[Vector3(0, 3, -6), Vector3(12, 6, 0.5)], [Vector3(-6, 3, 0), Vector3(0.5, 6, 12)], [Vector3(6, 3, 0), Vector3(0.5, 6, 12)], [Vector3(0, 6.2, 0), Vector3(12, 0.4, 12)]]:
		var cs2 := CollisionShape3D.new()
		var bs2 := BoxShape3D.new()
		bs2.size = sp[1]
		cs2.shape = bs2
		cs2.position = sp[0]
		room.add_child(cs2)
	room.position = Vector3(0, top, 0)
	add_child(room)
	player.global_position = Vector3(0, top + 0.3, -4.5)
	player.velocity = Vector3.ZERO
	player.set_distance(7.5)
	player.set_look(PI, -0.1)          # looking +z, camera sits behind (towards the -z wall)
	for i in 30:
		await get_tree().physics_frame
	notes.append("camera distance with wall behind: %.2f m" % player.camera_distance())
	if player.camera_distance() > 3.0:
		fails.append("camera did not collide with the wall (%.2f m)" % player.camera_distance())
	player.set_distance(Player.DEFAULT_DISTANCE)
	room.queue_free()

	# 5a2. Interaction range: focus a house door, open it, and see the prompt change.
	var hs0: Dictionary = houses.houses[0]
	var door_it: Interactable = hs0.door
	var hn0: Node3D = hs0.node
	player.global_position = door_it.global_position + (hn0.global_transform.basis * Vector3(0, 0, 3.0)) - Vector3(0, 1.0, 0) + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	for i in 40:
		await get_tree().physics_frame
	_look_at_point(door_it.global_position, 0.0)
	for i in 20:
		await get_tree().physics_frame
	if player.focus != door_it:
		fails.append("door not focused within reach (focus=%s)" % [player.focus])
	else:
		if door_it.prompt != "Open door":
			fails.append("unexpected door prompt: %s" % door_it.prompt)
		player.interact()
		for i in 60:
			await get_tree().physics_frame
		if door_it.prompt != "Close door":
			fails.append("door prompt did not change after interacting")
		notes.append("door interaction ok, prompt now '%s'" % door_it.prompt)
	# Out of range: nothing focused far away.
	_teleport(120.0, 160.0)
	for i in 40:
		await get_tree().physics_frame
	if player.focus != null:
		fails.append("focus should be empty far from any interactable")

	# 5b. Enter the first house through its door, then climb the outside stairs to the roof.
	var hs: Dictionary = houses.houses[0]
	var hn: Node3D = hs.node
	var door_out: Vector3 = hs.door_out
	player.global_position = door_out + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await get_tree().physics_frame
	var inward: Vector3 = hn.global_transform.basis * Vector3(0, 0, -1)
	player.set_look(atan2(-inward.x, -inward.z), 0.0)
	player.move_input = Vector2(0.0, 1.0)
	player.sprint = false
	for i in 150:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	var local_p: Vector3 = hn.global_transform.affine_inverse() * player.global_position
	notes.append("house 0: player local position after walking in %s" % [local_p.snappedf(0.1)])
	if absf(local_p.x) > hs.half.x or local_p.z > hs.half.y - 0.2 or local_p.z < -hs.half.y:
		fails.append("player did not get inside house 0 (local %s)" % [local_p.snappedf(0.1)])
	if local_p.y < 0.0 or local_p.y > 1.5:
		fails.append("player not on the house floor (local y=%.2f)" % local_p.y)

	var sb: Vector3 = hs.stair_bottom
	player.global_position = sb + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	player.set_look(atan2(-inward.x, -inward.z), 0.0)
	player.move_input = Vector2(0.0, 1.0)
	player.sprint = true
	for i in 400:
		await get_tree().physics_frame
		if (hn.global_transform.affine_inverse() * player.global_position).y >= HouseBuilder.WALL_H + 0.3:
			break
	player.move_input = Vector2.ZERO
	player.sprint = false
	var rp: Vector3 = hn.global_transform.affine_inverse() * player.global_position
	notes.append("house 0 stairs: player local position %s" % [rp.snappedf(0.1)])
	if rp.y < HouseBuilder.WALL_H:
		fails.append("player did not climb to the roof of house 0 (local y=%.2f)" % rp.y)

	# 5c. Goods line: walk up the dock ramp and into the boxcar.
	player.global_position = railway.dock_ramp_foot + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	player.set_look(-PI * 0.5, 0.0)
	player.move_input = Vector2(0.0, 1.0)
	for i in 400:
		await get_tree().physics_frame
		if player.global_position.y > RailwayBuilder.RAIL_Y + RailwayBuilder.DOCK_H - 0.2:
			break
	player.move_input = Vector2.ZERO
	notes.append("dock: player at %s" % [player.global_position.snappedf(0.1)])
	if player.global_position.y < RailwayBuilder.RAIL_Y + RailwayBuilder.DOCK_H - 0.3:
		fails.append("player did not reach the loading dock (y=%.2f)" % player.global_position.y)
	var door := railway.boxcar_door_world
	player.global_position = Vector3(door.x, RailwayBuilder.RAIL_Y + RailwayBuilder.DOCK_H + 0.2, door.z - 1.0)
	player.velocity = Vector3.ZERO
	for i in 20:
		await get_tree().physics_frame
	player.set_look(PI, 0.0)
	player.move_input = Vector2(0.0, 1.0)
	for i in 120:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	notes.append("boxcar: player at %s" % [player.global_position.snappedf(0.1)])
	if player.global_position.z < RailwayBuilder.RAIL_Z - 1.2 or player.global_position.y < RailwayBuilder.RAIL_Y + RailwayBuilder.DOCK_H - 0.3:
		fails.append("player did not enter the boxcar")

	# 5d. NPCs are solid: walking straight at one must stop short of its body.
	var elder: Npc = null
	for np in npcs:
		if np.name == "Elder":
			elder = np
	if elder != null:
		var front: Vector3 = elder.global_transform.basis * Vector3(0, 0, -1)
		player.global_position = elder.global_position + front * 3.2 + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		for i in 30:
			await get_tree().physics_frame
		var to_npc := elder.global_position - player.global_position
		player.set_look(atan2(-to_npc.x, -to_npc.z), 0.0)
		player.move_input = Vector2(0, 1)
		var min_d := 99.0
		for i in 240:
			await get_tree().physics_frame
			min_d = minf(min_d, Vector2(player.global_position.x - elder.global_position.x, player.global_position.z - elder.global_position.z).length())
		player.move_input = Vector2.ZERO
		notes.append("closest approach to NPC: %.2f m" % min_d)
		if min_d < 0.7:
			fails.append("player walked into an NPC (%.2f m)" % min_d)

	# 6. Scene census, for the performance notes.
	var meshes := 0
	var bodies := 0
	var multis := 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes += 1
		elif node is StaticBody3D:
			bodies += 1
		elif node is MultiMeshInstance3D:
			multis += 1
		stack.append_array(node.get_children())
	notes.append("MeshInstance3D=%d MultiMeshInstance3D=%d StaticBody3D=%d" % [meshes, multis, bodies])

	# Camera never ends up below the ground, even looking steeply up from below the horizon.
	var below := 0
	var crng := RandomNumberGenerator.new()
	crng.seed = 5
	for ci in 30:
		var cx := crng.randf_range(-150.0, 150.0)
		var cz := crng.randf_range(-150.0, 150.0)
		_teleport(cx, cz)
		player.set_look(crng.randf() * TAU, 0.45)
		for f in 12:
			await get_tree().physics_frame
		var cp := player.camera.global_position
		# Compare with the real collision surface (the terrain mesh's triangles differ slightly from
		# the smooth height formula): a ray from just above the camera downwards must not hit
		# anything higher than the camera.
		var cr := _ray(cp + Vector3(0, 1.5, 0), cp - Vector3(0, 0.5, 0))
		if not cr.is_empty() and cr["position"].y > cp.y + 0.03:
			below += 1
	notes.append("camera below ground: %d / 30" % below)
	if below > 0:
		fails.append("camera went below ground in %d cases" % below)

	# Combat: enemy takes hits and dies, player takes damage, power-ups apply, pickups exist.
	_teleport(100.0, 100.0)
	var foe := combat.spawn_enemy(player.global_position + Vector3(0, 0, -1.6), false, 0.0, "test")
	player.set_look(0.0, 0.0)
	player._model.rotation.y = 0.0
	var hp0 := foe.hp
	player._on_attack_hit()
	if foe.hp >= hp0:
		fails.append("combat: player hit did not damage enemy")
	player.take_damage(10.0, Vector3(0, 0, 1))
	if player.hp >= 100.0:
		fails.append("combat: player did not take damage")
	player.apply_powerup("shield")
	if not player.power.has("shield"):
		fails.append("combat: power-up not applied")
	foe.take_damage(999.0, Vector3.FORWARD)
	if not foe.dead:
		fails.append("combat: enemy did not die")
	for kk in ["health", "speed", "power", "shield"]:
		var tp := Pickup.new().setup(kk, player, player.global_position + Vector3(0, 0, -8.0))
		add_child(tp)
		tp._collect_fx()
		tp.queue_free()
	var pk := 0
	for ch in get_children():
		if ch is Pickup:
			pk += 1
	if pk < 6:
		fails.append("combat: expected pickups, found %d" % pk)
	player.hp = player.max_hp
	player.power.clear()
	notes.append("combat ok, pickups=%d" % pk)

	# Story: flags, quests, dialogue data, interactables.
	var sflow := Story.new()
	add_child(sflow)
	sflow.refresh()
	if sflow.active_objectives(4).is_empty():
		fails.append("story: no active objective at start")
	for who in ["Guide", "Chief", "Blacksmith", "RailWorker", "Elder", "desk", "map", "Trader"]:
		var d: Dictionary = sflow.dialogue_for(who)
		if d.is_empty() or not d["nodes"].has(d["start"]):
			fails.append("story: bad dialogue " + who)
			continue
		for k in d["nodes"]:
			var nd: Dictionary = d["nodes"][k]
			var gos: Array = [nd.get("go", "")]
			for c in nd.get("choices", []):
				gos.append(c.get("go", ""))
			for g in gos:
				if g != "" and not d["nodes"].has(g):
					fails.append("story: %s node %s -> missing %s" % [who, k, g])
	sflow.set_flag("journal"); sflow.set_flag("map"); sflow.set_flag("met_chief")
	sflow.refresh()
	if not sflow.quest_done(sflow.quests[0]):
		fails.append("story: quest 1 not done after flags")
	for sf in Story.SEALS:
		sflow.set_flag(sf)
	if sflow.seals_held() != 3:
		fails.append("story: seals_held != 3")
	sflow.free()
	var talk := 0
	var gate_it := 0
	for it in get_tree().get_nodes_in_group("interactables"):
		if (it as Interactable).prompt.begins_with("Talk to"):
			talk += 1
		if (it as Interactable).prompt.begins_with("Examine the Sun Gate"):
			gate_it += 1
	if talk < 10 or gate_it != 1:
		fails.append("story: interactables talk=%d gate=%d" % [talk, gate_it])
	notes.append("story ok: talk interactables=%d" % talk)

	# Save / load round trip (uses a temporary save file, then removes it).
	var had_save := GameMenu.has_save()
	if not had_save:
		story.set_flag("intro_done", true)
		story.set_flag("met_chief", true)
		var keep_pos := player.global_position
		menu.save()
		story.flags.erase("met_chief")
		player.global_position = Vector3.ZERO
		if not menu.load_save() or not story.get_flag("met_chief") or player.global_position.distance_to(keep_pos + Vector3(0, 0.3, 0)) > 0.5:
			fails.append("save/load round trip failed")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameMenu.SAVE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameMenu.SAVE_PATH + ".bak"))
		story.flags.clear()
		player.global_position = keep_pos
	notes.append("save/load checked")
	_selftest_save_v2(fails, notes)
	await _selftest_temple(fails, notes)
	_selftest_alignment(fails, notes)
	_selftest_race(fails, notes)
	await _selftest_forest(fails, notes)
	await _selftest_mount(fails, notes)
	_selftest_town(fails, notes)
	_selftest_inventory(fails, notes)
	_selftest_weather(fails, notes)
	_selftest_environment(fails, notes)
	_selftest_settings(fails, notes)
	_selftest_animal_acts(fails, notes)
	_selftest_stampede(fails, notes)
	await _selftest_localisation(fails, notes)
	await _selftest_powerfx(fails, notes)
	await _selftest_map_route(fails, notes)
	_selftest_cin_ground(fails)
	_selftest_night_life(fails)
	await _selftest_frontier(fails)
	await _selftest_monsters(fails)
	await _selftest_progression(fails)
	# hand props must be their real size (a 100x bone scale once turned brooms into giant yellow slabs)
	for i in 3:
		await get_tree().process_frame
	var big := 0
	for att in find_children("*", "BoneAttachment3D", true, false):
		for mi in (att as Node).find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh != null and (m.global_transform * m.get_aabb()).size.length() > 3.5:
				big += 1
				if big < 4:
					fails.append("props: oversized hand prop %s (%s)" % [m.get_path(), (m.global_transform * m.get_aabb()).size])
	print("[selftest] props: %d oversized hand props" % big)
	await _selftest_walls(fails)
	await _selftest_farm(fails)
	items.give("hide", 3)
	items.give("iron", 1)
	if not items.craft("bow") or not items.equip("bow") or not player.gear_ranged:
		fails.append("bow craft/equip failed")
	_teleport(180.0, 180.0)
	var bt := combat.spawn_enemy(player.global_position + Vector3(0, 0, -9.0), false, 0.0, "test")
	var bhp: float = bt.hp
	player._attack_cd = 0.0
	player.locked = false
	if not player.fire_arrow() or player.arrows_fired < 1:
		fails.append("bow did not fire at a foe 9 m away")
	await get_tree().create_timer(0.45).timeout
	if player._rig._nocked == null or not player._rig._nocked.visible or player._rig._string.size() != 2:
		fails.append("archery: no arrow on the string while drawing")
	await get_tree().create_timer(1.0).timeout
	if bt.hp >= bhp:
		fails.append("arrow did not hurt the target")
	var stuck := 0
	for an in find_children("*", "Node3D", true, false):
		if an is Arrow:
			stuck += 1
	print("[selftest] archery: target hp %.0f -> %.0f, arrows in the world %d" % [bhp, bt.hp, stuck])
	# manual aim: craft fire arrows, hold the draw (focus slows time), put the crosshair on the head, let go
	items.give("oil", 1)
	items.give("feather", 1)
	if not items.craft("fire_arrow") or items.count("fire_arrow") != 5:
		fails.append("fire arrows: crafting did not give 5")
	var bt2 := combat.spawn_enemy(player.global_position + Vector3(2.0, 0, -12.0), false, 0.0, "test2")
	bt2.set_physics_process(false)
	var hp2: float = bt2.hp
	var hsh0 := Arrow.headshots
	player._attack_cd = 0.0
	player.begin_aim()
	if not player.aiming:
		fails.append("manual aim: holding the bow button did not start a draw")
	var slowed := false
	for it in 6:
		await get_tree().create_timer(0.2, true, false, true).timeout
		var head: Vector3 = bt2.global_position + Vector3(0, Arrow.head_height(bt2), 0)
		var dv: Vector3 = head - player.camera.global_position
		player.set_look(atan2(-dv.x, -dv.z), atan2(dv.y, Vector2(dv.x, dv.z).length()))
		slowed = slowed or Engine.time_scale < 0.5
	var fa0 := items.count("fire_arrow")
	player.release_aim()
	if not slowed:
		fails.append("manual aim: focus did not slow time at full draw")
	if Engine.time_scale != 1.0:
		fails.append("manual aim: time scale not restored on release")
	await get_tree().create_timer(1.2).timeout
	if items.count("fire_arrow") != fa0 - 1:
		fails.append("manual aim: charged shot did not use a fire arrow")
	if Arrow.headshots <= hsh0:
		fails.append("manual aim: crosshair on the head did not score a headshot (hp %.0f -> %.0f)" % [hp2, bt2.hp])
	print("[selftest] manual aim: focus %s, fire arrows %d -> %d, headshots %d, target hp %.0f -> %.0f" % [slowed, fa0, items.count("fire_arrow"), Arrow.headshots - hsh0, hp2, bt2.hp])
	if is_instance_valid(bt2) and not bt2.dead:
		bt2.queue_free()
	await _selftest_boss(fails)
	await _selftest_horse(fails)
	await _selftest_pubg_aim(fails)
	await _selftest_dog(fails)
	await _selftest_crafting(fails)
	await _selftest_events(fails)
	_selftest_hindi(fails)
	await _selftest_photo(fails)
	await _selftest_seasons(fails)
	_selftest_transfer(fails)
	items.unequip("weapon")
	for k in 5:
		story.flags.erase("cache_%d" % k)
	story.flags.erase("night_chest")
	secrets.nodes[0].visible = true
	secrets.its[0].enabled = true
	var coins0: int = int(story.get_flag("coins", 0))
	if not secrets.open_cache(0) or secrets.open_cache(0) or int(story.get_flag("coins", 0)) != coins0 + 40:
		fails.append("secrets: cache payout/once-only wrong")
	atmosphere.time_of_day = 0.0
	atmosphere.apply_time()
	secrets._t = 0.0
	secrets._process(0.1)
	if not secrets.chest.visible or not secrets.chest_it.enabled:
		fails.append("secrets: night chest not visible at midnight")
	atmosphere.time_of_day = 0.5
	atmosphere.apply_time()
	secrets._t = 0.0
	secrets._process(0.1)
	if secrets.chest.visible:
		fails.append("secrets: night chest visible at noon")
	if not secrets.open_night_chest() or items.count("chain") < 1:
		fails.append("secrets: night chest reward missing")
	story.flags.erase("cache_0")
	story.set_flag("coins", 100)
	if minigames.dice_round(10, 9, 4) != "win" or int(story.get_flag("coins", 0)) != 110:
		fails.append("dice: win did not pay")
	if minigames.dice_round(50, 3, 8) != "lose" or int(story.get_flag("coins", 0)) != 60:
		fails.append("dice: loss did not cost")
	if minigames.dice_round(50, 7, 7) != "tie" or int(story.get_flag("coins", 0)) != 60:
		fails.append("dice: tie moved coins")
	if minigames.dice_round(500, 12, 2) != "broke":
		fails.append("dice: unaffordable bet allowed")
	_teleport(minigames.arena_center().x, minigames.arena_center().z)
	story.flags.erase("arena_best")
	if not minigames.start_arena() or minigames.arena_alive() != 3:
		fails.append("arena: wave 1 wrong (%d)" % minigames.arena_alive())
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).get_meta("tag", "") == "arena":
			(e as Enemy).take_hit("slam", 99999.0, Vector3.FORWARD)
	var c_before: int = int(story.get_flag("coins", 0))
	minigames._t = 0.0
	minigames._process(0.1)
	if minigames.wave != 2 or minigames.arena_alive() != 4 or int(story.get_flag("coins", 0)) != c_before + 20:
		fails.append("arena: wave 2 / reward wrong (wave %d, alive %d)" % [minigames.wave, minigames.arena_alive()])
	minigames.end_arena("test")
	if minigames.active or int(story.get_flag("arena_best", 0)) != 1:
		fails.append("arena: end/best wave wrong")
	story.flags.erase("animals_fed")
	var guard: Npc = null
	for f2 in get_tree().get_nodes_in_group("npcs"):
		var gn := f2 as Npc
		if gn != null and gn.role == "guard" and not gn.companion:
			guard = gn
			break
	if guard != null:
		var hp_g := player.hp
		player.assaults = 5
		player.wanted_t = 30.0
		guard.global_position = player.global_position + Vector3(0.0, 0.0, 1.0)
		guard._atk_cd = 0.0
		guard._guard_attack(0.016)
		if player.hp >= hp_g and player._invuln <= 0.0:
			fails.append("hits: hostile guard did not strike")
		player.heal(50.0)
		player.assaults = 0
		player.wanted_t = 0.0
	var cow: Animal = null
	for an in get_tree().get_nodes_in_group("animals"):
		if String(Animal.BEHAVIOUR.get((an as Animal).species, "")) == "prey" and not (an as Animal).dead:
			cow = an as Animal
			break
	if cow == null:
		notes.append("wildlife feed test skipped: no prey animal")
	else:
		player.global_position = cow.global_position + Vector3(1.5, 0.3, 0.0)
		items.give("herb", 2)
		if not items.feed_nearest() or cow.calm_t < 60.0 or int(story.get_flag("animals_fed", 0)) != 1:
			fails.append("feeding an animal failed")
		items.take("herb", items.count("herb"))
	festival.day = 5
	atmosphere.time_of_day = 0.8
	festival.refresh()
	var lit_l := 0
	for l in festival.lanterns:
		if l.visible:
			lit_l += 1
	if festival.kind != "lights" or lit_l != 24:
		fails.append("festival lights not shown on day 5 evening (kind %s, lit %d)" % [festival.kind, lit_l])
	atmosphere.time_of_day = 0.5
	festival.refresh()
	if festival.lanterns[0].visible:
		fails.append("festival lights on at noon")
	festival.day = 10
	if festival.kind_for(10) != "colours" or festival.kind_for(7) != "":
		fails.append("festival kinds wrong")
	festival.day = 1
	festival.refresh()
	story.set_flag("intro_done", true)
	story.set_flag("slot_test", 11)
	if not menu.slot_save(3) or menu.slot_info(3) == "Empty":
		fails.append("save slot: could not save slot 3")
	story.set_flag("slot_test", 22)
	var sd: Dictionary = SaveSystem.read(GameMenu.SLOT_PATH % 3)
	if int((sd.get("flags", {}) as Dictionary).get("slot_test", 0)) != 11:
		fails.append("save slot: slot 3 holds the wrong data")
	menu._show_page("Slots")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameMenu.SLOT_PATH % 3))
	DirAccess.remove_absolute(ProjectSettings.globalize_path((GameMenu.SLOT_PATH % 3) + ".bak"))
	story.flags.erase("slot_test")
	for k in ["braziers", "tablets", "karan_met", "captain_down", "warden_down", "act3_done", "v_entered", "brazier_0", "brazier_1", "brazier_2", "tablet_0", "tablet_1", "tablet_2"]:
		story.flags.erase(k)
	if campaign.descend():
		fails.append("descended before Karan was beaten")
	story.set_flag("captain_down", true)
	if not campaign.descend() or player.global_position.distance_to(Campaign.ORIGIN) > 80.0 or not story.get_flag("v_entered"):
		fails.append("descending into Veyra failed")
	for bi in 3:
		campaign.light_brazier(bi, campaign.brazier_its[bi])
	campaign.light_brazier(0, campaign.brazier_its[0])
	if int(story.get_flag("braziers", 0)) != 3:
		fails.append("brazier count wrong: %s" % str(story.get_flag("braziers", 0)))
	for ti in 3:
		campaign.read_tablet(ti)
		dlg.close_for_test()
	if int(story.get_flag("tablets", 0)) != 3 or not campaign.karan_it.enabled:
		fails.append("tablets did not unlock Karan")
	story.set_flag("karan_met", true)
	await get_tree().process_frame
	await get_tree().process_frame
	if campaign.warden == null or not is_instance_valid(campaign.warden) or campaign.warden.max_hp < 400.0:
		fails.append("Stone Warden did not appear")
	else:
		campaign.warden.take_hit("slam", 9999.0, Vector3.FORWARD)
		if not story.get_flag("warden_down", false):
			fails.append("killing the Warden did not set warden_down")
		await get_tree().process_frame
		if not story.get_flag("act3_done", false) or items.count("chain") < 1:
			fails.append("Act 3 completion rewards missing")
	campaign.ascend()
	await _selftest_act4(fails)
	await _selftest_act5(fails)
	for k in 3:
		story.flags.erase("rebuild_%d" % (k + 1))
	rebuild.built = [false, false, false]
	var rb_hp: float = player.max_hp
	var lamps0: int = night_life.points.size()
	story.set_flag("coins", 99)
	if rebuild.pay_next():
		fails.append("rebuilt without enough coins")
	story.set_flag("coins", 1000)
	if not rebuild.pay_next() or not rebuild.pay_next() or not rebuild.pay_next() or rebuild.pay_next():
		fails.append("rebuilding stages wrong")
	if rebuild.stage() != 3 or int(story.get_flag("coins", 0)) != 150 or player.max_hp != rb_hp + 45.0:
		fails.append("rebuild cost/health bonus wrong")
	if night_life.points.size() != lamps0 + 4:
		fails.append("new lamps not added to night lighting")
	player.max_hp = rb_hp
	story.flags.erase("sher_hired")
	story.set_flag("coins", 50)
	if companion_sys.toggle() or companion_sys.is_hired():
		fails.append("hired Sher without enough coins")
	story.set_flag("coins", 200)
	if not companion_sys.toggle() or not companion_sys.npc.companion or int(story.get_flag("coins", 0)) != 80:
		fails.append("hiring Sher failed")
	var dmg0: float = companion_sys.npc.companion_damage
	for k in 5:
		companion_sys.note_kill()
	if companion_sys.npc.companion_damage <= dmg0:
		fails.append("Sher did not grow stronger with trust")
	companion_sys.toggle()
	if companion_sys.npc.companion:
		fails.append("Sher still following after dismissal")
	story.flags.erase("sher_trust")
	companion_sys.trust = 0
	player.stamina = 100.0
	player.spend(30.0)
	if absf(player.stamina - 70.0) > 0.01:
		fails.append("stamina spend wrong")
	player._stam_delay = 0.0
	player._tick_stamina(1.0, false)
	if player.stamina <= 70.5:
		fails.append("stamina did not regenerate")
	player.stamina = 100.0
	_teleport(160.0, 160.0)
	var pe := combat.spawn_enemy(player.global_position + Vector3(0, 0, -1.5), false, 0.0, "test")
	player.hp = player.max_hp
	player.set_block(true)
	player._block_t = 0.0
	player._invuln = 0.0
	var hp_p: float = player.hp
	player.take_damage(12.0, Vector3(0, 0, 1))
	if player.hp < hp_p or player.parries < 1 or pe._stun <= 0.0:
		fails.append("parry did not negate damage and stagger")
	player.set_block(false)
	for k in ["herb", "iron", "hide", "potion", "spear", "leather"]:
		story.flags.erase("item_" + k)
	items.give("herb", 3)
	items.give("iron", 2)
	items.give("hide", 5)
	if not items.craft("potion") or items.count("potion") != 1 or items.count("herb") != 0:
		fails.append("crafting a potion failed")
	if not items.craft("spear") or not items.equip("spear") or player.gear_reach < 0.5:
		fails.append("spear craft/equip failed")
	if not items.craft("leather") or not items.equip("leather") or player.armor_mult > 0.85:
		fails.append("leather craft/equip failed")
	var hp_before: float = player.hp
	player.hp = 50.0
	if not items.use("potion") or player.hp <= 60.0:
		fails.append("potion did not heal")
	player.hp = hp_before
	items.unequip("weapon")
	items.unequip("armour")
	if player.gear_reach != 0.0 or player.armor_mult != 1.0:
		fails.append("unequip did not reset gear")
	menu._show_page("Items")
	Loc.set_language("hi")
	menu._show_page("Settings")
	var hi_btn := false
	for b in menu._panel.find_children("*", "Button", true, false):
		if (b as Button).text == "जारी रखो":
			hi_btn = true
	Loc.set_language("en")
	menu._show_page("Settings")
	var en_btn := false
	for b2 in menu._panel.find_children("*", "Button", true, false):
		if (b2 as Button).text == "Resume":
			en_btn = true
	if not hi_btn or not en_btn:
		fails.append("menu did not switch language both ways (hi %s, en %s)" % [hi_btn, en_btn])
	if player.set_outfit(3) < 1:
		fails.append("outfit colour changed nothing")
	player.set_outfit(0)
	var keep_t: float = atmosphere.time_of_day
	var keep_r: bool = atmosphere.running
	atmosphere.running = false
	atmosphere.time_of_day = 0.26
	atmosphere._story_t = 0.0
	atmosphere.story_weather = ""
	atmosphere.rain_target = 0.0
	atmosphere._update_weather(0.1)
	if atmosphere.mist_target < 0.3:
		fails.append("no morning mist at 0.26")
	atmosphere.time_of_day = 0.5
	atmosphere._update_weather(0.1)
	if atmosphere.mist_target > 0.01:
		fails.append("mist still on at noon")
	atmosphere.time_of_day = keep_t
	atmosphere.running = keep_r
	story.flags.erase("shrine_pond")
	if shrines.lit_list().size() != 0 and shrines.is_lit("pond"):
		fails.append("shrine should start unlit")
	shrines.light("pond")
	player._combat_t = 99.0
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node3D).global_position += Vector3(0, 0, 500)
	_teleport(0.0, 0.0)
	var travelled: bool = shrines.travel("pond")
	if not travelled or player.global_position.distance_to(Vector3(-60.0, player.global_position.y, 74.0)) > 6.0:
		fails.append("fast travel to a lit shrine failed")
	if shrines.travel("ruins") and not shrines.is_lit("ruins"):
		fails.append("fast travel to an unlit shrine must be refused")
	achievements.done.erase("chief")
	story.set_flag("met_chief", true)
	achievements._t = 0.0
	achievements._process(0.1)
	if not achievements.done.has("chief"):
		fails.append("achievement did not unlock from a story flag")
	hints.shown.erase("map")
	if not hints.tip("map") or hints.tip("map"):
		fails.append("hint should show exactly once")
	photo_mode.enter()
	var hidden_ok: bool = not touch.visible
	photo_mode.exit()
	if not hidden_ok or not touch.visible:
		fails.append("photo mode did not hide/restore controls")
	if not menu._journal_text().contains("Achievements"):
		fails.append("journal page text missing")
	_teleport(140.0, 140.0)
	var re := combat.spawn_enemy(player.global_position + Vector3(0, 0, -6.0), false, 0.0, "test")
	re.apply_role("shield")
	re.rotation.y = 0.0     # faces -Z... player hits from -Z side? use +Z push dir
	var hp_s: float = re.hp
	re.take_hit("punch", 10.0, Vector3(0, 0, 1))      # push toward +Z = attacker stands in front (-Z)
	var lost: float = hp_s - re.hp
	if lost > 4.0:
		fails.append("shield did not absorb a frontal punch (lost %.1f)" % lost)
	re.apply_role("archer")
	var arrows_before: int = re.shots_fired
	re.shoot()
	if re.shots_fired != arrows_before + 1:
		fails.append("archer did not shoot")
	var bos := combat.spawn_enemy(player.global_position + Vector3(8, 0, 0), true, 0.0, "test")
	bos.take_hit("punch", bos.max_hp * 0.55, Vector3.FORWARD)
	if not bos.enraged:
		fails.append("boss did not enrage below half health")
	_teleport(120.0, 120.0)
	var sfoe := combat.spawn_enemy(player.global_position + Vector3(0, 0, -2.0), false, 0.0, "test")
	var sl_hp0: float = sfoe.hp
	var sl_hits: int = player.ground_slam()
	if sl_hits < 1 or sfoe.hp >= sl_hp0:
		fails.append("ground slam did not hurt a nearby enemy")
	area_title.show_zone("forest")
	if area_title.label.text == "" or area_title.shown != "forest":
		fails.append("area title card missing")
	var rip := ambient_life.spawn_ripple(Vector3(0, 1, 0), 1.0)
	if rip == null or ambient_life.ripples < 1:
		fails.append("ambient life: ripple not spawned")
	_teleport(TerrainBuilder.FOREST_C.x, TerrainBuilder.FOREST_C.y)
	atmosphere.time_of_day = 0.5
	atmosphere.apply_time()
	ambient_life._zone_t = 0.0
	ambient_life._process(0.1)
	if not ambient_life.butterflies.emitting or not ambient_life.leaves.emitting:
		fails.append("ambient life: forest butterflies/leaves not on by day")
	var hfx := HitFx.burst(self, Vector3(0, 2, 0), true)
	if hfx == null or not hfx.one_shot:
		fails.append("hit fx burst missing")
	await _selftest_traffic(fails, notes)
	await _selftest_hunt(fails, notes)
	await _selftest_fight(fails, notes)

	for s in notes:
		print("[selftest] ", s)
	if fails.is_empty():
		print("[selftest] PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			printerr("[selftest] FAIL: ", f)
		get_tree().quit(1)


## Lists visible meshes that have no collision, so walk-through-able objects can be found.
func _run_audit() -> void:
	await get_tree().physics_frame
	var rows := []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null:
			continue
		# Does the mesh sit under / beside a collision body?
		var solid := false
		var a: Node = mi
		while a != null and a != self:
			if a is StaticBody3D or a is CharacterBody3D:
				solid = true
				break
			for c in a.get_children():
				if c is StaticBody3D:
					solid = true
					break
			if solid:
				break
			a = a.get_parent()
		if solid:
			continue
		var bb := mi.global_transform * mi.get_aabb()
		var sz := bb.size
		if sz.y < 0.5 or maxf(sz.x, sz.z) < 0.35 or sz.x > 300.0 or sz.z > 300.0:
			continue
		var low := bb.position.y - terrain.sample_height(bb.get_center().x, bb.get_center().z)
		if low > 2.0:
			continue
		rows.append([sz.x * sz.y * sz.z, str(mi.get_path()), bb])
	rows.sort_custom(func(p, q): return p[0] > q[0])
	print("[audit] %d meshes without collision and larger than 0.5 m" % rows.size())
	for i in mini(rows.size(), 80):
		var bb2: AABB = rows[i][2]
		print("[audit] vol=%.1f size=%s at %s  %s" % [rows[i][0], bb2.size.snappedf(0.1), bb2.get_center().snappedf(1.0), rows[i][1]])
	get_tree().quit(0)


# --- screenshot capture (needs a rendering backend, e.g. xvfb + software GL) ------------

func _run_capture_farm(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	player.global_position = Farm.start_position(terrain)
	for i in 30:
		await get_tree().physics_frame
	story.set_flag("seed_wheat", 20)
	story.set_flag("seed_corn", 20)
	story.set_flag("seed_tomato", 20)
	story.set_flag("seed_cotton", 20)
	var cr := ["wheat", "corn", "tomato", "cotton", "wheat", "corn"]
	for i in 6:
		farm.plant(i, cr[i])
	farm.water(1)
	farm.water(2)
	for i in [3, 4, 5]:
		farm.water(i)
		farm.plots[i]["ends"] = farm.now() - 1.0
		farm._advance_plot(i)
		farm.water(i)
		farm.plots[i]["ends"] = farm.now() - 1.0
		farm._advance_plot(i)
	story.set_flag("sap_mango", 2)
	story.set_flag("sap_neem", 1)
	farm.plant_tree(0, "mango")
	farm.plant_tree(1, "neem")
	farm.plant_tree(2, "mango")
	farm.spots[0]["planted"] = farm.now() - 200.0
	farm.spots[0]["fruit_at"] = farm.now() - 1.0
	farm.spots[1]["planted"] = farm.now() - 80.0
	farm._refresh_spot(0)
	farm._refresh_spot(1)
	player.set_distance(7.5)
	player.set_look(0.0, -0.18)
	for i in 40:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] farm_front -> ", get_viewport().get_texture().get_image().save_png("%s/farm_front.png" % dir))
	player.set_look(-1.1, -0.15)
	for i in 20:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] farm_orchard -> ", get_viewport().get_texture().get_image().save_png("%s/farm_orchard.png" % dir))
	player.set_look(PI, -0.12)
	for i in 20:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] farm_house -> ", get_viewport().get_texture().get_image().save_png("%s/farm_house.png" % dir))
	farm.open_market()
	for i in 6:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] shop -> ", get_viewport().get_texture().get_image().save_png("%s/shop.png" % dir))
	get_tree().quit()


func _run_capture_pickups(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 30:
		await get_tree().physics_frame
	player.set_distance(2.6)
	player.set_look(0.0, 0.05)
	player._model.visible = false
	var pp := player.global_position
	var kinds := ["health", "speed", "power", "shield"]
	for i in 4:
		var px := pp.x + (i - 1.5) * 0.9
		var pz := pp.z - 2.4
		var pk := Pickup.new().setup(kinds[i], player, Vector3(px, terrain.sample_height(px, pz), pz))
		add_child(pk)
		pk.set_process(false)
		pk._mesh.rotation.y = 0.5
		pk._mesh.position.y = 1.0
	for i in 50:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] pickups -> ", get_viewport().get_texture().get_image().save_png("%s/pickups.png" % dir))
	var pk2 := Pickup.new().setup("health", player, player.global_position + Vector3(0, 0, -0.5))
	add_child(pk2)
	for i in 3:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] collect -> ", get_viewport().get_texture().get_image().save_png("%s/collect.png" % dir))
	get_tree().quit()


## Pose lab: eight copies of the player rig in a row, each held in a pose given by the LAB_POSES variants below,
## shot from the front and from the side. Used to check animation poses against reference sheets.
func _run_capture_lab(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 30:
		await get_tree().physics_frame
	player.set_distance(4.6)
	player.set_look(0.0, -0.02)
	player._model.visible = false
	player.set_physics_process(false)
	var pp := player.global_position
	var variants: Array = RealHuman.lab_variants()
	var rigs: Array[RealHuman] = []
	for i in variants.size():
		var r := RealHuman.new().setup(player._rig.preset.duplicate(), "Lab%d" % i)
		add_child(r)
		r.global_position = pp + Vector3(-2.1 + i * 1.4, 0.0, 0.0)
		rigs.append(r)
	for view in ["front", "side"]:
		for i in rigs.size():
			rigs[i].rotation.y = PI * (1.0 if view == "front" else 0.5)
			for k in RealHuman.BONES:
				rigs[i]._pose[k] = Vector3.ZERO
			rigs[i]._hips_dy = 0.0
			var v: Dictionary = variants[i]
			for k in v:
				if k == "dy":
					rigs[i]._hips_dy = float(v[k])
				else:
					rigs[i]._pose[k] = v[k]
			rigs[i]._apply()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] lab_", view, " -> ", get_viewport().get_texture().get_image().save_png("%s/lab_%s.png" % [dir, view]))
	get_tree().quit()


## Gait filmstrip: seven rigs side by side, each frozen at the next eighth of one stride (heel strike first),
## seen from the side; one picture for walking and one for running (GAIT_SPEEDS overrides "1.5,5.5").
func _run_capture_gait(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	for c in get_children():
		if c is TitleScreen:
			c.queue_free()
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var base := _flat_spot()
	_teleport(base.x, base.y)
	for i in 30:
		await get_tree().physics_frame
	player._model.visible = false
	player.set_physics_process(false)
	player.set_process(false)
	var pp := player.global_position
	var rigs: Array[RealHuman] = []
	for i in 7:
		var r := RealHuman.new().setup(player._rig.preset.duplicate(), "Gait%d" % i)
		add_child(r)
		r.global_position = Vector3(pp.x - 4.8 + i * 1.6, terrain.sample_height(pp.x - 4.8 + i * 1.6, pp.z), pp.z)
		r.rotation.y = -PI * 0.5
		r.set_process(false)
		rigs.append(r)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 42.0
	cam.global_position = pp + Vector3(0.0, 1.0, 12.0)
	cam.look_at(pp + Vector3(0, 0.9, 0))
	cam.current = true
	if OS.get_environment("GAIT_PROBE") != "":
		var r0: RealHuman = rigs[0]
		var fwd := -r0.global_transform.basis.z
		var sk: Skeleton3D = r0._skins[0]
		var ball := -1
		for bi in sk.get_bone_count():
			if sk.get_bone_parent(bi) == sk.find_bone("foot_l"):
				ball = bi
				print("[gait] foot child: ", sk.get_bone_name(bi))
		for test in [["hip_L", Vector3(0.5, 0, 0), "an_L"], ["sh_L", Vector3(-0.5, 0, 0), "wr_L"], ["kn_L", Vector3(-0.8, 0, 0), "an_L"], ["el_L", Vector3(1.0, 0, 0), "wr_L"], ["spine", Vector3(-0.3, 0, 0), "head"], ["hips", Vector3(0, 0.3, 0), "hip_L"]]:
			for k in RealHuman.BONES:
				r0._pose[k] = Vector3.ZERO
			r0._hips_dy = 0.0
			r0._apply()
			var a0: Vector3 = r0._bone_pos(test[2]) - r0._bone_pos("hips")
			r0._pose[test[0]] = test[1]
			r0._apply()
			var a1: Vector3 = r0._bone_pos(test[2]) - r0._bone_pos("hips")
			print("[gait] %s %s -> %s moves fwd %.2f up %.2f" % [test[0], str(test[1]), test[2], (a1 - a0).dot(fwd), a1.y - a0.y])
		for k in RealHuman.BONES:
			r0._pose[k] = Vector3.ZERO
		r0._apply()
		var b0 := (sk.global_transform * sk.get_bone_global_pose(ball).origin) - r0._bone_pos("an_L")
		r0._pose["an_L"] = Vector3(0.4, 0, 0)
		r0._apply()
		var b1 := (sk.global_transform * sk.get_bone_global_pose(ball).origin) - r0._bone_pos("an_L")
		print("[gait] an_L +0.4: toe height %.3f -> %.3f (ball bone %d)" % [b0.y, b1.y, ball])
		get_tree().quit()
		return
	var speeds := (OS.get_environment("GAIT_SPEEDS") if OS.get_environment("GAIT_SPEEDS") != "" else "1.5,5.5").split(",")
	for sp in speeds:
		for i in rigs.size():
			var r: RealHuman = rigs[i]
			r.mode = "locomotion"
			r._speed_smooth = float(sp)
			r._air = 0.0
			r.air_vy = 0.0
			r._phase = fmod(RealHuman.GAIT_HEEL + TAU * i / 8.0, TAU)
			r._locomotion(0.0)
			r._apply()
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] gait ", sp, " -> ", get_viewport().get_texture().get_image().save_png("%s/gait_%s.png" % [dir, sp]))
	get_tree().quit()


## Close-up of hands for checking the finger curl axis: rigs with arms held forward, one shot per axis.
func _run_capture_fist(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 30:
		await get_tree().physics_frame
	player.set_distance(2.2)
	player.set_look(0.0, -0.05)
	player._model.visible = false
	player.set_physics_process(false)
	var pp := player.global_position
	var presets: Array = [player._rig.preset.duplicate(), {"body": "brute", "robe": false}]
	var rigs: Array[RealHuman] = []
	for i in presets.size():
		var r := RealHuman.new().setup(presets[i], "Fist%d" % i)
		add_child(r)
		r.global_position = pp + Vector3(-0.5 + i * 1.0, 0.0, -0.4)
		r.rotation.y = PI * 0.5
		r.set_process(false)
		rigs.append(r)
	var axes := [[Vector3.RIGHT, 1.0], [Vector3.BACK, 1.0], [Vector3.BACK, -1.0], [Vector3.UP, 1.0]]
	hud.visible = false
	map_ui.visible = false
	for ai in axes.size():
		RealHuman.fist_axis = axes[ai][0]
		RealHuman.fist_sign = axes[ai][1]
		for r in rigs:
			for k in RealHuman.BONES:
				r._pose[k] = Vector3.ZERO
			r._pose["sh_L"] = Vector3(-1.5, 0, 0)
			r._pose["sh_R"] = Vector3(-1.5, 0, 0)
			r.fist = 1.0
			r._apply()
		for ri in rigs.size():
			var r: RealHuman = rigs[ri]
			var sk: Skeleton3D = r._skins[0]
			var hb: int = r._bone_idx[0]["wr_R"]
			var hp := sk.global_transform * sk.get_bone_global_pose(hb).origin
			for vi in 2:
				var cam := Camera3D.new()
				add_child(cam)
				cam.fov = 30.0
				var fwd := -r.global_transform.basis.z
				var tgt := hp + fwd * 0.09
				var off := Vector3(0.0, 0.42, 0.0) if vi == 0 else Vector3(0.0, 0.0, 0.42)
				cam.global_position = tgt + off
				cam.look_at(tgt, fwd if vi == 0 else Vector3.UP)
				cam.current = true
				for i in 6:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/fist_%d_r%d_v%d.png" % [dir, ai, ri, vi])
				cam.queue_free()
	get_tree().quit()


func _run_capture_fight(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 30:
		await get_tree().physics_frame
	player.set_distance(4.2)
	player.set_look(0.0, -0.1)                  # side view
	var pp := player.global_position
	var foe := combat.spawn_enemy(pp + Vector3(-1.5, 0.3, 0.0), false, 0.0, "test")
	foe.rotation.y = -PI * 0.5
	foe.set_physics_process(false)
	foe.hp = 99999.0
	foe.max_hp = 99999.0
	player._model.rotation.y = PI * 0.5 * 1.0 + PI * 0.5 + PI * 0.5 - PI * 0.5
	player._model.rotation.y = atan2(1.0, 0.0)
	player.set_physics_process(false)
	player._model.rotation.y = atan2(1.0, 0.0) + (float(OS.get_environment("YAW")) if OS.get_environment("YAW") != "" else 0.0)
	for i in 10:
		await get_tree().physics_frame
		player._rig.animate(1.0 / 60.0, 0.0, true)
	player._rig.guard = true
	for i in 20:
		await get_tree().physics_frame
		player._rig.animate(1.0 / 60.0, 0.0, true)
	await RenderingServer.frame_post_draw
	print("[capture] guard -> ", get_viewport().get_texture().get_image().save_png("%s/m_guard.png" % dir))
	player._rig.guard = false
	var shots := [["jab", 9], ["cross", 10], ["hook", 11], ["uppercut", 13], ["kick_front", 18], ["kick_round", 20], ["kick_side", 18], ["roll", 16], ["grab", 22], ["lift", 24], ["throw", 6]]
	for sh in shots:
		player._rig.play_move(sh[0])
		for i in int(sh[1]):
			await get_tree().physics_frame
			player._rig.animate(1.0 / 60.0, 0.0, true)
		await RenderingServer.frame_post_draw
		print("[capture] ", sh[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/m_%s.png" % [dir, sh[0]]))
		for i in 40:
			await get_tree().physics_frame
			player._rig.animate(1.0 / 60.0, 0.0, true)
	for hk in ["head", "body", "gut"]:
		foe.rig.set_react("")
		foe.rig.play_hit(hk, 1.0)
		for i in 7:
			await get_tree().physics_frame
			foe.rig.animate(1.0 / 60.0, 0.0, true)
		await RenderingServer.frame_post_draw
		print("[capture] hit_", hk, " -> ", get_viewport().get_texture().get_image().save_png("%s/h_%s.png" % [dir, hk]))
		for i in 40:
			await get_tree().physics_frame
			foe.rig.animate(1.0 / 60.0, 0.0, true)
	for r in ["flinch", "stagger", "plead", "sob", "held", "clutch", "dead"]:
		foe.rig.set_react(r)
		for i in 30:
			await get_tree().physics_frame
			foe.rig.animate(1.0 / 60.0, 0.0, true)
		await RenderingServer.frame_post_draw
		print("[capture] ", r, " -> ", get_viewport().get_texture().get_image().save_png("%s/r_%s.png" % [dir, r]))
	get_tree().quit()


func _selftest_animal_acts(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var total := 0
	for sp in Animal.ACTS.keys():
		var a := Animal.new().setup(sp, terrain, player, Vector3.ZERO, 6.0)
		add_child(a)
		var px := TerrainBuilder.POND_C.x + 24.0
		var pz := TerrainBuilder.POND_C.y
		a.global_position = Vector3(px, terrain.sample_height(px, pz), pz)
		a.home = a.global_position
		var kinds := {}
		var drank := false
		for k in 60:
			a._act = {}
			if not a._start_act():
				continue
			kinds[str(a._act["n"])] = true
			if str(a._act["n"]) == "drink":
				drank = true
			var steps := 0
			while not a._act.is_empty() and steps < 900:
				a._act_step(0.1)
				steps += 1
			if steps >= 900:
				fails.append("animals: %s activity %s never finished" % [sp, a._act.get("n", "?")])
				break
			if not a.global_position.is_finite():
				fails.append("animals: %s position became NaN" % sp)
				break
		if kinds.size() < 3:
			fails.append("animals: %s only did %s" % [sp, ", ".join(kinds.keys())])
		if Animal.ACTS[sp].any(func(e: Array) -> bool: return e[0] == "drink") and not drank:
			fails.append("animals: %s never drank at the pond" % sp)
		total += kinds.size()
		a.queue_free()
	notes.append("animals: %d species, %d distinct activities seen" % [Animal.ACTS.size(), total])


func _selftest_farm(fails: PackedStringArray) -> void:
	if farm == null or coin_sys == null:
		fails.append("farm: systems missing")
		return
	await get_tree().physics_frame
	var sp := Farm.start_position(terrain)
	if Vector2(sp.x - TerrainBuilder.FARM_C.x, sp.z - TerrainBuilder.FARM_C.y).length() > 20.0:
		fails.append("farm: start is not at the farm")
	if farm.plots.size() != 6 or farm.spots.size() != Farm.ORCHARD_SPOTS:
		fails.append("farm: plots %d spots %d" % [farm.plots.size(), farm.spots.size()])
		return
	if coin_sys.coins.size() < 20:
		fails.append("coins: only %d world coins" % coin_sys.coins.size())
	else:
		var b0 := coin_sys.balance()
		coin_sys.collect(0)
		if coin_sys.balance() <= b0:
			fails.append("coins: collecting gave nothing")
	story.set_flag("seed_wheat", 5)
	if not farm.plant(0, "wheat") or farm.plots[0]["state"] != "dry":
		fails.append("farm: could not plant")
	if not farm.water(0) or farm.plots[0]["state"] != "grow":
		fails.append("farm: could not water")
	for stage_i in 2:
		farm.plots[0]["ends"] = farm.now() - 1.0
		farm._advance_plot(0)
		if stage_i == 0:
			if farm.plots[0]["state"] != "dry":
				fails.append("farm: stage 1 did not need water (%s)" % farm.plots[0]["state"])
			farm.water(0)
	if farm.plots[0]["state"] != "ready":
		fails.append("farm: crop never ripened (%s)" % farm.plots[0]["state"])
	# drive the tractor onto the ripe plot: it harvests
	farm.mount_tractor()
	if not farm.driving:
		fails.append("farm: tractor did not start")
	farm._dismount_cd = 0.0
	farm.tractor.global_position = farm.plots[0]["pos"]
	farm._physics_process(0.016)
	if farm.plots[0]["state"] != "empty" or int(story.get_flag("crop_wheat", 0)) < 4:
		fails.append("farm: tractor did not harvest")
	farm.dismount_tractor()
	if farm.driving or player.locked:
		fails.append("farm: tractor did not release the player")
	var c0 := coin_sys.balance()
	if farm.sell("wheat") <= 0 or coin_sys.balance() <= c0:
		fails.append("farm: selling crops gave no coins")
	if farm._market_rows().size() < 15:
		fails.append("farm: market list is short")
	story.set_flag("sap_mango", 1)
	if not farm.plant_tree(0, "mango"):
		fails.append("farm: could not plant a sapling")
	farm.spots[0]["planted"] = farm.now() - 200.0
	farm.spots[0]["fruit_at"] = farm.now() - 1.0
	farm._refresh_spot(0)
	farm._use_spot(0)
	if int(story.get_flag("fruit_mango", 0)) < 3:
		fails.append("farm: no mangoes picked")
	farm.fell_tree(0)
	if int(story.get_flag("timber", 0)) < 2 or farm.spots[0]["kind"] != "":
		fails.append("farm: felling a tree failed")
	story.set_flag("crop_corn", 6)
	var c1 := coin_sys.balance()
	farm.enter_contest()
	if coin_sys.balance() <= c1:
		fails.append("farm: contest paid nothing")
	story.set_flag("beehive", true)
	story.set_flag("hive_honey", 2)
	if farm.collect_honey() != 2:
		fails.append("farm: honey not collected")
	farm.reload()
	coin_sys.reload()
	# connections: wanted status closes the market, farm is always a travel stop, start is at the farm
	player.wanted_t = 30.0
	farm.open_market()
	if farm.shop.is_open():
		fails.append("farm: market opened for a wanted player")
	player.wanted_t = 0.0
	if not shrines.is_lit("farm"):
		fails.append("farm: not a fast-travel stop")
	# bounty board: accept, count real kills, claim once
	var coins_before := coin_sys.balance()
	story.set_flag("kills", 0)
	if not bounty.accept("slay") or bounty.accept("slay"):
		fails.append("bounty: accept rules")
	if bounty.claim("slay") != 0:
		fails.append("bounty: claimed before goal")
	for k in 5:
		achievements.note_kill("", false)
	if bounty.progress(BountyBoard.JOBS[0]) != 5 or bounty.claim("slay") != 90 or coin_sys.balance() != coins_before + 90:
		fails.append("bounty: claim failed")
	if bounty.state_of("slay") != "off":
		fails.append("bounty: not reposted")
	FloatText.spawn(self, player.global_position, "12")
	if lock_marker == null or diag == null or diag.summary() == "":
		fails.append("lock marker / diag missing")
	# touch ROLL button: a tap on it must start a roll
	player.locked = false
	player.dead = false
	player.stamina = 100.0
	player._roll_cd = 0.0
	touch.visible = true
	if touch._vp.x < 100.0:
		touch._vp = Vector2(1280, 720)
	var tev := InputEventScreenTouch.new()
	tev.index = 7
	tev.pressed = true
	tev.position = touch._roll_button_centre()
	touch._input(tev)
	if player._roll_cd <= 0.0:
		fails.append("touch: ROLL button did not roll (locked=%s mounted=%s)" % [player.locked, player.mounted])
	tev.pressed = false
	touch._input(tev)
	player._roll_cd = 0.0
	print("[selftest] farm: plant, water x2, tractor harvest, sell, orchard, contest, honey ok; %d world coins" % coin_sys.coins.size())


func _selftest_walls(fails: PackedStringArray) -> void:
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(6.0, 4.0, 0.4)
	cs.shape = bx
	wall.add_child(cs)
	wall.position = Vector3(0.0, 40.0, -3.0)
	add_child(wall)
	var walker := Node3D.new()
	add_child(walker)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var prev := Vector3(0.0, 38.5, -2.2)
	walker.global_position = Vector3(0.0, 38.5, -2.2)
	walker.global_position = Vector3(0.0, 38.5, -2.7)
	var blocked := Walls.fix(walker, prev, 0.5)
	if not blocked or walker.global_position.z < -2.25:
		fails.append("walls: walker passed through a wall (z=%.2f)" % walker.global_position.z)
	prev = Vector3(10.0, 38.5, -2.2)
	walker.global_position = Vector3(10.0, 38.5, -2.7)
	if Walls.fix(walker, prev, 0.5):
		fails.append("walls: blocked in open space")
	walker.queue_free()
	wall.queue_free()
	var folks := get_tree().get_nodes_in_group("npcs")
	var villager: Npc = null
	for f in folks:
		var fnpc := f as Npc
		if fnpc != null and not fnpc.companion:
			villager = fnpc
			break
	if villager == null:
		fails.append("hits: no villager found")
	else:
		villager.take_hit(10.0, Vector3.FORWARD)
		if villager._scared_t <= 0.0:
			fails.append("hits: villager did not react")
		villager._scared_t = 0.0
		villager._stun_t = 0.0
		villager.rig.set_react("")
	var cow: Animal = null
	for an in get_tree().get_nodes_in_group("animals"):
		cow = an as Animal
		if cow != null and not cow.dead:
			break
	if cow != null:
		cow.shove(Vector3.FORWARD)
		if cow._flee_t <= 0.0:
			fails.append("hits: animal did not bolt")
		cow._flee_t = 0.0
	# boxing: punches first, then kicks; every move is known to the rig
	var saw_kick := false
	for mv in Player.COMBO:
		if not RealHuman.MOVES.has(mv):
			fails.append("combat: combo move %s missing from the rig" % mv)
		if Player.MOVE_KIND[mv] != "punch":
			saw_kick = true
		elif saw_kick:
			fails.append("combat: punch %s after a kick in the combo" % mv)
	if not saw_kick:
		fails.append("combat: combo has no kick")
	player._rig.play_move("roll")
	if not RealHuman.MOVES.has("roll"):
		fails.append("combat: roll move missing")


## Levels, skills, weapon upgrades, daily challenges, login streak and night raids.
func _selftest_progression(fails: PackedStringArray) -> void:
	var pg := progression
	var lv0 := pg.level()
	var pts0 := pg.points()
	pg.gain(Progression.xp_needed(lv0) + 5, "test")
	if pg.level() != lv0 + 1 or pg.points() != pts0 + 1:
		fails.append("progression: level %d->%d, points %d->%d" % [lv0, pg.level(), pts0, pg.points()])
	var mh := player.max_hp
	if not pg.learn("vitality") or player.max_hp < mh + 14.0:
		fails.append("progression: Vitality did not raise max health (%.0f -> %.0f)" % [mh, player.max_hp])
	story.flags["skill_pts"] = 3
	for i in 3:
		pg.learn("heavy_hands")
	if pg.rank("heavy_hands") != 3 or absf(player.melee_mult - 1.36) > 0.01 or pg.learn("heavy_hands"):
		fails.append("progression: Heavy Hands ranks wrong (%d, %.2f)" % [pg.rank("heavy_hands"), player.melee_mult])
	# upgrades: refused away from the forge, done beside it with materials
	items.give("iron", 10)
	items.give("essence", 5)
	story.flags["coins"] = int(story.get_flag("coins", 0)) + 500
	player.set_weapon("fists")
	if pg.can_upgrade("fists") == "":
		fails.append("progression: upgrade allowed away from the blacksmith")
	var smith: Node3D = null
	for n in npcs:
		if String(n.name) == "Blacksmith":
			smith = n
	if smith != null:
		player.global_position = smith.global_position + Vector3(1.5, 0.3, 0)
		var w0 := player.wpn_up()
		if not pg.upgrade("fists") or player.wpn_up() <= w0:
			fails.append("progression: upgrade at the forge failed (%s)" % pg.can_upgrade("fists"))
	# daily challenges: three different ones, completing one pays
	var ds := pg.dailies()
	var ids := {}
	for d in ds:
		ids[d[0]] = true
	if ds.size() != 3 or ids.size() != 3:
		fails.append("progression: dailies %s" % [ds])
	story.flags["dc_date"] = ""            # start today's challenges from zero (earlier tests already earned coins)
	pg._roll_day()
	var c0 := int(story.get_flag("coins", 0))
	pg.note(String(ds[0][2]), int(ds[0][3]))
	if not bool(story.get_flag("dc_done0", false)) or int(story.get_flag("coins", 0)) < c0 + int(ds[0][4]):
		fails.append("progression: completing a daily paid nothing")
	pg.note(String(ds[1][2]), int(ds[1][3]))
	pg.note(String(ds[2][2]), int(ds[2][3]))
	if not bool(story.get_flag("dc_chest", false)):
		fails.append("progression: no bonus chest after all three dailies")
	# login streak: yesterday -> day 2; a gap -> back to day 1
	var y := Time.get_date_string_from_unix_time((Progression._day_number(Progression.today()) - 1) * 86400 + 43200)   # local yesterday
	story.flags["ls_last"] = y
	story.flags["ls_count"] = 1
	pg.check_login()
	var s2 := pg.streak()
	story.flags["ls_last"] = "2020-01-01"
	pg.check_login()
	if s2 != 2 or pg.streak() != 1:
		fails.append("progression: login streak %d then %d (want 2 then 1)" % [s2, pg.streak()])
	# a night raid can be announced and won
	monsters.raid_now(0)
	var ra: Vector2 = monsters.pending_raid.get("at", Vector2.ZERO)
	if monsters.pending_raid.is_empty():
		fails.append("progression: night raid not announced")
	else:
		var pr := monsters.pending_raid
		monsters.pending_raid = {}
		_teleport(ra.x + 2.0, ra.y + 2.0)
		monsters.start(pr, true)
		var g := 0
		while monsters.running != "" and g < 2000:
			g += 1
			for mon in monsters.alive.duplicate():
				if is_instance_valid(mon) and not (mon as Enemy).dead:
					(mon as Enemy).take_hit("arrow", 40.0, Vector3.FORWARD)
			player.hp = player.max_hp
			await get_tree().physics_frame
		if int(story.get_flag("raids_won", 0)) < 1:
			fails.append("progression: night raid could not be won")
	# wardrobe: buy, wear (armour + bonus), try-on reverts, dye, supplies
	story.flags["coins"] = int(story.get_flag("coins", 0)) + 3000
	var c1 := int(story.get_flag("coins", 0))
	wardrobe.open_shop("dhoop")
	wardrobe.close()
	if not wardrobe.buy("rajput") or wardrobe.worn() != "rajput" or absf(player.outfit_armor - 0.8) > 0.001 or int(story.get_flag("coins", 0)) != c1 - 350:
		fails.append("wardrobe: buying the Rajput set failed (worn %s, armour %.2f)" % [wardrobe.worn(), player.outfit_armor])
	var rig0 := player._rig
	wardrobe.open_shop("dhoop")
	wardrobe._tried = true
	wardrobe.wear("knight", false)
	wardrobe.close()
	if wardrobe.worn() != "rajput" or absf(player.outfit_armor - 0.8) > 0.001:
		fails.append("wardrobe: try-on did not revert")
	await get_tree().process_frame
	if not is_instance_valid(player._rig) or player._rig == rig0 or player._rig._skins.is_empty():
		fails.append("wardrobe: body swap left no working rig")
	wardrobe.buy("ghost_hunter")
	if absf(player.ghost_mult - (1.0 + 0.2 * progression.rank("spirit_bane")) * 1.2) > 0.01:
		fails.append("wardrobe: Ghost Hunter bonus not applied (%.2f)" % player.ghost_mult)
	var c2 := int(story.get_flag("coins", 0))
	if not wardrobe.dye(Color(0.1, 0.5, 0.3)) or int(story.get_flag("coins", 0)) != c2 - Wardrobe.DYE_PRICE:
		fails.append("wardrobe: dye failed")
	var pots := items.count("potion")
	if not wardrobe.buy_supply("potion", 40) or items.count("potion") != pots + 1:
		fails.append("wardrobe: supplies failed")
	print("[selftest] wardrobe: wearing %s, armour %.2f, ghost x%.2f, %d outfits" % [wardrobe.worn(), player.outfit_armor, player.ghost_mult, Wardrobe.OUTFITS.size()])
	print("[selftest] progression: level %d, points %d, streak %d, dailies %s, raids won %d" % [pg.level(), pg.points(), pg.streak(), [ds[0][1], ds[1][1], ds[2][1]], int(story.get_flag("raids_won", 0))])


## Ghost and monster missions: the first one starts, its waves spawn animated models and can be beaten,
## rewards arrive and the next mission unlocks. Also: mission tasks map to body actions, dialogue compaction.
func _selftest_monsters(fails: PackedStringArray) -> void:
	for pair in [["Dig at the stake", "dig"], ["Search the box under the sacks", "search"], ["Light the brazier", "reach"], ["Pray at the altar", "pray"], ["Cut the prisoner free", "cut"], ["Talk to Chief", ""]]:
		if Player.task_for_prompt(pair[0]) != pair[1]:
			fails.append("tasks: '%s' -> '%s' (want '%s')" % [pair[0], Player.task_for_prompt(pair[0]), pair[1]])
	var long_d := {"start": "a", "nodes": {"a": {"who": "X", "text": "One. Two.", "choices": [{"t": "?", "go": "b"}, {"t": "!", "go": "c"}]},
		"b": {"who": "X", "text": "Three. Four.", "set": {"t_flag": true}, "choices": [{"t": "ok", "go": ""}]}, "c": {"who": "X", "text": "Five.", "set": {"t_flag2": true}}}}
	var cd := DialogueUI.compact(long_d)
	var one: Dictionary = (cd["nodes"] as Dictionary).values()[0]
	if (cd["nodes"] as Dictionary).size() != 1 or not (one["set"] as Dictionary).has("t_flag2") or String(one["text"]) != "One. Three.":
		fails.append("dialogue: compaction gave %s" % [cd])
	var shop_d := {"start": "a", "nodes": {"a": {"who": "X", "text": "Buy?", "choices": [{"t": "Yes", "go": "", "cost": 5}]}}}
	if DialogueUI.compact(shop_d) != shop_d:
		fails.append("dialogue: a shop conversation was compacted")
	var m: Dictionary = monsters.available()
	if m.is_empty() or String(m["id"]) != "m_ghost1":
		fails.append("monsters: first mission not available (%s)" % [m])
		return
	var at: Vector2 = m["at"]
	player.locked = false
	_teleport(at.x + 3.0, at.y + 3.0)
	var coins0 := coin_sys.balance()
	monsters.start(m, true)
	await get_tree().physics_frame
	var spawned := monsters.alive.size()
	var animated := 0
	for mon in monsters.alive:
		if (mon as Monster)._anim != null:
			animated += 1
	print("[selftest] monsters: wave 1 spawned %d (%d animated), player weapon %s" % [spawned, animated, player.weapon])
	if spawned != 3:
		fails.append("monsters: wave 1 spawned %d, want 3" % spawned)
	if player.weapon != "bow":
		fails.append("monsters: the bow was not handed over")
	var guard := 0
	while monsters.running != "" and guard < 2000:
		guard += 1
		for mon in monsters.alive.duplicate():
			if is_instance_valid(mon) and not (mon as Enemy).dead:
				(mon as Enemy).take_hit("arrow", 30.0, Vector3.FORWARD)
		player.hp = player.max_hp
		await get_tree().physics_frame
	if not bool(story.get_flag("m_ghost1_done", false)):
		fails.append("monsters: the first mission did not complete (wave %d)" % monsters.wave)
	if coin_sys.balance() <= coins0:
		fails.append("monsters: no coins for the mission")
	var nx: Dictionary = monsters.available()
	if nx.is_empty() or String(nx["id"]) != "m_bones":
		fails.append("monsters: the second mission did not unlock")
	# every monster kind loads and stands up
	for k in Monster.KINDS:
		var t := Monster.new()
		t.player = player
		add_child(t)
		t.setup_monster(k, player.global_position + Vector3(30, 0, 0), "T_" + k)
		if t._anim == null and ResourceLoader.exists("res://assets/monsters/%s.gltf" % Monster.KINDS[k]["file"]):
			fails.append("monsters: %s has no animations" % k)
		t.queue_free()
	print("[selftest] monsters: first mission done=%s, coins +%d, next=%s" % [story.get_flag("m_ghost1_done", false), coin_sys.balance() - coins0, nx.get("id", "")])


## Southern Road: the ground joins the valley without a step, the pass is open, and the stops exist.
func _selftest_frontier(fails: PackedStringArray) -> void:
	var worst := 0.0
	for xi in 40:
		var x := -199.0 + xi * 8.0
		var a := terrain.sample_height(x, 199.95)
		var b := terrain.sample_height(x, 200.05)
		worst = maxf(worst, absf(a - b))
	if worst > 0.35:
		fails.append("frontier: step of %.2f m at the valley seam" % worst)
	# walk up through the pass from the valley side
	player.global_position = Vector3(TerrainBuilder.PASS_X, terrain.sample_height(TerrainBuilder.PASS_X, 172.0) + 0.4, 172.0)
	player.velocity = Vector3.ZERO
	player.locked = false
	player.set_look(PI, -0.1)            # face +z (south)
	for i in 10:
		await get_tree().physics_frame
	player.move_input = Vector2(0, 1)
	player.sprint = true
	for i in 420:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	player.sprint = false
	var pz := player.global_position.z
	print("[selftest] frontier: seam step %.3f m, walked the pass to z=%.1f (y=%.1f)" % [worst, pz, player.global_position.y])
	if pz < 215.0:
		fails.append("frontier: could not walk out through the south pass (stopped at z=%.1f)" % pz)
	var oh := terrain.sample_height(Act4.OUTPOSTS[2].x, Act4.OUTPOSTS[2].y)
	if oh > 30.0 or oh < 10.0:
		fails.append("frontier: third outpost ground at odd height %.1f" % oh)
	var names := []
	for n in npcs:
		names.append(n.name)
	for want in ["SaraiKeeper", "Headman"]:
		if not want in names:
			fails.append("frontier: %s missing" % want)
		elif story.dialogue_for(want).is_empty():
			fails.append("frontier: %s has no dialogue" % want)


func _selftest_night_life(fails: PackedStringArray) -> void:
	if night_life == null or night_life.points.size() < 6:
		fails.append("night life: lamp points missing")
		return
	var keep := atmosphere.time_of_day
	atmosphere.time_of_day = 0.0
	atmosphere.apply_time()
	night_life._process(0.1)
	var lit := 0
	for l in night_life.lights:
		if l.visible and l.light_energy > 0.1:
			lit += 1
	if lit < 1 or not night_life.flies.emitting:
		fails.append("night life: nothing lit at midnight (lit %d)" % lit)
	atmosphere.time_of_day = 0.5
	atmosphere.apply_time()
	night_life._process(0.1)
	if night_life.flies.emitting:
		fails.append("night life: fireflies out at noon")
	atmosphere.time_of_day = keep
	atmosphere.apply_time()


func _selftest_act4(fails: PackedStringArray) -> void:
	var a4: Act4 = campaign.act4
	for k in ["outposts_cleared", "a4_freed", "vikram_met", "siege_won", "vessa_down", "act4_done", "siege_down", "outpost_down"]:
		story.flags.erase(k)
	story.set_flag("act3_done", true)
	if a4.groups.size() != 3 or (a4.groups[0] as Array).size() != 5:
		fails.append("act 4: outposts not spawned")
		return
	for g in a4.groups:
		for e in g:
			(e as Enemy).take_hit("slam", 9999.0, Vector3.FORWARD)
	a4._check_outposts()
	if int(story.get_flag("outposts_cleared", 0)) != 3 or not a4.prisoner_it.enabled:
		fails.append("act 4: outposts/prisoner state wrong")
	a4.free_prisoner(a4.prisoner_it)
	if a4.vikram == null:
		fails.append("act 4: Vikram not spawned after freeing the prisoner")
	story.set_flag("vikram_met", true)
	for w in 3:
		var killed := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if (e as Enemy).get_meta("tag", "") == "siege":
				(e as Enemy).take_hit("slam", 9999.0, Vector3.FORWARD)
				killed += 1
		if killed != Act4.WAVES[w]:
			fails.append("act 4: wave %d had %d men, wanted %d" % [w + 1, killed, Act4.WAVES[w]])
		a4._t = 0.0
		a4._process(0.1)
	if not story.get_flag("siege_won", false) or a4.vessa == null:
		fails.append("act 4: Vessa did not appear after the siege")
	else:
		a4.vessa.take_hit("slam", 99999.0, Vector3.FORWARD)
		if not story.get_flag("act4_done", false):
			fails.append("act 4: Vessa's death did not complete Act 4")


func _selftest_act5(fails: PackedStringArray) -> void:
	var a5: Act5 = campaign.act5
	for k in ["v5_entered", "arin5_met", "pedestals_done", "eclipse_down", "ending_done", "ending", "game_complete", "endings_seen"]:
		story.flags.erase(k)
	story.flags.erase("act4_done")
	if a5.enter():
		fails.append("act 5: entered the vault before Act 4 was done")
	story.set_flag("act4_done", true)
	if not a5.enter() or player.global_position.distance_to(Act5.ORIGIN) > 80.0:
		fails.append("act 5: could not enter the Solar Vault")
	if a5.touch_pedestal(0) or a5.seq.size() != 0:
		fails.append("act 5: wrong pedestal order was accepted")
	if not a5.touch_pedestal(2) or not a5.touch_pedestal(1) or not a5.touch_pedestal(0) or not story.get_flag("pedestals_done", false):
		fails.append("act 5: pedestal puzzle did not solve")
	await get_tree().process_frame
	await get_tree().process_frame
	if a5.guardian == null or not is_instance_valid(a5.guardian):
		fails.append("act 5: Eclipse Guardian did not appear")
		return
	var g: Enemy = a5.guardian
	g.hp = g.max_hp * 0.6
	a5._process(0.1)
	var adds := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).get_meta("tag", "") == "eclipse_add":
			adds += 1
	if a5.stage != 2 or adds != 3:
		fails.append("act 5: stage 2 not reached (stage %d, adds %d)" % [a5.stage, adds])
	g.hp = g.max_hp * 0.3
	a5._process(0.1)
	if a5.stage != 3 or not g.enraged:
		fails.append("act 5: stage 3 / enrage not reached")
	g.take_hit("slam", 99999.0, Vector3.FORWARD)
	if not story.get_flag("eclipse_down", false) or not a5.heart_it.enabled:
		fails.append("act 5: killing the guardian did not unlock the Sun Heart")
	if a5.secret_unlocked():
		fails.append("act 5: secret ending should be locked in a fresh run")
	a5.play_ending("heroic")
	if not cin.playing:
		fails.append("act 5: ending cinematic did not play")
	cin.finish()
	await get_tree().process_frame
	if a5.credits == null or not story.get_flag("game_complete", false) or String(story.get_flag("endings_seen", "")) != "heroic":
		fails.append("act 5: credits / ending bookkeeping wrong")
	if a5.ending_lines("secret").size() != 3 or a5.ending_lines("sacrifice").size() != 3:
		fails.append("act 5: ending texts missing")
	a5.close_credits()
	if player.locked:
		fails.append("act 5: player still locked after the credits")


func _selftest_cin_ground(fails: PackedStringArray) -> void:
	var low := Vector3(20.0, -50.0, 20.0)
	var r: Vector3 = cin._above_ground(low)
	if r.y < terrain.sample_height(20.0, 20.0) + 1.0:
		fails.append("cinematic camera can sink below terrain")


func _selftest_map_route(fails: PackedStringArray, notes: PackedStringArray) -> void:
	# tap the full map: a route target is set, drawn from the player, shown by a beam, and clears on arrival
	map_ui.toggle_full()
	await get_tree().process_frame
	var r := map_ui._full_rect()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = r.position + r.size * Vector2(0.75, 0.30)
	map_ui._on_full_input(ev)
	if not map_ui.has_waypoint or map_ui._beam == null or not map_ui._beam.visible:
		fails.append("map: tapping the map set no route")
	else:
		var u := Vector2(0.75, 0.30)
		var wx := u.x * TerrainBuilder.HALF * 2.0 - TerrainBuilder.HALF
		var wz := u.y * TerrainBuilder.HALF * 2.0 - TerrainBuilder.HALF
		if Vector2(map_ui.waypoint.x - wx, map_ui.waypoint.z - wz).length() > 35.0:
			fails.append("map: route target is not where the tap was")
	await get_tree().process_frame
	map_ui.toggle_full()
	var keep := player.global_position
	player.global_position = Vector3(map_ui.waypoint.x, map_ui.waypoint.y + 0.5, map_ui.waypoint.z)
	await get_tree().process_frame
	await get_tree().process_frame
	if map_ui.has_waypoint:
		fails.append("map: route did not clear on arrival")
	player.global_position = keep
	notes.append("map: route ok")


func _selftest_powerfx(fails: PackedStringArray, notes: PackedStringArray) -> void:
	var fx := player.get_node_or_null("PowerFx") as PowerFx
	if fx == null:
		fails.append("powerfx: missing")
		return
	for k in ["speed", "power", "shield"]:
		player.power[k] = 30.0
	player.powerup_changed.emit()
	for i in 6:
		await get_tree().process_frame
	if not (fx.speed_on and fx.power_on and fx.shield_on):
		fails.append("powerfx: flags not set")
	if fx._light.light_energy < 1.0 or not fx._arcs.visible or not fx._aura.visible or not fx._bubble.visible:
		fails.append("powerfx: effects not visible")
	if fx._arc_mesh.get_surface_count() < 1:
		fails.append("powerfx: no lightning arcs drawn")
	player.power.clear()
	player.powerup_changed.emit()
	for i in 4:
		await get_tree().process_frame
	if fx._arcs.visible or fx._aura.visible or fx._bubble.visible:
		fails.append("powerfx: effects stay on after the power-up ends")
	notes.append("powerfx: ok")


func _selftest_localisation(fails: PackedStringArray, notes: PackedStringArray) -> void:
	# Hindi tables, speaker names and the wordless story cues
	Loc.set_language("hi")
	if Loc.t("Not now.") != "अभी नहीं।":
		fails.append("loc: choice not translated")
	if Loc.name_of("Tara") != "तारा":
		fails.append("loc: speaker name not translated")
	var line := Loc.t("Take your hands off her. Now.")
	if line == "Take your hands off her. Now.":
		fails.append("loc: story line not translated")
	var hindi_clip: AudioStream = Sfx.instance._clip_for("man", Loc.t("Heavy crates, light pay. Mind the dock ramp, friend."))
	notes.append("loc: Hindi clip for a sample line %s" % ("found" if hindi_clip != null else "not rendered yet"))
	Loc.set_language("en")
	if Loc.t("Not now.") != "Not now.":
		fails.append("loc: English not restored")
	for c in ["raid_panic", "battle_cry", "scream", "war_roar", "cheer", "wail", "stampede"]:
		Sfx.cue(c)
	for sname in ["scream_woman_0", "scream_woman_1", "yell_man_0", "yell_man_1", "war_roar", "panic_crowd", "cheer_crowd", "wail_woman", "sob_child", "bull_bellow", "horse_scream", "camel_roar", "groan_man", "laugh_villain"]:
		if not ResourceLoader.exists("res://assets/audio/%s.wav" % sname):
			fails.append("audio: missing %s" % sname)
	# Whispers in the Bazaar
	if bazaar == null:
		fails.append("bazaar: not built")
		return
	story.set_flag("ledger_given", true)
	await get_tree().process_frame
	if bazaar.state != "active" or bazaar.raju == null or bazaar.lal == null:
		fails.append("bazaar: did not activate (state %s)" % bazaar.state)
		return
	story.set_flag("bz_raju", true)
	story.set_flag("bz_lal", true)
	for i in 3:
		await get_tree().process_frame
	if bazaar.enemies.size() != 3 or bazaar.state != "fight":
		fails.append("bazaar: guards not spawned (%d, %s)" % [bazaar.enemies.size(), bazaar.state])
		return
	var cy := terrain.sample_height(bazaar.crate_pos.x, bazaar.crate_pos.z)
	if absf(bazaar.crate_pos.y - cy) > 0.5:
		fails.append("bazaar: crate floats %.2f m" % (bazaar.crate_pos.y - cy))
	story.flags["bazaar_down"] = 3
	story.changed.emit()
	if bazaar.state != "cleared" or not bazaar._crate_it.enabled:
		fails.append("bazaar: crate not unlocked after the fight")
	bazaar._crate_it.on_interact.call(player, bazaar._crate_it)
	if not story.get_flag("bz_receipt"):
		fails.append("bazaar: receipt not found")
	var d: Dictionary = story.dialogue_for("Priest")
	if not str(d["nodes"]["a"]["text"]).begins_with("A receipt"):
		fails.append("bazaar: Rishi has no reward dialogue")
	notes.append("bazaar: quest chain ok")


func _selftest_stampede(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if stampede == null:
		fails.append("stampede: not built")
		return
	story.set_flag("intro_done", true)
	player.global_position = Vector3(TerrainBuilder.TOWN_C.x, terrain.sample_height(TerrainBuilder.TOWN_C.x, TerrainBuilder.TOWN_C.y) + 0.4, TerrainBuilder.TOWN_C.y)
	if stampede._can_start():
		fails.append("stampede: would start inside the bazaar")
	var coins0 := int(story.get_flag("coins", 0))
	var hp0 := player.hp
	player.locked = false
	player.mounted = false
	player.global_position = Vector3(0, terrain.sample_height(0, 60) + 0.4, 60)
	player.velocity = Vector3.ZERO
	stampede.start()
	if stampede.herd.size() != Stampede.HERD.size():
		fails.append("stampede: herd of %d" % stampede.herd.size())
		return
	var hurt := false
	var steps := 0
	while stampede.state != "fight" and steps < 1500:
		stampede.step(0.1)
		steps += 1
		if stampede.state == "run" and not hurt and not stampede.herd.is_empty():
			var h: Animal = stampede.herd[0]
			if h.global_position.distance_to(player.global_position) < 14.0:
				player.global_position = h.global_position + stampede._dir * 1.5
				player._invuln = 0.0
				stampede._hurt_cd = 0.0
				stampede.step(0.05)
				hurt = player.hp < hp0
				if not hurt:
					fails.append("stampede: standing in the herd did no damage")
					break
		if not stampede.herd.is_empty() and not stampede.herd[0].global_position.is_finite():
			fails.append("stampede: herd position NaN")
			break
	if stampede.state != "fight":
		fails.append("stampede: never reached the fight (state %s after %d steps)" % [stampede.state, steps])
		return
	if stampede.raiders.size() != 4:
		fails.append("stampede: %d raiders" % stampede.raiders.size())
	for e in stampede.raiders:
		if is_instance_valid(e):
			e._die("punch", Vector3.ZERO)
	stampede.step(0.1)
	if stampede.state != "done" or not story.get_flag("stampede_done") or int(story.get_flag("coins", 0)) != coins0 + 120:
		fails.append("stampede: reward not given (state %s)" % stampede.state)
	var rideable := 0
	for n in get_children():
		if n is Animal and (n as Animal).species == "horse_white":
			for c in n.get_children():
				if c is Interactable:
					rideable += 1
	if rideable < 1:
		fails.append("stampede: no rideable horse left behind")
	notes.append("stampede: %d steps to the fight, herd of %d, damage %s, reward ok" % [steps, Stampede.HERD.size(), str(hurt)])
	player.hp = player.max_hp
	story.set_flag("stampede_done", false)
	story.flags["coins"] = coins0
	player.global_position = Vector3(TerrainBuilder.START_MOUND.x, terrain.sample_height(TerrainBuilder.START_MOUND.x, TerrainBuilder.START_MOUND.y) + 0.4, TerrainBuilder.START_MOUND.y)


func _run_capture_veyra(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	atmosphere.time_of_day = 0.5
	atmosphere.apply_time()
	var o := Campaign.ORIGIN
	for bi in 3:
		campaign.light_brazier(bi, campaign.brazier_its[bi])
	var shots := [
		["veyra_entry", Vector3(0, 0, 55), Vector3(0, 3.0, 10), -0.05],
		["veyra_mid", Vector3(-4, 0, 20), Vector3(0, 3.0, -30), -0.03],
		["veyra_far", Vector3(0, 0, -20), Vector3(0, 3.0, -55), -0.03],
	]
	for s in shots:
		var sp: Vector3 = s[1] + o
		player.set_distance(4.0)
		player.global_position = sp + Vector3(0, 0.4, 0)
		player.velocity = Vector3.ZERO
		player.locked = true
		_look_at_point(s[2] + o, s[3])
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] ", s[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]]))
	get_tree().quit()


func _run_capture_trees(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.4
	atmosphere.apply_time()
	var fc := TerrainBuilder.FOREST_C
	var shots := [
		["forest_in", Vector3(fc.x + 26.0, 0.0, fc.y + 30.0), Vector3(fc.x, 3.5, fc.y), -0.08],
		["forest_far", Vector3(fc.x + 70.0, 0.0, fc.y + 70.0), Vector3(fc.x, 5.0, fc.y), -0.1],
		["pond_trees", Vector3(-34.0, 0.0, 78.0), Vector3(-70.0, 3.0, 40.0), -0.05],
		["oasis_close", Vector3(-100.0, 0.0, 60.0), Vector3(-130.0, 2.0, 30.0), -0.02],
	]
	for s in shots:
		var sp: Vector3 = s[1]
		player.set_distance(4.0)
		player.global_position = Vector3(sp.x, terrain.sample_height(sp.x, sp.z) + 0.4, sp.z)
		player.velocity = Vector3.ZERO
		player.locked = true
		_look_at_point(s[2], s[3])
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] ", s[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]]))
	get_tree().quit()


func _selftest_traffic(fails: PackedStringArray, notes: PackedStringArray) -> void:
	if traffic == null:
		fails.append("traffic: not built")
		return
	while not traffic.done:
		await get_tree().process_frame
	if traffic.wagons.size() < 4 or traffic.riders.size() < 3 or traffic.walkers.size() < 8:
		fails.append("traffic: %d carts, %d riders, %d walkers" % [traffic.wagons.size(), traffic.riders.size(), traffic.walkers.size()])
	for w in traffic.wagons:
		if w.driver == null or not is_instance_valid(w.driver):
			fails.append("traffic: a cart has no driver")
	# no road may run through a hamlet house (sampled every 2 m, with a 1.5 m margin)
	var roads: Array = []
	for c in TrafficBuilder.CARTS:
		roads.append(c[2])
	for r in TrafficBuilder.RIDERS:
		roads.append(r[2])
	for wk in TrafficBuilder.WALKERS:
		roads.append(wk[1])
	var inside := 0
	for rd in roads:
		for i in (rd as Array).size() - 1:
			var a2: Vector2 = rd[i]
			var b2: Vector2 = rd[i + 1]
			var steps2 := int(a2.distance_to(b2) / 2.0) + 1
			for k in steps2 + 1:
				var q2 := a2.lerp(b2, float(k) / steps2)
				for hs in houses.houses:
					var lp: Vector3 = (hs.node as Node3D).global_transform.affine_inverse() * Vector3(q2.x, (hs.node as Node3D).global_position.y, q2.y)
					var half: Vector2 = hs.half
					if absf(lp.x) < half.x + 1.5 and absf(lp.z) < half.y + 1.5:
						inside += 1
	if inside > 0:
		fails.append("traffic: roads pass through hamlet houses at %d sample points" % inside)
	# put the player in the road ahead of the first cart: it must stop; then move away: it must go on
	var w0: Wagon = traffic.wagons[0]
	var fwd := Vector3(-sin(w0.rotation.y), 0.0, -cos(w0.rotation.y))
	player.global_position = w0.global_position + fwd * 4.0
	var s0 := w0._s
	for i in 10:
		w0._process(0.1)
	if not w0.blocked or absf(w0._s - s0) > 0.01:
		fails.append("traffic: cart did not stop for the player in the road")
	player.global_position = w0.global_position + fwd * 40.0 + Vector3(0, 0, 40)
	for i in 10:
		w0._process(0.1)
	if w0.blocked or w0._s <= s0:
		fails.append("traffic: cart did not resume")
	# everything moves and stays finite over a simulated minute
	var start_r: Array[Vector3] = []
	for t in traffic.riders:
		start_r.append(t.animal.position)
	player.global_position = Vector3(60, terrain.sample_height(60, 20) + 0.4, 20)
	for i in 300:
		for w in traffic.wagons:
			w._process(0.2)
		for t in traffic.riders:
			t._process(0.2)
	for k in traffic.riders.size():
		var t: Traveller = traffic.riders[k]
		if not t.animal.position.is_finite():
			fails.append("traffic: rider %d NaN" % k)
		elif t.animal.position.distance_to(start_r[k]) < 1.0 and t._s == 0.0:
			fails.append("traffic: rider %d never moved" % k)
	for w in traffic.wagons:
		if not w.position.is_finite():
			fails.append("traffic: cart NaN")
	notes.append("traffic: %d carts with drivers, %d riders, %d walkers" % [traffic.wagons.size(), traffic.riders.size(), traffic.walkers.size()])
	player.global_position = Vector3(TerrainBuilder.START_MOUND.x, terrain.sample_height(TerrainBuilder.START_MOUND.x, TerrainBuilder.START_MOUND.y) + 0.4, TerrainBuilder.START_MOUND.y)


func _run_capture_menu(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	await get_tree().process_frame
	menu.toggle()
	var shots := [["inventory", "Inventory", -1], ["audio", "Settings", 0], ["video", "Settings", 1], ["controls", "Settings", 2], ["gameplay", "Settings", 3], ["help", "Help", -1]]
	for s in shots:
		menu._show_page(s[1])
		if int(s[2]) >= 0:
			((menu._pages["Settings"]) as TabContainer).current_tab = int(s[2])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] menu ", s[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [dir, s[0]]))
	get_tree().quit()


func _selftest_settings(fails: PackedStringArray, notes: PackedStringArray) -> void:
	for b in GameSettings.BUSES:
		if AudioServer.get_bus_index(b) < 0:
			fails.append("settings: audio bus %s missing" % b)
	GameSettings.set_value("vol_music", 0.5)
	if absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) > 0.1:
		fails.append("settings: music volume not applied to its bus")
	GameSettings.set_value("difficulty", 2)
	if absf(GameSettings.damage_scale() - 1.5) > 0.01:
		fails.append("settings: hard difficulty scale %.2f" % GameSettings.damage_scale())
	GameSettings.set_value("tracker", false)
	if hud._tracker.visible:
		fails.append("settings: tracker toggle did nothing")
	GameSettings.set_value("lefty", true)
	if not bool(touch.get("left_handed")):
		fails.append("settings: left-handed layout not applied")
	GameSettings.set_value("sens_y", 2.0)
	if absf(player.look_sens_y - 2.0) > 0.01:
		fails.append("settings: vertical look speed not applied")
	GameSettings.set_value("aa", 3)
	if get_viewport().msaa_3d != Viewport.MSAA_4X:
		fails.append("settings: MSAA not applied")
	GameSettings.set_value("brightness", 1.3)
	if absf(atmosphere.environment.adjustment_brightness - 1.3) > 0.01:
		fails.append("settings: brightness not applied")
	player.locked = false
	player._attack_cd = 0.0
	player.attack()
	if player._attack_cd <= 0.0:
		fails.append("controls: the HIT button did nothing outside a race")
	player._attack_cd = 0.0
	# mission checkpoint: written when a mission starts, and Restart mission puts the player back there
	story.set_flag("intro_done", true)
	var cp_pos := player.global_position
	menu._write_checkpoint()
	var cp := SaveSystem.read(GameMenu.CHECKPOINT_PATH)
	if cp.is_empty() or not cp.has("flags") or absf(float((cp["pos"] as Array)[0]) - cp_pos.x) > 0.01:
		fails.append("menu: mission checkpoint was not written")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameMenu.CHECKPOINT_PATH))
	var shown := menu._controls.size()
	if shown != GameSettings.SPEC.size():
		fails.append("settings: menu shows %d of %d options" % [shown, GameSettings.SPEC.size()])
	# values survive a save and reload
	GameSettings.set_value("vol_sfx", 0.35)
	GameSettings.load_file()
	if absf(float(GameSettings.get_v("vol_sfx")) - 0.35) > 0.001:
		fails.append("settings: saved value did not reload")
	GameSettings.reset_tab("")
	GameSettings.apply_all()
	notes.append("settings: %d options in %d tabs, 5 audio buses, save/reload ok" % [GameSettings.SPEC.size(), GameSettings.TABS.size()])


func _run_capture_ride(arg: String) -> void:
	var parts := arg.split("|")
	var dir := parts[0]
	var only: String = parts[1] if parts.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var seen := {}
	for l in life:
		var an := l as Animal
		if an == null or not MountSystem.RIDEABLE.has(an.species) or seen.has(an.species) or (only != "" and an.species != only):
			continue
		seen[an.species] = true
		an.driven = true
		var p := an.global_position + Vector3(2.0, 0.0, 0.0)
		player.global_position = Vector3(p.x, terrain.sample_height(p.x, p.z) + 0.4, p.z)
		player.locked = false
		mounts.mount_animal(an)
		for i in 40:
			await get_tree().process_frame
		player.set_distance(6.0)
		for view in ([["side", PI * 0.5]] if only != "" else [["side", PI * 0.5], ["back", 0.0]]):
			player.set_look(mounts._heading + float(view[1]), -0.05)
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			print("[capture] ", an.species, view[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, an.species, view[0]]))
		mounts.dismount()
	get_tree().quit()


## Save transfer: a backup code round-trips, damaged codes are refused, and restoring keeps the old save.
func _selftest_transfer(fails: PackedStringArray) -> void:
	menu.save()
	if not story.get_flag("intro_done"):
		story.set_flag("intro_done", true)
		menu.save()
	var code := SaveTransfer.pack()
	var d := SaveTransfer.unpack(code)
	var note := "code %d chars" % code.length()
	if code == "" or d.is_empty():
		fails.append("transfer: backup code did not round-trip (%s)" % note)
		return
	if int((d["save"]["flags"] as Dictionary).get("coins", -1)) != int(story.get_flag("coins", 0)):
		fails.append("transfer: coins changed in the backup")
	var broken := code.substr(0, code.length() - 12) + "AAAAAAAAAAAA"
	if not SaveTransfer.unpack(broken).is_empty() or not SaveTransfer.unpack("hello").is_empty():
		fails.append("transfer: a damaged code was accepted")
	var p := SaveTransfer.export_now()
	note += ", file %s" % (p != "" and FileAccess.file_exists(p))
	if p == "" or SaveTransfer.unpack(FileAccess.get_file_as_string(p)).is_empty():
		fails.append("transfer: export file missing or unreadable")
	if SaveTransfer.import_from(code) != "" or not FileAccess.file_exists(SaveTransfer.BEFORE):
		fails.append("transfer: import did not keep the previous save")
	if p != "" and p.begins_with("/"):
		DirAccess.remove_absolute(p)
	print("[selftest] transfer: " + note)


## Seasons and dust storms: month table, how often each season brings rain or dust, a storm building up.
func _selftest_seasons(fails: PackedStringArray) -> void:
	var months := {1: "shishir", 3: "vasant", 5: "grishma", 8: "varsha", 11: "sharad", 12: "shishir"}
	for mo in months:
		if Atmosphere.season_for_month(mo) != String(months[mo]):
			fails.append("weather: month %d should be %s" % [mo, months[mo]])
	var a := atmosphere
	var keep := [a.season, a.rain, a.rain_target, a.dust, a.dust_target, a._weather_t, a._story_t, a.story_weather]
	a._story_t = 0.0
	a.story_weather = ""
	var notes: Array = []
	for sn in ["varsha", "grishma", "shishir"]:
		a.season = sn
		var rains := 0
		var dusts := 0
		for i in 300:
			a.rain_target = 0.0
			a.dust_target = 0.0
			a._weather_t = 0.0
			a._update_weather(0.0)
			if a.rain_target > 0.5:
				rains += 1
			elif a.dust_target > 0.5:
				dusts += 1
		notes.append("%s rain %d%% dust %d%%" % [sn, rains / 3, dusts / 3])
		if sn == "varsha" and rains < 210:
			fails.append("weather: the monsoon should mostly bring rain (%d/300)" % rains)
		if sn == "grishma" and dusts < 100:
			fails.append("weather: summer should often bring dust storms (%d/300)" % dusts)
		if sn == "shishir" and rains > 90:
			fails.append("weather: winter should be mostly dry (%d/300)" % rains)
	# a dust storm rolls in
	a.season = "grishma"
	a.rain = 0.0
	a.rain_target = 0.0
	var fog0 := a.environment.fog_density
	a.set_weather("dust", 60.0)
	for i in 25:
		a._update_weather(0.5)
	a.apply_time()
	notes.append("dust %.2f fog %.4f -> %.4f particles %s" % [a.dust, fog0, a.environment.fog_density, a._dust_p.emitting])
	if a.dust < 0.9 or a.environment.fog_density <= fog0 * 2.0 or not a._dust_p.emitting:
		fails.append("weather: dust storm did not build (" + notes[-1] + ")")
	a.season = "varsha"
	a.set_weather("clear", 1.0)
	for i in 25:
		a._update_weather(0.5)
	a.apply_time()
	var land: Color = a.terrain_mat.albedo_color if a.terrain_mat != null else Color.WHITE
	notes.append("monsoon land %s" % str(land))
	if a.terrain_mat != null and not (land.g > land.r):
		fails.append("weather: monsoon land should be greener")
	a.season = keep[0]
	a.rain = keep[1]
	a.rain_target = keep[2]
	a.dust = keep[3]
	a.dust_target = keep[4]
	a._weather_t = keep[5]
	a._story_t = keep[6]
	a.story_weather = keep[7]
	a._update_weather(0.0)
	a.apply_time()
	print("[selftest] weather: " + ", ".join(notes))


## Photo studio: poses hold, filters and light switch, a photo is saved, and everything is put back.
func _selftest_photo(fails: PackedStringArray) -> void:
	var tod0 := atmosphere.time_of_day
	var w0 := player.weapon
	photo_mode.enter()
	var notes: Array = []
	for i in PhotoMode.POSES.size():
		photo_mode.set_pose(i)
		for k in 40:
			await get_tree().physics_frame
		var r := player._rig
		var ok := true
		match PhotoMode.POSES[i]:
			"Archer":
				ok = r.move == "bow_shot" and r.move_t >= 0.58 and r.weapon == "bow"
			"Kick", "Punch":
				ok = r.move != "" and r.move_hold >= 0.0 and r.move_t >= r.move_hold - 0.01
			"Pray":
				ok = r.action == "pray"
			"Victory", "Fighter":
				ok = not r.photo_pose.is_empty()
		if not ok:
			fails.append("photo: pose %s did not hold" % PhotoMode.POSES[i])
	photo_mode.next_filter()
	photo_mode.next_time()
	var lit := atmosphere.time_of_day
	if DisplayServer.get_name() != "headless":          # no frames are drawn headless: saving is checked in the captures
		var path: String = await photo_mode.capture()
		notes.append("saved %s" % (path != "" and FileAccess.file_exists(path)))
		if path == "":
			fails.append("photo: capture did not save")
		elif path.begins_with("/"):
			DirAccess.remove_absolute(path)
	photo_mode.exit()
	for k in 5:
		await get_tree().physics_frame
	if player.locked or not player._rig.photo_pose.is_empty() or player._rig.move_hold >= 0.0 or player.weapon != w0 or absf(atmosphere.time_of_day - tod0) > 0.02:
		fails.append("photo: exit did not restore the player and the light")
	notes.append("light %.2f -> back %.2f" % [lit, atmosphere.time_of_day])
	print("[selftest] photo: " + ", ".join(notes))


## Hindi: sample lines through the translator, and every name and description in the newer data tables.
func _selftest_hindi(fails: PackedStringArray) -> void:
	var was := Loc.lang
	Loc.set_language("hi")
	var checks := [
		[Loc.tf("Go to %s", ["the village graveyard"]), "गाँव का कब्रिस्तान जाओ"],
		[Loc.t("Wave 2/3: 4 left"), "लहर 2/3: 4 बचे"],
		[Loc.t("Lv 3   HEALTH  80 / 100"), "स्तर 3   सेहत  80 / 100"],
		[Loc.t("Defeat 12 enemies or monsters"), "12 दुश्मन या राक्षस हराओ"],
		[Loc.tf("You whistle. Your %s is coming!", ["horse"]), "तुमने सीटी बजाई। तुम्हारा घोड़ा आ रहा है!"],
		[Loc.t("JUMP"), "कूदो"],
	]
	for c in checks:
		if String(c[0]) != String(c[1]):
			fails.append("hindi: got '%s', want '%s'" % [c[0], c[1]])
	var missing: Array = []
	var texts: Array = []
	for m in MonsterMissions.MISSIONS:
		texts.append_array([m["title"], m["short"], m["place"]])
		if String(m["line"]) != "":
			texts.append(m["line"])
	for o in Wardrobe.OUTFITS:
		texts.append_array([o["name"], o["desc"]])
	for id in Progression.SKILLS:
		texts.append_array([Progression.SKILLS[id]["name"], Progression.SKILLS[id]["desc"]])
	for id in Items.DEFS:
		texts.append_array([Items.DEFS[id]["name"], Items.DEFS[id]["desc"]])
	for id in Achievements.DEFS:
		texts.append_array(Achievements.DEFS[id])
	for id in BossBrain.NAMES:
		texts.append(BossBrain.NAMES[id])
	for id in LiveEvents.EVENTS:
		var e: Dictionary = LiveEvents.EVENTS[id]
		texts.append_array([e["name"], e["title"], e["task"], e["intro"]])
	for tx in texts:
		if Loc.t(String(tx)) == String(tx):
			missing.append(tx)
	Loc.set_language(was)
	print("[selftest] hindi: %d table texts checked, %d untranslated" % [texts.size(), missing.size()])
	if not missing.is_empty():
		fails.append("hindi: untranslated %s" % str(missing.slice(0, 8)))


## Real-calendar festivals: the date table, and each festival's task through to its reward.
func _selftest_events(fails: PackedStringArray) -> void:
	var dates := {"2026-11-08": "diwali", "2026-11-05": "diwali", "2026-11-13": "", "2027-03-22": "holi", "2027-01-14": "sankranti",
		"2028-01-15": "sankranti", "2026-10-15": "dussehra", "2026-12-01": "", "2027-10-29": "diwali"}
	for dk in dates:
		if LiveEvents.event_for_date(dk) != String(dates[dk]):
			fails.append("events: %s should be '%s', got '%s'" % [dk, dates[dk], LiveEvents.event_for_date(dk)])
	var notes: Array = []
	for id in ["diwali", "holi", "sankranti", "dussehra"]:
		var le := LiveEvents.new()
		le.main = self
		le.story = story
		le.player = player
		le.terrain = terrain
		le.hud = hud
		le.festival = festival
		add_child(le)
		le.year = 2099
		le.start(id)
		for i in 5:
			await get_tree().physics_frame
		match id:
			"diwali":
				for d in le._targets:
					le.light_diya(d, null)
			"holi":
				for n in le._targets.duplicate():
					le.colour(n, null)
			"sankranti":
				# one real arrow at a kite, the rest directly
				var k: Node3D = le._targets[0]
				_teleport(LiveEvents.C.x, LiveEvents.C.z)
				var ar := Arrow.new()
				add_child(ar)
				ar.launch(Transform3D(Basis(), k.global_position + Vector3(0, -6.0, 8.0)), k.global_position, null, 10.0, player)
				for i in 40:
					await get_tree().physics_frame
				notes.append("kite shot down by an arrow %s" % (le.progress() >= 1))
				if le.progress() < 1:
					fails.append("events: an arrow did not bring down a kite")
				for t in le._targets:
					le.arrow_hit(t, false)
			"dussehra":
				var ef: Node3D = le._targets[0]
				le.arrow_hit(ef, false)
				if le.progress() != 0:
					fails.append("events: an ordinary arrow burned the effigy")
				for i in 3:
					var ar2 := Arrow.new()
					add_child(ar2)
					ar2.fire = true
					var ep: Vector3 = ef.global_position + Vector3(0, 4.8, 0)
					ar2.launch(Transform3D(Basis(), ep + Vector3(0, 0.5, 9.0)), ep, null, 10.0, player)
					for j in 30:
						await get_tree().physics_frame
		var oid: String = String(LiveEvents.EVENTS[id]["outfit"])
		notes.append("%s %d/%d done %s outfit %s" % [id, le.progress(), le.goal(), le.done(), bool(story.get_flag("own_" + oid, false))])
		if not le.done() or not bool(story.get_flag("own_" + oid, false)):
			fails.append("events: %s task did not complete with its outfit (%s)" % [id, notes[-1]])
		var qid: String = "event_" + String(id)
		story.quests = story.quests.filter(func(q: Dictionary) -> bool: return String(q["id"]) != qid)
		festival.force_kind = ""
		le.queue_free()
	print("[selftest] events: " + ", ".join(notes))


## Crafting: monster materials, the new recipes, drinking tonics and wards, and spirit arrows on a ghost.
func _selftest_crafting(fails: PackedStringArray) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gd0 := items.count("ghost_dust")
	var bn0 := items.count("bone")
	for i in 12:
		items.loot("ghost", rng)
		items.loot("skeleton", rng)
	if items.count("ghost_dust") <= gd0 or items.count("bone") <= bn0:
		fails.append("crafting: ghosts and skeletons did not drop dust and bones")
	items.give("feather", 2)
	items.give("herb", 6)
	items.give("essence", 1)
	items.give("ghost_dust", 3)
	items.give("bone", 1)
	var made: Array = []
	for rid in ["spirit_arrow", "tonic", "elixir", "ward"]:
		if items.craft(rid):
			made.append(rid)
	if made.size() != 4 or items.count("spirit_arrow") < 5:
		fails.append("crafting: could not craft all new recipes (made %s)" % str(made))
	for i in 80:
		await get_tree().physics_frame
	player.stamina = 10.0
	items.use("tonic")
	items.use("ward")
	if player.stamina < 99.0 or not player.power.has("tonic") or not player.power.has("ward"):
		fails.append("crafting: tonic or ward had no effect")
	# the ward halves a ghost's blow
	player.hp = 100.0
	player._invuln = 0.0
	player._hurt_by_spirit = true
	player.take_damage(20.0, Vector3.FORWARD)
	player._hurt_by_spirit = false
	var warded := 100.0 - player.hp
	player.hp = 100.0
	player._invuln = 0.0
	player.take_damage(20.0, Vector3.FORWARD)
	var plain := 100.0 - player.hp
	if warded <= 0.0 or warded > plain * 0.6:
		fails.append("crafting: ghost ward did not halve spirit damage (%.1f vs %.1f)" % [warded, plain])
	player.power.clear()
	player.hp = player.max_hp
	# a spirit arrow at a ghost does three times an ordinary arrow
	var hurt: Array = []
	for sp in [false, true]:
		var g := Monster.new()
		g.player = player
		add_child(g)
		g.setup_monster("ghost", player.global_position + Vector3(0, 0, -8.0), "craftghost%s" % sp)
		g.set_physics_process(false)
		g.hp = 500.0
		g.max_hp = 500.0
		var ar := Arrow.new()
		add_child(ar)
		ar.spirit = sp
		var c: Vector3 = g.global_position + Vector3(0, Arrow.chest_height(g), 0)
		ar.launch(Transform3D(Basis(), c + Vector3(0, 0, 6.0)), c, g, 10.0, player)
		for i in 40:
			await get_tree().physics_frame
		hurt.append(500.0 - g.hp)
		g.queue_free()
	if hurt[0] <= 0.0 or hurt[1] < hurt[0] * 2.5:
		fails.append("crafting: spirit arrow did not triple damage on a ghost (%s)" % str(hurt))
	print("[selftest] crafting: made %s, ward %.1f vs %.1f, ghost arrow %.0f vs spirit %.0f" % [str(made), warded, plain, hurt[0], hurt[1]])


## Moti the dog: adoption, following, fighting, fetching a coin, petting.
func _selftest_dog(fails: PackedStringArray) -> void:
	if dog_sys.dog == null:
		fails.append("dog: no stray dog found")
		return
	dog_sys.adopt()
	if not dog_sys.adopted or not dog_sys.dog.driven:
		fails.append("dog: adoption failed")
	_teleport(150.0, 60.0)
	for i in 240:
		await get_tree().physics_frame
	var dd := dog_sys.dog.global_position.distance_to(player.global_position)
	var note := "follows at %.1f m" % dd
	if dd > 6.0:
		fails.append("dog: did not keep up with the player (%.1f m)" % dd)
	var foe := combat.spawn_enemy(player.global_position + Vector3(4.0, 0, -3.0), false, 0.0, "dogfoe")
	foe.set_physics_process(false)
	var fhp: float = foe.hp
	var b0 := dog_sys.bites
	for i in 300:
		await get_tree().physics_frame
		if dog_sys.bites > b0 + 1:
			break
	note += ", bites %d, foe hp %.0f -> %.0f" % [dog_sys.bites - b0, fhp, foe.hp]
	if dog_sys.bites <= b0 or foe.hp >= fhp:
		fails.append("dog: did not bite an enemy near the player (" + note + ")")
	if is_instance_valid(foe):
		foe.queue_free()
	for i in 30:
		await get_tree().physics_frame
	# a coin 12 m away: Moti fetches it
	var f0 := dog_sys.finds
	var coin_n: Node3D = null
	if coin_sys.coins.size() > 0:
		coin_n = coin_sys.coins[0]["node"]
		var cp := coin_n.global_position
		_teleport(cp.x + 12.0, cp.z)
		dog_sys._place_near_player()
		dog_sys.mode = "follow"
		for i in 600:
			await get_tree().physics_frame
			if dog_sys.finds > f0:
				break
		note += ", coin fetched %s" % (dog_sys.finds > f0)
		if dog_sys.finds <= f0:
			fails.append("dog: did not fetch a coin 12 m away (mode %s)" % dog_sys.mode)
	player.hp = 50.0
	dog_sys.pet()
	note += ", pet heals %s" % (player.hp > 50.0)
	if player.hp <= 50.0:
		fails.append("dog: petting did not heal")
	player.hp = player.max_hp
	print("[selftest] dog: " + note)


## The flattest open ground in the valley with nothing built or growing within 12 m (for aiming tests).
func _flat_spot() -> Vector2:
	var flat := Vector2(150.0, 60.0)
	var best_bump := INF
	for gx in range(-160, 170, 20):
		for gz in range(-160, 170, 20):
			var h0g := terrain.sample_height(gx, gz)
			var bump := 0.0
			for k in 12:
				var aa := TAU * k / 12.0
				for rr in [5.0, 11.0]:
					bump = maxf(bump, absf(terrain.sample_height(gx + cos(aa) * rr, gz + sin(aa) * rr) - h0g))
			if bump >= best_bump:
				continue
			var blocked := false               # nothing built or growing within 12 m at bow height, all round
			for k in 16:
				var aa := TAU * k / 16.0
				for hh in [0.4, 1.2, 2.4]:
					var q0 := PhysicsRayQueryParameters3D.create(Vector3(gx, h0g + hh, gz), Vector3(gx + cos(aa) * 12.0, h0g + hh, gz + sin(aa) * 12.0))
					if not get_world_3d().direct_space_state.intersect_ray(q0).is_empty():
						blocked = true
			if blocked:
				continue
			if bump < best_bump:
				best_bump = bump
				flat = Vector2(gx, gz)
	return flat


## PUBG-style aiming: the touch shot goes to the crosshair (not the nearest enemy), aim assist drifts onto an
## enemy near the crosshair, the scope zooms and slows the look.
func _selftest_pubg_aim(fails: PackedStringArray) -> void:
	items.give("bow")
	items.equip("bow")
	var fs := _flat_spot()
	_teleport(fs.x, fs.y)
	for i in 10:
		await get_tree().physics_frame
	player.crosshair_aim = true
	var near := combat.spawn_enemy(player.global_position + Vector3(4.0, 0, -2.0), false, 0.0, "decoy")
	var far := combat.spawn_enemy(player.global_position + Vector3(-6.0, 0, -11.0), false, 0.0, "aimed")
	near.set_physics_process(false)
	far.set_physics_process(false)
	var hn: float = near.hp
	var hf: float = far.hp
	for it in 4:
		var ch: Vector3 = far.global_position + Vector3(0, Arrow.chest_height(far), 0)
		var dv: Vector3 = ch - player.camera.global_position
		player.set_look(atan2(-dv.x, -dv.z), atan2(dv.y, Vector2(dv.x, dv.z).length()))
		await get_tree().physics_frame
	player._attack_cd = 0.0
	player.begin_aim()
	await get_tree().physics_frame
	player.release_aim()                       # a quick tap
	await get_tree().create_timer(1.6).timeout
	var note := "tap: aimed %.0f -> %.0f, decoy %.0f -> %.0f" % [hf, far.hp, hn, near.hp]
	if far.hp >= hf or near.hp < hn:
		fails.append("pubg aim: the tap did not go to the crosshair target (" + note + ")")
	# aim assist: 3 degrees off the decoy, while dragging the view drifts onto it
	var ch2: Vector3 = near.global_position + Vector3(0, Arrow.chest_height(near), 0)
	for it2 in 4:
		var dv2: Vector3 = ch2 - player.camera.global_position
		player.set_look(atan2(-dv2.x, -dv2.z) + 0.025, atan2(dv2.y, Vector2(dv2.x, dv2.z).length()))
		await get_tree().physics_frame
	var off0 := (-player.camera.global_transform.basis.z).angle_to((ch2 - player.camera.global_position).normalized())
	for i in 40:
		player._looking_t = 0.0
		await get_tree().physics_frame
	var off1 := (-player.camera.global_transform.basis.z).angle_to((ch2 - player.camera.global_position).normalized())
	note += ", assist %.1f -> %.1f deg, red %s" % [rad_to_deg(off0), rad_to_deg(off1), player._assist != null]
	if player._assist == null or off1 >= off0 * 0.8:
		fails.append("pubg aim: aim assist did not pull onto a nearby enemy (" + note + ")")
	# scope: zoomed in, slower look
	var fov0 := player.camera.fov
	player.toggle_scope()
	for i in 30:
		await get_tree().physics_frame
	var fov1 := player.camera.fov
	player._assist = null
	player.aim_assist_on = false
	var y0 := player._yaw
	player.add_look(Vector2(100, 0))
	var turned := absf(player._yaw - y0)
	player.toggle_scope()
	var y1 := player._yaw
	player.add_look(Vector2(100, 0))
	var turned_hip := absf(player._yaw - y1)
	player.aim_assist_on = true
	note += ", scope fov %.0f -> %.0f, look %.3f vs %.3f" % [fov0, fov1, turned, turned_hip]
	if fov1 > fov0 - 8.0 or turned >= turned_hip * 0.8:
		fails.append("pubg aim: the scope did not zoom and slow the look (" + note + ")")
	for e in [near, far]:
		if is_instance_valid(e):
			e.queue_free()
	items.unequip("weapon")
	player.set_weapon("fists")
	print("[selftest] pubg aim: " + note)


## Horseback archery, whistling for your horse, and riding out onto the Southern Road.
func _selftest_horse(fails: PackedStringArray) -> void:
	var horse: Animal = null
	for c in life:
		if c is Animal and (c as Animal).species == "horse" and not (c as Animal).driven:
			horse = c
			break
	if horse == null:
		fails.append("horse: no horse in the valley")
		return
	_teleport(horse.global_position.x + 3.0, horse.global_position.z)
	for i in 5:
		await get_tree().physics_frame
	mounts.mount_animal(horse)
	if not player.mounted or String(story.get_flag("my_ride", "")) != "horse":
		fails.append("horse: mounting did not remember your ride")
	items.give("bow")
	items.equip("bow")
	var tgt := combat.spawn_enemy(horse.global_position + Vector3(-8.0, 0, -4.0), false, 0.0, "horsetarget")
	tgt.set_physics_process(false)
	var thp: float = tgt.hp
	player._attack_cd = 0.0
	var fired := player.fire_arrow()
	var seated := true
	var twist := 0.0
	for i in 70:
		await get_tree().physics_frame
		if player._rig.move == "bow_shot" and player._rig.move_t > 0.5 and player._rig.move_t < 0.62:
			seated = seated and player._rig._hips_dy < -0.3
			twist = player._rig.aim_twist
	await get_tree().create_timer(0.6).timeout
	var note := "fired %s, seated %s, twist %.2f, target hp %.0f -> %.0f" % [fired, seated, twist, thp, tgt.hp]
	if not fired or not seated or tgt.hp >= thp:
		fails.append("horse: archery from the saddle failed (" + note + ")")
	if is_instance_valid(tgt):
		tgt.queue_free()
	# aim sweep: targets all round the horse; the bow arm must point at each one and every arrow must land
	var flat := _flat_spot()
	var best_bump := 0.0
	horse.global_position = Vector3(flat.x, terrain.sample_height(flat.x, flat.y), flat.y)
	note += ", sweep ground bump %.1f m" % best_bump
	for i in 10:
		await get_tree().physics_frame
	var rows: Array = []
	var worst := 0.0
	var misses := 0
	for deg in [0.0, 35.0, 70.0, 110.0, -35.0, -70.0, -110.0, 180.0]:
		var hd: float = mounts._heading
		var ang := hd + deg_to_rad(deg)
		var dir3 := Vector3(-sin(ang), 0.0, -cos(ang))
		var tp: Vector3 = horse.global_position + dir3 * 10.0
		tp.y = terrain.sample_height(tp.x, tp.z)
		var t2 := combat.spawn_enemy(tp, false, 0.0, "sweep%d" % int(deg))
		t2.set_physics_process(false)
		t2.global_position = tp
		var h0: float = t2.hp
		player._attack_cd = 0.0
		player.fire_arrow()
		var err := 999.0
		for i in 80:
			await get_tree().physics_frame
			if player._rig.move == "bow_shot" and player._rig.move_t > 0.56 and player._rig.move_t < 0.63:
				var arm: Vector3 = player._rig._bone_pos("wr_L") - player._rig._bone_pos("sh_L")
				var tg: Vector3 = tp - player._rig._bone_pos("sh_L")
				err = rad_to_deg(absf(Vector2(arm.x, arm.z).angle_to(Vector2(tg.x, tg.z))))
		await get_tree().create_timer(0.5).timeout
		var hit := t2.hp < h0
		if not hit:
			misses += 1
			for an in find_children("*", "Node3D", true, false):
				if an is Arrow and (an as Arrow)._life < 3.0:
					var dq := PhysicsRayQueryParameters3D.create(player._rig.nock_transform().origin, an.global_position + (an.global_position - player._rig.nock_transform().origin).normalized() * 0.6)
					dq.exclude = player.ray_excludes()
					var dh := get_world_3d().direct_space_state.intersect_ray(dq)
					print("[selftest] sweep blocker: %s, excludes %d, ride %s" % [str((dh["collider"] as Node).get_path()) if not dh.is_empty() else "none", player.ray_excludes().size(), str(player.ride)])
					print("[selftest] sweep %d miss: arrow under %s at %s (target %s, nock %s), stuck %.2f" % [int(deg), an.get_parent().name, str(an.global_position), str(tp), str(player._rig.nock_transform().origin), (an as Arrow)._stuck])
		if absf(deg) <= 110.0:
			worst = maxf(worst, err)
		rows.append("%d:%.0f%s" % [int(deg), err, "" if hit else "MISS"])
		t2.queue_free()
		player._attack_cd = 0.0
		await get_tree().physics_frame
	note += ", sweep [%s]" % " ".join(rows)
	# held aim with the crosshair from the saddle (the crosshair must not catch your own horse)
	var mang: float = mounts._heading + 0.4
	var mp: Vector3 = horse.global_position + Vector3(-sin(mang), 0.0, -cos(mang)) * 11.0
	mp.y = terrain.sample_height(mp.x, mp.z)
	var t3 := combat.spawn_enemy(mp, false, 0.0, "sweepaim")
	t3.set_physics_process(false)
	t3.global_position = mp
	var h3: float = t3.hp
	player._attack_cd = 0.0
	player.begin_aim()
	for i in 6:
		await get_tree().create_timer(0.15, true, false, true).timeout
		var ch: Vector3 = t3.global_position + Vector3(0, Arrow.chest_height(t3), 0)
		var dv3: Vector3 = ch - player.camera.global_position
		player.set_look(atan2(-dv3.x, -dv3.z), atan2(dv3.y, Vector2(dv3.x, dv3.z).length()))
	player.release_aim()
	await get_tree().create_timer(1.0).timeout
	note += ", held aim from the saddle hit %s" % (t3.hp < h3)
	if t3.hp >= h3:
		fails.append("horse: held crosshair aim from the saddle missed")
	t3.queue_free()
	if misses > 0 or worst > 15.0:
		fails.append("horse: aim sweep off (worst arm error %.0f deg within 110 deg, %d misses)" % [worst, misses])
	items.unequip("weapon")
	player.set_weapon("fists")
	# whistle from far away
	mounts.dismount()
	_teleport(horse.global_position.x + 70.0, horse.global_position.z + 10.0)
	for i in 5:
		await get_tree().physics_frame
	var line: String = mounts.whistle()
	var came := false
	for i in 900:
		await get_tree().physics_frame
		if mounts.called == null:
			came = true
			break
	var hd := horse.global_position.distance_to(player.global_position)
	note += ", whistle '%s', came %s at %.1f m" % [line, came, hd]
	if not came or hd > 4.5:
		fails.append("horse: whistle did not bring the horse (" + note + ")")
	# out on the Southern Road the horse is not pulled back to the valley edge
	mounts.mount_animal(horse)
	horse.global_position = Vector3(18.0, terrain.sample_height(18.0, 360.0), 360.0)
	mounts._heading = PI          # facing +z, down the road
	player.move_input = Vector2(0, 1)
	player.set_look(PI, -0.2)
	for i in 40:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	note += ", road z %.0f" % horse.global_position.z
	if horse.global_position.z < 340.0:
		fails.append("horse: riding on the Southern Road snapped back (" + note + ")")
	mounts.dismount()
	print("[selftest] horse: " + note)


## Boss fight: phases, summoned minions, stomp shockwave, weak spot, charge, the boss bar and the kill.
func _selftest_boss(fails: PackedStringArray) -> void:
	var mm := get_tree().get_first_node_in_group("monster_missions")
	if mm == null:
		fails.append("boss: no monster missions node")
		return
	_teleport(185.0, 150.0)
	for i in 5:
		await get_tree().physics_frame
	player.hp = 900.0
	player.max_hp = 900.0
	var b: Monster = mm.summon("demon", player.global_position + Vector3(0, 0, -4.0))
	for i in 100:
		await get_tree().physics_frame
	if b.boss == null:
		fails.append("boss: demon has no boss brain")
		return
	var notes: Array = []
	if b.boss._bar == null:
		fails.append("boss: no boss bar when the player is near")
	# stomp: the player stands inside the ring
	b.boss._stomp_cd = 0.0
	b.boss._end()
	var hp0 := player.hp
	var saw_stomp := false
	for i in 150:
		await get_tree().physics_frame
		player.global_position = b.global_position + Vector3(0, 0.2, -3.0)
		saw_stomp = saw_stomp or b.boss.state == "stomp"
		if b.boss.state == "dazed":
			break
	notes.append("stomp %s, player hp %.0f -> %.0f, dazed %s" % [saw_stomp, hp0, player.hp, b.boss.state == "dazed"])
	if not saw_stomp or player.hp >= hp0 or b.boss.state != "dazed":
		fails.append("boss: stomp did not hit the player and daze the boss (" + notes[-1] + ")")
	# phase 2: minions rise and the weak spot opens
	var n0 := get_tree().get_nodes_in_group("monsters").size()
	b.boss._end()
	b.hp = b.max_hp * 0.6
	b.take_hit("punch", 1.0, Vector3.ZERO)
	var n1 := get_tree().get_nodes_in_group("monsters").size()
	if b.boss.phase != 2 or not b.boss.gem_open() or n1 - n0 < 2:
		fails.append("boss: phase 2 did not start with minions and a weak spot (phase %d, minions +%d)" % [b.boss.phase, n1 - n0])
	for i in 110:
		await get_tree().physics_frame
	# an arrow into the weak spot
	var hpw := b.hp
	b.boss._end()
	b.set_physics_process(false)
	var gp: Vector3 = b.boss.gem_world()
	var ar := Arrow.new()
	add_child(ar)
	ar.launch(Transform3D(Basis(), gp + (gp - b.global_position).normalized() * 0.0 + Vector3(0, 0.3, 0) - b.global_transform.basis.z * 7.0), gp, b, 10.0, player)
	for i in 40:
		await get_tree().physics_frame
	notes.append("weak spot hits %d, hp %.0f -> %.0f" % [b.boss.weak_hits, hpw, b.hp])
	if b.boss.weak_hits < 1 or hpw - b.hp < 25.0:
		fails.append("boss: arrow into the weak spot did not do triple damage (" + notes[-1] + ")")
	b.set_physics_process(true)
	# charge from range
	b.boss._end()
	b.boss._stomp_cd = 99.0
	b.boss._charge_cd = 0.0
	var saw_charge := false
	for i in 120:
		await get_tree().physics_frame
		if b.boss.state == "" and not saw_charge:
			player.global_position = b.global_position + Vector3(0, 0.2, -12.0)
		saw_charge = saw_charge or b.boss.state == "charge"
		if saw_charge and b.boss.state != "charge":
			break
	notes.append("charge %s" % saw_charge)
	if not saw_charge:
		fails.append("boss: no charge in phase 2")
	# phase 3, then the kill
	b.boss._end()
	b.hp = b.max_hp * 0.3
	b.take_hit("punch", 1.0, Vector3.ZERO)
	if b.boss.phase != 3 or not b.enraged:
		fails.append("boss: phase 3 did not start")
	b.boss._end()
	b.hp = 1.0
	b.take_hit("punch", 50.0, Vector3.ZERO)
	await get_tree().physics_frame
	if not b.dead or b.boss._bar != null:
		fails.append("boss: did not die cleanly (bar left on screen)")
	print("[selftest] boss: " + ", ".join(notes) + ", beaten %d" % BossBrain.bosses_beaten)
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m):
			m.queue_free()
	player.max_hp = 100.0
	player.hp = 100.0


## Diagnostics: draw calls and what makes them, at the places players spend time (Low quality).
func _run_probe_perf() -> void:
	var tier := int(OS.get_environment("TIER")) if OS.get_environment("TIER") != "" else 2
	GameSettings.v["quality"] = tier
	await get_tree().process_frame
	for c in get_children():
		if c is TitleScreen:
			c.queue_free()
		elif c is CanvasLayer and OS.get_environment("SHOT") != "":
			(c as CanvasLayer).visible = false
	player.locked = false
	apply_quality(tier)
	atmosphere.time_of_day = 0.45
	atmosphere.apply_time()
	var spots := [["village", -80.0, 4.0, 0.6], ["bazaar", 22.0, -30.0, 0.0], ["graveyard", -122.0, 56.0, 2.4], ["road", 18.0, 300.0, PI], ["farm", 60.0, 60.0, 1.0]]
	for sp in spots:
		_teleport(float(sp[1]), float(sp[2]))
		player.set_look(float(sp[3]), -0.12)
		for i in 90:
			await get_tree().process_frame
		var cam := get_viewport().get_camera_3d()
		var groups := {}
		var surf_total := 0
		for n in find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree() or g is Label3D:
				continue
			var ab := g.get_aabb()
			var centre := g.global_transform * ab.get_center()
			var d := centre.distance_to(cam.global_position)
			if g.visibility_range_end > 0.0 and d > g.visibility_range_end + ab.size.length() * 0.5:
				continue
			if d > cam.far or not cam.is_position_in_frustum(centre) and d > ab.size.length():
				continue
			var surfs := 1
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				surfs = (g as MeshInstance3D).mesh.get_surface_count()
			elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null and (g as MultiMeshInstance3D).multimesh.mesh != null:
				surfs = (g as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
			var top: Node = g
			while top.get_parent() != null and top.get_parent() != self:
				top = top.get_parent()
			var key := String(top.name)
			if top is Npc:
				key = "NPC"
			elif top is Animal:
				key = "Animal"
			elif top is Enemy or top is Monster:
				key = "Enemy"
			key = key.rstrip("0123456789").trim_suffix("_").trim_suffix("@")
			if OS.get_environment("SPLIT") != "" and key == OS.get_environment("SPLIT"):
				var sub: Node = g
				while sub.get_parent() != top:
					sub = sub.get_parent()
				var nm := String(sub.name)
				if sub == g and g.name.contains("MeshInstance"):
					nm = "merged"
				elif sub.get_child_count() > 0:
					var ch := sub
					var d2: Node = g
					while d2.get_parent() != ch:
						d2 = d2.get_parent()
					nm += "/" + String(d2.name).left(12)
				key = nm.rstrip("0123456789").replace("@", "")
			groups[key] = int(groups.get(key, 0)) + surfs
			surf_total += surfs
		var keys := groups.keys()
		keys.sort_custom(func(x, y) -> bool: return groups[x] > groups[y])
		var top_list: Array = []
		for k in keys.slice(0, 9 if OS.get_environment("SPLIT") == "" else 30):
			top_list.append("%s=%d" % [k, groups[k]])
		if sp[0] == "bazaar":
			var why := {}
			var mats := {}
			for n in get_node("BazaarTown").find_children("*", "GeometryInstance3D", true, false):
				var g2 := n as GeometryInstance3D
				if not g2.is_visible_in_tree():
					continue
				if g2.name.begins_with("Merged"):
					var mm := (g2 as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
					if mm != null:
						var tk := "tex" if mm.albedo_texture != null else "flat"
						mats[tk + ("_em" if mm.emission_enabled else "")] = int(mats.get(tk + ("_em" if mm.emission_enabled else ""), 0)) + 1
					continue
				var r := g2.get_class()
				if g2 is MeshInstance3D:
					var mi2 := g2 as MeshInstance3D
					if mi2.get_script() != null: r = "script"
					elif mi2.visibility_range_end > 0.0:
						if mi2.mesh is ArrayMesh and mi2.get_parent() == get_node("BazaarTown") and mi2.get_child_count() == 0 and String(mi2.name).contains("Mesh"):
							r = "merged"
						else:
							var pp: Node = mi2.get_parent()
							r = "vr:%s/%s/%s" % [String(pp.get_parent().name).rstrip("0123456789").left(14), String(pp.name).rstrip("0123456789").left(14), String(mi2.name).rstrip("0123456789").left(12)]
					elif mi2.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: r = "noshadow"
					elif mi2.mesh != null and mi2.mesh.surface_get_material(0) is ShaderMaterial or mi2.material_override is ShaderMaterial: r = "shader"
					else:
						var bm2 := (mi2.material_override if mi2.material_override != null else (mi2.mesh.surface_get_material(0) if mi2.mesh != null else null)) as BaseMaterial3D
						if bm2 != null and bm2.transparency != 0: r = "transp"
						else: r = "name:" + String(mi2.name).left(10) + "/" + String(mi2.get_parent().name).left(10)
				why[r] = int(why.get(r, 0)) + 1
			var wk := why.keys()
			wk.sort_custom(func(x, y) -> bool: return why[x] > why[y])
			var wl: Array = []
			for k in wk.slice(0, 25):
				wl.append("%s=%d" % [k, why[k]])
			print("[perf] bazaar unmerged: ", ", ".join(wl))
			print("[perf] bazaar merged materials: ", mats)
		if OS.get_environment("SHOT") != "":
			get_viewport().get_texture().get_image().save_png("%s/%s_t%d.png" % [OS.get_environment("SHOT"), sp[0], tier])
		print("[perf] %s draws=%d objects=%d prims=%dk  visible surfaces=%d  top: %s" % [sp[0], int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000), surf_total, ", ".join(top_list)])
	get_tree().quit()


## Diagnostics: run The Restless Dead and report story changes, saves, nodes and frame time per second.
func _run_probe_ghost() -> void:
	for i in 30:
		await get_tree().physics_frame
	story.set_flag("intro_done", true)
	var counts := {"changed": 0}
	story.changed.connect(func() -> void: counts["changed"] += 1)
	var mm := get_tree().get_first_node_in_group("monster_missions")
	mm.set("skip_intro", true)
	_teleport(-122.0, 50.0)
	for i in 10:
		await get_tree().physics_frame
	var m: Dictionary = MonsterMissions.MISSIONS[0]
	mm.call("start", m)
	for sec in 12:
		var c0: int = counts["changed"]
		var n0 := get_tree().get_node_count()
		var t0 := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t0 < 1000000:
			await get_tree().process_frame
			frames += 1
			if sec >= 3 and frames % 20 == 0:
				player.attack()
		print("[probe] s%d changed %d nodes %d (+%d) frames %d alive %d" % [sec, counts["changed"] - c0, get_tree().get_node_count(), get_tree().get_node_count() - n0, frames, (mm.get("alive") as Array).size()])
	get_tree().quit()


## Close-ups for judging the look of the hero, a villager and the ghosts (day and night).
func _run_capture_look(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	var fs := _flat_spot()
	_teleport(fs.x, fs.y)
	var cam := player.camera
	if OS.get_environment("CROWD") != "":
		# villagers in the bazaar, from a little distance and close up
		cam.reparent(self)
		atmosphere.time_of_day = 0.42
		atmosphere.apply_time()
		var c := LiveEvents.C
		_teleport(c.x, c.z + 6.0)
		for i in 60:
			await get_tree().physics_frame
		var npcs: Array = []
		for n in get_tree().get_nodes_in_group("npcs"):
			if n is Node3D and (n as Node3D).global_position.distance_to(player.global_position) < 40.0:
				npcs.append(n)
		npcs.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
		for k in mini(4, npcs.size()):
			var np: Vector3 = (npcs[k] as Node3D).global_position + Vector3(0, 1.3, 0)
			var fw := -(npcs[k] as Node3D).global_transform.basis.z
			cam.global_position = np + fw * 2.2 + Vector3(0, 0.15, 0)
			cam.look_at(np, Vector3.UP)
			cam.fov = 45.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/crowd_%d.png" % [dir, k])
		get_tree().quit()
		return
	if OS.get_environment("MONSTERS") != "":
		# close-ups of other monsters, day then night
		cam.reparent(self)
		for tod in [0.42, 0.9]:
			atmosphere.time_of_day = tod
			atmosphere.apply_time()
			for kind in OS.get_environment("MONSTERS").split(","):
				var mo := Monster.new()
				mo.player = player
				add_child(mo)
				mo.setup_monster(kind, player.global_position + Vector3(0, 0, -8.0), "look_" + kind)
				mo.set_physics_process(false)
				mo.rotation.y = PI                    # face the camera
				for i in 30:
					await get_tree().physics_frame
				var h := float(Monster.KINDS[kind]["height"])
				var mp := mo.global_position + Vector3(0, h * 0.55, 0)
				cam.global_position = mp + Vector3(h * 0.5, h * 0.1, h * 1.3 + 1.0)
				cam.look_at(mp, Vector3.UP)
				cam.fov = 45.0
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/mon_%s_%d.png" % [dir, kind, int(tod * 10)])
				mo.queue_free()
				await get_tree().physics_frame
		get_tree().quit()
		return
	if OS.get_environment("OUTFITS") != "":
		# hero close-ups in several outfits (skin and dye check)
		atmosphere.time_of_day = 0.42
		atmosphere.apply_time()
		var wr := get_tree().get_first_node_in_group("wardrobe")
		cam.reparent(self)
		for oid in OS.get_environment("OUTFITS").split(","):
			story.set_flag("own_" + oid, true)
			wr.call("wear", oid)
			for i in 20:
				await get_tree().physics_frame
			var pc0 := player.global_position + Vector3(0, 1.45, 0)
			var fwd0 := -player._model.global_transform.basis.z
			cam.global_position = pc0 + fwd0 * 1.5 + Vector3(0, 0.1, 0)
			cam.look_at(pc0, Vector3.UP)
			cam.fov = 42.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/outfit_%s.png" % [dir, oid])
		get_tree().quit()
		return
	for pass_i in 2:
		atmosphere.time_of_day = 0.42 if pass_i == 0 else 0.9
		atmosphere.apply_time()
		var g := Monster.new()
		g.player = player
		add_child(g)
		g.setup_monster("ghost", player.global_position + Vector3(2.5, 0, -3.0), "lookghost")
		g.set_physics_process(false)
		var sk := Monster.new()
		sk.player = player
		add_child(sk)
		sk.setup_monster("ghost_skull", player.global_position + Vector3(-2.0, 0, -3.5), "lookskull")
		sk.set_physics_process(false)
		for i in 40:
			await get_tree().physics_frame
		cam.reparent(self) if cam.get_parent() != self else null
		var pc := player.global_position + Vector3(0, 1.45, 0)
		cam.global_position = pc + Vector3(0.3, 0.1, -1.6)
		cam.look_at(pc, Vector3.UP)
		cam.fov = 42.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hero_%d.png" % [dir, pass_i])
		var gp := g.global_position + Vector3(0, 1.4, 0)
		cam.global_position = gp + Vector3(-0.5, 0.2, 2.6)
		cam.look_at(gp, Vector3.UP)
		for i in 5:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/ghost_%d.png" % [dir, pass_i])
		var sp := sk.global_position + Vector3(0, 1.2, 0)
		cam.global_position = sp + Vector3(0.4, 0.1, 2.2)
		cam.look_at(sp, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/skull_%d.png" % [dir, pass_i])
		if pass_i == 1:
			# a ghost burning away
			cam.global_position = gp + Vector3(-0.5, 0.6, 2.8)
			cam.look_at(gp + Vector3(0, 0.6, 0), Vector3.UP)
			g.take_hit("arrow", 999.0, Vector3.FORWARD)
			for k in 5:
				await get_tree().create_timer(0.35).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/ghost_dying_%d.png" % [dir, k])
		if is_instance_valid(g):
			g.queue_free()
		sk.queue_free()
	# a villager
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n is Node3D:
			best = n
			break
	if best != null:
		var np: Vector3 = best.global_position + Vector3(0, 1.45, 0)
		atmosphere.time_of_day = 0.42
		atmosphere.apply_time()
		var fwd := -(best as Node3D).global_transform.basis.z
		cam.global_position = np + fwd * 1.7 + Vector3(0, 0.1, 0)
		cam.look_at(np, Vector3.UP)
		for i in 5:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/npc.png" % dir)
	get_tree().quit()


func _run_capture_pubg(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var fs := _flat_spot()
	_teleport(fs.x, fs.y)
	items.give("bow")
	items.equip("bow")
	var g := Monster.new()
	g.player = player
	add_child(g)
	g.setup_monster("ghost", player.global_position + Vector3(0, 0, -12.0), "capghost")
	g.set_physics_process(false)
	for i in 30:
		await get_tree().physics_frame
	for k in 2:
		for it in 4:
			var ch: Vector3 = g.global_position + Vector3(0, Arrow.chest_height(g), 0)
			var dv: Vector3 = ch - player.camera.global_position
			player.set_look(atan2(-dv.x, -dv.z) + 0.015, atan2(dv.y, Vector2(dv.x, dv.z).length()))
			await get_tree().physics_frame
		for i in 30:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, ["a_hip", "b_scope"][k]])
		player.toggle_scope()
	get_tree().quit()


func _run_capture_weather(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	_teleport(-60.0, 20.0)
	player.set_look(2.4, -0.05)
	player.set_distance(5.0)
	atmosphere.time_of_day = 0.45
	for sh in [["sharad", "clear"], ["grishma", "dust"], ["varsha", "rain"], ["shishir", "fog"]]:
		atmosphere.season = String(sh[0])
		atmosphere.set_weather(String(sh[1]), 999.0)
		atmosphere.rain = atmosphere.rain_target
		atmosphere.dust = atmosphere.dust_target
		atmosphere.mist = atmosphere.mist_target
		for i in 120:
			await get_tree().physics_frame
		atmosphere.apply_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, String(sh[0]), String(sh[1])])
	get_tree().quit()


func _run_capture_photo(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	atmosphere.time_of_day = 0.45
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	photo_mode.enter()
	photo_mode.selfie()
	var shots := [["Victory", 0], ["Archer", 1], ["Kick", 0], ["Pray", 3], ["Fighter", 4], ["Punch", 5]]
	for sh in shots:
		photo_mode.set_pose(PhotoMode.POSES.find(sh[0]))
		photo_mode.filter = int(sh[1])
		photo_mode._apply_filter()
		photo_mode._relabel()
		for i in 45:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, String(sh[0])])
	var saved_to: String = await photo_mode.capture()
	print("[capture] photo saved to %s exists %s" % [saved_to, FileAccess.file_exists(saved_to)])
	get_tree().quit()


func _run_capture_event(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var ev := live_events.active
	touch.visible = OS.get_environment("HINDI") != ""
	if OS.get_environment("HINDI") != "":
		Loc.set_language("hi")
		relocalize()
	atmosphere.time_of_day = 0.8 if ev == "diwali" else 0.45
	atmosphere.apply_time()
	var c := LiveEvents.C
	match ev:
		"diwali":
			for d in live_events._targets:
				live_events.light_diya(d, null)
			_teleport(c.x - 13.0, c.z + 3.0)
			player.set_look(-1.75, -0.12)
		"dussehra":
			_teleport(c.x + 2.0, c.z + 16.0)
			player.set_look(PI, 0.18)
		"sankranti":
			_teleport(c.x, c.z)
			player.set_look(0.7, 0.45)
	player.set_distance(4.0)
	for i in 90:
		await get_tree().physics_frame
	if ev == "diwali":
		for i in 3:
			live_events._firework()
		for i in 40:
			await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, ev])
	get_tree().quit()


func _run_capture_dog(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	for i in 10:
		await get_tree().physics_frame
	dog_sys.adopt(true)
	_teleport(-60.0, 20.0)
	player.set_look(2.6, -0.2)
	player.set_distance(4.5)
	player.move_input = Vector2(0, 0.6)
	for i in 150:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/a_follow.png" % dir)
	dog_sys.pet()
	for i in 20:
		await get_tree().physics_frame
	var cam := player.camera
	cam.reparent(self)
	var dp := dog_sys.dog.global_position
	cam.global_position = dp + Vector3(1.6, 1.0, 1.6)
	cam.look_at(dp + Vector3(0, 0.5, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/b_close.png" % dir)
	get_tree().quit()


func _run_capture_horse(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var horse: Animal = null
	for c in life:
		if c is Animal and (c as Animal).species == "horse":
			horse = c
			break
	_teleport(horse.global_position.x + 3.0, horse.global_position.z)
	for i in 10:
		await get_tree().physics_frame
	mounts.mount_animal(horse)
	items.give("bow")
	items.equip("bow")
	player.set_weapon("bow")
	mounts._heading = 0.0
	var tgt := combat.spawn_enemy(horse.global_position + Vector3(-9.0, 0, -6.0), false, 0.0, "t")
	tgt.set_physics_process(false)
	tgt.hp = 9999.0
	player.set_look(-1.9, -0.15)
	player.set_distance(5.0)
	for i in 20:
		await get_tree().physics_frame
	player._attack_cd = 0.0
	player.fire_arrow()
	var shots := [[24, "a_raise"], [36, "b_draw"], [44, "c_release"]]
	var f := 0
	for sh in shots:
		while f < int(sh[0]):
			await get_tree().physics_frame
			f += 1
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, String(sh[1])])
	get_tree().quit()


func _run_capture_boss(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	player.hp = 9999.0
	player.max_hp = 9999.0
	var mm := get_tree().get_first_node_in_group("monster_missions")
	var b: Monster = mm.summon(OS.get_environment("KIND") if OS.get_environment("KIND") != "" else "demon", player.global_position + Vector3(0, 0, -9.0))
	player.set_look(0.0, -0.25)
	player.set_distance(7.0)
	for i in 80:
		await get_tree().physics_frame
	b.boss._end()
	b.boss._stomp_cd = 0.0
	for i in 200:
		await get_tree().physics_frame
		player.global_position.z = b.global_position.z + 4.5
		player.global_position.x = b.global_position.x
		if b.boss.state == "stomp" and b.boss._t > 0.8:
			break
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/a_stomp.png" % dir)
	b.boss._end()
	b.hp = b.max_hp * 0.6
	b.take_hit("punch", 1.0, Vector3.ZERO)
	for i in 30:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/b_phase2.png" % dir)
	for i in 80:
		await get_tree().physics_frame
	b.boss._end()
	b.boss._stomp_cd = 99.0
	b.boss._charge_cd = 0.0
	for i in 200:
		await get_tree().physics_frame
		if b.boss.state == "":
			player.global_position = b.global_position + Vector3(2.0, 0.3, 11.0)
		if b.boss.state == "charge_aim" and b.boss._t > 0.6:
			break
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/c_charge.png" % dir)
	get_tree().quit()


func _run_capture_bow(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	atmosphere.time_of_day = 0.4
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	items.give("bow")
	items.equip("bow")
	player.set_weapon("bow")
	var foe := combat.spawn_enemy(player.global_position + Vector3(0, 0, -10.0), false, 0.0, "target")
	foe.hp = 9999.0
	foe.set_physics_process(false)
	player.hp = 99999.0
	var view := OS.get_environment("VIEW")
	for i in 20:
		await get_tree().physics_frame
	player._attack_cd = 0.0
	if view == "aim":
		# over-the-shoulder aim camera with the on-screen crosshair, then the arrow in flight
		touch.visible = true
		items.give("fire_arrow", 3)
		player.begin_aim()
		for k in 50:
			var hd: Vector3 = foe.global_position + Vector3(0, Arrow.head_height(foe), 0)
			var dv: Vector3 = hd - player.camera.global_position
			player.set_look(atan2(-dv.x, -dv.z), atan2(dv.y, Vector2(dv.x, dv.z).length()))
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/aim_a_draw.png" % dir)
		var arm: Vector3 = player._rig._bone_pos("wr_L") - player._rig._bone_pos("sh_L")
		var tg: Vector3 = foe.global_position - player.global_position
		print("[capture] bow arm off target by %.0f deg" % rad_to_deg(Vector2(arm.x, arm.z).angle_to(Vector2(tg.x, tg.z))))
		var bw := player._rig._bow_att.get_child(0) as Node3D
		var bxf := bw.global_transform
		var back := (bxf.origin - (bxf * Vector3(0.128, 0.0, 0.0))).normalized()      # grip side, should face the target
		var span := ((bxf * RealHuman.BOW_TIP_TOP) - (bxf * RealHuman.BOW_TIP_BOT)).normalized()
		print("[capture] bow back . target %.2f, limbs . up %.2f" % [back.dot(tg.normalized()), span.dot(Vector3.UP)])
		player.release_aim()
		for k in 9:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/aim_b_flight.png" % dir)
		for k in 20:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/aim_c_hit.png" % dir)
		get_tree().quit()
		return
	player.fire_arrow()
	player.set_physics_process(true)
	# a fixed camera to the archer's right (or front), looking across the shot
	var cam := player.camera
	cam.reparent(self)             # out of the spring arm, so it stays where we put it
	var pc := player.global_position + Vector3(0, 1.25, 0)
	cam.global_position = pc + (Vector3(3.2, 0.2, 0.0) if view != "front" else Vector3(1.2, 0.3, -3.0))
	cam.look_at(pc, Vector3.UP)
	var shots := [[9, "a_quiver"], [18, "b_nock"], [26, "c_raise"], [35, "d_draw"], [38, "e_anchor"], [41, "f_release"], [49, "g_follow"]]
	var f := 0
	for sh in shots:
		while f < int(sh[0]):
			await get_tree().physics_frame
			f += 1
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, view if view != "" else "side", String(sh[1])])
	cam.global_position = foe.global_position + Vector3(2.0, 1.6, 2.5)
	cam.look_at(foe.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	for i in 30:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_h_stuck.png" % [dir, view if view != "" else "side"])
	get_tree().quit()


func _run_capture_outfits(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	atmosphere.time_of_day = 0.4
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	if OS.get_environment("GEAR") != "":
		items.give("bow")
		items.give("sword")
		items.give("dagger")
	for o in Wardrobe.OUTFITS:
		if OS.get_environment("ONLY") != "" and not OS.get_environment("ONLY").split(",").has(String(o["id"])):
			continue
		wardrobe.wear(String(o["id"]), false)
		player._model.rotation.y = 0.0
		player.set_look(PI, -0.12)
		player.set_distance(2.6)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/o_%s.png" % [dir, String(o["id"])])
		player.set_look(PI * 0.25, -0.12)          # three-quarter view from behind: capes, sashes
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/b_%s.png" % [dir, String(o["id"])])
	wardrobe.open_shop("dhoop")
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/shop.png" % dir)
	get_tree().quit()


func _run_capture_hero(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 30:
		await get_tree().process_frame
	progression.gain(300, "capture")
	menu.toggle()
	menu._show_page("Hero")
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hero.png" % dir)
	get_tree().quit()


## Close-ups of every animal species after FurLook (smooth shading, coat, shell fur).
func _run_capture_fur(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	atmosphere.time_of_day = 0.4
	atmosphere.apply_time()
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	var only := OS.get_environment("SPECIES")
	if only == "probe":
		player.set_look(0.0, -0.08)
		player.set_distance(3.2)
		for i in 20:
			await get_tree().process_frame
		var cam := get_viewport().get_camera_3d()
		var px := Vector2(float(OS.get_environment("PX")) / 1280.0, float(OS.get_environment("PY")) / 720.0) * get_viewport().get_visible_rect().size
		print("[probe] cam ", cam.global_position, " vp ", get_viewport().get_visible_rect().size)
		var o := cam.project_ray_origin(px)
		var dv := cam.project_ray_normal(px)
		var hits: Array = []
		for mi in find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.is_visible_in_tree() or m.mesh == null:
				continue
			var bb := m.global_transform * m.get_aabb()
			var hp: Variant = bb.intersects_ray(o, dv)
			if hp != null:
				hits.append([o.distance_to(hp), str(m.get_path()), m.mesh.get_class(), bb.size])
		hits.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for h in hits.slice(0, 12):
			print("[probe] ", h)
		get_tree().quit()
		return
	for k in Animal.SPECIES:
		if only != "" and not only.split(",").has(k):
			continue
		var a := Animal.new().setup(k, terrain, player, player.global_position + Vector3(0, 0, -5), 0.0)
		add_child(a)
		a.global_position = player.global_position + Vector3(1.2, 0, -4.0)
		a.global_position.y = terrain.sample_height(a.global_position.x, a.global_position.z)
		a.rotation.y = PI * 0.5
		a.set_process(false)
		player.set_look(0.0, -0.08)
		player.set_distance(1.6 + float(Animal.SPECIES[k]["height"]) * 0.8)
		player._model.visible = false
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/a_%s.png" % [dir, k])
		a.queue_free()
	get_tree().quit()


func _run_capture_mon(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	hud.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var only := OS.get_environment("PART")
	_teleport(-60.0, 20.0)
	for i in 20:
		await get_tree().physics_frame
	player.set_physics_process(true)
	if only == "dbg":
		player.play_task("dig", 3.0)
		for i in 30:
			await get_tree().physics_frame
		print("[dbg] action=", player._rig.action, " t=", player._rig._action_t, " dur=", player._rig._action_dur, " task=", player._task_t, " phys=", player.is_physics_processing(), " locked=", player.locked, " sh_R=", player._rig._pose["sh_R"], " dy=", player._rig._hips_dy)
	if only == "" or only == "kinds":
		for k in Monster.KINDS:
			var t := Monster.new()
			t.player = null
			add_child(t)
			t.setup_monster(k, player.global_position + Vector3(0, 0, -7.0), "Show_" + k)
			t.global_position = player.global_position + Vector3(0, 0, -7.0)
			player.set_look(0.0, -0.02)
			player.set_distance(4.0)
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/k_%s.png" % [dir, k])
			t.queue_free()
	if only == "" or only == "tasks":
		for task in ["dig", "pray", "search", "pickup", "cut", "reach"]:
			player.set_look(player._model.rotation.y + PI * 0.5, -0.05)
			player.set_distance(3.0)
			player.play_task(task, 3.0)
			for i in 50:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/t_%s.png" % [dir, task])
			for i in 160:
				await get_tree().physics_frame
		player.set_weapon("bow")
		player._rig.play_move("bow_shot")
		for i in 17:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/t_bow.png" % dir)
	if only == "" or only == "mission":
		var m: Dictionary = MonsterMissions.MISSIONS[0]
		var at: Vector2 = m["at"]
		_teleport(at.x + 9.0, at.y + 9.0)
		for i in 20:
			await get_tree().physics_frame
		monsters.start(m, true)
		player.hp = 99999.0
		player.max_hp = 99999.0
		hud.visible = true
		for i in 100:
			await get_tree().process_frame
		player.set_distance(6.0)
		_look_at_point(Vector3(at.x, terrain.sample_height(at.x, at.y) + 1.5, at.y), -0.1)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/m1_night.png" % dir)
	get_tree().quit()


func _run_capture_road(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var sc := FrontierBuilder.SARAI_C
	var dc := FrontierBuilder.DHOOP_C
	var shots := [
		["r1_pass_up", Vector3(-40.0, 0.0, 165.0), Vector3(-40.0, 22.0, 215.0), -0.02],
		["r2_pass_top", Vector3(-38.0, 0.0, 232.0), Vector3(-20.0, 32.0, 300.0), -0.02],
		["r3_back_view", Vector3(-30.0, 0.0, 270.0), Vector3(-40.0, 10.0, 150.0), -0.05],
		["r4_sarai", Vector3(sc.x - 34.0, 0.0, sc.y - 12.0), Vector3(sc.x, 33.0, sc.y), -0.05],
		["r5_sarai_in", Vector3(sc.x - 8.0, 0.0, sc.y + 2.0), Vector3(sc.x + 8.0, 33.0, sc.y - 2.0), -0.05],
		["r6_dhoop", Vector3(dc.x - 4.0, 0.0, dc.y - 40.0), Vector3(dc.x, 33.0, dc.y), -0.05],
		["r7_over", Vector3(-30.0, 60.0, 300.0), Vector3(-30.0, 30.0, 420.0), -0.35],
	]
	for s in shots:
		var sp: Vector3 = s[1]
		player.set_distance(5.0)
		var gy := terrain.sample_height(sp.x, sp.z)
		player.global_position = Vector3(sp.x, maxf(gy + 0.4, sp.y), sp.z)
		player.velocity = Vector3.ZERO
		player.locked = true
		_look_at_point(s[2], s[3])
		for i in 70:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] ", s[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]]))
	map_ui.toggle_full()
	map_ui._view = MapUI.WORLD
	map_ui._sync_view_btn()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/map_world.png" % dir)
	get_tree().quit()


func _run_capture_town(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.42
	atmosphere.apply_time()
	var c := TerrainBuilder.TOWN_C
	var shots := [
		["t1_square", Vector3(c.x - 3.0, 0.0, c.y + 20.0), Vector3(c.x, 1.5, c.y - 4.0), -0.08],
		["t2_stalls", Vector3(c.x + 2.0, 0.0, c.y + 4.0), Vector3(c.x + 4.0, 1.4, c.y + 12.0), -0.05],
		["t3_street_e", Vector3(c.x + 17.0, 0.0, c.y + 0.0), Vector3(c.x + 42.0, 2.0, c.y + 0.0), -0.05],
		["t4_street_n", Vector3(c.x - 1.0, 0.0, c.y - 17.0), Vector3(c.x, 3.0, c.y - 44.0), -0.03],
		["t5_wash", Vector3(c.x - 2.0, 0.0, c.y + 8.0), Vector3(c.x - 6.4, 0.8, c.y + 2.6), -0.2],
		["t6_tea", Vector3(c.x + 1.0, 0.0, c.y - 1.0), Vector3(c.x + 5.0, 1.0, c.y - 6.0), -0.15],
		["t7_over", Vector3(c.x - 6.0, 22.0, c.y + 34.0), Vector3(c.x, 1.0, c.y - 4.0), -0.35],
	]
	for s in shots:
		var sp: Vector3 = s[1]
		player.set_distance(5.0)
		var gy := terrain.sample_height(sp.x, sp.z)
		player.global_position = Vector3(sp.x, maxf(gy + 0.4, sp.y), sp.z)
		player.velocity = Vector3.ZERO
		player.locked = true
		_look_at_point(s[2], s[3])
		for i in 70:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[capture] ", s[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]]))
	get_tree().quit()


func _run_capture_race(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	race.manual_step = true
	race.start_race()
	race._layer.visible = true
	for k in 120:
		race.step_race(1.0 / 30.0)
	race.mine.speed = 14.0
	var shots := [["r1_start", 125], ["r2_race", 330], ["r3_hit", 90], ["r4_wreck", 60]]
	for sh in shots:
		for k in int(sh[1]):
			race.step_race(1.0 / 30.0)
			if sh[0] == "r3_hit" and k == 40:
				for r in race.racers:
					if r != race.mine:
						r.place(race.mine.s + 1.5, race.mine.lat + 1.2)
						r.speed = race.mine.speed
						break
				race.mine.atk_cd = 0.0
				race.mine.attack(race.racers)
			if sh[0] == "r4_wreck" and k == 10:
				for r in race.racers:
					if r != race.mine and not r.dead:
						r.take_hit(200.0, 1.0)
						break
			if k % 10 == 0:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[race-state] ", race.state, " mine_hp ", race.mine.hp if race.mine != null else -1.0)
		print("[capture] ", sh[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, sh[0]]))
	# overview of the whole circuit
	race.mine.global_position = Vector3(TerrainBuilder.TRACK_C.x, 120.0, TerrainBuilder.TRACK_C.y)
	get_tree().quit()


func _run_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	# Water, sky and flora shots.
	atmosphere.time_of_day = 0.42
	atmosphere.apply_time()
	var wshots := [
		["01_pond", Vector3(-38.0, 0.0, 66.0), Vector3(-60.0, 0.0, 52.0), -0.12],
		["02_channel", Vector3(-80.0, 0.0, 30.0), Vector3(-88.0, 0.0, 16.0), -0.15],
		["03_sky", Vector3(-20.0, 0.0, 40.0), Vector3(-60.0, 60.0, -200.0), 0.2],
		["04_village", Vector3(-70.0, 0.0, 28.0), Vector3(-92.0, 0.0, 10.0), -0.1],
		["05_temple", Vector3(-35.0, 0.0, 24.0), Vector3(-35.0, 0.0, -10.0), 0.12],
		["06_temple_side", Vector3(-12.0, 0.0, 8.0), Vector3(-35.0, 0.0, -10.0), 0.1],
	]
	for w in wshots:
		var wp: Vector3 = w[1]
		player.set_distance(6.0)
		player.global_position = Vector3(wp.x, terrain.sample_height(wp.x, wp.z) + 0.4, wp.z)
		player.velocity = Vector3.ZERO
		var tgt: Vector3 = w[2]
		if tgt.y == 0.0:
			tgt.y = terrain.sample_height(tgt.x, tgt.z) + 1.0
		_look_at_point(tgt, w[3])
		for i in 60:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, w[0]])
	for tier in 3:
		apply_quality(tier)
		var tp := Vector3(-34.0, terrain.sample_height(-34.0, 70.0) + 0.4, 70.0)
		player.set_distance(6.0)
		player.global_position = tp
		player.velocity = Vector3.ZERO
		_look_at_point(Vector3(-60.0, terrain.pond_level, 52.0), -0.1)
		for i in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/tier_%d_pond.png" % [dir, tier])
		print("[capture] tier %d fps %.1f" % [tier, Engine.get_frames_per_second()])
	apply_quality(0)
	# Story shots: office, dialogue, HUD.
	var ho: Node3D = houses.houses[5].node
	player.set_distance(2.6)
	player.global_position = ho.global_transform * Vector3(0.5, 0.3, 2.4)
	player.velocity = Vector3.ZERO
	_look_at_point(ho.global_transform * Vector3(-1.5, 1.0, -2.0), -0.1)
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/20_office.png" % dir)
	player.set_distance(7.5)
	dlg.open(story.dialogue_for("desk"), null, "man")
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/21_dialogue.png" % dir)
	dlg.close()
	story.set_flag("journal")
	story.set_flag("map")
	story.refresh()
	hud._toggle_journal()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/22_journal.png" % dir)
	hud._toggle_journal()
	for i in 200:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/23_hud.png" % dir)
	# Act 2 shots: Arin, lanterns, seal effect.
	story.set_flag("gate_open")
	story_b.start_act2()
	player.set_distance(7.5)
	_teleport(0.0, -140.0)
	player.global_position = Vector3(2.0, EntranceBuilder.PLATFORM_Y + 0.4, -151.5)
	player.velocity = Vector3.ZERO
	_look_at_point(Vector3(3.0, EntranceBuilder.PLATFORM_Y + 1.5, -161.0), -0.1)
	story_b.story.refs["lanterns"][0].get_node("Flame").scale = Vector3.ONE
	story_b._light(story_b.story.refs["lanterns"][0], true)
	story_b.seal_fx(player.global_position + Vector3(0, 1.0, 0))
	for i in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/24_act2.png" % dir)
	map_ui.toggle_full()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/25_map.png" % dir)
	map_ui.toggle_full()
	var rx := terrain.river_x
	var views := [
		["01_start_viewpoint", Vector2(120, 160), Vector3(0, 22, -168), -0.07],
		["02_valley_approach", Vector2(-5, -85), Vector3(0, 15, -168), -0.08],
		["03_entrance_forecourt", Vector2(0, -120), Vector3(0, 26, -170), 0.2],
		["04_caravan_station", Vector2(18, 86), Vector3(48, 3, 40), -0.16],
		["05_riverbed", Vector2(rx.call(55.0), 55), Vector3(rx.call(-30.0), 0, -30), -0.1],
		["08_goods_train", Vector2(-20, 118), Vector3(-15, 4, 96), -0.04],
		["09_loading_dock", Vector2(-24, 91), Vector3(2, 3, 92), -0.02],
		["11_goods_shed_yard", Vector2(4, 68), Vector3(-9, 3, 85), -0.03],
		["10_goods_train_close", Vector2(-30, 108), Vector3(-5, 5, 96), 0.0],
	]
	for v in views:
		var p: Vector2 = v[1]
		_teleport(p.x, p.y)
		_look_at_point(v[2], v[3])
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [dir, v[0]]
		var err := img.save_png(path)
		print("[capture] %s -> %s (%s)" % [v[0], path, "ok" if err == OK else "error %d" % err])
	# House views: exteriors with the normal camera, then interiors with the camera pulled in.
	var views2 := [
		["06_house_exterior", 0, Vector3(1.0, 0.3, 14.0), Vector3(0, 2.0, 0), 7.5],
		["06b_house_exterior_roof_stairs", 2, Vector3(15.0, 0.3, -3.0), Vector3(2, 2.0, 0), 7.5],
		["07_house_interior_main", 0, Vector3(-3.0, 0.3, -1.0), Vector3(1.0, 1.2, 3.5), 2.4],
		["07b_house_interior_oven_shelf", 0, Vector3(0.5, 0.3, 1.5), Vector3(-5.0, 1.2, 0.3), 2.4],
		["06c_house_workshop_yard", 0, Vector3(-11.0, 0.3, 7.0), Vector3(-6, 1.0, 3), 6.0],
		["07c_house_interior_bedroom", 0, Vector3(2.2, 0.3, 2.2), Vector3(3.2, 0.6, -3.0), 2.4],
	]
	for v2 in views2:
		var hn: Node3D = houses.houses[v2[1]].node
		player.set_distance(v2[4])
		player.global_position = hn.global_transform * v2[2]
		player.velocity = Vector3.ZERO
		_look_at_point(hn.global_transform * v2[3], -0.08)
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := get_viewport().get_texture().get_image()
		print("[capture] %s -> %s" % [v2[0], "ok" if img2.save_png("%s/%s.png" % [dir, v2[0]]) == OK else "error"])
	# Phase 2 UI shots: touch overlay with an interaction prompt, and a message toast.
	touch.visible = true
	player.set_distance(Player.DEFAULT_DISTANCE)
	var hs1: Dictionary = houses.houses[0]
	var d1: Interactable = hs1.door
	var hn1: Node3D = hs1.node
	player.global_position = d1.global_position + hn1.global_transform.basis * Vector3(0, 0, 2.6) - Vector3(0, 0.7, 0)
	player.velocity = Vector3.ZERO
	_look_at_point(d1.global_position, -0.1)
	for i in 40:
		await get_tree().physics_frame
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[capture] 12_ui_door_prompt -> ", get_viewport().get_texture().get_image().save_png("%s/12_ui_door_prompt.png" % dir))
	_teleport(0.0, -120.0)
	player.global_position = Vector3(0.0, EntranceBuilder.PLATFORM_Y + 0.3, -170.0)
	player.velocity = Vector3.ZERO
	_look_at_point(Vector3(0, 8, -176), -0.1)
	for i in 40:
		await get_tree().physics_frame
	player.interact()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[capture] 13_ui_message -> ", get_viewport().get_texture().get_image().save_png("%s/13_ui_message.png" % dir))
	# Characters: walking player (profile) and close-ups of each NPC.
	touch.visible = false
	var model := player.get_node("Model") as Node3D
	_teleport(130.0, 150.0)
	for i in 40:
		await get_tree().physics_frame
	player.set_look(0.0, -0.08)
	player.set_distance(3.6)
	player.move_input = Vector2(1, 0)
	player.sprint = false
	for i in 50:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] 14_player_walk -> ", get_viewport().get_texture().get_image().save_png("%s/14_player_walk.png" % dir))
	player.sprint = true
	for i in 50:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	print("[capture] 14b_player_run -> ", get_viewport().get_texture().get_image().save_png("%s/14b_player_run.png" % dir))
	player.move_input = Vector2.ZERO
	player.sprint = false
	model.visible = false
	var idx := 0
	for np2 in npcs:
		var front2: Vector3 = np2.global_transform.basis * Vector3(0, 0, -1)
		player.global_position = np2.global_position + front2 * 1.3 + Vector3(0, 0.4, 0)
		player.velocity = Vector3.ZERO
		player.set_distance(1.25)
		_look_at_point(np2.global_position + Vector3(0, 1.2, 0), 0.0)
		for i in 40:
			await get_tree().physics_frame
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		idx += 1
		print("[capture] npc_%s -> " % np2.name, get_viewport().get_texture().get_image().save_png("%s/15_npc_%d_%s.png" % [dir, idx, np2.name]))
	# Animals and carts.
	var shots := 0
	for lf in life:
		var tgt: Node3D = lf
		var is_wagon := lf is Wagon
		var an := lf as Animal
		if not is_wagon and an != null and not (an.species in ["cow", "camel", "dog", "horse", "deer"]):
			continue
		shots += 1
		var off := Vector3(7.5, 0.5, 5.0) if is_wagon else Vector3(3.2, 0.5, 2.4)
		player.global_position = tgt.global_position + off
		player.velocity = Vector3.ZERO
		player.set_distance(2.6)
		_look_at_point(tgt.global_position + Vector3(0, 1.1, 0), -0.05)
		for i in 40:
			await get_tree().physics_frame
		for i in 4:
			await get_tree().process_frame
		_look_at_point(tgt.global_position + Vector3(0, 1.1, 0), -0.05)
		await RenderingServer.frame_post_draw
		print("[capture] life_%d -> " % shots, get_viewport().get_texture().get_image().save_png("%s/16_life_%02d_%s.png" % [dir, shots, tgt.name]))
	model.visible = true
	get_tree().quit(0)

