class_name BossOrb
extends Node3D
## A slow fire orb thrown by a boss in its last phase. It curves a little toward the player, so you
## dodge it by rolling or running across its path. Bursts on the ground or on the player.

const SPEED := 11.0
var vel := Vector3.ZERO
var dmg := 10.0
var target: Node3D
var _life := 0.0
var _mi: MeshInstance3D


func launch(from: Vector3, to: Vector3, damage: float, tgt: Node3D) -> void:
	global_position = from
	dmg = damage
	target = tgt
	vel = (to - from).normalized() * SPEED
	_mi = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 12
	sm.rings = 6
	_mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 4.0
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)


func _physics_process(delta: float) -> void:
	_life += delta
	_mi.scale = Vector3.ONE * (0.9 + 0.15 * sin(_life * 30.0))
	if _life > 4.0:
		queue_free()
		return
	if is_instance_valid(target):
		var want := (target.global_position + Vector3(0, 1.0, 0) - global_position).normalized() * SPEED
		vel = vel.lerp(want, clampf(0.6 * delta, 0.0, 1.0))      # gentle homing: a sidestep still beats it
	var prev := global_position
	var next := prev + vel * delta
	if is_instance_valid(target) and target.global_position.distance_to(next - Vector3(0, 1.0, 0)) < 0.9:
		if target.has_method("take_damage"):
			target.call("take_damage", dmg, vel.normalized())
		_burst()
		return
	var q := PhysicsRayQueryParameters3D.create(prev, next)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider is CharacterBody3D):
		_burst()
		return
	global_position = next


func _burst() -> void:
	HitFx.burst(get_parent(), global_position, true, Color(1.0, 0.5, 0.1))
	Sfx.at("hit_thud", global_position, -2.0, 0.6)
	queue_free()
