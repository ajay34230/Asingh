extends Node3D
class_name RoyalAnimationEffects
## Shared reusable one-shot visual effects. Add this node to the scene and call its methods.

@export var gold_color := Color(1.0, 0.67, 0.16, 1.0)

func impact_burst(world_position: Vector3, scale_amount := 1.0) -> void:
    var burst := _make_burst(world_position, gold_color, scale_amount)
    get_tree().current_scene.add_child(burst)
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector3.ONE * 1.8 * scale_amount, 0.22)
    tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.24)
    tween.tween_callback(burst.queue_free)

func transformation_burst(world_position: Vector3) -> void:
    impact_burst(world_position, 1.4)

func landing_burst(world_position: Vector3) -> void:
    impact_burst(world_position, 0.8)

func _make_burst(at: Vector3, tint: Color, amount: float) -> MeshInstance3D:
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.18
    mesh.outer_radius = 0.24
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.global_position = at + Vector3.UP * 0.025
    node.scale = Vector3.ONE * 0.45 * amount
    node.rotation.x = deg_to_rad(90.0)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = 2.0
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    node.material_override = mat
    return node
