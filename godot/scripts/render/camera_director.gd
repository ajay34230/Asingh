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
var _fov_extra := 0.0      ## extra field-of-view squeeze during captures
var _shake_time := 0.0
var _shake_strength := 0.0
var _tween: Tween


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
	_focus_point = point
	_focus_distance = distance
	_tween_to("_focus", 1.0, seconds)


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
	var position := base_position.lerp(_focus_point + (base_position - base_target) * _focus_distance, _focus)
	var target := base_target.lerp(_focus_point, _focus)
	camera.look_at_from_position(position + offset, target, up)
	camera.fov = base_fov - _fov_extra
