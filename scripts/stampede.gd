class_name Stampede
extends Node
## "Raid on the Road": a mid-journey set-piece. A raid horn sounds, Reavers stampede the valley's herd
## straight across the player's path (14 bulls, horses, cows, donkeys and camels in a dust cloud). The
## player can dodge or ride it out; being trampled hurts. When the herd has passed, a band of Reavers
## closes in. Beat them to earn coins and a frightened white horse left behind that can be ridden.
## It starts once, a few minutes after the intro, while the player is free to move.

const HERD := ["bull", "cow", "horse", "horse_white", "donkey", "camel", "cow", "bull", "horse", "donkey", "cow", "camel", "bull", "horse"]
const START_AFTER := 200.0         # seconds of free play after the intro
const RUN_SPEED := 10.5
const LEAD := 105.0                # herd starts this far from the player

var main: Node3D
var player: Player
var terrain: TerrainBuilder
var story: Story
var state := "wait"                # wait, warn, run, fight, done
var herd: Array[Animal] = []
var raiders: Array[Enemy] = []
var _t := 0.0
var _free := 0.0
var _dir := Vector3(1, 0, 0)
var _centre := Vector3.ZERO
var _travel := 0.0
var _hurt_cd := 0.0
var _hoof_t := 0.0
var _dust: CPUParticles3D
var _offsets: Array[Vector2] = []


func _init(m: Node3D, p: Player, t: TerrainBuilder, s: Story) -> void:
	main = m
	player = p
	terrain = t
	story = s
	name = "Stampede"


func _process(delta: float) -> void:
	step(delta)


func _can_start() -> bool:
	if story == null or not story.get_flag("intro_done") or story.get_flag("stampede_done"):
		return false
	if player.locked or player.dead or player.mounted or player.carried_by != null:
		return false
	var pp := Vector2(player.global_position.x, player.global_position.z)
	if pp.distance_to(TerrainBuilder.TOWN_C) < 75.0 or pp.distance_to(TerrainBuilder.TRACK_C) < 75.0 or pp.distance_to(TerrainBuilder.FOREST_C) < 70.0:
		return false
	var rc: Object = main.get("race")
	if rc != null and str(rc.get("state")) != "idle":
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not bool((e as Node).get("dead")) and (e as Node3D).global_position.distance_to(player.global_position) < 60.0:
			return false
	return true


func step(delta: float) -> void:
	match state:
		"wait":
			if _can_start():
				_free += delta
				if _free >= START_AFTER:
					start()
		"warn":
			_t -= delta
			if _t <= 0.0:
				state = "run"
		"run":
			_run(delta)
		"fight":
			_fight(delta)


## Begin the event now (also used by the self-test).
func start() -> void:
	state = "warn"
	_t = 5.0
	var pp := player.global_position
	var ang := randf() * TAU
	var from := Vector3(pp.x + cos(ang) * LEAD, 0.0, pp.z + sin(ang) * LEAD)
	from.x = clampf(from.x, -185.0, 185.0)
	from.z = clampf(from.z, -185.0, 185.0)
	_dir = Vector3(pp.x - from.x, 0.0, pp.z - from.z)
	_dir = _dir.normalized() if _dir.length() > 1.0 else Vector3(1, 0, 0)
	_centre = from
	_travel = 0.0
	_offsets.clear()
	for i in HERD.size():
		var a := Animal.new().setup(HERD[i], terrain, player, Vector3.ZERO, 1.0)
		a.driven = true
		main.add_child(a)
		var lat := randf_range(-9.0, 9.0)
		var dep := randf_range(-10.0, 10.0)
		_offsets.append(Vector2(lat, dep))
		a.global_position = _herd_pos(i)
		a.rotation.y = atan2(-_dir.x, -_dir.z)
		a.add_to_group("stampede")
		if a._anim != null:
			a._anim.play(a._gallop if a._has_gallop else a._walk, 0.1)
			a._anim.speed_scale = 1.5
		herd.append(a)
	_dust = CPUParticles3D.new()
	_dust.amount = 90
	_dust.lifetime = 3.0
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 50.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0, 0.5, 0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(9.0, 0.3, 11.0)
	_dust.scale_amount_min = 2.5
	_dust.scale_amount_max = 6.0
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	_dust.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.78, 0.62, 0.42, 0.32)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dust.material_override = pm
	main.add_child(_dust)
	var atmo: Atmosphere = main.get("atmosphere") as Atmosphere
	if atmo != null:
		atmo.set_weather("overcast", 150.0)
	Sfx.sting("danger", -2.0)
	Sfx.ui_at("raid_horn", -2.0)
	var hud: Object = main.get("hud")
	if hud != null:
		hud.call("banner", "A raid horn! Reavers are stampeding the herd. Get off the road!")


func _herd_pos(i: int) -> Vector3:
	var side := Vector3(-_dir.z, 0.0, _dir.x)
	var o := _offsets[i]
	var p := _centre + side * o.x + _dir * o.y
	p.y = terrain.sample_height(p.x, p.z)
	return p


func _run(delta: float) -> void:
	_centre += _dir * RUN_SPEED * delta
	_travel += RUN_SPEED * delta
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	_hoof_t -= delta
	var near := INF
	for i in herd.size():
		var a := herd[i]
		if not is_instance_valid(a):
			continue
		var wob := sin(_travel * 0.9 + float(i) * 1.7) * 0.9
		var side := Vector3(-_dir.z, 0.0, _dir.x)
		var p := _herd_pos(i) + side * wob
		p.y = terrain.sample_height(p.x, p.z)
		a.global_position = p
		a.rotation.y = atan2(-_dir.x, -_dir.z)
		var d := a.global_position.distance_to(player.global_position)
		near = minf(near, d)
		if d < 2.3 and _hurt_cd <= 0.0 and not player.mounted:
			_hurt_cd = 0.7
			var away := player.global_position - a.global_position
			away.y = 0.0
			player.take_damage(14.0, away if away.length() > 0.1 else side)
	_dust.global_position = _centre + Vector3(0, 0.5, 0)
	if _hoof_t <= 0.0 and near < 90.0:
		_hoof_t = 0.14
		var h := herd[randi() % herd.size()]
		if is_instance_valid(h):
			Sfx.at("hoof_%d" % randi_range(0, 1), h.global_position, clampf(3.0 - near * 0.03, -8.0, 3.0), randf_range(0.7, 0.95))
		if near < 45.0 and randf() < 0.4:
			StoryFX.shake(player, clampf(0.12 - near * 0.002, 0.02, 0.1), 0.2)
	# the herd has thundered past and gone: the raiders follow it
	var rel := _centre - player.global_position
	if _travel > LEAD * 2.0 + 40.0 and rel.dot(_dir) > 70.0:
		_end_herd()
		_raiders()


func _end_herd() -> void:
	for a in herd:
		if is_instance_valid(a):
			a.queue_free()
	herd.clear()
	if _dust != null:
		_dust.emitting = false
		_dust.queue_free()
		_dust = null


func _raiders() -> void:
	state = "fight"
	var cb: CombatBuilder = main.get("combat") as CombatBuilder
	if cb != null:
		var back := player.global_position - _dir * 38.0
		for i in 4:
			var p := back + Vector3(-_dir.z, 0.0, _dir.x) * (float(i) - 1.5) * 4.0
			p.y = terrain.sample_height(p.x, p.z) + 0.3
			raiders.append(cb.spawn_enemy(p, false, 90.0, "stampede"))
	Sfx.sting("danger", -3.0)
	var hud: Object = main.get("hud")
	if hud != null:
		hud.call("banner", "The raiders who spooked the herd are closing in. Fight them off!")


func _fight(_delta: float) -> void:
	for e in raiders:
		if is_instance_valid(e) and not e.dead:
			return
	finish()


func finish() -> void:
	state = "done"
	story.set_flag("stampede_done", true)
	story.add("coins", 120)
	var atmo: Atmosphere = main.get("atmosphere") as Atmosphere
	if atmo != null:
		atmo.release_weather()
	# a frightened white horse is left on the road, and it will carry the player
	var p := player.global_position + Vector3(6.0, 0.0, 4.0)
	p.y = terrain.sample_height(p.x, p.z)
	var h := Animal.new().setup("horse_white", terrain, player, Vector3.ZERO, 6.0)
	main.add_child(h)
	h.global_position = p
	h.home = p
	var ms: MountSystem = main.get("mounts") as MountSystem
	if ms != null:
		ms._attach(h)
	Sfx.sting("victory", -4.0)
	var hud: Object = main.get("hud")
	if hud != null:
		hud.call("banner", "You drove off the raiders. +120 coins. A white horse the Reavers dropped will carry you.")
