class_name Arrow
extends Node3D
## A flying arrow: leaves the string at ~40 m/s on a real ballistic arc aimed to land on the target,
## turns to follow its flight, leaves a faint streak, and on impact sticks into the enemy (or the ground or a
## wall) and quivers before it fades away.

const SPEED := 40.0
const G := 6.0                 # a little less than real gravity so arcs read well on a phone screen
var vel := Vector3.ZERO
var foe: Enemy
var dmg := 0.0
var shooter: Node3D
var _life := 0.0
var _stuck := -1.0
var _wobble := 0.0
var _trail: MeshInstance3D
var _model: Node3D


func launch(from: Transform3D, target: Vector3, f: Enemy, damage: float, by: Node3D) -> void:
	foe = f
	dmg = damage
	shooter = by
	global_transform = from
	var d := target - from.origin
	var flat := Vector2(d.x, d.z).length()
	var t := maxf(flat / SPEED, 0.05)
	var dir := Vector3(d.x, 0.0, d.z).normalized() if flat > 0.01 else -from.basis.z
	vel = dir * (flat / t) + Vector3.UP * ((d.y + 0.5 * G * t * t) / t)
	_model = RealHuman.arrow_model()
	if _model == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.01
		cm.bottom_radius = 0.01
		cm.height = 0.8
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		_model = Node3D.new()
		_model.add_child(mi)
	add_child(_model)
	_trail = MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.006
	tm.bottom_radius = 0.0
	tm.height = 1.0
	tm.radial_segments = 4
	_trail.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 0.92, 0.45)
	_trail.material_override = mat
	_trail.rotation.x = PI * 0.5
	_trail.position = Vector3(0, 0, 0.9)
	_trail.scale = Vector3(1, 1.1, 1)
	add_child(_trail)
	_face(vel)


func _face(v: Vector3) -> void:
	if v.length() > 0.01:
		look_at(global_position + v, Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.FORWARD)


func _physics_process(delta: float) -> void:
	_life += delta
	if _stuck >= 0.0:
		_stuck += delta
		if _wobble > 0.0:                       # the shaft quivers after it bites in
			_wobble = maxf(0.0, _wobble - delta * 3.0)
			_model.rotation.x = sin(_stuck * 60.0) * 0.06 * _wobble
		if _stuck > 6.0:
			queue_free()
		return
	if _life > 3.5:
		queue_free()
		return
	var prev := global_position
	vel.y -= G * delta
	var next := prev + vel * delta
	# enemies along this step (the chosen target first, then anyone else in the way)
	var victims: Array = []
	if is_instance_valid(foe) and not foe.dead:
		victims.append(foe)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != foe:
			victims.append(e)
	for e in victims:
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var hover := float(en.get("hover")) if en.get("hover") != null else 0.0
		var c := en.global_position + Vector3(0, 1.1 + hover, 0)
		var seg := next - prev
		var tt := clampf((c - prev).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (prev + seg * tt).distance_to(c) < 0.75:
			global_position = prev + seg * tt
			en.take_hit("arrow", dmg, vel.normalized())
			Sfx.at("hit_thud", global_position, -4.0, 1.4)
			_stick(en)
			return
	var q := PhysicsRayQueryParameters3D.create(prev, next)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider is CharacterBody3D):
		global_position = (hit.position as Vector3) - vel.normalized() * 0.25
		Sfx.at("tink", global_position, -6.0, 1.2)
		_stick(null)
		return
	global_position = next
	_face(vel)
	_trail.scale.y = clampf(vel.length() / SPEED, 0.2, 1.2)


func _stick(into: Node3D) -> void:
	_stuck = 0.0
	_wobble = 1.0
	_trail.visible = false
	if into != null and is_instance_valid(into):
		var g := global_transform
		get_parent().remove_child(self)
		into.add_child(self)
		global_transform = g
