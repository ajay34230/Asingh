class_name Pickup
extends Node3D
## A floating power-up gem. Walk into it to collect. kinds: health, speed, power, shield.

const COLORS := {
	"health": Color(1.0, 0.25, 0.3), "speed": Color(0.3, 0.7, 1.0),
	"power": Color(1.0, 0.6, 0.15), "shield": Color(1.0, 0.9, 0.35),
}
const NAMES := {"health": "HEALTH +40", "speed": "SPEED BOOST", "power": "POWER x2", "shield": "SHIELD"}
var kind := "health"
var player: Player
var _t := 0.0
var _mesh: Node3D
var _ground_y := 0.0
var respawn := 0.0           # > 0: comes back this many seconds after being taken
var _gone := 0.0


func setup(k: String, ply: Player, at: Vector3, respawn_after: float = 0.0) -> Pickup:
	kind = k
	player = ply
	respawn = respawn_after
	position = at
	_ground_y = at.y
	var col: Color = COLORS[k]
	_mesh = _icon(k, col)
	add_child(_mesh)
	# glowing ring on the ground and a few rising sparkles so the icon reads from far away
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	ring.mesh = tm
	ring.material_override = _glow(col, 0.8)
	ring.position.y = 0.06
	add_child(ring)
	var sp := CPUParticles3D.new()
	sp.amount = 8
	sp.lifetime = 1.6
	sp.direction = Vector3.UP
	sp.spread = 20.0
	sp.initial_velocity_min = 0.3
	sp.initial_velocity_max = 0.7
	sp.gravity = Vector3.ZERO
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.4
	sp.scale_amount_min = 0.7
	sp.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var qm := _glow(col, 2.5)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	sp.mesh = q
	sp.position.y = 0.3
	add_child(sp)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 4.0
	l.light_energy = 0.4
	add_child(l)
	return self


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


## A 3D icon built from primitives: heart, lightning bolt, sword or shield.
func _icon(k: String, col: Color) -> Node3D:
	var n := Node3D.new()
	var mat := _glow(col, 0.9)
	var white := _glow(Color(1, 1, 1), 0.7)
	match k:
		"health":
			var lobe := SphereMesh.new()
			lobe.radius = 0.17
			lobe.height = 0.34
			_part(n, lobe, mat, Vector3(-0.11, 0.1, 0.0)).scale = Vector3(1, 1, 0.7)
			_part(n, lobe, mat, Vector3(0.11, 0.1, 0.0)).scale = Vector3(1, 1, 0.7)
			var tip := CylinderMesh.new()
			tip.top_radius = 0.27
			tip.bottom_radius = 0.0
			tip.height = 0.34
			tip.radial_segments = 14
			_part(n, tip, mat, Vector3(0.0, -0.06, 0.0)).scale = Vector3(1, 1, 0.65)
			_part(n, _box(0.06, 0.2, 0.05), white, Vector3(0.0, 0.1, 0.17))
			_part(n, _box(0.2, 0.06, 0.05), white, Vector3(0.0, 0.1, 0.17))
		"speed":
			_part(n, _box(0.14, 0.34, 0.08), mat, Vector3(0.07, 0.24, 0.0), Vector3(0, 0, 0.42))
			_part(n, _box(0.36, 0.1, 0.08), mat, Vector3(0.0, 0.03, 0.0))
			_part(n, _box(0.14, 0.34, 0.08), mat, Vector3(-0.07, -0.18, 0.0), Vector3(0, 0, 0.42))
			_part(n, _box(0.07, 0.2, 0.09), white, Vector3(0.07, 0.24, 0.0), Vector3(0, 0, 0.42))
		"power":
			_part(n, _box(0.1, 0.46, 0.05), mat, Vector3(0.0, 0.14, 0.0))
			var tipm := CylinderMesh.new()
			tipm.top_radius = 0.0
			tipm.bottom_radius = 0.05
			tipm.height = 0.12
			tipm.radial_segments = 4
			_part(n, tipm, mat, Vector3(0.0, 0.43, 0.0))
			_part(n, _box(0.34, 0.06, 0.08), white, Vector3(0.0, -0.1, 0.0))
			_part(n, _box(0.07, 0.2, 0.07), white, Vector3(0.0, -0.22, 0.0))
			var pom := SphereMesh.new()
			pom.radius = 0.06
			pom.height = 0.12
			_part(n, pom, white, Vector3(0.0, -0.34, 0.0))
			n.rotation.z = 0.35
		"shield":
			var disc := CylinderMesh.new()
			disc.top_radius = 0.3
			disc.bottom_radius = 0.3
			disc.height = 0.08
			disc.radial_segments = 6
			_part(n, disc, mat, Vector3(0.0, 0.08, 0.0), Vector3(PI * 0.5, 0, 0))
			var pt := CylinderMesh.new()
			pt.top_radius = 0.26
			pt.bottom_radius = 0.0
			pt.height = 0.3
			pt.radial_segments = 6
			_part(n, pt, mat, Vector3(0.0, -0.16, 0.0)).scale = Vector3(1, 1, 0.25)
			_part(n, _box(0.07, 0.4, 0.06), white, Vector3(0.0, 0.04, 0.05))
			_part(n, _box(0.4, 0.07, 0.06), white, Vector3(0.0, 0.12, 0.05))
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			_part(n, sm, mat, Vector3.ZERO)
	n.scale = Vector3.ONE * 1.5
	return n


## Pickup burst: expanding ring, sparks, and a lingering effect on the player (healing sparkles for health).
func _collect_fx() -> void:
	var col: Color = COLORS[kind]
	var at := global_position + Vector3(0, 0.9, 0)
	var root := get_parent()
	HitFx.burst(root, at, true, col)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	ring.mesh = tm
	var rm := _glow(Color(col.r, col.g, col.b, 0.8), 2.0)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	root.add_child(ring)
	ring.global_position = at
	ring.scale = Vector3(0.2, 0.2, 0.2)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.0, 3.0, 3.0), 0.5)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)
	if kind == "health":
		var hp := HitFx.burst(player, Vector3.ZERO, true, Color(0.4, 1.0, 0.5))
		hp.reparent(player, false)
		hp.position = Vector3(0, 0.2, 0)
		hp.direction = Vector3.UP
		hp.spread = 25.0
		hp.initial_velocity_min = 1.0
		hp.initial_velocity_max = 2.4
		hp.gravity = Vector3(0, 0.5, 0)
		hp.amount = 30
		hp.lifetime = 1.2
		hp.one_shot = true
		hp.restart()


func _process(delta: float) -> void:
	if player == null:
		return
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			visible = true
		return
	_t += delta
	_mesh.position.y = 1.0 + sin(_t * 2.2) * 0.12
	_mesh.rotation.y = _t * 1.6
	if global_position.distance_to(player.global_position + Vector3(0, 0.8, 0)) < 1.6:
		player.apply_powerup(kind)
		_collect_fx()
		Sfx.ui("powerup", -3.0)
		visible = false
		if respawn > 0.0:
			_gone = respawn
		else:
			queue_free()
