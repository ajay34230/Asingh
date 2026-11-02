extends Node3D
class_name RoyalTokenVFX
## Optional child of a token. Creates lightweight selection/arrival glows and burst effects.

@export var ring_color := Color(1.0, 0.72, 0.18, 0.9)
@export var ring_radius := 0.42
@export var ring_width := 0.025
@export var rotate_speed := 1.4

var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _selected := false
var _time := 0.0

func _ready() -> void:
    _create_ring()
    set_selected(false)

func _process(delta: float) -> void:
    _time += delta
    if is_instance_valid(_ring):
        _ring.rotation.y += delta * rotate_speed
        _ring.visible = _selected
        if _selected:
            var pulse := 1.0 + sin(_time * 5.0) * 0.06
            _ring.scale = Vector3.ONE * pulse

func set_selected(value: bool) -> void:
    _selected = value
    if is_instance_valid(_ring):
        _ring.visible = value

func play_arrival_burst() -> void:
    var tween := create_tween()
    scale = Vector3.ONE * 0.55
    tween.tween_property(self, "scale", Vector3.ONE * 1.25, 0.13).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_SINE)

func _create_ring() -> void:
    var mesh := TorusMesh.new()
    mesh.inner_radius = ring_radius
    mesh.outer_radius = ring_radius + ring_width
    _ring = MeshInstance3D.new()
    _ring.name = "SelectionHalo"
    _ring.mesh = mesh
    _ring.position.y = 0.015
    _ring.rotation.x = deg_to_rad(90.0)
    _ring_material = StandardMaterial3D.new()
    _ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_material.albedo_color = ring_color
    _ring_material.emission_enabled = true
    _ring_material.emission = ring_color
    _ring_material.emission_energy_multiplier = 1.4
    _ring.material_override = _ring_material
    add_child(_ring)
