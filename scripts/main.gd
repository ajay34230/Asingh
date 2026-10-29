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
	_spawn_player()
	_build_ui()
	print("[LostKingdom] world built in %d ms" % (Time.get_ticks_msec() - t0))

	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_run_selftest.call_deferred()
		return
	for a in args:
		if a.begins_with("--capture="):
			_run_capture.call_deferred(a.trim_prefix("--capture="))
			return


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	var sp := TerrainBuilder.START_MOUND
	player.position = Vector3(sp.x, terrain.sample_height(sp.x, sp.y) + 0.3, sp.y)
	add_child(player)
	_look_at_point(Vector3(0.0, 22.0, -168.0), -0.07)
	atmosphere.make_dust(player)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	touch = TouchControls.new()
	touch.player = player
	layer.add_child(touch)


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
	for i in 480:
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
	for i in 130:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
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
	for i in 150:
		await get_tree().physics_frame
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
	for i in 90:
		await get_tree().physics_frame
	player.move_input = Vector2.ZERO
	notes.append("boxcar: player at %s" % [player.global_position.snappedf(0.1)])
	if player.global_position.z < RailwayBuilder.RAIL_Z - 1.2 or player.global_position.y < RailwayBuilder.RAIL_Y + RailwayBuilder.DOCK_H - 0.3:
		fails.append("player did not enter the boxcar")

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

	for s in notes:
		print("[selftest] ", s)
	if fails.is_empty():
		print("[selftest] PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			printerr("[selftest] FAIL: ", f)
		get_tree().quit(1)


# --- screenshot capture (needs a rendering backend, e.g. xvfb + software GL) ------------

func _run_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	touch.visible = false
	var rx := terrain.river_x
	var views := [
		["01_start_viewpoint", Vector2(120, 160), Vector3(0, 22, -168), -0.07],
		["02_valley_approach", Vector2(-5, -85), Vector3(0, 15, -168), -0.08],
		["03_entrance_forecourt", Vector2(0, -120), Vector3(0, 26, -170), 0.2],
		["04_caravan_station", Vector2(18, 86), Vector3(48, 3, 40), -0.16],
		["05_riverbed", Vector2(rx.call(55.0), 55), Vector3(rx.call(-30.0), 0, -30), -0.1],
		["08_goods_train", Vector2(-20, 118), Vector3(-15, 4, 96), -0.04],
		["09_loading_dock", Vector2(-24, 91), Vector3(2, 3, 92), -0.02],
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
	get_tree().quit(0)
