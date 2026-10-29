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

const WALK_SPEED := 2.4
const RUN_SPEED := 6.5
const GRAVITY := 24.0
const JUMP_SPEED := 8.0
const ACCEL_GROUND := 45.0
const DECEL_GROUND := 55.0
const ACCEL_AIR := 9.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const STEP_HEIGHT := 0.45
const LOOK_SENSITIVITY := 0.0045
const MIN_DISTANCE := 2.5
const MAX_DISTANCE := 12.0
const DEFAULT_DISTANCE := 7.5
const BASE_FOV := 70.0
const RUN_FOV := 77.0
const FOCUS_ANGLE_DEG := 80.0

## Placeholder explorer look (downloaded CC0 model) (generic, not a story character).
const PRESET := {"body": "striker_mail", "robe": true, "scale": 0.99}

## Movement request: x = strafe right (+), y = forward (+). Length 0..1.
var move_input := Vector2.ZERO
var sprint := false
var jump_requested := false
var spawn_position := Vector3.ZERO
var camera: Camera3D
var focus: Interactable = null
var locked := false              # true during dialogue, digging and cinematics: no input is read

var _yaw := 0.0
var _pitch := -0.2
var _pivot: Node3D
var _arm: SpringArm3D
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

	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	_pivot.position = Vector3(0, 1.55, 0)
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _target_distance
	_arm.margin = 0.4
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
func set_distance(d: float) -> void:
	_target_distance = clampf(d, MIN_DISTANCE * 0.5, MAX_DISTANCE)
	_arm.spring_length = _target_distance


## Zoom by `amount` metres (positive = further away). Smoothed in _physics_process.
func zoom(amount: float) -> void:
	_target_distance = clampf(_target_distance + amount, MIN_DISTANCE, MAX_DISTANCE)


## Actual distance from the pivot to the camera right now (shorter than requested when a wall
## is in the way).
func camera_distance() -> float:
	return camera.global_position.distance_to(_pivot.global_position)


func look_yaw() -> float:
	return _yaw


func add_look(delta_px: Vector2) -> void:
	_yaw -= delta_px.x * LOOK_SENSITIVITY
	_pitch = clampf(_pitch - delta_px.y * LOOK_SENSITIVITY, -1.2, 0.45)
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
	# Optional keyboard controls (handy when testing on a PC); touch sets move_input.
	var key_move := _keyboard_input()
	var input := move_input if move_input.length() > 0.05 else key_move
	var fast := sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	if locked:
		input = Vector2.ZERO
		fast = false
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

	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var dir := (forward * input.y + right * input.x)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := RUN_SPEED if fast else WALK_SPEED
	var target := dir * speed

	var on_floor := is_on_floor()
	_coyote = COYOTE_TIME if on_floor else maxf(0.0, _coyote - delta)
	if not locked and (jump_requested or Input.is_physical_key_pressed(KEY_SPACE)):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	jump_requested = false

	var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
	if dir.length() < 0.05 and on_floor:
		accel = DECEL_GROUND
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if not on_floor:
		velocity.y -= GRAVITY * delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
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
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 12.0 * delta))
	_rig.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor())
	if global_position.y < -40.0:
		global_position = spawn_position
		velocity = Vector3.ZERO

	# Smooth camera zoom and run FOV kick.
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance, 1.0 - exp(-10.0 * delta))
	var want_fov := RUN_FOV if (fast and dir.length() > 0.1) else BASE_FOV
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-6.0 * delta))

	_focus_timer -= delta
	if _focus_timer <= 0.0:
		_focus_timer = 0.1
		_update_focus()
