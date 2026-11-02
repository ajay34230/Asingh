extends Node
class_name RoyalLampFlicker
## Attach to a Deepam lamp root. Assign one or more OmniLight3D/SpotLight3D nodes.

@export var lights: Array[Light3D] = []
@export var base_energy := 0.85
@export var flicker_amount := 0.16
@export var speed := 8.0

var _time := 0.0

func _process(delta: float) -> void:
    _time += delta
    for i in range(lights.size()):
        var light := lights[i]
        if is_instance_valid(light):
            light.light_energy = base_energy + sin(_time * speed + float(i) * 1.7) * flicker_amount
