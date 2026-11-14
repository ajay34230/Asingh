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
var _vib_logged := false
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
var _roll_buf := 0.0
var wanted_t := 0.0             # >0: the town knows; shops refuse you, guards attack once assaults reach 5
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
	_rig.set_weapon("fists")
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
## Punches from the guard, settle back into the guard, then a kick, settle again (see _combo_gap).
const COMBO := ["jab", "cross", "hook", "uppercut", "kick_front", "kick_round"]
const GUARD_HOLD := 0.16   # seconds spent back in the boxing stance between a punch string and a kick
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
		stamina = minf(MAX_STAMINA, stamina + (30.0 if not blocking else 8.0) * regen_mult * (1.6 if power.has("tonic") else 1.0) * delta)
	if _winded and stamina > 25.0:
		_winded = false
var gear_dmg := 1.0         # S1: equipped weapon damage multiplier
var gear_ranged := false     # S1/X12: a bow is equipped; ATTACK fires an arrow
var arrows_fired := 0
var kicks_landed := 0
# --- progression (set by Progression from skills; weapon upgrades read from the save) ---
var melee_mult := 1.0       # Fighter: Heavy Hands
var cd_mult := 1.0          # Fighter: Combo Flow
var heavy_mult := 1.0       # Fighter: Crusher (hammer, axe, sword, spear swings)
var bow_cd_mult := 1.0      # Hunter: Quick Draw
var arrow_mult := 1.0       # Hunter: Piercing Shot
var ghost_mult := 1.0       # Hunter: Spirit Bane
var roll_cost_mult := 1.0   # Survivor: Nimble
var run_mult := 1.0         # Survivor: Nimble
var regen_mult := 1.0       # Survivor: Second Wind


## Damage bonus of the weapon in hand from blacksmith upgrades (+12% per level, up to +3).
func wpn_up() -> float:
	if story_ref == null:
		return 1.0
	return 1.0 + 0.12 * float(int(story_ref.call("get_flag", "up_" + weapon, 0)))
var gear_reach := 0.0       # S1: extra reach in metres
var armor_mult := 1.0       # S1: equipped armour (damage taken multiplier)
const OUTFITS := [Color(0.86, 0.16, 0.18), Color(0.16, 0.22, 0.78), Color(0.12, 0.55, 0.28), Color(0.96, 0.62, 0.08), Color(0.06, 0.58, 0.62), Color(0.5, 0.2, 0.7)]
var outfit := 0


## Outfit effects (set by Wardrobe): damage taken and small bonuses folded in by Progression.apply().
var outfit_armor := 1.0
var outfit_bonus := {}


## Change the whole body (outfit). Keeps the weapon in hand, riding pose and signal hookups.
func set_body(p: Dictionary) -> void:
	var old := _rig
	var react := old.react if old != null else ""
	var rk := old.ride_k if old != null else 0.0
	_rig = RealHuman.new().setup(p, "Explorer")
	_model.add_child(_rig)
	_rig.attack_hit.connect(_on_attack_hit)
	_rig.move_hit.connect(_on_move_hit)
	_rig.set_weapon(weapon)
	if react != "":
		_rig.set_react(react)
	_rig.ride_k = rk
	if old != null:
		old.queue_free()


## X27: 0 keeps the default clothes; 1-6 dress the explorer in a chosen colour with a gold trim.
func set_outfit(i: int) -> int:
	outfit = i
	if _rig == null or i <= 0 or i > OUTFITS.size():
		return 0
	return _rig.recolor(OUTFITS[i - 1], Color(0.95, 0.78, 0.3))


## X10: shockwave on landing from a dive. Hits every enemy within 4 m, throws up dust and sparks.
func ground_slam() -> int:
	var n := 0
	var dmg := 26.0 * hammer_mult * gear_dmg * heavy_mult * wpn_up() * (2.0 if power.has("power") else 1.0)
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
## Archery: aim at the nearest foe (or straight ahead if there is none), then the body does the real
## sequence (quiver, nock, raise, draw to the cheek, release). The arrow leaves on release from the string.
var _arrow_foe: Enemy
var _arrow_target := Vector3.ZERO
var _arrow_dmg := 0.0
var _arrow_off := Vector3(0, 1.1, 0)     # where on the foe the arrow is aimed (chest, or the head when aimed by hand)

## Manual aim: hold the bow button to draw and aim with the crosshair, let go to shoot. A quick tap still
## auto-aims. Holding at full draw slows time ("focus") until the focus meter runs out.
var aiming := false
var aim_blend := 0.0               # 0 normal camera .. 1 over-the-shoulder aim camera
var aim_focus := 1.0               # 0..1, drains while slowed, refills when not aiming
var _aim_t := 0.0                  # real seconds the button has been held
var _focusing := false
var _arrow_fire := false
var _arrow_charged := false
const AIM_TAP := 0.22
## PUBG-style aiming: a crosshair is always up with the bow and every touch shot goes where it points.
var crosshair_aim := true          # false: old auto-aim at the nearest enemy (setting "Bow aim")
var ads := false                   # SCOPE: zoomed over-the-shoulder view, slower steadier look
var scope_sens := 0.55             # look speed while scoped (setting)
var aim_assist_on := true          # the crosshair slows down and drifts onto an enemy near it (setting)
var gyro_mode := 0                 # 0 off, 1 while aiming or scoped, 2 always (setting)
var gyro_sens := 1.0
var gyro_invert := false
var _assist: Node3D                # the enemy under or near the crosshair right now (crosshair turns red)
var _assist_pt := Vector3.ZERO     # the point on it the arrow would go to (head, chest or a boss weak spot)
var _assist_scan := 0.0
var _looking_t := 9.0              # seconds since the last look drag (assist only pulls while you are aiming)
var _shot_crosshair := false       # this shot was fired from the touch FIRE button: aim it at the crosshair on release
var hit_marker := 0.0              # seconds left of the hit marker in the centre of the screen
var hit_marker_head := false
var hit_marker_kill := false


## SCOPE button: in and out of the zoomed over-the-shoulder view (bow only).
func toggle_scope() -> void:
	ads = gear_ranged and not ads
	Sfx.ui("tink", -14.0)


## An arrow of ours struck: show the hit marker (red for a headshot or a kill).
func on_arrow_hit(head: bool, kill: bool) -> void:
	hit_marker = 0.32 if not kill else 0.5
	hit_marker_head = head
	hit_marker_kill = kill


## Is the crosshair close to an enemy? Looks along the camera at heads, chests and open weak spots within 45 m,
## inside a small cone (tighter when scoped), and keeps one that is in plain sight.
func _scan_assist() -> void:
	_assist = null
	if not gear_ranged or not crosshair_aim or dead:
		return
	var o := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var cone := 0.075 if (ads or aiming) else 0.12
	var best := cone
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		if en.global_position.distance_to(global_position) > 45.0:
			continue
		var pts: Array = [en.global_position + Vector3(0, Arrow.chest_height(en), 0), en.global_position + Vector3(0, Arrow.head_height(en), 0)]
		var bb = en.get("boss")
		if bb != null and bb.gem_open():
			pts.push_front(bb.gem_world())
		for pt in pts:
			var d: Vector3 = pt - o
			if d.dot(fwd) <= 1.0:
				continue
			var ang := fwd.angle_to(d.normalized())
			if ang < best:
				var q := PhysicsRayQueryParameters3D.create(o + fwd * (camera_distance() + 0.6), pt)
				q.exclude = ray_excludes()
				q.collision_mask = 1
				var hit := get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty() or hit.collider == en or (hit.collider as Node).is_ancestor_of(en) or en.is_ancestor_of(hit.collider as Node):
					best = ang
					_assist = en
					_assist_pt = pt


## Aim assist: while you are aiming (dragging) near an enemy, the view drifts gently onto it and follows it a
## little as it moves. Never snaps; a quick flick away breaks it.
func _pull_assist(real: float) -> void:
	if _assist == null or not aim_assist_on or _looking_t > 0.35:
		return
	var o := camera.global_position
	var d := _assist_pt - o
	var want_yaw := atan2(-d.x, -d.z)
	var want_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var rate := (0.22 if (ads or aiming) else 0.14) * real      # radians per second of pull
	_yaw += clampf(wrapf(want_yaw - _yaw, -PI, PI), -rate, rate)
	_pitch = clampf(_pitch + clampf(want_pitch - _pitch, -rate, rate), -1.2, 0.45)
	_apply_look()


## Gyroscope aiming: tilt the phone to aim (Godot turns the sensor to match the screen orientation).
func _gyro_look(real: float) -> void:
	if gyro_mode == 0 or not OS.has_feature("mobile"):
		return
	if gyro_mode == 1 and not (ads or aiming):
		return
	var g := Input.get_gyroscope()
	if g.length() < 0.02:
		return                                 # sensor noise while holding still
	var inv := -1.0 if gyro_invert else 1.0
	_yaw += g.y * real * gyro_sens * inv
	_pitch = clampf(_pitch + g.x * real * gyro_sens * inv, -1.2, 0.45)
	_apply_look()

const FOCUS_SCALE := 0.4


var _shot_yaw := 0.0
var ride: Node3D                    # the animal under you (its body must not block your own aim or arrows)


## Physics bodies that aim rays and arrows must pass through: yourself and the animal you ride.
func ray_excludes() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	if mounted and is_instance_valid(ride):
		for c in ride.get_children():
			if c is CollisionObject3D:
				out.append((c as CollisionObject3D).get_rid())
	return out
var _hurt_by_spirit := false       # set by a ghost just before it hits (Ghost ward halves that damage)
var _arrow_spirit := false               # yaw from the archer to the target of the current shot


func fire_arrow() -> bool:
	if dead or (locked and not mounted) or _attack_cd > 0.0:
		return false
	var foe := _nearest_enemy(26.0)
	var from := global_position + Vector3(0, 1.4, 0)
	var target: Vector3
	if foe != null:
		var hover := 0.0          # flying bodies already float at their hover height
		_arrow_off = Vector3(0, Arrow.chest_height(foe) + hover, 0)
		target = foe.global_position + _arrow_off
	else:
		# free shot along the camera's view
		var cam := get_viewport().get_camera_3d()
		var fwd := -cam.global_transform.basis.z if cam != null else Vector3(-sin(_model.rotation.y), 0, -cos(_model.rotation.y))
		target = from + fwd * 35.0
	_shot_yaw = atan2(-(target.x - from.x), -(target.z - from.z))
	if not mounted:
		_model.rotation.y = _shot_yaw
	var rate := 1.0 / maxf(bow_cd_mult, 0.4)        # Quick Draw makes the whole draw faster
	_rig.play_move("bow_shot")
	_rig.move_rate = rate
	_attack_cd = float(RealHuman.MOVES["bow_shot"][0]) / rate * 0.9
	spend(4.0)
	arrows_fired += 1
	_arrow_foe = foe
	_arrow_target = target
	_arrow_fire = false
	_arrow_spirit = false
	_arrow_charged = false
	_arrow_dmg = 20.0 * hammer_mult * gear_dmg * arrow_mult * wpn_up() * (2.0 if power.has("power") else 1.0)
	Sfx.ui_at("swing", -14.0)
	return true


## Called on the release frame of the bow_shot move.
func _release_arrow() -> void:
	if _shot_crosshair:
		_aim_from_crosshair()                   # the shot goes where the crosshair is at the moment of release
		_shot_crosshair = false
	var ar := Arrow.new()
	get_parent().add_child(ar)
	var target := _arrow_target
	if not is_instance_valid(_arrow_foe):
		_arrow_foe = null                  # it vanished while we drew: the arrow still flies to the last aim point
	if _arrow_foe != null and not _arrow_foe.dead:
		target = _arrow_foe.global_position + _arrow_off      # it may have moved while we drew
	ar.fire = _arrow_fire
	ar.spirit = _arrow_spirit
	ar.launch(_rig.nock_transform(), target, _arrow_foe, _arrow_dmg * (1.35 if _arrow_charged else 1.0), self)
	_combat_t = 0.0
	Sfx.ui_at("swing", -2.0)
	StoryFX.shake(self, 0.03, 0.12)


## Bow button pressed: start drawing. Without a bow (or in the saddle) it is a normal attack.
func begin_aim() -> void:
	if not gear_ranged:
		attack()
		return
	if aiming or not fire_arrow():
		return
	aiming = true
	_aim_t = 0.0
	_rig.hold_draw = true
	_shot_crosshair = crosshair_aim
	if crosshair_aim:
		_aim_from_crosshair()                   # PUBG style: the crosshair, not the nearest enemy
		_shot_yaw = _yaw
		if not mounted:
			_model.rotation.y = _yaw


## Bow button released: a quick tap keeps the auto-aim shot; a held draw shoots where the crosshair points.
func release_aim() -> void:
	if not aiming:
		return
	aiming = false
	_rig.hold_draw = false
	_set_focus(false)
	if dead or _rig.move != "bow_shot":
		return
	if _aim_t >= AIM_TAP or _shot_crosshair:
		_aim_from_crosshair()
		_shot_yaw = atan2(-(_arrow_target.x - global_position.x), -(_arrow_target.z - global_position.z))
		if not mounted:
			_model.rotation.y = _yaw
		_arrow_charged = _rig.move_t >= 0.58
		var it := get_tree().get_first_node_in_group("items")
		var spectral_foe: bool = is_instance_valid(_arrow_foe) and _arrow_foe.get("spectral") == true
		if _arrow_charged and it != null and spectral_foe and int(it.call("count", "spirit_arrow")) > 0:
			it.call("take", "spirit_arrow", 1)
			_arrow_spirit = true
		elif _arrow_charged and it != null and int(it.call("count", "fire_arrow")) > 0:
			it.call("take", "fire_arrow", 1)
			_arrow_fire = true
	_attack_cd = maxf(_attack_cd, 0.4 / maxf(_rig.move_rate, 0.1))


## Ray from the centre of the screen: the arrow goes to whatever is under the crosshair. An enemy close to the
## ray is locked as the target (aimed at the head if the crosshair is on the head).
func _aim_from_crosshair() -> void:
	if _assist != null and is_instance_valid(_assist) and not (_assist as Enemy).dead:
		# aim assist already has an enemy right by the crosshair
		_arrow_foe = _assist as Enemy
		_arrow_off = _assist_pt - _assist.global_position
		_arrow_target = _assist_pt
		return
	var o := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var far := o + fwd * 90.0
	var q := PhysicsRayQueryParameters3D.create(o + fwd * (camera_distance() + 0.6), far)
	q.exclude = ray_excludes()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var point: Vector3 = far if hit.is_empty() else hit.position
	var best: Enemy = null
	var best_along := INF
	var best_off := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var hover := 0.0           # flying bodies already float at their hover height
		var pts: Array = [Vector3(0, Arrow.head_height(en) + hover, 0), Vector3(0, Arrow.chest_height(en) + hover, 0)]
		var bb = en.get("boss")
		if bb != null and bb.gem_open():
			pts.push_front((bb.gem_world() as Vector3) - en.global_position)       # the weak spot first
		for off in pts:
			var c: Vector3 = en.global_position + off
			var along := (c - o).dot(fwd)
			if along < 1.0 or along > 90.0 or along > (point - o).dot(fwd) + 1.0:
				continue
			var miss := (o + fwd * along).distance_to(c)
			var is_head_pt: bool = off.y > Arrow.chest_height(en) + hover + 0.1 or off == pts[0] and bb != null and bb.gem_open()
			if miss < (0.4 if is_head_pt else clampf(Arrow.chest_height(en) * 0.8, 0.9, 1.5)) and along < best_along:
				best = en
				best_along = along
				best_off = off
				break
	_arrow_foe = best
	if best != null:
		_arrow_off = best_off
		_arrow_target = best.global_position + best_off
	else:
		_arrow_target = point
		# festival targets (kites, the effigy) close to the crosshair line
		for ft in get_tree().get_nodes_in_group("arrow_targets"):
			var fn := ft as Node3D
			if fn == null or not fn.visible:
				continue
			var fp: Vector3 = fn.global_position + Vector3(0, float(fn.get_meta("aim_h", 0.0)), 0)
			var al := (fp - o).dot(fwd)
			if al > 1.0 and al < 90.0 and (o + fwd * al).distance_to(fp) < float(fn.get_meta("radius", 1.0)) * 1.4 and al < best_along:
				best_along = al
				_arrow_target = fp


func _set_focus(on: bool) -> void:
	if on == _focusing:
		return
	_focusing = on
	Engine.time_scale = FOCUS_SCALE if on else 1.0


## Per frame while drawing: the camera moves over the right shoulder, the archer turns with the view, and once
## at full draw time slows while there is focus left.
func _tick_aim(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	if aiming and (dead or (locked and not mounted) or _rig.move != "bow_shot"):
		aiming = false
		_rig.hold_draw = false
		_set_focus(false)
	if ads and not gear_ranged:
		ads = false
	hit_marker = maxf(0.0, hit_marker - real)
	_looking_t += real
	_assist_scan -= real
	if _assist_scan <= 0.0:
		_assist_scan = 0.08
		_scan_assist()
	elif _assist != null and (not is_instance_valid(_assist) or (_assist as Enemy).dead):
		_assist = null
	elif _assist != null:
		pass                                     # rescanned every 0.08 s, so it follows a moving ghost
	_pull_assist(real)
	_gyro_look(real)
	if crosshair_aim and _rig.move == "bow_shot" and not mounted and not aiming:
		_model.rotation.y = lerp_angle(_model.rotation.y, _yaw, 1.0 - exp(-14.0 * real))     # shoot where you look
	aim_blend = move_toward(aim_blend, 1.0 if (aiming or ads) else 0.0, real * 5.0)
	if aiming:
		_aim_t += real
		_shot_yaw = _yaw
		if not mounted:
			_model.rotation.y = lerp_angle(_model.rotation.y, _yaw, 1.0 - exp(-18.0 * real))
		var full := _rig.move_t >= 0.58
		if full and aim_focus > 0.0:
			_set_focus(true)
			aim_focus = maxf(0.0, aim_focus - real / 3.0)       # about 3 real seconds of slow time
		else:
			_set_focus(false)
	else:
		aim_focus = minf(1.0, aim_focus + real / 8.0)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var side := 0.0 if first_person else 0.55 * aim_blend
	_pivot.position.x = right.x * side
	_pivot.position.z = right.z * side


func attack() -> void:
	if attack_override.is_valid() and bool(attack_override.call()):
		return
	if gear_ranged and (not locked or mounted) and not dead and fire_arrow():
		return
	if mounted:
		_mounted_swing()
		return
	if locked or dead or _throwing:
		return
	if weapon != "fists" and weapon != "bow" and is_on_floor():
		_weapon_swing()
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
		if grab != null and not grab.is_boss and not grab.surrendered and not grab is Monster:
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
	_attack_cd = MOVE_CD[mv] * cd_mult
	# Between a punch and a kick (either way) wait until the move has fully retracted to the guard,
	# then hold the guard briefly, so the stance reads clearly before the next move starts.
	var nxt_kick: bool = _combo < COMBO.size() and MOVE_KIND[COMBO[_combo]] != "punch"
	if (MOVE_KIND[mv] != "punch") != nxt_kick or MOVE_KIND[mv] != "punch":
		_attack_cd = maxf(_attack_cd, float(RealHuman.MOVES[mv][0]) + GUARD_HOLD)
	_attack_cd += _rig.play_move(mv)   # plus the time to close the fist when the hands were relaxed
	Sfx.ui_at("whoosh_kick" if MOVE_KIND[mv] != "punch" else "whoosh_punch", -6.0)
	if mv == "kick_round" or mv == "cross":
		Sfx.ui_at("grunt_%d" % randi_range(0, 2), -14.0)


## Weapon in hand: "fists" (boxing combo), "hammer", or a crafted weapon (axe, spear, bow).
## The WEAPON button cycles through what you own; fists put the weapon away.
var weapon := "fists"
var story_ref: Object          # set by Main, used to remember the chosen weapon in the save


func weapons_owned() -> Array:
	var out: Array = ["fists", "hammer"]
	var it := get_tree().get_first_node_in_group("items")
	if it != null:
		for id in ["bow", "sword", "dagger", "spear", "axe"]:
			if int(it.call("count", id)) > 0:
				out.append(id)
	return out


func set_weapon(id: String) -> void:
	if _rig != null and _rig.weapon in RealHuman.BLADES and not id in RealHuman.BLADES and not mounted:
		_rig.play_clip("sheath_sword_2", 0.0, 1.2, false, 0.0, 0.1)          # puts the blade away
	weapon = id
	var it := get_tree().get_first_node_in_group("items")
	if it != null:
		if id in ["axe", "spear", "bow", "sword", "dagger"]:
			it.call("equip", id)
		else:
			it.call("unequip", "weapon")
	if _rig != null:
		_rig.set_weapon(id)
	if story_ref != null:
		story_ref.call("set_flag", "weapon_sel", id)


func cycle_weapon() -> String:
	if dead or _throwing:
		return weapon
	var own := weapons_owned()
	var i := own.find(weapon)
	set_weapon(String(own[(i + 1) % own.size()]))
	Sfx.ui_at("swing", -12.0)
	return weapon


## A swing with the weapon in hand (hammer, axe or spear) toward the nearest foe.
func _weapon_swing() -> void:
	if _attack_cd > 0.0:
		if _attack_cd < 0.3:
			_buffer = 0.3
		return
	blocking = false
	var near := _nearest_enemy(6.0 + gear_reach)
	if near != null:
		var to := near.global_position - global_position
		_model.rotation.y = atan2(-to.x, -to.z)
		var dist := Vector2(to.x, to.z).length()
		if dist > 2.0 + gear_reach:
			_lunge_v = Vector3(to.x, 0.0, to.z).normalized() * clampf((dist - 1.6) / 0.16, 2.0, 9.0)
			_lunge_t = 0.16
	if not spend(9.0):
		_hit_mult = 0.6
	_attack_cd = (0.75 if weapon == "axe" else 0.62) * cd_mult
	_combat_t = 0.0
	_rig.start_attack()
	Sfx.ui_at("swing", -4.0)


## Swing the hammer from the saddle (the HIT button while riding).
## Horseback archery: the rider turns in the saddle (up to about 30 degrees off the horse's heading) and twists
## the torso for the rest, so the bow arm points at the target while the legs stay on the horse.
const SADDLE_ARM := 0.8            # in the saddle the hips do not turn, so the bow arm sits this far left of the body
func saddle_aim(heading: float) -> void:
	if _rig.move != "bow_shot":
		_rig.aim_twist = 0.0
		return
	var aim_at := _arrow_target
	if is_instance_valid(_arrow_foe) and not _arrow_foe.dead:
		aim_at = _arrow_foe.global_position + _arrow_off
	if aiming:
		aim_at = camera.global_position - camera.global_transform.basis.z * 40.0
	var sh := _rig._bone_pos("sh_L")
	var tgt_yaw := atan2(-(aim_at.x - sh.x), -(aim_at.z - sh.z))
	var want := tgt_yaw - SADDLE_ARM
	var need := wrapf(want - heading, -PI, PI)
	var lim := clampf(absf(need) - 1.3, 0.8, 1.6)        # turn further in the saddle only when the twist alone cannot reach
	var my := heading + clampf(need, -lim, lim)
	_model.rotation.y = my
	if _rig.move_t < 0.42:
		_rig.aim_twist = clampf(wrapf(want - my, -PI, PI), -1.5, 1.5)
		return
	# once the bow is up, measure where the bow arm really points and close the gap each frame
	var arm := _rig._bone_pos("wr_L") - sh
	if Vector2(arm.x, arm.z).length() < 0.05:
		return
	var arm_yaw := atan2(-arm.x, -arm.z)
	_rig.aim_twist = clampf(_rig.aim_twist + wrapf(tgt_yaw - arm_yaw, -PI, PI) * 0.45, -1.5, 1.5)


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
	# blade in hand: the captured sword-and-shield guard; it ends with the block
	if on and _rig.weapon in RealHuman.BLADES:
		_rig.play_clip("ss_block_idle", 1.0, 1.0, false, 0.0, 0.12)
	elif not on and _rig.clip_playing("ss_block_idle"):
		_rig.stop_clip(0.15)


## Quick dodge roll with a short window of invulnerability (ROLL button / V).
func roll() -> void:
	if locked or dead or mounted or _throwing:
		return
	if _roll_cd > 0.0:
		_roll_buf = 0.35          # pressed a moment early: roll as soon as the cooldown ends
		return
	_roll_buf = 0.0
	var tired := stamina < 18.0
	spend(18.0 * roll_cost_mult)  # a tired player can still roll (shorter dodge window), it just drains what is left
	_roll_cd = 0.9
	_invuln = maxf(_invuln, 0.25 if tired else 0.45)
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
	if mv == "bow_shot":
		_release_arrow()
		return
	if not MOVE_DMG.has(mv):
		return
	var fwd := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	var reach := (2.9 if MOVE_KIND[mv] != "punch" else 2.3) + gear_reach
	var dmg: float = MOVE_DMG[mv] * _hit_mult * gear_dmg * melee_mult * wpn_up() * (2.0 if power.has("power") else 1.0)
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
			if MOVE_KIND[mv] != "punch":
				kicks_landed += 1
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
			if assaults >= 3 and np.role != "guard":
				wanted_t = 120.0
				if assaults == 5:
					say("The guards have been called. Stay away from the town for two minutes.")
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
	var dmg := 22.0 * hammer_mult * gear_dmg * heavy_mult * wpn_up() * (2.0 if power.has("power") else 1.0)
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = (e as Node3D).global_position - global_position
		to.y = 0.0
		if to.length() < 3.0 + gear_reach and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.2):
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
	if power.has("ward") and _hurt_by_spirit:
		amount *= 0.5
	amount *= GameSettings.damage_scale() * armor_mult * outfit_armor
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
		if not _vib_logged:
			_vib_logged = true
			LogCollector.event("first hit this run: vibrate")      # if the app dies right after this line, it was the vibration
		Input.vibrate_handheld(70)              # needs android.permission.VIBRATE (export preset permissions/vibrate)
	hp = maxf(0.0, hp - amount)
	FloatText.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "-" + str(int(round(amount))), Color(1.0, 0.25, 0.25), 1.1)
	_combat_t = 0.0
	_invuln = 0.35
	velocity += from.normalized() * 4.0 + Vector3(0, 1.5, 0)
	Sfx.ui_at("player_hurt", -3.0)
	_rig.play_hit("body" if amount < 18.0 else "head", randf_range(-1.0, 1.0))
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
	if not mounted:
		_rig.play_clip("ss_death", 1.0, 1.0, true, 0.0, 0.1, true)            # falls, and stays down
	await get_tree().create_timer(2.6).timeout
	_rig.stop_clip(0.05)
	global_position = checkpoint + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	hp = max_hp
	dead = false
	locked = false
	_invuln = 2.0
	hp_changed.emit(hp, max_hp)


func hostile_to_guards() -> bool:
	return wanted_t > 0.0 and assaults >= 5


func _tick_combat(delta: float) -> void:
	wanted_t = maxf(0.0, wanted_t - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	if _roll_buf > 0.0:
		_roll_buf -= delta
		if _roll_cd <= 0.0:
			roll()
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
	if ads or aiming:
		k *= scope_sens
	if _assist != null and aim_assist_on:
		k *= 0.6                                 # aim assist: the crosshair slows down over an enemy
	_looking_t = 0.0
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
		var task := task_for_prompt(focus.prompt)
		if task != "":
			var to := focus.global_position - global_position
			if Vector2(to.x, to.z).length() > 0.2:
				_model.rotation.y = atan2(-to.x, -to.z)     # turn to face what you are working on
			play_task(task, TASK_TIME.get(task, 1.0))
		focus.interact(self)
		# The prompt may have changed ("Open door" -> "Close door").
		focus_changed.emit(focus)


## Mission actions are acted out: digging, searching, picking up, lighting, praying, chopping, cutting...
const TASK_TIME := {"search": 1.2, "pickup": 0.9, "reach": 0.9, "pray": 2.0, "chop": 1.8, "cut": 1.6, "drink": 1.4, "read": 1.6, "push": 0.6, "dig": 4.2}
var _task_t := 0.0
var _task_prev_weapon := ""


static func task_for_prompt(p: String) -> String:
	var s := p.to_lower()
	for pair in [["dig", "dig"], ["search", "search"], ["examine", "search"], ["open the", "search"], ["open door", "push"], ["close door", "push"],
			["pick", "pickup"], ["collect", "pickup"], ["take", "pickup"], ["plant", "pickup"], ["water the", "pickup"], ["skin", "cut"],
			["cut", "cut"], ["fell", "chop"], ["chop", "chop"], ["light", "reach"], ["touch", "reach"], ["place", "reach"], ["ring", "reach"],
			["pray", "pray"], ["drink", "drink"], ["read the tablet", "read"], ["look into", "search"]]:
		if s.begins_with(String(pair[0])) or s.contains(" " + String(pair[0]) + " "):
			return String(pair[1])
	return ""


## Act out a task for `dur` seconds: the player stands still and the body does the work (with a tool if needed).
func play_task(kind: String, dur: float) -> void:
	if mounted or dead:
		return
	_task_t = dur
	velocity = Vector3.ZERO
	_rig.play_action(kind, dur)
	if kind == "dig":
		_task_prev_weapon = weapon
		_rig.set_weapon("shovel")
	elif kind == "chop" and weapon != "axe":
		_task_prev_weapon = weapon
		_rig.set_weapon("axe")


func _end_task() -> void:
	if _task_prev_weapon != "":
		_rig.set_weapon(weapon)
		_task_prev_weapon = ""


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
# --- jumping, vaulting and climbing ------------------------------------------------------------
var _jump_prep := 0.0
var _jump_prep_total := 0.0
var _climb_t := -1.0
var _climb_dur := 1.0
var _climb_cool := 0.0
var _climb_kind := ""
var _climb_a := Vector3.ZERO      # where the climb starts (feet)
var _climb_w := Vector3.ZERO      # feet position against the wall face
var _climb_top := Vector3.ZERO    # ledge top just past the edge
var _climb_end := Vector3.ZERO    # where the feet finish
var climbs := 0                   # counts climbs and vaults (tests, achievements)
const CLIMB_MAX := 2.6            # highest ledge (above the feet) you can pull yourself onto


func _take_off() -> void:
	var k := {"stand": 0.95, "walk": 1.0, "run": 1.06}.get(_rig.jump_kind, 1.0) as float
	velocity.y = JUMP_SPEED * k
	if _rig.jump_kind == "run":
		var hz := Vector3(velocity.x, 0.0, velocity.z)
		velocity += hz.normalized() * 0.8     # the leap carries a little further
	_coyote = 0.0
	jumped.emit()


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit.collider is CharacterBody3D or hit.collider is RigidBody3D):
		return {}                          # people, animals and loose props are not walls
	return hit


## Looks for something to vault over or climb in direction `fwd`. Returns {} when there is nothing,
## else {kind, h, top, wall, into, land}. `airborne` = a grab during a jump (reach measured from the feet).
func _ledge_ahead(fwd: Vector3, airborne: bool = false) -> Dictionary:
	if fwd.length() < 0.1:
		return {}
	var base := global_position
	for hgt in ([0.6, 1.3] if not airborne else [1.0, 1.6]):
		var a := base + Vector3(0, hgt, 0)
		var reach := 0.85 + 0.45 * clampf(Vector2(velocity.x, velocity.z).length() / 6.0, 0.0, 1.0)   # running: spot it earlier
		var hit := _ray(a, a + fwd * reach)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if n.y > 0.45:
			continue                       # a slope or stairs: walk up it instead
		var into := -Vector3(n.x, 0.0, n.z).normalized()
		if into.dot(fwd) < 0.55:
			continue                       # glancing along the wall
		var over: Vector3 = hit.position + into * 0.1      # just past the face, so thin fences are found too
		var top := _ray(Vector3(over.x, base.y + CLIMB_MAX + 0.4, over.z), Vector3(over.x, base.y + 0.2, over.z))
		if top.is_empty() or (top.normal as Vector3).y < 0.75:
			continue
		var tp: Vector3 = top.position
		var h := tp.y - base.y
		if h < STEP_HEIGHT + 0.1 or h > CLIMB_MAX or (airborne and h < 0.4):
			continue
		# room to stand up on top (nothing over the ledge)
		if not _ray(tp + Vector3(0, 0.1, 0), tp + Vector3(0, 1.85, 0)).is_empty():
			continue
		var out := {"h": h, "top": tp, "wall": Vector3(hit.position.x, base.y, hit.position.z), "into": into}
		out["kind"] = "climb" if h > 1.3 or airborne else "mantle"
		# a thin wall or fence: vault over if the ground continues on the far side, lower than the top
		if h < 1.3 and not airborne:
			var far: Vector3 = hit.position + into * 1.15
			var thick := _ray(Vector3(far.x, tp.y + 0.05, far.z) - into * 0.75, Vector3(far.x, tp.y + 0.05, far.z))
			var beyond := _ray(Vector3(far.x, tp.y + 0.3, far.z), Vector3(far.x, base.y - 2.0, far.z))
			if thick.is_empty() and not beyond.is_empty() and (beyond.position as Vector3).y < tp.y - 0.35:
				out["kind"] = "vault"
				out["land"] = beyond.position
		return out
	return {}


func _start_climb(l: Dictionary) -> void:
	_climb_kind = String(l["kind"])
	var into: Vector3 = l["into"]
	var h: float = l["h"]
	_climb_a = global_position
	_climb_w = (l["wall"] as Vector3) - into * 0.42
	_climb_w.y = global_position.y
	_climb_top = (l["top"] as Vector3) + into * 0.05
	match _climb_kind:
		"vault":
			_climb_end = l["land"]
			_climb_dur = 0.62
		"mantle":
			_climb_end = (l["top"] as Vector3) + into * 0.4
			_climb_dur = 0.55 + 0.25 * h
		_:
			_climb_end = (l["top"] as Vector3) + into * 0.45
			_climb_dur = 0.95 + 0.3 * maxf(0.0, h - 1.2)
	_model.rotation.y = atan2(-into.x, -into.z)
	velocity = Vector3.ZERO
	blocking = false
	_climb_t = 0.0
	_rig.climb_kind = _climb_kind
	_rig.climb_u = 0.0
	_rig.jump_prep = 0.0
	_jump_prep = 0.0
	spend(6.0)
	Sfx.ui_at("whoosh_kick", -10.0)


func _climb_path(u: float) -> Vector3:
	var tp := _climb_top
	match _climb_kind:
		"vault":
			var flat := _climb_a.lerp(_climb_end, u)
			var lift := maxf(0.0, tp.y + 0.45 - lerpf(_climb_a.y, _climb_end.y, 0.5))
			flat.y = lerpf(_climb_a.y, _climb_end.y, u) + lift * sin(u * PI)
			return flat
		"mantle":
			var a := _seg(u, 0.0, 0.6)
			var p := _climb_a.lerp(_climb_w, _seg(u, 0.0, 0.2))
			p.y = lerpf(_climb_a.y, tp.y + 0.03, a)
			var b := _seg(u, 0.5, 1.0)
			return Vector3(lerpf(p.x, _climb_end.x, b), lerpf(p.y, _climb_end.y + 0.03, b), lerpf(p.z, _climb_end.z, b))
		_:
			# jump up the wall and catch the ledge, pull up until the chest is over it, then roll over the edge
			var w := _climb_a.lerp(_climb_w, _seg(u, 0.0, 0.15))
			var hang_y := tp.y - 1.75
			var y := lerpf(_climb_a.y, maxf(hang_y, _climb_a.y), _seg(u, 0.0, 0.18))
			y = lerpf(y, tp.y - 0.95, _seg(u, 0.18, 0.6))
			y = lerpf(y, tp.y + 0.03, _seg(u, 0.6, 0.86))
			var over := _seg(u, 0.62, 1.0)
			return Vector3(lerpf(w.x, _climb_end.x, over), y, lerpf(w.z, _climb_end.z, over))


func _seg(u: float, a: float, b: float) -> float:
	return smoothstep(0.0, 1.0, clampf((u - a) / maxf(b - a, 0.001), 0.0, 1.0))


func _tick_climb(delta: float) -> void:
	_climb_t += delta
	var u := clampf(_climb_t / _climb_dur, 0.0, 1.0)
	global_position = _climb_path(u)
	velocity = Vector3.ZERO
	_rig.climb_u = u
	_rig.animate(delta, 0.0, true)
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance, 1.0 - exp(-10.0 * delta))
	if u >= 1.0:
		_climb_t = -1.0
		_climb_cool = 0.35
		_rig.climb_kind = ""
		climbs += 1
		_was_floor = true
		_fall_speed = 0.0
		if _climb_kind == "vault":
			_rig.land(6.0)
		apply_floor_snap()


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
	if _climb_t >= 0.0:
		_tick_climb(delta)
		return
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
	if _task_t > 0.0:
		_task_t -= delta
		if _task_t <= 0.0:
			_end_task()
		elif not locked:
			input = Vector2.ZERO
			fast = false
			jump_requested = false
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
		begin_aim() if gear_ranged else attack()
	elif _f_was and not f_down and aiming:
		release_aim()
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
	var speed := lerpf(WALK_SPEED, RUN_SPEED * run_mult, run_blend) * (1.45 if power.has("speed") else 1.0)
	if _rig.move == "bow_shot":
		speed *= 0.3                  # archers plant their feet to draw
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
	var fwd_m := Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y))
	if _jump_buffer > 0.0 and _coyote > 0.0 and _jump_prep <= 0.0:
		if crouching:
			set_crouch(false)
		_jump_buffer = 0.0
		# a wall or ledge in front: vault over it or climb it instead of jumping
		var ledge := _ledge_ahead(dir.normalized() if dir.length() > 0.3 else fwd_m) if not mounted and on_floor else {}
		if not ledge.is_empty():
			_start_climb(ledge)
			return
		var hv0 := Vector2(velocity.x, velocity.z).length()
		_rig.jump_kind = "stand" if hv0 < 0.8 else ("walk" if hv0 < 4.2 else "run")
		# standing and walking jumps crouch first (anticipation); a running jump takes off at once
		_jump_prep = {"stand": 0.15, "walk": 0.07}.get(_rig.jump_kind, 0.0)
		_jump_prep_total = _jump_prep
		if _jump_prep <= 0.0:
			_take_off()
	if _jump_prep > 0.0:
		_jump_prep -= delta
		_rig.jump_prep = clampf(1.0 - _jump_prep / maxf(_jump_prep_total, 0.01), 0.0, 1.0)
		if _jump_prep <= 0.0:
			_rig.jump_prep = 0.0
			if on_floor or _coyote > 0.0:
				_take_off()
	# GTA-style ledge grab: jumping at a wall with a ledge within reach catches it and climbs up
	if not on_floor and not mounted and velocity.y < 4.0 and dir.length() > 0.3 and _climb_cool <= 0.0:
		var grab := _ledge_ahead(dir.normalized(), true)
		if not grab.is_empty():
			_start_climb(grab)
			return
	_climb_cool = maxf(0.0, _climb_cool - delta)

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
			_land_slow = (0.18 + clampf(_fall_speed / 40.0, 0.0, 0.3)) * (0.3 if _rig.jump_kind == "run" else 1.0)
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
	_tick_aim(delta)
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
	var want_len := lerpf(_target_distance, minf(_target_distance, 1.7), aim_blend)
	_arm.spring_length = lerpf(_arm.spring_length, want_len * (1.0 - 0.7 * _cam_squeeze), 1.0 - exp(-10.0 * delta))
	var want_fov := base_fov + (RUN_FOV - BASE_FOV) if ((fast or run_blend > 0.5) and dir.length() > 0.1) else base_fov
	want_fov -= (16.0 + (10.0 if ads else 0.0)) * aim_blend
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-6.0 * delta))

	_focus_timer -= delta
	if _focus_timer <= 0.0:
		_focus_timer = 0.1
		_update_focus()
