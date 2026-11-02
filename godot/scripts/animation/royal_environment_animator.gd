extends Node3D
class_name RoyalEnvironmentAnimator
## Procedural idle animation controller for supplied palace/environment GLBs.
## Attach to the root Node3D of an elephant, peacock, statue, lamp, fountain, or board.
## Set animation_type in the Inspector: elephant, peacock, statue, lamp, fountain, board.

@export_enum("elephant", "peacock", "statue", "lamp", "fountain", "board") var animation_type := "statue"
@export var enable_animation := true
@export_range(0.0, 2.0, 0.05) var intensity := 1.0
@export var cycle_speed := 1.0
@export var rotate_idle := false
@export var rotate_degrees_per_second := 3.0

var _origin_position: Vector3
var _origin_rotation: Vector3
var _time := 0.0
var _meshes: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []

func _ready() -> void:
    _origin_position = position
    _origin_rotation = rotation
    _collect(self)
    if animation_type == "lamp":
        _setup_lamp_lights()

func _process(delta: float) -> void:
    if not enable_animation:
        return
    _time += delta * cycle_speed
    var wave := sin(_time)
    match animation_type:
        "elephant":
            rotation.z = _origin_rotation.z + sin(_time * 0.65) * 0.012 * intensity
            position.y = _origin_position.y + absf(sin(_time * 1.3)) * 0.008 * intensity
        "peacock":
            rotation.y = _origin_rotation.y + sin(_time * 0.42) * deg_to_rad(2.2) * intensity
            rotation.z = _origin_rotation.z + sin(_time * 0.9) * 0.009 * intensity
        "statue":
            # Statues remain still; only a restrained jewel glint is animated.
            _animate_glints(0.12 + 0.10 * (0.5 + 0.5 * wave))
        "lamp":
            _animate_lamps()
        "fountain":
            position.y = _origin_position.y + sin(_time * 1.6) * 0.006 * intensity
            _animate_glints(0.25 + 0.15 * (0.5 + 0.5 * wave))
        "board":
            if rotate_idle:
                rotation.y = _origin_rotation.y + sin(_time * 0.25) * deg_to_rad(1.0) * intensity

func _collect(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            _meshes.append(child)
        if child is OmniLight3D:
            _lights.append(child)
        _collect(child)

func _setup_lamp_lights() -> void:
    if not _lights.is_empty():
        return
    var light := OmniLight3D.new()
    light.name = "ProceduralDeepamGlow"
    light.position = Vector3(0, 0.8, 0)
    light.light_color = Color(1.0, 0.58, 0.20)
    light.light_energy = 0.7
    light.omni_range = 3.0
    add_child(light)
    _lights.append(light)

func _animate_lamps() -> void:
    for i in range(_lights.size()):
        var light := _lights[i]
        light.light_energy = 0.65 + (0.12 * sin(_time * 8.0 + float(i))) * intensity
        light.omni_range = 2.8 + 0.12 * sin(_time * 5.0 + float(i))

func _animate_glints(amount: float) -> void:
    # Low-cost subtle emissive modulation. Only touches materials that expose emission.
    for mesh in _meshes:
        if mesh.material_override is StandardMaterial3D:
            var mat := mesh.material_override as StandardMaterial3D
            if mat.emission_enabled:
                mat.emission_energy_multiplier = amount
