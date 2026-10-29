class_name Player
extends CharacterBody3D
## Placeholder scale-reference player: a 1.8 m capsule with a third-person orbit camera.
## Phase 1 only needs basic walking so the environment can be explored; this is NOT the
## final character controller or character model.

const WALK_SPEED := 5.0
const RUN_SPEED := 11.0
const GRAVITY := 24.0
const JUMP_SPEED := 8.0
const LOOK_SENSITIVITY := 0.0045

## Movement request: x = strafe right (+), y = forward (+). Length 0..1.
var move_input := Vector2.ZERO
var sprint := false
var jump_requested := false
var spawn_position := Vector3.ZERO
var camera: Camera3D

var _yaw := 0.0
var _pitch := -0.2
var _pivot: Node3D
var _arm: SpringArm3D
var _model: Node3D


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
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	cm.radial_segments = 12
	cm.rings = 4
	body.mesh = cm
	body.material_override = PropFactory.material(Color(0.93, 0.36, 0.10), 0.6)
	body.position = Vector3(0, 0.9, 0)
	_model.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.25, 0.2, 0.3)
	nose.mesh = nm
	nose.material_override = PropFactory.material(Color(0.1, 0.1, 0.1), 0.6)
	nose.position = Vector3(0, 1.5, -0.38)
	_model.add_child(nose)

	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	_pivot.position = Vector3(0, 1.5, 0)
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = 7.5
	_arm.margin = 0.4
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 3500.0
	_arm.add_child(camera)
	camera.make_current()
	_apply_look()


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


func _physics_process(delta: float) -> void:
	# Optional keyboard controls (handy when testing on a PC); touch sets move_input.
	var key_move := _keyboard_input()
	var input := move_input if move_input.length() > 0.05 else key_move
	var fast := sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	if Input.is_physical_key_pressed(KEY_LEFT):
		add_look(Vector2(-300.0 * delta, 0.0))
	if Input.is_physical_key_pressed(KEY_RIGHT):
		add_look(Vector2(300.0 * delta, 0.0))
	if Input.is_physical_key_pressed(KEY_UP):
		add_look(Vector2(0.0, -200.0 * delta))
	if Input.is_physical_key_pressed(KEY_DOWN):
		add_look(Vector2(0.0, 200.0 * delta))

	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var dir := (forward * input.y + right * input.x)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := RUN_SPEED if fast else WALK_SPEED
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 60.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 60.0 * delta)

	if is_on_floor():
		if jump_requested or Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	jump_requested = false
	move_and_slide()

	if dir.length() > 0.1:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 12.0 * delta))
	if global_position.y < -40.0:
		global_position = spawn_position
		velocity = Vector3.ZERO
