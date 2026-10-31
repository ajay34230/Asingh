class_name Player
extends CharacterBody3D
## Phase 2 player controller (still a placeholder capsule model; no character art yet).
##
## Movement : acceleration/deceleration, walk and run, jump with coyote time and a jump buffer,
##            automatic step-up over small ledges, slope limit with sliding on steep ground.
## Camera   : third-person orbit with collision (SpringArm3D), smoothed zoom (pinch / mouse
##            wheel), field-of-view kick while running, pitch limits.
## Interact : finds the best Interactable within reach in front of the camera and exposes it as
##            `focus`; `interact()` uses it. UI listens to `focus_changed` and `message`.
## Input    : touch controls (see touch_controls.gd) set `move_input` / `sprint` / `jump_requested`
##            and call `add_look`, `zoom` and `interact`; WASD, Shift, Space, E, arrows and mouse
##            wheel work on a PC.

signal focus_changed(target: Interactable)
signal message(text: String)
signal stepped(run: bool)
signal jumped
signal landed(impact: float)
signal hp_changed(hp: float, max_hp: float)
signal powerup_changed
signal died_signal
signal damaged(amount: float)

const WALK_SPEED := 2.4
const RUN_SPEED := 6.5
const GRAVITY := 24.0
const JUMP_SPEED := 7.2
const ACCEL_GROUND := 45.0
const DECEL_GROUND := 55.0
const ACCEL_AIR := 9.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const STEP_HEIGHT := 0.45
const LOOK_SENSITIVITY := 0.0045
const MIN_DISTANCE := 1.6
const MAX_DISTANCE := 10.0
const DEFAULT_DISTANCE := 4.3
const BASE_FOV := 70.0
const RUN_FOV := 77.0
const FOCUS_ANGLE_DEG := 80.0

## Placeholder explorer look (downloaded CC0 model) (generic, not a story character).
const PRESET := {"body": "striker_mail", "robe": true, "scale": 0.99, "tool": "hammer"}

## Movement request: x = strafe right (+), y = forward (+). Length 0..1.
var move_input := Vector2.ZERO
var sprint := false
var jump_requested := false
var spawn_position := Vector3.ZERO
var camera: Camera3D
var focus: Interactable = null
var look_sens_y := 1.0          # vertical look multiplier (settings)
var auto_sprint := true         # a full stick push breaks into a run
var haptics := true             # phone vibrates when hurt
var look_sens := 1.0             # multiplier on LOOK_SENSITIVITY (settings)
var invert_y := false
var base_fov := BASE_FOV
var first_person := false
var _saved_distance := DEFAULT_DISTANCE
var hp := 100.0
var max_hp := 100.0
var dead := false
var checkpoint := Vector3.ZERO
var power := {}                  # kind -> seconds left ("speed", "power", "shield")
var _attack_cd := 0.0
var blocking := false            # hold BLOCK: guard up, front hits do a quarter damage
var _buffer := 0.0               # a HIT press made just before the last move ends is queued
var _lunge_t := 0.0
var _lunge_v := Vector3.ZERO
var _hit_mult := 1.0
var _roll_cd := 0.0
var assaults := 0               # villagers the player has struck
var _f_was := false
var _q_was := false
var _v_was := false
var _combat_t := 99.0            # seconds since last hit taken / dealt
var _invuln := 0.0
var carried_by: Node3D = null    # riding a cart: position follows this node
var hammer_mult := 1.0              # 1.4 once Dhruv re-forges the hammer with the Queen's light
var attack_override := Callable()   # set by the cart race: the HIT button swings the cart blades
var has_knife := false            # hunter's knife from the Reaver camp: lets you hunt wild game
var hunted := 0
var crouching := false
var _c_was_down := false
var _land_slow := 0.0
var mounted := false             # riding an animal: MountSystem owns movement, JUMP means dismount
var locked := false              # true during dialogue, digging and cinematics: no input is read

var _yaw := 0.0
var _pitch := -0.2
var _pivot: Node3D
var _arm: SpringArm3D
var _cam_squeeze := 0.0
var _model: Node3D
var _rig: RealHuman
var _target_distance := DEFAULT_DISTANCE
var _coyote := 0.0
var _jump_buffer := 0.0
var _focus_timer := 0.0
var _e_was_down := false
var _step_dist := 0.0
var _was_floor := true
var _fall_speed := 0.0


func _ready() -> void:
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(52.0)
	spawn_position = global_position

	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	cs.shape = capsule
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_rig = RealHuman.new().setup(PRESET, "Explorer")
	_model.add_child(_rig)
	_rig.attack_hit.connect(_on_attack_hit)
	_rig.move_hit.connect(_on_move_hit)
	checkpoint = global_position

	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	_pivot.position = Vector3(0, 1.55, 0)
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _target_distance
	_arm.margin = 0.6
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = BASE_FOV
	camera.near = 0.1
	camera.far = 3500.0
	_arm.add_child(camera)
	camera.make_current()
	_apply_look()


# --- camera ------------------------------------------------------------------------------

## Immediately set the camera distance (screenshots, cut-scenes later).
func set_crouch(on: bool) -> void:
	if mounted or dead:
		return
	crouching = on
	_rig.crouch_target = 1.0 if on else 0.0


func toggle_crouch() -> void:
	set_crouch(not crouching)


func set_distance(d: float) -> void:
	_target_distance = clampf(d, MIN_DISTANCE * 0.5, MAX_DISTANCE)
	_arm.spring_length = _target_distance


## Zoom by `amount` metres (positive = further away). Smoothed in _physics_process.
func zoom(amount: float) -> void:
	if first_person:
		return
	_target_distance = clampf(_target_distance + amount, MIN_DISTANCE, MAX_DISTANCE)


## Actual distance from the pivot to the camera right now (shorter than requested when a wall
## is in the way).
func camera_distance() -> float:
	return camera.global_position.distance_to(_pivot.global_position)


## Switch between third person (orbit camera) and first person (camera at the eyes, body hidden).
func set_first_person(on: bool) -> void:
	if on == first_person:
		return
	first_person = on
	if on:
		_saved_distance = _target_distance
		_target_distance = 0.02
		_model.visible = false
		_pitch = clampf(_pitch, -1.2, 0.45)
	else:
		_target_distance = _saved_distance
		_model.visible = true


# --- combat ------------------------------------------------------------------------------------

## Fighting: tap HIT for a combo: jab, cross, front kick, hook, roundhouse, then a grab-and-throw
## (or a hammer smash when nobody is close enough to grab). Auto-aims at the nearest enemy.
const COMBO := ["jab", "cross", "jab", "hook", "cross", "uppercut"]   # boxing: kicks only when airborne
const MOVE_CD := {"jab": 0.34, "cross": 0.38, "hook": 0.42, "kick_front": 0.5, "kick_side": 0.55, "kick_round": 0.65, "uppercut": 0.45}
const MOVE_DMG := {"jab": 9.0, "cross": 12.0, "hook": 14.0, "uppercut": 16.0, "kick_front": 17.0, "kick_side": 19.0, "kick_round": 24.0}
const MOVE_KIND := {"jab": "punch", "cross": "punch", "hook": "punch", "uppercut": "punch", "kick_front": "kick", "kick_side": "kick", "kick_round": "round"}
var _combo := 0
var _combo_t := 9.0
var _held: Enemy = null
var _throwing := false


func _nearest_enemy(rng: float) -> Enemy:
	var near: Enemy = null
	var best := rng
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en.held:
			continue
		var d := global_position.distance_to(en.global_position)
		if d < best:
			best = d
			near = en
	return near


var slam_dive := false
const MAX_STAMINA := 100.0
var stamina := 100.0            # S2: sprint, roll, attack and blocking spend it; it refills when idle
var _stam_delay := 0.0
var _winded := false            # out of breath: no sprinting until partly recovered
var _block_t := 9.0             # seconds since the guard went up (a block this fresh is a parry)
var parries := 0


## S2: spend stamina. Returns false (and spends what is left) if there was not enough.
func spend(cost: float) -> bool:
	_stam_delay = 0.7
	if stamina >= cost:
		stamina -= cost
		return true
	stamina = 0.0
	return false


func _tick_stamina(delta: float, draining: bool) -> void:
	_block_t += delta
	_stam_delay = maxf(0.0, _stam_delay - delta)
	if draining:
		stamina = maxf(0.0, stamina - 14.0 * delta)
		_stam_delay = 0.7
		if stamina <= 0.0:
			_winded = true
	elif _stam_delay <= 0.0:
		stamina = minf(MAX_STAMINA, stamina + (30.0 if not blocking else 8.0) * delta)
	if _winded and stamina > 25.0:
		_winded = false
var gear_dmg := 1.0         # S1: equipped weapon damage multiplier
var gear_ranged := false     # S1/X12: a bow is equipped; ATTACK fires an arrow
var arrows_fired := 0
var gear_reach := 0.0       # S1: extra reach in metres
var armor_mult := 1.0       # S1: equipped armour (damage taken multiplier)
const OUTFITS := [Color(0.86, 0.16, 0.18), Color(0.16, 0.22, 0.78), Color(0.12, 0.55, 0.28), Color(0.96, 0.62, 0.08), Color(0.06, 0.58, 0.62), Color(0.5, 0.2, 0.7)]
var outfit := 0


## X27: 0 keeps the default clothes; 1-6 dress the explorer in a chosen colour with a gold trim.
func set_outfit(i: int) -> int:
	outfit = i
	if _rig == null or i <= 0 or i > OUTFITS.size():
		return 0
	return _rig.recolor(OUTFITS[i - 1], Color(0.95, 0.78, 0.3))


## X10: shockwave on landing from a dive. Hits every enemy within 4 m, throws up dust and sparks.
func ground_slam() -> int:
	var n := 0
	var dmg := 26.0 * hammer_mult * gear_dmg * (2.0 if power.has("power") else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < 4.0:
			en.take_hit("slam", dmg, to.normalized() if to.length() > 0.05 else Vector3.FORWARD)
			n += 1
	HitFx.burst(get_parent(), global_position + Vector3(0, 0.15, 0), true, Color(0.85, 0.75, 0.55))
	if n > 0:
		var ach := get_tree().get_first_node_in_group("achievements")
		if ach != null:
			ach.note_kill("", true)
	Sfx.ui_at("hit_thud", 0.0)
	StoryFX.shake(self, 0.16, 0.3)
	StoryFX.hitstop(0.07)
	_combat_t = 0.0
	return n


## X12: loose an arrow at the nearest enemy within 22 m (works on foot and from the saddle).
func fire_arrow() -> bool:
	if dead or locked or _attack_cd > 0.0:
		return false
	var foe := _nearest_enemy(22.0)
	if foe == null:
		return false
	_attack_cd = 0.6
	spend(5.0)
	arrows_fired += 1
	var from := global_position + Vector3(0, 1.4, 0)
	var target := foe.global_position + Vector3(0, 1.2, 0)
	_model.rotation.y = atan2(-(target.x - from.x), -(target.z - from.z))
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.8
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.55, 0.4, 0.22)
	cm.material = am
	arrow.mesh = cm
	get_parent().add_child(arrow)
	arrow.global_position = from
	arrow.look_at(target, Vector3.UP)
	arrow.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	Sfx.ui_at("swing", -4.0)
	var dmg := 20.0 * hammer_mult * gear_dmg * (2.0 if power.has("power") else 1.0)
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "global_position", target, maxf(0.12, from.distance_to(target) / 28.0))
	tw.tween_callback(func() -> void:
		if is_instance_valid(foe) and not foe.dead:
			foe.take_hit("kick", dmg, (target - from))
			_combat_t = 0.0
		arrow.queue_free())
	return true


func attack() -> void:
	if attack_override.is_valid() and bool(attack_override.call()):
		return
	if gear_ranged and not locked and not dead and fire_arrow():
		return
	if mounted:
		_mounted_swing()
		return
	if locked or dead or _throwing:
		return
	if _attack_cd > 0.0:
		if _attack_cd < 0.3:
			_buffer = 0.3          # queue the next move so combos flow without perfect timing
		return
	blocking = false
	if not is_on_floor() and velocity.y < -1.0 and not slam_dive:
		slam_dive = true           # X10: attack while falling = ground slam on landing
		velocity.y = -17.0
		Sfx.ui_at("whoosh_kick", -2.0)
		return
	var near := _nearest_enemy(6.0)
	var spd := Vector2(velocity.x, velocity.z).length()
	var airborne := not is_on_floor()
	if near != null:
		var to := near.global_position - global_position
		_model.rotation.y = atan2(-to.x, -to.z)
		# step into range: a short lunge toward the target (the further away, the longer it carries)
		var dist := Vector2(to.x, to.z).length()
		if dist > 1.6:
			_lunge_v = Vector3(to.x, 0.0, to.z).normalized() * clampf((dist - 1.3) / 0.16, 2.0, 9.0)
			_lunge_t = 0.16
	elif spd > 4.5:
		_lunge_v = Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y)) * 5.5   # sprint attack
		_lunge_t = 0.2
	_hit_mult = 1.0
	if airborne:
		_hit_mult = 1.3            # flying kick
	elif spd > 4.5:
		_hit_mult = 1.2
	if not spend(7.0):
		_hit_mult *= 0.6           # exhausted: weak swings
	if _combo_t > 1.4:
		_combo = 0
	_combo_t = 0.0
	if _combo >= COMBO.size():
		_combo = 0
		var grab := _nearest_enemy(2.6)
		if grab != null and not grab.is_boss and not grab.surrendered:
			_grab_throw(grab)
		else:
			_attack_cd = 0.7
			_rig.start_attack()
			Sfx.ui_at("swing", -4.0)
		return
	var mv: String = COMBO[_combo]
	if airborne:
		mv = "kick_front"
	_combo += 1
	_attack_cd = MOVE_CD[mv]
	_rig.play_move(mv)
	Sfx.ui_at("whoosh_kick" if MOVE_KIND[mv] != "punch" else "whoosh_punch", -6.0)
	if mv == "kick_round" or mv == "cross":
		Sfx.ui_at("grunt_%d" % randi_range(0, 2), -14.0)


## Swing the hammer from the saddle (the HIT button while riding).
func _mounted_swing() -> void:
	if dead or _attack_cd > 0.0:
		return
	_attack_cd = 0.7
	_rig.start_attack()
	Sfx.ui_at("swing", -4.0)


func set_block(on: bool) -> void:
	if on and (locked or dead or mounted or _throwing):
		on = false
	if on == blocking:
		return
	blocking = on
	if on:
		_block_t = 0.0
	_rig.set_react("block" if on else "")


## Quick dodge roll with a short window of invulnerability (ROLL button / V).
func roll() -> void:
	if locked or dead or mounted or _throwing or _roll_cd > 0.0:
		return
	if not spend(18.0):
		return
	_roll_cd = 0.9
	_invuln = maxf(_invuln, 0.45)
	blocking = false
	_rig.set_react("")
	var d := Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * move_input.y + Vector3(cos(_yaw), 0.0, -sin(_yaw)) * move_input.x
	if d.length() < 0.2:
		d = Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	_model.rotation.y = atan2(-d.x, -d.z)
	_lunge_v = d.normalized() * 8.0
	_lunge_t = 0.4
	Sfx.ui_at("whoosh_punch", -6.0)
	_rig.play_move("roll")
	# somersault around the body centre (not the feet) so no part dips below the ground
	var pivot := Vector3(0.0, 0.6, 0.0)
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void:
		_model.rotation.x = a
		_model.position = pivot - _model.basis * pivot, 0.0, -TAU, 0.44)
	tw.tween_callback(func() -> void:
		_model.rotation.x = 0.0
		_model.position = Vector3.ZERO)


func _on_move_hit(mv: String) -> void:
	if not MOVE_DMG.has(mv):
		return
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	var reach := (2.9 if MOVE_KIND[mv] != "punch" else 2.3) + gear_reach
	var dmg: float = MOVE_DMG[mv] * _hit_mult * gear_dmg * (2.0 if power.has("power") else 1.0)
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead or en.held:
			continue
		var to := en.global_position - global_position
		to.y = 0.0
		if to.length() < reach and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.25):
			en.take_hit(MOVE_KIND[mv], dmg, fwd)
			hit = true
	# villagers and animals: they react (stagger, shout, run) but are never damaged
	for nn in get_tree().get_nodes_in_group("npcs"):
		var np := nn as Npc
		if np == null or np.companion:
			continue
		var tn: Vector3 = np.global_position - global_position
		tn.y = 0.0
		if tn.length() < reach - 0.2 and (tn.length() < 0.6 or fwd.dot(tn.normalized()) > 0.3):
			np.take_hit(dmg, fwd)
			assaults += 1
			hit = true
			if assaults == 3:
				say("People are staring. Hitting villagers will make them fear you.")
	for an2 in get_tree().get_nodes_in_group("animals"):
		var an3 := an2 as Animal
		if an3 == null or an3.dead:
			continue
		var ta2: Vector3 = an3.global_position - global_position
		ta2.y = 0.0
		if ta2.length() < reach - 0.2 and (ta2.length() < 0.6 or fwd.dot(ta2.normalized()) > 0.3):
			an3.shove(fwd)
			hit = true
	if hit:
		_combat_t = 0.0
		var heavy: bool = MOVE_KIND[mv] != "punch"
		Sfx.ui_at("kick_hit" if heavy else "punch_hit_%d" % randi_range(0, 1), 0.0 if heavy else -2.0)
		StoryFX.shake(self, 0.05 if not heavy else 0.1, 0.18)
		StoryFX.hitstop(0.05 if not heavy else 0.09)


## Grab an enemy, lift him over the head and hurl him.
func _grab_throw(e: Enemy) -> void:
	_throwing = true
	_attack_cd = 2.0
	_rig.play_move("grab")
	Sfx.ui_at("cloth_grab", -3.0)
	await get_tree().create_timer(0.42).timeout
	if not is_instance_valid(e) or e.dead:
		_throwing = false
		return
	_held = e
	e.begin_held()
	_rig.play_move("lift")
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(e) or e.dead:
		_held = null
		_throwing = false
		return
	_rig.play_move("throw")
	await get_tree().create_timer(0.16).timeout
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	if is_instance_valid(e):
		e.throw_from(self, fwd)
	Sfx.ui_at("whoosh_throw", -2.0)
	_held = null
	await get_tree().create_timer(0.35).timeout
	_throwing = false
	_attack_cd = 0.3


func _update_held() -> void:
	if _held != null and is_instance_valid(_held):
		var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
		_held.global_position = global_position + Vector3(0, 1.75, 0) + fwd * 0.25
		_held.rotation.y = _model.rotation.y


func _on_attack_hit() -> void:
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	var dmg := 22.0 * hammer_mult * gear_dmg * (2.0 if power.has("power") else 1.0)
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = (e as Node3D).global_position - global_position
		to.y = 0.0
		if to.length() < 3.0 and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.2):
			(e as Enemy).take_hit("slam", dmg, fwd)
			hit = true
	if has_knife:
		for an in get_tree().get_nodes_in_group("animals"):
			var ani := an as Animal
			if ani != null and ani.huntable():
				var ta: Vector3 = ani.global_position - global_position
				ta.y = 0.0
				if ta.length() < 3.0 and fwd.dot(ta.normalized()) > 0.2:
					ani.take_hit(dmg, fwd)
					hit = true
	if hit:
		_combat_t = 0.0
		Sfx.ui_at("hit_thud", -2.0)
		StoryFX.shake(self, 0.14, 0.25)
		StoryFX.hitstop(0.1)


func take_damage(amount: float, from: Vector3) -> void:
	if dead or _invuln > 0.0:
		return
	if power.has("shield"):
		amount *= 0.2
	amount *= GameSettings.damage_scale() * armor_mult
	if blocking and _block_t < 0.25:
		# S2: a block raised just before the hit is a parry: no damage, the attacker is staggered
		parries += 1
		stamina = minf(MAX_STAMINA, stamina + 12.0)
		var near_e := _nearest_enemy(4.0)
		if near_e != null:
			near_e.stagger(1.3)
		Sfx.ui_at("hit_thud", -2.0)
		HitFx.burst(get_parent(), global_position + Vector3(0, 1.3, 0) + Vector3(-sin(_model.rotation.y), 0, -cos(_model.rotation.y)) * 0.6, true, Color(0.7, 0.85, 1.0))
		StoryFX.shake(self, 0.06, 0.15)
		return
	if blocking and not spend(10.0):
		amount *= 0.6                  # guard broken by exhaustion
	if blocking:
		var toward := from - global_position
		toward.y = 0.0
		var face := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
		if toward.length() < 0.1 or face.dot(toward.normalized()) > -0.2:
			amount *= 0.25
			Sfx.ui_at("hit_thud", -8.0)
			StoryFX.shake(self, 0.04, 0.12)
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(70)
	hp = maxf(0.0, hp - amount)
	_combat_t = 0.0
	_invuln = 0.35
	velocity += from.normalized() * 4.0 + Vector3(0, 1.5, 0)
	Sfx.ui_at("player_hurt", -3.0)
	_rig.play_action("startle", 0.4)
	damaged.emit(amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func apply_powerup(kind: String) -> void:
	match kind:
		"health":
			heal(40.0)
			say("Health restored.")
		"speed":
			power["speed"] = 15.0
			say("Speed boost for 15 seconds!")
		"power":
			power["power"] = 20.0
			say("Double damage for 20 seconds!")
		"shield":
			power["shield"] = 15.0
			say("Shield: you take far less damage for 15 seconds.")
	powerup_changed.emit()


func _die() -> void:
	dead = true
	locked = true
	died_signal.emit()
	await get_tree().create_timer(2.6).timeout
	global_position = checkpoint + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	hp = max_hp
	dead = false
	locked = false
	_invuln = 2.0
	hp_changed.emit(hp, max_hp)


func _tick_combat(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	if _buffer > 0.0:
		_buffer -= delta
		if _attack_cd <= 0.0:
			_buffer = 0.0
			attack()
	if _lunge_t > 0.0 and not dead:
		_lunge_t -= delta
		move_and_collide(_lunge_v * delta)
	_combo_t += delta
	_update_held()
	_invuln = maxf(0.0, _invuln - delta)
	_combat_t += delta
	if _combat_t > 6.0 and hp < max_hp and not dead:
		hp = minf(max_hp, hp + 3.0 * delta)
		hp_changed.emit(hp, max_hp)
	var changed := false
	for k in power.keys():
		power[k] -= delta
		if power[k] <= 0.0:
			power.erase(k)
			changed = true
	if changed:
		powerup_changed.emit()


func look_yaw() -> float:
	return _yaw


func add_look(delta_px: Vector2) -> void:
	var k := LOOK_SENSITIVITY * look_sens
	_yaw -= delta_px.x * k
	_pitch = clampf(_pitch - delta_px.y * k * look_sens_y * (-1.0 if invert_y else 1.0), -1.2, 0.45)
	_apply_look()


## Point the camera at a yaw (radians) and pitch, used for the opening view and screenshots.
func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = clampf(pitch, -1.2, 0.45)
	_apply_look()


func _apply_look() -> void:
	if _pivot:
		_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-0.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(0.8)


# --- interaction -------------------------------------------------------------------------

func interact() -> void:
	if locked:
		return
	if focus != null and is_instance_valid(focus):
		focus.interact(self)
		# The prompt may have changed ("Open door" -> "Close door").
		focus_changed.emit(focus)


func say(text: String) -> void:
	message.emit(text)


func _update_focus() -> void:
	var best: Interactable = null
	var best_score := INF
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var cos_limit := cos(deg_to_rad(FOCUS_ANGLE_DEG))
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it == null or not it.enabled:
			continue
		var to := it.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > it.reach or absf(it.global_position.y - global_position.y) > 4.0:
			continue
		if dist > 0.6 and to.normalized().dot(fwd) < cos_limit:
			continue
		if dist < best_score:
			best_score = dist
			best = it
	if best != focus:
		focus = best
		focus_changed.emit(focus)


# --- movement ----------------------------------------------------------------------------

func _keyboard_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	return v


## Step up small ledges: if the way ahead is blocked but free one STEP_HEIGHT higher and there is
## a walkable surface to land on, lift the body so move_and_slide carries on over the edge.
func _try_step_up(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	if speed < 0.5:
		return
	var motion := horizontal.normalized() * maxf(speed * delta, 0.1)
	if not test_move(global_transform, motion):
		return
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, up):
		return
	# Probe a capsule-radius ahead so the landing test touches the flat top, not the ledge edge.
	var probe := horizontal.normalized() * 0.5
	var raised := global_transform.translated(up)
	if test_move(raised, probe):
		return
	var ahead := raised.translated(probe)
	var col := KinematicCollision3D.new()
	if not test_move(ahead, -up * 1.5, col):
		return
	if col.get_normal().y < 0.7:
		return
	var gain := STEP_HEIGHT - col.get_travel().length()
	if gain > 0.03:
		global_position.y += gain + 0.02


func _physics_process(delta: float) -> void:
	_tick_combat(delta)
	if slam_dive and is_on_floor():
		slam_dive = false
		ground_slam()
	if carried_by != null and is_instance_valid(carried_by):
		global_position = carried_by.global_position
		velocity = Vector3.ZERO
		_model.rotation.y = lerp_angle(_model.rotation.y, carried_by.global_rotation.y, 1.0 - exp(-6.0 * delta))
		_rig.animate(delta, 0.0, true)
		_arm.spring_length = lerpf(_arm.spring_length, _target_distance, 1.0 - exp(-10.0 * delta))
		return
	# Optional keyboard controls (handy when testing on a PC); touch sets move_input.
	var key_move := _keyboard_input()
	var input := move_input if move_input.length() > 0.05 else key_move
	var fast := sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	if _winded:
		fast = false
	_tick_stamina(delta, fast and input.length() > 0.3 and is_on_floor() and not mounted)
	if locked:
		input = Vector2.ZERO
		fast = false
		if not mounted:
			jump_requested = false
	if not locked and Input.is_physical_key_pressed(KEY_LEFT):
		add_look(Vector2(-300.0 * delta, 0.0))
	if not locked and Input.is_physical_key_pressed(KEY_RIGHT):
		add_look(Vector2(300.0 * delta, 0.0))
	if not locked and Input.is_physical_key_pressed(KEY_UP):
		add_look(Vector2(0.0, -200.0 * delta))
	if not locked and Input.is_physical_key_pressed(KEY_DOWN):
		add_look(Vector2(0.0, 200.0 * delta))
	var e_down := Input.is_physical_key_pressed(KEY_E)
	if e_down and not _e_was_down and not locked:
		interact()
	_e_was_down = e_down
	var f_down := Input.is_physical_key_pressed(KEY_F)
	if f_down and not _f_was:
		attack()
	_f_was = f_down
	var v_down := Input.is_physical_key_pressed(KEY_V)
	if v_down and not _v_was:
		roll()
	_v_was = v_down
	var q_down := Input.is_physical_key_pressed(KEY_Q)
	if q_down != _q_was:
		set_block(q_down)
	_q_was = q_down
	var c_down := Input.is_physical_key_pressed(KEY_C)
	if c_down and not _c_was_down and not locked:
		toggle_crouch()
	_c_was_down = c_down

	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var dir := (forward * input.y + right * input.x)
	if dir.length() > 1.0:
		dir = dir.normalized()
	# Analogue stick: a light push walks, a firm push eases into a run, a full push auto-sprints
	# (no need to tap the run button); the run button still forces a run at any stick strength.
	var m := clampf(dir.length(), 0.0, 1.0)
	var run_blend := 1.0 if fast else (smoothstep(0.82, 0.97, m) if auto_sprint else 0.0)
	var speed := lerpf(WALK_SPEED, RUN_SPEED, run_blend) * (1.45 if power.has("speed") else 1.0)
	var push := m if fast else clampf(m / 0.82, 0.0, 1.0)
	if crouching:
		speed = minf(speed, WALK_SPEED * 0.62)
	if _land_slow > 0.0:
		_land_slow -= delta
		speed *= 0.55
	var target := (dir.normalized() * speed * push) if m > 0.001 else Vector3.ZERO

	var on_floor := is_on_floor()
	_coyote = COYOTE_TIME if on_floor else maxf(0.0, _coyote - delta)
	if not locked and (jump_requested or Input.is_physical_key_pressed(KEY_SPACE)):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if not mounted:
		jump_requested = false

	var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
	if dir.length() < 0.05 and on_floor:
		accel = DECEL_GROUND
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if not on_floor:
		# lighter on the way up, heavier on the way down: a weighty, believable arc
		velocity.y -= GRAVITY * (0.85 if velocity.y > 0.0 else 1.3) * delta
	_rig.air_vy = velocity.y
	if _jump_buffer > 0.0 and _coyote > 0.0:
		if crouching:
			set_crouch(false)
		velocity.y = JUMP_SPEED
		_jump_buffer = 0.0
		_coyote = 0.0
		jumped.emit()

	if on_floor:
		_try_step_up(Vector3(velocity.x, 0.0, velocity.z), delta)
	move_and_slide()

	var floor_now := is_on_floor()
	if not floor_now:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	elif not _was_floor:
		if _fall_speed > 4.0:
			landed.emit(_fall_speed)
			_rig.land(_fall_speed)
			_land_slow = 0.18 + clampf(_fall_speed / 40.0, 0.0, 0.3)
		_fall_speed = 0.0
	_was_floor = floor_now
	if floor_now:
		var hv := Vector2(velocity.x, velocity.z).length()
		if hv > 0.6:
			_step_dist += hv * delta
			var stride := 1.05 if hv < 4.0 else 1.7
			if _step_dist >= stride:
				_step_dist = 0.0
				stepped.emit(hv >= 4.0)
		else:
			_step_dist = 0.6
	if dir.length() > 0.1:
		var want_y := atan2(-dir.x, -dir.z)
		var dyaw := wrapf(want_y - _model.rotation.y, -PI, PI)
		_rig.turn_lean = clampf(dyaw * 1.2, -1.0, 1.0)
		_model.rotation.y = lerp_angle(_model.rotation.y, want_y, minf(1.0, 12.0 * delta))
	else:
		_rig.turn_lean = 0.0
	_pivot.position.y = lerpf(_pivot.position.y, 1.1 if crouching else 1.55, 1.0 - exp(-9.0 * delta))
	_rig.guard = _combat_t < 4.0 and not mounted and not dead and not locked
	_rig.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor())
	if global_position.y < -40.0:
		global_position = spawn_position
		velocity = Vector3.ZERO

	# Smooth camera zoom and run FOV kick. If the camera would end up at or under the ground (a
	# slope behind the player), the arm is pulled in until the camera is clear again.
	var cp := camera.global_position
	var gq := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 2.0, 0), cp - Vector3(0, 0.3, 0))
	gq.exclude = [get_rid()]
	var under := not get_world_3d().direct_space_state.intersect_ray(gq).is_empty()
	_cam_squeeze = move_toward(_cam_squeeze, 1.0 if under else 0.0, delta * (8.0 if under else 1.5))
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance * (1.0 - 0.7 * _cam_squeeze), 1.0 - exp(-10.0 * delta))
	var want_fov := base_fov + (RUN_FOV - BASE_FOV) if ((fast or run_blend > 0.5) and dir.length() > 0.1) else base_fov
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-6.0 * delta))

	_focus_timer -= delta
	if _focus_timer <= 0.0:
		_focus_timer = 0.1
		_update_focus()
