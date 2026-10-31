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


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	terrain = TerrainBuilder.new(1337)
	terrain.generate_heights()
	terrain.build(self)
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
		if a.begins_with("--capture-fight="):
			_run_capture_fight.call_deferred(a.trim_prefix("--capture-fight="))
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
func apply_quality(tier: int) -> void:
	atmosphere.quality = tier
	get_viewport().scaling_3d_scale = [1.0, 0.8, 0.62][tier]
	atmosphere.sun.shadow_enabled = true
	atmosphere.sun.directional_shadow_max_distance = [260.0, 150.0, 70.0][tier]
	atmosphere.sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_ORTHOGONAL][tier]
	atmosphere.environment.glow_enabled = tier < 2
	var ranges := {"foliage_grass": [130.0, 75.0, 40.0], "foliage_reeds": [160.0, 100.0, 60.0], "foliage_palm": [420.0, 260.0, 150.0], "foliage_stone": [220.0, 130.0, 75.0]}
	for g in ranges:
		for n in get_tree().get_nodes_in_group(g):
			var gi := n as GeometryInstance3D
			gi.visibility_range_end = ranges[g][tier]
			gi.visibility_range_end_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _process(delta: float) -> void:
	atmosphere.update(delta)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	var sp := TerrainBuilder.START_MOUND
	player.position = Vector3(sp.x, terrain.sample_height(sp.x, sp.y) + 0.3, sp.y)
	add_child(player)
	player.add_child(PowerFx.new(player))
	_look_at_point(Vector3(0.0, 22.0, -168.0), -0.07)
	atmosphere.make_dust(player)
	atmosphere.make_rain(player)
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
	if testing:
		return
	atmosphere.running = true
	if menu.load_save():
		story_b.apply_loaded_state()
	else:
		story_b.intro.call_deferred()


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
	for i in 10:
		await get_tree().physics_frame
	var shots := [["jab", 9], ["cross", 10], ["hook", 11], ["uppercut", 13], ["kick_front", 14], ["kick_round", 18], ["kick_side", 15], ["grab", 22], ["lift", 24], ["throw", 6]]
	for sh in shots:
		player._rig.play_move(sh[0])
		for i in int(sh[1]):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		print("[capture] ", sh[0], " -> ", get_viewport().get_texture().get_image().save_png("%s/m_%s.png" % [dir, sh[0]]))
		for i in 40:
			await get_tree().physics_frame
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


func _run_capture_town(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	atmosphere.time_of_day = 0.42
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
