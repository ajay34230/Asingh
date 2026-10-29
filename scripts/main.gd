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
var story: Story
var hud: QuestHUD
var dlg: DialogueUI
var cin: Cinematic
var story_b: StoryBuilder
var menu: GameMenu


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
	var sfx := Sfx.new().setup(player, houses)
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
		if a.begins_with("--capture="):
			_run_capture.call_deferred(a.trim_prefix("--capture="))
			return


func _process(delta: float) -> void:
	atmosphere.update(delta)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	var sp := TerrainBuilder.START_MOUND
	player.position = Vector3(sp.x, terrain.sample_height(sp.x, sp.y) + 0.3, sp.y)
	add_child(player)
	_look_at_point(Vector3(0.0, 22.0, -168.0), -0.07)
	atmosphere.make_dust(player)


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
		if a == "--selftest" or a == "--audit" or a.begins_with("--capture="):
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
		for f in 3:
			await get_tree().physics_frame
		var cp := player.camera.global_position
		if cp.y < terrain.sample_height(cp.x, cp.z) - 0.02:
			below += 1
	notes.append("camera below ground: %d / 30" % below)
	if below > 0:
		fails.append("camera went below ground in %d cases" % below)

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
		story.flags.clear()
		player.global_position = keep_pos
	notes.append("save/load checked")

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

func _run_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
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
