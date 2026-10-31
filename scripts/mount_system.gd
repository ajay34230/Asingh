class_name MountSystem
extends Node
## Ride any big animal: camel, horse, donkey or bull. Walk up, press the Ride prompt, steer with the
## stick (camera-relative), push far for a gallop, tap JUMP to dismount.

const RIDEABLE := {
	"horse": [3.4, 12.0], "horse_white": [3.4, 12.5], "camel": [2.8, 8.5], "donkey": [2.6, 7.0], "bull": [3.0, 9.5],
}
var main: Node3D
var player: Player
var terrain: TerrainBuilder
var mount: Animal = null
var _heading := 0.0
var _speed := 0.0
var _step_t := 0.0
var _print_d := 0.0
var _dist_saved := 6.0
var last_block := ""             # what stopped the animal last (diagnostics)


func _init(m: Node3D, p: Player, t: TerrainBuilder) -> void:
	main = m
	player = p
	terrain = t
	name = "MountSystem"


func build() -> void:
	main.add_child(self)
	var n := 0
	for c in main.life:
		var a := c as Animal
		if a != null and RIDEABLE.has(a.species) and not a.driven:
			_attach(a)
			n += 1
	set_meta("count", n)


func _attach(a: Animal) -> void:
	var it := Interactable.new()
	var h: float = float(Animal.SPECIES[a.species]["height"])
	it.position = Vector3(0, h * 0.8, 0)
	it.prompt = "Ride the %s" % a.species.replace("_", " ")
	it.reach = 3.2
	it.on_interact = func(_by: Node3D, _me: Interactable) -> void: mount_animal(a)
	a.add_child(it)


func mount_animal(a: Animal) -> void:
	if mount != null or player.locked or player.dead:
		return
	mount = a
	a.driven = true
	_heading = a.rotation.y
	_speed = 0.0
	player.locked = true
	player.mounted = true
	player.jump_requested = false
	_dist_saved = player._target_distance
	player.set_distance(7.5)
	player._rig.set_react("ride")
	Sfx.at(Animal.CALLS.get(a.species, ["cow_moo"])[0], a.global_position + Vector3(0, 1.2, 0), -3.0)
	player.say("You swing onto the %s. Push the stick to ride; tap JUMP to get down." % a.species.replace("_", " "))


func dismount() -> void:
	if mount == null:
		return
	var a := mount
	var side := Vector3(cos(a.rotation.y), 0.0, -sin(a.rotation.y))
	var p := a.global_position + side * 1.6
	p.y = terrain.sample_height(p.x, p.z) + 0.4
	player.global_position = p
	player.velocity = Vector3.ZERO
	player._rig.set_react("")
	player.locked = false
	player.mounted = false
	player.set_distance(_dist_saved)
	a.driven = false
	a.home = a.global_position
	a.play_walk(false)
	a.rotation.x = 0.0
	mount = null


func _physics_process(delta: float) -> void:
	if mount == null:
		return
	if not is_instance_valid(mount) or player.dead:
		if is_instance_valid(mount):
			dismount()
		else:
			mount = null
			player.locked = false
			player.mounted = false
			player._rig.set_react("")
		return
	if player.jump_requested or Input.is_physical_key_pressed(KEY_E):
		player.jump_requested = false
		dismount()
		return
	var a := mount
	var sp: Array = RIDEABLE[a.species]
	var inp := player.move_input
	if inp.length() < 0.05:
		inp = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var want_speed := 0.0
	if inp.length() > 0.12:
		var dir := Basis(Vector3.UP, player._yaw) * Vector3(inp.x, 0.0, inp.y)
		_heading = lerp_angle(_heading, atan2(-dir.x, -dir.z), 1.0 - exp(-5.0 * delta))
		var run := player.sprint or inp.length() > 0.85
		want_speed = float(sp[1]) if run else float(sp[0])
	_speed = move_toward(_speed, want_speed, (7.0 if want_speed > _speed else 12.0) * delta)
	a.rotation.y = _heading
	var fwd := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var step := fwd * _speed * delta
	# do not ride through walls, houses or trees
	if _speed > 0.1:
		var q := PhysicsRayQueryParameters3D.create(a.global_position + Vector3(0, 0.8, 0), a.global_position + Vector3(0, 0.8, 0) + fwd * (a.length * 0.5 + 1.0))
		q.exclude = [player.get_rid()]
		var hit := main.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.6:
			step = Vector3.ZERO
			_speed = 0.0
			last_block = str((hit["collider"] as Node).get_path())
	var np := a.global_position + step
	np.x = clampf(np.x, -195.0, 195.0)
	np.z = clampf(np.z, -195.0, 195.0)
	np.y = terrain.sample_height(np.x, np.z)
	a.global_position = np
	# pitch with the slope
	var ahead := terrain.sample_height(np.x + fwd.x * 1.2, np.z + fwd.z * 1.2)
	var behind := terrain.sample_height(np.x - fwd.x * 1.2, np.z - fwd.z * 1.2)
	a.rotation.x = lerpf(a.rotation.x, -atan2(ahead - behind, 2.4), 1.0 - exp(-8.0 * delta))
	# gait
	if a._anim != null:
		var run_gait := _speed > float(sp[0]) * 1.6 and a._has_gallop
		var want := a._gallop if run_gait else (a._walk if _speed > 0.3 else a._idle)
		if a._anim.current_animation != want:
			a._anim.play(want, 0.25)
		a._anim.speed_scale = clampf(_speed / (float(sp[0]) if not run_gait else float(sp[1]) * 0.55), 0.6, 2.2) if _speed > 0.3 else 1.0
	if _speed > 0.5:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = clampf(2.4 / maxf(_speed, 1.0), 0.18, 0.7)
			Sfx.at("hoof_%d" % randi_range(0, 1), a.global_position, -4.0 if _speed < float(sp[0]) * 1.6 else -1.0, randf_range(0.9, 1.1))
	if _speed > 0.5 and main.get("footprints") != null:
		_print_d += _speed * delta
		if _print_d > 0.9:
			_print_d = 0.0
			var sd := Vector3(cos(_heading), 0.0, -sin(_heading))
			(main.get("footprints") as Footprints).put(a.global_position + fwd * 0.9 + sd * 0.35, _heading, 1.4)
			(main.get("footprints") as Footprints).put(a.global_position - fwd * 0.9 - sd * 0.35, _heading, 1.4)
	# the rider sits on its back
	var h: float = float(Animal.SPECIES[a.species]["height"])
	player.global_position = a.global_position + Vector3(0, h * 0.8 - 0.42, 0) + Basis(Vector3(1, 0, 0), a.rotation.x) * Vector3(0, 0, 0.1)
	player.velocity = Vector3.ZERO
	player._model.rotation.y = _heading
