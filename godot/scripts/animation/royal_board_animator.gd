extends Node3D
class_name RoyalBoardAnimator
## Subtle presentation animation for the board root. Keep disabled during precision gameplay if needed.

@export var enable_breathing := true
@export var vertical_amplitude := 0.006
@export var rotation_amplitude_degrees := 0.35
@export var speed := 0.45

var _start_position: Vector3
var _start_rotation: Vector3
var _time := 0.0

func _ready() -> void:
    _start_position = position
    _start_rotation = rotation

func _process(delta: float) -> void:
    if not enable_breathing:
        return
    _time += delta * speed
    position.y = _start_position.y + sin(_time) * vertical_amplitude
    rotation.y = _start_rotation.y + sin(_time * 0.7) * deg_to_rad(rotation_amplitude_degrees)
