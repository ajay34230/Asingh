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
var _mesh: MeshInstance3D
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
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	match k:
		"health":
			m.radius = 0.2
			m.height = 0.4
		_:
			m.radius = 0.17
			m.height = 0.5
			m.radial_segments = 6
			m.rings = 2
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	_mesh.material_override = mat
	add_child(_mesh)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 5.0
	l.light_energy = 0.9
	add_child(l)
	return self


func _process(delta: float) -> void:
	if player == null:
		return
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			visible = true
		return
	_t += delta
	_mesh.position.y = 0.9 + sin(_t * 2.2) * 0.12
	_mesh.rotation.y = _t * 2.0
	if global_position.distance_to(player.global_position + Vector3(0, 0.8, 0)) < 1.6:
		player.apply_powerup(kind)
		Sfx.ui("powerup", -3.0)
		visible = false
		if respawn > 0.0:
			_gone = respawn
		else:
			queue_free()
