extends Area3D

signal dice_rolled(result: int)

@export var roll_duration: float = 0.95
@export var extra_spins_min: int = 2
@export var extra_spins_max: int = 4

@onready var dice_model: Node3D = $DiceModel
var is_rolling := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    input_ray_pickable = true
    input_event.connect(_on_input_event)

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    var tapped := false
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        tapped = true
    elif event is InputEventScreenTouch and event.pressed:
        tapped = true
    if tapped:
        roll_dice()

func roll_dice() -> void:
    if is_rolling:
        return
    is_rolling = true
    var result := rng.randi_range(1, 6)
    # Orient the generated physical die so the visible upper face matches the game result.
    var final_euler := _orientation_for_result(result)
    var spins := rng.randi_range(extra_spins_min, extra_spins_max)
    var spin_target := final_euler + Vector3(360.0 * spins, 360.0 * (spins + 1), 360.0 * (spins + 2))
    var start_y := dice_model.position.y
    var tween := create_tween().set_parallel(true)
    tween.tween_property(dice_model, "rotation_degrees", spin_target, roll_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_model, "position:y", start_y + 0.32, roll_duration * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    await tween.finished
    var settle := create_tween()
    settle.tween_property(dice_model, "position:y", start_y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    await settle.finished
    is_rolling = false
    dice_rolled.emit(result)

func _orientation_for_result(result: int) -> Vector3:
    # Model face layout: top=6, bottom=1, front=5, back=2, right=4, left=3.
    match result:
        1: return Vector3(180, 0, 0)
        2: return Vector3(90, 0, 0)
        3: return Vector3(0, 0, -90)
        4: return Vector3(0, 0, 90)
        5: return Vector3(-90, 0, 0)
        _: return Vector3.ZERO
