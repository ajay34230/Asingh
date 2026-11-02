## Royal jewel dice: tap to request a roll; shows the result it is given.
class_name DiceController
extends Area3D

## The game decides the result. The dice only reports taps and shows the result it is given.
signal roll_requested
signal dice_rolled(result: int)

@export var roll_duration: float = 0.95
@export var extra_spins_min: int = 2
@export var extra_spins_max: int = 4

@onready var dice_model: Node3D = $DiceModel
var is_rolling := false
var rollable := false

func _ready() -> void:
    input_ray_pickable = true
    input_event.connect(_on_input_event)

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    var tapped := false
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        tapped = true
    elif event is InputEventScreenTouch and event.pressed:
        tapped = true
    if tapped and rollable and not is_rolling:
        roll_requested.emit()

## Only the human's turn may roll; AI and busy states switch this off.
func set_rollable(on: bool) -> void:
    rollable = on
    input_ray_pickable = on

## Debug: puts the dice straight into the orientation for `value`.
func setup_face(value: int) -> void:
    dice_model.rotation_degrees = orientation_for_result(value)

## Shows `result` (already decided by the rules engine) with a tumble and settle.
func roll_to(result: int) -> void:
    if is_rolling:
        return
    is_rolling = true
    var final_euler := orientation_for_result(result)
    var spins := randi_range(extra_spins_min, extra_spins_max)
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

## Outward direction of each face in the model's own coordinates, measured from the
## supplied dice file (its meshes are named face_N_...; face N shows N pips).
const FACE_OUTWARD := {
    1: Vector3(0, 0, 1),
    2: Vector3(1, 0, 0),
    3: Vector3(0, 1, 0),
    4: Vector3(0, -1, 0),
    5: Vector3(-1, 0, 0),
    6: Vector3(0, 0, -1),
}

## Euler angles (degrees, YXZ) that turn the face showing `result` to point up.
func orientation_for_result(result: int) -> Vector3:
    var outward: Vector3 = FACE_OUTWARD[result].normalized()
    var rotation: Quaternion
    if outward.dot(Vector3.UP) < -0.999:
        rotation = Quaternion(Vector3.RIGHT, PI)  ## face pointing straight down: turn over about X
    else:
        rotation = Quaternion(outward, Vector3.UP)
    return rotation.get_euler() * (180.0 / PI)
