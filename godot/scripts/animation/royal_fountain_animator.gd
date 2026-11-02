extends Node3D
class_name RoyalFountainAnimator
## Attach to Lotus Fountain root. Assign optional water_surface and splash_particles.

@export var water_surface: Node3D
@export var splash_particles: GPUParticles3D
@export var ripple_nodes: Array[Node3D] = []
@export var water_bob_height := 0.018
@export var ripple_scale := 1.08
@export var cycle_speed := 1.0

var _water_start := Vector3.ZERO
var _time := 0.0

func _ready() -> void:
    if is_instance_valid(water_surface):
        _water_start = water_surface.position
    if is_instance_valid(splash_particles):
        splash_particles.emitting = true

func _process(delta: float) -> void:
    _time += delta * cycle_speed
    if is_instance_valid(water_surface):
        water_surface.position = _water_start + Vector3.UP * sin(_time * 2.0) * water_bob_height
    for i in range(ripple_nodes.size()):
        var ripple := ripple_nodes[i]
        if is_instance_valid(ripple):
            var phase := fposmod(_time * 0.55 + float(i) / maxf(1.0, float(ripple_nodes.size())), 1.0)
            var scale_factor := lerpf(0.65, ripple_scale, phase)
            ripple.scale = Vector3.ONE * scale_factor
            ripple.modulate.a = 1.0 - phase if ripple is Sprite3D else 1.0
