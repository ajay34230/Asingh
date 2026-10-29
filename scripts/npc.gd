class_name Npc
extends Node3D
## A non-interactive ambient figure (no dialogue, no AI, no story role yet): a HumanRig that
## idles or works, with a solid collider so the player cannot walk through it. Animation only
## runs while the player is within ANIM_RANGE metres, to save frame time on phones.

const ANIM_RANGE := 70.0

var rig: HumanRig
var player: Node3D


func setup(preset: Dictionary, mode: String, label: String) -> Npc:
	name = label
	rig = HumanRig.new().setup(preset, label)
	rig.mode = mode
	add_child(rig)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)
	return self


func _process(delta: float) -> void:
	if player == null or rig == null:
		return
	var near := global_position.distance_squared_to(player.global_position) < ANIM_RANGE * ANIM_RANGE
	rig.visible = near or true
	if near:
		rig.animate(delta, 0.0, true)
