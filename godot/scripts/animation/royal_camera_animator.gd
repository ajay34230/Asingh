extends Camera3D
class_name RoyalCameraAnimator
## Cinematic focus and shake helpers. Call focus_on(target), shake(), and reset_view().

@export var default_position := Vector3(0, 8.5, 8.5)
@export var default_rotation_degrees := Vector3(-42, 0, 0)
@export var default_fov := 48.0

var _base_position: Vector3
var _base_rotation: Vector3
var _shake_strength := 0.0
var _shake_time := 0.0

func _ready() -> void:
    _base_position = position
    _base_rotation = rotation

func focus_on(target: Node3D, distance := 5.0, duration := 0.45) -> void:
    if not is_instance_valid(target):
        return
    var destination := target.global_position + Vector3(0, distance * 0.65, distance)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "global_position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    var look_target := target.global_position
    tween.tween_method(Callable(self, "_look_at_point"), global_position, look_target, duration)

func _look_at_point(point: Vector3) -> void:
    look_at(point, Vector3.UP)

func shake(strength := 0.08, duration := 0.18) -> void:
    _shake_strength = strength
    _shake_time = duration

func reset_view(duration := 0.45) -> void:
    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "position", _base_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "rotation", _base_rotation, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "fov", default_fov, duration)

func _process(delta: float) -> void:
    if _shake_time > 0.0:
        _shake_time -= delta
        var fade := clampf(_shake_time / 0.18, 0.0, 1.0)
        h_offset = randf_range(-1.0, 1.0) * _shake_strength * fade
        v_offset = randf_range(-1.0, 1.0) * _shake_strength * fade
    else:
        h_offset = move_toward(h_offset, 0.0, delta)
        v_offset = move_toward(v_offset, 0.0, delta)
