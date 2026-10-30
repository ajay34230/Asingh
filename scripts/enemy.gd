class_name Enemy
extends CharacterBody3D
## A hostile human (Dust Reaver or its captain): patrols near `home`, chases the player within
## AGGRO metres, winds up and swings. Uses the same downloaded character models as the NPCs.
## Dies with a short fall, may drop a power-up. Collides with the world via move_and_slide.

signal died(enemy: Enemy)

const GRAVITY := 24.0
var rig: RealHuman
var player: Player
var home := Vector3.ZERO
var leash := 45.0
var aggro := 15.0
var hp := 60.0
var max_hp := 60.0
var damage := 9.0
var speed := 3.4
var attack_cd := 1.5
var kind := "reaver"
var drop_chance := 0.55
var is_boss := false
var dead := false
var _cd := 1.0
var _winding := -1.0
var _patrol_t := 0.0
var _patrol_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _flash := 0.0
var _hp_bar: Label3D
var _spawn_pickup := Callable()      # set by whoever creates enemies: func(pos, kind)


func setup(preset: Dictionary, at: Vector3, label: String) -> Enemy:
	name = label
	add_to_group("enemies")
	_rng.seed = hash(label) + int(at.x * 7.0)
	home = at
	rig = RealHuman.new().setup(preset, label)
	add_child(rig)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38 * float(preset.get("scale", 1.0))
	cap.height = 1.7 * float(preset.get("scale", 1.0))
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_hp_bar = Label3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	_hp_bar.fixed_size = true
	_hp_bar.pixel_size = 0.0009
	_hp_bar.font_size = 40
	_hp_bar.outline_size = 10
	_hp_bar.modulate = Color(1.0, 0.35, 0.3)
	_hp_bar.position.y = 2.25 * float(preset.get("scale", 1.0))
	add_child(_hp_bar)
	rig.attack_hit.connect(_on_swing)
	_refresh_bar()
	global_position = at
	return self


func _refresh_bar() -> void:
	var n := clampi(int(ceil(10.0 * hp / max_hp)), 0, 10)
	_hp_bar.text = ("BOSS " if is_boss else "") + "▮".repeat(n) + "▯".repeat(10 - n)


func take_damage(amount: float, from_dir: Vector3) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.25
	velocity += from_dir.normalized() * 4.5
	_winding = -1.0
	rig.play_action("startle", 0.5)
	Sfx.at("hit_hurt", global_position + Vector3(0, 1.2, 0), -2.0, _rng.randf_range(0.9, 1.1))
	_refresh_bar()
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	_hp_bar.visible = false
	collision_layer = 0
	collision_mask = 1
	Sfx.at("enemy_down", global_position + Vector3(0, 1.0, 0), -2.0)
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(rig, "position:y", -1.2, 1.2)
	tw.tween_callback(queue_free)
	if _spawn_pickup.is_valid() and (is_boss or _rng.randf() < drop_chance):
		var kinds := ["health", "health", "speed", "power", "shield"]
		_spawn_pickup.call(global_position + Vector3(0, 0.6, 0), kinds[_rng.randi() % kinds.size()])
	died.emit(self)


func _on_swing() -> void:
	if dead or player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	if to.length() < 2.6 and (to.length() < 0.5 or fwd.dot(to.normalized()) > 0.1):
		player.take_damage(damage, to)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0
	_cd -= delta
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var want := Vector3.ZERO
	var chasing := player != null and not player.dead and dist < aggro and global_position.distance_to(home) < leash + aggro
	if chasing:
		rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), minf(1.0, 8.0 * delta))
		if _winding >= 0.0:
			_winding += delta
			if _winding > 0.45:
				_winding = -1.0
		elif dist > 1.9:
			want = to_p.normalized() * speed
		elif _cd <= 0.0:
			_cd = attack_cd
			_winding = 0.0
			rig.start_attack()
			Sfx.at("swing", global_position + Vector3(0, 1.2, 0), -6.0, _rng.randf_range(0.9, 1.1))
	else:
		_patrol_t -= delta
		if _patrol_t <= 0.0:
			_patrol_t = _rng.randf_range(3.0, 8.0)
			var a := _rng.randf() * TAU
			_patrol_target = home + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.0, 7.0)
		var d := _patrol_target - global_position
		d.y = 0.0
		if d.length() > 1.0:
			want = d.normalized() * speed * 0.35
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, 4.0 * delta))
	velocity.x = lerpf(velocity.x, want.x, 1.0 - exp(-10.0 * delta))
	velocity.z = lerpf(velocity.z, want.z, 1.0 - exp(-10.0 * delta))
	move_and_slide()
	rig.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor())
