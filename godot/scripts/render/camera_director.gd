## Owns the 3D camera. Zooms in on the moving token, pushes the field of view for
## captures, and shakes on impacts. Gameplay never reads the camera; it only asks
## the director to frame something.
class_name CameraDirector
extends Node

var camera: Camera3D
var base_position := Vector3.ZERO
var base_target := Vector3(0, 0.3, 0)
var base_fov := 36.0
var up := Vector3.UP

var _focus := 0.0          ## 0 = full board, 1 = close on the focus point
var _focus_point := Vector3.ZERO
var _focus_distance := 4.0
var _close_position := Vector3.ZERO
var _fight_offset := Vector3.ZERO
var _track_a: Node3D
var _track_b: Node3D
var _use_close_position := false
var _fov_extra := 0.0      ## extra field-of-view squeeze during captures
var _shake_time := 0.0
var _shake_strength := 0.0
var _tween: Tween
var _attract := 0.0        ## 1 = title-screen orbit, 0 = normal game camera
var _attract_time := 0.0
var _attract_tween: Tween


func setup(cam: Camera3D) -> void:
	camera = cam


## Sets where the full-board view sits (called after the board is fitted).
func set_base(position: Vector3, target: Vector3, fov: float) -> void:
	base_position = position
	base_target = target
	base_fov = fov


## Smoothly zooms in on a point. `distance` is how close to get, as a fraction of the
## normal distance to the board (0.5 = half as far).
func focus(point: Vector3, seconds: float, distance := 0.5) -> void:
	stop_tracking()
	_focus_point = point
	_focus_distance = distance
	_use_close_position = false
	_tween_to("_focus", 1.0, seconds)


## Low side-on close-up of two fighters: the camera sits beside the line between them,
## on the side facing the player, so both stay in profile.
func fight_view(a: Vector3, b: Vector3, seconds: float, distance := 3.4, elevation_deg := 30.0) -> void:
	var mid := a.lerp(b, 0.5) + Vector3(0, 0.25, 0)
	var line := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	if line.length_squared() < 0.01:
		line = Vector3.RIGHT
	var side := Vector3(-line.z, 0, line.x)
	var toward_player := Vector3(base_position.x - mid.x, 0, base_position.z - mid.z).normalized()
	if side.dot(toward_player) < 0.0:
		side = -side
	## Lean towards the player's view a little so the board still reads.
	side = (side * 0.7 + toward_player * 0.3).normalized()
	var el := deg_to_rad(elevation_deg)
	_focus_point = mid
	_fight_offset = (side * cos(el) + Vector3.UP * sin(el)) * distance
	_close_position = mid + _fight_offset
	_use_close_position = true
	_tween_to("_focus", 1.0, seconds)


## Keeps a fight close-up centred on both fighters as they move (knock-backs, throws).
func track(a: Node3D, b: Node3D) -> void:
	_track_a = a
	_track_b = b


func stop_tracking() -> void:
	_track_a = null
	_track_b = null


## Title-screen camera: from a low close view it rises and widens into a slow orbit.
## `intro` false starts straight in the wide orbit (returning from a game).
func start_attract(intro := true) -> void:
	if _attract_tween and _attract_tween.is_valid():
		_attract_tween.kill()
	_attract = 1.0
	_attract_time = 0.0 if intro else ATTRACT_RISE


## Sweeps from the orbit down into the game view.
func stop_attract(seconds := 1.4) -> void:
	if _attract_tween and _attract_tween.is_valid():
		_attract_tween.kill()
	_attract_tween = create_tween()
	_attract_tween.tween_property(self, "_attract", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


const ATTRACT_RISE := 4.5


func _attract_pose() -> Array:
	var k := smoothstep(0.0, 1.0, clampf(_attract_time / ATTRACT_RISE, 0.0, 1.0))
	var radius := lerpf(8.0, 25.0, k)
	var height := lerpf(4.0, 13.0, k)
	var angle := 0.5 + _attract_time * 0.07
	var pos := Vector3(sin(angle) * radius, height, cos(angle) * radius)
	return [pos, Vector3(0, lerpf(0.9, 0.0, k), 0)]


func release(seconds: float) -> void:
	_tween_to("_focus", 0.0, seconds)


## Narrows the field of view for a moment, then returns it. Used on captures.
func punch_in(amount: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(self, "_fov_extra", amount, seconds * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_fov_extra", 0.0, seconds * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration


func _tween_to(property: String, value: float, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, property, value, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if camera == null:
		return
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		var fade := clampf(_shake_time / 0.4, 0.0, 1.0)
		offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake_strength * fade
	if _use_close_position and is_instance_valid(_track_a) and is_instance_valid(_track_b):
		var mid := _track_a.global_position.lerp(_track_b.global_position, 0.5) + Vector3(0, 0.3, 0)
		var spread := Vector2(_track_a.global_position.x - _track_b.global_position.x, _track_a.global_position.z - _track_b.global_position.z).length()
		var k := 1.0 - exp(-7.0 * delta)
		_focus_point = _focus_point.lerp(mid, k)
		## Pull back a little as the fighters separate.
		_close_position = _close_position.lerp(mid + _fight_offset * (1.0 + maxf(0.0, spread - 0.8) * 0.35), k)
	var close := _close_position if _use_close_position else _focus_point + (base_position - base_target) * _focus_distance
	var position := base_position.lerp(close, _focus)
	var target := base_target.lerp(_focus_point, _focus)
	if _attract > 0.0:
		_attract_time += delta
		var pose := _attract_pose()
		position = position.lerp(pose[0], _attract)
		target = target.lerp(pose[1], _attract)
	camera.look_at_from_position(position + offset, target, up)
	camera.fov = base_fov - _fov_extra
