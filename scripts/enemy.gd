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
var surrendered := false
var held := false                    # being carried by the player
var on_surrender := Callable()       # optional: func(enemy) when this man begs for mercy (story hooks)
var confesses := false               # surrenders at low health and talks (the forest ringleader)
var voice_type := "deep"
var _stun := 0.0
var _down := 0.0                     # seconds left lying after a knockdown
var _flying := false
var _bubble: Label3D
var _bubble_t := 0.0
var _flee_dir := Vector3.ZERO
var _plead_t := 0.0
var _death_style := -1
var role := "grunt"                  # X11: grunt, shield, archer, brute, ambusher
var enraged := false                 # X14: boss second phase
var _shot_cd := 1.5
var _stomp_cd := 4.0
var shots_fired := 0


## X11: give this man a fighting style. Safe to call once, right after setup.
func apply_role(r: String) -> void:
	role = r
	match r:
		"shield":
			hp *= 1.3
			max_hp = hp
			speed *= 0.9
			_hp_bar.modulate = Color(0.55, 0.7, 1.0)
		"archer":
			hp *= 0.7
			max_hp = hp
			aggro = maxf(aggro, 18.0)
			_hp_bar.modulate = Color(1.0, 0.85, 0.3)
		"brute":
			hp *= 1.8
			max_hp = hp
			damage *= 1.5
			speed *= 0.8
			attack_cd *= 1.2
			_hp_bar.modulate = Color(0.9, 0.2, 0.9)
		"ambusher":
			hp *= 0.7
			max_hp = hp
			speed *= 1.5
			aggro = maxf(aggro, 20.0)
			_hp_bar.modulate = Color(0.4, 1.0, 0.5)
	_refresh_bar()


## X11: archers loose a visible arrow that lands where you were; keep moving or block.
func shoot() -> void:
	if player == null or dead:
		return
	shots_fired += 1
	var from := global_position + Vector3(0, 1.5, 0)
	var target := player.global_position + Vector3(0, 1.1, 0)
	var arrow := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.025
	bm.bottom_radius = 0.025
	bm.height = 0.9
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.45, 0.32, 0.18)
	bm.material = am
	arrow.mesh = bm
	get_parent().add_child(arrow)
	arrow.global_position = from
	var dirv := (target - from)
	arrow.look_at(target, Vector3.UP)
	arrow.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	Sfx.at("swing", from, -4.0, 1.4)
	var t := maxf(0.25, dirv.length() / 16.0)
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "global_position", target, t)
	tw.tween_callback(func() -> void:
		if is_instance_valid(player) and not player.dead and player.global_position.distance_to(target - Vector3(0, 1.1, 0)) < 1.3:
			player.take_damage(damage * 0.7, (target - from))
		arrow.queue_free())


## X14: below half health a boss gets faster, angrier and starts stomping.
func enrage() -> void:
	if enraged:
		return
	enraged = true
	speed *= 1.25
	attack_cd *= 0.7
	_hp_bar.modulate = Color(1.0, 0.1, 0.1)
	say("ENOUGH! I will bury you!")
	if player != null:
		StoryFX.shake(player, 0.2, 0.6)
	Sfx.at("war_roar", global_position + Vector3(0, 1.5, 0), 2.0)


func _stomp() -> void:
	_stomp_cd = 5.0
	say("Feel this!")
	await get_tree().create_timer(0.7).timeout
	if dead or not is_instance_valid(player):
		return
	HitFx.burst(get_parent(), global_position + Vector3(0, 0.15, 0), true, Color(0.8, 0.7, 0.5))
	StoryFX.shake(player, 0.18, 0.4)
	if player.global_position.distance_to(global_position) < 4.5 and player.is_on_floor():
		player.take_damage(damage * 1.2, player.global_position - global_position)

const PLEAS := [
	"Please, no more! I surrender!", "Mercy! I have children at home!", "I'm sorry, I'm sorry! Don't kill me!",
	"It was only for the gold! Let me go!", "Stop! Please stop! I give up!", "Have mercy, I beg you!",
]
const CONFESSION := "Please! The man who paid us wore a council ring with the sun on it. I never saw his face, I swear it!"
const CRIES := ["It hurts, it hurts...", "I did not want this...", "Mother..."]


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
	rig.move_hit.connect(func(_m: String) -> void: _on_swing())
	voice_type = str(preset.get("voice", "deep"))
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.pixel_size = 0.0042
	_bubble.font_size = 42
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
	_bubble.modulate = Color(1.0, 0.9, 0.8, 1.0)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.width = 560.0
	_bubble.position = Vector3(0, 2.7, 0)
	_bubble.visible = false
	add_child(_bubble)
	_refresh_bar()
	position = at       # set_global_position needs the tree; setup runs before add_child (callers add us at the origin)
	return self


func _refresh_bar() -> void:
	var n := clampi(int(ceil(10.0 * hp / max_hp)), 0, 10)
	_hp_bar.text = ("BOSS " if is_boss else "") + "▮".repeat(n) + "▯".repeat(10 - n)


func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = clampf(1.8 + text.length() * 0.06, 2.5, 6.0)
	Sfx.speak(voice_type, text, self, -2.0)


func _pain_sfx(strong: bool) -> void:
	var n := "pain_%d" % _rng.randi_range(0, 2) if strong else "grunt_%d" % _rng.randi_range(0, 2)
	Sfx.at(n, global_position + Vector3(0, 1.5, 0), 0.0, _rng.randf_range(0.9, 1.1))


## Generic hit (hammer): small reaction.
## S2: a parry or heavy block leaves the attacker open for a moment.
func stagger(dur: float) -> void:
	if dead:
		return
	_stun = maxf(_stun, dur)
	_winding = -1.0
	_cd = maxf(_cd, dur)


func take_damage(amount: float, from_dir: Vector3) -> void:
	take_hit("hammer", amount, from_dir)


## kind: punch, kick, round, hammer, slam. Plays the right reaction, then dies or begs if low.
func take_hit(kind: String, amount: float, from_dir: Vector3) -> void:
	if dead or surrendered:
		return
	if role == "shield" and (kind == "punch" or kind == "kick"):
		var fwd_s := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		if fwd_s.dot(-from_dir.normalized()) > 0.3:      # blocked on the shield; kicks of the round or slam kind break guard
			amount *= 0.25
			Sfx.at("hit_thud", global_position + Vector3(0, 1.2, 0), -6.0, 1.6)
	hp -= amount
	_flash = 0.25
	if is_boss and not enraged and hp > 0.0 and hp < max_hp * 0.5:
		enrage()
	HitFx.burst(get_parent(), global_position + Vector3(0, 1.1, 0), kind != "punch")
	var dir := from_dir
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	_winding = -1.0
	_refresh_bar()
	if hp <= 0.0:
		_die(kind, dir)
		return
	if (confesses or (not is_boss and _rng.randf() < 0.35)) and hp < max_hp * (0.4 if confesses else 0.25):
		_surrender()
		return
	match kind:
		"punch":
			velocity += dir * 2.5
			_stun = 0.35
			rig.set_react("flinch")
			_pain_sfx(false)
		"kick":
			velocity += dir * 6.0
			_stun = 0.7
			rig.set_react("stagger")
			_pain_sfx(true)
		"round", "slam":
			velocity += dir * 9.0
			velocity.y = 3.0
			_knockdown(1.8)
			_pain_sfx(true)
		_:
			velocity += dir * 4.5
			_stun = 0.4
			rig.set_react("flinch")
			_pain_sfx(false)


func _knockdown(dur: float) -> void:
	_down = dur
	_stun = dur
	rig.set_react("")
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -PI * 0.5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rig, "position:y", 0.12, 0.05)
	tw.tween_interval(maxf(0.1, dur - 0.9))
	tw.tween_callback(func() -> void:
		rig.set_react("stagger"))
	tw.tween_property(rig, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(rig, "position:y", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if not dead:
			rig.set_react(""))
	Sfx.at("body_fall", global_position, -4.0, 1.1)


## Grabbed by the player: dangles above the player's head until thrown.
func begin_held() -> void:
	held = true
	_winding = -1.0
	rig.set_react("held")
	rig.rotation.x = -0.9
	collision_layer = 0
	_pain_sfx(true)
	Sfx.at("scream", global_position + Vector3(0, 1.5, 0), -6.0, 1.0)


func throw_from(thrower: Node3D, dir: Vector3) -> void:
	held = false
	_flying = true
	collision_layer = 1
	velocity = dir.normalized() * 11.0 + Vector3(0, 5.5, 0)
	global_position += Vector3(0, 0.2, 0)
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -PI * 1.5, 0.7).from(rig.rotation.x)
	Sfx.at("whoosh_throw", global_position, -2.0)


func _landed() -> void:
	_flying = false
	rig.rotation.x = -PI * 0.5
	Sfx.at("body_slam", global_position, 0.0)
	StoryFX.shake(player, 0.14, 0.35)
	take_hit_ground(30.0)


func take_hit_ground(amount: float) -> void:
	hp -= amount
	_flash = 0.3
	_refresh_bar()
	if hp <= 0.0:
		_die("slam", Vector3.ZERO)
		return
	_pain_sfx(true)
	rig.set_react("stagger")
	_down = 2.2
	_stun = 2.2
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(rig, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if not dead:
			rig.set_react(""))


## The man is beaten: kneels, drops his weapon, begs and cries. Counts as defeated.
func _surrender() -> void:
	surrendered = true
	remove_from_group("enemies")
	_hp_bar.visible = false
	_winding = -1.0
	_down = 0.0
	rig.set_react("plead")
	Sfx.at("whimper_%d" % _rng.randi_range(0, 1), global_position + Vector3(0, 1.0, 0), -2.0)
	var line: String = CONFESSION if confesses else str(PLEAS[_rng.randi() % PLEAS.size()])
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(self):
			say(line))
	get_tree().create_timer(4.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			rig.set_react("sob")
			Sfx.at("cry_loop", global_position + Vector3(0, 1.0, 0), -4.0))
	_plead_t = 8.0
	if on_surrender.is_valid():
		on_surrender.call(self)
	died.emit(self)


func _die(kind: String, dir: Vector3) -> void:
	dead = true
	var ach := get_tree().get_first_node_in_group("achievements")
	if ach != null:
		ach.note_kill(role, false)
	var cs := get_tree().get_first_node_in_group("companion_system")
	if cs != null:
		cs.note_kill()
	var itm := get_tree().get_first_node_in_group("items")
	if itm != null:
		itm.loot(role, _rng)
	remove_from_group("enemies")
	if player != null and global_position.distance_to(player.global_position) < 5.0:
		var others := 0
		for o in get_tree().get_nodes_in_group("enemies"):
			if (o as Node3D).global_position.distance_to(player.global_position) < 25.0:
				others += 1
		if others == 0:
			StoryFX.hitstop(0.45)       # X13: slow-motion finisher on the last man standing
			StoryFX.shake(player, 0.1, 0.5)
	_hp_bar.visible = false
	collision_layer = 0
	collision_mask = 1
	held = false
	# a different way of dying each time
	_death_style = _rng.randi() % 5
	if kind == "slam" or kind == "round":
		_death_style = 4
	var back := dir
	var tw := create_tween()
	match _death_style:
		0:   # staggers back and falls flat on his back
			rig.set_react("stagger")
			velocity += back * 5.0
			Sfx.at("death_0", global_position + Vector3(0, 1.4, 0), 0.0)
			tw.tween_interval(0.45)
			tw.tween_callback(func() -> void: rig.set_react("dead"))
			tw.tween_property(rig, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		1:   # clutches his body, drops to his knees and falls on his face
			rig.set_react("clutch")
			Sfx.at("death_1", global_position + Vector3(0, 1.2, 0), 0.0)
			tw.tween_interval(1.1)
			tw.tween_property(rig, "rotation:x", PI * 0.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: Sfx.at("body_fall", global_position, -2.0))
		2:   # screams, spins and drops
			rig.set_react("stagger")
			Sfx.at("scream", global_position + Vector3(0, 1.5, 0), -2.0, 0.85)
			tw.tween_property(rig, "rotation:y", rig.rotation.y + TAU * 0.8, 0.55)
			tw.parallel().tween_property(rig, "rotation:z", PI * 0.5, 0.55).set_delay(0.2)
			tw.tween_callback(func() -> void:
				rig.set_react("dead")
				Sfx.at("body_fall", global_position, -2.0))
		3:   # kneels, sways, gasps and topples sideways
			rig.set_react("plead")
			Sfx.at("gasp", global_position + Vector3(0, 1.2, 0), 0.0)
			Sfx.at("death_2", global_position + Vector3(0, 1.2, 0), -2.0, 0.9)
			tw.tween_interval(1.4)
			tw.tween_property(rig, "rotation:z", -PI * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				rig.set_react("dead")
				Sfx.at("body_fall", global_position, -2.0))
		_:   # hurled backwards and rolls to a stop
			velocity += back * 9.0 + Vector3(0, 3.0, 0)
			rig.set_react("stagger")
			Sfx.at("scream", global_position + Vector3(0, 1.5, 0), -2.0, 1.1)
			tw.tween_property(rig, "rotation:x", -PI * 0.5, 0.35)
			tw.tween_callback(func() -> void:
				rig.set_react("dead")
				Sfx.at("body_slam", global_position, -3.0)
				Sfx.at("death_0", global_position + Vector3(0, 0.6, 0), -2.0, 0.8))
	tw.tween_interval(4.5)
	tw.tween_property(rig, "position:y", -1.3, 1.5)
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
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if held:
		rig.animate(delta, 0.0, false)
		return
	if surrendered:
		_plead_t -= delta
		if _plead_t < 3.0 and _flee_dir == Vector3.ZERO:
			rig.set_react("crawl")
			var away := global_position - player.global_position
			away.y = 0.0
			_flee_dir = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				if is_instance_valid(self):
					queue_free())
		if _flee_dir != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(-_flee_dir.x, -_flee_dir.z), minf(1.0, 6.0 * delta))
			velocity.x = _flee_dir.x * 1.6
			velocity.z = _flee_dir.z * 1.6
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		rig.animate(delta, 0.0, true)
		return
	if dead:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-4.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-4.0 * delta))
		move_and_slide()
		rig.animate(delta, 0.0, true)
		return
	if _flying:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if is_on_floor():
			_landed()
		rig.animate(delta, 0.0, false)
		return
	if _stun > 0.0:
		_stun -= delta
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-6.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-6.0 * delta))
		move_and_slide()
		if _stun <= 0.0 and _down <= 0.0:
			rig.set_react("")
		rig.animate(delta, 0.0, true)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0
	_cd -= delta
	_stomp_cd -= delta
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
		elif role == "archer":
			if dist < 5.0:
				want = -to_p.normalized() * speed
			elif dist > 11.0:
				want = to_p.normalized() * speed
			_shot_cd -= delta
			if _shot_cd <= 0.0 and dist < 16.0:
				_shot_cd = 2.4
				shoot()
		elif enraged and _stomp_cd <= 0.0 and dist < 5.5:
			_stomp()
		elif dist > 1.9:
			want = to_p.normalized() * speed
		elif _cd <= 0.0:
			_cd = attack_cd
			_winding = 0.0
			var r := _rng.randf()
			if r < 0.3:
				rig.play_move("cross")
			elif r < 0.5:
				rig.play_move("kick_front")
			else:
				rig.start_attack()
			Sfx.at("swing" if r >= 0.5 else "whoosh_punch", global_position + Vector3(0, 1.2, 0), -6.0, _rng.randf_range(0.9, 1.1))
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
